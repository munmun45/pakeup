import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_schedule_models.dart';

class PartnerOpenHoursSection extends StatelessWidget {
  const PartnerOpenHoursSection({
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
    onChanged([
      for (final s in schedules)
        if (s.dayOfWeek == result.dayOfWeek) result else s,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < schedules.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          InkWell(
            onTap: () => _editDay(context, schedules[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      schedules[i].dayShortLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
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
              title: const Text('Opens'),
              trailing: Text(DaySchedule.formatTime(_open)),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _open,
                );
                if (t != null) setState(() => _open = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Closes'),
              trailing: Text(DaySchedule.formatTime(_close)),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _close,
                );
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
