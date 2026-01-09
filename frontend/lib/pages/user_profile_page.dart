import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../providers/terminology_provider.dart';
import '../utils/terminology_helper.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../shared/widgets/initials_avatar.dart';
import 'chat_page.dart';

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
                    decoration: InputDecoration(labelText: l10n.pictureUrl),
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
                  // Contact My Managers Section
                  _buildContactManagersCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildContactManagersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: InkWell(
        onTap: () => _showManagerPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.contactMyManagers,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.yourManagerWillAppearHere,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManagerPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagerPickerSheet(
        onManagerSelected: (manager) {
          Navigator.pop(context);
          _openNewChat(context, manager);
        },
      ),
    );
  }

  void _openNewChat(BuildContext context, Map<String, dynamic> manager) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          managerId: manager['id'] as String,
          managerName: manager['name'] as String? ?? 'Manager',
          managerPicture: manager['picture'] as String?,
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

/// Bottom sheet for selecting a manager to start a new chat
class _ManagerPickerSheet extends StatefulWidget {
  const _ManagerPickerSheet({
    required this.onManagerSelected,
  });

  final void Function(Map<String, dynamic> manager) onManagerSelected;

  @override
  State<_ManagerPickerSheet> createState() => _ManagerPickerSheetState();
}

class _ManagerPickerSheetState extends State<_ManagerPickerSheet> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _managers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final managers = await _chatService.fetchManagers();

      setState(() {
        _managers = managers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  l10n.contactMyManagers,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadManagers,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadManagers,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_managers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.supervisor_account_outlined, size: 64, color: AppColors.borderLight),
              const SizedBox(height: 16),
              Text(
                l10n.noManagersAssigned,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.joinTeamToChat,
                style: const TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _managers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final manager = _managers[index];
        return _ManagerTile(
          manager: manager,
          onTap: () => widget.onManagerSelected(manager),
        );
      },
    );
  }
}

/// Individual manager tile in the picker
class _ManagerTile extends StatelessWidget {
  const _ManagerTile({
    required this.manager,
    required this.onTap,
  });

  final Map<String, dynamic> manager;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = manager['name'] as String? ?? 'Manager';
    final email = manager['email'] as String? ?? '';
    final picture = manager['picture'] as String?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: picture,
              fullName: name,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryPurple,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
