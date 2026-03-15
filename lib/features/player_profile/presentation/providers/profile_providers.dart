import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/player_profile/data/repositories/profile_repository.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile(user.id);
});

final currentRatingProvider = FutureProvider.autoDispose<double>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 1200.0;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getCurrentRating(user.id);
});
