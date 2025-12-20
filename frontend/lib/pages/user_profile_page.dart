import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/terminology_provider.dart';
import '../utils/terminology_helper.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../shared/widgets/initials_avatar.dart';

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
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.failedToLoadProfile;
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
        SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfile),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save, style: const TextStyle(color: AppColors.textLight)),
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
                          style: const TextStyle(color: AppColors.error)),
                    ),
                  TextField(
                    controller: _firstNameCtrl,
                    decoration: InputDecoration(labelText: l10n.firstName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(labelText: l10n.lastName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      hintText: l10n.phoneHint,
                      helperText: l10n.phoneHelper,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _appIdCtrl,
                    decoration: InputDecoration(
                        labelText: l10n.appId),
                    keyboardType: TextInputType.number,
                    maxLength: 9,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pictureCtrl,
                    decoration: InputDecoration(
                        labelText: l10n.pictureUrl),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Terminology Settings Section
                  _buildTerminologySettings(context),
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
                              Text(
                                l10n.pushNotifications,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.youWillReceiveNotificationsFor,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ${l10n.newMessagesFromManagers}'),
                                Text('• ${l10n.taskAssignments}'),
                                Text('• ${l10n.eventInvitations}'),
                                Text('• ${l10n.hoursApprovalUpdates}'),
                                Text('• ${l10n.importantSystemAlerts}'),
                              ],
                            ),
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

  Widget _buildTerminologySettings(BuildContext context) {
    final terminologyProvider = context.watch<TerminologyProvider>();
    final l10n = AppLocalizations.of(context)!;
    // Auto-detect system language
    terminologyProvider.updateSystemLanguage(context);

    return Card(
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
                  Icons.work_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.workTerminology,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.howDoYouPreferToCallWork,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: Text(l10n.shiftsExample),
              value: TerminologyHelper.shifts,
              groupValue: terminologyProvider.terminology,
              onChanged: (value) {
                if (value != null) {
                  terminologyProvider.setTerminology(value);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(l10n.jobsExample),
              value: TerminologyHelper.jobs,
              groupValue: terminologyProvider.terminology,
              onChanged: (value) {
                if (value != null) {
                  terminologyProvider.setTerminology(value);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(l10n.eventsExample),
              value: TerminologyHelper.events,
              groupValue: terminologyProvider.terminology,
              onChanged: (value) {
                if (value != null) {
                  terminologyProvider.setTerminology(value);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.terminologyUpdateInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return InitialsAvatar(
      imageUrl: _pictureCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      radius: 48,
    );
  }
}
