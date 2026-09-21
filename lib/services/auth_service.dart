import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw _message(e);
    }
  }

  Future<void> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw _message(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      // Pengguna menutup dialog/batal memilih akun -> bukan error, cukup hentikan flow.
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      // idToken wajib ada untuk membuat credential Firebase.
      // Jika null, biasanya konfigurasi SHA-1 / google-services.json tidak cocok.
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        await _googleSignIn.signOut();
        throw 'Gagal mendapatkan token Google. Periksa konfigurasi SHA-1 di Firebase Console.';
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await _googleSignIn.signOut();
      throw _message(e);
    } on Exception catch (e) {
      // Batal memilih akun (dialog ditutup) bukan error yang perlu ditampilkan.
      if (e.toString().contains('sign_in_cancelled') ||
          e.toString().contains('kSignInCanceledError') ||
          e.toString().contains('canceled')) {
        return;
      }
      await _googleSignIn.signOut();
      throw 'Login Google gagal. Silakan coba lagi.';
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Abaikan kegagalan sign out Google, tetap lanjut sign out Firebase.
    }
    await _auth.signOut();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah (minimal 6 karakter).';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'account-exists-with-different-credential':
        return 'Akun sudah terdaftar dengan metode login lain.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'operation-not-allowed':
        return 'Login Google belum diaktifkan di Firebase Console.';
      default:
        return 'Terjadi kesalahan: ${e.message ?? e.code}';
    }
  }
}
