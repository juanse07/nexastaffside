import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/staff_chat_service.dart';

/// Widget to display a single chat message bubble
/// Adapted for staff app
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final String? userProfilePicture;
  final void Function(String)? onLinkTap;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onLinkTap,
    this.userProfilePicture,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: const Icon(
                  Icons.smart_toy, // AI assistant icon
                  size: 20,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF7C3AED), // Light purple
                              Color(0xFF6366F1), // Medium purple
                              Color(0xFF4F46E5), // Darker purple
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF7C3AED).withOpacity(0.3)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(isUser),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeFormat.format(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    // Show AI provider badge for assistant messages
                    if (!isUser && message.provider != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: message.provider == AIProvider.claude
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.provider == AIProvider.claude
                              ? 'Claude'
                              : 'GPT-4',
                          style: TextStyle(
                            color: message.provider == AIProvider.claude
                                ? Colors.orange.shade900
                                : Colors.blue.shade900,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: userProfilePicture != null && userProfilePicture!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        userProfilePicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.white,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build message content with support for clickable links and addresses
  Widget _buildMessageContent(bool isUser) {
    final content = message.content;
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for [LINK:...] pattern
      final linkPattern = RegExp(r'\[LINK:([^\]]+)\]');
      final linkMatch = linkPattern.firstMatch(line);

      if (linkMatch != null) {
        widgets.add(_buildClickableLink(line, linkMatch, isUser));
        continue;
      }

      // Check for address patterns: "- Lugar:" or "- Venue:" (with optional markdown bold **)
      final addressPattern = RegExp(
        r'^[\s\-]*\*{0,2}(Lugar|Venue)\*{0,2}:\s*(.+)$',
        caseSensitive: false,
      );
      final addressMatch = addressPattern.firstMatch(line);

      if (addressMatch != null) {
        // Check if next line looks like a street address (starts with a number)
        String fullAddress = addressMatch.group(2)!.trim();
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final streetAddressPattern = RegExp(r'^\d+\s+');
          if (streetAddressPattern.hasMatch(nextLine)) {
            // Multi-line address: combine venue name and street address
            fullAddress = '$fullAddress $nextLine';
            i++; // Skip the next line since we've consumed it
          }
        }

        widgets.add(_buildAddressLine(line, addressMatch, isUser, fullAddress));
        continue;
      }

      // Regular text line
      widgets.add(
        Text(
          line,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Build a clickable link from [LINK:...] pattern
  Widget _buildClickableLink(String line, RegExpMatch match, bool isUser) {
    final beforeLink = line.substring(0, match.start);
    final linkText = match.group(1)!;
    final afterLink = line.substring(match.end);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (beforeLink.isNotEmpty)
          Text(
            beforeLink,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        GestureDetector(
          onTap: () => onLinkTap?.call(linkText),
          child: Text(
            linkText,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF3B82F6),
              fontSize: 15,
              height: 1.4,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (afterLink.isNotEmpty)
          Text(
            afterLink,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  /// Build a clickable address line with maps icon
  Widget _buildAddressLine(String line, RegExpMatch match, bool isUser, String fullAddress) {
    final address = fullAddress; // Use the full address (may include next line)
    final prefix = line.substring(0, match.start + match.group(0)!.indexOf(':') + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prefix (e.g., "- Lugar:")
          Text(
            prefix,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 4),
          // Clickable address
          Expanded(
            child: GestureDetector(
              onTap: () => _openMaps(address),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF3B82F6),
                        fontSize: 15,
                        height: 1.4,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: isUser ? Colors.white : const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open Google Maps with the address
  Future<void> _openMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);

    // Try multiple URL schemes for best compatibility
    final urls = [
      // Google Maps app (if installed)
      'comgooglemaps://?q=$encodedAddress',
      // Apple Maps (iOS)
      'https://maps.apple.com/?q=$encodedAddress',
      // Google Maps web (fallback)
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    ];

    for (final urlString in urls) {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Final fallback: Google Maps web in browser
    final fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
  }
}
