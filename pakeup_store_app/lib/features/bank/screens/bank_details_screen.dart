import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../kyc/widgets/kyc_form_sections.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/providers/stores_provider.dart';
import '../widgets/bank_shared_widgets.dart';

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _confirmAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  String _accountType = 'savings';
  bool _loading = false;
  bool _loadingData = true;
  bool _obscureAccount = true;
  bool _hasExistingData = false;
  String? _accountStatus;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass =
        await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (user == null || loginPass == null || loginPass.isEmpty) {
      if (mounted) setState(() => _loadingData = false);
      return;
    }

    try {
      final data = await ref.read(storesRepositoryProvider).getBankDetails(
            accountId: user.id,
            loginPass: loginPass,
          );
      if (data != null && mounted) {
        _accountNameCtrl.text = data['account_name'] as String? ?? '';
        _bankNameCtrl.text = data['bank_name'] as String? ?? '';
        _ifscCtrl.text = data['ifsc'] as String? ?? '';
        final acct = data['account_number'] as String? ?? '';
        _accountNumberCtrl.text = acct;
        _confirmAccountCtrl.text = acct;
        _upiCtrl.text = data['upi_id'] as String? ?? '';
        _accountType = data['account_type'] as String? ?? 'savings';
        _accountStatus = data['account_status'] as String?;
        _hasExistingData = _bankNameCtrl.text.trim().isNotEmpty ||
            acct.trim().isNotEmpty;

        if (_accountStatus == 'approved' && mounted) {
          AppSnackBar.warning(
            context,
            'Approved bank accounts cannot be edited.',
          );
          context.pop();
          return;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass =
        await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (user == null || loginPass == null || loginPass.isEmpty) return;

    setState(() => _loading = true);
    try {
      final wasUpdate = _hasExistingData;
      final repo = ref.read(storesRepositoryProvider);
      await repo.saveBankDetails(
        accountId: user.id,
        loginPass: loginPass,
        accountName: _accountNameCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        ifsc: _ifscCtrl.text.trim().toUpperCase(),
        bankName: _bankNameCtrl.text.trim(),
        accountType: _accountType,
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _accountStatus = 'pending';
          _hasExistingData = true;
        });
        AppSnackBar.success(
          context,
          wasUpdate
              ? 'Bank account updated successfully!'
              : 'Bank account saved successfully!',
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final status = bankStatusInfo(_accountStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_hasExistingData ? 'Edit Bank Account' : 'Add Bank Account'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      bottomNavigationBar: _loadingData
          ? null
          : _BankSubmitBar(
              loading: _loading,
              isUpdate: _hasExistingData,
              onSubmit: _submit,
            ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : ColoredBox(
              color: AppColors.background.withValues(alpha: 0.55),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BankInfoCard(
                        ownerName: user?.ownerName,
                        shortAccountId:
                            user != null ? shortPartnerId(user.id) : null,
                        statusLabel: status.label,
                        statusColor: status.color,
                      ),
                      const SizedBox(height: 12),
                      KycStepSection(
                        step: '1',
                        title: 'Bank Account',
                        subtitle: 'Account holder and bank details',
                        icon: Icons.account_balance_rounded,
                        required: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _accountNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Account Holder Name',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bankNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Bank Name',
                                prefixIcon:
                                    Icon(Icons.account_balance_rounded),
                              ),
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _accountNumberCtrl,
                              obscureText: _obscureAccount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Account Number',
                                prefixIcon:
                                    const Icon(Icons.credit_card_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureAccount
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureAccount = !_obscureAccount,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v?.trim().isEmpty == true) {
                                  return 'Required';
                                }
                                if (v!.trim().length < 9) {
                                  return 'Enter valid account number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmAccountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Confirm Account Number',
                                prefixIcon: Icon(Icons.credit_card_rounded),
                              ),
                              validator: (v) {
                                if (v?.trim().isEmpty == true) {
                                  return 'Required';
                                }
                                if (v != _accountNumberCtrl.text) {
                                  return 'Account numbers do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ifscCtrl,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                                LengthLimitingTextInputFormatter(11),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'IFSC Code',
                                prefixIcon: Icon(Icons.numbers_rounded),
                                helperText: 'e.g. SBIN0001234',
                              ),
                              validator: (v) {
                                if (v?.trim().isEmpty == true) {
                                  return 'Required';
                                }
                                if (v!.trim().length != 11) {
                                  return 'IFSC must be 11 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
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
                                for (final type in ['savings', 'current'])
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: type == 'savings' ? 6 : 0,
                                        left: type == 'current' ? 6 : 0,
                                      ),
                                      child: _AccountTypeChip(
                                        label: type[0].toUpperCase() +
                                            type.substring(1),
                                        selected: _accountType == type,
                                        onTap: () =>
                                            setState(() => _accountType = type),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      KycStepSection(
                        step: '2',
                        title: 'UPI',
                        subtitle: 'Optional — for faster settlements',
                        icon: Icons.phone_android_rounded,
                        child: TextFormField(
                          controller: _upiCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'UPI ID',
                            prefixIcon: Icon(Icons.payment_rounded),
                            helperText: 'e.g. yourname@ybl',
                          ),
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

class _AccountTypeChip extends StatelessWidget {
  const _AccountTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BankSubmitBar extends StatelessWidget {
  const _BankSubmitBar({
    required this.loading,
    required this.isUpdate,
    required this.onSubmit,
  });

  final bool loading;
  final bool isUpdate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isUpdate
                              ? Icons.save_rounded
                              : Icons.check_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isUpdate
                              ? 'Update Bank Account'
                              : 'Save Bank Account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
