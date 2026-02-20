import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A card widget that displays the user's gamification stats:
/// - Total points
/// - Current streak
/// - Longest streak
/// - Progress to next level
class GamificationCard extends StatelessWidget {
  final int totalPoints;
  final int currentStreak;
  final int longestStreak;
  final bool isLoading;

  const GamificationCard({
    super.key,
    required this.totalPoints,
    required this.currentStreak,
    required this.longestStreak,
    this.isLoading = false,
  });

  /// Calculate the user's level based on total points
  /// Every 100 points = 1 level
  int get level => (totalPoints / 100).floor() + 1;

  /// Calculate progress towards next level (0.0 to 1.0)
  double get levelProgress => (totalPoints % 100) / 100;

  /// Points needed for next level
  int get pointsToNextLevel => 100 - (totalPoints % 100);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return _buildLoadingState();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with level
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.levelLabel(level),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.ptsLabel(totalPoints),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  value: totalPoints.toString(),
                  label: l10n.points,
                ),
                _buildVerticalDivider(),
                _buildStat(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  value: currentStreak.toString(),
                  label: l10n.streak,
                ),
                _buildVerticalDivider(),
                _buildStat(
                  icon: Icons.emoji_events,
                  iconColor: Colors.yellow,
                  value: longestStreak.toString(),
                  label: l10n.best,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.nextLevel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      l10n.ptsToGo(pointsToNextLevel),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // Streak encouragement message
            if (currentStreak > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStreakMessage(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  String _getStreakMessage() {
    if (currentStreak >= longestStreak && currentStreak > 1) {
      return "You're on a personal best streak! Keep it going!";
    } else if (currentStreak >= 7) {
      return "Amazing! A full week of punctuality!";
    } else if (currentStreak >= 5) {
      return "Great job! 5 days in a row!";
    } else if (currentStreak >= 3) {
      return "Nice streak! You're building a habit!";
    } else {
      return "Keep clocking in on time to build your streak!";
    }
  }
}

/// A compact version of the gamification card for smaller spaces
class GamificationCardCompact extends StatelessWidget {
  final int totalPoints;
  final int currentStreak;
  final VoidCallback? onTap;

  const GamificationCardCompact({
    super.key,
    required this.totalPoints,
    required this.currentStreak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Points
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$totalPoints',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Streak
            if (currentStreak > 0) ...[
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
