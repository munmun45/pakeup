import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/partners_repository.dart';
import 'partner_map_preview.dart';
import 'partner_table_widgets.dart';

class PartnerDetailDialog extends StatelessWidget {
  const PartnerDetailDialog({
    super.key,
    required this.partner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final PartnerRecord partner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      partner.businessName.isNotEmpty
                          ? partner.businessName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          partner.ownerName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PartnerCategoryBadge(label: partner.displayCategory),
                  PartnerStatusBadge(isActive: partner.isActive),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      if (partner.description?.trim().isNotEmpty == true) ...[
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partner.description!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _DetailField(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: partner.phone ?? '—',
                      ),
                      _DetailField(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: partner.email ?? '—',
                      ),
                      if (partner.whatsapp?.trim().isNotEmpty == true)
                        _DetailField(
                          icon: Icons.chat_outlined,
                          label: 'WhatsApp',
                          value: partner.whatsapp!,
                        ),
                      if (partner.alternatePhone?.trim().isNotEmpty == true)
                        _DetailField(
                          icon: Icons.phone_callback_outlined,
                          label: 'Alt. Phone',
                          value: partner.alternatePhone!,
                        ),
                      _DetailField(
                        icon: Icons.language_outlined,
                        label: 'Website',
                        value: partner.website ?? '—',
                      ),
                      _DetailField(
                        icon: Icons.receipt_long_outlined,
                        label: 'GST',
                        value: partner.gstNumber ?? '—',
                      ),
                      _DetailField(
                        icon: Icons.place_outlined,
                        label: 'Address',
                        value: partner.addressLine ?? '—',
                      ),
                      _DetailField(
                        icon: Icons.location_city_outlined,
                        label: 'City',
                        value: [
                          partner.city,
                          partner.state,
                          partner.pincode,
                        ].where((e) => e?.trim().isNotEmpty == true).join(', ').isEmpty
                            ? '—'
                            : [
                                partner.city,
                                partner.state,
                                partner.pincode,
                              ]
                                .where((e) => e?.trim().isNotEmpty == true)
                                .join(', '),
                      ),
                      if (partner.latitude != null &&
                          partner.longitude != null)
                        _DetailField(
                          icon: Icons.my_location_outlined,
                          label: 'Coordinates',
                          value:
                              '${partner.latitude!.toStringAsFixed(6)}, ${partner.longitude!.toStringAsFixed(6)}',
                        ),
                      _DetailField(
                        icon: Icons.verified_user_outlined,
                        label: 'KYC Status',
                        value: partner.kycStatus.toUpperCase(),
                      ),
                      if (partner.notes?.trim().isNotEmpty == true)
                        _DetailField(
                          icon: Icons.notes_outlined,
                          label: 'Notes',
                          value: partner.notes!,
                        ),
                      if (partner.createdAt != null)
                        _DetailField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Added On',
                          value: dateFmt.format(partner.createdAt!.toLocal()),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Map Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PartnerMapPreview(
                        googleMapEmbed: partner.googleMapEmbed,
                        latitude: partner.latitude,
                        longitude: partner.longitude,
                        height: 200,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PartnerDialogActionButton(
                      label: partner.isActive ? 'Deactivate' : 'Activate',
                      icon: partner.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      onPressed: onToggleActive,
                      variant: partner.isActive
                          ? PartnerDialogActionVariant.warning
                          : PartnerDialogActionVariant.success,
                    ),
                    const SizedBox(width: 6),
                    PartnerDialogActionButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      onPressed: onEdit,
                      variant: PartnerDialogActionVariant.primary,
                    ),
                    const SizedBox(width: 6),
                    PartnerDialogActionButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      onPressed: onDelete,
                      variant: PartnerDialogActionVariant.danger,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
