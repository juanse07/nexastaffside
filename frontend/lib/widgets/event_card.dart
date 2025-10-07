import 'package:flutter/material.dart';

enum InfoChipColor { primary, secondary }

class InfoChipData {
  final IconData icon;
  final String label;
  final InfoChipColor colorKey;
  InfoChipData({
    required this.icon,
    required this.label,
    required this.colorKey,
  });
}

class EventCard extends StatelessWidget {
  final String title;
  final List<InfoChipData> chips;
  final VoidCallback onTap;
  final bool isConfirmed;
  const EventCard({
    super.key,
    required this.title,
    required this.chips,
    required this.onTap,
    this.isConfirmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isConfirmed
        ? Color.lerp(
            theme.colorScheme.surface,
            Colors.green.shade100,
            0.15,
          )
        : theme.colorScheme.surface;

    return Card(
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips
                          .map((c) => _infoChip(context, c))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, InfoChipData data) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (data.colorKey) {
      InfoChipColor.primary => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      InfoChipColor.secondary => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
