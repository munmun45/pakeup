part of 'partner_inventory_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  AVAILABILITY CALENDAR TAB
// ══════════════════════════════════════════════════════════════════

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab({required this.services});
  final List<PartnerServiceRecord> services;

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  PartnerServiceRecord? _selectedService;
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, ServiceAvailabilityOverride> _overridesByDate = {};
  bool _loadingOverrides = false;
  bool _saving = false;

  String get _yearMonth =>
      '${_displayMonth.year}-${_displayMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    if (widget.services.isNotEmpty) {
      _selectedService = widget.services.first;
      _loadOverrides();
    }
  }

  @override
  void didUpdateWidget(_CalendarTab old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services &&
        _selectedService == null &&
        widget.services.isNotEmpty) {
      _selectedService = widget.services.first;
      _loadOverrides();
    }
  }

  Future<void> _loadOverrides() async {
    if (_selectedService == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _loadingOverrides = true);
    try {
      final overrides = await ref
          .read(serviceAvailabilityRepositoryProvider)
          .getMonthOverrides(
            callerId: user.id,
            serviceId: _selectedService!.id,
            yearMonth: _yearMonth,
          );
      setState(() {
        _overridesByDate = {
          for (final o in overrides)
            '${o.overrideDate.year}-${o.overrideDate.month.toString().padLeft(2, '0')}-${o.overrideDate.day.toString().padLeft(2, '0')}':
                o,
        };
      });
    } finally {
      setState(() => _loadingOverrides = false);
    }
  }

  Future<void> _onDayTapped(DateTime day) async {
    if (_selectedService == null) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final current = _overridesByDate[key];

    final next = _nextVisitType(current?.visitType);

    setState(() => _saving = true);
    try {
      final repo = ref.read(serviceAvailabilityRepositoryProvider);
      if (next == null) {
        await repo.clearOverride(
          callerId: user.id,
          serviceId: _selectedService!.id,
          date: day,
        );
        setState(() {
          _overridesByDate.remove(key);
        });
      } else {
        await repo.setOverride(
          callerId: user.id,
          serviceId: _selectedService!.id,
          date: day,
          visitType: next,
        );
        setState(() {
          _overridesByDate[key] = ServiceAvailabilityOverride(
            id: current?.id ?? '',
            serviceId: _selectedService!.id,
            overrideDate: day,
            visitType: next,
          );
        });
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Cycles: null → None → Parlour → Home → Both → null
  VisitType? _nextVisitType(VisitType? current) {
    switch (current) {
      case null:
        return VisitType.none;
      case VisitType.none:
        return VisitType.parlour;
      case VisitType.parlour:
        return VisitType.home;
      case VisitType.home:
        return VisitType.both;
      case VisitType.both:
        return null;
    }
  }

  void _goMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
      _overridesByDate = {};
    });
    _loadOverrides();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) {
      return const Center(
        child: Text(
          'No services. Add services first.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Service List panel ───────────────────────────────
        SizedBox(
          width: 280,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: const Color(0xFFFAF8FA),
                  child: const Text(
                    'SELECT SERVICE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: widget.services.length,
                    itemBuilder: (context, i) {
                      final s = widget.services[i];
                      final selected = _selectedService?.id == s.id;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedService = s);
                          _loadOverrides();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : Colors.transparent,
                            border: selected
                                ? const Border(
                                    left: BorderSide(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                  )
                                : const Border(
                                    left: BorderSide(
                                      color: Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
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
                                s.partnerName,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Calendar panel ───────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _LegendChip(
                      color: AppColors.surface,
                      label: 'Available (Default)',
                      border: true,
                    ),
                    _LegendChip(
                      color: const Color(0xFFFF4D4D).withValues(alpha: 0.85),
                      label: 'Unavailable',
                    ),
                    _LegendChip(
                      color: const Color(0xFF8E54E9).withValues(alpha: 0.8),
                      label: 'Parlour Only',
                    ),
                    _LegendChip(
                      color: const Color(0xFF44A0E3).withValues(alpha: 0.85),
                      label: 'Home Only',
                    ),
                    _LegendChip(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.85),
                      label: 'Both (Override)',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap a date to cycle: Default → Unavailable → Parlour Only → Home Only → Both → Default',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Month navigation
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _goMonth(-1),
                      tooltip: 'Previous Month',
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _monthLabel(_displayMonth),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _goMonth(1),
                      tooltip: 'Next Month',
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Day-of-week header
                Row(
                  children:
                      const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 6),

                // Calendar grid
                _loadingOverrides
                    ? const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Expanded(child: _buildCalendarGrid()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final startOffset = firstDay.weekday % 7; // Sun=0
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = DateTime(_displayMonth.year, _displayMonth.month, dayNum);
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final override = _overridesByDate[key];

        final isToday =
            day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;

        return _DayCell(
          day: dayNum,
          availabilityOverride: override,
          isToday: isToday,
          onTap: () => _onDayTapped(day),
        );
      },
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month]} ${d.year}';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.availabilityOverride,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final ServiceAvailabilityOverride? availabilityOverride;
  final bool isToday;
  final VoidCallback onTap;

  Color _bgColor() {
    if (availabilityOverride == null) return AppColors.surface;
    return switch (availabilityOverride!.visitType) {
      VisitType.none => const Color(0xFFFF4D4D).withValues(alpha: 0.85),
      VisitType.parlour => const Color(0xFF8E54E9).withValues(alpha: 0.8),
      VisitType.home => const Color(0xFF44A0E3).withValues(alpha: 0.85),
      VisitType.both => const Color(0xFF2ECC71).withValues(alpha: 0.85),
    };
  }

  Color _textColor() {
    if (availabilityOverride == null) return AppColors.textPrimary;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? AppColors.primary
                : availabilityOverride != null
                ? Colors.transparent
                : AppColors.border,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                color: _textColor(),
              ),
            ),
            if (availabilityOverride != null)
              Text(
                _shortLabel(availabilityOverride!.visitType),
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white70,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortLabel(VisitType t) {
    switch (t) {
      case VisitType.none:
        return 'OFF';
      case VisitType.parlour:
        return 'PARLOUR';
      case VisitType.home:
        return 'HOME';
      case VisitType.both:
        return 'BOTH';
    }
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    this.border = false,
  });

  final Color color;
  final String label;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: border ? Colors.transparent : color,
              shape: BoxShape.circle,
              border: border ? Border.all(color: color, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
