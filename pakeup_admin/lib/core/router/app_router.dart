import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admins/screens/manage_admins_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/widgets/admin_shell.dart';
import '../../features/partners/screens/add_partners_screen.dart';
import '../../features/partners/screens/manage_partner_categories_screen.dart';
import '../../features/partners/screens/partner_kyc_screen.dart';
import '../../features/partners/screens/partner_manage_accounts_screen.dart';
import '../../features/partners/screens/partner_services_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/shared/screens/placeholder_screen.dart';
import '../constants/admin_pages.dart';
import 'page_transitions.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final user = authState.valueOrNull;
      final isLoginRoute = state.matchedLocation == '/login';

      if (isLoading) return null;

      if (user == null && !isLoginRoute) return '/login';
      if (user != null && isLoginRoute) {
        RouteTransitionTracker.reset();
        final firstPage = AdminPages.forUser(
          isSuperAdmin: user.isSuperAdmin,
          pageKeys: user.pages,
        );
        return firstPage.isNotEmpty
            ? firstPage.first.route ?? '/dashboard'
            : '/dashboard';
      }

      if (user != null) {
        if (state.matchedLocation == '/profile') return null;

        final pageKey = RouteTransitionTracker.pageKeyFromPath(
          state.matchedLocation,
        );
        if (pageKey != null && !user.canAccess(pageKey)) {
          final allowed = AdminPages.forUser(
            isSuperAdmin: user.isSuperAdmin,
            pageKeys: user.pages,
          );
          return allowed.isNotEmpty
              ? allowed.first.route ?? '/dashboard'
              : '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildLoginPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.matchedLocation;
          final pageKey =
              RouteTransitionTracker.pageKeyFromPath(path) ?? 'dashboard';

          return AdminShell(
            title: RouteTransitionTracker.titleForPath(path),
            currentPageKey: pageKey,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/manage-admins',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const ManageAdminsScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/partners/add',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const AddPartnersScreen(),
            ),
          ),
          GoRoute(
            path: '/partners/categories',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const ManagePartnerCategoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/partners/kyc',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const PartnerKycScreen(),
            ),
          ),
          GoRoute(
            path: '/partners/accounts',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const PartnerManageAccountsScreen(),
            ),
          ),
          GoRoute(
            path: '/partners/services',
            pageBuilder: (context, state) => buildAdminPage(
              state: state,
              child: const PartnerServicesScreen(),
            ),
          ),
          for (final page in AdminPages.all)
            if (page.route != null &&
                page.route != '/dashboard' &&
                page.route != '/manage-admins' &&
                page.key != 'add_partners' &&
                page.key != 'partner_categories' &&
                page.key != 'partner_kyc' &&
                page.key != 'partner_manage_accounts' &&
                page.key != 'partner_services')
              GoRoute(
                path: page.route!,
                pageBuilder: (context, state) => buildAdminPage(
                  state: state,
                  child: PlaceholderScreen(
                    title: page.label,
                    pageKey: page.key,
                  ),
                ),
              ),
        ],
      ),
    ],
  );
});
