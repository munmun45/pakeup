import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/premium_card.dart';
import '../models/store_models.dart';
import '../providers/stores_provider.dart';

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);
    final profileId = ref.watch(authStateProvider).valueOrNull?.profileId?.trim();

    return PageScaffold(
      appBar: _StoresAppBar(profileId: profileId),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/stores/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Store'),
      ),
      body: storesAsync.when(
        loading: () => const LoadingState(message: 'Loading stores...'),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myStoresProvider),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return pullToRefreshBox(
              onRefresh: () async {
                ref.invalidate(myStoresProvider);
                await ref.read(myStoresProvider.future);
              },
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              child: Center(
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No stores yet',
                  message: 'Add your first store to get started.',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push('/stores/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Store'),
                  ),
                ),
              ),
            );
          }

          final activeCount = stores.where((s) => s.isActive).length;
          final approvedCount = stores.where((s) => s.isKycApproved).length;

          return pullToRefresh(
            onRefresh: () async {
              ref.invalidate(myStoresProvider);
              await ref.read(myStoresProvider.future);
            },
            child: ListView(
              physics: alwaysScrollablePhysics,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                12,
                AppSpacing.pageHorizontal,
                AppSpacing.pageBottom,
              ),
              children: [
                _StoresSummaryStrip(
                  total: stores.length,
                  active: activeCount,
                  approved: approvedCount,
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < stores.length; i++) ...[
                  _StoreCard(store: stores[i]),
                  if (i < stores.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoresAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StoresAppBar({this.profileId});

  final String? profileId;

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
            'My Stores',
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
    );
  }
}

class _StoresSummaryStrip extends StatelessWidget {
  const _StoresSummaryStrip({
    required this.total,
    required this.active,
    required this.approved,
  });

  final int total;
  final int active;
  final int approved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            icon: Icons.storefront_rounded,
            label: 'Total',
            value: '$total',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.bolt_rounded,
            label: 'Active',
            value: '$active',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.verified_rounded,
            label: 'Approved',
            value: '$approved',
            color: const Color(0xFF1976D2),
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      compact: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      accentColor: color,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final StoreRecord store;

  String? get _contact =>
      store.phone?.trim().isNotEmpty == true
          ? store.phone!.trim()
          : store.whatsapp?.trim().isNotEmpty == true
              ? store.whatsapp!.trim()
              : null;

  String get _kycLabel => switch (store.kycStatus) {
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };

  Color get _kycColor => switch (store.kycStatus) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final dateLabel = store.createdAt != null
        ? DateFormat('dd MMM yyyy').format(store.createdAt!.toLocal())
        : null;
    final location = store.addressLabel;
    final contact = _contact;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/stores/${store.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF0D47A1),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _StoreImage(
                      url: store.primaryImage,
                      name: store.businessName,
                      size: 46,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            store.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            store.categoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ],
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompactLine(
                        icon: Icons.location_on_outlined,
                        text: location,
                        maxLines: 3,
                      ),
                      if (contact != null) ...[
                        const SizedBox(height: 5),
                        _CompactLine(
                          icon: Icons.phone_outlined,
                          text: contact,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StoreChip(
                            icon: Icons.spa_outlined,
                            label: '${store.serviceCount} svc',
                          ),
                          if (dateLabel != null)
                            _StoreChip(
                              icon: Icons.calendar_today_outlined,
                              label: dateLabel,
                            ),
                          _StoreChip(
                            icon: Icons.verified_outlined,
                            label: 'KYC $_kycLabel',
                            color: _kycColor,
                          ),
                          _StoreChip(
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
          ),
        ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  const _StoreImage({
    required this.url,
    required this.name,
    this.size = 50,
  });

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
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
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({
    required this.icon,
    required this.label,
    this.color,
    this.iconSize = 12,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({
    required this.icon,
    required this.text,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
