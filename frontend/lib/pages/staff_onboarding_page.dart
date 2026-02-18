import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/route_error_manager.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import 'root_page.dart';

class StaffOnboardingGate extends StatefulWidget {
  const StaffOnboardingGate({super.key});

  @override
  State<StaffOnboardingGate> createState() => _StaffOnboardingGateState();
}

class _StaffOnboardingGateState extends State<StaffOnboardingGate> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print('[ONBOARDING GATE] Loading profile...');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await UserService.getMe();
      if (!mounted) return;

      print('[ONBOARDING GATE] Profile loaded: '
          'firstName=${profile.firstName}, '
          'lastName=${profile.lastName}, '
          'phone=${profile.phoneNumber}');

      // Initialize notifications after authentication
      print('[ONBOARDING GATE] Initializing notifications...');
      try {
        await NotificationService().initialize();
        print('[ONBOARDING GATE] ✅ Notifications initialized successfully');
      } catch (e) {
        print('[ONBOARDING GATE] ❌ Failed to initialize notifications: $e');
      }

      // Initialize subscription service (Qonversion)
      print('[ONBOARDING GATE] Initializing subscription...');
      try {
        await SubscriptionService().initialize();
        print('[ONBOARDING GATE] ✅ Subscription initialized successfully');
      } catch (e) {
        print('[ONBOARDING GATE] ❌ Failed to initialize subscription: $e');
      }

      setState(() {
        _profile = profile;
        _loading = false;
      });

      print('[ONBOARDING GATE] Profile complete: ${_isProfileComplete(profile)}');
    } catch (e) {
      print('[ONBOARDING GATE ERROR] Failed to load profile: $e');

      // If user doesn't exist or auth failed, sign out and go to login
      if (e.toString().contains('404') ||
          e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        print('[ONBOARDING GATE] Auth error - signing out');
        await _signOut();
        return;
      }

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isProfileComplete(UserProfile profile) {
    final firstName = profile.firstName?.trim();
    final lastName = profile.lastName?.trim();
    final phoneNumber = profile.phoneNumber?.trim();

    final isComplete = (firstName?.isNotEmpty ?? false) &&
        (lastName?.isNotEmpty ?? false) &&
        (phoneNumber?.isNotEmpty ?? false);

    print('[ONBOARDING GATE] Checking completion: '
        'firstName="${firstName ?? 'null'}" (${firstName?.isNotEmpty ?? false}), '
        'lastName="${lastName ?? 'null'}" (${lastName?.isNotEmpty ?? false}), '
        'phone="${phoneNumber ?? 'null'}" (${phoneNumber?.isNotEmpty ?? false}), '
        'complete=$isComplete');

    return isComplete;
  }

  Future<void> _signOut() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_jwt');
    if (!mounted) return;
    await RouteErrorManager.instance.pushNamedSafely(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProfile,
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If profile is complete, show main app
    if (_isProfileComplete(profile)) {
      return const RootPage();
    }

    // Otherwise, show onboarding
    return _OnboardingScreen(
      profile: profile,
      onComplete: _loadProfile,
      onSignOut: _signOut,
    );
  }
}

