import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/store_models.dart';

class StoreSelectDropdownTile extends StatelessWidget {
  const StoreSelectDropdownTile({
    super.key,
    required this.store,
    this.compact = false,
  });

  final StoreRecord store;
  final bool compact;

  Color get _kycColor => switch (store.kycStatus) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              store.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _KycStatusChip(
            label: _shortKycLabel(store.kycStatus),
            color: _kycColor,
            compact: true,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                store.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (store.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        store.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _KycStatusChip(
          label: store.kycLabel,
          color: _kycColor,
        ),
      ],
    );
  }

  static String _shortKycLabel(String status) => switch (status) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };
}

class _KycStatusChip extends StatelessWidget {
  const _KycStatusChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> buildStoreDropdownItems(
  List<StoreRecord> stores, {
  bool kycApprovedOnly = false,
}) {
  final filtered =
      kycApprovedOnly ? stores.where((s) => s.isKycApproved).toList() : stores;
  return filtered
      .map(
        (store) => DropdownMenuItem(
          value: store.id,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StoreSelectDropdownTile(store: store),
          ),
        ),
      )
      .toList();
}
