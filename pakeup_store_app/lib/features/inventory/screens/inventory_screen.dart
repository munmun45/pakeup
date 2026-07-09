import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bank/widgets/bank_shared_widgets.dart';
import '../../services/models/service_models.dart';
import '../../services/providers/services_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../stores/models/store_models.dart';
import '../../stores/providers/stores_provider.dart';

class _WeekDayEdit {
  _WeekDayEdit({
    required this.enabled,
    required this.isParlourAvailable,
    required this.isHomeAvailable,
    required this.parlourPriceMen,
    required this.parlourPriceWomen,
    required this.parlourDurationMen,
    required this.parlourDurationWomen,
    required this.homePriceMen,
    required this.homePriceWomen,
    required this.homeDurationMen,
    required this.homeDurationWomen,
    this.dirty = false,
  });

  bool enabled;
  bool isParlourAvailable;
  bool isHomeAvailable;
  double? parlourPriceMen;
  double? parlourPriceWomen;
  int? parlourDurationMen;
  int? parlourDurationWomen;
  double? homePriceMen;
  double? homePriceWomen;
  int? homeDurationMen;
  int? homeDurationWomen;
  bool dirty;

  factory _WeekDayEdit.fromService(
    ServiceRecord service, {
    bool enabled = true,
  }) {
    return _WeekDayEdit(
      enabled: enabled,
      isParlourAvailable: service.isParlourAvailable,
      isHomeAvailable: service.isHomeAvailable,
      parlourPriceMen: service.parlourPriceMen,
      parlourPriceWomen: service.parlourPriceWomen,
      parlourDurationMen: service.parlourDurationMen,
      parlourDurationWomen: service.parlourDurationWomen,
      homePriceMen: service.homePriceMen,
      homePriceWomen: service.homePriceWomen,
      homeDurationMen: service.homeDurationMen,
      homeDurationWomen: service.homeDurationWomen,
    );
  }

  _WeekDayEdit copy() => _WeekDayEdit(
        enabled: enabled,
        isParlourAvailable: isParlourAvailable,
        isHomeAvailable: isHomeAvailable,
        parlourPriceMen: parlourPriceMen,
        parlourPriceWomen: parlourPriceWomen,
        parlourDurationMen: parlourDurationMen,
        parlourDurationWomen: parlourDurationWomen,
        homePriceMen: homePriceMen,
        homePriceWomen: homePriceWomen,
        homeDurationMen: homeDurationMen,
        homeDurationWomen: homeDurationWomen,
        dirty: dirty,
      );

