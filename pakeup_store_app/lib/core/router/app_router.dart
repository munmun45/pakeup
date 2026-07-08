import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bank/screens/bank_account_view_screen.dart';
import '../../features/bank/screens/bank_details_screen.dart';
import '../../features/bookings/screens/bookings_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/kyc/screens/kyc_screen.dart';
import '../../features/main/screens/main_shell.dart';
import '../../features/payment/screens/payment_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/services/screens/services_screen.dart';
import '../../features/stores/screens/add_store_screen.dart';
import '../../features/stores/screens/edit_store_screen.dart';
import '../../features/stores/screens/store_detail_screen.dart';
import '../../features/stores/screens/stores_screen.dart';
import '../../features/shared/widgets/kyc_required_gate.dart';
import '../../features/shared/widgets/store_required_gate.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final user = authState.valueOrNull;
      final path = state.matchedLocation;
      final isAuthRoute =
          path == '/login' || path == '/register';
      if (user == null && !isAuthRoute) return '/login';
      if (user != null && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Non-shell routes (full screen)
      GoRoute(
        path: '/stores/add',
        builder: (context, state) => const AddStoreScreen(),
      ),
      GoRoute(
        path: '/stores/:storeId',
        builder: (context, state) => StoreDetailScreen(
          storeId: state.pathParameters['storeId']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => EditStoreScreen(
              storeId: state.pathParameters['storeId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) {
          final storeId = state.uri.queryParameters['storeId'];
          return StoreRequiredGate(
            title: 'KYC Verification',
            child: KycScreen(storeId: storeId),
          );
        },
      ),
      GoRoute(
        path: '/bank',
        builder: (context, state) {
          return const StoreRequiredGate(
            title: 'Bank Account',
            child: BankAccountViewScreen(),
          );
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              return const StoreRequiredGate(
                title: 'Bank Account',
                child: BankDetailsScreen(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) {
          final storeId = state.uri.queryParameters['storeId'];
          return StoreRequiredGate(
            title: 'Inventory',
            child: InventoryScreen(storeId: storeId),
          );
        },
      ),
      GoRoute(
        path: '/stores',
        builder: (context, state) => const StoresScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) {
          final storeId = state.uri.queryParameters['storeId'];
          return StoreRequiredGate(
            title: 'My Services',
            child: KycRequiredGate(
              title: 'My Services',
              storeId: storeId,
              child: ServicesScreen(storeId: storeId),
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // Bottom nav shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory-tab',
                builder: (context, state) {
                  final storeId = state.uri.queryParameters['storeId'];
                  return StoreRequiredGate(
                    title: 'Inventory',
                    child: InventoryScreen(storeId: storeId),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payment',
                builder: (context, state) => const PaymentScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
