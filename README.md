# Catatan Keuangan (Flutter + Firebase)

Fitur: login/daftar (Firebase Auth), catat pemasukan & pengeluaran (Cloud Firestore, realtime),
ringkasan saldo per bulan, edit, geser untuk hapus, dan statistik pengeluaran per kategori.

## Cara menjalankan

1. Buat project Flutter baru lalu timpa file-nya:
   ```
   flutter create catatan_keuangan
   ```
   Salin folder `lib/` dan `pubspec.yaml` dari zip ini ke dalam project tersebut.

2. Buat project di https://console.firebase.google.com, lalu aktifkan:
   - **Authentication → Sign-in method → Email/Password**
   - **Firestore Database** (mulai dalam production mode)

3. Hubungkan app ke Firebase (menghasilkan `lib/firebase_options.dart`):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

4. Siapkan environment:
   ```
   cp .env.example .env
   ```
   Isi `.env` mengatur Device Preview (`ENABLE_DEVICE_PREVIEW`), nama app, dan opsi Firebase Emulator.
   File `.env` sudah masuk `.gitignore`. Salin juga `.gitignore` dari zip ini ke root project.

5. Deploy aturan dan composite index ke Firestore (aturan mencakup subkoleksi
   `sources` dan `meta`):
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   Cara manual: tempel isi `firestore.rules` ke **Firestore → Rules**, lalu Publish,
   dan buat index dari `firestore.indexes.json` di tab **Indexes**.

   Index di file itu **wajib**, bukan opsional: saldo per sumber dana dan saldo
   awal bulan dihitung dengan agregasi `sum()`, dan Firestore menghitung agregasi
   lewat index scan sehingga field yang dijumlahkan harus sepaket dengan field
   filternya (lihat bagian **Struktur data**). Tanpa index tersebut, pemuatan
   saldo gagal dengan `failed-precondition` dan aplikasi turun ke perhitungan di
   perangkat. Index baru butuh beberapa menit untuk selesai dibangun.

6. Android: di `android/app/build.gradle(.kts)` pastikan `minSdk` minimal 23.

7. Jalankan:
   ```
   flutter pub get
   flutter run
   ```

## Struktur data

```
users/{uid}/transactions/{id}
  title, amount (int, Rupiah), type ("income" | "expense"),
  category, date (Timestamp), note,
  sourceId, sourceName, sourceIsCash,
  createdAt, updatedAt

users/{uid}/sources/{id}
  name, isCash (bool), createdAt
```

`sourceName` dan `sourceIsCash` disalin dari sumber dana saat transaksi dibuat,
sehingga transaksi lama tetap punya keterangan walau sumbernya diubah atau
dihapus. Transaksi yang dibuat sebelum fitur sumber dana ada akan tampil sebagai
**Belum diisi** dan bisa diubah lewat form transaksi.

Setiap transaksi menyimpan `signedAmount` (pemasukan positif, pengeluaran
negatif). Agregasi saldo memakai field itu:

- saldo awal bulan: `sum(signedAmount)` dengan filter `date`;
- saldo per sumber dana: `sum(signedAmount)` dengan filter `sourceId`.

Agregasi `sum()` **tidak** dihitung dari dokumen, melainkan dari index, jadi
field yang dijumlahkan harus berada di index yang sama dengan field filternya.
Artinya composite index tetap dibutuhkan — `firestore.indexes.json` bukan file
kosong, dan isinya harus di-deploy:

- `date` + `signedAmount` — saldo awal bulan;
- `sourceId` + `amount` dan `sourceId` + `signedAmount` — saldo per sumber dana.

Pemasukan dan pengeluaran per sumber dipulihkan dari `sum(amount)` (arus dana)
dan `sum(signedAmount)` (saldo bersih).

Transaksi lama yang belum punya `signedAmount` diisi otomatis sekali saat pertama
dibuka; penanda selesai disimpan di `users/{uid}/meta/migration`.

## Struktur kode

```
lib/
  config/    env, theme, theme_controller, bootstrap Firebase (termasuk emulator)
  models/    TransactionModel, MonthSummary, FundingSource, SourceBreakdown
  screens/   auth_gate, login, home, add_transaction, stats, sources
  services/  auth_service, transaction_service
  utils/     helpers (format & warna), thousands_input_formatter
  widgets/   komponen UI yang dipakai ulang antar layar
```

## Jika saldo gagal dimuat

Bila agregasi ditolak, aplikasi otomatis menghitung saldo di perangkat supaya
angka tetap tampil, dan menandainya dengan catatan kecil "Saldo dihitung di
perangkat karena agregasi Firestore belum siap." Penyebabnya dicetak lengkap
di konsol `flutter run` (termasuk tautan pembuatan index dari Firestore).

Banner kegagalan menampilkan pesan teknisnya dalam teks kecil yang bisa
disalin. Penyebab yang paling sering:

- **`permission-denied`** — aturan Firestore belum di-deploy:
  `firebase deploy --only firestore:rules`. Aturan harus mencakup subkoleksi
  `sources` dan `meta`.
- **`failed-precondition`** — composite index belum di-deploy atau belum selesai
  dibangun. Jalankan `firebase deploy --only firestore:indexes`, lalu tunggu
  sampai index berstatus **Enabled** di Firestore → Indexes. Pesan lengkapnya di
  konsol memuat tautan pembuatan index.
