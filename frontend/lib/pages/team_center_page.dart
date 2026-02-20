import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invitationAccepted)));
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToAcceptInvite(e.toString()))));
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invitationDeclined)));
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToDeclineInvite(e.toString()))));
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

    if (result == true && mounted) {
      await service.refreshTeamsAndInvites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(l10n.teamCenter),
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
            color: AppColors.yellow,
            onRefresh: () => _onRefresh(dataService),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildInvitesSection(dataService, invites),
                const SizedBox(height: 16),
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.yellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.invitations,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navySpaceCadet,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_processing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.yellow,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (invites.isEmpty) ...[
            Text(
              l10n.noPendingInvites,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : () => _showEnterInviteCodeDialog(service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navySpaceCadet,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.vpn_key, size: 18),
                label: Text(
                  l10n.enterInviteCode,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else
            ...invites.map((invite) {
              final teamName = (invite['teamName'] ?? 'Team').toString();
              final token = (invite['token'] ?? '').toString();
              final managerId = (invite['managerId'] ?? '').toString();
              final expiresAt = invite['expiresAt']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surfaceLight,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navySpaceCadet,
                      ),
                    ),
                    if (invite['teamDescription'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        invite['teamDescription'].toString(),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (managerId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.manager}: $managerId',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (expiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.expires}: $expiresAt',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _processing
                                ? null
                                : () => _acceptInvite(service, token),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.navySpaceCadet,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              l10n.accept,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _processing
                                ? null
                                : () => _declineInvite(service, token),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textTertiary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(l10n.declineInvitation),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(List<Map<String, dynamic>> teams) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tealInfo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.tealInfo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.myTeams,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navySpaceCadet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (teams.isEmpty)
            Text(
              l10n.youHaveNotJoinedAnyTeams,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else
            ...teams.map((team) {
              final name = (team['name'] ?? 'Team').toString();
              final description = (team['description'] ?? '').toString();
              final joinedAt = team['joinedAt']?.toString();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surfaceLight,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.tealInfo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.group_outlined,
                        color: AppColors.tealInfo,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navySpaceCadet,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (joinedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.joined}: $joinedAt',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
