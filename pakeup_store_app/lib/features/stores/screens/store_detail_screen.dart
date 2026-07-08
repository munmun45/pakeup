import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/external_links.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/store_models.dart';
import '../models/store_schedule_models.dart';
import '../providers/stores_provider.dart';
import '../widgets/store_images_section.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          storeAsync.maybeWhen(
            data: (store) => IconButton(
              onPressed: () => context.push('/stores/${store.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit store',
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _HeaderCard(store: store),
              const SizedBox(height: 12),
              StoreImagesSection(
                store: store,
                onChanged: () =>
                    ref.invalidate(storeDetailProvider(widget.storeId)),
              ),
              const SizedBox(height: 12),
              _ActiveCard(
                store: store,
                loading: _togglingActive,
                onChanged: (v) => _toggleActive(store, v),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _Section(
                title: 'Business',
                icon: Icons.storefront_outlined,
                children: [
                  _InfoRow('Category', store.category.toUpperCase()),
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
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.textSecondary,
      side: const BorderSide(color: AppColors.primary),
      disabledBackgroundColor: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/kyc?storeId=$storeId'),
                  icon: const Icon(Icons.verified_user_outlined, size: 17),
                  label: const Text(
                    'KYC',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: buttonStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: kycApproved
                      ? () => context.push('/bank')
                      : () => _showKycRequired(context),
                  icon: Icon(
                    Icons.account_balance_outlined,
                    size: 17,
                    color: kycApproved
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  label: Text(
                    'Bank Account',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kycApproved
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  style: buttonStyle.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: kycApproved
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: kycApproved
                      ? () => context.go('/services?storeId=$storeId')
                      : () => _showKycRequired(context),
                  icon: Icon(
                    Icons.spa_outlined,
                    size: 17,
                    color: kycApproved
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  label: Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kycApproved
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  style: buttonStyle.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        color: kycApproved
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StoreAvatar(store: store),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.businessName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [store.city, store.state].whereType<String>().join(', ').isEmpty
                      ? 'No location set'
                      : [store.city, store.state]
                          .whereType<String>()
                          .join(', '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: store.kycLabel,
                      color: _kycColor,
                    ),
                    _Chip(
                      label: store.isActive ? 'Active' : 'Inactive',
                      color: store.isActive ? AppColors.success : AppColors.error,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Store Active',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          store.isActive
              ? 'Visible to customers'
              : 'Hidden from customers',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        value: store.isActive,
        onChanged: loading ? null : onChanged,
        activeThumbColor: AppColors.primary,
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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
                      : AppColors.primary,
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
      color: _tappable ? AppColors.primary : AppColors.textPrimary,
      decoration: _tappable ? TextDecoration.underline : null,
      decorationColor: _tappable ? AppColors.primary : null,
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

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        store.businessName.isNotEmpty
            ? store.businessName[0].toUpperCase()
            : 'S',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
