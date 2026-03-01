import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../auth_service.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../shared/widgets/initials_avatar.dart';
import '../services/subscription_service.dart';
import '../shared/widgets/subscription_gate.dart';
import '../widgets/ai_message_composer.dart';
class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.managerId,
    required this.managerName,
    this.managerPicture,
    this.conversationId,
    super.key,
  });

  final String managerId;
  final String managerName;
  final String? managerPicture;
  final String? conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  bool _loading = true;
  String? _error;
  bool _sending = false;
  StreamSubscription<ChatMessage>? _messageSubscription;
  String? _visibleDate; // Tracks the currently visible date section

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToNewMessages();
    _markAsRead();
    _scrollController.addListener(_updateVisibleDate);
  }

  void _updateVisibleDate() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;

    // Get the scroll position
    final scrollOffset = _scrollController.offset;

    // Since we use reverse: true, messages are displayed newest first (index 0)
    // As we scroll up (increasing offset), we see older messages
    // Messages are in chronological order in the list (oldest at end)

    // Approximate: each message is ~80px, find the visible index
    final approximateIndex = (scrollOffset / 80).floor();

    // When scrolling up (increasing offset), we want to show older dates
    // So we need to go from beginning (newest) toward end (oldest)
    final targetIndex = approximateIndex.clamp(0, _messages.length - 1);

    if (targetIndex < _messages.length) {
      final message = _messages[_messages.length - 1 - targetIndex]; // Reverse the index
      final newDate = DateFormat('MMM d, yyyy').format(message.createdAt.toLocal());

      if (_visibleDate != newDate) {
        setState(() {
          _visibleDate = newDate;
        });
      }
    }
  }

  void _listenToNewMessages() {
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (widget.conversationId != null &&
          message.conversationId == widget.conversationId) {
        // Check for duplicate message (by ID)
        final isDuplicate = _messages.any((m) => m.id == message.id);

        if (!isDuplicate) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
          _markAsRead();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    if (widget.conversationId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final messages = await _chatService.fetchMessages(widget.conversationId!);

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
        // Set initial visible date to most recent message
        if (_messages.isNotEmpty) {
          _visibleDate = DateFormat('MMM d, yyyy').format(_messages.first.createdAt.toLocal());
        }
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    if (widget.conversationId != null) {
      try {
        await _chatService.markAsRead(widget.conversationId!);
      } catch (e) {
        // Silently fail
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    // With reverse: true, we scroll to 0 to reach the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(0);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    // Block read-only users from sending chat messages
    if (SubscriptionService().isReadOnly) {
      showSubscriptionRequiredSheet(context, featureName: AppLocalizations.of(context)!.chatWithManagers);
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final sentMessage = await _chatService.sendMessage(widget.managerId, message);
      _messageController.clear();

      // Immediately add the sent message to UI
      if (mounted) {
        setState(() {
          _messages.add(sentMessage);
        });
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSendMessage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  /// Show the AI message composer bottom sheet
  Future<void> _showAiComposer() async {
    // Haptic feedback to indicate long-press was detected
    HapticFeedback.mediumImpact();

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.pleaseLoginToUseAI),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      AiMessageComposer.show(
        context: context,
        authToken: token,
        initialText: _messageController.text.trim(),
        onMessageComposed: (composedMessage) {
          // Insert the AI-composed message into the text field
          setState(() {
            _messageController.text = composedMessage;
            // Move cursor to end
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
          });
        },
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToOpenAIComposer(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _showFullImage(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                      ),
                    ),
                  ),
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
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _initiateCall() async {
    final l10n = AppLocalizations.of(context)!;
    // For now, we'll show a dialog since we don't have the manager's phone number
    // In a real app, you'd have the phone number from the manager's profile
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.callManager),
        content: Text(l10n.callPerson(widget.managerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, you would have the manager's phone number
              // and would use: launchUrl(Uri(scheme: 'tel', path: phoneNumber))
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.callingFeatureAvailableSoon),
                ),
              );
            },
            icon: const Icon(Icons.phone),
            label: Text(l10n.call),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Detect keyboard and auto-scroll when it opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      // Keyboard is open, scroll to bottom (reverse list, so scroll to 0)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        foregroundColor: AppColors.navySpaceCadet,
        iconTheme: const IconThemeData(color: AppColors.navySpaceCadet),
        title: Row(
          children: <Widget>[
            GestureDetector(
              onTap: widget.managerPicture != null && widget.managerPicture!.isNotEmpty
                  ? () => _showFullImage(widget.managerPicture!)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.oceanBlue,
                    width: 2,
                  ),
                ),
                child: UserAvatar(
                  imageUrl: widget.managerPicture,
                  fullName: widget.managerName,
                  radius: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.managerName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navySpaceCadet,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 22),
            onPressed: _initiateCall,
            color: AppColors.navySpaceCadet,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(l10n.failedToLoadMessages),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadMessages,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/chat_empty.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noMessagesYetTitle,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sendMessageToStart,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // This makes latest messages stay at bottom
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          // Reverse the index since we're using reverse: true
          final reversedIndex = _messages.length - 1 - index;
          final message = _messages[reversedIndex];
          final isMe = message.senderType == SenderType.user;

          // Check if we should show date (compare with next message in original order)
          final showDate = reversedIndex == 0 ||
              !_isSameDay(_messages[reversedIndex - 1].createdAt, message.createdAt);

          return Column(
            key: ValueKey(message.id), // Prevent unnecessary rebuilds
            children: <Widget>[
              // Check if it's an invitation stamp or regular message
              message.messageType == 'eventInvitation'
                  ? _buildInvitationStamp(message)
                  : message.messageType == 'broadcast'
                      ? _buildBroadcastStamp(message)
                      : _MessageBubble(
                      key: ValueKey('bubble_${message.id}'),
                      message: message,
                      isMe: isMe,
                    ),
              // Add small spacing between messages
              const SizedBox(height: 4),
              if (showDate) _buildDateDivider(message.createdAt),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(localDate.year, localDate.month, localDate.day);

    String label;
    if (messageDate == today) {
      label = l10n.today;
    } else if (messageDate == yesterday) {
      label = l10n.yesterday;
    } else {
      label = DateFormat('MMM d, yyyy').format(localDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildInvitationStamp(ChatMessage message) {
    final metadata = message.metadata ?? {};
    final status = metadata['status'] as String?;
    final respondedAt = metadata['respondedAt'] != null
        ? DateTime.tryParse(metadata['respondedAt'] as String)
        : null;
    final invitationText = message.message;
    final sentDate = DateFormat('MMM d').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          // Invitation stamp
          Row(
            children: <Widget>[
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '\u{1F4E9} $invitationText \u00B7 $sentDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          // Response stamp
          if (status == 'accepted' || status == 'declined')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                status == 'accepted'
                    ? '\u2705 Accepted \u00B7 ${_formatStampTime(respondedAt)}'
                    : '\u274C Declined \u00B7 ${_formatStampTime(respondedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: status == 'accepted' ? Colors.green[600] : Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '\u23F3 Waiting for response...',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBroadcastStamp(ChatMessage message) {
    final l10n = AppLocalizations.of(context)!;
    final metadata = message.metadata ?? {};
    final broadcastType = metadata['broadcastType'] as String?;
    final eventName = metadata['eventName'] as String?;
    final sentDate = DateFormat('MMM d').format(message.createdAt.toLocal());

    final tagLine = broadcastType == 'event' && eventName != null
        ? '\u{1F4E2} ${l10n.broadcastSentToAllEvent(eventName)} \u00B7 $sentDate'
        : '\u{1F4E2} ${l10n.broadcastTeamMessage} \u00B7 $sentDate';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Divider(color: AppColors.techBlue.withOpacity(0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  tagLine,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.techBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.techBlue.withOpacity(0.3))),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.techBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.techBlue.withOpacity(0.15)),
            ),
            child: Text(
              message.message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStampTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final date = DateFormat('MMM d').format(dateTime);
    final time = DateFormat('h:mm a').format(dateTime);
    return '$date at $time';
  }

  Widget _buildMessageInput() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0x1A000000), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: l10n.typeAMessage,
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      tooltip: l10n.aiMessageAssistant,
                      onPressed: _showAiComposer,
                      padding: const EdgeInsets.all(8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryPurple, // Navy blue solid background
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: AppColors.yellow, size: 22), // Yellow icon
                  onPressed: _sending ? null : _sendMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.75;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 900 ? 800 : screenWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primaryPurple : Colors.grey[200], // Navy blue for sent
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (!isMe && message.senderName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message.senderName!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        Text(
                          message.message,
                          style: TextStyle(
                            fontSize: 15,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('h:mm a').format(message.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
