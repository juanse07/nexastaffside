import 'package:flutter/material.dart';
import '../../features/ai_assistant/presentation/subscription_paywall_screen.dart';
import '../presentation/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Shows a bottom sheet informing the user that a feature requires FlowShift Pro.
/// Returns `true` if the user subscribed (navigated to paywall and came back with success).
Future<bool> showSubscriptionRequiredSheet(
  BuildContext context, {
  required String featureName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _SubscriptionGateSheet(
      featureName: featureName,
      l10n: l10n,
    ),
  );
  return result == true;
}

class _SubscriptionGateSheet extends StatelessWidget {
  const _SubscriptionGateSheet({
    required this.featureName,
    required this.l10n,
  });

  final String featureName;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Lock icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: AppColors.navySpaceCadet,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            l10n.subscriptionRequired,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.navySpaceCadet,
            ),
          ),
          const SizedBox(height: 8),

          // Feature-specific message
          Text(
            '$featureName ${l10n.featureLocked}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Subscribe button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                final subscribed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPaywallScreen(),
                  ),
                );
                if (context.mounted) {
                  Navigator.of(context).pop(subscribed == true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navySpaceCadet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.subscribeToUnlock,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Not now
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.notNow,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
