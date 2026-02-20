import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/subscription_service.dart';
import '../../../shared/presentation/theme/theme.dart';

/// Subscription Paywall Screen
/// General subscription gate showing ALL Pro features (not just AI).
class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key});

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final _subscriptionService = SubscriptionService();
  bool _purchasing = false;
  bool _restoring = false;

  Future<void> _handlePurchase() async {
    setState(() => _purchasing = true);

    try {
      final success = await _subscriptionService.purchaseProSubscription();

      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      if (success) {
        // Refresh cached subscription state
        await _subscriptionService.refreshStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseSuccessful),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToPurchase),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToPurchase),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _purchasing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _restoring = true);

    try {
      final success = await _subscriptionService.restorePurchases();

      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      if (success) {
        await _subscriptionService.refreshStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseSuccessful),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noPreviousPurchase),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToRestore),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(l10n.upgradeToPro),
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pro Badge
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.navySpaceCadet,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star,
                  size: 52,
                  color: AppColors.yellow,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                l10n.flowShiftPro,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navySpaceCadet,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle — Unlock everything
              Text(
                l10n.subscribeToUnlock,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.navySpaceCadet.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ALL Pro Features List
              _buildFeature(l10n.proFeatureAcceptDecline, Icons.check_circle_outline),
              _buildFeature(l10n.proFeatureChat, Icons.chat_bubble_outline),
              _buildFeature(l10n.proFeatureAI, Icons.auto_awesome),
              _buildFeature(l10n.proFeatureClockInOut, Icons.access_time),
              _buildFeature(l10n.proFeatureAvailability, Icons.calendar_today),
              _buildFeature(l10n.proFeatureCaricatures, Icons.face_retouching_natural),
              _buildFeature(l10n.cancelAnytime, Icons.all_inclusive),

              const SizedBox(height: 32),

              // Pricing Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.navySpaceCadet,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.yellow,
                          ),
                        ),
                        Text(
                          '7.99',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            height: 1,
                            color: AppColors.yellow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'per month',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.cancelAnytime,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Subscribe Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _purchasing || _restoring ? null : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.navySpaceCadet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _purchasing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.navySpaceCadet,
                          ),
                        )
                      : Text(
                          l10n.subscribeNow,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navySpaceCadet,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Restore Button
              TextButton(
                onPressed: _purchasing || _restoring ? null : _handleRestore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.navySpaceCadet,
                ),
                child: _restoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navySpaceCadet,
                        ),
                      )
                    : Text(
                        l10n.restorePurchase,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Terms & Privacy
              Text(
                l10n.subscriptionDisclaimer,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.navySpaceCadet.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.navySpaceCadet,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.navySpaceCadet,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.yellow,
            size: 22,
          ),
        ],
      ),
    );
  }
}