- **`unavailable`** — koneksi internet. Muat ulang dengan tombol refresh.

Query saldo per sumber sengaja tidak memakai filter `sourceId == null`.
Transaksi tanpa sumber dihitung sebagai selisih total keseluruhan dengan jumlah
seluruh sumber yang diketahui.

## Perilaku UI

- Sumber dana ditandai per transaksi: tunai atau non-tunai (rekening bank, e-wallet).
  Nama sumber bebas ditambahkan pengguna lewat tombol **Kelola**; tiga sumber
  bawaan (Tunai, Rekening Bank, E-Wallet) dibuat otomatis saat pertama dibuka.
- Halaman **Sumber Dana** menampilkan saldo tiap sumber (pemasukan dikurangi
  pengeluaran sepanjang waktu), total saldo, dan pecahan tunai / non-tunai.
  Angka dihitung dengan agregasi Firestore, jadi tidak mengunduh dokumen
  transaksi. Hasil agregasi bukan realtime: tarik daftar ke bawah atau pakai
  tombol muat ulang untuk memperbarui.
- Transaksi lama tanpa sumber (dan transaksi yatim) dikelompokkan sebagai
  **Belum diisi**, dihitung dari selisih total keseluruhan.
- Sumber dana yang masih dipakai transaksi tidak bisa dihapus; ubah dulu sumber
  transaksi tersebut supaya tidak ada data yatim.
- Daftar transaksi bisa disaring per kategori dan per sumber dana.
- Kartu ringkasan di home dibagi dua bagian berdampingan: statistik bulan
  (Dari bulan lalu, Pemasukan, Pengeluaran) di kiri dan rincian saldo tiap
  sumber dana di kanan; tombol **Kelola** membuka halaman Sumber Dana. Kalau
  kolomnya terlalu sempit, kedua bagian kembali ditumpuk. Pemisahan ini membuat
  kartu jauh lebih pendek, supaya header home tidak overflow di layar pendek.
- Geser transaksi ke kiri untuk menghapus; tersedia tombol **Urungkan** pada snackbar.
- Seluruh isi layar home menggulir dalam satu `CustomScrollView`: pemilih bulan,
  kartu ringkasan, kolom pencarian, bar filter, dan daftar transaksi. Karena
  tidak ada lagi header berukuran tetap, halaman ini tidak bisa lagi melaporkan
  `bottom overflowed` walau kartu ringkasan memanjang.
- Tarik ke bawah di mana pun (pull-to-refresh) atau pakai **Muat ulang** di
  menu overflow untuk memuat ulang transaksi, saldo bulan lalu, dan saldo per
  sumber.
- AppBar home hanya memuat tiga action: ikon **Statistik**, menu overflow berisi
  **Muat ulang** dan **Keluar**, dan tombol tema. Batas tiga itu disengaja:
  di layar 360dp judul hanya dapat `360 - 48 x jumlah action - 32` = 184dp,
  sedangkan "Catatan Keuangan" pada `titleLarge` butuh 180dp. Action keempat
  memangkasnya jadi 136dp dan judul terpotong.
- Tombol tema di AppBar (ikon bulan/matahari) memilih tema gelap atau terang
  secara eksplisit. Pilihan itu hanya tersimpan di memori, jadi kembali
  mengikuti tema sistem setiap aplikasi dijalankan ulang (lihat
  `config/theme_controller.dart`).
- Label bulan di pemilih bulan bisa diketuk untuk membuka **pemilih bulan**:
  navigasi tahun di atas, lalu 12 bulan dalam 4 baris, jadi bisa melompat ke
  bulan mana pun dalam beberapa ketukan tanpa menekan tombol maju/mundur
  berulang kali. Tersedia juga **Batal** dan **Bulan ini**. Tombol maju/mundur
  tetap bekerja untuk geser satu bulan.
- Kolom jumlah otomatis memberi pemisah ribuan sambil mengetik.
- Kategori dan sumber dana di form transaksi dipilih lewat **dropdown**
  (`CategoryPicker` dan `SourcePicker`). Daftar kategori mengikuti tipe
  transaksi, dan dropdown sumber dana selalu menawarkan **Belum diisi** supaya
  transaksi lama bisa dikosongkan lagi. Tombol gerigi di dropdown sumber dana
  membuka halaman **Sumber Dana**. Transaksi baru tetap otomatis memakai sumber
  tunai pertama, tetapi pengisian otomatis itu berhenti begitu sumbernya dipilih
  sendiri supaya pilihan **Belum diisi** tidak ditimpa.
- Form transaksi memperingatkan bila ditutup saat masih ada perubahan.

## Device Preview

Dengan `ENABLE_DEVICE_PREVIEW=true` di `.env`, app tampil di dalam frame perangkat dan panel
pengaturannya (ganti perangkat, orientasi, mode gelap, ukuran teks). Cocok dijalankan di
Chrome/desktop: `flutter run -d chrome`. Fitur ini otomatis mati di build release.

## Firebase Emulator (opsional)

Set `USE_FIREBASE_EMULATOR=true` di `.env`, lalu jalankan `firebase emulators:start --only auth,firestore`
agar development tidak menyentuh data asli. Untuk Android emulator, host-nya `10.0.2.2`.
