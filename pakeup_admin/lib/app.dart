import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_messenger.dart';
import 'core/widgets/smooth_scroll_behavior.dart';
import 'features/auth/providers/auth_provider.dart';

class PakeUpAdminApp extends ConsumerWidget {
  const PakeUpAdminApp({super.key, this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initError != null) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        scrollBehavior: const SmoothScrollBehavior(),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Supabase not configured',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '1. Copy .env.example → .env\n'
                      '2. Paste anon key from Supabase → Settings → API\n'
                      '3. Restart the app',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authStateProvider);
    final router = ref.watch(routerProvider);

    if (authState.isLoading) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        scrollBehavior: const SmoothScrollBehavior(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const SmoothScrollBehavior(),
      builder: (context, child) {
        return ScaffoldMessenger(
          key: rootScaffoldMessengerKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
