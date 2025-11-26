import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/presentation/theme/theme.dart';

/// Card for confirming shift accept/decline actions
/// Shows shift details and confirmation buttons
class ShiftActionCard extends StatelessWidget {
  final Map<String, dynamic> shiftAction;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ShiftActionCard({
    super.key,
    required this.shiftAction,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final action = shiftAction['action'] as String? ?? 'accept';
    final eventName = shiftAction['shift_name'] as String? ?? 'Event';
    final dateStr = shiftAction['date'] as String?;
    final reason = shiftAction['reason'] as String?;

    // Parse date
    DateTime? date;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        print('[ShiftActionCard] Failed to parse date: $dateStr');
      }
    }

    // Get action display info
    final actionInfo = _getActionInfo(action);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: actionInfo['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (actionInfo['gradient'] as List<Color>)[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  actionInfo['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    actionInfo['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Event details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event name
                  Row(
                    children: [
                      const Icon(
                        Icons.event,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eventName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Date
                  if (date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Reason for decline (if declining)
                  if (action == 'decline' && reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reason: $reason',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confirmation message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    action == 'accept' ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action == 'accept'
                          ? 'You\'ll be confirmed for this shift and your manager will be notified.'
                          : 'This shift will be declined and your manager will be notified.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: (actionInfo['gradient'] as List<Color>)[0],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      action == 'accept' ? 'Accept Shift' : 'Decline Shift',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get action display information (colors, icon, title)
  Map<String, dynamic> _getActionInfo(String action) {
    switch (action.toLowerCase()) {
      case 'accept':
        return {
          'gradient': [
            AppColors.successLight, // Green
            AppColors.success, // Darker green
          ],
          'icon': Icons.check_circle,
          'title': 'Accept Shift',
        };
      case 'decline':
        return {
          'gradient': [
            AppColors.error, // Red
            AppColors.errorDark, // Darker red
          ],
          'icon': Icons.cancel,
          'title': 'Decline Shift',
        };
      default:
        return {
          'gradient': [
            AppColors.indigoPurple, // Blue
            AppColors.indigo, // Darker blue
          ],
          'icon': Icons.event,
          'title': 'Shift Action',
        };
    }
  }
}