// Brand colors matching login page
const _kNavy = Color(0xFF1B2544);
const _kNavyMid = Color(0xFF243056);
const _kNavyLight = Color(0xFF2A3A68);
const _kYellow = Color(0xFFFFD600);

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({
    required this.profile,
    required this.onComplete,
    required this.onSignOut,
  });

  final UserProfile profile;
  final VoidCallback onComplete;
  final VoidCallback onSignOut;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _appIdController = TextEditingController();

  int _currentStep = 0;
  bool _saving = false;
  String? _error;

  late final List<AnimationController> _stepAnimControllers;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.profile.firstName ?? '';
    _lastNameController.text = widget.profile.lastName ?? '';
    _phoneController.text = widget.profile.phoneNumber ?? '';
    _appIdController.text = widget.profile.appId ?? '';

    _stepAnimControllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
    });

    _fadeAnimations = _stepAnimControllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();

    _slideAnimations = _stepAnimControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();

    // Animate first step in
    _stepAnimControllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _appIdController.dispose();
    for (final c in _stepAnimControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step > 2) return;
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _stepAnimControllers[step].forward(from: 0);
  }

  void _goBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.fieldIsRequired(fieldName);
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.phoneNumberIsRequired;
    }
    final phoneRegex = RegExp(r'^(\d{3}-\d{3}-\d{4}|\d{10})$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return l10n.enterValidUSPhoneNumber;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final fn = _firstNameController.text.trim();
      final ln = _lastNameController.text.trim();
      final pn = _phoneController.text.trim();

      await UserService.updateMe(
        firstName: fn,
        lastName: ln,
        phoneNumber: pn,
        appId: _appIdController.text.trim().isEmpty
            ? null
            : _appIdController.text.trim(),
      );

      // Default tab is always Roles (0)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('default_tab', 0);

      if (!mounted) return;

      setState(() => _saving = false);
      _goToStep(2);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  bool get _isNavyBackground => _currentStep == 0 || _currentStep == 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: _isNavyBackground
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kNavy, _kNavyMid, _kNavyLight],
                  stops: [0.0, 0.45, 1.0],
                )
              : null,
          color: _isNavyBackground ? null : Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back arrow, dots, sign out
              _buildTopBar(),
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(),
                    _buildProfileStep(),
                    _buildDoneStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button (hidden on step 0)
          if (_currentStep == 1)
            IconButton(
              onPressed: _goBack,
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: _isNavyBackground ? Colors.white : _kNavy,
              ),
            )
          else
            const SizedBox(width: 48),
          // Step dots
          Expanded(child: _buildStepDots()),
          // Sign out
          TextButton(
            onPressed: widget.onSignOut,
            child: Text(
              AppLocalizations.of(context)!.signOut,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isNavyBackground
                    ? Colors.white.withValues(alpha: 0.7)
                    : _kNavy.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentStep;
        final isCompleted = i < _currentStep;
        Color dotColor;
        if (isActive) {
          dotColor = _kYellow;
        } else if (isCompleted) {
          dotColor = _kYellow.withValues(alpha: 0.5);
        } else {
          dotColor = _isNavyBackground
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.grey.shade300;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  // --------------- Step 0: Welcome ---------------

  Widget _buildWelcomeStep() {
    return FadeTransition(
      opacity: _fadeAnimations[0],
      child: SlideTransition(
        position: _slideAnimations[0],
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
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
                const SizedBox(height: 32),
                const Text(
                  'Welcome to FlowShift',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Let's get you set up in just a few steps",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildYellowButton(
                  label: 'Get Started',
                  onPressed: () => _goToStep(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------- Step 1: Profile ---------------

  Widget _buildProfileStep() {
    final l10n = AppLocalizations.of(context)!;
    return FadeTransition(
      opacity: _fadeAnimations[1],
      child: SlideTransition(
        position: _slideAnimations[1],
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Your Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _kNavy,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pleaseCompleteProfileToGetStarted,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                _buildStyledField(
                  controller: _firstNameController,
                  hint: l10n.enterYourFirstName,
                  label: l10n.firstNameLabel,
                  icon: Icons.person_outline,
                  action: TextInputAction.next,
                  validator: (v) => _validateRequired(v, l10n.firstName),
                ),
                const SizedBox(height: 16),
                _buildStyledField(
                  controller: _lastNameController,
                  hint: l10n.enterYourLastName,
                  label: l10n.lastNameLabel,
                  icon: Icons.person_outline,
                  action: TextInputAction.next,
                  validator: (v) => _validateRequired(v, l10n.lastName),
                ),
                const SizedBox(height: 16),
                _buildStyledField(
                  controller: _phoneController,
                  hint: l10n.phoneNumberHint,
                  label: l10n.phoneNumberLabel,
                  icon: Icons.phone_outlined,
                  action: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  helperText: l10n.phoneNumberFormat,
                ),
                const SizedBox(height: 16),
                _buildStyledField(
                  controller: _appIdController,
                  hint: l10n.enterYourAppId,
                  label: l10n.appIdOptional,
                  icon: Icons.badge_outlined,
                  action: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.requiredFields,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.shade200, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
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
                ],
                const SizedBox(height: 24),
                _buildYellowButton(
                  label: 'Finish Setup',
                  loading: _saving,
                  onPressed: _saving ? null : _saveProfile,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------- Step 2: All Done ---------------

  Widget _buildDoneStep() {
    return FadeTransition(
      opacity: _fadeAnimations[2],
      child: SlideTransition(
        position: _slideAnimations[2],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: _kYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "You're All Set!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your profile is ready. Time to get to work!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildYellowButton(
                  label: "Let's Go",
                  onPressed: widget.onComplete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------- Shared widgets ---------------

  Widget _buildYellowButton({
    required String label,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _kYellow,
          foregroundColor: _kNavy,
          disabledBackgroundColor: _kYellow.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _kNavy,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    TextInputAction action = TextInputAction.next,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: action,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
