import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';
import '../shared/widgets/initials_avatar.dart';
import 'chat_page.dart';
import '../features/ai_assistant/presentation/staff_ai_chat_screen.dart';

class ConversationsPage extends StatefulWidget {
  final Widget profileMenu;
  final VoidCallback? onTitleTap;

  const ConversationsPage({
    super.key,
    required this.profileMenu,
    this.onTitleTap,
  });

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _conversations = <Conversation>[];
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _listenToNewMessages();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _listenToNewMessages() {
    _chatService.messageStream.listen((message) {
      // Refresh conversations when a new message arrives
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final conversations = await _chatService.fetchConversations();

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Header height: title row (~62) + search bar (~60) + divider (1) + 2px buffer
    const double headerHeight = 125.0;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable content behind the header
            Padding(
              padding: const EdgeInsets.only(top: headerHeight),
              child: _buildBody(),
            ),
            // Frosted glass header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: widget.onTitleTap,
                                child: Text(
                                  l10n.chats,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              widget.profileMenu,
                              IconButton(
                                onPressed: _showManagerPicker,
                                icon: const Icon(Icons.add_comment_rounded, size: 22),
                                color: AppColors.navySpaceCadet,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: l10n.search,
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: AppColors.textMuted,
                                          size: 18,
                                        ),
                                        onPressed: () => _searchController.clear(),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManagerPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagerPickerSheet(
        onManagerSelected: (manager) {
          Navigator.pop(context);
          _openNewChat(manager);
        },
      ),
    );
  }

  void _openNewChat(Map<String, dynamic> manager) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          managerId: manager['id'] as String,
          managerName: manager['name'] as String? ?? 'Manager',
          managerPicture: manager['picture'] as String?,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadConversations,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadConversations,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    // Filter conversations by search query
    final filteredConversations = _searchQuery.isEmpty
        ? _conversations
        : _conversations.where((c) {
            final name = c.displayName.toLowerCase();
            final preview = (c.lastMessagePreview ?? '').toLowerCase();
            return name.contains(_searchQuery) || preview.contains(_searchQuery);
          }).toList();

    // Check if Valerio Assistant matches search
    final showAssistant = _searchQuery.isEmpty ||
        l10n.valerioAssistant.toLowerCase().contains(_searchQuery);

    if (filteredConversations.isEmpty && !showAssistant) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.search_off, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 16),
            Text(
              l10n.noResults,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty && showAssistant) {
      // Still show Valerio Assistant even when empty
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          children: <Widget>[
            _ValerioAssistantTile(
              onTap: () => _openAIChat(),
            ),
            const Divider(height: 1),
            const SizedBox(height: 100),
            Center(
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
                    l10n.noConversationsYet,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.yourManagerWillAppearHere,
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        itemCount: filteredConversations.length + (showAssistant ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          // First item is the pinned Valerio Assistant (if visible)
          if (showAssistant && index == 0) {
            return _ValerioAssistantTile(
              onTap: () => _openAIChat(),
            );
          }

          final conversationIndex = showAssistant ? index - 1 : index;
          final conversation = filteredConversations[conversationIndex];
          return _ConversationTile(
            conversation: conversation,
            onTap: () => _openChat(conversation),
          );
        },
      ),
    );
  }

  void _openChat(Conversation conversation) {
    // Debug logging
    print('[CHAT DEBUG] Opening chat with managerId: ${conversation.managerId}');
    print('[CHAT DEBUG] Conversation ID: ${conversation.id}');
    print('[CHAT DEBUG] Manager name: ${conversation.displayName}');

    if (conversation.managerId == null || conversation.managerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorManagerIdMissing),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatPage(
              managerId: conversation.managerId!,
              managerName: conversation.displayName,
              managerPicture: conversation.displayPicture,
              conversationId: conversation.id,
            ),
          ),
        )
        .then((_) => _loadConversations());
  }

  void _openAIChat() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const StaffAIChatScreen(),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            // Avatar
            Stack(
              children: <Widget>[
                UserAvatar(
                  imageUrl: conversation.displayPicture,
                  fullName: conversation.displayName,
                  radius: 28,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          conversation.unreadCount > 9
                              ? '9+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          conversation.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          timeago.format(conversation.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted, // Grey for all timestamps
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessagePreview ?? AppLocalizations.of(context)!.noMessagesYet,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread ? AppColors.textDark : AppColors.textSecondary,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
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

}

/// Pinned Valerio Assistant chat tile
class _ValerioAssistantTile extends StatelessWidget {
  const _ValerioAssistantTile({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryPurple.withOpacity(0.08), // Navy blue tint
              AppColors.primaryPurple.withOpacity(0.05),
            ],
          ),
        ),
        child: Row(
          children: <Widget>[
            // Valerio Avatar - AI mascot logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        l10n.valerioAssistant,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Pin icon
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: AppColors.textMuted, // Grey pin icon
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.valerioAssistantDescription,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
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
                  l10n.newChat,
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
