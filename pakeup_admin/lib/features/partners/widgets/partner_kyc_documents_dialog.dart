import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/partners_repository.dart';
import '../models/partner_kyc_models.dart';
import '../providers/partner_kyc_provider.dart';
import 'partner_table_widgets.dart';

class PartnerKycDocumentsDialog extends ConsumerStatefulWidget {
  const PartnerKycDocumentsDialog({
    super.key,
    required this.partner,
  });

  final PartnerRecord partner;

  @override
  ConsumerState<PartnerKycDocumentsDialog> createState() =>
      _PartnerKycDocumentsDialogState();
}

class _PartnerKycDocumentsDialogState
    extends ConsumerState<PartnerKycDocumentsDialog> {
  PartnerKycRecord? _kyc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in again';
      });
      return;
    }

    try {
      final kyc = await ref.read(partnerKycRepositoryProvider).getKyc(
            callerId: user.id,
            partnerId: widget.partner.id,
          );
      if (mounted) {
        setState(() {
          _kyc = kyc;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _previewDocument(BuildContext context, String url, String title) {
    final lowerUrl = url.toLowerCase();
    final isPdf = lowerUrl.contains('.pdf');

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        color: AppColors.background,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: isPdf
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'PDF Preview not supported inside the app.',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Please download or view it externally.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : InteractiveViewer(
                                  maxScale: 3.0,
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(child: CircularProgressIndicator());
                                    },
                                    errorBuilder: (context, error, stackTrace) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: Colors.red),
                                        SizedBox(height: 10),
                                        Text('Could not load image preview'),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (isPdf)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          color: AppColors.background,
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(url);
                              if (uri != null) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Open Externally'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DocEntry> _buildDocEntries(PartnerKycRecord? kyc) {
    String? otherLabel;
    if (kyc?.otherDocName?.trim().isNotEmpty == true) {
      otherLabel = kyc!.otherDocName!.trim();
    }

    return [
      _DocEntry(
        label: KycDocType.aadhaar.label,
        icon: Icons.credit_card_outlined,
        url: kyc?.aadhaarDocUrl,
      ),
      _DocEntry(
        label: KycDocType.pan.label,
        icon: Icons.badge_outlined,
        url: kyc?.panDocUrl,
      ),
      _DocEntry(
        label: KycDocType.agreement.label,
        icon: Icons.description_outlined,
        url: kyc?.agreementDocUrl,
        optional: true,
      ),
      _DocEntry(
        label: KycDocType.gst.label,
        icon: Icons.receipt_long_outlined,
        url: kyc?.gstDocUrl,
        optional: true,
      ),
      _DocEntry(
        label: otherLabel ?? KycDocType.other.label,
        icon: Icons.attach_file,
        url: kyc?.otherDocUrl,
        optional: true,
        subtitle: otherLabel != null ? 'Other document' : null,
      ),
    ];
  }

  String _propertyLabel(String? type) => switch (type) {
        'own' => 'Own',
        'lease' => 'Lease',
        'rent' => 'Rent',
        _ => 'Not provided',
      };

  @override
  Widget build(BuildContext context) {
    final kyc = _kyc;
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final docs = _buildDocEntries(kyc);
    final uploadedCount = docs.where((d) => d.isUploaded).length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.surface,
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.partner.businessName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.partner.ownerName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                PartnerKycStatusBadge(
                                  status: widget.partner.kycStatus,
                                ),
                                if (kyc?.submittedAt != null)
                                  Text(
                                    'Submitted ${dateFmt.format(kyc!.submittedAt!.toLocal())}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(_error!),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _InfoGrid(
                                    items: [
                                      _InfoItem(
                                        label: 'PAN Number',
                                        value: kyc?.panNumber?.trim().isNotEmpty ==
                                                true
                                            ? kyc!.panNumber!.toUpperCase()
                                            : '—',
                                      ),
                                      _InfoItem(
                                        label: 'Aadhaar Number',
                                        value: kyc?.aadhaarNumber
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? kyc!.aadhaarNumber!
                                            : '—',
                                      ),
                                      _InfoItem(
                                        label: 'Property Type',
                                        value: _propertyLabel(kyc?.propertyType),
                                      ),
                                      _InfoItem(
                                        label: 'Documents',
                                        value: '$uploadedCount / ${docs.length}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Text(
                                        'Uploaded Documents',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$uploadedCount uploaded',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  for (final doc in docs)
                                    _DocumentViewTile(
                                      entry: doc,
                                      onOpen: doc.url != null
                                          ? () => _previewDocument(context, doc.url!, doc.label)
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
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

class _DocEntry {
  const _DocEntry({
    required this.label,
    required this.icon,
    this.url,
    this.optional = false,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final String? url;
  final bool optional;
  final String? subtitle;

  bool get isUploaded => url?.trim().isNotEmpty == true;
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

class _DocumentViewTile extends StatelessWidget {
  const _DocumentViewTile({
    required this.entry,
    this.onOpen,
  });

  final _DocEntry entry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final uploaded = entry.isUploaded;

    return MouseRegion(
      cursor: uploaded && onOpen != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: uploaded ? onOpen : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: uploaded
                ? AppColors.success.withValues(alpha: 0.04)
                : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: uploaded
                  ? AppColors.success.withValues(alpha: 0.28)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (uploaded ? AppColors.success : AppColors.textSecondary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  entry.icon,
                  size: 18,
                  color: uploaded ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      uploaded
                          ? 'Uploaded'
                          : entry.optional
                              ? 'Not uploaded'
                              : 'Missing — required',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: uploaded
                            ? AppColors.success
                            : entry.optional
                                ? AppColors.textSecondary
                                : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (uploaded && onOpen != null)
                FilledButton.tonalIcon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Icon(
                  uploaded ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 20,
                  color: uploaded
                      ? AppColors.success
                      : AppColors.textSecondary.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
