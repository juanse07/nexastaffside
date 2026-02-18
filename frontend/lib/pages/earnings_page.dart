import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';

import '../services/earnings_service.dart';
import '../services/export_service.dart';
import '../widgets/enhanced_refresh_indicator.dart';
import '../widgets/export_options_sheet.dart';
import '../providers/terminology_provider.dart';
import '../l10n/app_localizations.dart';
import '../shared/presentation/theme/theme.dart';

/// Earnings page with optimized performance and pagination
class EarningsPage extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final String? userKey;
  final bool loading;
  final Widget profileMenu;
  final Widget Function({required BuildContext context, required String title, required Widget profileMenu, VoidCallback? onTitleTap}) buildAppBar;
  final VoidCallback? onTitleTap;

  const EarningsPage({
    super.key,
    required this.events,
    required this.userKey,
    required this.loading,
    required this.profileMenu,
    required this.buildAppBar,
    this.onTitleTap,
  });

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> with AutomaticKeepAliveClientMixin {
  late EarningsService _earningsService;
  final _exportButtonKey = GlobalKey();
  bool _isVisible = false;
  bool _hasCalculated = false;
  bool _isExporting = false;
  bool _isScrolled = false;

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

  /// Show export options and perform export
  Future<void> _showExportOptions() async {
    final result = await showModalBottomSheet<StaffExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StaffExportOptionsSheet(
        selectedYear: _selectedYear?.toString(),
      ),
    );

    if (result != null) {
      await _performExport(result);
    }
  }

  /// Perform the export
  Future<void> _performExport(StaffExportOptions options) async {
    setState(() => _isExporting = true);

    try {
      final exportResult = await ExportService.exportShifts(
        format: options.format,
        period: options.period,
        startDate: options.startDate,
        endDate: options.endDate,
      );

      if (exportResult.success) {
        // Get the FAB's position for the iOS share popover anchor
        Rect? origin;
        final renderBox = _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          origin = position & renderBox.size;
        }

        final shareError = await ExportService.shareExport(exportResult, origin: origin);

        if (shareError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $shareError')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exportResult.error ?? 'Export failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final scrolled = notification.metrics.pixels > 80;
            if (scrolled != _isScrolled) {
              setState(() => _isScrolled = scrolled);
            }
          }
          return false;
        },
        child: Stack(
          children: [
            _buildContent(theme),
            // Export button - only show when user is logged in
            if (widget.userKey != null)
              Positioned(
                right: 16,
                bottom: 130,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_isScrolled ? 28 : 16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      key: _exportButtonKey,
                      height: _isScrolled ? 48 : 48,
                      padding: EdgeInsets.symmetric(
                        horizontal: _isScrolled ? 12 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navySpaceCadet.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(_isScrolled ? 28 : 16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isExporting ? null : _showExportOptions,
                          borderRadius: BorderRadius.circular(_isScrolled ? 28 : 16),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isExporting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.download, color: Colors.white, size: 22),
                                if (!_isScrolled) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _isExporting ? 'Exporting...' : 'Export',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    // Login required state
    if (widget.userKey == null) {
      return CustomScrollView(
        slivers: [
          widget.buildAppBar(
            context: context,
            title: l10n.myEarnings,
            profileMenu: widget.profileMenu,
            onTitleTap: widget.onTitleTap,
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
            context: context,
            title: l10n.myEarnings,
            profileMenu: widget.profileMenu,
            onTitleTap: widget.onTitleTap,
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
                context: context,
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
                context: context,
                title: l10n.myEarnings,
                profileMenu: widget.profileMenu,
              ),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/earnings_empty.png',
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.noEarningsYetTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.navySpaceCadet,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.completeEventsToSeeEarnings,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
                context: context,
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
                          color: AppColors.navySpaceCadet,
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
              selectedColor: AppColors.yellow,
              checkmarkColor: AppColors.navySpaceCadet,
              backgroundColor: AppColors.surfaceLight,
              side: BorderSide(
                color: _selectedYear == null ? AppColors.yellow : AppColors.navySpaceCadet.withValues(alpha: 0.3),
              ),
              labelStyle: TextStyle(
                color: _selectedYear == null ? AppColors.navySpaceCadet : AppColors.navySpaceCadet,
                fontWeight: _selectedYear == null ? FontWeight.w700 : FontWeight.w500,
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
                selectedColor: AppColors.yellow,
                checkmarkColor: AppColors.navySpaceCadet,
                backgroundColor: AppColors.surfaceLight,
                side: BorderSide(
                  color: isSelected ? AppColors.yellow : AppColors.navySpaceCadet.withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  color: AppColors.navySpaceCadet,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navySpaceCadet.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circles with navy tint
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navySpaceCadet.withValues(alpha: 0.05),
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
                  color: AppColors.yellow.withValues(alpha: 0.1),
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
                            color: AppColors.navySpaceCadet.withValues(alpha: 0.8),
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
                            color: AppColors.navySpaceCadet,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            terminologyProvider.getCount(stats.totalShifts),
                            style: const TextStyle(
                              color: AppColors.yellow,
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
                      color: AppColors.navySpaceCadet,
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
                              color: AppColors.navySpaceCadet.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.navySpaceCadet.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 14,
                                  color: AppColors.navySpaceCadet.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.key}: ${entry.value}',
                                  style: TextStyle(
                                    color: AppColors.navySpaceCadet.withValues(alpha: 0.9),
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
        color: AppColors.navySpaceCadet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.navySpaceCadet.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navySpaceCadet,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.navySpaceCadet.withValues(alpha: 0.6),
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
      color: Colors.white,
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
                      color: AppColors.navySpaceCadet,
                    ),
                  ),
                  // Earnings amount with navy label background and yellow text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.navySpaceCadet,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${month.totalEarnings.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.yellow,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MonthStatItem(
                      icon: Icons.access_time,
                      label: AppLocalizations.of(context)!.hours,
                      value: month.totalHours.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: _MonthStatItem(
                      icon: Icons.event,
                      label: AppLocalizations.of(context)!.events,
                      value: '${month.eventCount}',
                    ),
                  ),
                  Expanded(
                    child: _MonthStatItem(
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

/// Stat item widget for monthly cards (navy theme on white background)
class _MonthStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MonthStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.navySpaceCadet.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.navySpaceCadet,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.navySpaceCadet.withValues(alpha: 0.6),
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

    // Calculate month totals
    double totalEarnings = 0;
    double totalHours = 0;
    for (final e in monthlyEvents) {
      totalEarnings += e.earnings;
      totalHours += e.hours;
    }
    final avgRate = totalHours > 0 ? totalEarnings / totalHours : 0.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        slivers: [
          // Gradient header with month summary
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.navySpaceCadet,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          monthName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${monthlyEvents.length} ${monthlyEvents.length == 1 ? 'event' : 'events'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Summary stats row
                        Row(
                          children: [
                            _HeaderStat(
                              label: l10n.totalEarningsTitle,
                              value: '\$${totalEarnings.toStringAsFixed(2)}',
                              isHighlighted: true,
                            ),
                            const SizedBox(width: 24),
                            _HeaderStat(
                              label: l10n.hours,
                              value: totalHours.toStringAsFixed(1),
                            ),
                            const SizedBox(width: 24),
                            _HeaderStat(
                              label: l10n.avgRate,
                              value: '\$${avgRate.toStringAsFixed(0)}/hr',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
          ),

          // Event cards
          if (monthlyEvents.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 64,
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noEventsFoundForMonth,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= monthlyEvents.length) return null;
                    final eventData = monthlyEvents[index];
                    return RepaintBoundary(
                      child: _buildEventCard(context, theme, eventData, l10n),
                    );
                  },
                  childCount: monthlyEvents.length,
                ),
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, ThemeData theme, EventEarnings eventData, AppLocalizations l10n) {
    final event = eventData.event;
    final eventName = event['event_name']?.toString() ?? 'Untitled Event';
    final clientName = event['client_name']?.toString() ?? 'Unknown Client';
    final venueName = event['venue_name']?.toString() ?? 'No venue';
    final venueAddress = event['venue_address']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.navySpaceCadet.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Top section: event name, date, earnings
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${eventData.date.month}/${eventData.date.day}/${eventData.date.year}',
                        style: TextStyle(
                          color: AppColors.navySpaceCadet.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.navySpaceCadet,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${eventData.earnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.yellow,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Detail chips row
            Row(
              children: [
                Expanded(
                  child: _DetailChip(
                    icon: Icons.business_rounded,
                    value: clientName,
                  ),
                ),
                const SizedBox(width: 8),
                _DetailChip(
                  icon: Icons.badge_rounded,
                  value: eventData.role,
                ),
              ],
            ),

            if (venueAddress != null && venueAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailChip(
                icon: Icons.location_on_rounded,
                value: '$venueName, $venueAddress',
                fullWidth: true,
              ),
            ] else ...[
              const SizedBox(height: 6),
              _DetailChip(
                icon: Icons.location_on_rounded,
                value: venueName,
                fullWidth: true,
              ),
            ],

            const SizedBox(height: 10),

            // Stats footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.navySpaceCadet.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _EventStat(
                      label: l10n.hours,
                      value: eventData.hours.toStringAsFixed(1),
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.navySpaceCadet.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: _EventStat(
                      label: l10n.rate,
                      value: '\$${eventData.rate.toStringAsFixed(2)}/hr',
                      icon: Icons.trending_up_rounded,
                    ),
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

/// Header stat for the gradient summary area
class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _HeaderStat({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? AppColors.yellow : Colors.white,
            fontSize: isHighlighted ? 22 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Compact detail chip widget
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool fullWidth;

  const _DetailChip({
    required this.icon,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.navySpaceCadet.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.navySpaceCadet.withValues(alpha: 0.45)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppColors.navySpaceCadet,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
    return chip;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: AppColors.navySpaceCadet.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.navySpaceCadet,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.navySpaceCadet.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
