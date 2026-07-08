import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/partner_kyc_status.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import 'empty_state.dart';
import 'page_scaffold.dart';

/// Blocks child content until KYC is approved for the partner (or specific store).
class KycRequiredGate extends ConsumerWidget {
  const KycRequiredGate({
    super.key,
    required this.title,
    required this.child,
    this.storeId,
  });

  final String title;
  final Widget child;
  final String? storeId;

  bool _isKycApproved({
    PartnerUser? partner,
    required List<StoreRecord> stores,
  }) {
    if (storeId != null) {
      for (final store in stores) {
        if (store.id == storeId) return store.isKycApproved;
      }
    }
    return PartnerKycStatus.isApproved(
      stores: stores,
      accountStatus: partner?.kycStatus,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authStateProvider).valueOrNull;
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
        if (!_isKycApproved(partner: partner, stores: stores)) {
          return PageScaffold(
            title: title,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'KYC verification required',
                  message:
                      'Complete and get KYC approved before accessing '
                      'bank details or services.',
                  action: ElevatedButton.icon(
                    onPressed: () {
                      final q = storeId != null ? '?storeId=$storeId' : '';
                      context.push('/kyc$q');
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Complete KYC'),
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
