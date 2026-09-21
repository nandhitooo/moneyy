import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env.dart';

/// Menyiapkan Firebase sekali di awal aplikasi.
///
/// Koneksi ke Firebase Emulator Suite hanya dilakukan pada build non-release
/// supaya data asli tidak pernah tersentuh dari build debug.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kReleaseMode || !Env.useFirebaseEmulator) return;

    final host = Env.emulatorHost;
    FirebaseAuth.instance.useAuthEmulator(host, Env.authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, Env.firestorePort);

    debugPrint('Firebase Emulator aktif di $host '
        '(auth: ${Env.authPort}, firestore: ${Env.firestorePort})');
  }
}
