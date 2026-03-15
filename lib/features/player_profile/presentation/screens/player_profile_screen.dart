import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';
import 'package:padel_app/features/rating/presentation/providers/rating_providers.dart';
import 'package:padel_app/features/rating/presentation/widgets/rating_chart.dart';
import 'package:padel_app/core/theme/app_theme.dart';

/// Provider to fetch a specific player's profile by ID.
final playerProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, playerId) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile(playerId);
});

/// Provider to fetch a specific player's rating.
final playerRatingProvider =
    FutureProvider.autoDispose.family<double, String>((ref, playerId) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getCurrentRating(playerId);
});

/// Provider to fetch a specific player's rating history.
final playerRatingHistoryProvider = FutureProvider.autoDispose
    .family<List<RatingRecord>, String>((ref, playerId) async {
  final repo = ref.watch(ratingRepositoryProvider);
  return repo.getRatingHistory(playerId);
});

/// Read-only profile view for another player.
class PlayerProfileScreen extends ConsumerWidget {
  final String playerId;

  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(playerProfileProvider(playerId));
    final ratingAsync = ref.watch(playerRatingProvider(playerId));
    final historyAsync = ref.watch(playerRatingHistoryProvider(playerId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerProfile)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Player not found'));
          }
          final name = profile['display_name'] as String? ?? 'Player';
          final rating = ratingAsync.valueOrNull ?? 1200.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.rating}: ${rating.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.secondary,
                      ),
                ),
                const SizedBox(height: 24),
                // Rating history chart
                historyAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (history) {
                    if (history.length < 2) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.playMoreMatches,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ratingHistory,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            RatingChart(history: history),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildInfoCard(context, [
                  _infoRow('Level',
                      _capitalize(profile['level'] as String? ?? 'beginner')),
                  _infoRow(
                      'Position',
                      _capitalize(
                          profile['preferred_position'] as String? ?? 'both')),
                  _infoRow('Handedness',
                      _capitalize(profile['handedness'] as String? ?? 'right')),
                ]),
                const SizedBox(height: 16),
                // Head-to-head button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/players/$playerId/h2h'),
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(l10n.headToHead),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: rows),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
