// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnalysisResultImpl _$$AnalysisResultImplFromJson(Map<String, dynamic> json) =>
    _$AnalysisResultImpl(
      players: (json['players'] as List<dynamic>)
          .map((e) => PlayerAnalysis.fromJson(e as Map<String, dynamic>))
          .toList(),
      processingMeta: ProcessingMeta.fromJson(
        json['processing_meta'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$$AnalysisResultImplToJson(
  _$AnalysisResultImpl instance,
) => <String, dynamic>{
  'players': instance.players,
  'processing_meta': instance.processingMeta,
};

_$PlayerAnalysisImpl _$$PlayerAnalysisImplFromJson(Map<String, dynamic> json) =>
    _$PlayerAnalysisImpl(
      trackId: json['track_id'] as String,
      totalDistanceM: (json['total_distance_m'] as num).toDouble(),
      courtCoveragePct: (json['court_coverage_pct'] as num).toDouble(),
      heatmap: _heatmapFromJson(json['heatmap'] as List),
    );

Map<String, dynamic> _$$PlayerAnalysisImplToJson(
  _$PlayerAnalysisImpl instance,
) => <String, dynamic>{
  'track_id': instance.trackId,
  'total_distance_m': instance.totalDistanceM,
  'court_coverage_pct': instance.courtCoveragePct,
  'heatmap': instance.heatmap,
};

_$ProcessingMetaImpl _$$ProcessingMetaImplFromJson(Map<String, dynamic> json) =>
    _$ProcessingMetaImpl(
      durationS: (json['duration_s'] as num).toDouble(),
      framesProcessed: (json['frames_processed'] as num).toInt(),
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ProcessingMetaImplToJson(
  _$ProcessingMetaImpl instance,
) => <String, dynamic>{
  'duration_s': instance.durationS,
  'frames_processed': instance.framesProcessed,
  'warnings': instance.warnings,
};
