import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/match/presentation/widgets/match_filter_sheet.dart';
import 'package:padel_app/features/player_profile/presentation/providers/player_search_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/features/rating/presentation/providers/rating_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchesAsync = ref.watch(filteredMatchListProvider);
    final filter = ref.watch(matchFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Record a match',
            onPressed: () async {
              try {
                final matchId = await ref.read(createDraftMatchProvider)();
                if (context.mounted) context.push('/matches/$matchId/record');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not start recording: $e')),
                  );
                }
              }
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: l10n.filterMatches,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const MatchFilterSheet(),
                ),
              ),
              if (filter.isActive)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(matchListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return _buildEmptyState(context, l10n, filter.isActive);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: matches.length,
              itemBuilder: (context, i) => _MatchCard(
                match: matches[i],
                onTap: () => context.push('/matches/${matches[i].id}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/matches/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newMatch),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, AppLocalizations l10n, bool hasFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off : Icons.sports_tennis,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? l10n.noMatchesFilter : l10n.noMatches,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  final PadelMatch match;
  final VoidCallback? onTap;

  const _MatchCard({required this.match, this.onTap});

  /// Parse notes for fallback player names (written from creator's perspective).
  static ({String? opponent1, String? opponent2, String? partner})
      _parseNotes(String? notes) {
    String? opp1, opp2, partner;
    if (notes == null) return (opponent1: opp1, opponent2: opp2, partner: partner);
    for (final line in notes.split('\n')) {
      if (line.startsWith('Opponent 1: ')) {
        opp1 = line.substring('Opponent 1: '.length);
      } else if (line.startsWith('Opponent 2: ')) {
        opp2 = line.substring('Opponent 2: '.length);
      } else if (line.startsWith('Opponent: ')) {
        opp1 = line.substring('Opponent: '.length);
      } else if (line.startsWith("Opponent's partner: ")) {
        opp2 = line.substring("Opponent's partner: ".length);
      } else if (line.startsWith('Partner: ')) {
        partner = line.substring('Partner: '.length);
      }
    }
    return (opponent1: opp1, opponent2: opp2, partner: partner);
  }

  /// Resolve a player's display name.
  /// Priority: "You" > profile cache > notes fallback > "Player".
  String _resolvePlayerName({
    required String playerId,
    required String? currentUserId,
    required Map<String, Map<String, dynamic>> profileCache,
    required WidgetRef ref,
    required AppLocalizations l10n,
    String? noteFallback,
  }) {
    if (playerId.isEmpty) return noteFallback ?? l10n.player;
    if (playerId == currentUserId) return l10n.you;
    // Try profile cache
    final cached = profileCache[playerId]?['display_name'] as String?;
    if (cached != null) return cached;
    // Trigger async fetch
    _fetchProfileIfNeeded(ref, playerId);
    // Use notes fallback or generic label
    return noteFallback ?? l10n.player;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserProvider)?.id;
    final profileCache = ref.watch(profileCacheProvider);

    // Determine which team the current user is on
    final userOnTeam1 = userId == match.team1Player1Id ||
        userId == match.team1Player2Id;
    final myTeam = userOnTeam1 ? 1 : 2;
    final won = match.winnerTeam == myTeam;

    final scoreStr = match.setScores.map((s) => s.toString()).join('  ');

    // Notes are from creator's perspective (creator = team1)
    final notes = _parseNotes(match.notes);

    // Helper: check if a player ID is a real linked player (not fallback to creator)
    bool isRealPlayer(String? id) =>
        id != null && id != match.createdBy;

    // Resolve all player names
    final team1P1Name = _resolvePlayerName(
      playerId: match.team1Player1Id ?? '',
      currentUserId: userId,
      profileCache: profileCache,
      ref: ref,
      l10n: l10n,
      noteFallback: null, // team1Player1 is always the creator
    );

    String? team1P2Name;
    if (match.team1Player2Id != null && isRealPlayer(match.team1Player2Id)) {
      team1P2Name = _resolvePlayerName(
        playerId: match.team1Player2Id!,
        currentUserId: userId,
        profileCache: profileCache,
        ref: ref,
        l10n: l10n,
        noteFallback: notes.partner,
      );
    } else if (notes.partner != null) {
      team1P2Name = notes.partner;
    }

    // team2Player1Id may be creator's ID if opponent wasn't linked from search
    String team2P1Name;
    if (isRealPlayer(match.team2Player1Id)) {
      team2P1Name = _resolvePlayerName(
        playerId: match.team2Player1Id ?? '',
        currentUserId: userId,
        profileCache: profileCache,
        ref: ref,
        l10n: l10n,
        noteFallback: notes.opponent1,
      );
    } else {
      team2P1Name = notes.opponent1 ?? l10n.player;
    }

    String? team2P2Name;
    if (match.team2Player2Id != null && isRealPlayer(match.team2Player2Id)) {
      team2P2Name = _resolvePlayerName(
        playerId: match.team2Player2Id!,
        currentUserId: userId,
        profileCache: profileCache,
        ref: ref,
        l10n: l10n,
        noteFallback: notes.opponent2,
      );
    } else if (notes.opponent2 != null) {
      team2P2Name = notes.opponent2;
    }

    final team1Display = [team1P1Name, team1P2Name]
        .where((n) => n != null)
        .join(' & ');
    final team2Display = [team2P1Name, team2P2Name]
        .where((n) => n != null)
        .join(' & ');

    final dateStr =
        '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}';

    // ELO change for this match
    final ratingAsync =
        match.id != null ? ref.watch(ratingForMatchProvider(match.id!)) : null;
    final ratingChange = ratingAsync?.valueOrNull?.ratingChange;

    // Determine tappable player IDs for navigation
    String? tappableId(String playerId) {
      if (playerId == userId) return null;
      if (playerId == match.createdBy) return playerId;
      if (playerId != userId) return playerId;
      return null;
    }

    final team1P1Tap = match.team1Player1Id != null ? tappableId(match.team1Player1Id!) : null;
    final team2P1Tap = match.team2Player1Id != null ? tappableId(match.team2Player1Id!) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: result badge + ELO change + date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: won ? AppColors.win : AppColors.loss,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      won ? l10n.won : l10n.lost,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (match.id != null) ...[
                    _AnalysisBadge(matchId: match.id!),
                    const SizedBox(width: 4),
                  ],
                  if (ratingChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (ratingChange >= 0
                                ? AppColors.win
                                : AppColors.loss)
                            .withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ratingChange >= 0
                            ? '+${ratingChange.toStringAsFixed(0)}'
                            : ratingChange.toStringAsFixed(0),
                        style: TextStyle(
                          color: ratingChange >= 0
                              ? AppColors.win
                              : AppColors.loss,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Team 1 row
              _buildTeamRow(
                context: context,
                label: userOnTeam1 ? l10n.team1 : l10n.team2,
                names: team1Display,
                isUserTeam: userOnTeam1,
                isWinner: match.winnerTeam == 1,
                tappablePlayerId: team1P1Tap,
              ),
              const SizedBox(height: 4),
              // Team 2 row
              _buildTeamRow(
                context: context,
                label: userOnTeam1 ? l10n.team2 : l10n.team1,
                names: team2Display,
                isUserTeam: !userOnTeam1,
                isWinner: match.winnerTeam == 2,
                tappablePlayerId: team2P1Tap,
              ),
              if (scoreStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scoreStr,
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                ),
              ],
              const SizedBox(height: 4),
              // Info chips
              Wrap(
                spacing: 8,
                children: [
                  if (match.location != null)
                    _chip(Icons.location_on_outlined, match.location!),
                  if (match.matchType != null)
                    _chip(Icons.sports, _formatMatchType(match.matchType!, l10n)),
                  _chip(Icons.grass,
                      _formatSurface(match.courtSurface, l10n)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow({
    required BuildContext context,
    required String label,
    required String names,
    required bool isUserTeam,
    required bool isWinner,
    String? tappablePlayerId,
  }) {
    return Row(
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.emoji_events, size: 14, color: AppColors.secondary),
          ),
        if (!isWinner) const SizedBox(width: 18),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              fontWeight: isUserTeam ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: tappablePlayerId != null
                ? () => context.push('/players/$tappablePlayerId')
                : null,
            child: Text(
              names,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isUserTeam ? FontWeight.bold : FontWeight.normal,
                    decoration: tappablePlayerId != null
                        ? TextDecoration.underline
                        : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  /// Fetch a profile and add to cache if not already present.
  void _fetchProfileIfNeeded(WidgetRef ref, String playerId) {
    if (playerId.isEmpty) return;
    final cache = ref.read(profileCacheProvider);
    if (cache.containsKey(playerId)) return;
    final repo = ref.read(profileRepositoryProvider);
    repo.getProfile(playerId).then((profile) {
      if (profile != null) {
        ref.read(profileCacheProvider.notifier).update(
              (state) => {...state, playerId: profile},
            );
      }
    });
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Badge showing the latest analysis job status for a single match.
///
/// Renders nothing if no job has been submitted. Auto-refreshes every 30s
/// while the job is queued or processing (driven by analysisStatusProvider).
class _AnalysisBadge extends ConsumerWidget {
  final String matchId;

  const _AnalysisBadge({required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(analysisStatusProvider(matchId));
    return jobAsync.maybeWhen(
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        return switch (info.status) {
          AnalysisStatus.queued || AnalysisStatus.processing => _badge(
              'Analysing…',
              AppColors.secondary,
              Icons.sync,
            ),
          AnalysisStatus.done => _badge(
              'Analysis ready',
              AppColors.win,
              Icons.check_circle_outline,
            ),
          AnalysisStatus.failed => GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Re-upload to retry — coming soon'),
                  ),
                );
              },
              child: _badge(
                'Analysis failed',
                AppColors.error,
                Icons.refresh,
              ),
            ),
        };
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
