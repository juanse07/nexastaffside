import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/message_composition_service.dart';

/// Beautiful bottom sheet for AI-powered message composition
/// Provides quick actions for common scenarios with elegant animations
class AiMessageComposer extends StatefulWidget {
  final String authToken;
  final Function(String message) onMessageComposed;
  final String? initialText;

  const AiMessageComposer({
    super.key,
    required this.authToken,
    required this.onMessageComposed,
    this.initialText,
  });

  static void show({
    required BuildContext context,
    required String authToken,
    required Function(String message) onMessageComposed,
    String? initialText,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiMessageComposer(
        authToken: authToken,
        onMessageComposed: onMessageComposed,
        initialText: initialText,
      ),
    );
  }

  @override
  State<AiMessageComposer> createState() => _AiMessageComposerState();
}

class _AiMessageComposerState extends State<AiMessageComposer>
    with SingleTickerProviderStateMixin {
  final _service = MessageCompositionService();
  final _detailsController = TextEditingController();

  ComposedMessageResponse? _composedMessage;
  bool _isLoading = false;
  String? _errorMessage;
  MessageScenario? _selectedScenario;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // If initial text provided, auto-select polish scenario
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _detailsController.text = widget.initialText!;
      _selectedScenario = MessageScenario.polish;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _composeMessage(MessageScenario scenario) async {
    setState(() {
      _selectedScenario = scenario;
      _isLoading = true;
      _errorMessage = null;
      _composedMessage = null;
    });

    try {
      final response = await _service.composeMessage(
        scenario: scenario,
        message: scenario == MessageScenario.translate ||
                 scenario == MessageScenario.polish ||
                 scenario == MessageScenario.professionalize
            ? _detailsController.text
            : null,
        details: scenario != MessageScenario.translate &&
                 scenario != MessageScenario.polish &&
                 scenario != MessageScenario.professionalize &&
                 _detailsController.text.isNotEmpty
            ? _detailsController.text
            : null,
        authToken: widget.authToken,
      );

      setState(() {
        _composedMessage = response;
        _isLoading = false;
      });
    } on MessageCompositionException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.failedToComposeMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  void _useMessage(String message) {
    final l10n = AppLocalizations.of(context)!;
    widget.onMessageComposed(message);
    Navigator.of(context).pop();

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(l10n.messageInserted),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _copyToClipboard(String text) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.content_copy, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(l10n.copiedToClipboard),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _adjustTone(String tone) async {
    if (_composedMessage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tonePrompt = tone == 'professional'
          ? 'Rewrite this message in a professional and friendly tone (keep it concise): ${_composedMessage!.original}'
          : 'Rewrite this message in a casual and friendly tone (keep it concise): ${_composedMessage!.original}';

      // Use custom scenario to adjust tone
      final response = await _service.composeMessage(
        scenario: MessageScenario.custom,
        details: tonePrompt,
        authToken: widget.authToken,
      );

      setState(() {
        _composedMessage = response;
        _isLoading = false;
      });
    } on MessageCompositionException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.failedToComposeMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (!_isLoading && _composedMessage == null) ...[
                    _buildScenarioChips(),
                    const SizedBox(height: 16),
                    _buildDetailsInput(),
                  ],
                  if (_isLoading) _buildLoadingState(),
                  if (_composedMessage != null) _buildMessagePreview(),
                  if (_errorMessage != null) _buildErrorState(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC107), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiMessageAssistant,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.composeProfessionalMessages,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF718096)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: MessageScenario.values.map((scenario) {
          final isSelected = _selectedScenario == scenario;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ActionChip(
                avatar: Text(scenario.emoji, style: const TextStyle(fontSize: 18)),
                label: Text(scenario.displayName),
                backgroundColor: isSelected
                    ? const Color(0xFFFFC107).withOpacity(0.1)
                    : Colors.grey[100],
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFFC107) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFFFC107) : const Color(0xFF4A5568),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                onPressed: () {
                  if (scenario == MessageScenario.translate ||
                      scenario == MessageScenario.polish ||
                      scenario == MessageScenario.professionalize) {
                    // These need input text
                    if (_detailsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter text to ${scenario.displayName.toLowerCase()}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                  }
                  _composeMessage(scenario);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getInputLabel(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _getInputHint(),
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _getInputLabel() {
    if (_selectedScenario == MessageScenario.translate ||
        _selectedScenario == MessageScenario.polish ||
        _selectedScenario == MessageScenario.professionalize) {
      return 'Your message:';
    }
    return 'Details (optional):';
  }

  String _getInputHint() {
    if (_selectedScenario == MessageScenario.translate) {
      return 'Enter text to translate...';
    } else if (_selectedScenario == MessageScenario.polish) {
      return 'Enter message to make more professional...';
    } else if (_selectedScenario == MessageScenario.professionalize) {
      return 'Enter message to make professional, friendly & concise...';
    }
    return 'Add any details to help compose your message...';
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Opacity(
                  opacity: 0.3 + (value * 0.7),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC107), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  ),
                ),
              );
            },
            onEnd: () {
              // Loop animation
              setState(() {});
            },
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.composingYourMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This should only take a moment',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePreview() {
    if (_composedMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMessageCard(
            title: _composedMessage!.language == 'es' ? '🇪🇸 Spanish' : '🇺🇸 English',
            message: _composedMessage!.original,
            isPrimary: true,
          ),
          if (_composedMessage!.hasTranslation) ...[
            const SizedBox(height: 12),
            _buildMessageCard(
              title: '🇬🇧 English Translation',
              message: _composedMessage!.translation!,
              isPrimary: false,
            ),
          ],
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required String title,
    required String message,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFFFFC107).withOpacity(0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFFFFC107).withOpacity(0.3)
              : Colors.grey[200]!,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? const Color(0xFFFFC107) : const Color(0xFF718096),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.content_copy,
                  size: 18,
                  color: isPrimary ? const Color(0xFFFFC107) : Colors.grey[600],
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copyToClipboard(message),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tone adjustment options before "Use Message"
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.tone}:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adjustTone('professional'),
                      icon: const Icon(Icons.business_center, size: 16),
                      label: Text(l10n.professionalFriendly),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFC107),
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adjustTone('casual'),
                      icon: const Icon(Icons.emoji_emotions, size: 16),
                      label: Text(l10n.casualFriendly),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFC107),
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _useMessage(_composedMessage!.original),
          icon: const Icon(Icons.check_circle),
          label: Text(l10n.useMessage),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        if (_composedMessage!.hasTranslation) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _useMessage(_composedMessage!.formattedMessages),
            icon: const Icon(Icons.translate),
            label: Text('${l10n.useBoth} (${l10n.originalMessage} + ${l10n.generatedMessage})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFC107),
              side: const BorderSide(color: Color(0xFFFFC107)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _composedMessage = null;
              _selectedScenario = null;
            });
          },
          icon: const Icon(Icons.refresh),
          label: Text(l10n.tryDifferentScenario),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _selectedScenario = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.tryAgain),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
