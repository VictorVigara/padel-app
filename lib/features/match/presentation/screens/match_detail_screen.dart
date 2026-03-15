import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class MatchDetailScreen extends ConsumerWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchAsync = ref.watch(matchDetailProvider(matchId));
    final statsAsync = ref.watch(matchStatsProvider(matchId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.edit,
            onPressed: () => context.push('/matches/$matchId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _confirmDelete(context, ref, l10n),
          ),
        ],
      ),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }
          final stats = statsAsync.valueOrNull ?? [];
          return _MatchDetailBody(match: match, stats: stats);
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(matchRepositoryProvider);
              await repo.deleteMatch(matchId);
              ref.invalidate(matchListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.matchDeleted)),
                );
                context.pop();
              }
            },
            child: Text(l10n.delete,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MatchDetailBody extends StatelessWidget {
  final PadelMatch match;
  final List<MatchStats> stats;

  const _MatchDetailBody({required this.match, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final won = match.winnerTeam == 1;
    final scoreStr = match.setScores.map((s) => s.toString()).join('  ');

    // Parse player info from notes (supports both old and new format)
    String? opponent1;
    String? opponent2;
    String? partnerName;
    String? userNotes;
    if (match.notes != null) {
      final noteLines = <String>[];
      for (final line in match.notes!.split('\n')) {
        if (line.startsWith('Opponent 1: ')) {
          opponent1 = line.substring('Opponent 1: '.length);
        } else if (line.startsWith('Opponent 2: ')) {
          opponent2 = line.substring('Opponent 2: '.length);
        } else if (line.startsWith('Opponent: ')) {
          opponent1 = line.substring('Opponent: '.length);
        } else if (line.startsWith('Partner: ')) {
          partnerName = line.substring('Partner: '.length);
        } else if (line.startsWith("Opponent's partner: ")) {
          opponent2 = line.substring("Opponent's partner: ".length);
        } else {
          noteLines.add(line);
        }
      }
      if (noteLines.isNotEmpty) userNotes = noteLines.join('\n');
    }

    final dateStr =
        '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}';
    final isDoubles =
        match.team1Player2Id != null || match.team2Player2Id != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: (won ? AppColors.win : AppColors.loss).withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (won ? AppColors.win : AppColors.loss).withAlpha(100),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.sports_tennis,
                  size: 40,
                  color: won ? AppColors.win : AppColors.loss,
                ),
                const SizedBox(height: 8),
                Text(
                  won ? l10n.won : l10n.lost,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: won ? AppColors.win : AppColors.loss,
                      ),
                ),
                if (scoreStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    scoreStr,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Players
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isDoubles ? l10n.doubles : l10n.singles,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          )),
                  const Divider(),
                  if (opponent1 != null)
                    _infoRow(isDoubles ? l10n.opponent1 : l10n.opponent, opponent1),
                  if (opponent2 != null)
                    _infoRow(l10n.opponent2, opponent2),
                  if (partnerName != null)
                    _infoRow(l10n.partner, partnerName),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Match info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(l10n.date, dateStr),
                  if (match.location != null)
                    _infoRow(l10n.location, match.location!),
                  _infoRow(l10n.matchType,
                      _formatMatchType(match.matchType, l10n)),
                  _infoRow(l10n.matchFormat,
                      _formatMatchFormat(match.matchFormat, l10n)),
                  _infoRow(l10n.courtSurface,
                      _formatSurface(match.courtSurface, l10n)),
                ],
              ),
            ),
          ),

          // Stats section
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStatsCard(context, l10n, stats.first),
          ],

          // Notes
          if (userNotes != null && userNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.notes,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                )),
                    const SizedBox(height: 8),
                    Text(userNotes),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
      BuildContext context, AppLocalizations l10n, MatchStats s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.addStats,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
            const Divider(),
            // Serves
            if (s.firstServeTotal > 0) ...[
              _statRow(l10n.serves,
                  '${s.firstServeIn}/${s.firstServeTotal} (${s.firstServePercentage.toStringAsFixed(0)}%)'),
            ],
            if (s.aces > 0) _statRow(l10n.aces, '${s.aces}'),
            if (s.doubleFaults > 0)
              _statRow(l10n.doubleFaults, '${s.doubleFaults}'),
            // Shots
            if (s.winners > 0) _statRow(l10n.winners, '${s.winners}'),
            if (s.unforcedErrors > 0)
              _statRow(l10n.unforcedErrors, '${s.unforcedErrors}'),
            // Padel shots
            if (s.bandejaWinners > 0)
              _statRow(l10n.bandeja, '${s.bandejaWinners}'),
            if (s.viboraWinners > 0)
              _statRow(l10n.vibora, '${s.viboraWinners}'),
            if (s.smashWinners > 0)
              _statRow(l10n.smash, '${s.smashWinners}'),
            if (s.lobWinners > 0) _statRow(l10n.lob, '${s.lobWinners}'),
            if (s.volleyWinners > 0)
              _statRow(l10n.volley, '${s.volleyWinners}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatMatchType(String type, AppLocalizations l10n) {
    switch (type) {
      case 'friendly':
        return l10n.friendly;
      case 'league':
        return l10n.league;
      case 'tournament':
        return l10n.tournament;
      default:
        return type;
    }
  }

  String _formatMatchFormat(String format, AppLocalizations l10n) {
    switch (format) {
      case 'best_of_3':
        return l10n.bestOf3;
      case 'best_of_5':
        return l10n.bestOf5;
      case 'single_set':
        return l10n.singleSet;
      default:
        return format;
    }
  }

  String _formatSurface(String? surface, AppLocalizations l10n) {
    switch (surface) {
      case 'glass':
        return l10n.glass;
      case 'cement':
        return l10n.cement;
      case 'turf':
        return l10n.turf;
      default:
        return l10n.other;
    }
  }
}
