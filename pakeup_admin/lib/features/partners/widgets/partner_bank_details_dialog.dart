import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/partner_kyc_models.dart';
import '../providers/partner_kyc_provider.dart';
import '../utils/kyc_document_limits.dart';
import 'kyc_document_upload_tile.dart';
import 'partner_form_field.dart';

class PartnerBankDetailsDialog extends ConsumerStatefulWidget {
  const PartnerBankDetailsDialog({super.key, required this.account});

  final PartnerAccountRecord account;

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
  late final TextEditingController _upiCtrl;

  final _LocalDoc _passbook = _LocalDoc();
  String _accountType = 'savings';
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
    _upiCtrl = TextEditingController();
    _applyAccountData(widget.account);
    _loadExisting();
  }

  void _applyAccountData(PartnerAccountRecord account) {
    _holderCtrl.text = account.bankAccountHolder ?? '';
    _bankCtrl.text = account.bankName ?? '';
    _ifscCtrl.text = account.ifscCode ?? '';
    _accountCtrl.text = account.accountNumber ?? '';
    _confirmAccountCtrl.text = _accountCtrl.text;
    _upiCtrl.text = account.upiId ?? '';
    _accountType = account.accountType ?? 'savings';
    _passbook.existingUrl = account.passbookDocUrl;
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final bank = await ref.read(partnerKycRepositoryProvider).getBankAccount(
            callerId: user.id,
            accountId: widget.account.accountId,
          );
      if (!mounted) return;

      if (bank != null) {
        _holderCtrl.text = bank.bankAccountHolder ?? _holderCtrl.text;
        _bankCtrl.text = bank.bankName ?? _bankCtrl.text;
        _ifscCtrl.text = bank.ifscCode ?? _ifscCtrl.text;
        _accountCtrl.text = bank.accountNumber ?? _accountCtrl.text;
        _confirmAccountCtrl.text = _accountCtrl.text;
        _upiCtrl.text = bank.upiId ?? _upiCtrl.text;
        _accountType = bank.accountType ?? _accountType;
        _passbook.existingUrl = bank.passbookDocUrl ?? _passbook.existingUrl;
      }
    } catch (_) {
      // Keep values already loaded from widget.account.
    }

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
      _upiCtrl,
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

    const type = KycDocType.passbook;
    final size = file.size;
    if (size > 0) {
      final error = KycDocumentLimits.validateBytes(size, type);
      if (error != null) {
        setState(() => _passbook.errorMessage = error);
        return;
      }
    } else {
      final error = await KycDocumentLimits.validatePath(file.path!, type);
      if (error != null) {
        setState(() => _passbook.errorMessage = error);
        return;
      }
    }

    setState(() {
      _passbook
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

  bool get _hasPassbook =>
      _passbook.localPath != null || _passbook.existingUrl != null;

  String? get _passbookLabel =>
      _passbook.localName ??
      (_passbook.existingUrl != null ? 'Uploaded document' : null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasPassbook) {
      setState(() {
        _passbook.errorMessage =
            'Please upload bank passbook or cancelled cheque';
      });
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again');
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(partnerKycRepositoryProvider);
      final accountId = widget.account.accountId;

      String? passbookUrl = _passbook.existingUrl;
      if (_passbook.localPath != null) {
        passbookUrl = await repo.uploadBankDocument(
          accountId: accountId,
          docType: KycDocType.passbook,
          localPath: _passbook.localPath!,
        );
      }

      await repo.saveBankAccount(
        callerId: user.id,
        accountId: accountId,
        bankAccountHolder: _holderCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        accountNumber: _accountCtrl.text.trim(),
        passbookDocUrl: passbookUrl,
        accountType: _accountType,
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
      );

      await repo.setAccountStatus(
        callerId: user.id,
        accountId: accountId,
        status: 'pending',
      );

      if (mounted) {
        AppSnackBar.success(context, 'Account details saved successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(context, 'save account details', e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final initial = widget.account.ownerName.isNotEmpty
        ? widget.account.ownerName[0].toUpperCase()
        : 'P';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                              'Bank Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${widget.account.ownerName} · ID ${widget.account.shortAccountId}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasPassbook)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 13,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Doc uploaded',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : ColoredBox(
                          color: AppColors.background.withValues(alpha: 0.45),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _BankSection(
                                    step: '1',
                                    title: 'Bank Account',
                                    subtitle: 'Account holder and bank details',
                                    icon: Icons.account_balance_outlined,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                                FilteringTextInputFormatter
                                                    .allow(
                                                  RegExp(r'[A-Za-z0-9]'),
                                                ),
                                                LengthLimitingTextInputFormatter(
                                                  11,
                                                ),
                                              ],
                                              validator: (v) {
                                                if (v == null ||
                                                    v.trim().isEmpty) {
                                                  return 'IFSC is required';
                                                }
                                                if (!RegExp(
                                                  r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                                ).hasMatch(
                                                  v.trim().toUpperCase(),
                                                )) {
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
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                            ),
                                            PartnerFormField(
                                              label: 'Confirm Account Number',
                                              icon: Icons.numbers,
                                              controller: _confirmAccountCtrl,
                                              required: true,
                                              keyboard: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
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
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Account Type',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            for (final type
                                                in ['savings', 'current'])
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: type == 'savings'
                                                        ? 6
                                                        : 0,
                                                    left: type == 'current'
                                                        ? 6
                                                        : 0,
                                                  ),
                                                  child: GestureDetector(
                                                    onTap: () => setState(
                                                      () => _accountType = type,
                                                    ),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 150,
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 10,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _accountType ==
                                                                type
                                                            ? AppColors.primary
                                                                .withValues(
                                                              alpha: 0.1,
                                                            )
                                                            : AppColors.surface,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                          color: _accountType ==
                                                                  type
                                                              ? AppColors
                                                                  .primary
                                                              : AppColors.border,
                                                          width: _accountType ==
                                                                  type
                                                              ? 2
                                                              : 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        type[0].toUpperCase() +
                                                            type.substring(1),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12.5,
                                                          color: _accountType ==
                                                                  type
                                                              ? AppColors
                                                                  .primary
                                                              : AppColors
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        PartnerFormField(
                                          label: 'UPI ID (Optional)',
                                          icon: Icons.payment_rounded,
                                          controller: _upiCtrl,
                                          keyboard:
                                              TextInputType.emailAddress,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _BankSection(
                                    step: '2',
                                    title: 'Passbook Document',
                                    subtitle:
                                        'Upload passbook or cancelled cheque',
                                    icon: Icons.menu_book_outlined,
                                    child: KycDocumentUploadTile(
                                      label:
                                          'Bank Passbook / Cancelled Cheque',
                                      icon: Icons.menu_book_outlined,
                                      fileName: _passbookLabel,
                                      hasFile: _hasPassbook,
                                      sizeHint: KycDocumentLimits.uploadHint(
                                        KycDocType.passbook,
                                      ),
                                      errorText: _passbook.errorMessage,
                                      onPick: _pickPassbook,
                                      onView: _passbook.existingUrl != null
                                          ? () => _openUrl(
                                                _passbook.existingUrl!,
                                              )
                                          : null,
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
                        KycDocumentLimits.uploadHint(KycDocType.passbook),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const Spacer(),
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
                          _submitting
                              ? 'Saving...'
                              : (widget.account.hasBankDetails
                                  ? 'Update Account Details'
                                  : 'Save Account Details'),
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

class _BankSection extends StatelessWidget {
  const _BankSection({
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
              Icon(
                icon,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
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
