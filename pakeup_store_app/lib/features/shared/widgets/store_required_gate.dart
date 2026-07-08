import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'empty_state.dart';
import 'page_scaffold.dart';
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
      loading: () => PageScaffold(
        title: title,
        body: const LoadingState(),
      ),
      error: (e, _) => PageScaffold(
        title: title,
        body: ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myStoresProvider),
        ),
      ),
      data: (stores) {
        if (stores.isEmpty) {
          return PageScaffold(
            title: title,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Add a store first',
                  message:
                      'You need at least one store before using this feature.',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push('/stores/add'),
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Add Store'),
                  ),
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
