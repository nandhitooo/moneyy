# Graph Report - catatan_keuangan  (2026-09-21)

## Corpus Check
- Corpus is ~5,902 words - fits in a single context window. You may not need a graph.

## Summary
- 237 nodes · 279 edges · 18 communities (12 shown, 6 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.58)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- UI Home & Filter
- Runner Linux
- Layanan Firebase
- Form & Auth UI
- Form Transaksi
- Inisialisasi App
- Config Environment
- Model Transaksi
- Statistik Chart
- Widget Reusable
- Util Format & Ikon
- MainActivity Android
- Navigasi Halaman
- Linter Config
- FlutterFire Config

## God Nodes (most connected - your core abstractions)
1. `_MyApplication` - 7 edges
2. `my_application_local_command_line()` - 4 edges
3. `TransactionModel` - 3 edges
4. `AddTransactionScreen` - 3 edges
5. `_AddTransactionScreenState` - 3 edges
6. `HomeScreen` - 3 edges
7. `_HomeScreenState` - 3 edges
8. `LoginScreen` - 3 edges
9. `_LoginScreenState` - 3 edges
10. `fl_register_plugins()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Panduan Setup Firebase` --references--> `Aturan Keamanan Firestore`  [EXTRACTED]
  README.md → firestore.rules
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/runner/main.cc → linux/runner/my_application.cc

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Alur Data Transaksi** — lib_main, lib_services_auth_service, lib_services_transaction_service, lib_models_transaction_model, config_firestore_rules, doc_readme_data_model [INFERRED]

## Communities (18 total, 6 thin omitted)

### Community 0 - "UI Home & Filter"
Cohesion: 0.05
Nodes (40): add_transaction_screen.dart, Color, IconData, balance, _carry, _categoryFilter, _changeMonth, color (+32 more)

### Community 1 - "Runner Linux"
Cohesion: 0.08
Nodes (26): FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx, generated_plugin_registrant (+18 more)

### Community 2 - "Layanan Firebase"
Cohesion: 0.08
Nodes (24): Aturan Keamanan Firestore, README Catatan Keuangan, Struktur Data Firestore, Fitur: Login & Kategori, Panduan Setup Firebase, _auth, AuthService, _googleSignIn (+16 more)

### Community 3 - "Form & Auth UI"
Cohesion: 0.09
Nodes (23): FormState, AddTransactionScreen, _AddTransactionScreenState, HomeScreen, _HomeScreenState, _auth, build, createState (+15 more)

### Community 4 - "Form Transaksi"
Cohesion: 0.09
Nodes (22): bool get, _amount, build, _categories, _category, createState, _date, dispose (+14 more)

### Community 5 - "Inisialisasi App"
Cohesion: 0.11
Nodes (18): Platform Android, Ikon Aplikasi (5 resolusi), config/env.dart, Metadata Project Flutter, firebase_options.dart, build, _buildTheme, initializeApp (+10 more)

### Community 6 - "Config Environment"
Cohesion: 0.13
Nodes (14): Template Environment (.env.example), appName, authPort, _bool, emulatorHost, enableDevicePreview, Env, firestorePort (+6 more)

### Community 7 - "Model Transaksi"
Cohesion: 0.13
Nodes (14): amount, category, date, expenseCategories, fromDoc, id, incomeCategories, note (+6 more)

### Community 8 - "Statistik Chart"
Cohesion: 0.18
Nodes (10): DateTime, build, _colors, month, StatsScreen, transactions, List, package:fl_chart/fl_chart.dart (+2 more)

### Community 9 - "Widget Reusable"
Cohesion: 0.18
Nodes (11): AuthGate, MyApp, _CategoryFilterBar, _EmptyState, _MiniStat, _MonthSelector, _NoResult, _SearchField (+3 more)

### Community 10 - "Util Format & Ikon"
Cohesion: 0.20
Nodes (9): categoryIcon, dateFmt, expenseColor, incomeColor, monthFmt, rupiah, thousandFmt, package:flutter/material.dart (+1 more)

### Community 12 - "Navigasi Halaman"
Cohesion: 0.67
Nodes (3): build, _openForm, MaterialPageRoute

## Knowledge Gaps
- **121 isolated node(s):** `Env`, `appName`, `enableDevicePreview`, `useFirebaseEmulator`, `emulatorHost` (+116 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 160 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Template Environment (.env.example)` connect `Config Environment` to `Inisialisasi App`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `TransactionModel` connect `Model Transaksi` to `UI Home & Filter`, `Form Transaksi`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `Struktur Data Firestore` connect `Layanan Firebase` to `Model Transaksi`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **What connects `Env`, `appName`, `enableDevicePreview` to the rest of the system?**
  _121 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `UI Home & Filter` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._
- **Should `Runner Linux` be split into smaller, more focused modules?**
  _Cohesion score 0.08172043010752689 - nodes in this community are weakly interconnected._
- **Should `Layanan Firebase` be split into smaller, more focused modules?**
  _Cohesion score 0.08307692307692308 - nodes in this community are weakly interconnected._