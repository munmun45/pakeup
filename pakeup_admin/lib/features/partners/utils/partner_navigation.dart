import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/partner_table_focus_provider.dart';
import '../data/partners_repository.dart';
import '../../../core/providers/header_search_provider.dart';

enum PartnerHubPage { kyc, account, service }

class PartnerNavigation {
  PartnerNavigation._();

  static void openHubPage(
    WidgetRef ref,
    BuildContext context, {
    required PartnerHubPage page,
    required String partnerId,
    String? businessName,
  }) {
    ref.read(partnerTableFocusProvider.notifier).state = PartnerTableFocus(
      partnerId: partnerId,
      businessName: businessName,
    );

    final route = switch (page) {
      PartnerHubPage.kyc => '/partners/kyc',
      PartnerHubPage.account => '/partners/accounts',
      PartnerHubPage.service => '/partners/services',
    };

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(route);
    });
  }

  static void openPartnerManagement(
    WidgetRef ref,
    BuildContext context, {
    required String partnerId,
    String? businessName,
  }) {
    ref.read(partnerTableFocusProvider.notifier).state = PartnerTableFocus(
      partnerId: partnerId,
      businessName: businessName,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/partners/add');
    });
  }

  static void openAccountStores(
    WidgetRef ref,
    BuildContext context, {
    required PartnerOwnerAccount account,
  }) {
    ref.read(partnerTableFocusProvider.notifier).state = null;
    ref.read(partnerAccountStoreFilterProvider.notifier).state =
        PartnerAccountStoreFilter(
      accountId: account.id,
      ownerName: account.ownerName,
      storeCount: account.storeCount,
      profileId: account.profileId,
    );
    ref.read(headerSearchQueryProvider.notifier).state = account.ownerName;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/partners/add');
    });
  }

  static void clearFocus(WidgetRef ref) {
    ref.read(partnerTableFocusProvider.notifier).state = null;
    ref.read(partnerAccountStoreFilterProvider.notifier).state = null;
    ref.read(headerSearchQueryProvider.notifier).state = '';
  }

  static void openPartnerRoute(
    WidgetRef ref,
    BuildContext context,
    String route,
  ) {
    ref.read(partnerTableFocusProvider.notifier).state = null;
    context.go(route);
  }
}
