import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/terminology_provider.dart';
import '../../../services/subscription_service.dart';
import '../services/staff_chat_service.dart';
import '../widgets/availability_confirmation_card.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/shift_action_card.dart';

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
  int _aiMessagesLimit = 50;
  String _selectedModel = 'llama'; // 'llama' (default) or 'gpt-oss'

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    _scrollToBottom();
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
      modelPreference: _selectedModel,
      terminology: terminology,
    );
    if (response != null) {
      setState(() {});
      _scrollToBottom();
      // Refresh usage stats after sending message
      _loadSubscriptionStatus();
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get AI response. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
        backgroundColor: Colors.green,
      ),
    );

    _chatService.clearPendingAvailability();
    _chatService.addSystemMessage('✅ Your availability has been updated successfully!');
    setState(() {});
    _scrollToBottom();
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
        backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
      ),
    );

    _chatService.clearPendingShiftAction();
    _chatService.addSystemMessage(
      action == 'accept'
          ? '🎉 Great! You\'re confirmed for $eventName. Your manager has been notified.'
          : '👍 No problem! $eventName has been declined. Your manager has been notified.'
    );
    setState(() {});
    _scrollToBottom();
  }

  /// Cancel availability confirmation
  void _cancelAvailability() {
    _chatService.clearPendingAvailability();
    _chatService.addSystemMessage('Availability update cancelled.');
    setState(() {});
    _scrollToBottom();
  }

  /// Cancel shift action
  void _cancelShiftAction() {
    _chatService.clearPendingShiftAction();
    _chatService.addSystemMessage('Shift action cancelled.');
    setState(() {});
    _scrollToBottom();
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
              Navigator.pop(context);
              setState(() {});

              // Re-add welcome message
              _chatService.addSystemMessage(
                'Conversation cleared. How can I help you?'
              );
              setState(() {});
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Build a suggestion chip for quick actions
  Widget _buildSuggestionChip(String label, String query) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _sendMessage(query),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300, width: 1),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      pressElevation: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect keyboard and auto-scroll when it opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      // Keyboard is open, scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Usage indicator for free tier
          if (_subscriptionTier == 'free')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to upgrade screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Upgrade to Pro for unlimited AI messages!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _aiMessagesUsed >= 40
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _aiMessagesUsed >= 40
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
                        color: _aiMessagesUsed >= 40
                            ? Colors.orange.shade900
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_aiMessagesUsed/$_aiMessagesLimit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _aiMessagesUsed >= 40
                              ? Colors.orange.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Model selector (llama vs gpt-oss)
          PopupMenuButton<String>(
            icon: Icon(
              _selectedModel == 'llama' ? Icons.bolt : Icons.speed,
              color: const Color(0xFF6366F1),
            ),
            tooltip: 'Select AI Model',
            onSelected: (String value) {
              setState(() {
                _selectedModel = value;
              });
              // Show snackbar with model info
              String modelInfo;
              if (value == 'llama') {
                modelInfo = 'Llama 3.1 8B: Fast & economical (560 T/sec)';
              } else {
                modelInfo = 'GPT-OSS 20B: More capable (1000 T/sec)';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(modelInfo),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF6366F1),
                ),
              );
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'llama',
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 20,
                      color: _selectedModel == 'llama' ? const Color(0xFF6366F1) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Llama 3.1 8B',
                          style: TextStyle(
                            fontWeight: _selectedModel == 'llama' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'Fast & economical',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    if (_selectedModel == 'llama')
                      const Icon(Icons.check, size: 16, color: Color(0xFF6366F1)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'gpt-oss',
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 20,
                      color: _selectedModel == 'gpt-oss' ? const Color(0xFF6366F1) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPT-OSS 20B',
                          style: TextStyle(
                            fontWeight: _selectedModel == 'gpt-oss' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'More powerful',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    if (_selectedModel == 'gpt-oss')
                      const Icon(Icons.check, size: 16, color: Color(0xFF6366F1)),
                  ],
                ),
              ),
            ],
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
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: _chatService.conversationHistory.length +
                        (_chatService.pendingAvailability != null ? 1 : 0) +
                        (_chatService.pendingShiftAction != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Regular messages
                      if (index < _chatService.conversationHistory.length) {
                        final message = _chatService.conversationHistory[index];

                        // Skip system messages that are just markers
                        if (message.role == 'system' &&
                            (message.content.contains('AVAILABILITY_MARK') ||
                             message.content.contains('SHIFT_ACCEPT') ||
                             message.content.contains('SHIFT_DECLINE'))) {
                          return const SizedBox.shrink();
                        }

                        return ChatMessageWidget(
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
                        );
                      }

                      // Availability confirmation card
                      if (_chatService.pendingAvailability != null &&
                          index == _chatService.conversationHistory.length) {
                        return AvailabilityConfirmationCard(
                          availabilityData: _chatService.pendingAvailability!,
                          onConfirm: _confirmAvailability,
                          onCancel: _cancelAvailability,
                        );
                      }

                      // Shift action confirmation card
                      if (_chatService.pendingShiftAction != null) {
                        return ShiftActionCard(
                          shiftAction: _chatService.pendingShiftAction!,
                          onConfirm: _confirmShiftAction,
                          onCancel: _cancelShiftAction,
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),

                // Quick action suggestion chips (zero AI cost!)
                if (!_chatService.isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200, width: 1),
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

                // Input field
                SafeArea(
                  child: ChatInputWidget(
                    onSendMessage: _sendMessage,
                    isLoading: _chatService.isLoading,
                  ),
                ),
              ],
            ),
    );
  }
}
