import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/terminology_provider.dart';
import '../../../shared/presentation/theme/theme.dart';
import '../../../services/data_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/user_service.dart';
import '../services/chat_summary_service.dart';
import '../services/staff_chat_service.dart';
import '../services/staff_extraction_service.dart';
import '../widgets/animated_ai_message_widget.dart';
import '../widgets/availability_confirmation_card.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/shift_action_card.dart';
import 'subscription_paywall_screen.dart';
import '../../../shared/widgets/subscription_gate.dart';
import '../../../shared/widgets/personal_event_bottom_sheet.dart';

/// Staff AI Assistant Chat Screen
/// Main interface for staff to interact with AI assistant
class StaffAIChatScreen extends StatefulWidget {
  const StaffAIChatScreen({super.key});

  @override
  State<StaffAIChatScreen> createState() => _StaffAIChatScreenState();
}

class _StaffAIChatScreenState extends State<StaffAIChatScreen> {
  final StaffChatService _chatService = StaffChatService();
  final ChatSummaryService _summaryService = ChatSummaryService();
  final ScrollController _scrollController = ScrollController();
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _isInitialized = false;
  bool _isExtracting = false;
  String _subscriptionTier = 'free';
  int _aiMessagesUsed = 0;
  int _aiMessagesLimit = 4; // Free tier: 4 messages before paywall
  String? _userFirstName;
  String? _userLastName;
  String? _userPictureUrl;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadSubscriptionStatus();
    _loadUserProfile();
  }

  @override
  void dispose() {
    // Save conversation summary when leaving the screen
    // Only save if there's meaningful content (more than just welcome message)
    _saveOnExit();

    _scrollController.dispose();
    super.dispose();
  }

  /// Save conversation when user leaves the screen
  void _saveOnExit() {
    // Count user messages (excluding system welcome message)
    final userMessages = _chatService.conversationHistory
        .where((msg) => msg.role == 'user')
        .length;

    // Only save if user actually sent at least one message
    if (userMessages > 0) {
      print('[StaffAIChatScreen] Saving conversation on exit (${userMessages} user messages)');
      _saveChatSummary(
        outcome: 'question_answered',
        outcomeReason: 'User left chat screen',
      );
    } else {
      print('[StaffAIChatScreen] No user messages - skipping save on exit');
    }
  }

  Future<void> _initializeChat() async {
    await _chatService.initialize();
    setState(() {
      _isInitialized = true;
    });

  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Block read-only users
    if (_subscriptionService.isReadOnly) {
      showSubscriptionRequiredSheet(context, featureName: 'AI Assistant');
      return;
    }

    // Clear old pending actions
    setState(() {});

    // Get user's terminology preference
    final terminology = context.read<TerminologyProvider>().lowercasePlural;

    // Model selection is handled server-side by cascade router
    final response = await _chatService.sendMessage(
      message,
      terminology: terminology,
    );
    if (response != null) {
      setState(() {});
      // Invalidate availability cache if AI tool modified it
      if (response.toolsUsed.contains('mark_availability')) {
        context.read<DataService>().invalidateAvailabilityCache();
      }
      // Refresh data if personal event tools were used
      const personalEventTools = {
        'create_personal_event',
        'create_personal_events_bulk',
        'update_personal_event',
        'update_personal_events_bulk',
        'delete_personal_event',
      };
      if (response.toolsUsed.any((t) => personalEventTools.contains(t))) {
        context.read<DataService>().forceRefresh();
      }
      // With reverse: true, new messages appear at bottom automatically - no scroll needed!
      // Refresh usage stats after sending message
      _loadSubscriptionStatus();
    } else {
      // Show error
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToGetAIResponse('')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    // EXPERT: With reverse: true, new messages appear at position 0 (bottom) automatically
    // No scrolling needed! The message is already visible.
    // This method is kept for backward compatibility but does nothing now.
  }

  /// Load subscription status and usage statistics
  Future<void> _loadSubscriptionStatus() async {
    try {
      await _subscriptionService.initialize();

      final status = await _subscriptionService.getBackendStatus();
      final usage = await _subscriptionService.getUsageStats();

      if (mounted) {
        setState(() {
          _subscriptionTier = status['tier'] ?? 'free';
          _aiMessagesUsed = usage['used'] ?? 0;
          _aiMessagesLimit = usage['limit'] ?? 50;
        });
      }
    } catch (e) {
      print('[StaffAIChatScreen] Failed to load subscription status: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final me = await UserService.getMe();
      if (mounted) {
        setState(() {
          _userFirstName = me.firstName;
          _userLastName = me.lastName;
          _userPictureUrl = (me.picture ?? '').trim().isEmpty ? null : me.picture!.trim();
        });
      }
    } catch (_) {}
  }

  /// Handle availability confirmation
  Future<void> _confirmAvailability() async {
    // TODO: Call availability API endpoint
    final availabilityData = _chatService.pendingAvailability!;

    // For now, just show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Availability marked for ${(availabilityData['dates'] as List).length} date(s)!'),
        backgroundColor: AppColors.success,
      ),
    );

    // Save conversation summary (fire-and-forget)
    _saveChatSummary(
      outcome: 'availability_marked',
      actionData: availabilityData,
    );

    _chatService.clearPendingAvailability();
    _chatService.addSystemMessage('✅ Your availability has been updated successfully!');
    setState(() {});
    // With reverse: true, message appears at bottom automatically
  }

  /// Handle shift action confirmation
  Future<void> _confirmShiftAction() async {
    // TODO: Call shift accept/decline API endpoint
    final shiftAction = _chatService.pendingShiftAction!;
    final action = shiftAction['action'] as String;
    final eventName = shiftAction['shift_name'] as String;

    // For now, just show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'accept'
              ? 'Shift accepted: $eventName'
              : 'Shift declined: $eventName'
        ),
        backgroundColor: action == 'accept' ? AppColors.success : AppColors.warning,
      ),
    );

    // Save conversation summary (fire-and-forget)
    _saveChatSummary(
      outcome: action == 'accept' ? 'shift_accepted' : 'shift_declined',
      actionData: shiftAction,
    );

    _chatService.clearPendingShiftAction();
    _chatService.addSystemMessage(
      action == 'accept'
          ? '🎉 Great! You\'re confirmed for $eventName. Your manager has been notified.'
          : '👍 No problem! $eventName has been declined. Your manager has been notified.'
    );
    setState(() {});
    // With reverse: true, message appears at bottom automatically
  }

  /// Cancel availability confirmation
  void _cancelAvailability() {
    _chatService.clearPendingAvailability();
    _chatService.addSystemMessage('Availability update cancelled.');
    setState(() {});
    // With reverse: true, message appears at bottom automatically
  }

  /// Cancel shift action
  void _cancelShiftAction() {
    _chatService.clearPendingShiftAction();
    _chatService.addSystemMessage('Shift action cancelled.');
    setState(() {});
    // With reverse: true, message appears at bottom automatically
  }

  /// Clear conversation
  void _clearConversation() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearConversation),
        content: Text(l10n.clearConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              // Save summary before clearing if there was any conversation
              if (_chatService.conversationHistory.isNotEmpty) {
                _saveChatSummary(
                  outcome: 'question_answered',
                  outcomeReason: 'User cleared conversation',
                );
              }

              _chatService.clearConversation();
              AnimatedAiMessageWidget.clearAnimationTracking(); // Clear animation tracking
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(l10n.clear, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// Save conversation summary to database (fire-and-forget)
  void _saveChatSummary({
    required String outcome,
    String? outcomeReason,
    Map<String, dynamic>? actionData,
  }) {
    // Export conversation data from chat service
    final summaryData = _chatService.exportConversationSummary(
      outcome: outcome,
      outcomeReason: outcomeReason,
      actionData: actionData,
    );

    // Fire-and-forget save (don't await)
    _summaryService.saveSummary(summaryData);
  }

  /// Get a time-of-day greeting like "How can I help you this afternoon?"
  String _getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    String timeOfDay;
    if (hour < 12) {
      timeOfDay = 'this morning';
    } else if (hour < 17) {
      timeOfDay = 'this afternoon';
    } else {
      timeOfDay = 'this evening';
    }
    return 'How can I help you\n$timeOfDay?';
  }

  /// Build a suggestion chip for quick actions
  Widget _buildSuggestionChip(String label, String query) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _sendMessage(query),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build an action chip that runs a callback instead of sending a message
  Widget _buildActionChip(String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.personalEventLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.personalEvent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.personalEvent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPersonalEvent() {
    final sub = SubscriptionService();
    final tier = sub.tier;
    if (tier != 'pro' && tier != 'premium' && !sub.isInFreeMonth) {
      showSubscriptionRequiredSheet(
        context,
        featureName: AppLocalizations.of(context)!.personalEvent,
      );
      return;
    }

    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const PersonalEventBottomSheet(),
      ),
    ).then((created) {
      if (created == true && mounted) {
        context.read<DataService>().forceRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.personalEventCreated),
          ),
        );
      }
    });
  }

  void _showAttachmentOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryPurple),
                title: Text(l10n.takePhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryPurple),
                title: Text(l10n.chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryPurple),
                title: Text(l10n.uploadPdf),
                onTap: () {
                  Navigator.pop(context);
                  _pickPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined, color: AppColors.personalEvent),
                title: Text(l10n.manualEntry),
                onTap: () {
                  Navigator.pop(context);
                  _showAddPersonalEvent();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) await _processImage(File(image.path));
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) await _processImage(File(image.path));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      await _processPdf(File(result.files.single.path!));
    }
  }

  Future<void> _processImage(File imageFile) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExtracting = true);
    try {
      final extracted = await StaffExtractionService.extractFromImage(imageFile);
      if (!mounted) return;
      if (extracted != null) {
        _openPrefilledEventSheet(extracted);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.extractionFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.extractionFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _processPdf(File pdfFile) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExtracting = true);
    try {
      final extracted = await StaffExtractionService.extractFromPdf(pdfFile);
      if (!mounted) return;
      if (extracted != null) {
        _openPrefilledEventSheet(extracted);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.extractionFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.extractionFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  void _openPrefilledEventSheet(Map<String, dynamic> extracted) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PersonalEventBottomSheet(existingEvent: extracted),
      ),
    ).then((created) {
      if (created == true && mounted) {
        context.read<DataService>().forceRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.personalEventCreated),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surfaceLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n.aiAssistant,
          style: const TextStyle(color: AppColors.navySpaceCadet),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        foregroundColor: AppColors.navySpaceCadet,
        iconTheme: const IconThemeData(color: AppColors.navySpaceCadet),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          // Usage indicator for free tier
          if (_subscriptionTier == 'free')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () async {
                  // Navigate to subscription paywall
                  final upgraded = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPaywallScreen(),
                    ),
                  );

                  // Refresh status if user upgraded
                  if (upgraded == true && mounted) {
                    await _loadSubscriptionStatus();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _aiMessagesUsed >= 16 // 80% of 20 message limit
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _aiMessagesUsed >= 16
                          ? Colors.orange.shade300
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: _aiMessagesUsed >= 16
                            ? Colors.orange.shade900
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_aiMessagesUsed/$_aiMessagesLimit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _aiMessagesUsed >= 16
                              ? Colors.orange.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main content area with messages
                Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: _chatService.conversationHistory.isEmpty
                          && _chatService.pendingAvailability == null
                          && _chatService.pendingShiftAction == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 160),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/ai_assistant_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _getTimeOfDayGreeting(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.charcoal.withOpacity(0.75),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // EXPERT: Makes new messages appear at bottom naturally
                        padding: const EdgeInsets.only(
                          top: 16,
                          bottom: 140, // Extra padding for chips + input area
                        ),
                        itemCount: _chatService.conversationHistory.length +
                            (_chatService.pendingAvailability != null ? 1 : 0) +
                            (_chatService.pendingShiftAction != null ? 1 : 0),
                        itemBuilder: (context, index) {
                      // EXPERT: With reverse: true, index 0 is the newest message (at bottom)
                      // We need to map index to the correct position in conversationHistory
                      final historyLength = _chatService.conversationHistory.length;

                      // Check for pending cards first (they appear at the very bottom, index 0)
                      if (_chatService.pendingShiftAction != null && index == 0) {
                        return RepaintBoundary(
                          key: const ValueKey('shift_action_card'),
                          child: ShiftActionCard(
                            shiftAction: _chatService.pendingShiftAction!,
                            onConfirm: _confirmShiftAction,
                            onCancel: _cancelShiftAction,
                          ),
                        );
                      }

                      if (_chatService.pendingAvailability != null) {
                        final availabilityIndex = _chatService.pendingShiftAction != null ? 1 : 0;
                        if (index == availabilityIndex) {
                          return RepaintBoundary(
                            key: const ValueKey('availability_card'),
                            child: AvailabilityConfirmationCard(
                              availabilityData: _chatService.pendingAvailability!,
                              onConfirm: _confirmAvailability,
                              onCancel: _cancelAvailability,
                            ),
                          );
                        }
                      }

                      // Calculate message index: skip pending cards, then reverse
                      final pendingCards =
                          (_chatService.pendingShiftAction != null ? 1 : 0) +
                          (_chatService.pendingAvailability != null ? 1 : 0);
                      final messageIndex = historyLength - 1 - (index - pendingCards);

                      if (messageIndex < 0 || messageIndex >= historyLength) {
                        return const SizedBox.shrink();
                      }

                      final message = _chatService.conversationHistory[messageIndex];

                      // Skip system messages that are just markers
                      if (message.role == 'system' &&
                          (message.content.contains('AVAILABILITY_MARK') ||
                           message.content.contains('SHIFT_ACCEPT') ||
                           message.content.contains('SHIFT_DECLINE'))) {
                        return const SizedBox.shrink();
                      }

                      // Check if this is the latest assistant message (widget handles animation tracking internally)
                      final messageId = message.timestamp.millisecondsSinceEpoch;
                      final isLatestAiMessage = message.role == 'assistant' &&
                          messageIndex == _chatService.conversationHistory.length - 1;

                      // Show avatar only on the last consecutive user message
                      final isLastUserInGroup = message.role != 'user' ||
                          messageIndex == _chatService.conversationHistory.length - 1 ||
                          _chatService.conversationHistory[messageIndex + 1].role != 'user';

                      // Use RepaintBoundary with keys to prevent unnecessary rebuilds
                      return RepaintBoundary(
                        key: ValueKey('message_$messageId'),
                        child: message.role == 'assistant'
                          ? AnimatedAiMessageWidget(
                              message: message,
                              showAnimation: isLatestAiMessage, // Widget internally tracks if already animated
                            )
                          : ChatMessageWidget(
                              message: message,
                              userProfilePicture: _userPictureUrl,
                              userFirstName: _userFirstName,
                              userLastName: _userLastName,
                              showAvatar: isLastUserInGroup,
                              onLinkTap: (linkText) async {
                                // Open venue in Google Maps
                                final encodedAddress = Uri.encodeComponent(linkText);
                                final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

                                try {
                                  if (await canLaunchUrl(mapsUrl)) {
                                    await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                                  } else {
                                    print('Could not launch maps for: $linkText');
                                  }
                                } catch (e) {
                                  print('Error opening maps: $e');
                                }
                              },
                            ),
                      );
                        },
                      ),
                    ),
                  ],
                ),

                // Input field + chips layer (at bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(
                    color: Colors.white.withValues(alpha: 0.75),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom
                        : 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quick action chips (integrated above input)
                        if (!_chatService.isLoading)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Builder(
                                builder: (context) {
                                  final term = context.read<TerminologyProvider>();
                                  final p = term.lowercasePlural;
                                  final isEs = Localizations.localeOf(context).languageCode == 'es';
                                  return Row(
                                    children: [
                                      _buildSuggestionChip(
                                        isEs ? '📋 Mi horario' : '📋 My schedule',
                                        isEs ? 'Muestra mis próximos $p' : 'Show my upcoming $p',
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSuggestionChip(
                                        isEs ? '💰 Ingresos' : '💰 Earnings',
                                        isEs ? '¿Cuánto gané este mes?' : 'How much did I earn this month?',
                                      ),
                                      const SizedBox(width: 6),
                                      _buildSuggestionChip(
                                        isEs ? '📅 Disponibilidad' : '📅 Availability',
                                        isEs ? 'Ayúdame a marcar mi disponibilidad' : 'Help me mark my availability',
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionChip(
                                        isEs ? '📌 Trabajo independiente' : '📌 Independent job',
                                        _showAddPersonalEvent,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        // Chat input
                        if (_isExtracting)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.extractingData,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ChatInputWidget(
                          onSendMessage: _sendMessage,
                          isLoading: _chatService.isLoading || _isExtracting,
                          onAttachmentTap: _showAttachmentOptions,
                        ),
                      ],
                    ),
                  ),
                    ),  // BackdropFilter
                  ),    // ClipRect
                ),
              ],
            ),
    );
  }
}
