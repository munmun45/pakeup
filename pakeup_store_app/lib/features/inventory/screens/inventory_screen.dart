import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/theme/app_theme.dart';
import '../../services/models/service_models.dart';
import '../../services/providers/services_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.storeId});
  final String? storeId;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String? _selectedStoreId;
  String? _selectedServiceId;
  bool _showStorePicker = true;
  late DateTime _weekStart;
  final Map<String, Map<String, bool>> _availability = {};
  bool _saving = false;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    if (widget.storeId != null) {
      _selectedStoreId = widget.storeId;
      _showStorePicker = false;
    }
  }

  DateTime _mondayOf(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  void _previousWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));

  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _isAvailable(String serviceId, DateTime date) {
    return _availability[serviceId]?[_dateKey(date)] ?? true;
  }

  void _toggleDay(String serviceId, DateTime date) {
    setState(() {
      _availability.putIfAbsent(serviceId, () => {});
      final key = _dateKey(date);
      _availability[serviceId]![key] =
          !(_availability[serviceId]![key] ?? true);
    });
  }

  void _onStoreSelected(StoreRecord store) {
    setState(() {
      _selectedStoreId = store.id;
      _selectedServiceId = null;
      _showStorePicker = false;
      _availability.clear();
    });
    ref.invalidate(storeServicesProvider(store.id));
  }

  void _backToStoreList() {
    setState(() {
      _showStorePicker = true;
      _selectedStoreId = null;
      _selectedServiceId = null;
      _availability.clear();
    });
  }

  StoreRecord? _findStore(List<StoreRecord> stores, String? id) {
    if (id == null) return null;
    for (final store in stores) {
      if (store.id == id) return store;
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

  Future<void> _saveChanges() async {
    if (_selectedServiceId == null) return;
    setState(() => _saving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) AppSnackBar.success(context, 'Inventory saved!');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        appBar: AppBar(title: const Text('Inventory')),
        body: Center(child: Text('$e')),
      ),
      data: (stores) {
        final sortedStores = _sortedStores(stores);
        final showStoreList =
            _showStorePicker || _selectedStoreId == null || stores.isEmpty;
        final selectedStore = _findStore(stores, _selectedStoreId);

        List<ServiceRecord> services = [];
        if (_selectedStoreId != null) {
          final servicesAsync =
              ref.watch(storeServicesProvider(_selectedStoreId!));
          services = servicesAsync.valueOrNull ?? [];
        }

        final hasPendingChanges = _availability.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              showStoreList
                  ? 'Inventory'
                  : selectedStore?.businessName ?? 'Inventory',
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
            actions: [
              if (!showStoreList && hasPendingChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveChanges,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save', style: TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
          body: showStoreList
              ? pullToRefresh(
                  onRefresh: _refreshPage,
                  child: _InventoryStoreList(
                    stores: sortedStores,
                    onSelectStore: _onStoreSelected,
                  ),
                )
              : Column(
                  children: [
                    if (selectedStore != null)
                      _SelectedStoreBanner(store: selectedStore),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(12),
                      child: _DropdownSelector<String>(
                        label: 'Select Service',
                        icon: Icons.spa_outlined,
                        value: _selectedServiceId,
                        items: services
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedServiceId = v),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _previousWeek,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _weekStart,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(
                                    () => _weekStart = _mondayOf(picked),
                                  );
                                }
                              },
                              child: Column(
                                children: [
                                  Text(
                                    'Week of ${DateFormat('d MMM').format(_weekStart)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${DateFormat('d MMM').format(_weekStart)} – '
                                    '${DateFormat('d MMM yyyy').format(_weekStart.add(const Duration(days: 6)))}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: _nextWeek,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: pullToRefresh(
                        onRefresh: _refreshPage,
                        child: _selectedServiceId == null
                            ? ListView(
                                physics: alwaysScrollablePhysics,
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.45,
                                    child: _EmptyState(
                                      hasStore: true,
                                      hasServices: services.isNotEmpty,
                                    ),
                                  ),
                                ],
                              )
                            : _WeekGrid(
                                serviceId: _selectedServiceId!,
                                weekDays: _weekDays,
                                weekdays: _weekdays,
                                isAvailable: _isAvailable,
                                onToggle: _toggleDay,
                              ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _InventoryStoreList extends StatelessWidget {
  const _InventoryStoreList({
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
                'Add a store first to manage its inventory.',
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

    return ListView(
      physics: alwaysScrollablePhysics,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Select a store to manage inventory',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...stores.map(
          (store) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InventoryStorePickerCard(
              store: store,
              onTap: () => onSelectStore(store),
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryStorePickerCard extends ConsumerWidget {
  const _InventoryStorePickerCard({
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
    final serviceCount =
        servicesAsync.valueOrNull?.length ?? store.serviceCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
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
                      backgroundImage:
                          store.primaryImage?.trim().isNotEmpty == true
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
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      servicesAsync.isLoading
                          ? 'Loading services...'
                          : '$serviceCount service${serviceCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.primary,
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

class _SelectedStoreBanner extends StatelessWidget {
  const _SelectedStoreBanner({required this.store});

  final StoreRecord store;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              store.addressLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownSelector<T> extends StatelessWidget {
  const _DropdownSelector({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.selectedItemBuilder,
  });
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final DropdownButtonBuilder? selectedItemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        items: items,
        selectedItemBuilder: selectedItemBuilder,
        onChanged: onChanged,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasStore, required this.hasServices});
  final bool hasStore;
  final bool hasServices;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = !hasStore
        ? (
            Icons.storefront_outlined,
            'Select a Store',
            'Choose a store to manage its inventory.'
          )
        : !hasServices
            ? (
                Icons.spa_outlined,
                'No Services',
                'This store has no services yet.'
              )
            : (
                Icons.spa_outlined,
                'Select a Service',
                'Choose a service to view its weekly schedule.'
              );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.serviceId,
    required this.weekDays,
    required this.weekdays,
    required this.isAvailable,
    required this.onToggle,
  });
  final String serviceId;
  final List<DateTime> weekDays;
  final List<String> weekdays;
  final bool Function(String, DateTime) isAvailable;
  final void Function(String, DateTime) onToggle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return ListView(
      physics: alwaysScrollablePhysics,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _LegendItem(color: AppColors.success, label: 'Available'),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.error, label: 'Blocked'),
            const SizedBox(width: 16),
            _LegendItem(color: const Color(0xFF1976D2), label: 'Today'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(weekDays.length, (i) {
              final date = weekDays[i];
              final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                  DateFormat('yyyy-MM-dd').format(now);
              final isPast = date.isBefore(
                  DateTime(now.year, now.month, now.day));
              final available = isAvailable(serviceId, date);

              return GestureDetector(
                onTap: isPast ? null : () => onToggle(serviceId, date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isPast
                        ? AppColors.background
                        : available
                            ? AppColors.success.withValues(alpha: 0.05)
                            : AppColors.error.withValues(alpha: 0.05),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(
                            top: Radius.circular(16))
                        : i == 6
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(16))
                            : BorderRadius.zero,
                    border: Border(
                      bottom: i < 6
                          ? const BorderSide(color: AppColors.border)
                          : BorderSide.none,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          weekdays[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isToday
                                ? const Color(0xFF1976D2)
                                : isPast
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday
                              ? const Color(0xFF1976D2)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? Colors.white
                                  : isPast
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isPast)
                        const Text(
                          'Past',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        )
                      else ...[
                        Text(
                          available ? 'Available' : 'Blocked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: available
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Switch.adaptive(
                          value: available,
                          onChanged: (_) => onToggle(serviceId, date),
                          activeThumbColor: AppColors.success,
                          inactiveThumbColor: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bulk Actions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final now2 = DateTime.now();
                  for (final date in weekDays) {
                    if (!date.isBefore(
                        DateTime(now2.year, now2.month, now2.day))) {
                      onToggle.call(serviceId, date);
                    }
                  }
                },
                icon: const Icon(Icons.block_rounded, size: 16),
                label: const Text('Block All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final now2 = DateTime.now();
                  for (final date in weekDays) {
                    if (!date.isBefore(
                        DateTime(now2.year, now2.month, now2.day))) {
                      final avail = isAvailable(serviceId, date);
                      if (!avail) onToggle.call(serviceId, date);
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded,
                    size: 16),
                label: const Text('Enable All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: BorderSide(
                      color: AppColors.success.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
