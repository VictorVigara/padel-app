import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/rating/data/repositories/rating_repository.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository();
});

/// All rating records for the current user (oldest first, for charting).
final ratingHistoryProvider =
    FutureProvider.autoDispose<List<RatingRecord>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(ratingRepositoryProvider);
  return repo.getRatingHistory(user.id);
});

/// Rating record associated with a specific match, or null.
final ratingForMatchProvider = FutureProvider.autoDispose
    .family<RatingRecord?, String>((ref, matchId) async {
  final history = await ref.watch(ratingHistoryProvider.future);
  try {
    return history.firstWhere((r) => r.matchId == matchId);
  } catch (_) {
    return null;
  }
});
