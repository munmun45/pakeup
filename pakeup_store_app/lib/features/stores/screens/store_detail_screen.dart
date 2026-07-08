import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/external_links.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../models/store_models.dart';
import '../models/store_schedule_models.dart';
import '../providers/stores_provider.dart';
import '../widgets/store_images_section.dart';

const _storeHeaderGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
);

class StoreDetailScreen extends ConsumerStatefulWidget {
  const StoreDetailScreen({super.key, required this.storeId});

  final String storeId;

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  bool _togglingActive = false;

  Future<void> _toggleActive(StoreRecord store, bool active) async {
    if (!active) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate store?'),
          content: const Text(
            'Customers will not see this store while it is inactive. '
            'You can activate it again anytime.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    final loginPass = await ref.read(authRepositoryProvider).getStoredLoginPass();
    if (!mounted) return;
    if (user == null || loginPass == null || loginPass.isEmpty) {
      AppSnackBar.error(context, 'Session expired. Please log in again.');
      return;
    }

    setState(() => _togglingActive = true);
    try {
      await ref.read(storesRepositoryProvider).setStoreActive(
            accountId: user.id,
            loginPass: loginPass,
            storeId: store.id,
            active: active,
          );
      ref.invalidate(myStoresProvider);
      ref.invalidate(storeDetailProvider(widget.storeId));
      if (mounted) {
        AppSnackBar.success(
          context,
          active ? 'Store activated' : 'Store deactivated',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to update status: $e');
    } finally {
      if (mounted) setState(() => _togglingActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailProvider(widget.storeId));
    final partner = ref.watch(authStateProvider).valueOrNull;
    final profileId = partner?.profileId?.trim();

    return PageScaffold(
      appBar: storeAsync.maybeWhen(
        data: (store) => _StoreDetailAppBar(
          profileId: profileId,
          onEdit: () => context.push('/stores/${store.id}/edit'),
        ),
        orElse: () => _StoreDetailAppBar(profileId: profileId),
      ),
      bottomNavigationBar: storeAsync.maybeWhen(
        data: (store) => _StoreActionBar(
          storeId: store.id,
          kycApproved: store.isKycApproved,
        ),
        orElse: () => null,
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(storeDetailProvider(widget.storeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (store) => pullToRefresh(
          onRefresh: () async {
            ref.invalidate(storeDetailProvider(widget.storeId));
            await ref.read(storeDetailProvider(widget.storeId).future);
          },
          child: ListView(
            physics: alwaysScrollablePhysics,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _HeaderCard(store: store),
              const SizedBox(height: 14),
              StoreImagesSection(
                store: store,
                onChanged: () =>
                    ref.invalidate(storeDetailProvider(widget.storeId)),
              ),
              const SizedBox(height: 14),
              _DetailSurface(
                child: _ActiveCard(
                  store: store,
                  loading: _togglingActive,
                  onChanged: (v) => _toggleActive(store, v),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Contact',
                icon: Icons.badge_outlined,
                children: [
                  _InfoRow(
                    'Phone',
                    store.phone ?? '—',
                    onTap: store.phone != null
                        ? () => _openPhone(context, store.phone!)
                        : null,
                  ),
                  _InfoRow(
                    'WhatsApp',
                    store.whatsapp ?? '—',
                    onTap: store.whatsapp != null
                        ? () => _openWhatsApp(context, store.whatsapp!)
                        : null,
                  ),
                  if (store.email != null)
                    _InfoRow(
                      'Email',
                      store.email!,
                      onTap: () => _openEmail(context, store.email!),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Owner Details',
                icon: Icons.person_outline_rounded,
                children: [
                  _InfoRow(
                    'Owner Name',
                    store.ownerName.isNotEmpty
                        ? store.ownerName
                        : (partner?.ownerName ?? '—'),
                  ),
                  if (partner?.phone != null && partner!.phone!.isNotEmpty)
                    _InfoRow(
                      'Login Phone',
                      partner.phone!,
                      onTap: () => _openPhone(context, partner.phone!),
                    ),
                  if (partner?.email != null && partner!.email!.isNotEmpty)
                    _InfoRow(
                      'Email',
                      partner.email!,
                      onTap: () => _openEmail(context, partner.email!),
                    ),
                  if (partner?.whatsapp != null && partner!.whatsapp!.isNotEmpty)
                    _InfoRow(
                      'WhatsApp',
                      partner.whatsapp!,
                      onTap: () => _openWhatsApp(context, partner.whatsapp!),
                    ),
                  if (_altPhone(store, partner) != null)
                    _InfoRow(
                      'Alt. Phone',
                      _altPhone(store, partner)!,
                      onTap: () => _openPhone(context, _altPhone(store, partner)!),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Location',
                icon: Icons.location_on_outlined,
                children: [
                  _InfoRow(
                    'Address',
                    store.address ?? '—',
                    onTap: _hasMapTarget(store)
                        ? () => _openMaps(context, store)
                        : null,
                  ),
                  _InfoRow('City', store.city ?? '—'),
                  _InfoRow('State', store.state ?? '—'),
                  _InfoRow('Pincode', store.pincode ?? '—'),
                  if (store.latitude != null && store.longitude != null)
                    _InfoRow(
                      'Coordinates',
                      '${store.latitude!.toStringAsFixed(5)}, '
                      '${store.longitude!.toStringAsFixed(5)}',
                      onTap: () => _openMaps(context, store),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Business',
                icon: Icons.storefront_outlined,
                children: [
                  _InfoRow('Category', store.categoryLabel),
                  if (store.description != null && store.description!.isNotEmpty)
                    _InfoRow('Description', store.description!),
                ],
              ),
              const SizedBox(height: 12),
              _OpeningHoursSection(
                schedules: store.schedules.isEmpty
                    ? DaySchedule.defaults()
                    : store.schedules,
              ),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }

  String? _altPhone(StoreRecord store, PartnerUser? partner) {
    final storeAlt = store.alternatePhone?.trim();
    if (storeAlt != null && storeAlt.isNotEmpty) return storeAlt;
    final partnerAlt = partner?.alternatePhone?.trim();
    if (partnerAlt != null && partnerAlt.isNotEmpty) return partnerAlt;
    return null;
  }

  bool _hasMapTarget(StoreRecord store) {
    if (store.latitude != null && store.longitude != null) return true;
    final address = _fullAddress(store);
    return address != null;
  }

  String? _fullAddress(StoreRecord store) {
    final parts = [
      store.address,
      store.city,
      store.state,
      store.pincode,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<void> _launchLink(
    BuildContext context,
    Future<bool> Function() action,
    String failMessage,
  ) async {
    try {
      final opened = await action();
      if (!context.mounted) return;
      if (!opened) AppSnackBar.error(context, failMessage);
    } catch (_) {
      if (context.mounted) AppSnackBar.error(context, failMessage);
    }
  }

  Future<void> _openPhone(BuildContext context, String phone) {
    return _launchLink(
      context,
      () => ExternalLinks.openPhone(phone),
      'Could not open phone dialer',
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String whatsapp) {
    return _launchLink(
      context,
      () => ExternalLinks.openWhatsApp(whatsapp),
      'Could not open WhatsApp',
    );
  }

  Future<void> _openEmail(BuildContext context, String email) {
    return _launchLink(
      context,
      () => ExternalLinks.openEmail(email),
      'Could not open email app',
    );
  }

  Future<void> _openMaps(BuildContext context, StoreRecord store) {
    return _launchLink(
      context,
      () => ExternalLinks.openMaps(
        address: _fullAddress(store),
        latitude: store.latitude,
        longitude: store.longitude,
      ),
      'Could not open Google Maps',
    );
  }
}

class _StoreDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StoreDetailAppBar({this.profileId, this.onEdit});

  final String? profileId;
  final VoidCallback? onEdit;

  @override
  Size get preferredSize {
    final hasId = profileId?.trim().isNotEmpty == true;
    return Size.fromHeight(hasId ? 56 : kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final id = profileId?.trim();

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      toolbarHeight: preferredSize.height,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Store Details',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          if (id != null && id.isNotEmpty)
            Text(
              'Profile ID: $id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit store',
          ),
      ],
    );
  }
}

class _DetailSurface extends StatelessWidget {
  const _DetailSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _StoreActionBar extends StatelessWidget {
  const _StoreActionBar({
    required this.storeId,
    required this.kycApproved,
  });

  final String storeId;
  final bool kycApproved;

  void _showKycRequired(BuildContext context) {
    AppSnackBar.warning(
      context,
      'Complete KYC verification to access this feature.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'KYC',
                  icon: Icons.verified_user_outlined,
                  enabled: true,
                  onPressed: () => context.push('/kyc?storeId=$storeId'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Bank Account',
                  icon: Icons.account_balance_outlined,
                  enabled: kycApproved,
                  onPressed: kycApproved
                      ? () => context.push('/bank')
                      : () => _showKycRequired(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Services',
                  icon: Icons.spa_outlined,
                  enabled: kycApproved,
                  onPressed: kycApproved
                      ? () => context.go('/services?storeId=$storeId')
                      : () => _showKycRequired(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.background,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: tint),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tint,
                    height: 1.1,
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.store});
  final StoreRecord store;

  Color get _kycColor => switch (store.kycStatus) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              gradient: _storeHeaderGradient,
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                _StoreAvatar(store: store),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.businessName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.categoryLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        store.addressLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                if (store.phone?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          store.phone!.trim(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: Icons.spa_outlined,
                      label: '${store.serviceCount} services',
                    ),
                    _Chip(
                      icon: Icons.verified_outlined,
                      label: store.kycLabel,
                      color: _kycColor,
                    ),
                    _Chip(
                      icon: Icons.circle,
                      label: store.isActive ? 'Active' : 'Inactive',
                      color: store.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      iconSize: 7,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.store,
    required this.loading,
    required this.onChanged,
  });

  final StoreRecord store;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: const Text(
        'Store Active',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      subtitle: Text(
        store.isActive
            ? 'Visible to customers'
            : 'Hidden from customers',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      value: store.isActive,
      onChanged: loading ? null : onChanged,
      activeThumbColor: const Color(0xFF1565C0),
      activeTrackColor: const Color(0xFF1565C0).withValues(alpha: 0.35),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OpeningHoursSection extends StatelessWidget {
  const _OpeningHoursSection({required this.schedules});

  final List<DaySchedule> schedules;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Opening Hours',
      icon: Icons.access_time_rounded,
      children: [
        for (var i = 0; i < schedules.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    schedules[i].dayShortLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    schedules[i].summary,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: schedules[i].isClosed
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  schedules[i].isClosed
                      ? Icons.block_rounded
                      : Icons.schedule_rounded,
                  size: 16,
                  color: schedules[i].isClosed
                      ? AppColors.error
                      : const Color(0xFF1565C0),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  bool get _isPlaceholder => value.trim().isEmpty || value == '—';
  bool get _tappable => onTap != null && !_isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: _tappable ? const Color(0xFF1565C0) : AppColors.textPrimary,
      decoration: _tappable ? TextDecoration.underline : null,
      decorationColor: _tappable ? const Color(0xFF1565C0) : null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _tappable
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Text(value, style: valueStyle),
                  )
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.store});
  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
    final imageUrl = store.primaryImage ??
        (store.images.isNotEmpty ? store.images.first : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 54,
        height: 54,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.22),
      child: Center(
        child: Text(
          store.businessName.isNotEmpty
              ? store.businessName[0].toUpperCase()
              : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.color,
    this.iconSize = 12,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
