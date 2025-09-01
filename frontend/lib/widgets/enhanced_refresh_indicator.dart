import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';

/// Enhanced refresh indicator with smart refresh logic and better UX
class EnhancedRefreshIndicator extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;
  final bool showLastRefreshTime;
  final Color? backgroundColor;
  final Color? color;

  const EnhancedRefreshIndicator({
    super.key,
    required this.child,
    this.onRefresh,
    this.showLastRefreshTime = true,
    this.backgroundColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, _) {
        return RefreshIndicator(
          onRefresh: () async {
            final startTime = DateTime.now();

            // Call custom onRefresh if provided, otherwise use DataService
            if (onRefresh != null) {
              onRefresh!();
            } else {
              await dataService.forceRefresh();
            }

            // Ensure minimum refresh duration for better UX
            final elapsed = DateTime.now().difference(startTime);
            if (elapsed.inMilliseconds < 500) {
              await Future.delayed(
                Duration(milliseconds: 500 - elapsed.inMilliseconds),
              );
            }

            // Show success feedback
            if (context.mounted) {
              _showRefreshFeedback(context, dataService);
            }
          },
          backgroundColor: backgroundColor,
          color: color ?? Theme.of(context).colorScheme.primary,
          child: Stack(
            children: [
              child,
              if (showLastRefreshTime && dataService.hasData)
                _buildLastRefreshIndicator(context, dataService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLastRefreshIndicator(
    BuildContext context,
    DataService dataService,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${dataService.getLastRefreshTime()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
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

  void _showRefreshFeedback(BuildContext context, DataService dataService) {
    if (dataService.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Refresh failed: ${dataService.lastError}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => dataService.forceRefresh(),
          ),
        ),
      );
    } else {
      // Subtle success indication
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Updated successfully',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }
}

/// Quick refresh button widget for manual refresh
class QuickRefreshButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool showLastRefreshTime;
  final bool compact;

  const QuickRefreshButton({
    super.key,
    this.onPressed,
    this.showLastRefreshTime = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, _) {
        if (compact) {
          return IconButton(
            onPressed: dataService.isRefreshing
                ? null
                : () async {
                    if (onPressed != null) {
                      onPressed!();
                    } else {
                      await dataService.forceRefresh();
                    }
                  },
            tooltip: 'Refresh data',
            icon: dataService.isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              onPressed: dataService.isRefreshing
                  ? null
                  : () async {
                      if (onPressed != null) {
                        onPressed!();
                      } else {
                        await dataService.forceRefresh();
                      }
                    },
              tooltip: 'Refresh data',
              child: dataService.isRefreshing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
            if (showLastRefreshTime && dataService.hasData) ...[
              const SizedBox(height: 4),
              Text(
                dataService.getLastRefreshTime(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Smart refresh banner that appears when data is stale
class StaleDataBanner extends StatelessWidget {
  final Duration staleThreshold;

  const StaleDataBanner({
    super.key,
    this.staleThreshold = const Duration(minutes: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, _) {
        final lastFetch = dataService.lastFetch;
        if (lastFetch == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final staleDuration = now.difference(lastFetch);

        if (staleDuration > staleThreshold) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data may be outdated (${dataService.getLastRefreshTime()})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => dataService.forceRefresh(),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
