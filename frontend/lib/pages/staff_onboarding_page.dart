import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_service.dart';
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
    Navigator.of(context).pushReplacementNamed('/login');
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
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProfile,
                    child: const Text('Retry'),
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

class _OnboardingScreenState extends State<_OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _appIdController = TextEditingController();

  bool _saving = false;
  String? _error;
  int _selectedDefaultTab = 0; // 0=Clock In, 1=Roles, 2=Earnings, 3=Team Center

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.profile.firstName ?? '';
    _lastNameController.text = widget.profile.lastName ?? '';
    _phoneController.text = widget.profile.phoneNumber ?? '';
    _appIdController.text = widget.profile.appId ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _appIdController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // US phone validation: XXX-XXX-XXXX or XXXXXXXXXX
    final phoneRegex = RegExp(
      r'^(\d{3}-\d{3}-\d{4}|\d{10})$',
    );

    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid US phone number';
    }

    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      print('[ONBOARDING] Saving profile...');
      print('[ONBOARDING] firstName: "${_firstNameController.text.trim()}"');
      print('[ONBOARDING] lastName: "${_lastNameController.text.trim()}"');
      print('[ONBOARDING] phoneNumber: "${_phoneController.text.trim()}"');
      print('[ONBOARDING] appId: "${_appIdController.text.trim()}"');

      final fn = _firstNameController.text.trim();
      final ln = _lastNameController.text.trim();
      final pn = _phoneController.text.trim();

      print('[DEBUG] About to call updateMe with:');
      print('[DEBUG] firstName length: ${fn.length} value: "$fn"');
      print('[DEBUG] lastName length: ${ln.length} value: "$ln"');
      print('[DEBUG] phoneNumber length: ${pn.length} value: "$pn"');

      await UserService.updateMe(
        firstName: fn,
        lastName: ln,
        phoneNumber: pn,
        appId: _appIdController.text.trim().isEmpty
            ? null
            : _appIdController.text.trim(),
      );

      print('[ONBOARDING] Profile saved successfully');

      // Save default tab preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('default_tab', _selectedDefaultTab);
      print('[ONBOARDING] Default tab saved: $_selectedDefaultTab');

      if (!mounted) return;

      // Show success and reload
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      print('[ONBOARDING] Calling onComplete()...');
      widget.onComplete();
    } catch (e) {
      print('[ONBOARDING ERROR] Failed to save: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          TextButton(
            onPressed: widget.onSignOut,
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome message
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.waving_hand,
                        size: 48,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome to Nexa Staff!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete your profile to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  hintText: 'Enter your first name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => _validateRequired(value, 'First name'),
              ),
              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  hintText: 'Enter your last name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => _validateRequired(value, 'Last name'),
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '555-123-4567',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  helperText: 'Format: XXX-XXX-XXXX or 10 digits',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),

              // Default Tab Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.home_outlined, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Default Home Screen',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose which screen to show when you open the app',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Clock In'),
                            selected: _selectedDefaultTab == 0,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDefaultTab = 0);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Roles'),
                            selected: _selectedDefaultTab == 1,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDefaultTab = 1);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Earnings'),
                            selected: _selectedDefaultTab == 2,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDefaultTab = 2);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Team Center'),
                            selected: _selectedDefaultTab == 3,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDefaultTab = 3);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App ID (optional)
              TextFormField(
                controller: _appIdController,
                decoration: const InputDecoration(
                  labelText: 'App ID (Optional)',
                  hintText: 'Enter your app ID if provided',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Save button
              FilledButton(
                onPressed: _saving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 12),

              // Required fields note
              Text(
                '* Required fields',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
