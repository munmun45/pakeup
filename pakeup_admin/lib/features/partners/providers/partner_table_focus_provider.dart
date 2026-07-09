import 'package:flutter_riverpod/flutter_riverpod.dart';

class PartnerTableFocus {
  const PartnerTableFocus({
    required this.partnerId,
    this.businessName,
  });

  final String partnerId;
  final String? businessName;
}

/// Filter store list to all stores under one parent account.
class PartnerAccountStoreFilter {
  const PartnerAccountStoreFilter({
    required this.accountId,
    required this.ownerName,
    required this.storeCount,
    this.profileId,
  });

  final String accountId;
  final String ownerName;
  final int storeCount;
  final String? profileId;

  String get headerLabel {
    final id = profileId?.trim();
    if (id != null && id.isNotEmpty) return '$ownerName · $id';
    return ownerName;
  }
}

final partnerTableFocusProvider =
    StateProvider<PartnerTableFocus?>((ref) => null);

final partnerAccountStoreFilterProvider =
    StateProvider<PartnerAccountStoreFilter?>((ref) => null);

List<T> filterByPartnerFocus<T>(
  List<T> items,
  PartnerTableFocus? focus,
  String Function(T item) partnerIdSelector,
) {
  if (focus == null) return items;
  return items.where((e) => partnerIdSelector(e) == focus.partnerId).toList();
}

List<T> filterByAccountStores<T>(
  List<T> items,
  PartnerAccountStoreFilter? filter,
  String? Function(T item) accountIdSelector,
) {
  if (filter == null) return items;
  return items
      .where((e) => accountIdSelector(e) == filter.accountId)
      .toList();
}
