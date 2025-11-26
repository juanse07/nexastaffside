import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../shared/presentation/theme/theme.dart';
import '../widgets/enter_invite_code_dialog.dart';

class TeamCenterPage extends StatefulWidget {
  const TeamCenterPage({super.key});

  @override
  State<TeamCenterPage> createState() => _TeamCenterPageState();
}

class _TeamCenterPageState extends State<TeamCenterPage> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<DataService>();
      service.refreshTeamsAndInvites();
    });
  }

  Future<void> _onRefresh(DataService service) async {
    await service.refreshTeamsAndInvites();
    await service.refreshIfNeeded();
  }

  Future<void> _acceptInvite(DataService service, String token) async {
    setState(() => _processing = true);
    try {
      await service.acceptInvite(token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite accepted')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept invite: \$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _declineInvite(DataService service, String token) async {
    setState(() => _processing = true);
    try {
      await service.declineInvite(token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite declined')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decline invite: \$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _showEnterInviteCodeDialog(DataService service) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const EnterInviteCodeDialog(),
    );

    // Refresh data if user successfully joined a team
    if (result == true && mounted) {
      await service.refreshTeamsAndInvites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, _) {
          final invites = dataService.pendingInvites;
          final teams = dataService.teams;

          return RefreshIndicator(
            onRefresh: () => _onRefresh(dataService),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildInvitesSection(dataService, invites),
                const SizedBox(height: 24),
                _buildTeamsSection(teams),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitesSection(
    DataService service,
    List<Map<String, dynamic>> invites,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Invitations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_processing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (invites.isEmpty) ...[
              Text(
                'No pending invites right now. New invitations will appear here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _processing ? null : () => _showEnterInviteCodeDialog(service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.vpn_key),
                label: const Text('Enter Invite Code'),
              ),
            ] else
              ...invites.map((invite) {
                final teamName = (invite['teamName'] ?? 'Team').toString();
                final token = (invite['token'] ?? '').toString();
                final managerId = (invite['managerId'] ?? '').toString();
                final expiresAt = invite['expiresAt']?.toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.purpleLight.withOpacity(0.3),
                  ),
                  child: ListTile(
                    title: Text(teamName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (invite['teamDescription'] != null)
                          Text(
                            invite['teamDescription'].toString(),
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        if (managerId.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Manager: \$managerId',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        if (expiresAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Expires: \$expiresAt',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: _processing
                              ? null
                              : () => _acceptInvite(service, token),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            minimumSize: const Size(90, 36),
                          ),
                          child: const Text('Accept'),
                        ),
                        TextButton(
                          onPressed: _processing
                              ? null
                              : () => _declineInvite(service, token),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsSection(List<Map<String, dynamic>> teams) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_outlined, color: AppColors.secondaryPurple),
                const SizedBox(width: 8),
                Text(
                  'My teams',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (teams.isEmpty)
              Text(
                'You have not joined any teams yet.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: teams.map((team) {
                  final name = (team['name'] ?? 'Team').toString();
                  final description = (team['description'] ?? '').toString();
                  final joinedAt = team['joinedAt']?.toString();
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        if (joinedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Joined: \$joinedAt',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
