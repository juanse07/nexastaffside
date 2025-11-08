import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Simple event invitation card matching Available Roles design
class EventInvitationCard extends StatelessWidget {
  const EventInvitationCard({
    required this.eventName,
    required this.roleName,
    required this.clientName,
    required this.startDate,
    required this.endDate,
    this.venueName,
    this.rate,
    this.currency = 'USD',
    this.status,
    this.respondedAt,
    this.onAccept,
    this.onDecline,
    super.key,
  });

  final String eventName;
  final String roleName;
  final String clientName;
  final DateTime startDate;
  final DateTime endDate;
  final String? venueName;
  final double? rate;
  final String currency;
  final String? status; // null, 'accepted', 'declined'
  final DateTime? respondedAt;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final isPending = status == null || status == 'pending';
    final isAccepted = status == 'accepted';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with role name and status badge
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAccepted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF7C3AED), // Purple for invitations
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    roleName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                // Status badge in top-right corner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAccepted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF7C3AED), // Purple for invitations
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAccepted ? Icons.check_circle : Icons.mail_outline,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAccepted ? 'Accepted' : 'Invitation',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DATE & TIME - Highlighted prominently at top
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date - Large and prominent
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: isAccepted
                            ? const Color(0xFF16A34A).withOpacity(0.5) // Subtle green for accepted
                            : const Color(0xFF7C3AED), // Purple for invitations
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM').format(startDate), // "3 Nov" format
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('(EEEE)').format(startDate), // "(Monday)"
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Time - Prominent
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: isAccepted
                            ? const Color(0xFF16A34A).withOpacity(0.5) // Subtle green for accepted
                            : const Color(0xFF7C3AED), // Purple for invitations
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('h:mm a').format(startDate)} — ${DateFormat('h:mm a').format(endDate)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Client name - Highlighted
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isAccepted
                    ? const Color(0xFFF0FDF4).withOpacity(0.5) // Very soft green for accepted
                    : const Color(0xFFEEF2FF), // Light blue for invitations
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 16,
                    color: isAccepted
                        ? const Color(0xFF16A34A).withOpacity(0.5) // Subtle green for accepted
                        : const Color(0xFF7C3AED), // Purple for invitations
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Roboto',
                        ),
                        children: [
                          const TextSpan(text: 'Client: '),
                          TextSpan(
                            text: clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Event name
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    eventName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),

            // Venue
            if (venueName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      venueName!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Accept/Decline buttons for pending invitations
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAccept,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(
                          color: Color(0xFF059669),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isAccepted && respondedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'on ${DateFormat('MMM d').format(respondedAt!)} at ${DateFormat('h:mm a').format(respondedAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
