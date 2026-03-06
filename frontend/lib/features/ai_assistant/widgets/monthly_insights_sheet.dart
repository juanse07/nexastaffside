import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/commute_service.dart';
import '../../../services/subscription_service.dart';
import '../../../shared/widgets/subscription_gate.dart';
import '../config/app_config.dart';
import '../services/staff_chat_service.dart';

/// Bottom sheet that shows AI-generated monthly insights for the focused calendar month.
/// Makes a direct HTTP call to the backend (no StaffChatService context pre-fetch)
/// to avoid the hanging GET /api/ai/staff/context that blocked the initial request.
class MonthlyInsightsSheet extends StatefulWidget {
  const MonthlyInsightsSheet({
    super.key,
    required this.focusedMonth,
    this.customTitle,
    this.customPrompt,
    this.loadingLabel,
  });

  final DateTime focusedMonth;

  /// If set, overrides the default "Monthly Insights" header title.
  final String? customTitle;

  /// If set, this prompt is sent directly instead of the month-analysis prompt.
  final String? customPrompt;

  /// If set, overrides the "Valerio is analyzing your month..." loading label.
  final String? loadingLabel;

  @override
  State<MonthlyInsightsSheet> createState() => _MonthlyInsightsSheetState();
}

class _MonthlyInsightsSheetState extends State<MonthlyInsightsSheet>
    with SingleTickerProviderStateMixin {
  // Used only for follow-up messages (seeded after initial analysis succeeds).
  final StaffChatService _chatService = StaffChatService();
  final TextEditingController _followUpController = TextEditingController();

  late AnimationController _pulseController;

  bool _loading = true;
  bool _sendingFollowUp = false;
  bool _hitMessageLimit = false;
  String? _analysis;
  String? _followUpResponse;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Defer until after the first frame so AppLocalizations.of(context) works.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAnalysis());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  // ─── Initial Analysis (direct HTTP, no context pre-fetch) ──────────────────

  Future<void> _fetchAnalysis() async {
    // Subscription gate
    if (SubscriptionService().isReadOnly) {
      if (mounted) {
        Navigator.pop(context);
        showSubscriptionRequiredSheet(context,
            featureName: AppLocalizations.of(context)!.monthlyInsights);
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _analysis = null;
      _followUpResponse = null;
      _hitMessageLimit = false;
    });

    // Capture l10n synchronously before any await.
    final l10n = AppLocalizations.of(context)!;

    try {
      // Build commute addendum from in-memory cache (instant, no HTTP).
      String commuteAddendum = '';
      if (widget.customPrompt != null) {
        final cached = CommuteService.allCached;
        if (cached.isNotEmpty) {
          double totalRoundTripMi = 0;
          final lines = cached.entries.map((e) {
            final rt = e.value.distanceMiles * 2;
            final rtMin = e.value.durationMinutes * 2;
            totalRoundTripMi += rt;
            return '- ${e.key}: ${e.value.distanceMiles.toStringAsFixed(1)} mi one-way'
                ' → ${rt.toStringAsFixed(1)} mi round-trip (~$rtMin min)';
          }).join('\n');
          commuteAddendum = '\n\nPre-computed driving distances from my home'
              ' (use ONLY these figures — do NOT include any links):\n$lines\n'
              'Combined round-trip miles across all unique venues: ${totalRoundTripMi.toStringAsFixed(1)} mi.';
        }
      }

      final String prompt;
      if (widget.customPrompt != null) {
        prompt = widget.customPrompt! + commuteAddendum;
      } else {
        final monthStr = DateFormat.yMMMM().format(widget.focusedMonth);
        final todayStr = DateFormat.yMMMMd().format(DateTime.now());
        prompt = l10n.monthlyAnalysisPrompt(monthStr, todayStr);
      }

      // Direct HTTP call — bypasses StaffChatService.sendMessage() to avoid the
      // GET /api/ai/staff/context pre-fetch that was hanging before the POST.
      final token = await AuthService.getJwt();
      if (token == null) throw Exception('Not authenticated');

      debugPrint('[MonthlyInsights] Sending request...');

      final uri = Uri.parse('${AIAssistantConfig.baseUrl}/api/ai/staff/chat/message');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
          'maxTokens': 1500,
          'provider': 'groq',
        }),
      ).timeout(const Duration(seconds: 120));

      debugPrint('[MonthlyInsights] Response: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 402) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = errorData['message']?.toString() ??
            'Message limit reached. Upgrade to Pro for more messages.';
        setState(() {
          _hitMessageLimit = true;
          _analysis = '⚠️ $msg';
          _loading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content']?.toString() ?? '';
        if (content.isNotEmpty) {
          // Seed the chat service with this exchange so follow-up messages
          // can reference Valerio's initial analysis.
          await _chatService.initialize();
          _chatService.seedExchange(prompt, content);
          setState(() {
            _analysis = content;
            _loading = false;
          });
          return;
        }
      }

      // Non-200 or empty content
      setState(() {
        _error = l10n.failedToAnalyze;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MonthlyInsights] Error: $e');
      if (mounted) {
        setState(() {
          _error = l10n.failedToAnalyze;
          _loading = false;
        });
      }
    }
  }

  // ─── Follow-up (uses StaffChatService with seeded history) ─────────────────

  Future<void> _sendFollowUp() async {
    final text = _followUpController.text.trim();
    if (text.isEmpty || _sendingFollowUp) return;

    setState(() => _sendingFollowUp = true);
    _followUpController.clear();

    try {
      final response = await _chatService.sendMessage(text);
      if (!mounted) return;

      if (response == null) {
        setState(() => _sendingFollowUp = false);
        return;
      }

      if (response.role == 'system' && response.content.contains('⚠️')) {
        setState(() {
          _hitMessageLimit = true;
          _followUpResponse = response.content;
          _sendingFollowUp = false;
        });
        return;
      }

      setState(() {
        _followUpResponse = response.content;
        _sendingFollowUp = false;
      });
    } catch (e) {
      debugPrint('[MonthlyInsights] Follow-up error: $e');
      if (mounted) setState(() => _sendingFollowUp = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height * 0.63;
    final String headerTitle = widget.customTitle ?? l10n.monthlyInsights;
    final String? headerSubtitle = widget.customPrompt == null
        ? DateFormat.yMMMM().format(widget.focusedMonth)
        : null;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/ai_assistant_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212C4A),
                        ),
                      ),
                      if (headerSubtitle != null)
                        Text(
                          headerSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _loading
                ? _buildLoadingState(l10n)
                : _error != null
                    ? _buildErrorState(l10n)
                    : _buildAnalysisContent(),
          ),

          // Follow-up input (only when analysis loaded and no message limit)
          if (_analysis != null && !_loading && !_hitMessageLimit)
            _buildFollowUpBar(l10n),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ─── Loading State ─────────────────────────────────────

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing Valerio avatar
          FadeTransition(
            opacity: Tween<double>(begin: 0.4, end: 1.0)
                .animate(_pulseController),
            child: ClipOval(
              child: Image.asset(
                'assets/ai_assistant_logo.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Shimmer-like placeholder bars
          for (final width in [180.0, 140.0, 160.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.2, end: 0.5)
                    .animate(_pulseController),
                child: Container(
                  width: width,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
          Text(
            widget.loadingLabel ?? l10n.valerioAnalyzing,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Error State ───────────────────────────────────────

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchAnalysis,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Analysis Content ──────────────────────────────────

  Widget _buildAnalysisContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: _analysis ?? '',
            styleSheet: _markdownStyle,
          ),
          if (_followUpResponse != null) ...[
            const Divider(height: 32),
            MarkdownBody(
              data: _followUpResponse!,
              styleSheet: _markdownStyle,
            ),
          ],
        ],
      ),
    );
  }

  MarkdownStyleSheet get _markdownStyle => MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF212C4A),
        ),
        h2: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212C4A),
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
        p: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFF374151),
        ),
        listBullet: const TextStyle(
          fontSize: 14,
          color: Color(0xFF374151),
        ),
        strong: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF212C4A),
        ),
      );

  // ─── Follow-up Input ───────────────────────────────────

  Widget _buildFollowUpBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _followUpController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendFollowUp(),
              decoration: InputDecoration(
                hintText: l10n.askFollowUp,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _sendingFollowUp
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Color(0xFF212C4A), size: 22),
                  onPressed: _sendFollowUp,
                ),
        ],
      ),
    );
  }
}
