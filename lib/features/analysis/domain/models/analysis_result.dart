import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_result.freezed.dart';
part 'analysis_result.g.dart';

@freezed
class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    required List<PlayerAnalysis> players,
    @JsonKey(name: 'processing_meta') required ProcessingMeta processingMeta,
  }) = _AnalysisResult;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultFromJson(json);
}

@freezed
class PlayerAnalysis with _$PlayerAnalysis {
  const factory PlayerAnalysis({
    @JsonKey(name: 'track_id') required String trackId,
    @JsonKey(name: 'total_distance_m') required double totalDistanceM,
    @JsonKey(name: 'court_coverage_pct') required double courtCoveragePct,
    @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
    required List<List<double>> heatmap,
  }) = _PlayerAnalysis;

  factory PlayerAnalysis.fromJson(Map<String, dynamic> json) =>
      _$PlayerAnalysisFromJson(json);
}

@freezed
class ProcessingMeta with _$ProcessingMeta {
  const factory ProcessingMeta({
    @JsonKey(name: 'duration_s') required double durationS,
    @JsonKey(name: 'frames_processed') required int framesProcessed,
    @Default([]) List<String> warnings,
  }) = _ProcessingMeta;

  factory ProcessingMeta.fromJson(Map<String, dynamic> json) =>
      _$ProcessingMetaFromJson(json);
}

// Custom converter for nested List<List<double>>
List<List<double>> _heatmapFromJson(List<dynamic> json) => json
    .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
    .toList();
