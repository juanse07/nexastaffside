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
import '../utils/error_helpers.dart';
import '../shared/widgets/home_address_field.dart';
import 'chat_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _pictureCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  double? _homeLat;
  double? _homeLng;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _reverting = false;
  String? _error;

  String? _originalPicture;
  List<CaricatureHistoryItem> _caricatureHistory = [];

  // Smart scheduling fields
  List<String> _skills = [];
  List<Map<String, dynamic>> _certifications = [];
  Map<String, dynamic>? _workPreferences;
  bool _savingSchedulingData = false;

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
        _addressCtrl.text = me.homeAddress ?? '';
        _homeLat = me.homeLat;
        _homeLng = me.homeLng;
        _originalPicture = me.originalPicture;
        _caricatureHistory = me.caricatureHistory;
        _skills = List<String>.from(me.skills);
        _certifications = List<Map<String, dynamic>>.from(me.certifications);
        _workPreferences = me.workPreferences != null
            ? Map<String, dynamic>.from(me.workPreferences!)
            : null;
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

      await _save();
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = AppLocalizations.of(context)!.failedToUploadPicture;
      });
    }
  }

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
      if (!mounted) return;
      setState(() => _error = localizedErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _reverting = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final addressTrimmed = _addressCtrl.text.trim();
      await UserService.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: _pictureCtrl.text.trim().isEmpty ? null : _pictureCtrl.text.trim(),
        homeAddress: addressTrimmed.isEmpty ? null : addressTrimmed,
        homeLat: addressTrimmed.isEmpty ? null : _homeLat,
        homeLng: addressTrimmed.isEmpty ? null : _homeLng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizedErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFullImage(String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _FullImageViewer(imageUrl: imageUrl, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _showCaricatureSheet() {
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
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(l10n.myProfile),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                    )
                  : Text(
                      l10n.save,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  _buildAvatarSection(),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRed,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.errorBorder),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ),
                  _buildFormCard(l10n),
                  const SizedBox(height: 16),
                  _buildHomeAddressCard(l10n),
                  const SizedBox(height: 16),
                  _buildSkillsCard(l10n),
                  const SizedBox(height: 16),
                  _buildCertificationsCard(l10n),
                  const SizedBox(height: 16),
                  _buildWorkPreferencesCard(l10n),
                  const SizedBox(height: 16),
                  _buildTerminologySettings(context),
                  const SizedBox(height: 16),
                  _buildNotificationsCard(l10n),
                  const SizedBox(height: 16),
                  _buildContactManagersCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ─── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final l10n = AppLocalizations.of(context)!;
    final hasPicture = _pictureCtrl.text.trim().isNotEmpty;
    final canRevert = _originalPicture != null && _originalPicture!.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
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
                  radius: 52,
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
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGray,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceLight, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt, size: 15, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Photo action pills
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.yellow),
                  )
                : _actionPill(
                    icon: Icons.photo_library_rounded,
                    label: l10n.upload,
                    onTap: _pickAndUploadImage,
                    filled: true,
                  ),
            if (hasPicture) ...[
              const SizedBox(width: 8),
              _actionPill(
                icon: Icons.camera_enhance_rounded,
                label: l10n.glowUp,
                onTap: _showCaricatureSheet,
                filled: true,
              ),
            ],
            if (canRevert) ...[
              const SizedBox(width: 8),
              _reverting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _actionPill(
                      icon: Icons.undo_rounded,
                      label: l10n.originalPhoto,
                      onTap: _revertPicture,
                      filled: false,
                    ),
            ],
          ],
        ),
        if (_caricatureHistory.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildCreationsGallery(),
        ],
      ],
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.surfaceGray : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? AppColors.borderMedium : AppColors.borderMedium,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Validators ────────────────────────────────────────────────────────────

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional on edit
    final phoneRegex = RegExp(r'^(\d{3}-\d{3}-\d{4}|\d{10})$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return AppLocalizations.of(context)!.errorPhoneFormat;
    }
    return null;
  }

  String? _validateAppId(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional field
    final appIdRegex = RegExp(r'^\d{9}$');
    if (!appIdRegex.hasMatch(value.trim())) {
      return AppLocalizations.of(context)!.errorAppIdFormat;
    }
    return null;
  }

  // ─── Form Card ─────────────────────────────────────────────────────────────

  Widget _buildFormCard(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _formRow(
              icon: Icons.person_outline,
              child: TextFormField(
                controller: _firstNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.firstName,
                  labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  floatingLabelStyle: const TextStyle(color: AppColors.navySpaceCadet, fontSize: 12, fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
              isFirst: true,
            ),
            _divider(),
            _formRow(
              icon: Icons.person_outline,
              child: TextFormField(
                controller: _lastNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.lastName,
                  labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  floatingLabelStyle: const TextStyle(color: AppColors.navySpaceCadet, fontSize: 12, fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            _divider(),
            _formRow(
              icon: Icons.phone_outlined,
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                decoration: InputDecoration(
                  labelText: l10n.phoneNumber,
                  labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  floatingLabelStyle: const TextStyle(color: AppColors.navySpaceCadet, fontSize: 12, fontWeight: FontWeight.w600),
                  hintText: l10n.phoneHint,
                  helperText: l10n.phoneHelper,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            _divider(),
            _formRow(
              icon: Icons.tag_outlined,
              child: TextFormField(
                controller: _appIdCtrl,
                keyboardType: TextInputType.number,
                maxLength: 9,
                validator: _validateAppId,
                decoration: InputDecoration(
                  labelText: l10n.appId,
                  labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  floatingLabelStyle: const TextStyle(color: AppColors.navySpaceCadet, fontSize: 12, fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow({
    required IconData icon,
    required Widget child,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 6 : 0,
        bottom: isLast ? 6 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 46, color: AppColors.borderLight);

  // ─── Home Address ──────────────────────────────────────────────────────────

  Widget _buildHomeAddressCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🤖', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.homeAddressInfo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3D4A9A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          // Address field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: HomeAddressField(
              initialAddress: _addressCtrl.text,
              onAddressSelected: (address, lat, lng) {
                setState(() {
                  _addressCtrl.text = address;
                  _homeLat = lat;
                  _homeLng = lng;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skills ────────────────────────────────────────────────────────────────

  Widget _buildSkillsCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 18, color: AppColors.yellow),
                const SizedBox(width: 8),
                Text(l10n.mySkills, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: _showSkillPicker,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 20, color: AppColors.yellow),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _skills.isEmpty
                ? Text('Tap + to add your skills', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) => Chip(
                      label: Text(
                        _titleCase(skill),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSkill(skill),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppColors.yellow.withOpacity(0.15),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static const _skillCategories = <String, (IconData, List<String>)>{
    'Hospitality': (Icons.local_bar, ['Bartending', 'Mixology', 'Wine Service', 'Beer Knowledge', 'Barista', 'Table Service', 'Fine Dining', 'Banquet Service', 'Buffet Setup', 'Host/Hostess']),
    'Kitchen': (Icons.restaurant, ['Line Cook', 'Prep Cook', 'Pastry', 'Grill', 'Sauté', 'Food Plating', 'Catering', 'Kitchen Management', 'Baking', 'Food Styling']),
    'Events': (Icons.celebration, ['DJ', 'Sound & Lighting', 'Photography', 'Videography', 'Event Setup', 'Stage Management', 'Floral Arrangement', 'Decoration', 'MC/Emcee', 'Coat Check']),
    'Childcare': (Icons.child_care, ['Infant Care', 'Toddler Care', 'Child Development', 'Tutoring', 'Activity Planning', 'Special Needs Care', 'Newborn Care', 'Homework Help']),
    'Construction': (Icons.construction, ['Carpentry', 'Plumbing', 'Electrical', 'Painting', 'Drywall', 'Concrete', 'Welding', 'HVAC', 'Roofing', 'Demolition']),
    'Healthcare': (Icons.medical_services, ['Patient Care', 'Vital Signs', 'Wound Care', 'Medication Admin', 'Phlebotomy', 'Physical Therapy', 'Elder Care', 'Home Health']),
    'General': (Icons.work, ['Customer Service', 'Cash Handling', 'POS Systems', 'Inventory', 'Cleaning', 'Driving', 'Security', 'Warehouse', 'Forklift', 'Data Entry']),
  };

  Future<void> _showSkillPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final existing = _skills.map((s) => s.toLowerCase()).toSet();
    final selected = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var searchQuery = '';
        var activeCategory = 'All';

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Filter skills based on search + category
            final entries = <MapEntry<String, List<String>>>[];
            for (final cat in _skillCategories.entries) {
              final filtered = cat.value.$2.where((s) {
                if (activeCategory != 'All' && cat.key != activeCategory) return false;
                if (searchQuery.isNotEmpty) return s.toLowerCase().contains(searchQuery.toLowerCase());
                return true;
              }).toList();
              if (filtered.isNotEmpty) entries.add(MapEntry(cat.key, filtered));
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Text(l10n.addSkill, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search skills...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                    ),
                  ),
                  // Category chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('All', style: TextStyle(color: activeCategory == 'All' ? Colors.white : AppColors.textSecondary, fontSize: 13)),
                            selected: activeCategory == 'All',
                            selectedColor: AppColors.primaryPurple,
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (_) => setSheetState(() => activeCategory = 'All'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        ..._skillCategories.entries.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.value.$1, size: 16, color: activeCategory == cat.key ? Colors.white : AppColors.textMuted),
                            label: Text(cat.key, style: TextStyle(color: activeCategory == cat.key ? Colors.white : AppColors.textSecondary, fontSize: 13)),
                            selected: activeCategory == cat.key,
                            selectedColor: AppColors.primaryPurple,
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (_) => setSheetState(() => activeCategory = cat.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Suggestion chips
                  Flexible(
                    child: entries.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No skills match "$searchQuery"', style: TextStyle(color: Colors.grey.shade500)),
                        ))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: entries.expand((entry) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPurple.withValues(alpha: 0.7))),
                            ),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: entry.value.map((skill) {
                                final isExisting = existing.contains(skill.toLowerCase());
                                final isSelected = selected.contains(skill.toLowerCase());
                                final isActive = isExisting || isSelected;
                                return FilterChip(
                                  label: Text(skill, style: TextStyle(fontSize: 13, color: isExisting ? Colors.grey : isSelected ? Colors.white : AppColors.textSecondary)),
                                  selected: isActive,
                                  selectedColor: isExisting ? Colors.grey.shade200 : AppColors.primaryPurple,
                                  checkmarkColor: isExisting ? Colors.grey : AppColors.primaryIndigo,
                                  onSelected: isExisting ? null : (val) => setSheetState(() {
                                    val ? selected.add(skill.toLowerCase()) : selected.remove(skill.toLowerCase());
                                  }),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: isActive ? (isExisting ? Colors.grey.shade300 : AppColors.primaryPurple) : AppColors.border),
                                );
                              }).toList(),
                            ),
                          ]).toList(),
                        ),
                  ),
                  // Custom input + Done
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Enter custom skill...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  isDense: true,
                                ),
                                onSubmitted: (v) {
                                  final trimmed = v.trim();
                                  if (trimmed.isNotEmpty && !existing.contains(trimmed.toLowerCase()) && !selected.contains(trimmed.toLowerCase())) {
                                    setSheetState(() => selected.add(trimmed.toLowerCase()));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(selected.isEmpty ? l10n.cancel : 'Done (${selected.length} selected)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected.isNotEmpty) {
      setState(() => _skills = [..._skills, ...selected]);
      await _saveSchedulingData();
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills = _skills.where((s) => s != skill).toList());
    _saveSchedulingData();
  }

  // ─── Certifications ───────────────────────────────────────────────────────

  Widget _buildCertificationsCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 18, color: AppColors.yellow),
                const SizedBox(width: 8),
                Text(l10n.myCertifications, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: _showCertPicker,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 20, color: AppColors.yellow),
                  ),
                ),
              ],
            ),
          ),
          if (_certifications.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Add your certifications', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            )
          else
            ..._certifications.asMap().entries.map((entry) {
              final index = entry.key;
              final cert = entry.value;
              final name = cert['name']?.toString() ?? '';
              final expiryStr = cert['expiryDate']?.toString();
              final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
              final now = DateTime.now();

              Color statusColor = Colors.green;
              String statusText = l10n.valid;
              if (expiry != null) {
                if (expiry.isBefore(now)) {
                  statusColor = Colors.red;
                  statusText = l10n.expired;
                } else if (expiry.isBefore(now.add(const Duration(days: 30)))) {
                  statusColor = Colors.orange;
                  statusText = l10n.expiringSoon;
                }
              } else {
                statusText = l10n.noExpiry;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 18, color: statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          if (cert['certNumber'] != null && (cert['certNumber'] as String).isNotEmpty)
                            Text('#${cert['certNumber']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if (expiry != null)
                            Text('Exp: ${expiry.month}/${expiry.day}/${expiry.year}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _certifications = [..._certifications]..removeAt(index));
                        _saveSchedulingData();
                      },
                      child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              );
            }),
          if (_certifications.isNotEmpty) const SizedBox(height: 12),
        ],
      ),
    );
  }

  static const _certCategories = <String, (IconData, List<String>)>{
    'Food & Beverage': (Icons.restaurant_menu, ['TIPS', 'ServSafe Food Handler', 'ServSafe Manager', 'Alcohol Server (ABC)', "Food Handler's Card", 'Allergen Awareness']),
    'Safety': (Icons.health_and_safety, ['CPR / First Aid', 'AED Certified', 'OSHA 10-Hour', 'OSHA 30-Hour', 'Fire Safety', 'Bloodborne Pathogens']),
    'Childcare': (Icons.child_care, ['Child CPR', 'Mandated Reporter', 'Pediatric First Aid', 'Child Development Associate (CDA)', 'Background Check (cleared)']),
    'Construction': (Icons.construction, ['Forklift Operator', 'Scaffolding Safety', 'Confined Space', 'Fall Protection', 'Rigging & Signaling']),
    'Healthcare': (Icons.medical_services, ['CNA', 'BLS (Basic Life Support)', 'ACLS', 'Phlebotomy', 'Home Health Aide (HHA)', 'Medical Assistant']),
    'Driving': (Icons.directions_car, ['Commercial Driver (CDL)', 'Passenger Endorsement', 'Chauffeur License', 'Clean Driving Record']),
  };

  Future<void> _showCertPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final existingNames = _certifications.map((c) => (c['name'] as String?)?.toLowerCase() ?? '').toSet();
    final newCerts = <Map<String, dynamic>>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var searchQuery = '';
        var activeCategory = 'All';
        final selectedNames = <String>{};
        // For each selected cert, track optional expiry
        final expiryDates = <String, DateTime?>{};

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final entries = <MapEntry<String, List<String>>>[];
            for (final cat in _certCategories.entries) {
              final filtered = cat.value.$2.where((c) {
                if (activeCategory != 'All' && cat.key != activeCategory) return false;
                if (searchQuery.isNotEmpty) return c.toLowerCase().contains(searchQuery.toLowerCase());
                return true;
              }).toList();
              if (filtered.isNotEmpty) entries.add(MapEntry(cat.key, filtered));
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Text(l10n.addCertification, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search certifications...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('All', style: TextStyle(color: activeCategory == 'All' ? Colors.white : AppColors.textSecondary, fontSize: 13)),
                            selected: activeCategory == 'All',
                            selectedColor: AppColors.primaryPurple,
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (_) => setSheetState(() => activeCategory = 'All'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        ..._certCategories.entries.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.value.$1, size: 16, color: activeCategory == cat.key ? Colors.white : AppColors.textMuted),
                            label: Text(cat.key, style: TextStyle(color: activeCategory == cat.key ? Colors.white : AppColors.textSecondary, fontSize: 13)),
                            selected: activeCategory == cat.key,
                            selectedColor: AppColors.primaryPurple,
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (_) => setSheetState(() => activeCategory = cat.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: entries.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No certifications match "$searchQuery"', style: TextStyle(color: Colors.grey.shade500)),
                        ))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: entries.expand((entry) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPurple.withValues(alpha: 0.7))),
                            ),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: entry.value.map((cert) {
                                final isExisting = existingNames.contains(cert.toLowerCase());
                                final isSelected = selectedNames.contains(cert);
                                final isActive = isExisting || isSelected;
                                return FilterChip(
                                  label: Text(cert, style: TextStyle(fontSize: 13, color: isExisting ? Colors.grey : isSelected ? Colors.white : AppColors.textSecondary)),
                                  selected: isActive,
                                  selectedColor: isExisting ? Colors.grey.shade200 : AppColors.primaryPurple,
                                  checkmarkColor: isExisting ? Colors.grey : AppColors.primaryIndigo,
                                  onSelected: isExisting ? null : (val) async {
                                    if (val) {
                                      final expiry = await showDatePicker(
                                        context: ctx,
                                        initialDate: DateTime.now().add(const Duration(days: 365)),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2040),
                                        helpText: '${l10n.expiryDate} (cancel to skip)',
                                      );
                                      setSheetState(() {
                                        selectedNames.add(cert);
                                        expiryDates[cert] = expiry;
                                      });
                                    } else {
                                      setSheetState(() {
                                        selectedNames.remove(cert);
                                        expiryDates.remove(cert);
                                      });
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: isActive ? (isExisting ? Colors.grey.shade300 : AppColors.primaryPurple) : AppColors.border),
                                );
                              }).toList(),
                            ),
                          ]).toList(),
                        ),
                  ),
                  // Custom input + Done
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Enter custom certification...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  isDense: true,
                                ),
                                onSubmitted: (v) async {
                                  final trimmed = v.trim();
                                  if (trimmed.isNotEmpty && !existingNames.contains(trimmed.toLowerCase()) && !selectedNames.contains(trimmed)) {
                                    final expiry = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now().add(const Duration(days: 365)),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2040),
                                      helpText: '${l10n.expiryDate} (cancel to skip)',
                                    );
                                    setSheetState(() {
                                      selectedNames.add(trimmed);
                                      expiryDates[trimmed] = expiry;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              for (final name in selectedNames) {
                                final map = <String, dynamic>{'name': name};
                                if (expiryDates[name] != null) {
                                  map['expiryDate'] = expiryDates[name]!.toUtc().toIso8601String();
                                }
                                newCerts.add(map);
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(selectedNames.isEmpty ? l10n.cancel : 'Done (${selectedNames.length} selected)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (newCerts.isNotEmpty) {
      setState(() => _certifications = [..._certifications, ...newCerts]);
      await _saveSchedulingData();
    }
  }

  // ─── Work Preferences ─────────────────────────────────────────────────────

  Widget _buildWorkPreferencesCard(AppLocalizations l10n) {
    final prefs = _workPreferences ?? {};
    final maxHours = (prefs['maxHoursPerWeek'] as num?)?.toDouble();
    final travelRadius = (prefs['travelRadiusMiles'] as num?)?.toDouble();
    final prefDays = List<String>.from(prefs['preferredDays'] ?? []);
    final prefShifts = List<String>.from(prefs['preferredShifts'] ?? []);

    const dayLabels = {'mon': 'M', 'tue': 'T', 'wed': 'W', 'thu': 'T', 'fri': 'F', 'sat': 'S', 'sun': 'S'};
    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const shiftKeys = ['morning', 'afternoon', 'evening', 'overnight'];

    String shiftLabel(String key) {
      switch (key) {
        case 'morning': return l10n.morning;
        case 'afternoon': return l10n.afternoon;
        case 'evening': return l10n.evening;
        case 'overnight': return l10n.overnight;
        default: return key;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.tune, size: 18, color: AppColors.yellow),
        title: Text(l10n.workPreferences, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // Max Hours/Week
          Row(
            children: [
              Expanded(child: Text(l10n.maxHoursPerWeek, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '40',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  controller: TextEditingController(text: maxHours?.toStringAsFixed(0) ?? ''),
                  onSubmitted: (val) {
                    final n = double.tryParse(val);
                    if (n != null && n > 0) _updateWorkPref('maxHoursPerWeek', n);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Travel Radius
          Row(
            children: [
              Expanded(child: Text(l10n.travelRadius, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Text('${(travelRadius ?? 25).toStringAsFixed(0)} mi', style: const TextStyle(fontSize: 14)),
            ],
          ),
          Slider(
            value: travelRadius ?? 25,
            min: 0, max: 100,
            divisions: 20,
            activeColor: AppColors.yellow,
            onChanged: (val) {
              _updateWorkPref('travelRadiusMiles', val.roundToDouble());
            },
          ),

          // Preferred Days
          const SizedBox(height: 8),
          Text(l10n.preferredDays, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: dayKeys.map((day) {
              final selected = prefDays.contains(day);
              return GestureDetector(
                onTap: () {
                  final updated = selected
                      ? prefDays.where((d) => d != day).toList()
                      : [...prefDays, day];
                  _updateWorkPref('preferredDays', updated);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.yellow : Colors.grey.shade200,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayLabels[day]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Preferred Shifts
          const SizedBox(height: 16),
          Text(l10n.preferredShifts, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: shiftKeys.map((shift) {
              final selected = prefShifts.contains(shift);
              return ChoiceChip(
                label: Text(shiftLabel(shift)),
                selected: selected,
                selectedColor: AppColors.yellow.withOpacity(0.3),
                onSelected: (_) {
                  final updated = selected
                      ? prefShifts.where((s) => s != shift).toList()
                      : [...prefShifts, shift];
                  _updateWorkPref('preferredShifts', updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _updateWorkPref(String key, dynamic value) {
    setState(() {
      _workPreferences = Map<String, dynamic>.from(_workPreferences ?? {});
      _workPreferences![key] = value;
    });
    _saveSchedulingData();
  }

  Future<void> _saveSchedulingData() async {
    if (_savingSchedulingData) return;
    setState(() => _savingSchedulingData = true);
    try {
      await UserService.updateMe(
        skills: _skills,
        certifications: _certifications,
        workPreferences: _workPreferences,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizedErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _savingSchedulingData = false);
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // ─── Terminology ───────────────────────────────────────────────────────────

  Widget _buildTerminologySettings(BuildContext context) {
    final terminologyProvider = context.watch<TerminologyProvider>();
    final l10n = AppLocalizations.of(context)!;
    terminologyProvider.updateSystemLanguage(context);

    final options = [
      (TerminologyHelper.shifts, l10n.shiftsExample),
      (TerminologyHelper.jobs, l10n.jobsExample),
      (TerminologyHelper.events, l10n.eventsExample),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline, color: AppColors.yellow, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.workTerminology,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navySpaceCadet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.howDoYouPreferToCallWork,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final selected = terminologyProvider.terminology == opt.$1;
            return GestureDetector(
              onTap: () => terminologyProvider.setTerminology(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.surfaceGray
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.borderMedium : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected ? AppColors.textSecondary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.textSecondary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.terminologyUpdateInfo,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Widget _buildNotificationsCard(AppLocalizations l10n) {
    final items = [
      l10n.newMessagesFromManagers,
      l10n.taskAssignments,
      l10n.eventInvitations,
      l10n.hoursApprovalUpdates,
      l10n.importantSystemAlerts,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_outlined, color: AppColors.primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.pushNotifications,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navySpaceCadet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.youWillReceiveNotificationsFor,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.tealInfo,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(item, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Contact Managers ──────────────────────────────────────────────────────

  Widget _buildContactManagersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => _showManagerPicker(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.contactMyManagers,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navySpaceCadet,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.yourManagerWillAppearHere,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── Creations Gallery ─────────────────────────────────────────────────────

  Widget _buildCreationsGallery() {
    final l10n = AppLocalizations.of(context)!;
    final items = _caricatureHistory.reversed.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.collections_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              l10n.myCreations,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${items.length} of ${_caricatureHistory.length}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
            color: isActive ? AppColors.yellow : AppColors.border,
            width: isActive ? 2.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
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
                            color: Colors.black54,
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
                color: isActive ? AppColors.primaryPurple.withValues(alpha: 0.06) : Colors.white,
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
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
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
                      backgroundColor: AppColors.surfaceGray,
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
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
}

// ─── Full Image Viewer ──────────────────────────────────────────────────────

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

// ─── Manager Picker Sheet ───────────────────────────────────────────────────

class _ManagerPickerSheet extends StatefulWidget {
  const _ManagerPickerSheet({required this.onManagerSelected});

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

    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(l10n.failedToLoadManagers, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadManagers, child: Text(l10n.retry)),
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
              const Icon(Icons.supervisor_account_outlined, size: 64, color: AppColors.borderLight),
              const SizedBox(height: 16),
              Text(
                l10n.noManagersAssigned,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.joinTeamToChat, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
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

class _ManagerTile extends StatelessWidget {
  const _ManagerTile({required this.manager, required this.onTap});

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
            UserAvatar(imageUrl: picture, fullName: name, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chat_bubble_outline, color: AppColors.navySpaceCadet, size: 20),
          ],
        ),
      ),
    );
  }
}
