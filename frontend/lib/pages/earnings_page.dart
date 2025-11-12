import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';

import '../services/earnings_service.dart';
import '../widgets/enhanced_refresh_indicator.dart';
import '../providers/terminology_provider.dart';
import '../l10n/app_localizations.dart';

/// Earnings page with optimized performance and pagination
class EarningsPage extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final Widget profileMenu;
  final Widget Function({required String title, required Widget profileMenu}) buildAppBar;

  const EarningsPage({
    super.key,
    required this.events,
    required this.userKey,
    required this.loading,
    required this.profileMenu,
    required this.buildAppBar,
  });

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> with AutomaticKeepAliveClientMixin {
  late EarningsService _earningsService;
  bool _isVisible = false;
  bool _hasCalculated = false;

  // Pagination state
  int _displayMonths = 12;
  static const int _monthsPerPage = 12;

  // Filter state
  int? _selectedYear;  // null = All years

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _earningsService = EarningsService();

    // Initial calculation will happen when page becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.userKey != null && !widget.loading) {
        _calculateIfNeeded();
      }
    });
  }

  @override
  void didUpdateWidget(EarningsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate if events or userKey changed
    if (oldWidget.events != widget.events ||
        oldWidget.userKey != widget.userKey ||
        oldWidget.loading != widget.loading) {
      if (mounted && widget.userKey != null && !widget.loading && _isVisible) {
        _calculateIfNeeded();
      }
    }
  }

  @override
  void dispose() {
    _earningsService.dispose();
    super.dispose();
  }

  /// Calculate earnings only when needed
  Future<void> _calculateIfNeeded() async {
    if (widget.userKey == null || widget.events.isEmpty) return;

    await _earningsService.calculateEarnings(
      widget.events,
      widget.userKey!,
      forceRecalculation: false,
    );

    if (mounted) {
      _hasCalculated = true;
      setState(() {});
    }
  }

  /// Force recalculation (for pull-to-refresh)
  Future<void> _forceRecalculation() async {
    if (widget.userKey == null) return;

    _earningsService.invalidateCache();
    await _earningsService.calculateEarnings(
      widget.events,
      widget.userKey!,
      forceRecalculation: true,
    );

    if (mounted) {
      setState(() {});
    }
  }

  /// Load more months
  void _loadMoreMonths() {
    setState(() {
      _displayMonths += _monthsPerPage;
    });
  }

  /// Select year filter
  void _selectYear(int? year) {
    setState(() {
      _selectedYear = year;
      _displayMonths = 12;  // Reset pagination when filter changes
    });
  }

  /// Filter monthly data by selected year
  List<MonthlyEarnings> _filterMonthlyData(List<MonthlyEarnings> allMonths) {
    if (_selectedYear == null) return allMonths;
    return allMonths.where((month) => month.year == _selectedYear).toList();
  }

  /// Calculate aggregate statistics across all years
  YearlyStats? _calculateAggregateStats(Map<int, YearlyStats> yearlyStats) {
    if (yearlyStats.isEmpty) return null;

    double totalEarnings = 0.0;
    double totalHours = 0.0;
    int totalShifts = 0;
    final Map<String, int> aggregateRoleBreakdown = {};
    final Map<String, double> aggregateRoleEarnings = {};

    // Aggregate all years
    for (final stats in yearlyStats.values) {
      totalEarnings += stats.totalEarnings;
      totalHours += stats.totalHours;
      totalShifts += stats.totalShifts;

      // Merge role breakdowns
      stats.roleBreakdown.forEach((role, count) {
        aggregateRoleBreakdown[role] = (aggregateRoleBreakdown[role] ?? 0) + count;
      });

      // Merge role earnings
      stats.roleEarnings.forEach((role, earnings) {
        aggregateRoleEarnings[role] = (aggregateRoleEarnings[role] ?? 0.0) + earnings;
      });
    }

    return YearlyStats(
      year: 0,  // Special value to indicate "all years"
      totalEarnings: totalEarnings,
      totalHours: totalHours,
      totalShifts: totalShifts,
      roleBreakdown: aggregateRoleBreakdown,
      roleEarnings: aggregateRoleEarnings,
    );
  }

  /// Handle visibility changes
  void _onVisibilityChanged(VisibilityInfo info) {
    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.1;

    // Calculate when page becomes visible for the first time
    if (!wasVisible && _isVisible && !_hasCalculated) {
      _calculateIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);

    return VisibilityDetector(
      key: const Key('earnings-page'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    // Login required state
    if (widget.userKey == null) {
      return CustomScrollView(
        slivers: [
          widget.buildAppBar(
            title: l10n.myEarnings,
            profileMenu: widget.profileMenu,
          ),
          SliverFillRemaining(
            child: Center(
              child: Text(
                l10n.pleaseLoginToViewEarnings,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    // Loading state (initial data load)
    if (widget.loading) {
      return CustomScrollView(
        slivers: [
          widget.buildAppBar(
            title: l10n.myEarnings,
            profileMenu: widget.profileMenu,
          ),
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    // Build with earnings data
    return ListenableBuilder(
      listenable: _earningsService,
      builder: (context, _) {
        final data = _earningsService.data;
        final isCalculating = _earningsService.isCalculating;

        // Show calculating state if not calculated yet
        if (!_hasCalculated && isCalculating) {
          return CustomScrollView(
            slivers: [
              widget.buildAppBar(
                title: l10n.myEarnings,
                profileMenu: widget.profileMenu,
              ),
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.calculatingEarnings),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Empty state
        if (data.yearTotal == 0.0 && data.monthlyData.isEmpty) {
          return CustomScrollView(
            slivers: [
              widget.buildAppBar(
                title: l10n.myEarnings,
                profileMenu: widget.profileMenu,
              ),
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 80,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.noEarningsYetTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.completeEventsToSeeEarnings,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Main earnings view with pagination
        final filteredMonths = _filterMonthlyData(data.monthlyData);
        final displayedMonths = filteredMonths.take(_displayMonths).toList();
        final hasMoreMonths = filteredMonths.length > _displayMonths;

        // Calculate displayed totals based on filter
        final displayedYearlyStats = _selectedYear != null
            ? data.yearlyStats[_selectedYear]
            : _calculateAggregateStats(data.yearlyStats);
        final displayedTotal = displayedYearlyStats?.totalEarnings ?? data.yearTotal;

        return EnhancedRefreshIndicator(
          showLastRefreshTime: false,
          onRefresh: _forceRecalculation,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              widget.buildAppBar(
                title: l10n.myEarnings,
                profileMenu: widget.profileMenu,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Year Filter Chips
                    if (data.availableYears.isNotEmpty)
                      RepaintBoundary(
                        child: _buildYearFilterChips(theme, data.availableYears, l10n),
                      ),

                    if (data.availableYears.isNotEmpty)
                      const SizedBox(height: 16),

                    // Total Earnings Card with RepaintBoundary (redesigned)
                    RepaintBoundary(
                      child: _buildEnhancedEarningsCard(context, theme, displayedTotal, displayedYearlyStats, l10n),
                    ),

                    const SizedBox(height: 32),

                    // Monthly Breakdown Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.monthly,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Monthly Cards
                    ...displayedMonths.map((month) {
                      return RepaintBoundary(
                        child: _buildMonthlyCard(theme, month),
                      );
                    }),

                    // Load More Button
                    if (hasMoreMonths) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _loadMoreMonths,
                          icon: const Icon(Icons.expand_more, size: 20),
                          label: Text(
                            l10n.loadMoreMonths((filteredMonths.length - _displayMonths).clamp(0, _monthsPerPage)),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Bottom padding to clear bottom navigation bar
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build year filter chips
  Widget _buildYearFilterChips(ThemeData theme, List<int> years, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(l10n.allYearsFilter),
              selected: _selectedYear == null,
              onSelected: (selected) => _selectYear(null),
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedYear == null ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: _selectedYear == null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // Year chips
          ...years.map((year) {
            final isSelected = _selectedYear == year;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(year.toString()),
                selected: isSelected,
                onSelected: (selected) => _selectYear(year),
                selectedColor: theme.colorScheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build enhanced earnings card with detailed stats
  Widget _buildEnhancedEarningsCard(BuildContext context, ThemeData theme, double total, YearlyStats? stats, AppLocalizations l10n) {
    final terminologyProvider = context.watch<TerminologyProvider>();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with year indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedYear != null ? l10n.yearEarnings(_selectedYear!) : l10n.totalEarningsTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (stats != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            terminologyProvider.getCount(stats.totalShifts),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Main earnings amount
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),

                  if (stats != null) ...[
                    const SizedBox(height: 24),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatPill(
                            theme,
                            l10n.hours,
                            stats.totalHours.toStringAsFixed(1),
                            Icons.access_time_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatPill(
                            theme,
                            l10n.avgRate,
                            '\$${(stats.totalEarnings / stats.totalHours).toStringAsFixed(0)}/hr',
                            Icons.trending_up_rounded,
                          ),
                        ),
                      ],
                    ),

                    // Role breakdown
                    if (stats.roleBreakdown.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: stats.roleBreakdown.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.key}: ${entry.value}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build stat pill widget
  Widget _buildStatPill(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build monthly earnings card
  Widget _buildMonthlyCard(ThemeData theme, MonthlyEarnings month) {
    final now = DateTime.now();
    final allYears = _earningsService.data.monthlyData.map((m) => m.year).toSet();
    final showYear = allYears.length > 1 || month.year != now.year;
    final displayLabel = showYear ? '${month.monthName} ${month.year}' : month.monthName;

    final avgRate = month.totalHours > 0
        ? month.totalEarnings / month.totalHours
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MonthlyEarningsDetailPage(
                monthName: displayLabel,
                monthNum: month.monthNum,
                year: month.year,
                earningsService: _earningsService,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '\$${month.totalEarnings.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.access_time,
                      label: AppLocalizations.of(context)!.hours,
                      value: month.totalHours.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.event,
                      label: AppLocalizations.of(context)!.events,
                      value: '${month.eventCount}',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.trending_up,
                      label: AppLocalizations.of(context)!.avgRate,
                      value: '\$${avgRate.toStringAsFixed(0)}/hr',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stat item widget (reused from original)
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Monthly earnings detail page (optimized to use cached data)
class MonthlyEarningsDetailPage extends StatelessWidget {
  final String monthName;
  final int monthNum;
  final int year;
  final EarningsService earningsService;

  const MonthlyEarningsDetailPage({
    super.key,
    required this.monthName,
    required this.monthNum,
    required this.year,
    required this.earningsService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Get cached monthly events (no recalculation!)
    final yearMonth = '$year-${monthNum.toString().padLeft(2, '0')}';
    final monthlyEvents = earningsService.getMonthlyEvents(yearMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(monthName),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
      ),
      body: monthlyEvents.isEmpty
          ? Center(
              child: Text(
                l10n.noEventsFoundForMonth,
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: monthlyEvents.length,
              itemBuilder: (context, index) {
                final eventData = monthlyEvents[index];
                return RepaintBoundary(
                  child: _buildEventCard(context, theme, eventData, l10n),
                );
              },
            ),
    );
  }

  Widget _buildEventCard(BuildContext context, ThemeData theme, EventEarnings eventData, AppLocalizations l10n) {
    final event = eventData.event;
    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? 'Unknown Client';
    final venueName = event['venue_name']?.toString() ?? 'No venue';
    final venueAddress = event['venue_address']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name & Earnings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${eventData.date.month}/${eventData.date.day}/${eventData.date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${eventData.earnings.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B46C1),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Client
            _DetailRow(
              icon: Icons.business,
              label: l10n.client,
              value: clientName,
            ),

            const SizedBox(height: 8),

            // Venue
            _DetailRow(
              icon: Icons.location_on,
              label: l10n.venue,
              value: venueAddress != null && venueAddress.isNotEmpty
                  ? '$venueName\n$venueAddress'
                  : venueName,
            ),

            const SizedBox(height: 8),

            // Role
            _DetailRow(
              icon: Icons.badge,
              label: l10n.role,
              value: eventData.role,
            ),

            const SizedBox(height: 16),

            // Stats Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _EventStat(
                    label: l10n.hours,
                    value: eventData.hours.toStringAsFixed(1),
                    icon: Icons.access_time,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  _EventStat(
                    label: l10n.rate,
                    value: '\$${eventData.rate.toStringAsFixed(2)}/hr',
                    icon: Icons.attach_money,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B46C1).withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Event stat widget
class _EventStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _EventStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF6B46C1)),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
