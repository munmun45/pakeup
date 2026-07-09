import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_kyc_models.dart';
import '../utils/kyc_document_limits.dart';

class PartnerKycRepository {
  PartnerKycRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'partner-kyc';

  Future<PartnerKycRecord?> getKyc({
    required String callerId,
    required String partnerId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_partner_kyc',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
      },
    );
    if (result == null) return null;
    return PartnerKycRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<PartnerKycOverviewRecord>> listKycOverview(String callerId) async {
    final overviewResult = await _client.rpc<dynamic>(
      'list_partner_kyc_overview',
      params: {'caller_id': callerId},
    );
    if (overviewResult == null) return [];

    final list = overviewResult is List<dynamic>
        ? overviewResult
        : const <dynamic>[];
    final rows = list
        .map(
          (e) => PartnerKycOverviewRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    try {
      final enrichResults = await Future.wait<dynamic>([
        _client.rpc<dynamic>(
          'list_partners',
          params: {'caller_id': callerId},
        ),
        _client.rpc<dynamic>(
          'list_partner_accounts',
          params: {'caller_id': callerId},
        ),
      ]);

      final partners = enrichResults[0] is List<dynamic>
          ? (enrichResults[0] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const <Map<String, dynamic>>[];
      final accounts = enrichResults[1] is List<dynamic>
          ? (enrichResults[1] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const <Map<String, dynamic>>[];

      final profileByAccountId = <String, String>{
        for (final account in accounts)
          if (account['id'] is String &&
              (account['profile_id'] as String?)?.trim().isNotEmpty == true)
            account['id'] as String: (account['profile_id'] as String).trim(),
      };

      final profileByPartnerId = <String, String>{};
      final accountIdByPartnerId = <String, String>{};
      for (final partner in partners) {
        final partnerId = partner['id'] as String?;
        if (partnerId == null) continue;

        final accountId = partner['account_id'] as String?;
        if (accountId != null) {
          accountIdByPartnerId[partnerId] = accountId;
        }

        final direct = (partner['profile_id'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) {
          profileByPartnerId[partnerId] = direct;
          continue;
        }

        if (accountId == null) continue;

        final profileId = profileByAccountId[accountId];
        if (profileId != null) {
          profileByPartnerId[partnerId] = profileId;
        }
      }

      final enriched = rows.map((row) {
        var next = row;
        final accountId = accountIdByPartnerId[row.partnerId];
        if (accountId != null) {
          next = next.copyWith(accountId: accountId);
        }

        final existing = next.profileId?.trim();
        if (existing != null && existing.isNotEmpty) return next;

        final profileId = profileByPartnerId[row.partnerId];
        if (profileId == null) return next;

        return next.copyWith(profileId: profileId);
      }).toList();

      return _dedupeKycByAccount(enriched);
    } catch (_) {
      return _dedupeKycByAccount(rows);
    }
  }

  List<PartnerKycOverviewRecord> _dedupeKycByAccount(
    List<PartnerKycOverviewRecord> rows,
  ) {
    final groups = <String, List<PartnerKycOverviewRecord>>{};
    for (final row in rows) {
      groups.putIfAbsent(_kycGroupKey(row), () => []).add(row);
    }

    final merged = groups.values.map(_mergeKycGroup).toList()
      ..sort((a, b) {
        final da = a.createdAt;
        final db = b.createdAt;
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.ownerName.compareTo(b.ownerName);
      });
    return merged;
  }

  String _kycGroupKey(PartnerKycOverviewRecord row) {
    final accountId = row.accountId?.trim();
    if (accountId != null && accountId.isNotEmpty) return 'account:$accountId';

    final profileId = row.profileId?.trim();
    if (profileId != null && profileId.isNotEmpty) return 'profile:$profileId';

    return 'partner:${row.partnerId}';
  }

  PartnerKycOverviewRecord _mergeKycGroup(List<PartnerKycOverviewRecord> group) {
    if (group.length == 1) return group.first;

    final sorted = [...group]
      ..sort((a, b) {
        final score = _kycRowScore(b).compareTo(_kycRowScore(a));
        if (score != 0) return score;
        final da = a.createdAt;
        final db = b.createdAt;
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return 0;
      });
    final primary = sorted.first;

    return primary.copyWith(
      businessName: primary.ownerName,
      storeCount: group.length,
      kycStatus: _aggregateKycStatus(group),
      panNumber: _firstNonEmpty(group.map((r) => r.panNumber)),
      aadhaarNumber: _firstNonEmpty(group.map((r) => r.aadhaarNumber)),
      hasAadhaarDoc: group.any((r) => r.hasAadhaarDoc),
      hasPanDoc: group.any((r) => r.hasPanDoc),
      hasAgreementDoc: group.any((r) => r.hasAgreementDoc),
      hasGstDoc: group.any((r) => r.hasGstDoc),
      hasOtherDoc: group.any((r) => r.hasOtherDoc),
      hasPassbookDoc: group.any((r) => r.hasPassbookDoc),
    );
  }

  int _kycRowScore(PartnerKycOverviewRecord row) {
    var score = row.uploadedDocCount * 10;
    if (row.panNumber?.trim().isNotEmpty == true) score += 5;
    if (row.aadhaarNumber?.trim().isNotEmpty == true) score += 5;
    if (row.kycStatus == 'approved') score += 3;
    return score;
  }

  String _aggregateKycStatus(Iterable<PartnerKycOverviewRecord> rows) {
    if (rows.any((r) => r.kycStatus == 'approved')) return 'approved';
    if (rows.any((r) => r.kycStatus == 'rejected')) return 'rejected';
    return 'pending';
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Future<PartnerKycRecord> saveKyc({
    required String callerId,
    required String partnerId,
    required PartnerKycFormData data,
    bool markSubmitted = true,
  }) async {
    final result = await _client.rpc<dynamic>(
      'upsert_partner_kyc',
      params: {
        'caller_id': callerId,
        'partner_id': partnerId,
        ...data.toRpcParams(markSubmitted: markSubmitted),
      },
    );
    return PartnerKycRecord.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<void> deletePartnerDocuments(String partnerId) async {
    try {
      final entries = await _client.storage.from(_bucket).list(path: partnerId);
      if (entries.isEmpty) return;

      final paths = entries
          .where((entry) => entry.name.isNotEmpty)
          .map((entry) => '$partnerId/${entry.name}')
          .toList();

      if (paths.isNotEmpty) {
        await _client.storage.from(_bucket).remove(paths);
      }
    } catch (_) {
      // Storage cleanup is best-effort; DB delete still proceeds.
    }
  }

  Future<String> uploadDocument({
    required String partnerId,
    required KycDocType docType,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final sizeError = await KycDocumentLimits.validatePath(localPath, docType);
    if (sizeError != null) {
      throw Exception(sizeError);
    }

    final ext = _extension(localPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$partnerId/${docType.key}_$timestamp$ext';
    final bytes = await file.readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeType(ext),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<PartnerBankAccountRecord?> getBankAccount({
    required String callerId,
    required String accountId,
  }) async {
    try {
      final result = await _client.rpc<dynamic>(
        'get_partner_bank_account',
        params: {
          'caller_id': callerId,
          'account_id': accountId,
        },
      );
      if (result == null) return null;
      return PartnerBankAccountRecord.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      return _getBankAccountLegacy(callerId: callerId, accountId: accountId);
    }
  }

  Future<void> saveBankAccount({
    required String callerId,
    required String accountId,
    required String bankAccountHolder,
    required String bankName,
    required String ifscCode,
    required String accountNumber,
    String? passbookDocUrl,
    String? accountType,
    String? upiId,
  }) async {
    final type = accountType ?? 'savings';
    final data = PartnerKycFormData(
      bankAccountHolder: bankAccountHolder,
      bankName: bankName,
      ifscCode: ifscCode,
      accountNumber: accountNumber,
      passbookDocUrl: passbookDocUrl,
      accountType: type,
      upiId: upiId,
    );

    await _saveBankAccountExtras(
      callerId: callerId,
      accountId: accountId,
      accountType: type,
      upiId: upiId,
    );

    try {
      await _client.rpc(
        'upsert_partner_bank_account',
        params: {
          'caller_id': callerId,
          'account_id': accountId,
          'bank_account_holder': bankAccountHolder,
          'bank_name': bankName,
          'ifsc_code': ifscCode,
          'account_number': accountNumber,
          'passbook_doc_url': passbookDocUrl,
          'account_type': type,
          'upi_id': upiId,
        },
      );
    } catch (e) {
      if (!_isMissingRpc(e)) {
        try {
          await _client.rpc(
            'upsert_partner_bank_account',
            params: {
              'caller_id': callerId,
              'account_id': accountId,
              'bank_account_holder': bankAccountHolder,
              'bank_name': bankName,
              'ifsc_code': ifscCode,
              'account_number': accountNumber,
              'passbook_doc_url': passbookDocUrl,
            },
          );
        } catch (inner) {
          if (!_isMissingRpc(inner)) rethrow;
          await _saveBankAccountLegacy(
            callerId: callerId,
            accountId: accountId,
            data: data,
          );
        }
      } else {
        await _saveBankAccountLegacy(
          callerId: callerId,
          accountId: accountId,
          data: data,
        );
      }
    }

    await _saveBankAccountExtras(
      callerId: callerId,
      accountId: accountId,
      accountType: type,
      upiId: upiId,
    );
  }

  Future<void> _saveBankAccountExtras({
    required String callerId,
    required String accountId,
    required String accountType,
    String? upiId,
  }) async {
    Object? lastError;

    for (final rpc in ['patch_partner_bank_account_extras', 'save_partner_bank_meta_admin']) {
      try {
        await _client.rpc(
          rpc,
          params: {
            'caller_id': callerId,
            'account_id': accountId,
            'account_type': accountType,
            'upi_id': upiId,
          },
        );
        return;
      } catch (e) {
        if (!_isMissingRpc(e)) {
          lastError = e;
        }
      }
    }

    if (lastError != null) throw lastError;
  }

  Future<String> uploadBankDocument({
    required String accountId,
    required KycDocType docType,
    required String localPath,
  }) async {
    return uploadDocument(
      partnerId: accountId,
      docType: docType,
      localPath: localPath,
    );
  }

  Future<List<PartnerAccountRecord>> listAccounts(String callerId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'list_partner_bank_accounts',
        params: {'caller_id': callerId},
      );
      if (result == null) return [];
      final list = result as List<dynamic>;
      final rows = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (rows.isNotEmpty && rows.first.containsKey('account_id')) {
        return rows
            .map((e) => PartnerAccountRecord.fromJson(e))
            .toList();
      }

      return _listAccountsLegacy(callerId: callerId, bankRows: rows);
    } catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      return _listAccountsLegacy(callerId: callerId, bankRows: const []);
    }
  }

  Future<PartnerAccountRecord> enrichAccountRecord({
    required String callerId,
    required PartnerAccountRecord account,
  }) async {
    if (account.accountId.isEmpty) return account;

    try {
      final bank = await getBankAccount(
        callerId: callerId,
        accountId: account.accountId,
      );
      if (bank == null) return account;
      return _mergeAccountWithBank(account, bank);
    } catch (_) {
      return account;
    }
  }

  PartnerAccountRecord _mergeAccountWithBank(
    PartnerAccountRecord account,
    PartnerBankAccountRecord bank,
  ) {
    return PartnerAccountRecord(
      accountId: account.accountId,
      ownerName: account.ownerName,
      phone: account.phone,
      email: account.email,
      primaryImage: account.primaryImage,
      isActive: account.isActive,
      storeCount: account.storeCount,
      accountStatus: account.accountStatus,
      bankAccountHolder: bank.bankAccountHolder ?? account.bankAccountHolder,
      bankName: bank.bankName ?? account.bankName,
      ifscCode: bank.ifscCode ?? account.ifscCode,
      accountNumber: bank.accountNumber ?? account.accountNumber,
      passbookDocUrl: bank.passbookDocUrl ?? account.passbookDocUrl,
      accountType: bank.accountType ?? account.accountType,
      upiId: bank.upiId ?? account.upiId,
      createdAt: account.createdAt,
      accountUpdatedAt: bank.updatedAt ?? account.accountUpdatedAt,
    );
  }

  Future<void> setAccountStatus({
    required String callerId,
    required String accountId,
    required String status,
  }) async {
    try {
      await _client.rpc(
        'set_partner_account_status',
        params: {
          'caller_id': callerId,
          'account_id': accountId,
          'new_status': status,
        },
      );
      return;
    } catch (e) {
      if (!_isMissingRpc(e)) rethrow;
    }

    final partnerIds = await _partnerIdsForAccount(callerId, accountId);
    if (partnerIds.isEmpty) {
      throw Exception('No stores found for this partner account');
    }

    for (final partnerId in partnerIds) {
      await _client.rpc(
        'set_partner_account_status',
        params: {
          'caller_id': callerId,
          'partner_id': partnerId,
          'new_status': status,
        },
      );
    }
  }

  Future<PartnerBankAccountRecord?> _getBankAccountLegacy({
    required String callerId,
    required String accountId,
  }) async {
    final partnerIds = await _partnerIdsForAccount(callerId, accountId);
    if (partnerIds.isEmpty) return null;

    final kyc = await getKyc(callerId: callerId, partnerId: partnerIds.first);
    if (kyc == null) return null;

    try {
      final bank = await _client.rpc<dynamic>(
        'get_partner_bank_account',
        params: {
          'caller_id': callerId,
          'account_id': accountId,
        },
      );
      if (bank != null) {
        final row = Map<String, dynamic>.from(bank as Map);
        return PartnerBankAccountRecord(
          accountId: accountId,
          bankAccountHolder:
              row['bank_account_holder'] as String? ?? kyc.bankAccountHolder,
          bankName: row['bank_name'] as String? ?? kyc.bankName,
          ifscCode: row['ifsc_code'] as String? ?? kyc.ifscCode,
          accountNumber: row['account_number'] as String? ?? kyc.accountNumber,
          passbookDocUrl:
              row['passbook_doc_url'] as String? ?? kyc.passbookDocUrl,
          accountType: row['account_type'] as String? ?? kyc.accountType,
          upiId: row['upi_id'] as String? ?? kyc.upiId,
        );
      }
    } catch (_) {}

    return PartnerBankAccountRecord(
      accountId: accountId,
      bankAccountHolder: kyc.bankAccountHolder,
      bankName: kyc.bankName,
      ifscCode: kyc.ifscCode,
      accountNumber: kyc.accountNumber,
      passbookDocUrl: kyc.passbookDocUrl,
      accountType: kyc.accountType ?? 'savings',
      upiId: kyc.upiId,
    );
  }

  Future<void> _saveBankAccountLegacy({
    required String callerId,
    required String accountId,
    required PartnerKycFormData data,
  }) async {
    final partnerIds = await _partnerIdsForAccount(callerId, accountId);
    if (partnerIds.isEmpty) {
      throw Exception('No stores found for this partner account');
    }

    for (final partnerId in partnerIds) {
      final existing = await getKyc(callerId: callerId, partnerId: partnerId);
      await saveKyc(
        callerId: callerId,
        partnerId: partnerId,
        markSubmitted: false,
        data: PartnerKycFormData(
          propertyType: existing?.propertyType,
          panNumber: existing?.panNumber,
          aadhaarNumber: existing?.aadhaarNumber,
          bankAccountHolder: data.bankAccountHolder,
          bankName: data.bankName,
          ifscCode: data.ifscCode,
          accountNumber: data.accountNumber,
          aadhaarDocUrl: existing?.aadhaarDocUrl,
          panDocUrl: existing?.panDocUrl,
          agreementDocUrl: existing?.agreementDocUrl,
          gstDocUrl: existing?.gstDocUrl,
          passbookDocUrl: data.passbookDocUrl ?? existing?.passbookDocUrl,
          otherDocUrl: existing?.otherDocUrl,
          otherDocName: existing?.otherDocName,
          accountType: data.accountType,
          upiId: data.upiId,
        ),
      );
    }
  }

  Future<List<PartnerAccountRecord>> _listAccountsLegacy({
    required String callerId,
    required List<Map<String, dynamic>> bankRows,
  }) async {
    final partners = await _listPartnerMaps(callerId);
    final byAccount = <String, Map<String, dynamic>>{};

    for (final partner in partners) {
      final accountId = partner['account_id'] as String?;
      if (accountId == null || accountId.isEmpty) continue;

      byAccount.putIfAbsent(accountId, () {
        return {
          'account_id': accountId,
          'profile_id': partner['profile_id'],
          'owner_name': partner['owner_name'] ?? '',
          'phone': partner['phone'],
          'email': partner['email'],
          'is_active': partner['is_active'] ?? true,
          'store_count': partner['store_count'] ?? 0,
          'primary_image': partner['primary_image'],
          'created_at': partner['created_at'],
          'account_status': 'pending',
        };
      });
    }

    for (final row in bankRows) {
      final partnerId = row['partner_id'] as String?;
      if (partnerId == null) continue;

      final partner = partners.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['id'] == partnerId,
            orElse: () => null,
          );
      final accountId = partner?['account_id'] as String?;
      if (accountId == null || !byAccount.containsKey(accountId)) continue;

      final account = byAccount[accountId]!;
      account['account_status'] = row['account_status'] ?? 'pending';
      account['bank_account_holder'] = row['bank_account_holder'];
      account['bank_name'] = row['bank_name'];
      account['ifsc_code'] = row['ifsc_code'];
      account['account_number'] = row['account_number'];
      account['passbook_doc_url'] = row['passbook_doc_url'];
      account['account_type'] = row['account_type'];
      account['upi_id'] = row['upi_id'];
      account['account_updated_at'] = row['account_updated_at'];
    }

    return byAccount.values
        .map((row) => PartnerAccountRecord.fromJson(row))
        .toList();
  }

  Future<List<String>> _partnerIdsForAccount(
    String callerId,
    String accountId,
  ) async {
    final partners = await _listPartnerMaps(callerId);
    return partners
        .where((p) => p['account_id'] == accountId)
        .map((p) => p['id'] as String)
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _listPartnerMaps(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_partners',
      params: {'caller_id': callerId},
    );
    if (result == null) return [];
    return (result as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  bool _isMissingRpc(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('schema cache');
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot).toLowerCase();
  }

  String _mimeType(String ext) {
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
