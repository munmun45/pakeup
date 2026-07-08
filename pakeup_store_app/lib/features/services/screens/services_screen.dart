import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../models/service_models.dart';
import '../providers/services_provider.dart';
import 'add_service_screen.dart';
import 'edit_service_screen.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.storeId});
  final String? storeId;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String? _selectedStoreId;
  bool _showStorePicker = true;

  @override
  void initState() {
    super.initState();
    if (widget.storeId != null) {
      _selectedStoreId = widget.storeId;
      _showStorePicker = false;
    }
  }

  void _onStoreSelected(StoreRecord store) {
    if (!store.isKycApproved) {
      AppSnackBar.warning(
        context,
        'Services are available only after KYC is approved.',
      );
      return;
    }
    setState(() {
      _selectedStoreId = store.id;
      _showStorePicker = false;
    });
    ref.invalidate(storeServicesProvider(store.id));
  }

  void _backToStoreList() {
    setState(() {
      _showStorePicker = true;
      _selectedStoreId = null;
    });
  }

  StoreRecord? _findStore(List<StoreRecord> stores, String? id) {
    if (id == null) return null;
    for (final s in stores) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<StoreRecord> _sortedStores(List<StoreRecord> stores) {
    final copy = [...stores];
    copy.sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return a.businessName.compareTo(b.businessName);
    });
    return copy;
  }

  Future<void> _refreshPage() async {
    ref.invalidate(myStoresProvider);
    await ref.read(myStoresProvider.future);
    final storeId = _selectedStoreId;
    if (storeId != null) {
      ref.invalidate(storeServicesProvider(storeId));
      await ref.read(storeServicesProvider(storeId).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);

    return storesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('My Services')),
        body: _ErrorBody(
          message: '$e',
          onRetry: () => ref.invalidate(myStoresProvider),
        ),
      ),
      data: (stores) {
        final sortedStores = _sortedStores(stores);
        final showStoreList =
            _showStorePicker || _selectedStoreId == null || stores.isEmpty;
        final selectedStore = _findStore(stores, _selectedStoreId);

        if (_selectedStoreId != null &&
            selectedStore != null &&
            !selectedStore.isKycApproved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _backToStoreList();
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              showStoreList
                  ? 'My Services'
                  : selectedStore?.businessName ?? 'My Services',
            ),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: !showStoreList && widget.storeId == null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _backToStoreList,
                  )
                : null,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.border),
            ),
          ),
          floatingActionButton: !showStoreList && selectedStore != null
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final added = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddServiceScreen(initialStore: selectedStore),
                      ),
                    );
                    if (added == true) {
                      ref.invalidate(storeServicesProvider(selectedStore.id));
                    }
                  },
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Add Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
          body: showStoreList
              ? pullToRefresh(
                  onRefresh: _refreshPage,
                  child: _ServicesStoreList(
                    stores: sortedStores,
                    onSelectStore: _onStoreSelected,
                  ),
                )
              : selectedStore == null
                  ? pullToRefresh(
                      onRefresh: _refreshPage,
                      child: _ServicesStoreList(
                        stores: sortedStores,
                        onSelectStore: _onStoreSelected,
                      ),
                    )
                  : _ServicesForStore(
                      store: selectedStore,
                      onRefresh: _refreshPage,
                    ),
        );
      },
    );
  }
}

// ─── Store picker list ─────────────────────────────────────────────────────────

class _ServicesStoreList extends StatelessWidget {
  const _ServicesStoreList({
    required this.stores,
    required this.onSelectStore,
  });

