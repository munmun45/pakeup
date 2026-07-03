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

class PartnerBankDetailsDialog extends ConsumerStatefulWidget {
  const PartnerBankDetailsDialog({super.key, required this.partner});

  final PartnerRecord partner;

  @override
  ConsumerState<PartnerBankDetailsDialog> createState() =>
      _PartnerBankDetailsDialogState();
}

class _PartnerBankDetailsDialogState
    extends ConsumerState<PartnerBankDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _confirmAccountCtrl;

  final _LocalDoc _passbook = _LocalDoc();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _holderCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
    _ifscCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _confirmAccountCtrl = TextEditingController();
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
        _holderCtrl.text = kyc.bankAccountHolder ?? '';
        _bankCtrl.text = kyc.bankName ?? '';
        _ifscCtrl.text = kyc.ifscCode ?? '';
        _accountCtrl.text = kyc.accountNumber ?? '';
        _confirmAccountCtrl.text = kyc.accountNumber ?? '';
        _passbook.existingUrl = kyc.passbookDocUrl;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _holderCtrl,
      _bankCtrl,
      _ifscCtrl,
      _accountCtrl,
      _confirmAccountCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPassbook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _passbook
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

  bool get _hasPassbook =>
      _passbook.localPath != null || _passbook.existingUrl != null;

  String? get _passbookLabel =>
      _passbook.localName ??
      (_passbook.existingUrl != null ? 'Uploaded document' : null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasPassbook) {
      AppSnackBar.error(context, 'Upload bank passbook or cancelled cheque');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerKycRepositoryProvider);
      final partnerId = widget.partner.id;

      String? passbookUrl = _passbook.existingUrl;
      if (_passbook.localPath != null) {
        passbookUrl = await repo.uploadDocument(
          partnerId: partnerId,
          docType: KycDocType.passbook,
          localPath: _passbook.localPath!,
        );
      }

      await repo.saveKyc(
        callerId: user.id,
        partnerId: partnerId,
        markSubmitted: false,
        data: PartnerKycFormData(
          bankAccountHolder: _holderCtrl.text.trim(),
          bankName: _bankCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim().toUpperCase(),
          accountNumber: _accountCtrl.text.trim(),
          passbookDocUrl: passbookUrl,
        ),
      );

      await repo.setAccountStatus(
        callerId: user.id,
        partnerId: partnerId,
        status: 'pending',
      );

      if (mounted) {
        AppSnackBar.success(context, 'Account details saved');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
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
          maxWidth: 640,
          maxHeight: size.height * 0.88,
        ),
        child: Column(
          children: [
            _BankHeader(
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
                          child: PartnerFormSection(
                            title: 'Bank Account Details',
                            icon: Icons.account_balance_outlined,
                            children: [
                              PartnerFormField(
                                label: 'Account Holder Name',
                                icon: Icons.person_outline,
                                controller: _holderCtrl,
                                required: true,
                              ),
                              PartnerFormRow(
                                children: [
                                  PartnerFormField(
                                    label: 'Bank Name',
                                    icon: Icons.account_balance,
                                    controller: _bankCtrl,
                                    required: true,
                                  ),
                                  PartnerFormField(
                                    label: 'IFSC Code',
                                    icon: Icons.tag,
                                    controller: _ifscCtrl,
                                    required: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[A-Za-z0-9]'),
                                      ),
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'IFSC is required';
                                      }
                                      if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                          .hasMatch(v.trim().toUpperCase())) {
                                        return 'Invalid IFSC format';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              PartnerFormRow(
                                children: [
                                  PartnerFormField(
                                    label: 'Account Number',
                                    icon: Icons.numbers,
                                    controller: _accountCtrl,
                                    required: true,
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                  PartnerFormField(
                                    label: 'Confirm Account Number',
                                    icon: Icons.numbers,
                                    controller: _confirmAccountCtrl,
                                    required: true,
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) {
                                      if (v?.trim() !=
                                          _accountCtrl.text.trim()) {
                                        return 'Account numbers do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              KycDocumentUploadTile(
                                label: 'Bank Passbook / Cancelled Cheque',
                                icon: Icons.menu_book_outlined,
                                fileName: _passbookLabel,
                                hasFile: _hasPassbook,
                                onPick: _pickPassbook,
                                onView: _passbook.existingUrl != null
                                    ? () => _openUrl(_passbook.existingUrl!)
                                    : null,
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
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
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
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _submitting ? 'Saving...' : 'Save Account Details',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
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

class _BankHeader extends StatelessWidget {
  const _BankHeader({required this.partnerName, this.onClose});

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
              Icons.account_balance_wallet_outlined,
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
                  'Account Details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
