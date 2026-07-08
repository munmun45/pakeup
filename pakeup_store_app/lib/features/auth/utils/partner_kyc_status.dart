import '../../stores/models/store_models.dart';

/// Resolves partner-visible KYC from live store records (preferred) or account cache.
class PartnerKycStatus {
  PartnerKycStatus._();

  static String resolve({
    required List<StoreRecord> stores,
    String? accountStatus,
  }) {
    if (stores.any((s) => s.isKycApproved)) return 'approved';
    if (stores.isNotEmpty && stores.every((s) => s.kycStatus == 'rejected')) {
      return 'rejected';
    }
    if (stores.any((s) => s.kycStatus == 'rejected')) return 'rejected';
    if (stores.isNotEmpty) {
      return stores.first.kycStatus;
    }
    return accountStatus ?? 'pending';
  }

  static bool isApproved({
    required List<StoreRecord> stores,
    String? accountStatus,
  }) =>
      resolve(stores: stores, accountStatus: accountStatus) == 'approved';
}
