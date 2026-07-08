part of 'partner_inventory_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  MMT-STYLE INVENTORY — stores → 7-day availability + date pricing
// ══════════════════════════════════════════════════════════════════

const _weekdayShortNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

VisitType _visitTypeFromBools({required bool parlour, required bool home}) {
  if (parlour && home) return VisitType.both;
  if (parlour) return VisitType.parlour;
  if (home) return VisitType.home;
  return VisitType.none;
}

VisitType _defaultVisitTypeForDraft(ServicePricingDraft draft) {
  return _visitTypeFromBools(
    parlour: draft.isParlourAvailable,
    home: draft.isHomeAvailable,
  );
}

class _UnifiedInventoryPanel extends ConsumerStatefulWidget {
  const _UnifiedInventoryPanel({
    super.key,
    required this.partners,
    required this.services,
  });

  final List<PartnerRecord> partners;
  final List<PartnerServiceRecord> services;

  @override
  ConsumerState<_UnifiedInventoryPanel> createState() =>
      _UnifiedInventoryPanelState();
}

class _DayPricingEdit {
  _DayPricingEdit({
    this.isParlourAvailable = true,
    this.isHomeAvailable = false,
    this.parlourPriceMen,
    this.parlourPriceWomen,
    this.homePriceMen,
    this.homePriceWomen,
    this.parlourDurationMen,
    this.parlourDurationWomen,
    this.homeDurationMen,
    this.homeDurationWomen,
  });

  bool isParlourAvailable;
  bool isHomeAvailable;
  double? parlourPriceMen;
  double? parlourPriceWomen;
  double? homePriceMen;
  double? homePriceWomen;
  int? parlourDurationMen;
  int? parlourDurationWomen;
  int? homeDurationMen;
  int? homeDurationWomen;
  bool isDirty = false;
  /// True when price/duration fields were edited (not visit-type checkboxes).
  bool pricingFieldsTouched = false;
}

class _UnifiedInventoryPanelState extends ConsumerState<_UnifiedInventoryPanel> {
  String? _selectedStoreId;
  String? _expandedDayKey;
  String? _savingDayKey;
  String _storeSearch = '';
  late Map<String, ServicePricingDraft> _drafts;
  final Map<String, _DayPricingEdit> _dayEdits = {};

  late DateTime _windowStart;
  Map<String, ServiceAvailabilityOverride> _availability = {};
  Map<String, ServicePricingOverride> _dayPricing = {};
  bool _loadingWeek = false;
  bool _savingAll = false;
  VoidCallback? _dialogRebuild;

  static const _lblMale = 'Male';
  static const _lblFemale = 'Female';
  static const _serviceColWidth = 210.0;
  static const _invHome = Color(0xFF6A5ACD);
  static const _gridRowHPadding = 6.0;
  static const _dayColHPadding = 5.0;
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const _days = _weekdayShortNames;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool _isBeforeToday(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.isBefore(_today());
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _windowStart.add(Duration(days: i)));

  DateTime get _windowEnd => _windowStart.add(const Duration(days: 6));

