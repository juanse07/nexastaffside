import 'package:flutter/material.dart';

import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  String? _error;

  Future<void> _handleGoogle() async {
    setState(() {
      _loadingGoogle = true;
      _error = null;
    });
    final ok = await AuthService.signInWithGoogle();
    setState(() {
      _loadingGoogle = false;
      if (!ok) _error = 'Google sign-in failed';
    });
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _handleApple() async {
    setState(() {
      _loadingApple = true;
      _error = null;
    });
    final ok = await AuthService.signInWithApple();
    setState(() {
      _loadingApple = false;
      if (!ok) _error = 'Apple sign-in failed';
    });
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Image.asset('assets/appbar_logo.png', height: 44)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _loadingGoogle ? null : _handleGoogle,
                icon: _loadingGoogle
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _loadingGoogle ? 'Signing in...' : 'Continue with Google',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _loadingApple ? null : _handleApple,
                icon: _loadingApple
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apple),
                label: Text(
                  _loadingApple ? 'Signing in...' : 'Continue with Apple',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
