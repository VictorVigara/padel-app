import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/analysis/presentation/providers/analysis_providers.dart';

class MatchAnalysisScreen extends ConsumerWidget {
  final String matchId;

  const MatchAnalysisScreen({
    super.key,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(analysisResultProvider(matchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Analysis'),
      ),
      body: analysisAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading analysis...'),
            ],
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading analysis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(analysisResultProvider(matchId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No analysis available yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analysis results will appear here once processing is complete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Placeholder for actual analysis UI (Task 3 & 4)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Analysis loaded: ${data.players.length} players\n\n'
                'Player data:\n${data.players.map((p) => '- Track ${p.trackId}: ${p.totalDistanceM.toStringAsFixed(0)}m, ${p.courtCoveragePct.toStringAsFixed(1)}%').join('\n')}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        },
      ),
    );
  }
}
