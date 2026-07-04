import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_messenger.dart';
import 'features/auth/providers/auth_provider.dart';

class PakeUpStoreApp extends ConsumerWidget {
  const PakeUpStoreApp({super.key, this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initError != null) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    'Supabase not configured',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(initError!, textAlign: TextAlign.center),
                ],
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
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
