import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/partner_table_focus_provider.dart';
import '../utils/partner_navigation.dart';
import 'partner_table_widgets.dart';
import '../../../core/providers/header_search_provider.dart';

class PartnerHubNavHeaders extends StatelessWidget {
  const PartnerHubNavHeaders({super.key});

  static const kycWidth = 70.0;
  static const accountWidth = 82.0;
  static const serviceWidth = 76.0;
  static const gap = 8.0;

  static double get totalWidth =>
      kycWidth + gap + accountWidth + gap + serviceWidth;

  static double get tableColumnWidth =>
      totalWidth +
      partnerTableColumnPadding.left +
      partnerTableColumnPadding.right;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: totalWidth,
        child: const Row(
          children: [
            _HubHeader(label: 'KYC', width: kycWidth),
            SizedBox(width: gap),
            _HubHeader(label: 'BANK', width: accountWidth),
            SizedBox(width: gap),
            _HubHeader(label: 'SVC', width: serviceWidth),
          ],
        ),
      ),
    );
  }
}

class PartnerHubNavRow extends ConsumerWidget {
  const PartnerHubNavRow({
    super.key,
    required this.partnerId,
    required this.businessName,
    this.currentPage,
  });

  final String partnerId;
  final String businessName;
  final PartnerHubPage? currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: PartnerHubNavHeaders.totalWidth,
        child: Row(
          children: [
            SizedBox(
              width: PartnerHubNavHeaders.kycWidth,
              child: _buildSlot(
                ref,
                context,
                page: PartnerHubPage.kyc,
                label: 'KYC',
                icon: Icons.verified_user_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: PartnerHubNavHeaders.gap),
            SizedBox(
              width: PartnerHubNavHeaders.accountWidth,
              child: _buildSlot(
                ref,
                context,
                page: PartnerHubPage.account,
                label: 'Bank',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF7B1FA2),
              ),
            ),
            const SizedBox(width: PartnerHubNavHeaders.gap),
            SizedBox(
              width: PartnerHubNavHeaders.serviceWidth,
              child: _buildSlot(
                ref,
                context,
                page: PartnerHubPage.service,
                label: 'Svc',
                icon: Icons.spa_outlined,
                color: const Color(0xFF00897B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(
    WidgetRef ref,
    BuildContext context, {
    required PartnerHubPage page,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    if (currentPage == page) {
      return _HubNavButton(
        label: 'Partner',
        icon: Icons.storefront_outlined,
        color: AppColors.primary,
        onPressed: () => PartnerNavigation.openPartnerManagement(
          ref,
          context,
          partnerId: partnerId,
          businessName: businessName,
        ),
      );
    }

    return _HubNavButton(
      label: label,
      icon: icon,
      color: color,
      onPressed: () => PartnerNavigation.openHubPage(
        ref,
        context,
        page: page,
        partnerId: partnerId,
        businessName: businessName,
      ),
    );
  }
}

class PartnerFocusBanner extends ConsumerWidget {
  const PartnerFocusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountFilter = ref.watch(partnerAccountStoreFilterProvider);
    final focus = ref.watch(partnerTableFocusProvider);
    if (accountFilter == null && focus == null) {
      return const SizedBox.shrink();
    }

    final String message;
    if (accountFilter != null) {
      final id = accountFilter.profileId?.trim();
      final idPart = id != null && id.isNotEmpty ? ' · $id' : '';
      final n = accountFilter.storeCount;
      message =
          'Showing $n store${n == 1 ? '' : 's'} for ${accountFilter.ownerName}$idPart';
    } else {
      message = 'Showing: ${focus!.businessName ?? focus.partnerId}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(partnerAccountStoreFilterProvider.notifier).state = null;
              ref.read(partnerTableFocusProvider.notifier).state = null;
              ref.read(headerSearchQueryProvider.notifier).state = '';
            },
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label, style: partnerTableHeaderStyle),
    );
  }
}

class _HubNavButton extends StatelessWidget {
  const _HubNavButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        hoverColor: color.withValues(alpha: 0.14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
