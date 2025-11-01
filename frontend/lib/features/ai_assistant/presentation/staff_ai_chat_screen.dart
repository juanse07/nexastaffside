import 'package:flutter/material.dart';

import '../services/staff_chat_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/availability_confirmation_card.dart';
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

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
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

    // Send welcome message
    _chatService.addSystemMessage(
      'Hi! 👋 I\'m your AI assistant. I can help you with:\n\n'
      '• Viewing your schedule and shifts\n'
      '• Marking your availability\n'
      '• Accepting or declining shift offers\n'
      '• Tracking your earnings\n'
      '• Answering questions about events\n\n'
      'What would you like help with?'
    );
    setState(() {});

    _scrollToBottom();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Clear old pending actions
    setState(() {});

    final response = await _chatService.sendMessage(message);
    if (response != null) {
      setState(() {});
      _scrollToBottom();
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
    final eventName = shiftAction['event_name'] as String;

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

  /// Change AI provider
  void _changeProvider() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose AI Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              title: const Text('Claude Sonnet 4.5'),
              subtitle: const Text('Fast, efficient, with prompt caching'),
              trailing: _chatService.selectedProvider == AIProvider.claude
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                _chatService.setProvider(AIProvider.claude);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to Claude Sonnet')),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🧠',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              title: const Text('GPT-4o'),
              subtitle: const Text('OpenAI\'s latest model'),
              trailing: _chatService.selectedProvider == AIProvider.openai
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                _chatService.setProvider(AIProvider.openai);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to GPT-4o')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // AI Provider selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: _changeProvider,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _chatService.selectedProvider == AIProvider.claude
                      ? Colors.orange.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _chatService.selectedProvider == AIProvider.claude
                          ? 'Claude'
                          : 'GPT-4',
                      style: TextStyle(
                        color: _chatService.selectedProvider == AIProvider.claude
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: _chatService.selectedProvider == AIProvider.claude
                          ? Colors.orange.shade900
                          : Colors.blue.shade900,
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
                          onLinkTap: (linkText) {
                            // Handle link taps (e.g., navigate to schedule)
                            print('Link tapped: $linkText');
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
