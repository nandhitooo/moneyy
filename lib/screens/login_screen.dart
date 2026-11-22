import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Pesan dari AuthService sudah ramah pengguna, cukup buang prefix
  /// `Exception:` bawaan Dart.
  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      // AuthGate akan otomatis pindah ke HomeScreen setelah login berhasil.
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() => _isLogin
        ? _auth.signIn(_email.text, _password.text)
        : _auth.register(_email.text, _password.text));
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LoginHeader(),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Masuk ke akunmu' : 'Buat akun baru',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Masukkan email yang valid'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isLogin
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        onFieldSubmitted: (_) {
                          if (!_loading) unawaited(_submit());
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Tampilkan password'
                                : 'Sembunyikan password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimal 6 karakter'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorCard(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const _ButtonSpinner()
                            : Text(_isLogin ? 'Masuk' : 'Daftar'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                        ),
                        child: Text(
                          _isLogin
                              ? 'Belum punya akun? Daftar'
                              : 'Sudah punya akun? Masuk',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tanda aplikasi: satu kotak berwarna aksen, tanpa bayangan.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 30,
            color: cs.onPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Catatan Keuangan',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
      ],
    );
  }
}

/// Error sebagai garis tipis berwarna, bukan kartu penuh.
class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
