import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class BankInfoCard extends StatelessWidget {
  const BankInfoCard({
    super.key,
    this.ownerName,
    this.shortAccountId,
    this.statusLabel,
    this.statusColor,
  });

  final String? ownerName;
  final String? shortAccountId;
  final String? statusLabel;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.security_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerName?.trim().isNotEmpty == true
                          ? ownerName!
                          : 'Partner account',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'One bank account per login. Shared across all your stores.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (shortAccountId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'ID $shortAccountId',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (statusLabel != null && statusColor != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor!.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BankDetailRow extends StatelessWidget {
  const BankDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String maskAccountNumber(String? accountNumber) {
  final ac = accountNumber?.trim();
  if (ac == null || ac.isEmpty) return '—';
  if (ac.length <= 4) return ac;
  return '****${ac.substring(ac.length - 4)}';
}

String formatAccountType(String? type) {
  final value = type?.trim();
  if (value == null || value.isEmpty) return '—';
  return value[0].toUpperCase() + value.substring(1);
}

String shortPartnerId(String id) {
  if (id.length <= 12) return id;
  return '${id.substring(0, 8)}…';
}

BankStatusInfo bankStatusInfo(String? status) {
  return switch (status) {
    'approved' => const BankStatusInfo('Approved', AppColors.success),
    'rejected' => const BankStatusInfo('Rejected', AppColors.error),
    'pending' => const BankStatusInfo('Pending approval', AppColors.warning),
    _ => const BankStatusInfo(null, null),
  };
}

class BankStatusInfo {
  const BankStatusInfo(this.label, this.color);
  final String? label;
  final Color? color;
}
