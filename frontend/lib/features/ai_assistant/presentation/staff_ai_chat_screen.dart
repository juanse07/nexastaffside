import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/terminology_provider.dart';
import '../../../shared/presentation/theme/theme.dart';
import '../../../services/data_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/user_service.dart';
import '../services/chat_summary_service.dart';
import '../services/staff_chat_service.dart';
import '../widgets/animated_ai_message_widget.dart';
import '../widgets/availability_confirmation_card.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/shift_action_card.dart';
import 'subscription_paywall_screen.dart';

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
  String _subscriptionTier = 'free';
  int _aiMessagesUsed = 0;
  int _aiMessagesLimit = 20; // Free tier limit (changed from 50 to reduce costs)
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

    // Get user's terminology preference for welcome message
    final terminology = context.read<TerminologyProvider>().lowercasePlural;
    final singularTerm = context.read<TerminologyProvider>().singular.toLowerCase();

    // Send welcome message with user's terminology
    _chatService.addSystemMessage(
      'Hi! 👋 I\'m your AI assistant. I can help you with:\n\n'
      '• Viewing your schedule and $terminology\n'
      '• Marking your availability\n'
      '• Accepting or declining $singularTerm offers\n'
      '• Tracking your earnings\n'
      '• Answering questions about $terminology\n\n'
      'What would you like help with?'
    );
    setState(() {});

    // With reverse: true, welcome message appears at bottom automatically
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

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
      // With reverse: true, new messages appear at bottom automatically - no scroll needed!
      // Refresh usage stats after sending message
      _loadSubscriptionStatus();
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to get AI response. Please try again.'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text('This will delete all messages in the current conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Save summary before clearing if there was meaningful conversation
              // (more than just the welcome message)
              if (_chatService.conversationHistory.length > 1) {
                _saveChatSummary(
                  outcome: 'question_answered',
                  outcomeReason: 'User cleared conversation',
                );
              }

              _chatService.clearConversation();
              AnimatedAiMessageWidget.clearAnimationTracking(); // Clear animation tracking
              Navigator.pop(context);
              setState(() {});

              // Re-add welcome message
              _chatService.addSystemMessage(
                'Conversation cleared. How can I help you?'
              );
              setState(() {});
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
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

  @override
  Widget build(BuildContext context) {
    // Detect keyboard and auto-scroll when it opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      // Keyboard is open, scroll to bottom (position 0 with reverse: true)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // With reverse: true, 0 is the bottom
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surfaceLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'AI Assistant',
          style: TextStyle(color: AppColors.navySpaceCadet),
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

          // Clear conversation
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearConversation,
            tooltip: 'Clear conversation',
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
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true, // EXPERT: Makes new messages appear at bottom naturally
                        padding: EdgeInsets.only(
                          top: 16,
                          bottom: 140 + keyboardHeight, // Extra padding for chips + input area + keyboard
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
                  bottom: keyboardHeight,
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
                              child: Row(
                                children: [
                                  _buildSuggestionChip(
                                    '📋 My Schedule',
                                    'Show my upcoming shifts',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSuggestionChip(
                                    '🔜 Next Shift',
                                    'What is my next shift?',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSuggestionChip(
                                    '📅 This Week',
                                    'Show my shifts this week',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSuggestionChip(
                                    '💰 Earnings',
                                    'How much did I earn this month?',
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSuggestionChip(
                                    '📍 Where',
                                    'Where is my next shift?',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Chat input
                        ChatInputWidget(
                          onSendMessage: _sendMessage,
                          isLoading: _chatService.isLoading,
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
