import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../auth/providers/auth_provider.dart';
import '../../kyc/widgets/kyc_form_sections.dart';
import '../../stores/providers/stores_provider.dart';
import '../widgets/bank_shared_widgets.dart';

class BankAccountViewScreen extends ConsumerStatefulWidget {
  const BankAccountViewScreen({super.key});

  @override
  ConsumerState<BankAccountViewScreen> createState() =>
      _BankAccountViewScreenState();
}

class _BankAccountViewScreenState extends ConsumerState<BankAccountViewScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass =
        await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (user == null || loginPass == null || loginPass.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final data = await ref.read(storesRepositoryProvider).getBankDetails(
            accountId: user.id,
            loginPass: loginPass,
          );
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _data = null);
    }

    if (mounted) setState(() => _loading = false);
  }

  bool get _hasBankData {
    if (_data == null) return false;
    final bank = _data!['bank_name'] as String? ?? '';
    final acct = _data!['account_number'] as String? ?? '';
    return bank.trim().isNotEmpty || acct.trim().isNotEmpty;
  }

  bool get _isApproved => _data?['account_status'] == 'approved';

  bool get _showEditAction => !_isApproved;

  Future<void> _openEdit() async {
    final saved = await context.push<bool>('/bank/edit');
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final status = bankStatusInfo(_data?['account_status'] as String?);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bank Account'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      bottomNavigationBar: _loading || !_showEditAction
          ? null
          : _BankActionBar(
              hasData: _hasBankData,
              onPressed: _openEdit,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pullToRefresh(
              onRefresh: _load,
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.55),
                child: SingleChildScrollView(
                  physics: alwaysScrollablePhysics,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    _showEditAction ? 108 : 24,
                  ),
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
                    if (!_hasBankData)
                      _EmptyBankCard(onAdd: _openEdit)
                    else ...[
                      if (_isApproved) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: AppColors.success,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your bank account is approved. Details can no longer be edited.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      KycStepSection(
                        step: '1',
                        title: 'Bank Account',
                        subtitle: 'Settlement account details',
                        icon: Icons.account_balance_rounded,
                        child: Column(
                          children: [
                            BankDetailRow(
                              icon: Icons.person_rounded,
                              label: 'Account Holder Name',
                              value: _data!['account_name'] as String? ?? '',
                            ),
                            BankDetailRow(
                              icon: Icons.account_balance_rounded,
                              label: 'Bank Name',
                              value: _data!['bank_name'] as String? ?? '',
                            ),
                            BankDetailRow(
                              icon: Icons.credit_card_rounded,
                              label: 'Account Number',
                              value: maskAccountNumber(
                                _data!['account_number'] as String?,
                              ),
                            ),
                            BankDetailRow(
                              icon: Icons.numbers_rounded,
                              label: 'IFSC Code',
                              value: _data!['ifsc'] as String? ?? '',
                            ),
                            BankDetailRow(
                              icon: Icons.savings_outlined,
                              label: 'Account Type',
                              value: formatAccountType(
                                _data!['account_type'] as String?,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      KycStepSection(
                        step: '2',
                        title: 'UPI',
                        subtitle: 'Optional payment ID',
                        icon: Icons.phone_android_rounded,
                        child: BankDetailRow(
                          icon: Icons.payment_rounded,
                          label: 'UPI ID',
                          value: _data!['upi_id'] as String? ?? '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
    );
  }
}

class _EmptyBankCard extends StatelessWidget {
  const _EmptyBankCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No bank account added',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your bank details to receive settlements from all stores.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Bank Account'),
          ),
        ],
      ),
    );
  }
}

class _BankActionBar extends StatelessWidget {
  const _BankActionBar({
    required this.hasData,
    required this.onPressed,
  });

  final bool hasData;
  final VoidCallback onPressed;

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
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasData ? Icons.edit_rounded : Icons.add_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasData ? 'Edit Bank Account' : 'Add Bank Account',
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
