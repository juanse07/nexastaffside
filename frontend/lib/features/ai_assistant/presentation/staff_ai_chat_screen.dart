import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/terminology_provider.dart';
import '../../../shared/presentation/theme/theme.dart';
import '../../../services/subscription_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _isInitialized = false;
  String _subscriptionTier = 'free';
  int _aiMessagesUsed = 0;
  int _aiMessagesLimit = 20; // Free tier limit (changed from 50 to reduce costs)

  // Scroll-based chips visibility
  bool _showChips = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadSubscriptionStatus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll to hide/show chips bar
  void _onScroll() {
    final currentOffset = _scrollController.offset;
    // Note: With reverse: true, scrolling "up" (to older messages) increases offset
    // Scrolling "down" (to newer messages) decreases offset toward 0
    final scrollingToOlder = currentOffset > _lastScrollOffset;
    final scrollingToNewer = currentOffset < _lastScrollOffset;

    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      if (scrollingToOlder && _showChips && currentOffset > 50) {
        setState(() => _showChips = false);
      } else if (scrollingToNewer && !_showChips) {
        setState(() => _showChips = true);
      }
      _lastScrollOffset = currentOffset;
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

    // Pass model preference and terminology to chat service
    final response = await _chatService.sendMessage(
      message,
      modelPreference: 'llama', // Default to fast model
      terminology: terminology,
    );
    if (response != null) {
      setState(() {});
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

  /// Build a suggestion chip for quick actions
  Widget _buildSuggestionChip(String label, String query) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.7),
            Colors.white.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _sendMessage(query),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
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
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'AI Assistant',
          style: TextStyle(color: AppColors.navySpaceCadet),
        ),
        backgroundColor: AppColors.backgroundWhite,
        foregroundColor: AppColors.navySpaceCadet,
        iconTheme: const IconThemeData(color: AppColors.navySpaceCadet),
        elevation: 0,
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

                // Floating chips layer (positioned over messages, hides on scroll)
                if (!_chatService.isLoading)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 60 + (MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8),
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 200),
                      offset: _showChips ? Offset.zero : const Offset(0, 1),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _showChips ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_showChips,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.surfaceLight.withOpacity(0.3),
                                  AppColors.surfaceLight.withOpacity(0.6),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSuggestionChip(
                                    '📋 Next 7 Jobs',
                                    'Show my next 7 jobs',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '🔜 Next Shift',
                                    'When is my next shift?',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '📅 Last Month',
                                    'Show all my shifts from last month',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '💰 Earnings',
                                    'How much have I earned this month?',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '📍 Upcoming',
                                    'What are my upcoming events?',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Input field layer (at bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: AppColors.backgroundWhite,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom
                        : 8, // Extra padding if no safe area
                    ),
                    child: ChatInputWidget(
                      onSendMessage: _sendMessage,
                      isLoading: _chatService.isLoading,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