  final List<StoreRecord> stores;
  final ValueChanged<StoreRecord> onSelectStore;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return ListView(
        physics: alwaysScrollablePhysics,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(
                Icons.add_business_rounded,
                size: 72,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No stores yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a store first to manage its services.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final approvedCount = stores.where((s) => s.isKycApproved).length;

    return ListView(
      physics: alwaysScrollablePhysics,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          approvedCount == 0
              ? 'Complete KYC to manage services'
              : 'Select a store to manage services',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...stores.map(
          (store) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ServicesStorePickerCard(
              store: store,
              onTap: () => onSelectStore(store),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicesStorePickerCard extends ConsumerWidget {
  const _ServicesStorePickerCard({
    required this.store,
    required this.onTap,
  });

  final StoreRecord store;
  final VoidCallback onTap;

  Color get _kycColor => switch (store.kycStatus) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(storeServicesProvider(store.id));
    final serviceCount = servicesAsync.valueOrNull?.length ?? store.serviceCount;
    final canOpen = store.isKycApproved;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: canOpen
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Opacity(
            opacity: canOpen ? 1 : 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: store.primaryImage?.trim().isNotEmpty ==
                                true
                            ? NetworkImage(store.primaryImage!.trim())
                            : null,
                        child: store.primaryImage?.trim().isNotEmpty == true
                            ? null
                            : Text(
                                store.businessName.isNotEmpty
                                    ? store.businessName[0].toUpperCase()
                                    : 'S',
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
                            Text(
                              store.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              store.ownerName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    store.addressLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _kycColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _kycColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          store.kycLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kycColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 15,
                        color: canOpen
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        servicesAsync.isLoading
                            ? 'Loading services...'
                            : '$serviceCount service${serviceCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: canOpen
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (canOpen)
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.primary,
                        )
                      else
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.warning,
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
// ─── Services list for selected store ─────────────────────────────────────────

class _ServicesForStore extends ConsumerWidget {
  const _ServicesForStore({
    required this.store,
    required this.onRefresh,
  });

  final StoreRecord store;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(storeServicesProvider(store.id));

    return servicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBody(
        message: '$e',
        onRetry: () => ref.invalidate(storeServicesProvider(store.id)),
      ),
      data: (services) {
        if (services.isEmpty) {
          return pullToRefreshBox(
            onRefresh: onRefresh,
            padding: const EdgeInsets.all(32),
            child: _EmptyServices(store: store),
          );
        }

        final grouped = <String, List<ServiceRecord>>{};
        for (final s in services) {
          grouped.putIfAbsent(s.category, () => []).add(s);
        }

        return pullToRefresh(
          onRefresh: onRefresh,
          child: ListView(
            physics: alwaysScrollablePhysics,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              ...grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryHeader(category: entry.key),
                    const SizedBox(height: 8),
                    ...entry.value.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ServiceCard(
                          service: s,
                          store: store,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty state with Add button ──────────────────────────────────────────────

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.store});
  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 72,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No services for ${store.businessName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Services are added by the admin.\nContact your admin to add services to this store.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Contact your admin to add services to this store.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Request Services'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ServiceCard extends ConsumerStatefulWidget {
  const _ServiceCard({
    required this.service,
    required this.store,
  });

  final ServiceRecord service;
  final StoreRecord store;

  @override
  ConsumerState<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<_ServiceCard> {
  bool _toggling = false;

  Future<void> _toggleActive() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final loginPass =
          await ref.read(authRepositoryProvider).getStoredLoginPass();
      if (user == null || loginPass == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final nextActive = !widget.service.isActive;
      await ref.read(servicesRepositoryProvider).toggleServiceActive(
            accountId: user.id,
            loginPass: loginPass,
            storeId: widget.store.id,
            serviceId: widget.service.id,
            active: nextActive,
          );

      ref.invalidate(storeServicesProvider(widget.store.id));
      if (mounted) {
        AppSnackBar.success(
          context,
          nextActive ? 'Service enabled' : 'Service disabled',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to update status: $e');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditServiceScreen(
          store: widget.store,
          service: widget.service,
        ),
      ),
    );
    if (updated == true) {
      ref.invalidate(storeServicesProvider(widget.store.id));
    }
  }

  void _openView() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ServiceDetailSheet(service: widget.service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final imageUrl = service.displayImage;
    final hasDesc = service.description?.trim().isNotEmpty == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: service.isActive
              ? AppColors.border.withValues(alpha: 0.9)
              : AppColors.error.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: service.isActive
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceThumbnail(
                  imageUrl: imageUrl,
                  isActive: service.isActive,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 1.2,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(isActive: service.isActive),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.category,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasDesc ? service.description! : 'No description added',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: hasDesc
                              ? AppColors.textSecondary
                              : AppColors.textSecondary.withValues(alpha: 0.6),
                          fontStyle:
                              hasDesc ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      if (service.hasPricing) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded,
                                size: 14,
                                color: AppColors.primary.withValues(alpha: 0.85)),
                            const SizedBox(width: 2),
                            Text(
                              service.priceDisplay.replaceFirst('₹', ''),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F9),
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.85),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'View',
                    icon: Icons.visibility_rounded,
                    accent: const Color(0xFF6366F1),
                    onTap: _openView,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: service.isActive ? 'Disable' : 'Enable',
                    icon: service.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    accent: service.isActive
                        ? AppColors.warning
                        : AppColors.success,
                    loading: _toggling,
                    onTap: _toggleActive,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: 'Edit',
                    icon: Icons.edit_rounded,
                    accent: AppColors.primary,
                    primary: true,
                    onTap: _openEdit,
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

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({
    required this.imageUrl,
    required this.isActive,
  });

  final String? imageUrl;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ColorFiltered(
        colorFilter: isActive
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 0.72, 0,
              ]),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _ServiceThumbnailFallback(isActive: isActive),
              )
            : _ServiceThumbnailFallback(isActive: isActive),
      ),
    );
  }
}

class _ServiceThumbnailFallback extends StatelessWidget {
  const _ServiceThumbnailFallback({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: isActive ? 0.14 : 0.08),
            AppColors.secondary.withValues(alpha: isActive ? 0.1 : 0.05),
          ],
        ),
      ),
      child: Icon(
        Icons.spa_rounded,
        color: AppColors.primary.withValues(alpha: isActive ? 1 : 0.5),
        size: 30,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.primary = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? accent : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: primary ? 0 : 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary ? accent : accent.withValues(alpha: 0.16),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary ? Colors.white : accent,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: primary ? Colors.white : accent,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary ? Colors.white : accent,
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

class _ServiceDetailSheet extends StatelessWidget {
  const _ServiceDetailSheet({required this.service});
  final ServiceRecord service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.displayImage;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                )
              else
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.spa_rounded,
                      size: 48, color: AppColors.primary),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusPill(isActive: service.isActive),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                    icon: Icons.category_outlined,
                    label: service.category,
                  ),
                  _DetailChip(
                    icon: Icons.people_outline_rounded,
                    label: service.targetGender,
                  ),
                  if (service.hasPricing)
                    _DetailChip(
                      icon: Icons.currency_rupee_rounded,
                      label: service.priceDisplay,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                service.description?.trim().isNotEmpty == true
                    ? service.description!
                    : 'No description provided.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
              if (service.images.length > 1) ...[
                const SizedBox(height: 20),
                const Text(
                  'Gallery',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: service.images.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        service.images[i],
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