  List<PartnerRecord> get _visibleStores {
    final q = _storeSearch.trim().toLowerCase();
    final stores = widget.partners.where((p) {
      if (q.isEmpty) return true;
      return p.businessName.toLowerCase().contains(q) ||
          p.ownerName.toLowerCase().contains(q);
    }).toList();
    stores.sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return a.businessName.compareTo(b.businessName);
    });
    return stores;
  }

  List<PartnerServiceRecord> get _storeServices {
    if (_selectedStoreId == null) return [];
    return widget.services
        .where((s) => s.partnerId == _selectedStoreId)
        .toList()
      ..sort((a, b) {
        final da = a.createdAt;
        final db = b.createdAt;
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.name.compareTo(b.name);
      });
  }

  PartnerRecord? get _selectedStore => _selectedStoreId == null
      ? null
      : widget.partners
          .where((p) => p.id == _selectedStoreId)
          .firstOrNull;

  int _serviceCountForStore(String partnerId) =>
      widget.services.where((s) => s.partnerId == partnerId).length;

  int get _dirtyCountInStore =>
      _storeServices.where((s) => _drafts[s.id]?.isDirty == true).length;

  String _cellKey(String serviceId, DateTime day) =>
      '$serviceId|${_dateKey(day)}';

  String _dateKey(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _formatDayLabel(DateTime day) {
    return '${_days[day.weekday % 7]}, ${day.day} ${_months[day.month - 1]} ${day.year}';
  }

  _DayPricingEdit _dayEditFor(String serviceId, DateTime day) {
    final key = _cellKey(serviceId, day);
    return _dayEdits.putIfAbsent(key, () {
      final override = _dayPriceOverride(serviceId, day);
      final base = _drafts[serviceId]!;
      final availability = _availability[key];
      final visitType = availability?.visitType;
      return _DayPricingEdit(
        isParlourAvailable: base.isParlourAvailable &&
            (visitType == null ||
                visitType == VisitType.both ||
                visitType == VisitType.parlour),
        isHomeAvailable: base.isHomeAvailable &&
            (visitType == null ||
                visitType == VisitType.both ||
                visitType == VisitType.home),
        parlourPriceMen:
            override != null ? override.parlourPriceMen : base.parlourPriceMen,
        parlourPriceWomen: override != null
            ? override.parlourPriceWomen
            : base.parlourPriceWomen,
        homePriceMen: override != null ? override.homePriceMen : base.homePriceMen,
        homePriceWomen:
            override != null ? override.homePriceWomen : base.homePriceWomen,
        parlourDurationMen: override != null
            ? override.parlourDurationMen
            : base.parlourDurationMen,
        parlourDurationWomen: override != null
            ? override.parlourDurationWomen
            : base.parlourDurationWomen,
        homeDurationMen:
            override != null ? override.homeDurationMen : base.homeDurationMen,
        homeDurationWomen: override != null
            ? override.homeDurationWomen
            : base.homeDurationWomen,
      );
    });
  }

  void _touchDayEdit(_DayPricingEdit edit) {
    setState(() => edit.isDirty = true);
    _dialogRebuild?.call();
  }

  @override
  void initState() {
    super.initState();
    _windowStart = _today();
    _rebuildDrafts();
    if (_visibleStores.isNotEmpty) {
      _selectedStoreId = _visibleStores.first.id;
      _loadWeekInventory();
    }
  }

  @override
  void didUpdateWidget(_UnifiedInventoryPanel old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) {
      _rebuildDrafts();
      if (_selectedStoreId != null &&
          !widget.partners.any((p) => p.id == _selectedStoreId)) {
        _selectedStoreId =
            _visibleStores.isNotEmpty ? _visibleStores.first.id : null;
      }
      _loadWeekInventory();
    }
  }

  void _rebuildDrafts() {
    _drafts = {
      for (final s in widget.services) s.id: _draftFromService(s),
    };
  }

  ServicePricingDraft _draftFromService(PartnerServiceRecord s) {
    return ServicePricingDraft(
      serviceId: s.id,
      partnerId: s.partnerId,
      serviceName: s.name,
      partnerName: s.partnerName,
      category: s.category,
      isParlourAvailable: s.isParlourAvailable,
      parlourPriceMen: s.parlourPriceMen,
      parlourDurationMen: s.parlourDurationMen,
      parlourPriceWomen: s.parlourPriceWomen,
      parlourDurationWomen: s.parlourDurationWomen,
      isHomeAvailable: s.isHomeAvailable,
      homePriceMen: s.homePriceMen,
      homeDurationMen: s.homeDurationMen,
      homePriceWomen: s.homePriceWomen,
      homeDurationWomen: s.homeDurationWomen,
      freeRadiusKm: s.freeRadiusKm,
      perKmCharge: s.perKmCharge,
      discountPrice: s.discountPrice,
    );
  }

  void _selectStore(String storeId) {
    setState(() {
      _selectedStoreId = storeId;
      _expandedDayKey = null;
      _dayEdits.clear();
      _availability = {};
      _dayPricing = {};
    });
    _loadWeekInventory();
  }

  Future<void> _loadWeekInventory() async {
    final storeId = _selectedStoreId;
    if (storeId == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _loadingWeek = true);
    try {
      final data = await ref
          .read(serviceAvailabilityRepositoryProvider)
          .getPartnerWeekInventory(
            callerId: user.id,
            partnerId: storeId,
            startDate: _windowStart,
            endDate: _windowEnd,
          );
      if (!mounted) return;
      setState(() {
        _availability = {
          for (final o in data.availability)
            _cellKey(o.serviceId, o.overrideDate): o,
        };
        _dayPricing = {
          for (final p in data.pricing)
            _cellKey(p.serviceId, p.overrideDate): p,
        };
      });
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not load week: $e');
    } finally {
      if (mounted) setState(() => _loadingWeek = false);
    }
  }

  void _shiftWindow(int days) {
    setState(() {
      _windowStart = _windowStart.add(Duration(days: days));
      _expandedDayKey = null;
      _dayEdits.clear();
      _availability = {};
      _dayPricing = {};
    });
    _loadWeekInventory();
  }

  Future<void> _pickWeekStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _windowStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Select week start date',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _windowStart = DateTime(picked.year, picked.month, picked.day);
      _expandedDayKey = null;
      _dayEdits.clear();
      _availability = {};
      _dayPricing = {};
    });
    await _loadWeekInventory();
  }

  void _toggleDayEditor(String serviceId, DateTime day) {
    final service = _storeServices.where((s) => s.id == serviceId).firstOrNull;
    if (service == null) return;
    _openDayPricingDialog(service, day);
  }

  Widget _buildPricingDialog({
    required Widget child,
  }) {
    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }

  Future<void> _openBasePricingDialog(PartnerServiceRecord service) async {
    final draft = _drafts[service.id]!;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            _dialogRebuild = () => setDialogState(() {});
            return _buildPricingDialog(
              child: _buildPricingEditorShell(
                headerTitle: 'Default rates',
                headerSubtitle: service.name,
                headerIcon: Icons.price_change_outlined,
                onClose: () => Navigator.of(dialogContext).pop(),
                onSave: draft.isDirty && !_savingAll ? _saveAllDirty : null,
                saving: _savingAll,
                dirty: draft.isDirty,
                saveLabel: 'Save',
                child: _buildBasePricingTables(draft),
              ),
            );
          },
        );
      },
    );

    _dialogRebuild = null;
  }

  Future<void> _openDayPricingDialog(
    PartnerServiceRecord service,
    DateTime day,
  ) async {
    final draft = _drafts[service.id]!;
    final key = _cellKey(service.id, day);
    _dayEditFor(service.id, day);

    setState(() {
      _expandedDayKey = key;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            _dialogRebuild = () => setDialogState(() {});
            final edit = _dayEditFor(service.id, day);
            final saving = _savingDayKey == key;
            return _buildPricingDialog(
              child: _buildPricingEditorShell(
                headerTitle: service.name,
                headerSubtitle: _formatDayLabel(day),
                headerIcon: Icons.calendar_today_outlined,
                onClose: () => Navigator.of(dialogContext).pop(),
                onSave: !saving && edit.isDirty
                    ? () async {
                        await _saveDayPricing(service, day);
                        if (mounted) setDialogState(() {});
                      }
                    : null,
                saving: saving,
                dirty: edit.isDirty,
                saveLabel: 'Save',
                child: _buildDayPricingTables(draft, edit),
              ),
            );
          },
        );
      },
    );

    _dialogRebuild = null;
    if (mounted) setState(() => _expandedDayKey = null);
  }

  Future<void> _saveDayPricing(
    PartnerServiceRecord service,
    DateTime day,
  ) async {
    final key = _cellKey(service.id, day);
    final edit = _dayEdits[key] ?? _dayEditFor(service.id, day);
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (!edit.isParlourAvailable && !edit.isHomeAvailable) {
      AppSnackBar.warning(
        context,
        'Select at least one visit type (Parlour or Home).',
      );
      return;
    }

    final existing = _dayPricing[key];
    final draft = _drafts[service.id]!;

    setState(() => _savingDayKey = key);
    try {
      await ref.read(serviceAvailabilityRepositoryProvider).upsertDayPricing(
            callerId: user.id,
            serviceId: service.id,
            date: day,
            parlourPriceMen: edit.isParlourAvailable
                ? edit.parlourPriceMen
                : existing?.parlourPriceMen,
            parlourPriceWomen: edit.isParlourAvailable
                ? edit.parlourPriceWomen
                : existing?.parlourPriceWomen,
            homePriceMen:
                edit.isHomeAvailable ? edit.homePriceMen : existing?.homePriceMen,
            homePriceWomen: edit.isHomeAvailable
                ? edit.homePriceWomen
                : existing?.homePriceWomen,
            parlourDurationMen: edit.isParlourAvailable
                ? edit.parlourDurationMen
                : existing?.parlourDurationMen,
            parlourDurationWomen: edit.isParlourAvailable
                ? edit.parlourDurationWomen
                : existing?.parlourDurationWomen,
            homeDurationMen:
                edit.isHomeAvailable ? edit.homeDurationMen : existing?.homeDurationMen,
            homeDurationWomen: edit.isHomeAvailable
                ? edit.homeDurationWomen
                : existing?.homeDurationWomen,
          );
      final visitType = _visitTypeFromBools(
        parlour: edit.isParlourAvailable && draft.isParlourAvailable,
        home: edit.isHomeAvailable && draft.isHomeAvailable,
      );
      await ref.read(serviceAvailabilityRepositoryProvider).setOverride(
            callerId: user.id,
            serviceId: service.id,
            date: day,
            visitType: visitType,
          );
      if (!mounted) return;
      setState(() {
        edit.isDirty = false;
        _availability[key] = ServiceAvailabilityOverride(
          id: _availability[key]?.id ?? '',
          serviceId: service.id,
          overrideDate: DateTime(day.year, day.month, day.day),
          visitType: visitType,
        );
        _dayPricing[key] = ServicePricingOverride(
          serviceId: service.id,
          overrideDate: day,
          parlourPriceMen:
              edit.isParlourAvailable ? edit.parlourPriceMen : existing?.parlourPriceMen,
          parlourPriceWomen: edit.isParlourAvailable
              ? edit.parlourPriceWomen
              : existing?.parlourPriceWomen,
          homePriceMen:
              edit.isHomeAvailable ? edit.homePriceMen : existing?.homePriceMen,
          homePriceWomen: edit.isHomeAvailable
              ? edit.homePriceWomen
              : existing?.homePriceWomen,
          parlourDurationMen: edit.isParlourAvailable
              ? edit.parlourDurationMen
              : existing?.parlourDurationMen,
          parlourDurationWomen: edit.isParlourAvailable
              ? edit.parlourDurationWomen
              : existing?.parlourDurationWomen,
          homeDurationMen:
              edit.isHomeAvailable ? edit.homeDurationMen : existing?.homeDurationMen,
          homeDurationWomen: edit.isHomeAvailable
              ? edit.homeDurationWomen
              : existing?.homeDurationWomen,
        );
      });
      _dayEdits.remove(key);
      AppSnackBar.success(
        context,
        'Saved prices & duration for ${_formatDayLabel(day)}',
      );
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _savingDayKey = null);
        _dialogRebuild?.call();
      }
    }
  }

  bool _isDayAvailable(String serviceId, DateTime day) {
    final o = _availability[_cellKey(serviceId, day)];
    if (o == null) return false;
    return o.visitType != VisitType.none;
  }

  bool _parlourShownForDay(String serviceId, DateTime day) {
    final draft = _drafts[serviceId];
    if (draft == null || !draft.isParlourAvailable) return false;
    final visitType = _availability[_cellKey(serviceId, day)]?.visitType;
    if (visitType == null) return false;
    return visitType == VisitType.both || visitType == VisitType.parlour;
  }

  bool _homeShownForDay(String serviceId, DateTime day) {
    final draft = _drafts[serviceId];
    if (draft == null || !draft.isHomeAvailable) return false;
    final visitType = _availability[_cellKey(serviceId, day)]?.visitType;
    if (visitType == null) return false;
    return visitType == VisitType.both || visitType == VisitType.home;
  }

  ServicePricingOverride? _dayPriceOverride(String serviceId, DateTime day) =>
      _dayPricing[_cellKey(serviceId, day)];

  _DayCellPrices _pricesForCell(String serviceId, DateTime day) {
    final draft = _drafts[serviceId];
    if (draft == null) return const _DayCellPrices();

    final override = _dayPriceOverride(serviceId, day);
    final hasDayOverride = override != null;
    return _DayCellPrices(
      parlourMen: hasDayOverride
          ? override.parlourPriceMen
          : draft.parlourPriceMen,
      parlourWomen: hasDayOverride
          ? override.parlourPriceWomen
          : draft.parlourPriceWomen,
      homeMen: hasDayOverride ? override.homePriceMen : draft.homePriceMen,
      homeWomen: hasDayOverride ? override.homePriceWomen : draft.homePriceWomen,
      parlourEnabled: _parlourShownForDay(serviceId, day),
      homeEnabled: _homeShownForDay(serviceId, day),
      layoutParlourRow: draft.isParlourAvailable,
      layoutHomeRow: draft.isHomeAvailable,
    );
  }

  Future<void> _toggleDayAvailable(
    String serviceId,
    DateTime day,
    bool value,
  ) async {
    if (_loadingWeek) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final key = _cellKey(serviceId, day);
    final prev = _availability[key];
    final draft = _drafts[serviceId]!;

    setState(() {
      if (value) {
        final visitType = _defaultVisitTypeForDraft(draft);
        _availability[key] = ServiceAvailabilityOverride(
          id: prev?.id ?? '',
          serviceId: serviceId,
          overrideDate: DateTime(day.year, day.month, day.day),
          visitType: visitType,
        );
      } else {
        _availability.remove(key);
      }
    });

    try {
      if (value) {
        await ref.read(serviceAvailabilityRepositoryProvider).setOverride(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              visitType: _defaultVisitTypeForDraft(draft),
            );
      } else {
        await ref.read(serviceAvailabilityRepositoryProvider).setDayAvailable(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              isAvailable: false,
            );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (prev == null) {
          _availability.remove(key);
        } else {
          _availability[key] = prev;
        }
      });
      AppSnackBar.error(context, 'Update failed: $e');
    }
  }

  void openBulkUpdateDialog() => _openBulkUpdateDialog();

  void _openBulkUpdateDialog() {
    final store = _selectedStore;
    if (store == null) return;
    final services = _storeServices;
    if (services.isEmpty) {
      AppSnackBar.warning(context, 'No services in this store.');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _buildPricingDialog(
          child: _BulkUpdateDialog(
            storeName: store.businessName,
            services: services,
            drafts: _drafts,
            onApply: (dates, serviceIds, action, pricing) async {
              await _applyBulkUpdate(
                dates: dates,
                serviceIds: serviceIds,
                action: action,
                pricing: pricing,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _applyBulkUpdate({
    required List<DateTime> dates,
    required List<String> serviceIds,
    required _BulkUpdateAction action,
    _DayPricingEdit? pricing,
  }) async {
    if (dates.isEmpty || serviceIds.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final storeId = _selectedStoreId;
    if (storeId == null) return;

    final repo = ref.read(serviceAvailabilityRepositoryProvider);
    setState(() => _loadingWeek = true);

    try {
      final pricingLookup = Map<String, ServicePricingOverride>.from(_dayPricing);
      if (action == _BulkUpdateAction.updatePrices) {
        final sorted = [...dates]..sort((a, b) => a.compareTo(b));
        final rangeData = await repo.getPartnerWeekInventory(
          callerId: user.id,
          partnerId: storeId,
          startDate: sorted.first,
          endDate: sorted.last,
        );
        for (final p in rangeData.pricing) {
          pricingLookup[_cellKey(p.serviceId, p.overrideDate)] = p;
        }
      }

      for (final serviceId in serviceIds) {
        final draft = _drafts[serviceId];
        for (final day in dates) {
          if (action == _BulkUpdateAction.enable) {
            if (draft == null) continue;
            final enableType = _defaultVisitTypeForDraft(draft);
            await repo.setOverride(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              visitType: enableType,
            );
          } else if (action == _BulkUpdateAction.disable) {
            await repo.setDayAvailable(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              isAvailable: false,
            );
          } else if (action == _BulkUpdateAction.updatePrices) {
            if (pricing == null || draft == null) continue;
            if (!pricing.isParlourAvailable && !pricing.isHomeAvailable) {
              continue;
            }
            final applyParlour =
                pricing.isParlourAvailable && draft.isParlourAvailable;
            final applyHome =
                pricing.isHomeAvailable && draft.isHomeAvailable;
            final visitType = _visitTypeFromBools(
              parlour: applyParlour,
              home: applyHome,
            );
            await repo.setOverride(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              visitType: visitType,
            );
            if (!pricing.pricingFieldsTouched) continue;

            final existing =
                pricingLookup[_cellKey(serviceId, day)];
            await repo.upsertDayPricing(
              callerId: user.id,
              serviceId: serviceId,
              date: day,
              parlourPriceMen: applyParlour
                  ? pricing.parlourPriceMen
                  : (existing?.parlourPriceMen ?? draft.parlourPriceMen),
              parlourPriceWomen: applyParlour
                  ? pricing.parlourPriceWomen
                  : (existing?.parlourPriceWomen ?? draft.parlourPriceWomen),
              homePriceMen: applyHome
                  ? pricing.homePriceMen
                  : (existing?.homePriceMen ?? draft.homePriceMen),
              homePriceWomen: applyHome
                  ? pricing.homePriceWomen
                  : (existing?.homePriceWomen ?? draft.homePriceWomen),
              parlourDurationMen: applyParlour
                  ? pricing.parlourDurationMen
                  : (existing?.parlourDurationMen ?? draft.parlourDurationMen),
              parlourDurationWomen: applyParlour
                  ? pricing.parlourDurationWomen
                  : (existing?.parlourDurationWomen ??
                      draft.parlourDurationWomen),
              homeDurationMen: applyHome
                  ? pricing.homeDurationMen
                  : (existing?.homeDurationMen ?? draft.homeDurationMen),
              homeDurationWomen: applyHome
                  ? pricing.homeDurationWomen
                  : (existing?.homeDurationWomen ?? draft.homeDurationWomen),
            );
          }
        }
      }

      if (!mounted) return;
      _dayEdits.clear();
      await _loadWeekInventory();
      AppSnackBar.success(
        context,
        'Bulk update applied to ${dates.length} date(s)',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(context, 'apply bulk update', e);
      }
    } finally {
      if (mounted) setState(() => _loadingWeek = false);
    }
  }

  Future<void> _saveAllDirty() async {
    final dirty =
        _storeServices.map((s) => _drafts[s.id]!).where((d) => d.isDirty);
    final list = dirty.toList();
    if (list.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _savingAll = true);
    final repo = ref.read(serviceAvailabilityRepositoryProvider);
    var saved = 0;
    try {
      for (final d in list) {
        await repo.updateServicePricing(
          callerId: user.id,
          serviceId: d.serviceId,
          isParlourAvailable: d.isParlourAvailable,
          parlourPriceMen: d.parlourPriceMen,
          parlourDurationMen: d.parlourDurationMen,
          parlourPriceWomen: d.parlourPriceWomen,
          parlourDurationWomen: d.parlourDurationWomen,
          isHomeAvailable: d.isHomeAvailable,
          homePriceMen: d.homePriceMen,
          homeDurationMen: d.homeDurationMen,
          homePriceWomen: d.homePriceWomen,
          homeDurationWomen: d.homeDurationWomen,
          freeRadiusKm: d.freeRadiusKm,
          perKmCharge: d.perKmCharge,
          discountPrice: d.discountPrice,
        );
        d.isDirty = false;
        saved++;
      }
      ref.invalidate(partnerServicesListProvider);
      if (mounted) {
        AppSnackBar.success(context, '$saved base price(s) saved');
        _loadWeekInventory();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _savingAll = false);
        _dialogRebuild?.call();
      }
    }
  }

  void _touchDraft(ServicePricingDraft d) {
    setState(() => d.isDirty = true);
    _dialogRebuild?.call();
  }

  void _openBaseRates(PartnerServiceRecord service) {
    _openBasePricingDialog(service);
  }

  String? _serviceDisplayImage(PartnerServiceRecord service) {
    final primary = service.primaryImage?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final legacy = service.serviceImage?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    if (service.images.isNotEmpty) {
      final first = service.images.first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  Widget _buildPricingEditorShell({
    required String headerTitle,
    String? headerSubtitle,
    IconData headerIcon = Icons.price_change_outlined,
    required VoidCallback onClose,
    required VoidCallback? onSave,
    required bool saving,
    required bool dirty,
    required String saveLabel,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  headerIcon,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (headerSubtitle != null &&
                        headerSubtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        headerSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: saving ? null : onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: child,
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: saving ? null : onClose,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: saving || onSave == null ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        dirty ? Icons.save_outlined : Icons.check_circle_outline,
                        size: 18,
                      ),
                label: Text(dirty ? saveLabel : 'Saved'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      dirty ? AppColors.primary : AppColors.success,
                  disabledBackgroundColor: AppColors.success.withValues(
                    alpha: 0.85,
                  ),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _splitPricingLayout({
    required Widget left,
    required Widget right,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildDayPricingTables(
    ServicePricingDraft draft,
    _DayPricingEdit edit,
  ) {
    return _splitPricingLayout(
      left: _VisitPricingTable(
        title: 'Parlour Visit',
        enabled: edit.isParlourAvailable,
        accent: AppColors.secondary,
        maleAccent: AppColors.textPrimary,
        femaleAccent: AppColors.primary,
        malePrice: edit.parlourPriceMen,
        femalePrice: edit.parlourPriceWomen,
        maleDuration: edit.parlourDurationMen,
        femaleDuration: edit.parlourDurationWomen,
        onEnabledChanged: (v) {
          edit.isParlourAvailable = v;
          _touchDayEdit(edit);
        },
        onMaleChanged: (p, d) {
          edit.parlourPriceMen = p;
          edit.parlourDurationMen = d;
          _touchDayEdit(edit);
        },
        onFemaleChanged: (p, d) {
          edit.parlourPriceWomen = p;
          edit.parlourDurationWomen = d;
          _touchDayEdit(edit);
        },
      ),
      right: _VisitPricingTable(
        title: 'Home Visit',
        enabled: edit.isHomeAvailable,
        accent: _invHome,
        maleAccent: AppColors.textPrimary,
        femaleAccent: AppColors.primary,
        malePrice: edit.homePriceMen,
        femalePrice: edit.homePriceWomen,
        maleDuration: edit.homeDurationMen,
        femaleDuration: edit.homeDurationWomen,
        onEnabledChanged: (v) {
          edit.isHomeAvailable = v;
          _touchDayEdit(edit);
        },
        onMaleChanged: (p, d) {
          edit.homePriceMen = p;
          edit.homeDurationMen = d;
          _touchDayEdit(edit);
        },
        onFemaleChanged: (p, d) {
          edit.homePriceWomen = p;
          edit.homeDurationWomen = d;
          _touchDayEdit(edit);
        },
      ),
    );
  }

  Widget _buildBasePricingTables(ServicePricingDraft draft) {
    return _splitPricingLayout(
      left: _VisitPricingTable(
        title: 'Parlour Visit',
        enabled: draft.isParlourAvailable,
        accent: AppColors.secondary,
        maleAccent: AppColors.textPrimary,
        femaleAccent: AppColors.primary,
        malePrice: draft.parlourPriceMen,
        femalePrice: draft.parlourPriceWomen,
        maleDuration: draft.parlourDurationMen,
        femaleDuration: draft.parlourDurationWomen,
        onEnabledChanged: (v) {
          draft.isParlourAvailable = v;
          _touchDraft(draft);
        },
        onMaleChanged: (p, d) {
          draft.parlourPriceMen = p;
          draft.parlourDurationMen = d;
          _touchDraft(draft);
        },
        onFemaleChanged: (p, d) {
          draft.parlourPriceWomen = p;
          draft.parlourDurationWomen = d;
          _touchDraft(draft);
        },
      ),
      right: _VisitPricingTable(
        title: 'Home Visit',
        enabled: draft.isHomeAvailable,
        accent: _invHome,
        maleAccent: AppColors.textPrimary,
        femaleAccent: AppColors.primary,
        malePrice: draft.homePriceMen,
        femalePrice: draft.homePriceWomen,
        maleDuration: draft.homeDurationMen,
        femaleDuration: draft.homeDurationWomen,
        onEnabledChanged: (v) {
          draft.isHomeAvailable = v;
          _touchDraft(draft);
        },
        onMaleChanged: (p, d) {
          draft.homePriceMen = p;
          draft.homeDurationMen = d;
          _touchDraft(draft);
        },
        onFemaleChanged: (p, d) {
          draft.homePriceWomen = p;
          draft.homeDurationWomen = d;
          _touchDraft(draft);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 260, child: _buildStoreList()),
              Expanded(child: _buildStoreWorkspace()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    final stores = _visibleStores;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'STORES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setState(() => _storeSearch = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search store...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: stores.isEmpty
                ? const Center(
                    child: Text('No stores',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    primary: false,
                    itemCount: stores.length,
                    itemBuilder: (context, i) {
                      final store = stores[i];
                      final selected = _selectedStoreId == store.id;
                      final count = _serviceCountForStore(store.id);
                      return InkWell(
                        onTap: () => _selectStore(store.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.07)
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                              bottom: const BorderSide(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  store.businessName.isNotEmpty
                                      ? store.businessName[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.businessName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      store.ownerName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.12)
                                      : const Color(0xFFEEEEEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreWorkspace() {
    final store = _selectedStore;
    if (store == null) {
      return const Center(
        child: Text('Select a store',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final services = _storeServices;
    final days = _weekDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.07),
                AppColors.secondary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  store.businessName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildWeekNavControls(compact: true),
              const SizedBox(width: 8),
              if (_dirtyCountInStore > 0)
                TextButton(
                  onPressed: _savingAll
                      ? null
                      : () {
                          for (final s in services) {
                            final fresh = widget.services
                                .where((x) => x.id == s.id)
                                .firstOrNull;
                            if (fresh != null) {
                              _drafts[s.id] = _draftFromService(fresh);
                            }
                          }
                          setState(() {});
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Discard', style: TextStyle(fontSize: 12)),
                ),
              if (_dirtyCountInStore > 0 || _savingAll)
                FilledButton(
                  onPressed:
                      _dirtyCountInStore > 0 && !_savingAll ? _saveAllDirty : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _savingAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save $_dirtyCountInStore',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              _LegendChip(
                label: 'Enabled day',
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _LegendChip(
                label: 'Disabled (default)',
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              _LegendChip(
                label: 'Tap cell → edit prices',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _LegendChip(
                label: 'P=Parlour H=Home · M/F prices',
                color: AppColors.secondary,
                border: true,
              ),
              const Spacer(),
              Text(
                '${services.length} services',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (services.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No services in this store.\nAdd services from Partner Services.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else if (_loadingWeek)
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
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
                      _buildWeekHeader(days),
                      Expanded(child: _buildWeekGrid(services, days)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeekNavControls({bool compact = false}) {
    final iconColor = AppColors.primary;
    final textStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    final startLabel =
        '${_windowStart.day} ${_months[_windowStart.month - 1]}';
    final endLabel = '${_windowEnd.day} ${_months[_windowEnd.month - 1]}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact) ...[
            Tooltip(
              message: 'Pick start date',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickWeekStartDate,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 4,
                      top: 6,
                      bottom: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: iconColor,
                        ),
                        const SizedBox(width: 6),
                        Text.rich(
                          TextSpan(
                            style: textStyle,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Previous 7 days',
            icon: Icon(Icons.chevron_left, color: iconColor),
            iconSize: compact ? 22 : 24,
            onPressed: () => _shiftWindow(-7),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: compact ? 32 : 40,
              minHeight: compact ? 32 : 40,
            ),
          ),
          IconButton(
            tooltip: 'Next 7 days',
            icon: Icon(Icons.chevron_right, color: iconColor),
            iconSize: compact ? 22 : 24,
            onPressed: () => _shiftWindow(7),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: compact ? 32 : 40,
              minHeight: compact ? 32 : 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceColumnHeader(String label) {
    return SizedBox(
      width: _serviceColWidth,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _dayColumn(Widget child) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _dayColHPadding),
        child: child,
      ),
    );
  }

  Widget _buildWeekHeader(List<DateTime> days) {
    return Container(
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
      padding: const EdgeInsets.fromLTRB(
        _gridRowHPadding,
        8,
        _gridRowHPadding,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _serviceColumnHeader('Service'),
          for (final day in days)
            _dayColumn(
              _WeekHeaderDay(
                day: day,
                isToday: day.year == _today().year &&
                    day.month == _today().month &&
                    day.day == _today().day,
                isPast: _isBeforeToday(day),
                dayLabel: _days[day.weekday % 7],
                monthLabel: _months[day.month - 1],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekGrid(
    List<PartnerServiceRecord> services,
    List<DateTime> days,
  ) {
    return ListView.builder(
      primary: false,
      physics: const ClampingScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final service = services[i];
        final draft = _drafts[service.id]!;

        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Container(
            color: draft.isDirty
                ? AppColors.primary.withValues(alpha: 0.02)
                : null,
            padding: const EdgeInsets.fromLTRB(
              _gridRowHPadding,
              8,
              _gridRowHPadding,
              8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              _InventoryServiceCell(
                service: service,
                imageUrl: _serviceDisplayImage(service),
                onAddDefaultPrice: () => _openBaseRates(service),
              ),
              for (final day in days)
                _dayColumn(
                  _DayInventoryCell(
                    available: _isDayAvailable(service.id, day),
                    isPast: _isBeforeToday(day),
                    prices: _pricesForCell(service.id, day),
                    isSelected:
                        _expandedDayKey == _cellKey(service.id, day),
                    onToggle: (v) =>
                        _toggleDayAvailable(service.id, day, v),
                    onOpen: () => _toggleDayEditor(service.id, day),
                  ),
                ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _InventoryServiceCell extends StatelessWidget {
  const _InventoryServiceCell({
    required this.service,
    required this.imageUrl,
    required this.onAddDefaultPrice,
  });

  final PartnerServiceRecord service;
  final String? imageUrl;
  final VoidCallback onAddDefaultPrice;

  static const _colWidth = _UnifiedInventoryPanelState._serviceColWidth;
  static const _thumbSize = 38.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _colWidth,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ServiceThumb(url: imageUrl, size: _thumbSize),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 26,
                    child: OutlinedButton(
                      onPressed: onAddDefaultPrice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Add default price',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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

class _ServiceThumb extends StatelessWidget {
  const _ServiceThumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(size),
            )
          : _placeholder(size),
    );
  }

  Widget _placeholder(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.spa_outlined,
        size: size * 0.48,
        color: AppColors.textSecondary.withValues(alpha: 0.7),
      ),
    );
  }
}

class _WeekHeaderDay extends StatelessWidget {
  const _WeekHeaderDay({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.dayLabel,
    required this.monthLabel,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final String dayLabel;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final bg = isToday
        ? AppColors.today
        : isPast
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.surface;
    final border = isToday
        ? AppColors.today
        : isPast
            ? AppColors.error.withValues(alpha: 0.55)
            : AppColors.border;
    final labelColor = isToday
        ? Colors.white70
        : isPast
            ? AppColors.error
            : AppColors.textSecondary;
    final dayColor = isToday
        ? Colors.white
        : isPast
            ? AppColors.error
            : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.today.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : isPast
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
      ),
      child: Column(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: dayColor,
            ),
          ),
          Text(
            monthLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCellPrices {
  const _DayCellPrices({
    this.parlourMen,
    this.parlourWomen,
    this.homeMen,
    this.homeWomen,
    this.parlourEnabled = true,
    this.homeEnabled = false,
    this.layoutParlourRow = true,
    this.layoutHomeRow = false,
  });

  final double? parlourMen;
  final double? parlourWomen;
  final double? homeMen;
  final double? homeWomen;
  /// Visit type active for this day (show real prices when set).
  final bool parlourEnabled;
  final bool homeEnabled;
  /// Fixed rows per service so every day cell has the same height.
  final bool layoutParlourRow;
  final bool layoutHomeRow;

  static const double priceRowHeight = 30;
  static const double rowGap = 5;

  double get priceBlockHeight {
    var h = 0.0;
    if (layoutParlourRow) h += priceRowHeight;
    if (layoutParlourRow && layoutHomeRow) h += rowGap;
    if (layoutHomeRow) h += priceRowHeight;
    return h;
  }
}

class _DayInventoryCell extends StatelessWidget {
  const _DayInventoryCell({
    required this.available,
    required this.isPast,
    required this.prices,
    required this.isSelected,
    required this.onToggle,
    required this.onOpen,
  });

  final bool available;
  final bool isPast;
  final _DayCellPrices prices;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  static const _mintBg = Color(0xFFEAF6EC);
  static const _mintBorder = Color(0xFF81C784);
  static const _disabledBg = Color(0xFFFFEBEE);
  static const _disabledBorder = Color(0xFFE57373);
  static const _plusBlue = Color(0xFF1E88E5);
  static const _parlourColor = Color(0xFF7B1FA2);
  static const _homeColor = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final bg = !available
        ? _disabledBg
        : isSelected
            ? const Color(0xFFE3F2FD)
            : isPast
                ? AppColors.error.withValues(alpha: 0.1)
                : _mintBg;
    final borderColor = isSelected
        ? _plusBlue
        : !available
            ? _disabledBorder
            : isPast
                ? AppColors.error.withValues(alpha: 0.55)
                : _mintBorder;
    final muted = !available;
    final pastEnabled = isPast && available;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onToggle(!available),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: !available
                        ? AppColors.error.withValues(alpha: 0.1)
                        : pastEnabled
                            ? AppColors.error.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: !available
                          ? AppColors.error.withValues(alpha: 0.35)
                          : pastEnabled
                              ? AppColors.error.withValues(alpha: 0.45)
                              : _mintBorder.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DayCheckBadge(
                        active: available,
                        pastDate: isPast,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        available ? 'Disable' : 'Enable',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: !available
                              ? AppColors.error
                              : pastEnabled
                                  ? AppColors.error
                                  : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (prices.layoutParlourRow || prices.layoutHomeRow) ...[
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: prices.priceBlockHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (prices.layoutParlourRow)
                          _CellPricePairRow(
                            muted: muted || !prices.parlourEnabled,
                            left: _CellPriceChip(
                              label: 'PM',
                              price: prices.parlourEnabled
                                  ? prices.parlourMen
                                  : null,
                              accent: _parlourColor,
                              muted: muted || !prices.parlourEnabled,
                            ),
                            right: _CellPriceChip(
                              label: 'PF',
                              price: prices.parlourEnabled
                                  ? prices.parlourWomen
                                  : null,
                              accent: AppColors.primary,
                              muted: muted || !prices.parlourEnabled,
                            ),
                          ),
                        if (prices.layoutParlourRow && prices.layoutHomeRow)
                          const SizedBox(height: _DayCellPrices.rowGap),
                        if (prices.layoutHomeRow)
                          _CellPricePairRow(
                            muted: muted || !prices.homeEnabled,
                            left: _CellPriceChip(
                              label: 'HM',
                              price:
                                  prices.homeEnabled ? prices.homeMen : null,
                              accent: _homeColor,
                              muted: muted || !prices.homeEnabled,
                            ),
                            right: _CellPriceChip(
                              label: 'HF',
                              price:
                                  prices.homeEnabled ? prices.homeWomen : null,
                              accent: const Color(0xFF5C6BC0),
                              muted: muted || !prices.homeEnabled,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CellPricePairRow extends StatelessWidget {
  const _CellPricePairRow({
    required this.left,
    required this.right,
    required this.muted,
  });

  final _CellPriceChip left;
  final _CellPriceChip right;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DayCellPrices.priceRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 5),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _CellPriceChip extends StatelessWidget {
  const _CellPriceChip({
    required this.label,
    required this.price,
    required this.accent,
    required this.muted,
  });

  final String label;
  final double? price;
  final Color accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final value = price != null && price! > 0
        ? '₹${price!.toStringAsFixed(0)}'
        : '—';

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.5 : 0.9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: muted
              ? AppColors.error.withValues(alpha: 0.28)
              : accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              height: 1,
              color: muted ? AppColors.textSecondary : accent,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1,
                color: muted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration: muted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCheckBadge extends StatelessWidget {
  const _DayCheckBadge({
    required this.active,
    this.pastDate = false,
  });

  final bool active;
  final bool pastDate;

  @override
  Widget build(BuildContext context) {
    final activeColor = pastDate
        ? AppColors.error
        : const Color(0xFF43A047);
    final activeBorder = pastDate
        ? AppColors.error
        : const Color(0xFF2E7D32);

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: active
            ? activeColor
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? activeBorder : AppColors.error,
          width: 1.2,
        ),
      ),
      child: active
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}

class _GridPriceCell extends StatefulWidget {
  const _GridPriceCell({
    required this.width,
    required this.enabled,
    required this.price,
    required this.duration,
    required this.accent,
    required this.onChanged,
    this.label,
    this.priceOnly = false,
  });

  final double width;
  final bool enabled;
  final double? price;
  final int? duration;
  final Color accent;
  final void Function(double? price, int? duration) onChanged;
  final String? label;
  final bool priceOnly;

  @override
  State<_GridPriceCell> createState() => _GridPriceCellState();
}

class _GridPriceCellState extends State<_GridPriceCell> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.price?.toStringAsFixed(0) ?? '',
    );
    _durCtrl = TextEditingController(
      text: widget.duration?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(_GridPriceCell old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) return;
    final p = widget.price?.toStringAsFixed(0) ?? '';
    final d = widget.duration?.toString() ?? '';
    if (_priceCtrl.text != p) _priceCtrl.text = p;
    if (!widget.priceOnly && _durCtrl.text != d) _durCtrl.text = d;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged(
      _parsePrice(_priceCtrl.text),
      widget.priceOnly ? null : _parseDuration(_durCtrl.text),
    );
  }

  double? _parsePrice(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  int? _parseDuration(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.label ?? '—',
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: widget.accent,
                ),
              ),
            ),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: widget.accent,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '₹',
              prefixStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accent.withValues(alpha: 0.85),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: widget.accent.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => _emitChange(),
            onEditingComplete: _emitChange,
            onSubmitted: (_) => _emitChange(),
          ),
          if (!widget.priceOnly) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 88,
                child: TextField(
                  controller: _durCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: 'min',
                    suffixStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _emitChange(),
                  onEditingComplete: _emitChange,
                  onSubmitted: (_) => _emitChange(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitPricingTable extends StatelessWidget {
  const _VisitPricingTable({
    required this.title,
    required this.enabled,
    required this.accent,
    required this.maleAccent,
    required this.femaleAccent,
    required this.malePrice,
    required this.femalePrice,
    required this.maleDuration,
    required this.femaleDuration,
    required this.onEnabledChanged,
    required this.onMaleChanged,
    required this.onFemaleChanged,
  });

  final String title;
  final bool enabled;
  final Color accent;
  final Color maleAccent;
  final Color femaleAccent;
  final double? malePrice;
  final double? femalePrice;
  final int? maleDuration;
  final int? femaleDuration;
  final ValueChanged<bool> onEnabledChanged;
  final void Function(double? price, int? duration) onMaleChanged;
  final void Function(double? price, int? duration) onFemaleChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.35) : AppColors.border,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _VisitTypeCheckbox(
              label: title,
              value: enabled,
              color: accent,
              onChanged: onEnabledChanged,
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _GridPriceCell(
                      width: double.infinity,
                      enabled: true,
                      price: malePrice,
                      duration: maleDuration,
                      accent: maleAccent,
                      label: _UnifiedInventoryPanelState._lblMale,
                      onChanged: onMaleChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _GridPriceCell(
                      width: double.infinity,
                      enabled: true,
                      price: femalePrice,
                      duration: femaleDuration,
                      accent: femaleAccent,
                      label: _UnifiedInventoryPanelState._lblFemale,
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

class _VisitTypeCheckbox extends StatelessWidget {
  const _VisitTypeCheckbox({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? color.withValues(alpha: 0.08) : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? color.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                value ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: value ? color : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value ? color : AppColors.textSecondary,
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

enum _BulkUpdateAction { enable, disable, updatePrices }

const _bulkDialogBtnRadius = BorderRadius.all(Radius.circular(5));

class _BulkUpdateDialog extends ConsumerStatefulWidget {
  const _BulkUpdateDialog({
    required this.storeName,
    required this.services,
    required this.drafts,
    required this.onApply,
  });

  final String storeName;
  final List<PartnerServiceRecord> services;
  final Map<String, ServicePricingDraft> drafts;
  final Future<void> Function(
    List<DateTime> dates,
    List<String> serviceIds,
    _BulkUpdateAction action,
    _DayPricingEdit? pricing,
  ) onApply;

  @override
  ConsumerState<_BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends ConsumerState<_BulkUpdateDialog> {
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Set<String> _selectedDateKeys = {};
  final Map<String, ServiceAvailabilityOverride> _monthAvailability = {};
  String? _lastClickedDateKey;
  String? _serviceId;
  _BulkUpdateAction _action = _BulkUpdateAction.enable;
  late _DayPricingEdit _pricingEdit;
  bool _saving = false;
  bool _loadingMonth = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.services.length == 1 ? widget.services.first.id : null;
    _resetPricingFromService(_serviceId);
    _loadMonthAvailability();
  }

  String _monthAvailabilityKey(String serviceId, DateTime day) =>
      '$serviceId|${_dateKey(day)}';

  bool _isDayEnabledInMonth(String? serviceId, DateTime day) {
    if (serviceId != null) {
      final o = _monthAvailability[_monthAvailabilityKey(serviceId, day)];
      return o != null && o.visitType != VisitType.none;
    }
    return widget.services.every((s) {
      final o = _monthAvailability[_monthAvailabilityKey(s.id, day)];
      return o != null && o.visitType != VisitType.none;
    });
  }

  Future<void> _loadMonthAvailability() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final yearMonth =
        '${_displayMonth.year}-${_displayMonth.month.toString().padLeft(2, '0')}';
    final repo = ref.read(serviceAvailabilityRepositoryProvider);

    setState(() => _loadingMonth = true);
    try {
      final results = await Future.wait(
        widget.services.map(
          (service) => repo.getMonthOverrides(
            callerId: user.id,
            serviceId: service.id,
            yearMonth: yearMonth,
          ),
        ),
      );

      if (!mounted) return;
      final map = <String, ServiceAvailabilityOverride>{};
      for (var i = 0; i < widget.services.length; i++) {
        final serviceId = widget.services[i].id;
        for (final override in results[i]) {
          final date = DateTime(
            override.overrideDate.year,
            override.overrideDate.month,
            override.overrideDate.day,
          );
          map[_monthAvailabilityKey(serviceId, date)] = override;
        }
      }

      setState(() => _monthAvailability
        ..clear()
        ..addAll(map));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not load month availability: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + delta,
      );
    });
    _loadMonthAvailability();
  }

  void _resetPricingFromService(String? serviceId) {
    final draft = serviceId != null ? widget.drafts[serviceId] : null;
    _pricingEdit = _DayPricingEdit(
      isParlourAvailable: draft?.isParlourAvailable ?? true,
      isHomeAvailable: draft?.isHomeAvailable ?? false,
      parlourPriceMen: draft?.parlourPriceMen,
      parlourPriceWomen: draft?.parlourPriceWomen,
      homePriceMen: draft?.homePriceMen,
      homePriceWomen: draft?.homePriceWomen,
      parlourDurationMen: draft?.parlourDurationMen,
      parlourDurationWomen: draft?.parlourDurationWomen,
      homeDurationMen: draft?.homeDurationMen,
      homeDurationWomen: draft?.homeDurationWomen,
    )..pricingFieldsTouched = false;
  }

  String _dateKey(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  List<DateTime> get _selectedDates {
    final parsed = _selectedDateKeys.map((k) {
      final p = k.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }).toList();
    parsed.sort((a, b) => a.compareTo(b));
    return parsed;
  }

  List<String> get _targetServiceIds => _serviceId == null
      ? widget.services.map((s) => s.id).toList()
      : [_serviceId!];

  ServicePricingDraft? get _selectedDraft =>
      _serviceId != null ? widget.drafts[_serviceId!] : null;

  DateTime _parseDateKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  void _addSelectableRange(DateTime from, DateTime to) {
    final start = from.isBefore(to) ? from : to;
    final end = from.isAfter(to) ? from : to;
    var cursor = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDate)) {
      if (!_isPastCalendarDay(cursor)) {
        _selectedDateKeys.add(_dateKey(cursor));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  void _onDateTap(
    DateTime day, {
    required bool shiftPressed,
    required bool multiSelectPressed,
  }) {
    if (_isPastCalendarDay(day)) return;
    final key = _dateKey(day);

    setState(() {
      if (shiftPressed && _lastClickedDateKey != null) {
        _addSelectableRange(_parseDateKey(_lastClickedDateKey!), day);
      } else if (multiSelectPressed) {
        if (_selectedDateKeys.contains(key)) {
          _selectedDateKeys.remove(key);
        } else {
          _selectedDateKeys.add(key);
        }
      } else if (_selectedDateKeys.length == 1 && _selectedDateKeys.contains(key)) {
        _selectedDateKeys.clear();
      } else {
        _selectedDateKeys
          ..clear()
          ..add(key);
      }
      _lastClickedDateKey = key;
    });
  }

  void _selectAllInMonth() {
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    setState(() {
      for (var d = 1; d <= daysInMonth; d++) {
        final day = DateTime(_displayMonth.year, _displayMonth.month, d);
        if (!_isPastCalendarDay(day)) {
          _selectedDateKeys.add(_dateKey(day));
        }
      }
    });
  }

  void _clearSelectedDates() {
    setState(() {
      _selectedDateKeys.clear();
      _lastClickedDateKey = null;
    });
  }

  Widget _actionChip({
    required String label,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: AppColors.primary,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: _bulkDialogBtnRadius),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: _saving ? null : (_) => onSelect(),
    );
  }

  Widget _bulkToolbarButton({
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
    IconData? icon,
  }) {
    final enabled = onPressed != null;
    final background = primary && enabled
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.surface;
    final borderColor = !enabled
        ? AppColors.border.withValues(alpha: 0.55)
        : primary
            ? AppColors.primary
            : AppColors.border;
    final foreground = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : primary
            ? AppColors.primary
            : AppColors.textSecondary;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: _bulkDialogBtnRadius,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _bulkDialogBtnRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthNavButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: _bulkDialogBtnRadius,
        side: BorderSide(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: _bulkDialogBtnRadius,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  InputDecoration _bulkFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: _bulkDialogBtnRadius,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: _bulkDialogBtnRadius,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: _bulkDialogBtnRadius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Future<void> _apply() async {
    if (_selectedDates.isEmpty) {
      AppSnackBar.warning(context, 'Select at least one date.');
      return;
    }
    if (_action == _BulkUpdateAction.updatePrices && _serviceId == null) {
      AppSnackBar.warning(context, 'Select one service to update prices.');
      return;
    }
    if (_action == _BulkUpdateAction.updatePrices &&
        !_pricingEdit.isParlourAvailable &&
        !_pricingEdit.isHomeAvailable) {
      AppSnackBar.warning(
        context,
        'Select at least one visit type (Parlour or Home).',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onApply(
        _selectedDates,
        _targetServiceIds,
        _action,
        _action == _BulkUpdateAction.updatePrices ? _pricingEdit : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.actionFailed(context, 'apply bulk update', e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 720,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bulk update',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.storeName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _serviceId,
                          decoration: _bulkFieldDecoration('Service'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All services'),
                            ),
                            for (final s in widget.services)
                              DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) => setState(() {
                                    _serviceId = v;
                                    _resetPricingFromService(v);
                                  }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: _bulkDialogBtnRadius,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              _monthNavButton(
                                icon: Icons.chevron_left,
                                onTap: _saving ? null : () => _shiftMonth(-1),
                              ),
                              Expanded(
                                child: Text(
                                  '${monthNames[_displayMonth.month]} ${_displayMonth.year}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _monthNavButton(
                                icon: Icons.chevron_right,
                                onTap: _saving ? null : () => _shiftMonth(1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: _bulkDialogBtnRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${_selectedDateKeys.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const TextSpan(text: ' date(s) selected'),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _bulkToolbarButton(
                                  label: 'Select all',
                                  icon: Icons.done_all_rounded,
                                  primary: true,
                                  onPressed:
                                      _saving ? null : _selectAllInMonth,
                                ),
                                const SizedBox(width: 6),
                                _bulkToolbarButton(
                                  label: 'Clear',
                                  icon: Icons.clear_rounded,
                                  onPressed: _saving ||
                                          _selectedDateKeys.isEmpty
                                      ? null
                                      : _clearSelectedDates,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click = one date · Ctrl+click = multi · Shift+click = range',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: _bulkDialogBtnRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _BulkCalendarLegendDot(
                          color: Color(0xFF81C784),
                          label: 'Enabled',
                        ),
                        const _BulkCalendarLegendDot(
                          color: AppColors.error,
                          label: 'Disabled',
                        ),
                        const _BulkCalendarLegendDot(
                          color: AppColors.today,
                          label: 'Today',
                        ),
                        Text(
                          'Past dates cannot be selected',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.error.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: _bulkDialogBtnRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      children: [
                        _BulkMonthGrid(
                          month: _displayMonth,
                          selectedKeys: _selectedDateKeys,
                          serviceId: _serviceId,
                          isDayEnabled: _isDayEnabledInMonth,
                          onDateTap: _onDateTap,
                        ),
                        if (_loadingMonth)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.65),
                                borderRadius: _bulkDialogBtnRadius,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionChip(
                        label: 'Enable',
                        selected: _action == _BulkUpdateAction.enable,
                        onSelect: () =>
                            setState(() => _action = _BulkUpdateAction.enable),
                      ),
                      _actionChip(
                        label: 'Disable',
                        selected: _action == _BulkUpdateAction.disable,
                        onSelect: () =>
                            setState(() => _action = _BulkUpdateAction.disable),
                      ),
                      _actionChip(
                        label: 'Update prices',
                        selected: _action == _BulkUpdateAction.updatePrices,
                        onSelect: () => setState(
                          () => _action = _BulkUpdateAction.updatePrices,
                        ),
                      ),
                    ],
                  ),
                  if (_action == _BulkUpdateAction.updatePrices) ...[
                    const SizedBox(height: 12),
                    if (_selectedDraft == null)
                      const Text(
                        'Select one service above to set prices.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _VisitPricingTable(
                              title: 'Parlour Visit',
                              enabled: _pricingEdit.isParlourAvailable,
                              accent: AppColors.secondary,
                              maleAccent: AppColors.textPrimary,
                              femaleAccent: AppColors.primary,
                              malePrice: _pricingEdit.parlourPriceMen,
                              femalePrice: _pricingEdit.parlourPriceWomen,
                              maleDuration: _pricingEdit.parlourDurationMen,
                              femaleDuration: _pricingEdit.parlourDurationWomen,
                              onEnabledChanged: (v) => setState(() {
                                _pricingEdit.isParlourAvailable = v;
                              }),
                              onMaleChanged: (p, d) => setState(() {
                                _pricingEdit.pricingFieldsTouched = true;
                                _pricingEdit.parlourPriceMen = p;
                                _pricingEdit.parlourDurationMen = d;
                              }),
                              onFemaleChanged: (p, d) => setState(() {
                                _pricingEdit.pricingFieldsTouched = true;
                                _pricingEdit.parlourPriceWomen = p;
                                _pricingEdit.parlourDurationWomen = d;
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _VisitPricingTable(
                              title: 'Home Visit',
                              enabled: _pricingEdit.isHomeAvailable,
                              accent: const Color(0xFF6A5ACD),
                              maleAccent: AppColors.textPrimary,
                              femaleAccent: AppColors.primary,
                              malePrice: _pricingEdit.homePriceMen,
                              femalePrice: _pricingEdit.homePriceWomen,
                              maleDuration: _pricingEdit.homeDurationMen,
                              femaleDuration: _pricingEdit.homeDurationWomen,
                              onEnabledChanged: (v) => setState(() {
                                _pricingEdit.isHomeAvailable = v;
                              }),
                              onMaleChanged: (p, d) => setState(() {
                                _pricingEdit.pricingFieldsTouched = true;
                                _pricingEdit.homePriceMen = p;
                                _pricingEdit.homeDurationMen = d;
                              }),
                              onFemaleChanged: (p, d) => setState(() {
                                _pricingEdit.pricingFieldsTouched = true;
                                _pricingEdit.homePriceWomen = p;
                                _pricingEdit.homeDurationWomen = d;
                              }),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: _bulkDialogBtnRadius,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _apply,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Apply bulk update'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: _bulkDialogBtnRadius,
                    ),
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

bool _isPastCalendarDay(DateTime day) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final d = DateTime(day.year, day.month, day.day);
  return d.isBefore(todayDate);
}

class _BulkCalendarLegendDot extends StatelessWidget {
  const _BulkCalendarLegendDot({
    required this.color,
    required this.label,
  });

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
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _BulkMonthGrid extends StatelessWidget {
  const _BulkMonthGrid({
    required this.month,
    required this.selectedKeys,
    required this.serviceId,
    required this.isDayEnabled,
    required this.onDateTap,
  });

  final DateTime month;
  final Set<String> selectedKeys;
  final String? serviceId;
  final bool Function(String? serviceId, DateTime day) isDayEnabled;
  final void Function(
    DateTime day, {
    required bool shiftPressed,
    required bool multiSelectPressed,
  }) onDateTap;

  static const _enabledBg = Color(0xFFEAF6EC);
  static const _enabledBorder = Color(0xFF81C784);
  static const _enabledText = Color(0xFF2E7D32);
  static const _disabledBg = Color(0xFFFFEBEE);
  static const _disabledBorder = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((startOffset + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 4,
          mainAxisSpacing: 0,
          childAspectRatio: 3.6,
          children: _weekdayShortNames
              .map(
                (d) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.35,
            crossAxisSpacing: 4,
            mainAxisSpacing: 3,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, index) {
            final dayNum = index - startOffset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNum);
            final dayName = _weekdayShortNames[day.weekday % 7];
            final key =
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final selected = selectedKeys.contains(key);
            final isToday = day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;
            final isPast = _isPastCalendarDay(day);
            final enabled = !isPast && isDayEnabled(serviceId, day);

            final Color bg;
            final Color borderColor;
            final Color textColor;

            if (isPast) {
              bg = _disabledBg.withValues(alpha: 0.55);
              borderColor = _disabledBorder.withValues(alpha: 0.35);
              textColor = AppColors.error.withValues(alpha: 0.45);
            } else if (selected) {
              bg = enabled ? _enabledBg : _disabledBg;
              borderColor = AppColors.primary;
              textColor = enabled ? _enabledText : AppColors.error;
            } else if (enabled) {
              bg = _enabledBg;
              borderColor = _enabledBorder;
              textColor = _enabledText;
            } else {
              bg = _disabledBg;
              borderColor = _disabledBorder;
              textColor = AppColors.error;
            }

            return MouseRegion(
              cursor: isPast
                  ? SystemMouseCursors.forbidden
                  : SystemMouseCursors.click,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isPast
                      ? null
                      : () {
                          final keyboard = HardwareKeyboard.instance;
                          onDateTap(
                            day,
                            shiftPressed: keyboard.isShiftPressed,
                            multiSelectPressed: keyboard.isControlPressed ||
                                keyboard.isMetaPressed,
                          );
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday && !isPast
                            ? AppColors.today
                            : borderColor,
                        width: selected || (isToday && !isPast) ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: isToday && !isPast
                                ? AppColors.today.withValues(alpha: 0.85)
                                : textColor.withValues(alpha: 0.75),
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isToday && !isPast
                                ? AppColors.today
                                : textColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
