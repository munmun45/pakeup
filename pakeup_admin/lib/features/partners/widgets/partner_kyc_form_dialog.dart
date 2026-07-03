import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../data/partners_repository.dart';
import '../models/partner_kyc_models.dart';
import '../providers/partner_kyc_provider.dart';
import 'kyc_document_upload_tile.dart';
import 'partner_form_field.dart';

/// Result from [PartnerKycFormDialog]: `true` = saved, `'open_bank'` = open account page.
typedef PartnerKycDialogResult = Object?;

class PartnerKycFormDialog extends ConsumerStatefulWidget {
  const PartnerKycFormDialog({super.key, required this.partner});

  final PartnerRecord partner;

  @override
  ConsumerState<PartnerKycFormDialog> createState() =>
      _PartnerKycFormDialogState();
}

class _PartnerKycFormDialogState extends ConsumerState<PartnerKycFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _panCtrl;
  late final TextEditingController _aadhaarCtrl;
  late final TextEditingController _otherDocNameCtrl;

  String? _propertyType;
  bool _loading = true;
  bool _submitting = false;
  bool _kycSaved = false;

  final Map<KycDocType, _LocalDoc> _docs = {
    for (final t in KycDocType.values)
      if (t != KycDocType.passbook) t: _LocalDoc(),
  };

  static const _requiredDocs = [KycDocType.aadhaar, KycDocType.pan];

  @override
  void initState() {
    super.initState();
    _panCtrl = TextEditingController();
    _aadhaarCtrl = TextEditingController();
    _otherDocNameCtrl = TextEditingController();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final kyc = await ref.read(partnerKycRepositoryProvider).getKyc(
            callerId: user.id,
            partnerId: widget.partner.id,
          );
      if (kyc != null && mounted) {
        _propertyType = kyc.propertyType;
        _panCtrl.text = kyc.panNumber ?? '';
        _aadhaarCtrl.text = kyc.aadhaarNumber ?? '';
        _otherDocNameCtrl.text = kyc.otherDocName ?? '';
        _docs[KycDocType.aadhaar]!.existingUrl = kyc.aadhaarDocUrl;
        _docs[KycDocType.pan]!.existingUrl = kyc.panDocUrl;
        _docs[KycDocType.agreement]!.existingUrl = kyc.agreementDocUrl;
        _docs[KycDocType.gst]!.existingUrl = kyc.gstDocUrl;
        _docs[KycDocType.other]!.existingUrl = kyc.otherDocUrl;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_panCtrl, _aadhaarCtrl, _otherDocNameCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile(KycDocType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _docs[type]!
        ..localPath = file.path
        ..localName = file.name;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnackBar.error(context, 'Could not open document');
    }
  }

  String? _docLabel(KycDocType type) {
    final doc = _docs[type]!;
    return doc.localName ??
        (doc.existingUrl != null ? 'Uploaded document' : null);
  }

  bool _hasDoc(KycDocType type) {
    final doc = _docs[type]!;
    return doc.localPath != null || doc.existingUrl != null;
  }

  String? _docUrlOrNull(KycDocType type) {
    final doc = _docs[type]!;
    return doc.localPath == null ? doc.existingUrl : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_propertyType == null) {
      AppSnackBar.error(context, 'Select property type (Own, Lease, or Rent)');
      return;
    }

    for (final type in _requiredDocs) {
      if (!_hasDoc(type)) {
        AppSnackBar.error(context, 'Upload ${type.label}');
        return;
      }
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerKycRepositoryProvider);
      final partnerId = widget.partner.id;

      Future<String?> urlFor(KycDocType type) async {
        final doc = _docs[type]!;
        if (doc.localPath != null) {
          return repo.uploadDocument(
            partnerId: partnerId,
            docType: type,
            localPath: doc.localPath!,
          );
        }
        return doc.existingUrl;
      }

      final data = PartnerKycFormData(
        propertyType: _propertyType,
        panNumber: _panCtrl.text.trim(),
        aadhaarNumber: _aadhaarCtrl.text.trim(),
        aadhaarDocUrl: await urlFor(KycDocType.aadhaar),
        panDocUrl: await urlFor(KycDocType.pan),
        agreementDocUrl: _hasDoc(KycDocType.agreement)
            ? await urlFor(KycDocType.agreement)
            : null,
        gstDocUrl:
            _hasDoc(KycDocType.gst) ? await urlFor(KycDocType.gst) : null,
        otherDocUrl:
            _hasDoc(KycDocType.other) ? await urlFor(KycDocType.other) : null,
        otherDocName: _otherDocNameCtrl.text.trim().isEmpty
            ? null
            : _otherDocNameCtrl.text.trim(),
      );

      await repo.saveKyc(
        callerId: user.id,
        partnerId: partnerId,
        data: data,
      );

      if (mounted) {
        AppSnackBar.success(context, 'KYC documents submitted for review');
        setState(() {
          _submitting = false;
          _kycSaved = true;
        });
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            _Header(
              partnerName: widget.partner.businessName,
              onClose: _submitting ? null : () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      color: const Color(0xFFF3F4F6),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_kycSaved)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.success
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: AppColors.success,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'KYC submitted. Add bank account details on the next step.',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              PartnerFormSection(
                                title: 'Property Type',
                                icon: Icons.home_work_outlined,
                                children: [
                                  KycPropertyTypeSelector(
                                    value: _propertyType,
                                    onChanged: (v) =>
                                        setState(() => _propertyType = v),
                                  ),
                                ],
                              ),
                              PartnerFormSection(
                                title: 'Identity & Business Documents',
                                icon: Icons.folder_open_outlined,
                                children: [
                                  PartnerFormRow(
                                    children: [
                                      PartnerFormField(
                                        label: 'PAN Number',
                                        icon: Icons.badge_outlined,
                                        controller: _panCtrl,
                                        required: true,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[A-Za-z0-9]'),
                                          ),
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'PAN is required';
                                          }
                                          if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
                                              .hasMatch(
                                                  v.trim().toUpperCase())) {
                                            return 'Invalid PAN format';
                                          }
                                          return null;
                                        },
                                      ),
                                      PartnerFormField(
                                        label: 'Aadhaar Number',
                                        icon: Icons.fingerprint,
                                        controller: _aadhaarCtrl,
                                        required: true,
                                        keyboard: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(12),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Aadhaar is required';
                                          }
                                          if (v.trim().length != 12) {
                                            return 'Aadhaar must be 12 digits';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                  KycDocumentUploadTile(
                                    label: KycDocType.aadhaar.label,
                                    icon: Icons.credit_card_outlined,
                                    fileName: _docLabel(KycDocType.aadhaar),
                                    hasFile: _hasDoc(KycDocType.aadhaar),
                                    onPick: () => _pickFile(KycDocType.aadhaar),
                                    onView: _docUrlOrNull(KycDocType.aadhaar) !=
                                            null
                                        ? () => _openUrl(
                                              _docUrlOrNull(
                                                KycDocType.aadhaar,
                                              )!,
                                            )
                                        : null,
                                  ),
                                  KycDocumentUploadTile(
                                    label: KycDocType.pan.label,
                                    icon: Icons.badge_outlined,
                                    fileName: _docLabel(KycDocType.pan),
                                    hasFile: _hasDoc(KycDocType.pan),
                                    onPick: () => _pickFile(KycDocType.pan),
                                    onView: _docUrlOrNull(KycDocType.pan) !=
                                            null
                                        ? () => _openUrl(
                                              _docUrlOrNull(KycDocType.pan)!,
                                            )
                                        : null,
                                  ),
                                  KycDocumentUploadTile(
                                    label: KycDocType.agreement.label,
                                    icon: Icons.description_outlined,
                                    fileName: _docLabel(KycDocType.agreement),
                                    hasFile: _hasDoc(KycDocType.agreement),
                                    onPick: () =>
                                        _pickFile(KycDocType.agreement),
                                    onView: _docUrlOrNull(
                                              KycDocType.agreement) !=
                                            null
                                        ? () => _openUrl(
                                              _docUrlOrNull(
                                                KycDocType.agreement,
                                              )!,
                                            )
                                        : null,
                                    required: false,
                                  ),
                                  KycDocumentUploadTile(
                                    label: KycDocType.gst.label,
                                    icon: Icons.receipt_long_outlined,
                                    fileName: _docLabel(KycDocType.gst),
                                    hasFile: _hasDoc(KycDocType.gst),
                                    onPick: () => _pickFile(KycDocType.gst),
                                    onView: _docUrlOrNull(KycDocType.gst) !=
                                            null
                                        ? () => _openUrl(
                                              _docUrlOrNull(KycDocType.gst)!,
                                            )
                                        : null,
                                    required: false,
                                  ),
                                  PartnerFormField(
                                    label: 'Other Document Name (optional)',
                                    icon: Icons.label_outline,
                                    controller: _otherDocNameCtrl,
                                    hint: 'e.g. Trade License, FSSAI...',
                                  ),
                                  KycDocumentUploadTile(
                                    label: KycDocType.other.label,
                                    icon: Icons.attach_file,
                                    fileName: _docLabel(KycDocType.other),
                                    hasFile: _hasDoc(KycDocType.other),
                                    onPick: () => _pickFile(KycDocType.other),
                                    onView: _docUrlOrNull(KycDocType.other) !=
                                            null
                                        ? () => _openUrl(
                                              _docUrlOrNull(KycDocType.other)!,
                                            )
                                        : null,
                                    required: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context, _kycSaved),
                    child: Text(_kycSaved ? 'Done' : 'Cancel'),
                  ),
                  if (_kycSaved) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, 'open_bank'),
                      icon: const Icon(Icons.account_balance_outlined, size: 18),
                      label: const Text('Add Account Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(_submitting ? 'Uploading...' : 'Submit KYC'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDoc {
  String? existingUrl;
  String? localPath;
  String? localName;
}

class _Header extends StatelessWidget {
  const _Header({required this.partnerName, this.onClose});

  final String partnerName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner KYC Upload',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  partnerName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
