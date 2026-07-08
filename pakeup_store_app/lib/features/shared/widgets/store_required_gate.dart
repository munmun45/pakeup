import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../stores/providers/stores_provider.dart';

/// Blocks child content until the partner has at least one store.
class StoreRequiredGate extends ConsumerWidget {
  const StoreRequiredGate({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);

    return storesAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (stores) {
        if (stores.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _appBar(title),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add a store first',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You need at least one store before using this feature.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/stores/add'),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Add Store'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}
