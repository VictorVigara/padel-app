import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/match/presentation/widgets/match_filter_sheet.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final won = match.winnerTeam == 1;
    final scoreStr = match.setScores.map((s) => s.toString()).join('  ');

    // Extract opponent names from notes (supports old + new format)
    String? opponent1;
    String? opponent2;
    if (match.notes != null) {
      for (final line in match.notes!.split('\n')) {
        if (line.startsWith('Opponent 1: ')) {
          opponent1 = line.substring('Opponent 1: '.length);
        } else if (line.startsWith('Opponent 2: ')) {
          opponent2 = line.substring('Opponent 2: '.length);
        } else if (line.startsWith('Opponent: ')) {
          opponent1 = line.substring('Opponent: '.length);
        } else if (line.startsWith("Opponent's partner: ")) {
          opponent2 = line.substring("Opponent's partner: ".length);
        }
      }
    }
    final opponentDisplay = [opponent1, opponent2]
        .where((n) => n != null && n.isNotEmpty)
        .join(' & ');
    final opponentName =
        opponentDisplay.isNotEmpty ? opponentDisplay : l10n.opponent;

    final dateStr =
        '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}';

    // ELO change for this match
    final ratingAsync =
        match.id != null ? ref.watch(ratingForMatchProvider(match.id!)) : null;
    final ratingChange = ratingAsync?.valueOrNull?.ratingChange;

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
              // Header row: result badge + opponent + ELO + date
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
                  if (ratingChange != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.vs} $opponentName',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
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
                  _chip(
                      Icons.sports, _formatMatchType(match.matchType, l10n)),
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
