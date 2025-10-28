import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/data_service.dart';
import '../widgets/event_invitation_card.dart';

// Global cache to persist event data across widget rebuilds
final Map<String, Map<String, dynamic>> _globalEventCache = {};

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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToNewMessages();
    _markAsRead();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initiateCall() async {
    // For now, we'll show a dialog since we don't have the manager's phone number
    // In a real app, you'd have the phone number from the manager's profile
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Manager'),
        content: Text('Call ${widget.managerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, you would have the manager's phone number
              // and would use: launchUrl(Uri(scheme: 'tel', path: phoneNumber))
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calling feature will be available soon'),
                ),
              );
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7C3AED), // Purple 600
                Color(0xFF6366F1), // Indigo 500
                Color(0xFF8B5CF6), // Purple 500
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative shadow shapes
              Positioned(
                top: -20,
                right: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              // AppBar content
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                title: Row(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: widget.managerPicture != null
                            ? NetworkImage(widget.managerPicture!)
                            : null,
                        child: widget.managerPicture == null
                            ? Text(
                                _getInitials(widget.managerName),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.managerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: _initiateCall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _buildMessageList(),
          ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Failed to load messages'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
              // Check if it's an invitation card or regular message
              message.messageType == 'eventInvitation'
                  ? _buildInvitationCard(message)
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String label;
    if (messageDate == today) {
      label = 'Today';
    } else if (messageDate == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
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
                color: Colors.grey[600],
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

  Widget _buildInvitationCard(ChatMessage message) {
    final metadata = message.metadata ?? {};
    final eventId = metadata['eventId'] as String?;
    final roleId = metadata['roleId'] as String?;
    final status = metadata['status'] as String?;
    final respondedAt = metadata['respondedAt'] != null
        ? DateTime.parse(metadata['respondedAt'] as String)
        : null;

    debugPrint('[INVITATION_ANALYTICS] invitation_card_displayed');
    debugPrint('[INVITATION_ANALYTICS] messageId: ${message.id}');
    debugPrint('[INVITATION_ANALYTICS] eventId: $eventId');
    debugPrint('[INVITATION_ANALYTICS] roleId: $roleId');
    debugPrint('[INVITATION_ANALYTICS] status: $status');
    debugPrint('[INVITATION_ANALYTICS] userRole: staff');

    if (eventId == null || roleId == null) {
      debugPrint('[INVITATION_ANALYTICS] invitation_card_error: missing eventId or roleId');
      return const SizedBox.shrink();
    }

    // Check cache first
    if (_globalEventCache.containsKey(message.id)) {
      return _buildInvitationCardWidget(
        _globalEventCache[message.id]!,
        roleId,
        status,
        respondedAt,
        message,
        eventId,
      );
    }

    // Fetch event data using the new invitation endpoint only if not cached
    return FutureBuilder<Map<String, dynamic>>(
      future: _chatService.fetchInvitationEvent(message.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint('[INVITATION_ANALYTICS] invitation_card_error: event not found');
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Event not found'),
          );
        }

        final eventData = snapshot.data!;

        // Cache the result
        _globalEventCache[message.id] = eventData;

        return _buildInvitationCardWidget(
          eventData,
          roleId,
          status,
          respondedAt,
          message,
          eventId,
        );
      },
    );
  }

  Widget _buildInvitationCardWidget(
    Map<String, dynamic> eventData,
    String roleId,
    String? status,
    DateTime? respondedAt,
    ChatMessage message,
    String eventId,
  ) {
    final roles = eventData['roles'] as List<dynamic>? ?? [];
    final role = roles.cast<Map<String, dynamic>>().firstWhere(
      (r) => (r['_id'] ?? r['role_id'] ?? r['role']) == roleId,
      orElse: () => <String, dynamic>{},
    );

    final eventName = eventData['title'] as String? ?? eventData['event_name'] as String? ?? 'Event';
    final roleName = role['role_name'] as String? ?? role['role'] as String? ?? 'Role';
    final clientName = eventData['client_name'] as String? ?? 'Client';
    final venueName = eventData['venue_name'] as String? ?? eventData['venue_address'] as String?;
    final rate = role['rate'] as num? ?? (role['tariff'] as Map<String, dynamic>?)?['rate'] as num?;
    final startDateStr = eventData['start_date'] as String? ?? eventData['date'] as String?;
    final startDate = startDateStr != null
        ? DateTime.parse(startDateStr)
        : DateTime.now();
    final endDate = eventData['end_date'] != null
        ? DateTime.parse(eventData['end_date'] as String)
        : startDate.add(const Duration(hours: 4));

    debugPrint('[INVITATION_ANALYTICS] invitation_card_loaded successfully');
    debugPrint('[INVITATION_ANALYTICS] eventName: $eventName');
    debugPrint('[INVITATION_ANALYTICS] roleName: $roleName');
    debugPrint('[INVITATION_ANALYTICS] venueName: $venueName');

    return EventInvitationCard(
      key: ValueKey('invitation_${message.id}'),
      eventName: eventName,
      roleName: roleName,
      clientName: clientName,
      startDate: startDate,
      endDate: endDate,
      venueName: venueName,
      rate: rate?.toDouble(),
      status: status,
      respondedAt: respondedAt,
      onAccept: status == null || status == 'pending'
          ? () => _handleInvitationResponse(message, eventId, roleId, true)
          : null,
      onDecline: status == null || status == 'pending'
          ? () => _showDeclineConfirmation(message, eventId, roleId)
          : null,
    );
  }

  Future<void> _showDeclineConfirmation(
    ChatMessage message,
    String eventId,
    String roleId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Invitation?'),
        content: const Text(
          'Are you sure you want to decline this event invitation? '
          'The manager will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleInvitationResponse(message, eventId, roleId, false);
    }
  }

  Future<void> _handleInvitationResponse(
    ChatMessage message,
    String eventId,
    String roleId,
    bool accept,
  ) async {
    final startTime = DateTime.now();
    final sentAt = message.createdAt;
    final responseTimeMinutes = startTime.difference(sentAt).inMinutes;

    debugPrint('[INVITATION_ANALYTICS] invitation_responded event started');
    debugPrint('[INVITATION_ANALYTICS] messageId: ${message.id}');
    debugPrint('[INVITATION_ANALYTICS] eventId: $eventId');
    debugPrint('[INVITATION_ANALYTICS] roleId: $roleId');
    debugPrint('[INVITATION_ANALYTICS] accept: $accept');
    debugPrint('[INVITATION_ANALYTICS] responseTimeMinutes: $responseTimeMinutes');
    debugPrint('[INVITATION_ANALYTICS] managerId: ${widget.managerId}');

    try {
      await _chatService.respondToInvitation(
        messageId: message.id,
        eventId: eventId,
        roleId: roleId,
        accept: accept,
      );

      final duration = DateTime.now().difference(startTime);
      debugPrint('[INVITATION_ANALYTICS] invitation_responded success');
      debugPrint('[INVITATION_ANALYTICS] apiCallDuration: ${duration.inMilliseconds}ms');
      debugPrint('[INVITATION_ANALYTICS] accepted: $accept');

      // Update the message locally to reflect the response
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1 && mounted) {
        setState(() {
          // The backend will update the message and send it via socket
          // For now, we'll wait for the socket update
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted!' : 'Invitation declined'),
            backgroundColor: accept ? Colors.green : Colors.grey.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Reload messages to get updated status
      await _loadMessages();

      // Refresh events and availability to update Available Roles and My Events
      if (accept) {
        debugPrint('[INVITATION_ANALYTICS] refreshing events after accept');
        try {
          final dataService = context.read<DataService>();
          debugPrint('🎯 Event accepted, invalidating cache and refreshing...');
          await dataService.invalidateEventsCache();
          await dataService.forceRefresh();
          debugPrint('🎯 Refresh complete after event accept');
          debugPrint('[INVITATION_ANALYTICS] events refreshed successfully');
        } catch (refreshError) {
          debugPrint('[INVITATION_ANALYTICS] error refreshing events: $refreshError');
          // Don't fail the whole operation if refresh fails
        }
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('[INVITATION_ANALYTICS] invitation_error');
      debugPrint('[INVITATION_ANALYTICS] error: $e');
      debugPrint('[INVITATION_ANALYTICS] messageId: ${message.id}');
      debugPrint('[INVITATION_ANALYTICS] eventId: $eventId');
      debugPrint('[INVITATION_ANALYTICS] step: respond');
      debugPrint('[INVITATION_ANALYTICS] duration: ${duration.inMilliseconds}ms');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to respond: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
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
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7C3AED), // Light purple
                    Color(0xFF6366F1), // Medium purple
                    Color(0xFF4F46E5), // Darker purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
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
                      : const Icon(Icons.send, color: Color(0xFFB8860B), size: 22),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
    final theme = Theme.of(context);
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
              if (!isMe) ...<Widget>[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  backgroundImage: message.senderPicture != null
                      ? NetworkImage(message.senderPicture!)
                      : null,
                  child: message.senderPicture == null
                      ? Text(
                          (message.senderName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? theme.primaryColor : Colors.grey[200],
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
                          DateFormat('h:mm a').format(message.createdAt),
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
