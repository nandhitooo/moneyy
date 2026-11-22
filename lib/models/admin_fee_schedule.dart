/// Jadwal biaya admin bulanan satu sumber dana.
///
/// Hanya menyimpan nominal dan tanggal potong; kelas ini tidak membuat
/// transaksi. Tanggal potong yang tidak ada di suatu bulan (mis. 31 di bulan
/// 30 hari) memakai hari terakhir bulan itu.
class AdminFeeSchedule {
  /// Biaya admin per bulan dalam Rupiah.
  final int amount;

  /// Tanggal potong tiap bulan, 1 sampai 31.
  final int dayOfMonth;

  const AdminFeeSchedule({required this.amount, required this.dayOfMonth})
      : assert(amount >= 0),
        assert(dayOfMonth >= 1 && dayOfMonth <= 31);

  /// True bila nominalnya lebih dari nol.
  bool get isActive => amount > 0;

  /// Tanggal potong pada [year]-[month].
  ///
  /// Bulan yang lebih pendek memakai hari terakhirnya, jadi tanggal 31 di
  /// Februari menjadi 28 atau 29.
  DateTime dateInMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dayOfMonth > lastDay ? lastDay : dayOfMonth);
  }

  /// Pemotongan berikutnya pada atau setelah [from].
  ///
  /// [from] dihitung per tanggal, sehingga jam dan menit tidak memengaruhi
  /// hasilnya.
  DateTime nextDate(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final thisMonth = dateInMonth(today.year, today.month);
    if (!thisMonth.isBefore(today)) return thisMonth;
    return dateInMonth(today.year, today.month + 1);
  }

  /// Selisih hari ke pemotongan berikutnya; 0 berarti hari ini.
  int daysUntil(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    return nextDate(from).difference(today).inDays;
  }

  /// Saldo setelah biaya admin dipotong. Boleh negatif bila saldonya kurang.
  int balanceAfter(int balance) => balance - amount;
}
