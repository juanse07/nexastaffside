import 'dart:math';
import 'package:flutter/material.dart';

/// A celebration overlay that shows points earned and streak achievements
/// with animations when the user clocks in successfully.
class CelebrationOverlay extends StatefulWidget {
  final int? pointsEarned;
  final int? newStreak;
  final bool isNewRecord;
  final VoidCallback onComplete;

  const CelebrationOverlay({
    super.key,
    this.pointsEarned,
    this.newStreak,
    this.isNewRecord = false,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Main animation for points/streak display
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));

    // Confetti animation for new records
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.isNewRecord) {
      _generateConfetti();
      _confettiController.forward();
    }

    _mainController.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  void _generateConfetti() {
    for (int i = 0; i < 50; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: -0.1 - _random.nextDouble() * 0.3,
        color: _confettiColors[_random.nextInt(_confettiColors.length)],
        size: 8 + _random.nextDouble() * 8,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        fallSpeed: 0.3 + _random.nextDouble() * 0.4,
        swaySpeed: (_random.nextDouble() - 0.5) * 2,
      ));
    }
  }

  static const List<Color> _confettiColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFE66D), // Yellow
    Color(0xFF95E1D3), // Mint
    Color(0xFFF38181), // Coral
    Color(0xFFAA96DA), // Purple
  ];

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop
          GestureDetector(
            onTap: widget.onComplete,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // Confetti particles for new records
          if (widget.isNewRecord)
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),

          // Main celebration card
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildCelebrationCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isNewRecord
              ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
              : [const Color(0xFF11998e), const Color(0xFF38ef7d)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isNewRecord ? Icons.emoji_events : Icons.check_circle,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.isNewRecord ? 'New Record!' : 'Clocked In!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Points earned
          if (widget.pointsEarned != null && widget.pointsEarned! > 0) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  '+${widget.pointsEarned} points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Streak display
          if (widget.newStreak != null && widget.newStreak! > 0) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Text(
                  '${widget.newStreak} day streak!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Tap to dismiss hint
          Text(
            'Tap anywhere to dismiss',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Represents a single confetti particle
class _ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;
  final double fallSpeed;
  final double swaySpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.fallSpeed,
    required this.swaySpeed,
  });
}

/// Custom painter for confetti particles
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Update particle position based on progress
      final currentY = particle.y + (progress * particle.fallSpeed * 1.5);
      final currentX =
          particle.x + sin(progress * 10 * particle.swaySpeed) * 0.05;
      final currentRotation =
          particle.rotation + progress * particle.rotationSpeed;

      // Skip if particle is below the screen
      if (currentY > 1.2) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - progress * 0.5)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX * size.width, currentY * size.height);
      canvas.rotate(currentRotation);

      // Draw rectangle confetti
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Helper widget to show celebration overlay as an overlay entry
class CelebrationOverlayManager {
  static OverlayEntry? _overlayEntry;

  /// Show celebration overlay
  static void show(
    BuildContext context, {
    int? pointsEarned,
    int? newStreak,
    bool isNewRecord = false,
  }) {
    // Don't show if nothing to celebrate
    if (pointsEarned == null && newStreak == null) return;

    dismiss();

    _overlayEntry = OverlayEntry(
      builder: (context) => CelebrationOverlay(
        pointsEarned: pointsEarned,
        newStreak: newStreak,
        isNewRecord: isNewRecord,
        onComplete: dismiss,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Dismiss the overlay
  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
