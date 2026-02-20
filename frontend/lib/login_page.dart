import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'auth_service.dart';
import 'core/navigation/route_error_manager.dart';
import 'l10n/app_localizations.dart';
import 'pages/staff_onboarding_page.dart';
import 'widgets/phone_login_widget.dart';

// Brand colors extracted from the FlowShift logo
const _kNavy = Color(0xFF1B2544);
const _kNavyLight = Color(0xFF243056);
const _kYellow = Color(0xFFFFD600);
const _kYellowMuted = Color(0xFFFFC107);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  bool _loadingEmail = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loadingGoogle = true;
      _error = null;
    });
    String? err;
    final ok = await AuthService.signInWithGoogle(onError: (m) => err = m);
    if (!mounted) return;

    final googleFailedMsg = AppLocalizations.of(context)!.googleSignInFailed;
    setState(() {
      _loadingGoogle = false;
      if (!ok) {
        final errorMsg = err?.trim() ?? googleFailedMsg;
        _error = errorMsg.isEmpty ? googleFailedMsg : errorMsg;
      }
    });

    if (ok && mounted) {
      await RouteErrorManager.instance.navigateSafely(
        context,
        () => const StaffOnboardingGate(),
        clearStack: true,
      );
    }
  }

  Future<void> _handleApple() async {
    setState(() {
      _loadingApple = true;
      _error = null;
    });
    final ok = await AuthService.signInWithApple();
    setState(() {
      _loadingApple = false;
      if (!ok) _error = AppLocalizations.of(context)!.appleSignInFailed;
    });
    if (ok && mounted) {
      await RouteErrorManager.instance.navigateSafely(
        context,
        () => const StaffOnboardingGate(),
        clearStack: true,
      );
    }
  }

  Future<void> _handleEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.pleaseEnterEmailAndPassword);
      return;
    }
    setState(() {
      _loadingEmail = true;
      _error = null;
    });
    String? err;
    final ok = await AuthService.signInWithEmail(
      email: email,
      password: password,
      onError: (m) => err = m,
    );
    if (!mounted) return;
    setState(() {
      _loadingEmail = false;
      if (!ok) _error = err ?? AppLocalizations.of(context)!.emailSignInFailed;
    });
    if (ok && mounted) {
      await RouteErrorManager.instance.navigateSafely(
        context,
        () => const StaffOnboardingGate(),
        clearStack: true,
      );
    }
  }

  void _handlePhone() {
    setState(() => _error = null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: PhoneLoginWidget(
          onSuccess: () {
            Navigator.pop(sheetContext);
            RouteErrorManager.instance.navigateSafely(
              context,
              () => const StaffOnboardingGate(),
              clearStack: true,
            );
          },
          onCancel: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bool showApple = Platform.isIOS;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kNavy, _kNavyLight, Color(0xFF2A3A68)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/logo_icon_square.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Brand Name
                      Text(
                        l10n.flowShiftStaff,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.signInToContinue,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Auth Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Error Banner
                            if (_error != null && _error!.trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Google Sign In Button
                            _SocialButton(
                              onPressed: _loadingGoogle ? null : _handleGoogle,
                              loading: _loadingGoogle,
                              icon: Icons.g_mobiledata_rounded,
                              iconSize: 28,
                              label: l10n.continueWithGoogle,
                              backgroundColor: _kNavy,
                              foregroundColor: Colors.white,
                            ),

                            if (showApple) ...[
                              const SizedBox(height: 12),
                              _SocialButton(
                                onPressed: _loadingApple ? null : _handleApple,
                                loading: _loadingApple,
                                icon: Icons.apple,
                                label: l10n.continueWithApple,
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ],

                            const SizedBox(height: 12),
                            _SocialButton(
                              onPressed: _handlePhone,
                              icon: Icons.phone_android,
                              label: l10n.continueWithPhone,
                              backgroundColor: Colors.transparent,
                              foregroundColor: _kNavy,
                              outlined: true,
                            ),

                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider(height: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      l10n.orSignInWithEmail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(height: 1)),
                                ],
                              ),
                            ),

                            // Email field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                hintText: l10n.email,
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _kNavy, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleEmail(),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.lock_outlined,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                hintText: l10n.password,
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _kNavy, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Sign In button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _loadingEmail ? null : _handleEmail,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kYellow,
                                  foregroundColor: _kNavy,
                                  disabledBackgroundColor: _kYellow.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loadingEmail
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: _kNavy,
                                        ),
                                      )
                                    : Text(
                                        l10n.signIn,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer
                      Text(
                        '${l10n.bySigningInYouAgree}\n${l10n.termsOfService} ${l10n.andWord} ${l10n.privacyPolicy}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
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

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool outlined;

  const _SocialButton({
    required this.onPressed,
    this.loading = false,
    required this.icon,
    this.iconSize = 22,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _buildContent(),
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                disabledBackgroundColor: backgroundColor.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: foregroundColor,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
