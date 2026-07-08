import 'package:flutter_test/flutter_test.dart';
import 'package:pakeup_admin/features/partners/models/service_availability_models.dart';

void main() {
  test('parseOverrideDate normalizes to local date only', () {
    final d = parseOverrideDate('2026-07-14');
    expect(d.year, 2026);
    expect(d.month, 7);
    expect(d.day, 14);
    expect(d.hour, 0);
    expect(d.minute, 0);
  });

  test('ServiceAvailabilityOverride.fromJson tolerates missing id', () {
    final o = ServiceAvailabilityOverride.fromJson({
      'service_id': 'abc-123',
      'override_date': '2026-07-09',
      'visit_type': 'None',
    });

    expect(o.id, '');
    expect(o.serviceId, 'abc-123');
    expect(o.visitType, VisitType.none);
  });

  test('ServiceAvailabilityOverride.fromJson parses full row', () {
    final o = ServiceAvailabilityOverride.fromJson({
      'id': 'row-id',
      'service_id': 'svc-id',
      'override_date': '2026-07-09',
      'visit_type': 'None',
      'note': null,
    });

    expect(o.id, 'row-id');
    expect(o.visitType, VisitType.none);
  });
}
