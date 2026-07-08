import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/partner_kyc_status.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authStateProvider).valueOrNull;
    final hasStores = ref.watch(hasStoresProvider);
    final stores = ref.watch(myStoresProvider).valueOrNull ?? const <StoreRecord>[];
    final kycStatus = PartnerKycStatus.resolve(
      stores: stores,
      accountStatus: partner?.kycStatus,
    );
    if (partner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pullToRefresh(
        onRefresh: () async {
          await ref.read(authStateProvider.notifier).refreshSession();
          ref.invalidate(myStoresProvider);
          await ref.read(myStoresProvider.future);
        },
        child: CustomScrollView(
          physics: alwaysScrollablePhysics,
          slivers: [
          // Gradient header
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          partner.businessName.isNotEmpty
                              ? partner.businessName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        partner.businessName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        partner.ownerName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KYC status
                  _KycStatusCard(status: kycStatus, hasStores: hasStores),
                  const SizedBox(height: 16),

                  // Business info (read-only)
                  _Section(
                    title: 'Business Info',
                    children: [
                      _InfoTile(
                        icon: Icons.storefront_rounded,
                        label: 'Business Name',
                        value: partner.businessName,
                        accent: AppColors.primary,
                      ),
                      _InfoTile(
                        icon: Icons.person_rounded,
                        label: 'Owner Name',
                        value: partner.ownerName,
                        accent: AppColors.secondary,
                      ),
                      _InfoTile(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: partner.category.toUpperCase(),
                        accent: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Contact details (editable)
                  _ContactSection(partner: partner),
                  const SizedBox(height: 12),

                  // Manage section
                  _Section(
                    title: 'Manage',
                    children: [
                      _ActionTile(
                        icon: Icons.storefront_rounded,
                        label: 'My Stores',
                        subtitle: 'View and manage your stores',
                        color: AppColors.primary,
                        onTap: () => context.push('/stores'),
                      ),
                      _ActionTile(
                        icon: Icons.verified_user_rounded,
                        label: 'KYC Documents',
                        subtitle: hasStores
                            ? 'Upload identity & business docs'
                            : 'Add a store first',
                        color: const Color(0xFF5C6BC0),
                        enabled: hasStores,
                        onTap: () => context.push('/kyc'),
                      ),
                      _ActionTile(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank Account',
                        subtitle: hasStores
                            ? 'Add your settlement account'
                            : 'Add a store first',
                        color: const Color(0xFF00897B),
                        enabled: hasStores,
                        onTap: () => context.push('/bank'),
                      ),
                      _ActionTile(
                        icon: Icons.inventory_2_rounded,
                        label: 'Inventory',
                        subtitle: hasStores
                            ? 'Manage weekly availability'
                            : 'Add a store first',
                        color: const Color(0xFFE65100),
                        enabled: hasStores,
                        onTap: () => context.push('/inventory'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Account
                  _Section(
                    title: 'Account',
                    children: [
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        subtitle: 'Log out from this device',
                        color: AppColors.error,
                        trailing: null,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                  'Are you sure you want to sign out?'),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(authStateProvider.notifier)
                                .logout();
                            ref.read(routerProvider).go('/login');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Contact editable section ────────────────────────────────────────────────

class _ContactSection extends ConsumerStatefulWidget {
  const _ContactSection({required this.partner});
  final dynamic partner;

  @override
  ConsumerState<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends ConsumerState<_ContactSection> {
  late final TextEditingController _wpCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _altCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wpCtrl =
        TextEditingController(text: widget.partner.whatsapp ?? '');
    _emailCtrl =
        TextEditingController(text: widget.partner.email ?? '');
    _altCtrl =
        TextEditingController(text: widget.partner.alternatePhone ?? '');
  }

  @override
  void dispose() {
    _wpCtrl.dispose();
    _emailCtrl.dispose();
    _altCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Save contact details — in production call the update RPC
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        AppSnackBar.success(context, 'Contact details saved!');
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    _wpCtrl.text = widget.partner.whatsapp ?? '';
    _emailCtrl.text = widget.partner.email ?? '';
    _altCtrl.text = widget.partner.alternatePhone ?? '';
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.partner.phone as String? ??
        widget.partner.loginId as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Text(
                'CONTACT DETAILS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!_editing)
                GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _editing
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
              width: _editing ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Phone (login ID) — always read-only
              _ContactRow(
                icon: Icons.phone_rounded,
                label: 'Mobile (Login ID)',
                iconColor: AppColors.primary,
                child: Text(
                  phone,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const _RowDivider(),

              // WhatsApp
              _ContactRow(
                icon: Icons.message_rounded,
                label: 'WhatsApp',
                iconColor: const Color(0xFF25D366),
                child: _editing
                    ? _PhoneInput(controller: _wpCtrl, hint: 'WhatsApp number')
                    : Text(
                        _wpCtrl.text.isEmpty ? 'Not added' : _wpCtrl.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _wpCtrl.text.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
              ),
              const _RowDivider(),

              // Email
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                iconColor: AppColors.secondary,
                child: _editing
                    ? TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(
                                color: AppColors.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                      )
                    : Text(
                        _emailCtrl.text.isEmpty ? 'Not added' : _emailCtrl.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _emailCtrl.text.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
              ),
              const _RowDivider(),

              // Alternate Phone
              _ContactRow(
                icon: Icons.phone_callback_rounded,
                label: 'Alternate Phone',
                iconColor: const Color(0xFF546E7A),
                child: _editing
                    ? _PhoneInput(
                        controller: _altCtrl, hint: 'Alternate number')
                    : Text(
                        _altCtrl.text.isEmpty ? 'Not added' : _altCtrl.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _altCtrl.text.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
              ),

              // Save / Cancel buttons when editing
              if (_editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.child,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneInput extends StatelessWidget {
  const _PhoneInput({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _KycStatusCard extends StatelessWidget {
  const _KycStatusCard({required this.status, required this.hasStores});
  final String status;
  final bool hasStores;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      'approved' => (AppColors.success, Icons.verified_rounded, 'KYC Approved'),
      'rejected' => (AppColors.error, Icons.cancel_rounded, 'KYC Rejected'),
      _ => (AppColors.warning, Icons.pending_rounded, 'KYC Pending'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          const Spacer(),
          if (status != 'approved' && hasStores)
            TextButton(
              onPressed: () => context.push('/kyc'),
              child: const Text('Upload Docs'),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.trailing = const Icon(Icons.arrow_forward_ios_rounded,
        size: 13, color: AppColors.textSecondary),
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? color : AppColors.textSecondary;
    return InkWell(
      onTap: enabled
          ? onTap
          : () => AppSnackBar.error(context, 'Add a store first'),
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        ),
      ),
    );
  }
}
