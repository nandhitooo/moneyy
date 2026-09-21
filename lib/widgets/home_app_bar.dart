import 'package:flutter/material.dart';

import '../config/theme_controller.dart';

/// Aksi yang dipindah dari AppBar ke menu overflow.
enum HomeMenuAction { refresh, logout }

/// AppBar layar home: statistik, menu overflow, dan tombol tema.
///
/// Dipisah dari halaman supaya tata letaknya bisa diuji.
///
/// Anggaran lebarnya ketat di layar 360dp: judul hanya dapat
/// `360 - 48 x jumlah action - 32` (48dp per action, 16dp jarak tiap sisi).
/// Judul "Catatan Keuangan" di `titleLarge` (22sp) butuh 180dp - diukur dengan
/// Roboto asli - jadi action dibatasi **tiga**. Dengan empat action ruangnya
/// tinggal 136dp dan judul terpotong. Karena itu "Muat ulang" dan "Keluar"
/// dipindah ke menu overflow; "Muat ulang" tetap bisa dicapai lewat geser ke
/// bawah (pull-to-refresh).
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenStats;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const HomeAppBar({
    super.key,
    required this.onOpenStats,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Catatan Keuangan',
        maxLines: 1,
        // Jaring pengaman kalau skala teks sistem diperbesar.
        overflow: TextOverflow.ellipsis,
      ),
      titleSpacing: 16,
      actions: [
        IconButton(
          tooltip: 'Statistik',
          icon: const Icon(Icons.pie_chart_outline),
          onPressed: onOpenStats,
        ),
        PopupMenuButton<HomeMenuAction>(
          tooltip: 'Menu lainnya',
          onSelected: (action) {
            switch (action) {
              case HomeMenuAction.refresh:
                onRefresh();
              case HomeMenuAction.logout:
                onLogout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: HomeMenuAction.refresh,
              child: _MenuItem(icon: Icons.refresh, label: 'Muat ulang'),
            ),
            PopupMenuItem(
              value: HomeMenuAction.logout,
              child: _MenuItem(icon: Icons.logout, label: 'Keluar'),
            ),
          ],
        ),
        const ThemeToggleButton(),
      ],
    );
  }
}

/// Isi satu baris menu overflow: ikon dan labelnya.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

/// Tombol pengganti tema untuk AppBar.
///
/// Memakai tombol ikon, bukan `Switch`. `Switch` selebar ~52dp plus jaraknya
/// membuat anggaran action membengkak dan judul ikut terpotong, sedangkan
/// tombol ikon cukup satu slot selebar ikon lain.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Dibaca dari tema aktif, bukan dari ThemeController, supaya saat mode
    // system yang gelap ikonnya sudah menunjukkan tema yang sedang dipakai.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Ganti ke tema terang' : 'Ganti ke tema gelap',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ThemeController.instance.setDark(!isDark),
    );
  }
}
