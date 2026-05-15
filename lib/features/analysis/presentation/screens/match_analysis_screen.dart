import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/analysis/domain/models/analysis_result.dart';
import 'package:padel_app/features/analysis/presentation/providers/analysis_providers.dart';
import 'package:padel_app/features/analysis/presentation/widgets/court_heatmap_painter.dart';

class MatchAnalysisScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchAnalysisScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchAnalysisScreen> createState() => _MatchAnalysisScreenState();
}

class _MatchAnalysisScreenState extends ConsumerState<MatchAnalysisScreen> {
  int _selectedPlayerIndex = 0;
  bool _showYourSide = true;

  static const _playerColors = [
    AppColors.player1,
    AppColors.player2,
    AppColors.player3,
    AppColors.player4,
  ];

  // Parses the integer suffix of backend `track_id` strings ("player_3" → 3).
  // This is the player tracker's logical_player_id: 1=near-left, 2=near-right,
  // 3=far-left, 4=far-right. Falls back to a large sentinel so unparseable IDs
  // sort to the end without crashing.
  static int _logicalId(String trackId) {
    final m = RegExp(r'(\d+)$').firstMatch(trackId);
    return m == null ? 999 : int.parse(m.group(1)!);
  }

  String _inferPosition(List<List<double>> heatmap) {
    if (heatmap.isEmpty) return '—';

    double weightedRow = 0;
    double weightedCol = 0;
    double totalWeight = 0;

    for (int r = 0; r < heatmap.length; r++) {
      for (int c = 0; c < heatmap[r].length; c++) {
        final w = heatmap[r][c];
        weightedRow += r * w;
        weightedCol += c * w;
        totalWeight += w;
      }
    }

    if (totalWeight == 0) return '—';

    final comRow = weightedRow / totalWeight;
    final comCol = weightedCol / totalWeight;

    final depth = comRow < 10 ? 'Back' : 'Front';
    final side = comCol < 5 ? 'Left' : 'Right';
    return '$depth $side';
  }

  @override
  Widget build(BuildContext context) {
    final analysisAsync = ref.watch(analysisResultProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match Analysis')),
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
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading analysis',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(analysisResultProvider(widget.matchId)),
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
                  Icon(Icons.analytics_outlined,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('No analysis available yet',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Analysis results will appear here once processing is complete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Sort by the player tracker's logical_player_id (parsed from
          // `track_id` strings like "player_3"). The backend builds the list
          // in detection-insertion order, so without this sort UI "P1" can
          // map to logical P3 and the heatmap lands in the wrong half.
          final players = [...data.players]
            ..sort((a, b) =>
                _logicalId(a.trackId).compareTo(_logicalId(b.trackId)));
          final safeIndex =
              _selectedPlayerIndex.clamp(0, players.length - 1);
          final selected = players[safeIndex];
          final selectedLogicalId = _logicalId(selected.trackId);
          final maxDistance = players
              .map((p) => p.totalDistanceM)
              .reduce((a, b) => a > b ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player selector chips
                Wrap(
                  spacing: 8,
                  children: List.generate(players.length, (i) {
                    final logicalId = _logicalId(players[i].trackId);
                    final color =
                        _playerColors[(logicalId - 1).clamp(0, 3)];
                    return ChoiceChip(
                      label: Text('P$logicalId'),
                      selected: safeIndex == i,
                      selectedColor: color.withAlpha(180),
                      onSelected: (_) => setState(() {
                        _selectedPlayerIndex = i;
                        _showYourSide = logicalId <= 2;
                      }),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Heatmap
                CourtHeatmapWidget(
                  fullHeatmap: selected.heatmap,
                  playerColor: _playerColors[
                      (selectedLogicalId - 1).clamp(0, 3)],
                  showYourSide: _showYourSide,
                  onSideChanged: (v) => setState(() => _showYourSide = v),
                ),
                const SizedBox(height: 20),

                // Summary 2×2 grid
                _StatGrid(
                  distance: selected.totalDistanceM,
                  coverage: selected.courtCoveragePct,
                  position: _inferPosition(selected.heatmap),
                ),
                const SizedBox(height: 24),

                // Distance comparison bars
                Text('Distance Comparison',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _DistanceBars(
                  players: players,
                  maxDistance: maxDistance,
                  selectedIndex: safeIndex,
                  playerColors: _playerColors,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final double distance;
  final double coverage;
  final String position;

  const _StatGrid({
    required this.distance,
    required this.coverage,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        _StatCell(label: 'Distance', value: '${distance.toStringAsFixed(0)} m'),
        _StatCell(label: 'Court Coverage', value: '${coverage.toStringAsFixed(1)}%'),
        _StatCell(label: 'Position', value: position),
        const _StatCell(label: 'Players', value: '—'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DistanceBars extends StatelessWidget {
  final List<PlayerAnalysis> players;
  final double maxDistance;
  final int selectedIndex;
  final List<Color> playerColors;

  const _DistanceBars({
    required this.players,
    required this.maxDistance,
    required this.selectedIndex,
    required this.playerColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(players.length, (i) {
        final p = players[i];
        final logicalId = _MatchAnalysisScreenState._logicalId(p.trackId);
        final color = playerColors[(logicalId - 1).clamp(0, 3)];
        final fraction =
            maxDistance > 0 ? p.totalDistanceM / maxDistance : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text('P$logicalId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: i == selectedIndex
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 16,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: color.withAlpha(i == selectedIndex ? 220 : 140),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(
                  '${p.totalDistanceM.toStringAsFixed(0)} m',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
