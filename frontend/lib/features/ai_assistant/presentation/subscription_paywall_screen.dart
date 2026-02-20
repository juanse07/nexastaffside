import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/subscription_service.dart';
import '../../../shared/presentation/theme/theme.dart';

/// Modernized subscription paywall screen.
/// Full-bleed dark gradient with glassmorphism cards and a
/// Free-vs-Pro comparison table that makes the upgrade value
/// immediately legible.
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
      final result = await _subscriptionService.purchaseProSubscription();
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
      if (mounted) setState(() => _purchasing = false);
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
                      _buildPricingCard(l10n),
                      const SizedBox(height: 24),
                      _buildSubscribeButton(l10n),
                      const SizedBox(height: 10),
                      _buildRestoreButton(l10n),
                      const SizedBox(height: 20),
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
        // Outer ambient glow ring
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow.withValues(alpha: 0.10),
          ),
        ),
        // Inner glow ring
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow.withValues(alpha: 0.18),
          ),
        ),
        // Badge
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
          l10n.flowShiftPro,
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

  // ── Comparison card ────────────────────────────────────────────────────────

  Widget _buildComparisonCard(AppLocalizations l10n) {
    final features = [
      _FeatureItem(Icons.check_circle_outline, l10n.proFeatureAcceptDecline,
          freeLabel: l10n.readOnlyMode, proCheck: true),
      _FeatureItem(Icons.chat_bubble_outline, l10n.proFeatureChat,
          freeCheck: false, proCheck: true),
      _FeatureItem(Icons.auto_awesome, l10n.proFeatureAI,
          freeCheck: false, proLabel: '20 msgs', proNote: l10n.plentyForMost),
      _FeatureItem(Icons.access_time, l10n.proFeatureClockInOut,
          freeCheck: false, proCheck: true),
      _FeatureItem(Icons.event_available, l10n.proFeatureAvailability,
          freeCheck: false, proCheck: true),
      _FeatureItem(Icons.face_retouching_natural, l10n.proFeatureCaricatures,
          freeCheck: false, proCheck: true),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column headers
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Free',
                    style: TextStyle(
                      fontSize: 12,
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
                    'Pro',
                    style: const TextStyle(
                      fontSize: 12,
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 15, color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(width: 10),
          // Feature name
          Expanded(
            flex: 5,
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w400),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Free status
          Expanded(
            flex: 2,
            child: Center(child: _statusWidget(item.freeCheck, item.freeLabel, isFree: true)),
          ),
          // Pro status
          Expanded(
            flex: 2,
            child: Center(child: _statusWidget(item.proCheck, item.proLabel, isFree: false, note: item.proNote)),
          ),
        ],
      ),
    );
  }

  Widget _statusWidget(bool? check, String? label, {required bool isFree, String? note}) {
    // Custom label (e.g. "Read only", "20 msgs")
    if (label != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFree ? Colors.white.withValues(alpha: 0.42) : AppColors.yellow,
            ),
            textAlign: TextAlign.center,
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.yellow.withValues(alpha: 0.60),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }
    // Checkmark
    if (check == true) {
      return Icon(
        Icons.check_circle_rounded,
        size: 19,
        color: isFree ? Colors.white.withValues(alpha: 0.42) : AppColors.yellow,
      );
    }
    // Locked / unavailable
    return Icon(
      Icons.remove_circle_outline,
      size: 17,
      color: Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Pricing card ───────────────────────────────────────────────────────────

  Widget _buildPricingCard(AppLocalizations l10n) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Price with trial callout
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Free trial badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '30 DAYS FREE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '\$',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const Text(
                      '8.99',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'per month after trial',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Cancel anytime badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.yellow.withValues(alpha: 0.30), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.all_inclusive_rounded, color: AppColors.yellow, size: 22),
                const SizedBox(height: 5),
                Text(
                  l10n.cancelAnytime,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.yellow,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA buttons ────────────────────────────────────────────────────────────

  Widget _buildSubscribeButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _purchasing || _restoring ? null : _handlePurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.navySpaceCadet,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _purchasing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navySpaceCadet),
              )
            : Text(
                l10n.subscribeNow,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navySpaceCadet,
                ),
              ),
      ),
    );
  }

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
  final bool? proCheck;
  final String? freeLabel;
  final String? proLabel;
  final String? proNote;

  const _FeatureItem(
    this.icon,
    this.name, {
    this.freeCheck,
    this.proCheck,
    this.freeLabel,
    this.proLabel,
    this.proNote,
  });
}

// ── Glassmorphism card ───────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
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
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
