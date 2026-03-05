import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/subscription_service.dart';
import '../../../shared/presentation/theme/theme.dart';

/// Modernized subscription paywall screen with two tiers.
/// Full-bleed dark gradient with glassmorphism cards, a
/// Free-vs-Starter-vs-Pro comparison table, and two pricing cards.
class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key, this.showSkipButton = false});

  final bool showSkipButton;

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  final _subscriptionService = SubscriptionService();
  bool _purchasing = false;
  bool _restoring = false;
  String? _purchasingTier; // 'starter' or 'pro'

  Future<void> _handlePurchase(String tier) async {
    setState(() {
      _purchasing = true;
      _purchasingTier = tier;
    });
    try {
      final result = tier == 'starter'
          ? await _subscriptionService.purchaseStarterSubscription()
          : await _subscriptionService.purchaseProSubscription();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (result.success) {
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
            content: Text('${l10n.failedToPurchase}: ${result.error ?? "unknown"}'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.failedToPurchase}: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() {
        _purchasing = false;
        _purchasingTier = null;
      });
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
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // Very deep navy
              Color(0xFF1A2E50), // Mid navy-blue
              Color(0xFF00606B), // Dark teal
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _buildHeroBadge(),
                      const SizedBox(height: 18),
                      _buildTitle(l10n),
                      const SizedBox(height: 28),
                      _buildComparisonCard(l10n),
                      const SizedBox(height: 16),
                      _buildPricingCards(l10n),
                      const SizedBox(height: 16),
                      _buildRestoreButton(l10n),
                      if (widget.showSkipButton) ...[
                        const SizedBox(height: 8),
                        _buildSkipButton(l10n),
                      ],
                      const SizedBox(height: 16),
                      _buildDisclaimer(l10n),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 17, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero badge ─────────────────────────────────────────────────────────────

  Widget _buildHeroBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow.withValues(alpha: 0.10),
          ),
        ),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow.withValues(alpha: 0.18),
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.yellow, AppColors.yellow.withValues(alpha: 0.75)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium,
            size: 34,
            color: AppColors.navySpaceCadet,
          ),
        ),
      ],
    );
  }

  // ── Title ──────────────────────────────────────────────────────────────────

  Widget _buildTitle(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.chooseYourPlan,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.subscribeToUnlock,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.60),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Comparison card (3 columns: Free | Starter | Pro) ──────────────────────

  Widget _buildComparisonCard(AppLocalizations l10n) {
    final features = [
      _FeatureItem(Icons.check_circle_outline, l10n.proFeatureAcceptDecline,
          freeLabel: l10n.readOnlyMode, starterCheck: true, proCheck: true),
      _FeatureItem(Icons.chat_bubble_outline, l10n.proFeatureChat,
          freeCheck: false, starterCheck: true, proCheck: true),
      _FeatureItem(Icons.auto_awesome, l10n.proFeatureAIShort,
          freeCheck: false, starterLabel: l10n.starterAiLimit, proLabel: l10n.proAiLimit),
      _FeatureItem(Icons.access_time, l10n.proFeatureClockInOut,
          freeCheck: false, starterCheck: true, proCheck: true),
      _FeatureItem(Icons.event_available, l10n.proFeatureAvailability,
          freeCheck: false, starterCheck: true, proCheck: true),
      _FeatureItem(Icons.face_retouching_natural, l10n.proFeatureCaricaturesShort,
          freeCheck: false, starterLabel: l10n.starterCaricatureLimit, proLabel: l10n.proCaricatureLimit),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column headers
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Free',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    l10n.flowShiftStarter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Pro',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 18),
          // Feature rows
          ...features.map(_buildComparisonRow),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(_FeatureItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(item.icon, size: 14, color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(width: 8),
          // Feature name
          Expanded(
            flex: 3,
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w400),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Free status
          Expanded(
            flex: 2,
            child: Center(child: _statusWidget(item.freeCheck, item.freeLabel, tier: 'free')),
          ),
          // Starter status
          Expanded(
            flex: 2,
            child: Center(child: _statusWidget(item.starterCheck, item.starterLabel, tier: 'starter')),
          ),
          // Pro status
          Expanded(
            flex: 2,
            child: Center(child: _statusWidget(item.proCheck, item.proLabel, tier: 'pro')),
          ),
        ],
      ),
    );
  }

  Widget _statusWidget(bool? check, String? label, {required String tier}) {
    final isFree = tier == 'free';
    final isPro = tier == 'pro';

    // Custom label (e.g. "3/mo", "25/mo")
    if (label != null) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPro
              ? AppColors.yellow
              : (isFree ? Colors.white.withValues(alpha: 0.42) : Colors.white.withValues(alpha: 0.80)),
        ),
        textAlign: TextAlign.center,
      );
    }
    // Checkmark
    if (check == true) {
      return Icon(
        Icons.check_circle_rounded,
        size: 17,
        color: isPro
            ? AppColors.yellow
            : (isFree ? Colors.white.withValues(alpha: 0.42) : Colors.white.withValues(alpha: 0.70)),
      );
    }
    // Locked / unavailable
    return Icon(
      Icons.remove_circle_outline,
      size: 15,
      color: Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Pricing cards (side-by-side) ──────────────────────────────────────────

  Widget _buildPricingCards(AppLocalizations l10n) {
    return Row(
      children: [
        // Starter card
        Expanded(child: _buildTierCard(
          tierName: l10n.flowShiftStarter,
          price: '6.99',
          onPurchase: () => _handlePurchase('starter'),
          isPurchasing: _purchasing && _purchasingTier == 'starter',
          isDisabled: _purchasing || _restoring,
          badge: null,
          l10n: l10n,
        )),
        const SizedBox(width: 12),
        // Pro card
        Expanded(child: _buildTierCard(
          tierName: l10n.flowShiftPro,
          price: '11.99',
          onPurchase: () => _handlePurchase('pro'),
          isPurchasing: _purchasing && _purchasingTier == 'pro',
          isDisabled: _purchasing || _restoring,
          badge: l10n.bestValue,
          l10n: l10n,
          isHighlighted: true,
        )),
      ],
    );
  }

  Widget _buildTierCard({
    required String tierName,
    required String price,
    required VoidCallback onPurchase,
    required bool isPurchasing,
    required bool isDisabled,
    required String? badge,
    required AppLocalizations l10n,
    bool isHighlighted = false,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: isHighlighted ? AppColors.yellow.withValues(alpha: 0.40) : null,
      child: Column(
        children: [
          // Badge
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.yellow,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 22), // Align with badge height
          ],
          // Tier name
          Text(
            tierName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? AppColors.yellow : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Price
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.80),
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  color: isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.80),
                ),
              ),
            ],
          ),
          Text(
            '/mo',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 6),
          // Free trial badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '30 DAYS FREE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.yellow,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Purchase button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: isDisabled ? null : onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted ? AppColors.yellow : Colors.white.withValues(alpha: 0.18),
                foregroundColor: isHighlighted ? AppColors.navySpaceCadet : Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isPurchasing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isHighlighted ? AppColors.navySpaceCadet : Colors.white,
                      ),
                    )
                  : Text(
                      l10n.subscribeNow,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isHighlighted ? AppColors.navySpaceCadet : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA buttons ────────────────────────────────────────────────────────────

  Widget _buildRestoreButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: _purchasing || _restoring ? null : _handleRestore,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: _restoring
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          : Text(
              l10n.restorePurchase,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.50),
              ),
            ),
    );
  }

  Widget _buildSkipButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: _purchasing || _restoring ? null : () => Navigator.pop(context, false),
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(
        l10n.continueWithFreeTrial,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.50),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n) {
    return Text(
      l10n.subscriptionDisclaimer,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withValues(alpha: 0.32),
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class _FeatureItem {
  final IconData icon;
  final String name;
  final bool? freeCheck;
  final bool? starterCheck;
  final bool? proCheck;
  final String? freeLabel;
  final String? starterLabel;
  final String? proLabel;

  const _FeatureItem(
    this.icon,
    this.name, {
    this.freeCheck,
    this.starterCheck,
    this.proCheck,
    this.freeLabel,
    this.starterLabel,
    this.proLabel,
  });
}

// ── Glassmorphism card ───────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.16),
              width: borderColor != null ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
