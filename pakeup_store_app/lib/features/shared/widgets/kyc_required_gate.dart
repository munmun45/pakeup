import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/partner_kyc_status.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';

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
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title),
        body: Center(child: Text('$e')),
      ),
      data: (stores) {
        if (!_isKycApproved(partner: partner, stores: stores)) {
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
                      Icons.verified_user_outlined,
                      size: 64,
                      color: AppColors.warning.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'KYC verification required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete and get KYC approved before accessing '
                      'bank details or services.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        final q = storeId != null ? '?storeId=$storeId' : '';
                        context.push('/kyc$q');
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Complete KYC'),
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
