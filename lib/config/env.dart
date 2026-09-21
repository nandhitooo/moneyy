import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Akses terpusat ke nilai di file `.env`.
class Env {
  static String get appName => dotenv.maybeGet('APP_NAME') ?? 'Catatan Keuangan';

  static bool get enableDevicePreview => _bool('ENABLE_DEVICE_PREVIEW');

  static bool get useFirebaseEmulator => _bool('USE_FIREBASE_EMULATOR');

  static String get emulatorHost => dotenv.maybeGet('FIREBASE_EMULATOR_HOST') ?? 'localhost';

  static int get firestorePort => _int('FIRESTORE_EMULATOR_PORT', 8080);

  static int get authPort => _int('AUTH_EMULATOR_PORT', 9099);

  static bool _bool(String key) => (dotenv.maybeGet(key) ?? 'false').toLowerCase() == 'true';

  static int _int(String key, int fallback) =>
      int.tryParse(dotenv.maybeGet(key) ?? '') ?? fallback;
}