  String get priceDisplay {
    if (!enabled) return 'Off';
    final prices = <double>[];
    if (isParlourAvailable) {
      for (final price in [parlourPriceMen, parlourPriceWomen]) {
        if (price != null && price > 0) prices.add(price);
      }
    }
    if (isHomeAvailable) {
      for (final price in [homePriceMen, homePriceWomen]) {
        if (price != null && price > 0) prices.add(price);
      }
    }
    if (prices.isEmpty) return '—';
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    if (min == max) return '₹${min.toStringAsFixed(0)}';
    return '₹${min.toStringAsFixed(0)} – ₹${max.toStringAsFixed(0)}';
  }
}

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
  final Map<String, Map<String, _WeekDayEdit>> _weekEdits = {};
  bool _saving = false;

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
    return _weekEdits[serviceId]?[_dateKey(date)]?.enabled ?? true;
  }

  String _todayPriceFor(ServiceRecord service) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _dayPriceFor(service, today);
  }

  String _dayPriceFor(ServiceRecord service, DateTime day) {
    return _ensureWeekEdit(service.id, day, service).priceDisplay;
  }

  _WeekDayEdit _ensureWeekEdit(
    String serviceId,
    DateTime date,
    ServiceRecord service,
  ) {
    _weekEdits.putIfAbsent(serviceId, () => {});
    return _weekEdits[serviceId]!.putIfAbsent(
      _dateKey(date),
      () => _WeekDayEdit.fromService(service),
    );
  }

  bool get _hasPendingChanges =>
      _weekEdits.values.any((days) => days.values.any((edit) => edit.dirty));

  Future<void> _openDayScheduleDialog(
    ServiceRecord service,
    DateTime day,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _DayScheduleDialog(
          service: service,
          weekDays: _weekDays,
          initialDay: day,
          loadDraft: (date) =>
              _ensureWeekEdit(service.id, date, service).copy(),
          onSaveDay: (date, updated) {
            setState(() {
              updated.dirty = true;
              _weekEdits.putIfAbsent(service.id, () => {})[_dateKey(date)] =
                  updated;
            });
          },
          onDone: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _onStoreSelected(StoreRecord store, {String? serviceId}) {
    setState(() {
      _selectedStoreId = store.id;
      _selectedServiceId = serviceId;
      _showStorePicker = false;
      _weekEdits.clear();
    });
    ref.invalidate(storeServicesProvider(store.id));
  }

  void _backToStoreList() {
    setState(() {
      _showStorePicker = true;
      _selectedStoreId = null;
      _selectedServiceId = null;
      _weekEdits.clear();
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
      if (mounted) {
        setState(() {
          for (final days in _weekEdits.values) {
            for (final edit in days.values) {
              edit.dirty = false;
            }
          }
        });
        AppSnackBar.success(
          context,
          'Inventory saved!',
          bottomMargin: _inventorySnackBottomMargin(context),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Failed to save: $e',
          bottomMargin: _inventorySnackBottomMargin(context),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _inventorySnackBottomMargin(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    const navBarHeight = 68.0;
    const centerFabClearance = 44.0;
    const spacing = 16.0;
    var margin = padding.bottom + navBarHeight + centerFabClearance + spacing;
    if (_hasPendingChanges) {
      margin += 76;
    }
    return margin;
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
        backgroundColor: AppColors.background,
        appBar: const BankPageAppBar(title: 'Inventory'),
        body: Center(child: Text('$e')),
      ),
      data: (stores) {
        final sortedStores = _sortedStores(stores);
        final showStoreList =
            _showStorePicker || _selectedStoreId == null || stores.isEmpty;
        final selectedStore = _findStore(stores, _selectedStoreId);
        final profileId =
            ref.watch(authStateProvider).valueOrNull?.profileId?.trim();

        AsyncValue<List<ServiceRecord>>? servicesAsync;
        if (_selectedStoreId != null) {
          servicesAsync = ref.watch(storeServicesProvider(_selectedStoreId!));
          ref.listen(storeServicesProvider(_selectedStoreId!), (previous, next) {
            final services = next.valueOrNull;
            if (services == null || services.isEmpty) return;
            final current = _selectedServiceId;
            final isValid =
                current != null && services.any((service) => service.id == current);
            if (!isValid) {
              setState(() => _selectedServiceId = services.first.id);
            }
          });
        }

        final hasPendingChanges = _hasPendingChanges;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: BankPageAppBar(
            title: showStoreList
                ? 'Inventory'
                : selectedStore?.businessName ?? 'Inventory',
            profileId: showStoreList ? profileId : null,
            subtitle: showStoreList
                ? 'Select a store to manage availability'
                : selectedStore?.categoryLabel,
            leading: !showStoreList && widget.storeId == null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _backToStoreList,
                  )
                : null,
          ),
          bottomNavigationBar: !showStoreList && hasPendingChanges
              ? BankGradientButtonBar(
                  label: 'Save Changes',
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _saveChanges,
                )
              : null,
          body: showStoreList
              ? pullToRefresh(
                  onRefresh: _refreshPage,
                  child: _InventoryStoreList(
                    stores: sortedStores,
                    onSelectStore: _onStoreSelected,
                  ),
                )
              : selectedStore == null
                  ? const SizedBox.shrink()
                  : pullToRefresh(
                      onRefresh: _refreshPage,
                      child: _InventoryDetailBody(
                        servicesAsync: servicesAsync!,
                        selectedServiceId: _selectedServiceId,
                        weekStart: _weekStart,
                        onPreviousWeek: _previousWeek,
                        onNextWeek: _nextWeek,
                        onPickWeek: (date) =>
                            setState(() => _weekStart = _mondayOf(date)),
                        weekDays: _weekDays,
                        isAvailable: _isAvailable,
                        onOpenDayEditor: _openDayScheduleDialog,
                        todayPriceFor: _todayPriceFor,
                        dayPriceFor: _dayPriceFor,
                        bottomPadding: hasPendingChanges ? 96 : 24,
                      ),
                    ),
        );
      },
    );
  }
}

class _InventoryDetailBody extends StatelessWidget {
  const _InventoryDetailBody({
    required this.servicesAsync,
    required this.selectedServiceId,
    required this.weekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickWeek,
    required this.weekDays,
    required this.isAvailable,
    required this.onOpenDayEditor,
    required this.todayPriceFor,
    required this.dayPriceFor,
    required this.bottomPadding,
  });

  final AsyncValue<List<ServiceRecord>> servicesAsync;
  final String? selectedServiceId;
  final DateTime weekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onPickWeek;
  final List<DateTime> weekDays;
  final bool Function(String, DateTime) isAvailable;
  final void Function(ServiceRecord service, DateTime day) onOpenDayEditor;
  final String Function(ServiceRecord service) todayPriceFor;
  final String Function(ServiceRecord service, DateTime day) dayPriceFor;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return servicesAsync.when(
      loading: () => ListView(
        physics: alwaysScrollablePhysics,
        padding: const EdgeInsets.all(32),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (e, _) => ListView(
        physics: alwaysScrollablePhysics,
        padding: const EdgeInsets.all(32),
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text('$e', textAlign: TextAlign.center),
        ],
      ),
      data: (services) {
        ServiceRecord? selectedService;
        if (selectedServiceId != null) {
          for (final service in services) {
            if (service.id == selectedServiceId) {
              selectedService = service;
              break;
            }
          }
        }

        return ListView(
          physics: alwaysScrollablePhysics,
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          children: [
            if (services.isEmpty)
              const _InventoryEmptyServicesCard()
            else if (selectedService != null)
              _WeekScheduleSection(
                service: selectedService,
                todayPriceLabel: todayPriceFor(selectedService),
                dayPriceFor: (day) => dayPriceFor(selectedService!, day),
                weekStart: weekStart,
                onPreviousWeek: onPreviousWeek,
                onNextWeek: onNextWeek,
                onPickWeek: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: weekStart,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) onPickWeek(picked);
                },
                weekDays: weekDays,
                isAvailable: isAvailable,
                onOpenDayEditor: (day) => onOpenDayEditor(selectedService!, day),
              )
            else
              const _InventoryPickServiceHint(),
          ],
        );
      },
    );
  }
}

