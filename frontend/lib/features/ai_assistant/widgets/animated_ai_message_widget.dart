import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Reasoning expand/collapse state
  final ValueNotifier<bool> _reasoningExpandedNotifier = ValueNotifier<bool>(false);

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
    _reasoningExpandedNotifier.dispose();
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
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildReasoningSection(),
                                  _buildMessageContent(),
                                ],
                              );
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

  Widget _buildReasoningSection() {
    if (widget.message.reasoning == null || widget.message.reasoning!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _reasoningExpandedNotifier,
      builder: (context, expanded, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _reasoningExpandedNotifier.value = !expanded,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\u{1F9E0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'View thinking',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  widget.message.reasoning!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
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
        return AnimatedScale(
          scale: isTyping ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isTyping ? 0.2 : 0.1),
                  blurRadius: isTyping ? 10 : 6,
                  offset: const Offset(0, 2),
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
            // Check if text contains [LINK:...] patterns
            final hasLinks = displayedText.contains('[LINK:');

            final Widget textWidget;
            if (hasLinks) {
              // Build custom widget with clickable venue links
              textWidget = _buildTextWithLinks(displayedText);
            } else {
              // Use standard MarkdownBody for text without links
              textWidget = MarkdownBody(
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
            }

            if (!showShimmer) return textWidget;

            // Apply navy blue / ocean blue / grey shimmer
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
                              AppColors.textDark, // Dark base
                              AppColors.navySpaceCadet, // Navy blue
                              AppColors.oceanBlue, // Ocean blue highlight
                              AppColors.navySpaceCadet, // Navy blue
                              AppColors.textDark, // Dark base
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
                            AppColors.navySpaceCadet, // Navy blue
                            AppColors.oceanBlue, // Ocean blue
                            AppColors.oceanBlue, // Ocean blue highlight peak
                            AppColors.oceanBlue, // Ocean blue
                            AppColors.navySpaceCadet, // Navy blue
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

  /// Build text content with clickable venue links
  Widget _buildTextWithLinks(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Check for [LINK:...] pattern
      final linkPattern = RegExp(r'\[LINK:([^\]]+)\]');
      final match = linkPattern.firstMatch(line);

      if (match != null) {
        // Line contains a venue link
        final beforeLink = line.substring(0, match.start);
        final venueName = match.group(1)!;
        final afterLink = line.substring(match.end);

        widgets.add(
          Wrap(
            children: [
              if (beforeLink.isNotEmpty)
                Text(
                  beforeLink,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              GestureDetector(
                onTap: () => _openMaps(venueName),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      venueName,
                      style: const TextStyle(
                        color: AppColors.oceanBlue,
                        fontSize: 15,
                        height: 1.4,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.oceanBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.oceanBlue,
                    ),
                  ],
                ),
              ),
              if (afterLink.isNotEmpty)
                Text(
                  afterLink,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        );
      } else {
        // Regular text line - handle markdown bold
        widgets.add(_buildMarkdownText(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parse and render simple markdown (bold text with **)
  Widget _buildMarkdownText(String text) {
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final matches = boldPattern.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          height: 1.4,
        ),
      );
    }

    // Build TextSpans with bold sections
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 15,
            height: 1.4,
          ),
        ));
      }

      spans.add(TextSpan(
        text: match.group(1)!,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          height: 1.4,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Open Google Maps with the venue name
  Future<void> _openMaps(String venueName) async {
    final encodedAddress = Uri.encodeComponent(venueName);

    // Try multiple URL schemes for best compatibility
    final urls = [
      'comgooglemaps://?q=$encodedAddress',
      'https://maps.apple.com/?q=$encodedAddress',
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    ];

    for (final urlString in urls) {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Final fallback
    final fallbackUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    );
    await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
  }
}
