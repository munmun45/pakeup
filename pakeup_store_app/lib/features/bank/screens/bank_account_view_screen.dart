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
    final profileId = user?.profileId?.trim();
    final status = bankStatusInfo(_data?['account_status'] as String?);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BankPageAppBar(
        title: 'Bank Account',
        profileId: profileId,
        subtitle: 'Settlement details for your stores',
      ),
      bottomNavigationBar: _loading || !_showEditAction
          ? null
          : BankGradientButtonBar(
              label: _hasBankData ? 'Edit Bank Account' : 'Add Bank Account',
              icon: _hasBankData ? Icons.edit_rounded : Icons.add_rounded,
              onPressed: _openEdit,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pullToRefresh(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: alwaysScrollablePhysics,
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  _showEditAction ? 100 : 24,
                ),
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
                    if (!_hasBankData)
                      _EmptyBankCard(onAdd: _openEdit)
                    else ...[
                      if (_isApproved) ...[
                        _BankStatusBanner(
                          color: AppColors.success,
                          icon: Icons.verified_rounded,
                          message:
                              'Your bank account is approved. Details can no longer be edited.',
                        ),
                        const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
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
    );
  }
}

class _BankStatusBanner extends StatelessWidget {
  const _BankStatusBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add Bank Account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
