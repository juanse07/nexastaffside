import 'package:flutter/material.dart';
import '../../features/ai_assistant/presentation/subscription_paywall_screen.dart';
import '../presentation/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Shows a bottom sheet inviting the user to try FlowShift Pro.
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

          // Valerio mascot avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.yellow.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/ai_assistant_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Context-aware title: "Unlock {featureName}"
          Text(
            '${l10n.unlockFeature} $featureName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.navySpaceCadet,
            ),
          ),
          const SizedBox(height: 8),

          // Value-first subtitle
          Text(
            l10n.tryProFree,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),

          // Price anchor
          Text(
            l10n.priceAnchor,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          // CTA button — warm yellow with navy text
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
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.navySpaceCadet,
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
          const SizedBox(height: 8),

          // Reassurance text
          Text(
            l10n.noChargeUntilTrialEnds,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),

          // "Not now" — slightly more visible
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.notNow,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
