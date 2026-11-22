import 'package:catatan_keuangan/models/funding_source.dart';
import 'package:catatan_keuangan/services/transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

FundingSource _source({
  int amount = 6500,
  int? day = 25,
  String? posted,
}) =>
    FundingSource(
      id: 'bank1',
      name: 'Rekening Bank',
      adminFee: amount,
      adminFeeDay: day,
      adminFeePosted: posted,
    );

void main() {
  group('FundingSource.adminFeePendingMonth', () {
    test('belum jatuh tempo berarti belum dicatat', () {
      final source = _source();

      expect(source.adminFeePendingMonth(DateTime(2026, 11, 24)), isNull);
    });

    test('pada tanggal bayar biaya admin dicatat', () {
      final source = _source();

      expect(source.adminFeePendingMonth(DateTime(2026, 11, 25)), '2026-11');
    });

    test('setelah tanggal bayar tetap dicatat untuk bulan berjalan', () {
      final source = _source();

      expect(source.adminFeePendingMonth(DateTime(2026, 11, 30)), '2026-11');
    });

    test('bulan yang sudah tercatat tidak dicatat lagi', () {
      final source = _source(posted: '2026-11');

      expect(source.adminFeePendingMonth(DateTime(2026, 11, 25)), isNull);
      // Bulan berikutnya tetap perlu dicatat lagi.
      expect(source.adminFeePendingMonth(DateTime(2026, 12, 25)), '2026-12');
    });

    test('tanpa nominal atau tanggal tidak ada yang dicatat', () {
      expect(_source(amount: 0).adminFeePendingMonth(DateTime(2026, 11, 26)),
          isNull);
      expect(_source(day: null).adminFeePendingMonth(DateTime(2026, 11, 26)),
          isNull);
    });

    test('tanggal 31 jatuh tempo di hari terakhir bulan pendek', () {
      final source = _source(day: 31);

      expect(source.adminFeePendingMonth(DateTime(2026, 2, 27)), isNull);
      expect(source.adminFeePendingMonth(DateTime(2026, 2, 28)), '2026-02');
    });

    test('kunci bulan selalu dua digit', () {
      expect(FundingSource.monthKey(2026, 1), '2026-01');
      expect(FundingSource.monthKey(2026, 11), '2026-11');
    });
  });

  group('TransactionService.adminFeeDocId', () {
    test('id tetap untuk sumber dan bulan yang sama', () {
      final first = TransactionService.adminFeeDocId('bank1', '2026-11');
      final second = TransactionService.adminFeeDocId('bank1', '2026-11');

      expect(first, second);
      expect(first, contains('bank1'));
      expect(first, contains('2026-11'));
    });

    test('bulan berbeda menghasilkan id berbeda', () {
      expect(
        TransactionService.adminFeeDocId('bank1', '2026-11'),
        isNot(TransactionService.adminFeeDocId('bank1', '2026-12')),
      );
    });
  });
}
