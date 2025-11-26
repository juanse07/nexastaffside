import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/presentation/theme/theme.dart';

/// Card for confirming availability marking actions
/// Shows dates being marked and confirmation buttons
class AvailabilityConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> availabilityData;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const AvailabilityConfirmationCard({
    super.key,
    required this.availabilityData,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dates = availabilityData['dates'] as List<dynamic>? ?? [];
    final status = availabilityData['status'] as String? ?? 'available';
    final notes = availabilityData['notes'] as String?;

    // Parse dates and format them
    final List<DateTime> parsedDates = [];
    for (var dateStr in dates) {
      try {
        parsedDates.add(DateTime.parse(dateStr.toString()));
      } catch (e) {
        print('[AvailabilityCard] Failed to parse date: $dateStr');
      }
    }

    // Sort dates
    parsedDates.sort();

    // Get status display info
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: statusInfo['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (statusInfo['gradient'] as List<Color>)[0].withOpacity(0.3),
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
                  statusInfo['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusInfo['title'] as String,
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

            // Dates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dates:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...parsedDates.map((date) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 14,
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
                    );
                  }).toList(),
                ],
              ),
            ),

            // Notes (if any)
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.note,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                      foregroundColor: (statusInfo['gradient'] as List<Color>)[0],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
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

  /// Get status display information (colors, icon, title)
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return {
          'gradient': [
            AppColors.successLight, // Green
            AppColors.success, // Darker green
          ],
          'icon': Icons.check_circle,
          'title': 'Mark as Available',
        };
      case 'unavailable':
        return {
          'gradient': [
            AppColors.error, // Red
            AppColors.errorDark, // Darker red
          ],
          'icon': Icons.cancel,
          'title': 'Mark as Unavailable',
        };
      case 'preferred':
        return {
          'gradient': [
            AppColors.purple, // Purple
            AppColors.purpleDark, // Darker purple
          ],
          'icon': Icons.star,
          'title': 'Mark as Preferred',
        };
      default:
        return {
          'gradient': [
            AppColors.secondaryPurple, // Blue
            AppColors.indigoPurple, // Darker blue
          ],
          'icon': Icons.info,
          'title': 'Update Availability',
        };
    }
  }
}
