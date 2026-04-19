import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/analysis/data/repositories/analysis_repository.dart';
import 'package:padel_app/features/analysis/domain/models/analysis_result.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository();
});

final analysisResultProvider = FutureProvider.autoDispose
    .family<AnalysisResult?, String>((ref, matchId) async {
  final repo = ref.watch(analysisRepositoryProvider);
  return repo.getAnalysis(matchId);
});
