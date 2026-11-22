import 'package:catatan_keuangan/models/admin_fee_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminFeeSchedule', () {
    test('memakai tanggal potong bulan berjalan', () {
      const schedule = AdminFeeSchedule(amount: 6500, dayOfMonth: 25);

      expect(schedule.nextDate(DateTime(2026, 11, 3)), DateTime(2026, 11, 25));
      expect(schedule.daysUntil(DateTime(2026, 11, 3)), 22);
    });

    test('hari potong hari ini tetap dihitung hari ini', () {
      const schedule = AdminFeeSchedule(amount: 6500, dayOfMonth: 25);

      expect(schedule.nextDate(DateTime(2026, 11, 25)), DateTime(2026, 11, 25));
      expect(schedule.daysUntil(DateTime(2026, 11, 25)), 0);
    });

    test('setelah tanggal lewat, pindah ke bulan berikutnya', () {
      const schedule = AdminFeeSchedule(amount: 6500, dayOfMonth: 25);

      expect(schedule.nextDate(DateTime(2026, 11, 26)), DateTime(2026, 12, 25));
      expect(schedule.nextDate(DateTime(2026, 12, 26)), DateTime(2027, 1, 25));
    });

    test('tanggal 31 memakai hari terakhir bulan yang lebih pendek', () {
      const schedule = AdminFeeSchedule(amount: 10000, dayOfMonth: 31);

      expect(schedule.dateInMonth(2026, 2), DateTime(2026, 2, 28));
      expect(schedule.dateInMonth(2028, 2), DateTime(2028, 2, 29));
      expect(schedule.dateInMonth(2026, 4), DateTime(2026, 4, 30));
      expect(schedule.nextDate(DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
    });

    test('saldo setelah potong mengurangi nominal biaya', () {
      const schedule = AdminFeeSchedule(amount: 6500, dayOfMonth: 25);

      expect(schedule.balanceAfter(100000), 93500);
      expect(schedule.balanceAfter(5000), -1500);
    });
  });
}
