import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';

class EnterInviteCodeDialog extends StatefulWidget {
  const EnterInviteCodeDialog({super.key});

  @override
  State<EnterInviteCodeDialog> createState() => _EnterInviteCodeDialogState();
}

class _EnterInviteCodeDialogState extends State<EnterInviteCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _validating = false;
  bool _joining = false;
  Map<String, dynamic>? _teamInfo;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _error = 'Please enter an invite code';
      });
      return;
    }

    setState(() {
      _validating = true;
      _error = null;
      _teamInfo = null;
    });

    try {
      final dataService = context.read<DataService>();
      final teamInfo = await dataService.validateInviteCode(code);

      setState(() {
        _teamInfo = teamInfo;
        _validating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _validating = false;
      });
    }
  }

  Future<void> _joinTeam() async {
    final code = _codeController.text.trim().toUpperCase();

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final dataService = context.read<DataService>();
      await dataService.redeemInviteCode(code);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${_teamInfo!['teamName']}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      // Close dialog
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.group_add, color: Color(0xFFFFC107)),
          SizedBox(width: 8),
          Text('Join a Team'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the invite code your manager shared with you',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Invite Code Input
            TextField(
              controller: _codeController,
              enabled: !_validating && !_joining,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              onSubmitted: (_) => _validateCode(),
              onChanged: (value) {
                // Auto-validate when code looks complete (6+ chars)
                if (value.trim().length >= 6 && _teamInfo == null) {
                  _validateCode();
                }
                // Clear team info if user modifies code
                if (_teamInfo != null) {
                  setState(() {
                    _teamInfo = null;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Validate Button
            if (_teamInfo == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _validating ? null : _validateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.white,
                  ),
                  child: _validating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Validate Code'),
                ),
              ),

            // Team Info Preview
            if (_teamInfo != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Valid Invite!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.business, 'Team', _teamInfo!['teamName']?.toString() ?? 'Unknown'),
                    if (_teamInfo!['teamDescription'] != null && _teamInfo!['teamDescription'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.description, 'Description', _teamInfo!['teamDescription']?.toString() ?? ''),
                    ],
                    if (_teamInfo!['managerName'] != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.person, 'Manager', _teamInfo!['managerName']?.toString() ?? ''),
                    ],
                    if (_teamInfo!['expiresAt'] != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.schedule, 'Expires', _formatDate(_teamInfo!['expiresAt']?.toString() ?? '')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joining ? null : _joinTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _joining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(_joining ? 'Joining...' : 'Join Team'),
                ),
              ),
            ],

            // Error Message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _validating || _joining ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFC107)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$month/$day/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
