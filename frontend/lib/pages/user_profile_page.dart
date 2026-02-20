import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/file_upload_service.dart';
import '../providers/terminology_provider.dart';
import '../utils/terminology_helper.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../shared/widgets/initials_avatar.dart';
import '../shared/widgets/caricature_generator_sheet.dart';
import '../services/subscription_service.dart';
import '../shared/widgets/subscription_gate.dart';
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
  final _imagePicker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _reverting = false;
  String? _error;

  /// The original (pre-caricature) picture URL from the backend.
  String? _originalPicture;

  /// Caricature history from backend (last 10, newest last).
  List<CaricatureHistoryItem> _caricatureHistory = [];

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
        _originalPicture = me.originalPicture;
        _caricatureHistory = me.caricatureHistory;
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

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = await FileUploadService.uploadProfilePictureBytes(bytes, picked.name);
      } else {
        url = await FileUploadService.uploadProfilePicture(File(picked.path));
      }

      setState(() {
        _pictureCtrl.text = url;
        _uploading = false;
      });

      // Auto-save the new picture to the backend
      await _save();
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = AppLocalizations.of(context)!.failedToUploadPicture;
      });
    }
  }

  /// Accept a caricature and save it immediately with the isCaricature flag.
  Future<void> _acceptCaricature(String caricatureUrl) async {
    if (!mounted) return;
    setState(() {
      _pictureCtrl.text = caricatureUrl;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await UserService.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: caricatureUrl,
        isCaricature: true,
      );
      if (!mounted) return;
      // Reload profile to get updated history
      final me = await UserService.getMe();
      if (!mounted) return;
      setState(() {
        _originalPicture = updated.originalPicture;
        _caricatureHistory = me.caricatureHistory;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.newLookSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.failedToSaveCreation);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Reuse a caricature from history as the current profile picture.
  Future<void> _reuseCaricature(CaricatureHistoryItem item) async {
    if (!mounted) return;
    setState(() {
      _pictureCtrl.text = item.url;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await UserService.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: item.url,
        isCaricature: true,
      );
      if (!mounted) return;
      setState(() {
        _originalPicture = updated.originalPicture;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profilePictureUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.failedToUpdateProfilePicture);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Delete a caricature from history.
  Future<void> _deleteCaricature(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCreation),
        content: Text(AppLocalizations.of(context)!.deleteCreationConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final updated = await UserService.deleteCaricature(index);
      if (!mounted) return;
      setState(() => _caricatureHistory = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creation deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.failedToDeleteCreation)),
      );
    }
  }

  /// Revert to the original (pre-caricature) picture.
  Future<void> _revertPicture() async {
    if (_originalPicture == null) return;

    setState(() {
      _reverting = true;
      _error = null;
    });

    try {
      final result = await UserService.revertPicture();
      if (!mounted) return;
      setState(() {
        _pictureCtrl.text = result.picture ?? _originalPicture!;
        _originalPicture = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverted to original photo')),
      );
    } catch (e) {
      setState(() => _error = 'Failed to revert: $e');
    } finally {
      if (mounted) setState(() => _reverting = false);
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
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showFullImage(String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _FullImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showCaricatureSheet() {
    // Block read-only users
    if (SubscriptionService().isReadOnly) {
      showSubscriptionRequiredSheet(context, featureName: AppLocalizations.of(context)!.generateCaricature);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaricatureGeneratorSheet(
        currentPictureUrl: _pictureCtrl.text.trim(),
        onAccepted: _acceptCaricature,
        userName: _firstNameCtrl.text.trim(),
        userLastName: _lastNameCtrl.text.trim(),
      ),
    );
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
                  const SizedBox(height: 8),
                  _buildPictureActions(),
                  if (_caricatureHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCreationsGallery(),
                  ],
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Terminology Settings Section
                  _buildTerminologySettings(context),
                  const SizedBox(height: 16),
                  // Notification Settings Section
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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

  Widget _buildAvatar() {
    final hasPicture = _pictureCtrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: _uploading
          ? null
          : hasPicture
              ? () => _showFullImage(_pictureCtrl.text.trim(), heroTag: 'profile-avatar')
              : _pickAndUploadImage,
      child: Hero(
        tag: 'profile-avatar',
        child: Stack(
          children: [
            InitialsAvatar(
              imageUrl: _pictureCtrl.text.trim(),
              firstName: _firstNameCtrl.text.trim(),
              lastName: _lastNameCtrl.text.trim(),
              radius: 48,
            ),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the row of action buttons below the avatar.
  Widget _buildPictureActions() {
    final l10n = AppLocalizations.of(context)!;
    final hasPicture = _pictureCtrl.text.trim().isNotEmpty;
    final canRevert = _originalPicture != null && _originalPicture!.isNotEmpty;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        // Upload photo from gallery
        _uploading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : TextButton.icon(
                onPressed: _pickAndUploadImage,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: Text(l10n.upload),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
        if (hasPicture)
          TextButton.icon(
            onPressed: _showCaricatureSheet,
            icon: const Icon(Icons.camera_enhance_rounded, size: 16),
            label: Text(l10n.glowUp),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        if (canRevert)
          _reverting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton.icon(
                  onPressed: _revertPicture,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(l10n.originalPhoto),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
      ],
    );
  }

  /// Horizontal gallery of previous caricature creations.
  Widget _buildCreationsGallery() {
    final l10n = AppLocalizations.of(context)!;
    // Show newest first, max 5
    final items = _caricatureHistory.reversed.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.collections_rounded, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.myCreations,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
            const Spacer(),
            Text(
              '${items.length} of ${_caricatureHistory.length}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              final isActive = item.url == _pictureCtrl.text.trim();
              final originalIndex = _caricatureHistory.length - 1 - i;
              return _buildCreationCard(item, isActive, originalIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreationCard(CaricatureHistoryItem item, bool isActive, int originalIndex) {
    final l10n = AppLocalizations.of(context)!;
    final roleLabel = _formatLabel(item.role);
    final styleLabel = _formatLabel(item.artStyle);

    return GestureDetector(
      onTap: () => _showCreationDetail(item, isActive, originalIndex),
      child: Container(
        width: 105,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primaryIndigo : AppColors.border,
            width: isActive ? 2.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceGray,
                        child: const Icon(Icons.broken_image, size: 24, color: AppColors.textMuted),
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.activeBadge,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryPurple.withValues(alpha: 0.05) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Column(
                children: [
                  Text(
                    roleLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    styleLabel,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a bottom sheet with the full creation + actions.
  void _showCreationDetail(CaricatureHistoryItem item, bool isActive, int originalIndex) {
    final l10n = AppLocalizations.of(context)!;
    final roleLabel = _formatLabel(item.role);
    final styleLabel = _formatLabel(item.artStyle);
    final dateStr = '${item.createdAt.month}/${item.createdAt.day}/${item.createdAt.year}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showFullImage(item.url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  item.url,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 300,
                    color: AppColors.surfaceGray,
                    child: const Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(Icons.badge_outlined, roleLabel),
                const SizedBox(width: 8),
                _infoChip(Icons.palette_outlined, styleLabel),
                const SizedBox(width: 8),
                _infoChip(Icons.calendar_today_outlined, dateStr),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteCaricature(originalIndex);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.delete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isActive
                        ? () {
                            Navigator.pop(ctx);
                            _showFullImage(item.url);
                          }
                        : () {
                            Navigator.pop(ctx);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _reuseCaricature(item);
                            });
                          },
                    icon: Icon(isActive ? Icons.fullscreen_rounded : Icons.check_rounded, size: 20),
                    label: Text(isActive ? 'View Full Size' : 'Use This Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _formatLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildContactManagersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
    terminologyProvider.updateSystemLanguage(context);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                if (value != null) terminologyProvider.setTerminology(value);
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(l10n.jobsExample),
              value: TerminologyHelper.jobs,
              groupValue: terminologyProvider.terminology,
              onChanged: (value) {
                if (value != null) terminologyProvider.setTerminology(value);
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(l10n.eventsExample),
              value: TerminologyHelper.events,
              groupValue: terminologyProvider.terminology,
              onChanged: (value) {
                if (value != null) terminologyProvider.setTerminology(value);
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
}

/// Full-screen image viewer with pinch-to-zoom and dismiss.
class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.imageUrl, this.heroTag});

  final String imageUrl;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final imageWidget = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: heroTag != null
                  ? Hero(tag: heroTag!, child: imageWidget)
                  : imageWidget,
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          Expanded(child: _buildContent()),
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
