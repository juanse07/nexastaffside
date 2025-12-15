import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../shared/presentation/theme/theme.dart';
import '../services/staff_chat_service.dart';

/// Fast animated widget for AI chat messages (ChatGPT-style)
/// Optimized with ValueNotifier to reduce rebuilds
class AnimatedAiMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final bool showAnimation;

  const AnimatedAiMessageWidget({
    super.key,
    required this.message,
    this.showAnimation = true,
  });

  /// Clear animation tracking (call when conversation is reset)
  static void clearAnimationTracking() {
    _AnimatedAiMessageWidgetState._animatedMessages.clear();
  }

  @override
  State<AnimatedAiMessageWidget> createState() => _AnimatedAiMessageWidgetState();
}

class _AnimatedAiMessageWidgetState extends State<AnimatedAiMessageWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeInController;
  late AnimationController _slideInController;
  late AnimationController _typingDotsController;
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _shimmerAnimation;

  // Typewriter effect with ValueNotifier to avoid rebuilding entire widget
  final ValueNotifier<String> _displayedTextNotifier = ValueNotifier<String>('');
  Timer? _typewriterTimer;
  int _currentCharIndex = 0;

  // Typing indicator
  final ValueNotifier<bool> _isTypingNotifier = ValueNotifier<bool>(false);

  // Shimmer effect for typing animation
  final ValueNotifier<bool> _showShimmerNotifier = ValueNotifier<bool>(false);

  // Track which messages have already been animated (persists across rebuilds)
  static final Set<String> _animatedMessages = {};
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    // Initialize fade in animation (ULTRA FAST)
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    // Initialize slide in animation (ULTRA FAST)
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutQuart,
    ));

    // Initialize typing dots animation (ULTRA FAST)
    _typingDotsController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize shimmer animation for typing highlight
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    // Use content hash as stable identifier (manager app pattern)
    final messageId = '${widget.message.role}-${widget.message.content.hashCode}';

    // Check if this message has already been animated
    if (_animatedMessages.contains(messageId)) {
      _hasAnimated = true;
      _displayedTextNotifier.value = widget.message.content; // Show full text immediately
      _fadeInController.value = 1.0; // Skip fade animation
      _slideInController.value = 1.0; // Skip slide animation
      return;
    }

    // Mark as animated AFTER first frame to avoid premature tracking (manager app pattern)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animatedMessages.add(messageId);
    });
    _hasAnimated = true;

    // Start fade and slide animations
    _fadeInController.forward();
    _slideInController.forward();

    if (widget.showAnimation) {
      _isTypingNotifier.value = true;
      _typingDotsController.repeat();

      // Show typing indicator briefly (ULTRA FAST)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _isTypingNotifier.value = false;
          _typingDotsController.stop();
          _showShimmerNotifier.value = true; // Start shimmer effect
          _startTypewriterEffect();
        }
      });
    } else {
      // No animation, show full text immediately
      _displayedTextNotifier.value = widget.message.content;
    }
  }

  void _startTypewriterEffect() {
    final text = widget.message.content;
    const duration = Duration(milliseconds: 4); // BLAZING FAST - 250 chars/sec

    _typewriterTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentCharIndex < text.length) {
        // Add 3 characters at a time for blazing fast effect
        final charsToAdd = (_currentCharIndex + 3 <= text.length) ? 3 : (text.length - _currentCharIndex);
        _displayedTextNotifier.value = text.substring(0, _currentCharIndex + charsToAdd);
        _currentCharIndex += charsToAdd;
      } else {
        timer.cancel();
        _showShimmerNotifier.value = false; // Stop shimmer when done
        // Dispose fade and slide controllers after animation completes
        _fadeInController.dispose();
        _slideInController.dispose();
      }
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _displayedTextNotifier.dispose();
    _isTypingNotifier.dispose();
    _showShimmerNotifier.dispose();
    _typingDotsController.dispose();
    _shimmerController.dispose();

    // Only dispose controllers if they haven't been disposed already
    if (_fadeInController.isAnimating || _fadeInController.status != AnimationStatus.dismissed) {
      _fadeInController.dispose();
    }
    if (_slideInController.isAnimating || _slideInController.status != AnimationStatus.dismissed) {
      _slideInController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideInAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildAiAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // Only rebuild this part when typing state changes
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isTypingNotifier,
                        builder: (context, isTyping, _) {
                          return isTyping
                            ? _buildTypingIndicator()
                            : _buildMessageContent();
                        },
                      ),
                    ),
                    // Only show timestamp when not typing
                    ValueListenableBuilder<bool>(
                      valueListenable: _isTypingNotifier,
                      builder: (context, isTyping, _) {
                        if (isTyping) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            timeFormat.format(widget.message.timestamp),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 50,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _typingDotsController,
            builder: (context, child) {
              final double value = _typingDotsController.value;
              final double delay = index * 0.2;
              final double adjustedValue = (value - delay) % 1.0;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -4 * (adjustedValue < 0.5
                        ? adjustedValue * 2
                        : 2 - adjustedValue * 2),
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAiAvatar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isTypingNotifier,
      builder: (context, isTyping, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryPurple, // Navy blue background
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(isTyping ? 0.5 : 0.3),
                blurRadius: isTyping ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: AnimatedScale(
              scale: isTyping ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.yellow, // Yellow icon
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  // Only rebuilds when _displayedTextNotifier changes
  Widget _buildMessageContent() {
    return ValueListenableBuilder<String>(
      valueListenable: _displayedTextNotifier,
      builder: (context, displayedText, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _showShimmerNotifier,
          builder: (context, showShimmer, _) {
            final textWidget = MarkdownBody(
              data: displayedText,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  height: 1.4,
                ),
                strong: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                ),
                em: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                listBullet: const TextStyle(
                  color: AppColors.textDark,
                ),
              ),
            );

            if (!showShimmer) return textWidget;

            // Apply sophisticated multi-color shimmer with glow
            return AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Glow layer behind text
                    Opacity(
                      opacity: 0.6,
                      child: ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [
                              (_shimmerAnimation.value - 0.4).clamp(0.0, 1.0),
                              (_shimmerAnimation.value - 0.2).clamp(0.0, 1.0),
                              _shimmerAnimation.value.clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.2).clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.4).clamp(0.0, 1.0),
                            ],
                            colors: const [
                              AppColors.textDark,
                              AppColors.primaryIndigo, // Yellow/gold
                              AppColors.secondaryPurple, // Blue
                              AppColors.primaryIndigo, // Yellow/gold
                              AppColors.textDark,
                            ],
                          ).createShader(bounds);
                        },
                        child: child,
                      ),
                    ),
                    // Main text with shimmer
                    ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [
                            (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                            (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                            (_shimmerAnimation.value - 0.1).clamp(0.0, 1.0),
                            _shimmerAnimation.value.clamp(0.0, 1.0),
                            (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                            (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                            (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                          ],
                          colors: const [
                            AppColors.textDark, // Dark base
                            AppColors.indigoPurple, // Indigo
                            AppColors.purple, // Purple
                            AppColors.pinkAccent, // Pink highlight peak
                            AppColors.purple, // Purple
                            AppColors.indigoPurple, // Indigo
                            AppColors.textDark, // Dark base
                          ],
                        ).createShader(bounds);
                      },
                      child: child,
                    ),
                  ],
                );
              },
              child: textWidget,
            );
          },
        );
      },
    );
  }
}