class _InventoryPickServiceHint extends StatelessWidget {
  const _InventoryPickServiceHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.touch_app_outlined, size: 40, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Select a service',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            'Go back and tap a service on the store card to manage its weekly availability.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _InventoryEmptyServicesCard extends StatelessWidget {
  const _InventoryEmptyServicesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 40,
            color: AppColors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          const Text(
            'No services yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add services for this store first, then manage availability here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _InventoryTodayPriceBadge extends StatelessWidget {
  const _InventoryTodayPriceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isOff = label == 'Off';
    final color = isOff ? AppColors.textSecondary : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOff
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Today',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekScheduleSection extends StatelessWidget {
  const _WeekScheduleSection({
    required this.service,
    required this.todayPriceLabel,
    required this.weekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickWeek,
    required this.weekDays,
    required this.isAvailable,
    required this.onOpenDayEditor,
    required this.dayPriceFor,
  });

  final ServiceRecord service;
  final String todayPriceLabel;
  final String Function(DateTime day) dayPriceFor;
  final DateTime weekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPickWeek;
  final List<DateTime> weekDays;
  final bool Function(String, DateTime) isAvailable;
  final ValueChanged<DateTime> onOpenDayEditor;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isBeforeToday(DateTime day) =>
      day.isBefore(DateTime(_today.year, _today.month, _today.day));

  @override
  Widget build(BuildContext context) {
    final serviceId = service.id;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startLabel = DateFormat('d MMM').format(weekStart);
    final endLabel = DateFormat('d MMM').format(weekEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.07),
                AppColors.secondary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (service.category.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            service.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _InventoryTodayPriceBadge(label: todayPriceLabel),
                ],
              ),
              const SizedBox(height: 8),
              _InventoryWeekNav(
                startLabel: startLabel,
                endLabel: endLabel,
                onPrevious: onPreviousWeek,
                onNext: onNextWeek,
                onPick: onPickWeek,
                expanded: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.secondary.withValues(alpha: 0.06),
                      ],
                    ),
                    border: const Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(
                    children: [
                      for (final day in weekDays)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: _WeekHeaderDay(
                              day: day,
                              isToday: day.year == _today.year &&
                                  day.month == _today.month &&
                                  day.day == _today.day,
                              isPast: _isBeforeToday(day),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in weekDays)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: _DayColumnButton(
                              enabled: isAvailable(serviceId, day),
                              isPast: _isBeforeToday(day),
                              isToday: day.year == _today.year &&
                                  day.month == _today.month &&
                                  day.day == _today.day,
                              priceLabel: dayPriceFor(day),
                              onTap: () => onOpenDayEditor(day),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayColumnButton extends StatelessWidget {
  const _DayColumnButton({
    required this.enabled,
    required this.isPast,
    required this.isToday,
    required this.priceLabel,
    required this.onTap,
  });

  final bool enabled;
  final bool isPast;
  final bool isToday;
  final String priceLabel;
  final VoidCallback onTap;

  static const _mintBg = Color(0xFFEAF6EC);
  static const _mintBorder = Color(0xFF81C784);
  static const _disabledBg = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? _disabledBg
        : isToday
            ? AppColors.today.withValues(alpha: 0.1)
            : isPast
                ? AppColors.background
                : _mintBg;
    final borderColor = isToday
        ? AppColors.today
        : !enabled
            ? AppColors.border
            : isPast
                ? AppColors.border
                : _mintBorder;
    final statusColor = enabled
        ? (isToday
            ? AppColors.today
            : isPast
                ? AppColors.textSecondary
                : const Color(0xFF2E7D32))
        : AppColors.textSecondary;
    final priceColor = isToday
        ? AppColors.today
        : enabled
            ? AppColors.primary
            : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.check_circle_rounded : Icons.block_rounded,
                  size: 13,
                  color: statusColor,
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isToday ? 8.5 : 7.5,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: priceColor,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.edit_outlined,
                  size: 9,
                  color: AppColors.textSecondary.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryWeekNav extends StatelessWidget {
  const _InventoryWeekNav({
    required this.startLabel,
    required this.endLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    this.expanded = false,
  });

  final String startLabel;
  final String endLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 4,
                    top: 6,
                    bottom: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: startLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(text: ' – $endLabel'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous 7 days',
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            iconSize: 22,
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            tooltip: 'Next 7 days',
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            iconSize: 22,
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _InventoryDayDialogHeader extends StatelessWidget {
  const _InventoryDayDialogHeader({
    required this.serviceName,
    required this.serviceCategory,
    required this.shortDayLabel,
    required this.dayIndex,
    required this.totalDays,
    required this.isToday,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final String serviceName;
  final String serviceCategory;
  final String shortDayLabel;
  final int dayIndex;
  final int totalDays;
  final bool isToday;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.14),
                      AppColors.secondary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (serviceCategory.trim().isNotEmpty)
                      Text(
                        serviceCategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _DayNavArrow(
                  tooltip: 'Previous day',
                  enabled: canGoPrevious,
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        shortDayLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isToday
                              ? AppColors.today
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Day ${dayIndex + 1} of $totalDays',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _DayNavArrow(
                  tooltip: 'Next day',
                  enabled: canGoNext,
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayNavArrow extends StatelessWidget {
  const _DayNavArrow({
    required this.tooltip,
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 24,
        color: enabled
            ? AppColors.primary
            : AppColors.textSecondary.withValues(alpha: 0.35),
      ),
    );
  }
}

class _DayScheduleDialog extends StatefulWidget {
  const _DayScheduleDialog({
    required this.service,
    required this.weekDays,
    required this.initialDay,
    required this.loadDraft,
    required this.onSaveDay,
    required this.onDone,
  });

  final ServiceRecord service;
  final List<DateTime> weekDays;
  final DateTime initialDay;
  final _WeekDayEdit Function(DateTime day) loadDraft;
  final void Function(DateTime day, _WeekDayEdit edit) onSaveDay;
  final VoidCallback onDone;

  @override
  State<_DayScheduleDialog> createState() => _DayScheduleDialogState();
}

class _DayScheduleDialogState extends State<_DayScheduleDialog> {
  late int _dayIndex;
  late _WeekDayEdit _draft;
  final Map<String, _WeekDayEdit> _sessionDrafts = {};
  bool _dirty = false;

  String _dateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  DateTime get _currentDay => widget.weekDays[_dayIndex];

  @override
  void initState() {
    super.initState();
    _dayIndex = widget.weekDays.indexWhere(
      (d) =>
          d.year == widget.initialDay.year &&
          d.month == widget.initialDay.month &&
          d.day == widget.initialDay.day,
    );
    if (_dayIndex < 0) _dayIndex = 0;
    _draft = widget.loadDraft(_currentDay);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isPast(DateTime day) => day.isBefore(_today);

  bool _isToday(DateTime day) =>
      day.year == _today.year &&
      day.month == _today.month &&
      day.day == _today.day;

  void _touch() => setState(() => _dirty = true);

  void _stashCurrentDraft() {
    _sessionDrafts[_dateKey(_currentDay)] = _draft.copy();
  }

  void _loadDraftForIndex(int index) {
    final day = widget.weekDays[index];
    final key = _dateKey(day);
    _draft = (_sessionDrafts[key] ?? widget.loadDraft(day)).copy();
  }

  void _goToPreviousDay() {
    if (_dayIndex <= 0) return;
    _stashCurrentDraft();
    setState(() {
      _dayIndex--;
      _loadDraftForIndex(_dayIndex);
    });
  }

  void _goToNextDay() {
    if (_dayIndex >= widget.weekDays.length - 1) return;
    _stashCurrentDraft();
    setState(() {
      _dayIndex++;
      _loadDraftForIndex(_dayIndex);
    });
  }

  void _saveAll() {
    _stashCurrentDraft();
    for (final day in widget.weekDays) {
      final key = _dateKey(day);
      final edit = _sessionDrafts[key];
      if (edit != null) widget.onSaveDay(day, edit);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final shortDayLabel = DateFormat('EEE, d MMM').format(_currentDay);
    final canGoPrevious = _dayIndex > 0;
    final canGoNext = _dayIndex < widget.weekDays.length - 1;
    final isToday = _isToday(_currentDay);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InventoryDayDialogHeader(
              serviceName: widget.service.name,
              serviceCategory: widget.service.category,
              shortDayLabel: shortDayLabel,
              dayIndex: _dayIndex,
              totalDays: widget.weekDays.length,
              isToday: isToday,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              onPrevious: _goToPreviousDay,
              onNext: _goToNextDay,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _WeekDayEditorCard(
                  key: ValueKey(_dateKey(_currentDay)),
                  day: _currentDay,
                  edit: _draft,
                  service: widget.service,
                  isPast: _isPast(_currentDay),
                  isToday: _isToday(_currentDay),
                  compact: true,
                  onChanged: _touch,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _dirty
                                ? [AppColors.primary, AppColors.secondary]
                                : [
                                    AppColors.success,
                                    AppColors.success.withValues(alpha: 0.85),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _saveAll,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            _dirty ? Icons.save_rounded : Icons.check_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _dirty ? 'Save changes' : 'Save',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayEditorCard extends StatelessWidget {
  const _WeekDayEditorCard({
    super.key,
    required this.day,
    required this.edit,
    required this.service,
    required this.isPast,
    required this.isToday,
    required this.onChanged,
    this.compact = false,
  });

  final DateTime day;
  final _WeekDayEdit edit;
  final ServiceRecord service;
  final bool isPast;
  final bool isToday;
  final bool compact;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE, d MMM').format(day);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color:
                            isToday ? AppColors.today : AppColors.textPrimary,
                      ),
                    ),
                    if (isPast)
                      const Text(
                        'Past date',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                edit.enabled ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: edit.enabled ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: edit.enabled,
                onChanged: isPast
                    ? null
                    : (value) {
                        edit.enabled = value;
                        onChanged();
                      },
                activeThumbColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: edit.enabled ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Day availability',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        edit.enabled ? 'Open for bookings' : 'Closed this day',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: edit.enabled
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: edit.enabled,
                  onChanged: isPast
                      ? null
                      : (value) {
                          edit.enabled = value;
                          onChanged();
                        },
                  activeThumbColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        if (edit.enabled) ...[
          const SizedBox(height: 10),
          _VisitPriceSection(
            title: 'Parlour',
            icon: Icons.storefront_outlined,
            enabled: edit.isParlourAvailable,
            readOnly: isPast,
            compact: compact,
            maleLabel: 'Men',
            femaleLabel: 'Women',
            malePrice: edit.parlourPriceMen,
            femalePrice: edit.parlourPriceWomen,
            maleDuration: edit.parlourDurationMen,
            femaleDuration: edit.parlourDurationWomen,
            onEnabledChanged: isPast
                ? null
                : (value) {
                    edit.isParlourAvailable = value;
                    onChanged();
                  },
            onMaleChanged: (price, duration) {
              edit.parlourPriceMen = price;
              edit.parlourDurationMen = duration;
              onChanged();
            },
            onFemaleChanged: (price, duration) {
              edit.parlourPriceWomen = price;
              edit.parlourDurationWomen = duration;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _VisitPriceSection(
            title: 'Home visit',
            icon: Icons.home_outlined,
            enabled: edit.isHomeAvailable,
            readOnly: isPast,
            compact: compact,
            maleLabel: 'Men',
            femaleLabel: 'Women',
            malePrice: edit.homePriceMen,
            femalePrice: edit.homePriceWomen,
            maleDuration: edit.homeDurationMen,
            femaleDuration: edit.homeDurationWomen,
            onEnabledChanged: isPast
                ? null
                : (value) {
                    edit.isHomeAvailable = value;
                    onChanged();
                  },
            onMaleChanged: (price, duration) {
              edit.homePriceMen = price;
              edit.homeDurationMen = duration;
              onChanged();
            },
            onFemaleChanged: (price, duration) {
              edit.homePriceWomen = price;
              edit.homeDurationWomen = duration;
              onChanged();
            },
          ),
        ],
      ],
    );

    if (compact) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? AppColors.today.withValues(alpha: 0.55)
              : AppColors.border,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: content,
      ),
    );
  }
}

class _VisitPriceSection extends StatelessWidget {
  const _VisitPriceSection({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.readOnly,
    required this.compact,
    required this.maleLabel,
    required this.femaleLabel,
    required this.malePrice,
    required this.femalePrice,
    required this.maleDuration,
    required this.femaleDuration,
    required this.onEnabledChanged,
    required this.onMaleChanged,
    required this.onFemaleChanged,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final bool readOnly;
  final bool compact;
  final String maleLabel;
  final String femaleLabel;
  final double? malePrice;
  final double? femalePrice;
  final int? maleDuration;
  final int? femaleDuration;
  final ValueChanged<bool>? onEnabledChanged;
  final void Function(double? price, int? duration) onMaleChanged;
  final void Function(double? price, int? duration) onFemaleChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.03)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: enabled
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: enabled ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!readOnly && onEnabledChanged != null)
                  Switch.adaptive(
                    value: enabled,
                    onChanged: onEnabledChanged,
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RateField(
                      label: maleLabel,
                      price: malePrice,
                      duration: maleDuration,
                      readOnly: readOnly,
                      compact: compact,
                      onChanged: onMaleChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RateField(
                      label: femaleLabel,
                      price: femalePrice,
                      duration: femaleDuration,
                      readOnly: readOnly,
                      compact: compact,
                      onChanged: onFemaleChanged,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateField extends StatefulWidget {
  const _RateField({
    required this.label,
    required this.price,
    required this.duration,
    required this.readOnly,
    required this.compact,
    required this.onChanged,
  });

  final String label;
  final double? price;
  final int? duration;
  final bool readOnly;
  final bool compact;
  final void Function(double? price, int? duration) onChanged;

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.price != null && widget.price! > 0
          ? widget.price!.toStringAsFixed(0)
          : '',
    );
    _durationCtrl = TextEditingController(
      text: widget.duration != null && widget.duration! > 0
          ? '${widget.duration}'
          : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final price = double.tryParse(_priceCtrl.text.trim());
    final duration = int.tryParse(_durationCtrl.text.trim());
    widget.onChanged(
      price != null && price > 0 ? price : null,
      duration != null && duration > 0 ? duration : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = TextStyle(
      fontSize: widget.compact ? 12 : 13,
      fontWeight: FontWeight.w700,
    );
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 10,
        vertical: widget.compact ? 8 : 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _priceCtrl,
                readOnly: widget.readOnly,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: widget.readOnly ? null : (_) => _emit(),
                style: fieldStyle,
                decoration: inputDecoration.copyWith(
                  prefixText: '₹ ',
                  prefixStyle: fieldStyle.copyWith(
                    fontSize: widget.compact ? 11 : 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'Price',
                  hintStyle: TextStyle(
                    fontSize: widget.compact ? 11 : 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _durationCtrl,
                readOnly: widget.readOnly,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: widget.readOnly ? null : (_) => _emit(),
                style: fieldStyle.copyWith(fontWeight: FontWeight.w600),
                decoration: inputDecoration.copyWith(
                  suffixText: ' min',
                  suffixStyle: TextStyle(
                    fontSize: widget.compact ? 9 : 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'Time',
                  hintStyle: TextStyle(
                    fontSize: widget.compact ? 11 : 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeekHeaderDay extends StatelessWidget {
  const _WeekHeaderDay({
    required this.day,
    required this.isToday,
    required this.isPast,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final labelColor = isToday
        ? Colors.white70
        : isPast
            ? AppColors.textSecondary.withValues(alpha: 0.65)
            : AppColors.textSecondary;
    final dayColor = isToday
        ? Colors.white
        : isPast
            ? AppColors.textSecondary
            : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
      decoration: BoxDecoration(
        color: isToday ? AppColors.today : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isToday ? AppColors.today : AppColors.border,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.today.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEE').format(day),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: labelColor,
              height: 1.1,
            ),
          ),
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: dayColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryStoreList extends StatelessWidget {
  const _InventoryStoreList({
    required this.stores,
    required this.onSelectStore,
  });

  final List<StoreRecord> stores;
  final void Function(StoreRecord store, {String? serviceId}) onSelectStore;

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

    final approvedCount = stores.where((s) => s.isKycApproved).length;
    final totalServices = stores.fold<int>(
      0,
      (sum, store) => sum + store.serviceCount,
    );

    return ListView(
      physics: alwaysScrollablePhysics,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _InventorySummaryStrip(
          stores: stores.length,
          approved: approvedCount,
          services: totalServices,
        ),
        const SizedBox(height: 14),
        ...stores.map(
          (store) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _InventoryStorePickerCard(
              store: store,
              onSelectStore: onSelectStore,
            ),
          ),
        ),
      ],
    );
  }
}

class _InventorySummaryStrip extends StatelessWidget {
  const _InventorySummaryStrip({
    required this.stores,
    required this.approved,
    required this.services,
  });

  final int stores;
  final int approved;
  final int services;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InventorySummaryChip(
            icon: Icons.storefront_rounded,
            label: 'Stores',
            value: '$stores',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InventorySummaryChip(
            icon: Icons.verified_rounded,
            label: 'Approved',
            value: '$approved',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InventorySummaryChip(
            icon: Icons.inventory_2_outlined,
            label: 'Services',
            value: '$services',
            color: const Color(0xFF1976D2),
          ),
        ),
      ],
    );
  }
}

class _InventorySummaryChip extends StatelessWidget {
  const _InventorySummaryChip({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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

class _InventoryStorePickerCard extends ConsumerWidget {
  const _InventoryStorePickerCard({
    required this.store,
    required this.onSelectStore,
  });

  final StoreRecord store;
  final void Function(StoreRecord store, {String? serviceId}) onSelectStore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(storeServicesProvider(store.id));
    final serviceCount =
        servicesAsync.valueOrNull?.length ?? store.serviceCount;
    final hasServices = serviceCount > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 7),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onSelectStore(store),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                ),
                child: Row(
                  children: [
                    _InventoryStoreImage(
                      url: store.primaryImage,
                      name: store.businessName,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            store.ownerName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.kycLabel.replaceFirst('KYC ', ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      store.addressLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: servicesAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => _InventoryStoreServicesFooter(
                  serviceCount: serviceCount,
                  hasServices: hasServices,
                  services: const [],
                  failed: true,
                  onOpenStore: () => onSelectStore(store),
                ),
                data: (services) => _InventoryStoreServicesFooter(
                  serviceCount: services.length,
                  hasServices: services.isNotEmpty,
                  services: services,
                  onOpenStore: () => onSelectStore(store),
                  onSelectService: (serviceId) =>
                      onSelectStore(store, serviceId: serviceId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryStoreServicesFooter extends StatelessWidget {
  const _InventoryStoreServicesFooter({
    required this.serviceCount,
    required this.hasServices,
    required this.services,
    required this.onOpenStore,
    this.onSelectService,
    this.failed = false,
  });

  final int serviceCount;
  final bool hasServices;
  final List<ServiceRecord> services;
  final VoidCallback onOpenStore;
  final ValueChanged<String>? onSelectService;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onOpenStore,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$serviceCount service${serviceCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                failed
                    ? 'Retry'
                    : hasServices
                        ? 'Manage'
                        : 'Add services',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: failed
                      ? AppColors.error
                      : hasServices
                          ? AppColors.primary
                          : AppColors.warning,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: failed
                    ? AppColors.error
                    : hasServices
                        ? AppColors.primary
                        : AppColors.warning,
              ),
            ],
          ),
        ),
        if (failed) ...[
          const SizedBox(height: 8),
          const Text(
            'Could not load services',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ] else if (services.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'No services added yet',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _InventoryStoreServiceRow(
                service: service,
                onTap: onSelectService == null
                    ? null
                    : () => onSelectService!(service.id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InventoryStoreServiceRow extends StatelessWidget {
  const _InventoryStoreServiceRow({
    required this.service,
    this.onTap,
  });

  final ServiceRecord service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  size: 13,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (service.category.trim().isNotEmpty)
                      Text(
                        service.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                service.priceDisplay,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryStoreImage extends StatelessWidget {
  const _InventoryStoreImage({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 46,
        height: 46,
        child: hasImage
            ? Image.network(
                imageUrl,
                width: 46,
                height: 46,
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
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
