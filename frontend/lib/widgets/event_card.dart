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
  final double? hourlyRate;
  final double? totalPayment;
  const EventCard({
    super.key,
    required this.title,
    required this.chips,
    required this.onTap,
    this.isConfirmed = false,
    this.hourlyRate,
    this.totalPayment,
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
                    // Payment info
                    if (hourlyRate != null || totalPayment != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hourlyRate != null) ...[
                              const Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '\$${hourlyRate!.toStringAsFixed(2)}/hr',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            if (hourlyRate != null && totalPayment != null)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                width: 1,
                                height: 16,
                                color: const Color(0xFF059669).withOpacity(0.3),
                              ),
                            if (totalPayment != null) ...[
                              const Icon(
                                Icons.payments_outlined,
                                size: 14,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '\$${totalPayment!.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF059669),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
