import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../shared/widgets/app_ui_components.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../models/store_models.dart';
import '../providers/stores_provider.dart';

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);

    return PageScaffold(
      title: 'My Stores',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/stores/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Store'),
      ),
      body: storesAsync.when(
        loading: () => const LoadingState(message: 'Loading stores...'),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myStoresProvider),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return pullToRefreshBox(
              onRefresh: () async {
                ref.invalidate(myStoresProvider);
                await ref.read(myStoresProvider.future);
              },
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              child: Center(
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No stores yet',
                  message: 'Add your first store to get started.',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push('/stores/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Store'),
                  ),
                ),
              ),
            );
          }

          return pullToRefresh(
            onRefresh: () async {
              ref.invalidate(myStoresProvider);
              await ref.read(myStoresProvider.future);
            },
            child: ListView.builder(
              physics: alwaysScrollablePhysics,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.pageHorizontal,
                AppSpacing.pageHorizontal,
                AppSpacing.pageBottom,
              ),
              itemCount: stores.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StoreCard(store: stores[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: () => context.push('/stores/${store.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: store.primaryImage != null && store.primaryImage!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      store.primaryImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : const Icon(Icons.storefront_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.businessName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (store.city != null && store.city!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${store.city}${store.state != null && store.state!.isNotEmpty ? ', ${store.state}' : ''}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusBadge.forKyc(store.kycStatus),
                    const SizedBox(width: 8),
                    if (store.isActive)
                      StatusBadge(
                        label: 'Active',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
