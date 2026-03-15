import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/statistics/presentation/providers/stats_providers.dart';
import 'package:padel_app/features/statistics/presentation/widgets/overview_card.dart';
import 'package:padel_app/features/statistics/presentation/widgets/serve_stats_card.dart';
import 'package:padel_app/features/statistics/presentation/widgets/shot_distribution_card.dart';
import 'package:padel_app/features/statistics/presentation/widgets/performance_breakdown_card.dart';

class StatsDashboardScreen extends ConsumerWidget {
  const StatsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(overviewStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statistics)),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (overview) {
          if (overview.totalMatches == 0) {
            return _buildEmptyState(context, l10n);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(matchListProvider);
              ref.invalidate(allUserStatsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  OverviewCard(stats: overview),
                  const SizedBox(height: 12),
                  _ServeSection(),
                  const SizedBox(height: 12),
                  _ShotSection(),
                  const SizedBox(height: 12),
                  _PerformanceSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noStatsYet,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ServeSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serveAsync = ref.watch(serveStatsProvider);
    return serveAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => ServeStatsCard(stats: stats),
    );
  }
}

class _ShotSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shotAsync = ref.watch(shotDistributionProvider);
    return shotAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => ShotDistributionCard(stats: stats),
    );
  }
}

class _PerformanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceAsync = ref.watch(surfaceBreakdownProvider);
    final typeAsync = ref.watch(matchTypeBreakdownProvider);

    return surfaceAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (bySurface) => typeAsync.when(
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (byType) => PerformanceBreakdownCard(
          bySurface: bySurface,
          byType: byType,
        ),
      ),
    );
  }
}
