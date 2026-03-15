import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';

/// Current search query for player search.
final playerSearchQueryProvider = StateProvider<String>((ref) => '');

/// Search results based on query. Only fires when query >= 2 chars.
final playerSearchResultsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(playerSearchQueryProvider);
  if (query.length < 2) return [];

  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.watch(profileRepositoryProvider);
  return repo.searchPlayers(query, user.id);
});

/// Cache of fetched profiles: id → profile map.
/// Used to display opponent names in match cards without repeated queries.
final profileCacheProvider =
    StateProvider<Map<String, Map<String, dynamic>>>((ref) => {});
