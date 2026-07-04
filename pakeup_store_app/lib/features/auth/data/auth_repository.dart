import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

class PartnerCategoryOption {
  const PartnerCategoryOption({required this.slug, required this.name});

  final String slug;
  final String name;

  factory PartnerCategoryOption.fromJson(Map<String, dynamic> json) {
    return PartnerCategoryOption(
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }
}

class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.loginId,
    this.phone,
    this.email,
    this.city,
    this.category = 'salon',
    this.isActive = true,
    this.kycStatus = 'pending',
    this.createdAt,
    this.storeCount = 1,
  });

  final String id;
  final String businessName;
  final String ownerName;
  final String loginId;
  final String? phone;
  final String? email;
  final String? city;
  final String category;
  final bool isActive;
  final String kycStatus;
  final DateTime? createdAt;
  final int storeCount;

  bool get isKycApproved => kycStatus == 'approved';

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_name': businessName,
        'owner_name': ownerName,
        'login_id': loginId,
        'phone': phone,
        'email': email,
        'city': city,
        'category': category,
        'is_active': isActive,
        'kyc_status': kycStatus,
        'created_at': createdAt?.toIso8601String(),
      };

  factory PartnerUser.fromJson(Map<String, dynamic> json) => PartnerUser(
        id: json['id'] as String,
        businessName: json['business_name'] as String,
        ownerName: json['owner_name'] as String,
        loginId: json['login_id'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        city: json['city'] as String?,
        category: json['category'] as String? ?? 'salon',
        isActive: json['is_active'] as bool? ?? true,
        kycStatus: json['kyc_status'] as String? ?? 'pending',
        createdAt: _parseDate(json['created_at']),
        storeCount: json['store_count'] as int? ?? 1,
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

class PartnerRegisterData {
  const PartnerRegisterData({
    required this.businessName,
    required this.ownerName,
    required this.phone,
    required this.password,
    this.email,
    this.category = 'salon',
  });

  final String businessName;
  final String ownerName;
  final String phone;
  final String password;
  final String? email;
  final String category;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<PartnerUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.sessionKey);
    if (raw == null) return null;

    try {
      return PartnerUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(AppConstants.sessionKey);
      return null;
    }
  }

  Future<List<PartnerCategoryOption>> listCategories() async {
    final result = await _client.rpc<dynamic>('list_public_partner_categories');
    if (result == null) return const [];
    final list = result as List<dynamic>;
    return list
        .map((e) => PartnerCategoryOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<PartnerUser> login({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = phone.trim();
    final result = await _client.rpc<dynamic>(
      'verify_partner',
      params: {
        'login_id': normalizedPhone,
        'login_pass': password,
      },
    );

    if (result == null) {
      throw AuthException('Invalid phone number or password.');
    }

    final data = Map<String, dynamic>.from(result as Map);

    if (data['error'] == 'deactivated') {
      throw AuthException('Your partner account has been deactivated.');
    }
    if (data['error'] == 'no_password') {
      throw AuthException('Password not set. Contact admin or register again.');
    }

    final user = PartnerUser.fromJson(data);
    await _saveSession(user);
    return user;
  }

  Future<PartnerUser> register(PartnerRegisterData data) async {
    final result = await _client.rpc<dynamic>(
      'register_partner',
      params: {
        'business_name': data.businessName.trim(),
        'owner_name': data.ownerName.trim(),
        'login_id': data.phone.trim(),
        'login_pass': data.password,
        'phone': data.phone.trim(),
        'email': data.email?.trim(),
        'category': data.category,
      },
    );

    final map = Map<String, dynamic>.from(result as Map);
    final user = PartnerUser.fromJson(map);
    await _saveSession(user);
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionKey);
  }

  Future<void> _saveSession(PartnerUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionKey, jsonEncode(user.toJson()));
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
