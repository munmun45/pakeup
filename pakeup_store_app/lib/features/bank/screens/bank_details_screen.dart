import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../kyc/widgets/kyc_form_sections.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/providers/stores_provider.dart';
import '../../stores/widgets/store_form_fields.dart';
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
    final profileId = user?.profileId?.trim();
    final status = bankStatusInfo(_accountStatus);
    final title = _hasExistingData ? 'Edit Bank Account' : 'Add Bank Account';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BankPageAppBar(
        title: title,
        profileId: profileId,
        subtitle: 'Enter settlement account details',
      ),
      bottomNavigationBar: _loadingData
          ? null
          : BankGradientButtonBar(
              label: _hasExistingData
                  ? 'Update Bank Account'
                  : 'Save Bank Account',
              icon: _hasExistingData ? Icons.save_rounded : Icons.check_rounded,
              loading: _loading,
              onPressed: _submit,
            ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BankInfoCard(
                      ownerName: user?.ownerName,
                      profileId: profileId,
                      statusLabel: status.label,
                      statusColor: status.color,
                    ),
                    const SizedBox(height: 14),
                    KycStepSection(
                      step: '1',
                      title: 'Bank Account',
                      subtitle: 'Account holder and bank details',
                      icon: Icons.account_balance_rounded,
                      required: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StoreFormField(
                            controller: _accountNameCtrl,
                            label: 'Account Holder Name',
                            icon: Icons.person_rounded,
                            required: true,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          StoreFormField(
                            controller: _bankNameCtrl,
                            label: 'Bank Name',
                            icon: Icons.account_balance_rounded,
                            required: true,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          StoreFormField(
                            controller: _accountNumberCtrl,
                            label: 'Account Number',
                            icon: Icons.credit_card_rounded,
                            required: true,
                            keyboardType: TextInputType.number,
                            obscureText: _obscureAccount,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v?.trim().isEmpty == true) return 'Required';
                              if (v!.trim().length < 9) {
                                return 'Enter valid account number';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _obscureAccount = !_obscureAccount,
                              ),
                              icon: Icon(
                                _obscureAccount
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _obscureAccount ? 'Show number' : 'Hide number',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          StoreFormField(
                            controller: _confirmAccountCtrl,
                            label: 'Confirm Account Number',
                            icon: Icons.credit_card_rounded,
                            required: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v?.trim().isEmpty == true) return 'Required';
                              if (v != _accountNumberCtrl.text) {
                                return 'Account numbers do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          StoreFormField(
                            controller: _ifscCtrl,
                            label: 'IFSC Code',
                            icon: Icons.numbers_rounded,
                            required: true,
                            hint: 'SBIN0001234',
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: (v) {
                              if (v?.trim().isEmpty == true) return 'Required';
                              if (v!.trim().length != 11) {
                                return 'IFSC must be 11 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          const StoreFieldLabel(
                            label: 'Account Type',
                            icon: Icons.savings_outlined,
                            required: true,
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
                    const SizedBox(height: 14),
                    KycStepSection(
                      step: '2',
                      title: 'UPI',
                      subtitle: 'Optional — for faster settlements',
                      icon: Icons.phone_android_rounded,
                      child: StoreFormField(
                        controller: _upiCtrl,
                        label: 'UPI ID',
                        icon: Icons.payment_rounded,
                        hint: 'yourname@ybl',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
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
                : AppColors.background,
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
