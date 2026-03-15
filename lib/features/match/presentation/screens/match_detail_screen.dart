import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/player_search_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class MatchDetailScreen extends ConsumerWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchAsync = ref.watch(matchDetailProvider(matchId));
    final statsAsync = ref.watch(matchStatsProvider(matchId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return matchAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.matchDetails)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.matchDetails)),
        body: Center(child: Text('Error: $e')),
      ),
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.matchDetails)),
            body: const Center(child: Text('Match not found')),
          );
        }
        final isCreator = currentUserId == match.createdBy;
        final stats = statsAsync.valueOrNull ?? [];
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.matchDetails),
            actions: [
              if (isCreator) ...[
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
            ],
          ),
          body: _MatchDetailBody(
            match: match,
            stats: stats,
            currentUserId: currentUserId,
          ),
        );
      },
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

class _MatchDetailBody extends ConsumerWidget {
  final PadelMatch match;
  final List<MatchStats> stats;
  final String? currentUserId;

  const _MatchDetailBody({
    required this.match,
    required this.stats,
    required this.currentUserId,
  });

  /// Resolve a player's display name from profile cache.
  String _resolvePlayerName({
    required String playerId,
    required String? currentUserId,
    required Map<String, Map<String, dynamic>> profileCache,
    required WidgetRef ref,
    required AppLocalizations l10n,
    String? noteFallback,
  }) {
    if (playerId == currentUserId) return l10n.you;
    final cached = profileCache[playerId]?['display_name'] as String?;
    if (cached != null) return cached;
    // Trigger async fetch
    final cache = ref.read(profileCacheProvider);
    if (!cache.containsKey(playerId)) {
      final repo = ref.read(profileRepositoryProvider);
      repo.getProfile(playerId).then((profile) {
        if (profile != null) {
          ref.read(profileCacheProvider.notifier).update(
                (state) => {...state, playerId: profile},
              );
        }
      });
    }
    return noteFallback ?? l10n.player;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileCache = ref.watch(profileCacheProvider);

    // Determine viewer's team
    final userOnTeam1 = currentUserId == match.team1Player1Id ||
        currentUserId == match.team1Player2Id;

    // Perspective-aware result
    final won = userOnTeam1
        ? match.winnerTeam == 1
        : match.winnerTeam == 2;

    // Perspective-aware scores: swap if viewer is on team 2
    final displayScores = userOnTeam1
        ? match.setScores
        : match.setScores
            .map((s) => SetScore(
                  team1Games: s.team2Games,
                  team2Games: s.team1Games,
                ))
            .toList();
    final scoreStr = displayScores.map((s) => s.toString()).join('  ');

    // Parse notes (always from creator's/team1's perspective)
    String? noteOpp1, noteOpp2, notePartner;
    String? userNotes;
    if (match.notes != null) {
      final noteLines = <String>[];
      for (final line in match.notes!.split('\n')) {
        if (line.startsWith('Opponent 1: ')) {
          noteOpp1 = line.substring('Opponent 1: '.length);
        } else if (line.startsWith('Opponent 2: ')) {
          noteOpp2 = line.substring('Opponent 2: '.length);
        } else if (line.startsWith('Opponent: ')) {
          noteOpp1 = line.substring('Opponent: '.length);
        } else if (line.startsWith('Partner: ')) {
          notePartner = line.substring('Partner: '.length);
        } else if (line.startsWith("Opponent's partner: ")) {
          noteOpp2 = line.substring("Opponent's partner: ".length);
        } else {
          noteLines.add(line);
        }
      }
      if (noteLines.isNotEmpty) userNotes = noteLines.join('\n');
    }

    // Resolve player names based on perspective
    String? opponent1Name, opponent2Name, partnerName;

    // Helper: check if a player ID is a real linked player (not a fallback to creator)
    bool isRealPlayer(String? id) =>
        id != null && id != match.createdBy;

    if (userOnTeam1) {
      // Creator's perspective — opponents are team 2, use notes as fallback
      // team2Player1Id might be creator's own ID if opponent wasn't linked
      if (isRealPlayer(match.team2Player1Id)) {
        opponent1Name = _resolvePlayerName(
          playerId: match.team2Player1Id,
          currentUserId: currentUserId,
          profileCache: profileCache,
          ref: ref,
          l10n: l10n,
          noteFallback: noteOpp1,
        );
      } else {
        opponent1Name = noteOpp1 ?? l10n.player;
      }
      if (match.team2Player2Id != null && isRealPlayer(match.team2Player2Id)) {
        opponent2Name = _resolvePlayerName(
          playerId: match.team2Player2Id!,
          currentUserId: currentUserId,
          profileCache: profileCache,
          ref: ref,
          l10n: l10n,
          noteFallback: noteOpp2,
        );
      } else if (noteOpp2 != null) {
        opponent2Name = noteOpp2;
      }
      if (match.team1Player2Id != null && isRealPlayer(match.team1Player2Id)) {
        partnerName = _resolvePlayerName(
          playerId: match.team1Player2Id!,
          currentUserId: currentUserId,
          profileCache: profileCache,
          ref: ref,
          l10n: l10n,
          noteFallback: notePartner,
        );
      } else if (notePartner != null) {
        partnerName = notePartner;
      }
    } else {
      // Viewer is on team 2 — opponents are team 1 players
      opponent1Name = _resolvePlayerName(
        playerId: match.team1Player1Id,
        currentUserId: currentUserId,
        profileCache: profileCache,
        ref: ref,
        l10n: l10n,
        noteFallback: null,
      );
      if (match.team1Player2Id != null && isRealPlayer(match.team1Player2Id)) {
        opponent2Name = _resolvePlayerName(
          playerId: match.team1Player2Id!,
          currentUserId: currentUserId,
          profileCache: profileCache,
          ref: ref,
          l10n: l10n,
          noteFallback: notePartner, // creator's partner = viewer's opponent 2
        );
      } else if (notePartner != null) {
        opponent2Name = notePartner;
      }

      // Partner is the OTHER team 2 player (not the viewer).
      // Viewer could be team2Player1 or team2Player2.
      final viewerIsT2P1 = currentUserId == match.team2Player1Id;
      final partnerId = viewerIsT2P1
          ? match.team2Player2Id
          : match.team2Player1Id;
      // Note mapping: noteOpp1 = team2Player1 name, noteOpp2 = team2Player2 name
      final partnerNoteFallback = viewerIsT2P1 ? noteOpp2 : noteOpp1;

      if (partnerId != null && isRealPlayer(partnerId)) {
        partnerName = _resolvePlayerName(
          playerId: partnerId,
          currentUserId: currentUserId,
          profileCache: profileCache,
          ref: ref,
          l10n: l10n,
          noteFallback: partnerNoteFallback,
        );
      } else if (partnerNoteFallback != null) {
        partnerName = partnerNoteFallback;
      }
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
                  _infoRow(isDoubles ? l10n.opponent1 : l10n.opponent, opponent1Name),
                  if (opponent2Name != null)
                    _infoRow(l10n.opponent2, opponent2Name),
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
