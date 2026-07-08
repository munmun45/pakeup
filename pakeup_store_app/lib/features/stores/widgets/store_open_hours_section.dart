import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/store_schedule_models.dart';

class StoreOpenHoursSection extends StatelessWidget {
  const StoreOpenHoursSection({
    super.key,
    required this.schedules,
    required this.onChanged,
  });

  final List<DaySchedule> schedules;
  final ValueChanged<List<DaySchedule>> onChanged;

  Future<void> _editDay(BuildContext context, DaySchedule day) async {
    final result = await showDialog<DaySchedule>(
      context: context,
      builder: (ctx) => _DayScheduleDialog(schedule: day),
    );
    if (result == null) return;
    final next = [
      for (final s in schedules)
        if (s.dayOfWeek == result.dayOfWeek) result else s,
    ];
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < schedules.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          _DayRow(
            schedule: schedules[i],
            onTap: () => _editDay(context, schedules[i]),
          ),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.schedule, required this.onTap});

  final DaySchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = schedule.isClosed;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                schedule.dayShortLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                schedule.summary,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: closed
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              closed ? Icons.block_rounded : Icons.schedule_rounded,
              size: 16,
              color: closed ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayScheduleDialog extends StatefulWidget {
  const _DayScheduleDialog({required this.schedule});

  final DaySchedule schedule;

  @override
  State<_DayScheduleDialog> createState() => _DayScheduleDialogState();
}

class _DayScheduleDialogState extends State<_DayScheduleDialog> {
  late bool _closed;
  late TimeOfDay _open;
  late TimeOfDay _close;

  @override
  void initState() {
    super.initState();
    _closed = widget.schedule.isClosed;
    _open = widget.schedule.openTime ?? const TimeOfDay(hour: 9, minute: 0);
    _close = widget.schedule.closeTime ?? const TimeOfDay(hour: 21, minute: 0);
  }

  Future<TimeOfDay?> _pick(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.schedule.dayLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Closed this day'),
            value: _closed,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _closed = v),
          ),
          if (!_closed) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.login_rounded, color: AppColors.primary),
              title: const Text('Opens'),
              trailing: Text(
                DaySchedule.formatTime(_open),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                final t = await _pick(_open);
                if (t != null) setState(() => _open = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: AppColors.secondary),
              title: const Text('Closes'),
              trailing: Text(
                DaySchedule.formatTime(_close),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                final t = await _pick(_close);
                if (t != null) setState(() => _close = t);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              DaySchedule(
                dayOfWeek: widget.schedule.dayOfWeek,
                openTime: _closed ? null : _open,
                closeTime: _closed ? null : _close,
                isClosed: _closed,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
