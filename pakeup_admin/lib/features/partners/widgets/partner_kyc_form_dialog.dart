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
import '../utils/kyc_document_limits.dart';
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

  static const _docTypes = [
    KycDocType.aadhaar,
    KycDocType.pan,
    KycDocType.agreement,
    KycDocType.gst,
    KycDocType.other,
  ];

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

  int get _uploadedDocCount =>
      _docTypes.where((t) => _hasDoc(t)).length;

  Future<void> _pickFile(KycDocType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final size = file.size;
    if (size > 0) {
      final error = KycDocumentLimits.validateBytes(size, type);
      if (error != null) {
        setState(() => _docs[type]!.errorMessage = error);
        return;
      }
    } else {
      final error = await KycDocumentLimits.validatePath(file.path!, type);
      if (error != null) {
        setState(() => _docs[type]!.errorMessage = error);
        return;
      }
    }

    setState(() {
      _docs[type]!
        ..localPath = file.path
        ..localName = file.name
        ..errorMessage = null;
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

  Widget _docTile(KycDocType type, {bool required = true}) {
    return KycDocumentUploadTile(
      label: type.label,
      icon: _docIcon(type),
      fileName: _docLabel(type),
      hasFile: _hasDoc(type),
      sizeHint: KycDocumentLimits.uploadHint(type),
      errorText: _docs[type]!.errorMessage,
      required: required,
      onPick: () => _pickFile(type),
      onView: _docUrlOrNull(type) != null
          ? () => _openUrl(_docUrlOrNull(type)!)
          : null,
    );
  }

  IconData _docIcon(KycDocType type) => switch (type) {
        KycDocType.aadhaar => Icons.credit_card_outlined,
        KycDocType.pan => Icons.badge_outlined,
        KycDocType.agreement => Icons.description_outlined,
        KycDocType.gst => Icons.receipt_long_outlined,
        KycDocType.other => Icons.attach_file,
        KycDocType.passbook => Icons.menu_book_outlined,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_propertyType == null) {
      AppSnackBar.error(context, 'Select property type (Own, Lease, or Rent)');
      return;
    }

    var hasDocError = false;
    for (final type in _requiredDocs) {
      if (!_hasDoc(type)) {
        setState(() {
          _docs[type]!.errorMessage = 'Please upload ${type.label}';
        });
        hasDocError = true;
      }
    }
    if (hasDocError) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

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
      if (mounted) {
        AppSnackBar.actionFailed(context, 'submit KYC documents', e);
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final initial = widget.partner.businessName.isNotEmpty
        ? widget.partner.businessName[0].toUpperCase()
        : 'P';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.14),
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
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
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.partner.businessName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_uploadedDocCount/${_docTypes.length} docs',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context, _kycSaved),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ColoredBox(
                          color: AppColors.background.withValues(alpha: 0.45),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_kycSaved)
                                    _SuccessBanner(
                                      onAddAccount: () => Navigator.pop(
                                        context,
                                        'open_bank',
                                      ),
                                    ),
                                  _KycSection(
                                    step: '1',
                                    title: 'Property Type',
                                    subtitle:
                                        'Select how the business premises is held',
                                    icon: Icons.home_work_outlined,
                                    child: KycPropertyTypeSelector(
                                      value: _propertyType,
                                      onChanged: (v) =>
                                          setState(() => _propertyType = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _KycSection(
                                    step: '2',
                                    title: 'Identity Details',
                                    subtitle: 'PAN and Aadhaar numbers',
                                    icon: Icons.badge_outlined,
                                    child: PartnerFormRow(
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
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return 'PAN is required';
                                            }
                                            if (!RegExp(
                                              r'^[A-Z]{5}[0-9]{4}[A-Z]$',
                                            ).hasMatch(v.trim().toUpperCase())) {
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
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(12),
                                          ],
                                          validator: (v) {
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return 'Aadhaar is required';
                                            }
                                            if (v.trim().length != 12) {
                                              return 'Must be 12 digits';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _KycSection(
                                    step: '3',
                                    title: 'Required Documents',
                                    subtitle: 'Aadhaar and PAN card uploads',
                                    icon: Icons.folder_open_outlined,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final twoCol =
                                            constraints.maxWidth >= 520;
                                        if (twoCol) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _docTile(
                                                  KycDocType.aadhaar,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _docTile(
                                                  KycDocType.pan,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          children: [
                                            _docTile(KycDocType.aadhaar),
                                            _docTile(KycDocType.pan),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _KycSection(
                                    step: '4',
                                    title: 'Additional Documents',
                                    subtitle: 'Optional business documents',
                                    icon: Icons.attach_file,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final twoCol =
                                                constraints.maxWidth >= 520;
                                            if (twoCol) {
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: _docTile(
                                                      KycDocType.agreement,
                                                      required: false,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: _docTile(
                                                      KycDocType.gst,
                                                      required: false,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                            return Column(
                                              children: [
                                                _docTile(
                                                  KycDocType.agreement,
                                                  required: false,
                                                ),
                                                _docTile(
                                                  KycDocType.gst,
                                                  required: false,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        PartnerFormField(
                                          label: 'Other Document Name',
                                          icon: Icons.label_outline,
                                          controller: _otherDocNameCtrl,
                                          hint: 'e.g. Trade License, FSSAI...',
                                        ),
                                        _docTile(
                                          KycDocType.other,
                                          required: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Max 1 MB per file · Agreement 2 MB',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const Spacer(),
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
                          icon: const Icon(
                            Icons.account_balance_outlined,
                            size: 18,
                          ),
                          label: const Text('Add Account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.45),
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
                              : const Icon(Icons.cloud_upload_outlined,
                                  size: 18),
                          label: Text(
                            _submitting ? 'Uploading...' : 'Submit KYC',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
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
        ),
      ),
    );
  }
}

class _KycSection extends StatelessWidget {
  const _KycSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'KYC submitted successfully!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onAddAccount,
            child: const Text('Add Account →'),
          ),
        ],
      ),
    );
  }
}

class _LocalDoc {
  String? existingUrl;
  String? localPath;
  String? localName;
  String? errorMessage;
}
