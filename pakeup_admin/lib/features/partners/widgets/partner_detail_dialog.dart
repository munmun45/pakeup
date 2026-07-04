import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/partners_repository.dart';
import '../providers/partners_provider.dart';
import 'partner_map_preview.dart';
import 'partner_table_widgets.dart';

class PartnerDetailDialog extends ConsumerWidget {
  const PartnerDetailDialog({
    super.key,
    required this.partner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final PartnerRecord partner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  String _display(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return 'Not provided';
    return v;
  }

  bool _has(String? value) => value?.trim().isNotEmpty == true;

  String get _cityLine {
    final parts = [partner.city, partner.state, partner.pincode]
        .where((e) => e?.trim().isNotEmpty == true)
        .join(', ');
    return parts.isEmpty ? 'Not provided' : parts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final size = MediaQuery.sizeOf(context);
    final accountsAsync = ref.watch(partnerOwnerAccountsListProvider);
    final linkedAccount = _linkedAccount(accountsAsync);
    final accountLoading =
        partner.accountId != null && accountsAsync.isLoading;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: size.height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailHeader(partner: partner),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 640;

                        final accountSection = _buildAccountSection(
                          dateFmt: dateFmt,
                          account: linkedAccount,
                          loading: accountLoading,
                        );

                        final storeSections = _buildStoreInfoSections(
                          dateFmt: dateFmt,
                        );
                        final locationSection = _buildLocationSection();

                        if (wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: partner.accountId != null
                                        ? accountSection
                                        : _buildNoAccountSection(),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: storeSections,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              locationSection,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (partner.accountId != null) ...[
                              accountSection,
                              const SizedBox(height: 14),
                            ] else ...[
                              _buildNoAccountSection(),
                              const SizedBox(height: 14),
                            ],
                            ...storeSections,
                            const SizedBox(height: 14),
                            locationSection,
                          ],
                        );
                      },
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
                    children: [
                      Icon(
                        partner.isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        size: 16,
                        color: partner.isActive
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        partner.isActive
                            ? 'Partner is live & visible'
                            : 'Partner is deactivated',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      PartnerDialogActionButton(
                        label: partner.isActive ? 'Deactivate' : 'Activate',
                        icon: partner.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        onPressed: onToggleActive,
                        variant: partner.isActive
                            ? PartnerDialogActionVariant.warning
                            : PartnerDialogActionVariant.success,
                      ),
                      const SizedBox(width: 8),
                      PartnerDialogActionButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: onEdit,
                        variant: PartnerDialogActionVariant.primary,
                      ),
                      const SizedBox(width: 8),
                      PartnerDialogActionButton(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        onPressed: onDelete,
                        variant: PartnerDialogActionVariant.danger,
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

  PartnerOwnerAccount? _linkedAccount(
    AsyncValue<List<PartnerOwnerAccount>> accountsAsync,
  ) {
    final accountId = partner.accountId;
    if (accountId == null) return null;

    return accountsAsync.maybeWhen(
      data: (accounts) {
        for (final account in accounts) {
          if (account.id == accountId) return account;
        }
        return null;
      },
      orElse: () => null,
    );
  }

  Widget _buildNoAccountSection() {
    return _DetailSection(
      icon: Icons.manage_accounts_outlined,
      title: 'Owner Info',
      children: const [
        Text(
          'No owner account linked to this store.',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStoreInfoSections({required DateFormat dateFmt}) {
    return [
      _DetailSection(
        icon: Icons.storefront_outlined,
        title: 'Store Info',
        children: [
          if (_has(partner.description))
            _InfoTile(
              icon: Icons.notes_outlined,
              label: 'About',
              value: partner.description!.trim(),
              fullWidth: true,
            ),
          _InfoTile(
            icon: Icons.category_outlined,
            label: 'Category',
            value: '',
            compact: true,
            customValue: PartnerCategoryBadge(label: partner.displayCategory),
          ),
          _InfoTile(
            icon: Icons.toggle_on_outlined,
            label: 'Store Status',
            value: '',
            compact: true,
            customValue: PartnerStatusBadge(isActive: partner.isActive),
          ),
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: 'KYC Status',
            value: '',
            compact: true,
            customValue: PartnerKycStatusBadge(status: partner.kycStatus),
          ),
          if (partner.createdAt != null)
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Added On',
              value: dateFmt.format(partner.createdAt!.toLocal()),
            ),
        ],
      ),
      const SizedBox(height: 14),
      _DetailSection(
        icon: Icons.contact_phone_outlined,
        title: 'Store Contact',
        children: [
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _display(partner.phone),
            muted: !_has(partner.phone),
          ),
          _InfoTile(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            value: _display(partner.whatsapp),
            muted: !_has(partner.whatsapp),
          ),
          if (_has(partner.alternatePhone))
            _InfoTile(
              icon: Icons.phone_callback_outlined,
              label: 'Alt. Phone',
              value: partner.alternatePhone!,
            ),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _display(partner.email),
            muted: !_has(partner.email),
          ),
          _InfoTile(
            icon: Icons.language_outlined,
            label: 'Website',
            value: _display(partner.website),
            muted: !_has(partner.website),
          ),
          _InfoTile(
            icon: Icons.receipt_long_outlined,
            label: 'GST Number',
            value: _display(partner.gstNumber),
            muted: !_has(partner.gstNumber),
          ),
        ],
      ),
      if (_has(partner.notes)) ...[
        const SizedBox(height: 14),
        _DetailSection(
          icon: Icons.sticky_note_2_outlined,
          title: 'Internal Notes',
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                partner.notes!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _buildLocationSection() {
    return _DetailSection(
      icon: Icons.location_on_outlined,
      title: 'Location',
      children: [
        _InfoTile(
          icon: Icons.place_outlined,
          label: 'Address',
          value: _display(partner.addressLine),
          muted: !_has(partner.addressLine),
          fullWidth: true,
        ),
        _InfoTile(
          icon: Icons.location_city_outlined,
          label: 'City / State / PIN',
          value: _cityLine,
          muted: _cityLine == 'Not provided',
        ),
        if (partner.latitude != null && partner.longitude != null)
          _InfoTile(
            icon: Icons.my_location_outlined,
            label: 'Coordinates',
            value:
                '${partner.latitude!.toStringAsFixed(6)}, ${partner.longitude!.toStringAsFixed(6)}',
          ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: PartnerMapPreview(
            googleMapEmbed: partner.googleMapEmbed,
            latitude: partner.latitude,
            longitude: partner.longitude,
            height: 180,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection({
    required DateFormat dateFmt,
    required PartnerOwnerAccount? account,
    required bool loading,
  }) {
    if (loading) {
      return _DetailSection(
        icon: Icons.manage_accounts_outlined,
        title: 'Owner Info',
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        ],
      );
    }

    if (account == null) {
      return _DetailSection(
        icon: Icons.manage_accounts_outlined,
        title: 'Owner Info',
        children: const [
          Text(
            'Linked account could not be loaded.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return _DetailSection(
      icon: Icons.manage_accounts_outlined,
      title: 'Owner Info',
      children: [
        _InfoTile(
          icon: Icons.person_outline_rounded,
          label: 'Owner Name',
          value: account.ownerName,
        ),
        _InfoTile(
          icon: Icons.phone_android_outlined,
          label: 'Login Phone',
          value: _display(account.phone),
          muted: !_has(account.phone),
        ),
        _InfoTile(
          icon: Icons.alternate_email_outlined,
          label: 'Login ID',
          value: _display(account.loginId ?? account.phone),
          muted: !_has(account.loginId) && !_has(account.phone),
        ),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _display(account.email),
          muted: !_has(account.email),
        ),
        _InfoTile(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          value: _display(account.whatsapp),
          muted: !_has(account.whatsapp),
        ),
        if (_has(account.alternatePhone))
          _InfoTile(
            icon: Icons.phone_callback_outlined,
            label: 'Alt. Phone',
            value: account.alternatePhone!,
          ),
        _InfoTile(
          icon: Icons.lock_outline_rounded,
          label: 'Password',
          value: '',
          compact: true,
          customValue: Text(
            account.hasPassword ? 'Set' : 'Not set',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  account.hasPassword ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
        _InfoTile(
          icon: Icons.store_mall_directory_outlined,
          label: 'Total Stores',
          value:
              '${account.storeCount} store${account.storeCount == 1 ? '' : 's'}',
          compact: true,
        ),
        _InfoTile(
          icon: Icons.toggle_on_outlined,
          label: 'Account Status',
          value: '',
          compact: true,
          customValue: PartnerStatusBadge(isActive: account.isActive),
        ),
        if (account.createdAt != null)
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Account Created',
            value: dateFmt.format(account.createdAt!.toLocal()),
          ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.partner});

  final PartnerRecord partner;

  @override
  Widget build(BuildContext context) {
    final initial = partner.businessName.isNotEmpty
        ? partner.businessName[0].toUpperCase()
        : 'P';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.secondary.withValues(alpha: 0.06),
            AppColors.surface,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        partner.ownerName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    PartnerCategoryBadge(label: partner.displayCategory),
                    PartnerStatusBadge(isActive: partner.isActive),
                    PartnerKycStatusBadge(status: partner.kycStatus),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.customValue,
    this.muted = false,
    this.fullWidth = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? customValue;
  final bool muted;
  final bool fullWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const Spacer(),
            if (customValue != null)
              customValue!
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  color: muted
                      ? AppColors.textSecondary.withValues(alpha: 0.65)
                      : AppColors.textPrimary,
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: fullWidth ? 10 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                if (customValue != null)
                  customValue!
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                      fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                      color: muted
                          ? AppColors.textSecondary.withValues(alpha: 0.65)
                          : AppColors.textPrimary,
                      height: 1.35,
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
