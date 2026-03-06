import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth_service.dart';
import '../../features/ai_assistant/widgets/monthly_insights_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../services/data_service.dart';
import '../presentation/theme/app_colors.dart';
import 'personal_event_bottom_sheet.dart';

/// Detail bottom sheet for a personal event. Shows info + Edit/Delete buttons.
class PersonalEventDetailSheet extends StatelessWidget {
  final Map<String, dynamic> event;

  const PersonalEventDetailSheet({super.key, required this.event});

  String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    return raw;
  }

  String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.personalEvent),
        content: Text(l10n.personalEventDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final token = await AuthService.getJwt();
      if (token == null) return;
      final id = event['id'] ?? event['_id'];
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/personal-events/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        context.read<DataService>().forceRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.personalEventDeleted)),
        );
        Navigator.pop(context, true);
      } else {
        final msg =
            jsonDecode(response.body)['message'] ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PersonalEventBottomSheet(existingEvent: event),
      ),
    );
    if (result == true && context.mounted) {
      context.read<DataService>().forceRefresh();
      Navigator.pop(context, true);
    }
  }

  void _askValerio(BuildContext context) {
    final title = event['event_name'] ?? event['title'] ?? 'Shift';
    final dateStr = event['date']?.toString() ?? '';
    final startTime = event['start_time'] ?? event['startTime'] ?? '';
    final endTime = event['end_time'] ?? event['endTime'] ?? '';
    final location = event['venue_name'] ?? event['location'] ?? '';
    final role = event['personal_role']?.toString() ?? event['role']?.toString() ?? '';
    final client = event['personal_client']?.toString() ?? event['client']?.toString() ?? '';
    final hourlyRate = event['personal_hourly_rate'] ?? event['hourlyRate'];
    final estimatedPay = event['personal_estimated_pay'];
    final currency = event['personal_currency']?.toString() ?? '\$';
    final notes = event['notes']?.toString() ?? '';

    String formattedDate = dateStr;
    try {
      formattedDate = DateFormat('EEEE, MMM d, y').format(DateTime.parse(dateStr));
    } catch (_) {}

    final payStr = (hourlyRate != null && (hourlyRate as num) > 0)
        ? '$currency${(hourlyRate as num).toStringAsFixed(0)}/hr'
            '${estimatedPay != null && (estimatedPay as num) > 0 ? ' · est. $currency${(estimatedPay as num).toStringAsFixed(0)} total' : ''}'
        : null;

    final buf = StringBuffer();
    buf.writeln('I have an independent shift coming up. Here are the details:');
    if (title.isNotEmpty) buf.writeln('- Title: $title');
    if (role.isNotEmpty) buf.writeln('- Role: $role');
    if (client.isNotEmpty) buf.writeln('- Client/Venue: $client');
    if (formattedDate.isNotEmpty) buf.writeln('- Date: $formattedDate');
    if (startTime.isNotEmpty) buf.writeln('- Time: $startTime – $endTime');
    if (location.isNotEmpty) buf.writeln('- Location: $location');
    if (payStr != null) buf.writeln('- Pay: $payStr');
    if (notes.isNotEmpty) buf.writeln('- Notes: $notes');
    buf.writeln(
      '\nDo NOT call any tools — all the data you need is above. '
      'Give me 2–3 practical preparation tips for this shift (what to bring, '
      'what to expect, how to perform at my best). '
      'Then briefly invite me to ask anything else or to request changes.',
    );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MonthlyInsightsSheet(
        focusedMonth: DateTime.now(),
        customTitle: title.isNotEmpty ? title : 'Shift Assistant',
        customPrompt: buf.toString(),
        loadingLabel: 'Valerio is reviewing your shift…',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = event['event_name'] ?? event['title'] ?? '';
    final dateStr = event['date']?.toString() ?? '';
    final startTime = event['start_time'] ?? event['startTime'] ?? '';
    final endTime = event['end_time'] ?? event['endTime'] ?? '';
    final location = event['venue_name'] ?? event['location'] ?? '';
    final notes = event['notes'] ?? '';
    final role = event['personal_role']?.toString() ?? event['role']?.toString() ?? '';
    final client = event['personal_client']?.toString() ?? event['client']?.toString() ?? '';
    final hourlyRate = event['personal_hourly_rate'] ?? event['hourlyRate'];
    final estimatedPay = event['personal_estimated_pay'];
    final currency = event['personal_currency']?.toString() ?? '\$';

    String formattedDate = dateStr;
    try {
      final d = DateTime.parse(dateStr);
      formattedDate = DateFormat('EEEE, MMM d, y').format(d);
    } catch (_) {}

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header with accent bar
          Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.personalEvent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.personalEventLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 14, color: AppColors.personalEvent),
                          const SizedBox(width: 4),
                          Text(
                            l10n.personalBadge,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.personalEvent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Date
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: formattedDate,
          ),
          const SizedBox(height: 12),

          // Time
          _DetailRow(
            icon: Icons.access_time_rounded,
            label: '$startTime – $endTime',
          ),

          // Role
          if (role.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: role,
            ),
          ],

          // Client
          if (client.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.business_outlined,
              label: client,
            ),
          ],

          // Pay
          if (hourlyRate != null && hourlyRate > 0) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.attach_money_rounded,
              label: '$currency${(hourlyRate as num).toStringAsFixed(0)}/hr'
                  '${estimatedPay != null && estimatedPay > 0 ? '  ·  est. $currency${(estimatedPay as num).toStringAsFixed(0)} total' : ''}',
            ),
          ],

          // Location
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: location,
            ),
          ],

          // Notes
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.notes_rounded,
              label: notes,
            ),
          ],

          const SizedBox(height: 24),

          // Valerio AI button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _askValerio(context),
              icon: ClipOval(
                child: Image.asset(
                  'assets/ai_assistant_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
              label: const Text(
                'Ask Valerio',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF212C4A),
                side: const BorderSide(color: Color(0xFF212C4A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Edit / Delete buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.editPersonalEvent),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.personalEvent,
                    side: const BorderSide(color: AppColors.personalEvent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
