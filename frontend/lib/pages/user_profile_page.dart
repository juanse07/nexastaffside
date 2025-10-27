import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _pictureCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _sendingTest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await UserService.getMe();
      setState(() {
        _firstNameCtrl.text = me.firstName ?? '';
        _lastNameCtrl.text = me.lastName ?? '';
        _phoneCtrl.text = me.phoneNumber ?? '';
        _appIdCtrl.text = me.appId ?? '';
        _pictureCtrl.text = me.picture ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserService.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty
            ? null
            : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty
            ? null
            : _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        appId:
            _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: _pictureCtrl.text.trim().isEmpty
            ? null
            : _pictureCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sendingTest = true);

    final success = await NotificationService().sendTestNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test notification sent! Check your notifications.'
                : 'Failed to send test notification',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      setState(() => _sendingTest = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _appIdCtrl.dispose();
    _pictureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  _buildAvatar(),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '(555) 123-4567',
                      helperText: 'US format only',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _appIdCtrl,
                    decoration: const InputDecoration(
                        labelText: 'App ID (9 digits, optional)'),
                    keyboardType: TextInputType.number,
                    maxLength: 9,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pictureCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Picture URL (optional)'),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Notification Settings Section
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Push Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'You\'ll receive notifications for:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• New messages from managers'),
                                Text('• Task assignments'),
                                Text('• Event invitations'),
                                Text('• Hours approval updates'),
                                Text('• Important system alerts'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _sendingTest ? null : _sendTestNotification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _sendingTest
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _sendingTest
                                    ? 'Sending Test...'
                                    : 'Send Test Notification',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to verify push notifications are working',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final url = _pictureCtrl.text.trim();
    return CircleAvatar(
      radius: 48,
      backgroundColor: const Color(0xFF430172),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 48)
          : null,
    );
  }
}
