import 'dart:ui';
import 'package:flutter/material.dart';
import '../../features/ai_assistant/presentation/subscription_paywall_screen.dart';
import '../../services/subscription_service.dart';
import '../presentation/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Banner showing free month status or expired free month CTA.
/// Place below app bar in root page.
class FreeMonthBanner extends StatelessWidget {
  const FreeMonthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionService();
    final l10n = AppLocalizations.of(context)!;

    // Don't show if status hasn't loaded yet
    if (!service.statusLoaded) return const SizedBox.shrink();

    // Don't show for active Pro subscribers (App Store trial is separate)
    if (!service.isReadOnly) return const SizedBox.shrink();

    final isExpired = service.isReadOnly && !service.isInFreeMonth;
    final daysRemaining = service.freeMonthDaysRemaining;
    final isUrgent = daysRemaining <= 5 && !isExpired;

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (isExpired) {
      bgColor = const Color(0xCCFFF3E0); // light orange, 80% opacity for blur
      textColor = const Color(0xFFE65100); // deep orange
      icon = Icons.warning_amber_rounded;
      message = l10n.freeMonthExpired;
    } else if (isUrgent) {
      bgColor = const Color(0xCCFFF8E1); // light amber, 80% opacity for blur
      textColor = const Color(0xFFF57F17); // amber dark
      icon = Icons.timer_outlined;
      message = l10n.freeMonthBanner(daysRemaining);
    } else {
      bgColor = AppColors.navySpaceCadet.withValues(alpha: 0.08);
      textColor = AppColors.navySpaceCadet;
      icon = Icons.card_giftcard_rounded;
      message = l10n.freeMonthBanner(daysRemaining);
    }

    return GestureDetector(
      onTap: isExpired
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              )
          : null,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: bgColor),
            child: Row(
              children: [
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.subscribeNow,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
