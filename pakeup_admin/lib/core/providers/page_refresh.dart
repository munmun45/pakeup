import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admins/providers/admin_users_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/partners/providers/partner_categories_provider.dart';
import '../../features/partners/providers/partner_kyc_provider.dart';
import '../../features/partners/providers/partner_services_provider.dart';
import '../../features/partners/providers/partners_provider.dart'
    show partnersListProvider, partnerOwnerAccountsListProvider;
import '../../features/profile/providers/profile_provider.dart';

/// Invalidates data providers for the given admin page key.
void refreshAdminPage(WidgetRef ref, String pageKey) {
  switch (pageKey) {
    case 'dashboard':
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentBookingsProvider);
      ref.invalidate(pendingSalonsProvider);
    case 'partner_create_account':
      ref.invalidate(partnerOwnerAccountsListProvider);
    case 'add_partners':
      ref.invalidate(partnersListProvider);
      ref.invalidate(partnerOwnerAccountsListProvider);
    case 'partner_categories':
      ref.invalidate(partnerCategoriesListProvider);
      ref.invalidate(activePartnerCategoriesProvider);
    case 'partner_kyc':
      ref.invalidate(partnersListProvider);
    case 'partner_manage_accounts':
      ref.invalidate(partnerAccountsListProvider);
    case 'partner_services':
      ref.invalidate(partnerServicesListProvider);
      ref.invalidate(partnersListProvider);
    case 'partner_inventory':
      ref.invalidate(partnerServicesListProvider);
      ref.invalidate(partnersListProvider);
    case 'manage_admins':
      ref.invalidate(adminUsersListProvider);
    case 'profile':
      ref.invalidate(adminProfileProvider);
    default:
      break;
  }
}
