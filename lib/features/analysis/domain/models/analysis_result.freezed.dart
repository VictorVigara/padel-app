// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AnalysisResult _$AnalysisResultFromJson(Map<String, dynamic> json) {
  return _AnalysisResult.fromJson(json);
}

/// @nodoc
mixin _$AnalysisResult {
  List<PlayerAnalysis> get players => throw _privateConstructorUsedError;
  @JsonKey(name: 'processing_meta')
  ProcessingMeta get processingMeta => throw _privateConstructorUsedError;

  /// Serializes this AnalysisResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalysisResultCopyWith<AnalysisResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalysisResultCopyWith<$Res> {
  factory $AnalysisResultCopyWith(
    AnalysisResult value,
    $Res Function(AnalysisResult) then,
  ) = _$AnalysisResultCopyWithImpl<$Res, AnalysisResult>;
  @useResult
  $Res call({
    List<PlayerAnalysis> players,
    @JsonKey(name: 'processing_meta') ProcessingMeta processingMeta,
  });

  $ProcessingMetaCopyWith<$Res> get processingMeta;
}

/// @nodoc
class _$AnalysisResultCopyWithImpl<$Res, $Val extends AnalysisResult>
    implements $AnalysisResultCopyWith<$Res> {
  _$AnalysisResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? players = null, Object? processingMeta = null}) {
    return _then(
      _value.copyWith(
            players: null == players
                ? _value.players
                : players // ignore: cast_nullable_to_non_nullable
                      as List<PlayerAnalysis>,
            processingMeta: null == processingMeta
                ? _value.processingMeta
                : processingMeta // ignore: cast_nullable_to_non_nullable
                      as ProcessingMeta,
          )
          as $Val,
    );
  }

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProcessingMetaCopyWith<$Res> get processingMeta {
    return $ProcessingMetaCopyWith<$Res>(_value.processingMeta, (value) {
      return _then(_value.copyWith(processingMeta: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AnalysisResultImplCopyWith<$Res>
    implements $AnalysisResultCopyWith<$Res> {
  factory _$$AnalysisResultImplCopyWith(
    _$AnalysisResultImpl value,
    $Res Function(_$AnalysisResultImpl) then,
  ) = __$$AnalysisResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<PlayerAnalysis> players,
    @JsonKey(name: 'processing_meta') ProcessingMeta processingMeta,
  });

  @override
  $ProcessingMetaCopyWith<$Res> get processingMeta;
}

/// @nodoc
class __$$AnalysisResultImplCopyWithImpl<$Res>
    extends _$AnalysisResultCopyWithImpl<$Res, _$AnalysisResultImpl>
    implements _$$AnalysisResultImplCopyWith<$Res> {
  __$$AnalysisResultImplCopyWithImpl(
    _$AnalysisResultImpl _value,
    $Res Function(_$AnalysisResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? players = null, Object? processingMeta = null}) {
    return _then(
      _$AnalysisResultImpl(
        players: null == players
            ? _value._players
            : players // ignore: cast_nullable_to_non_nullable
                  as List<PlayerAnalysis>,
        processingMeta: null == processingMeta
            ? _value.processingMeta
            : processingMeta // ignore: cast_nullable_to_non_nullable
                  as ProcessingMeta,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalysisResultImpl implements _AnalysisResult {
  const _$AnalysisResultImpl({
    required final List<PlayerAnalysis> players,
    @JsonKey(name: 'processing_meta') required this.processingMeta,
  }) : _players = players;

  factory _$AnalysisResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalysisResultImplFromJson(json);

  final List<PlayerAnalysis> _players;
  @override
  List<PlayerAnalysis> get players {
    if (_players is EqualUnmodifiableListView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_players);
  }

  @override
  @JsonKey(name: 'processing_meta')
  final ProcessingMeta processingMeta;

  @override
  String toString() {
    return 'AnalysisResult(players: $players, processingMeta: $processingMeta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalysisResultImpl &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            (identical(other.processingMeta, processingMeta) ||
                other.processingMeta == processingMeta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_players),
    processingMeta,
  );

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalysisResultImplCopyWith<_$AnalysisResultImpl> get copyWith =>
      __$$AnalysisResultImplCopyWithImpl<_$AnalysisResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalysisResultImplToJson(this);
  }
}

abstract class _AnalysisResult implements AnalysisResult {
  const factory _AnalysisResult({
    required final List<PlayerAnalysis> players,
    @JsonKey(name: 'processing_meta')
    required final ProcessingMeta processingMeta,
  }) = _$AnalysisResultImpl;

  factory _AnalysisResult.fromJson(Map<String, dynamic> json) =
      _$AnalysisResultImpl.fromJson;

  @override
  List<PlayerAnalysis> get players;
  @override
  @JsonKey(name: 'processing_meta')
  ProcessingMeta get processingMeta;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalysisResultImplCopyWith<_$AnalysisResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayerAnalysis _$PlayerAnalysisFromJson(Map<String, dynamic> json) {
  return _PlayerAnalysis.fromJson(json);
}

/// @nodoc
mixin _$PlayerAnalysis {
  @JsonKey(name: 'track_id')
  String get trackId => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_distance_m')
  double get totalDistanceM => throw _privateConstructorUsedError;
  @JsonKey(name: 'court_coverage_pct')
  double get courtCoveragePct => throw _privateConstructorUsedError;
  @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
  List<List<double>> get heatmap => throw _privateConstructorUsedError;

  /// Serializes this PlayerAnalysis to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerAnalysisCopyWith<PlayerAnalysis> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerAnalysisCopyWith<$Res> {
  factory $PlayerAnalysisCopyWith(
    PlayerAnalysis value,
    $Res Function(PlayerAnalysis) then,
  ) = _$PlayerAnalysisCopyWithImpl<$Res, PlayerAnalysis>;
  @useResult
  $Res call({
    @JsonKey(name: 'track_id') String trackId,
    @JsonKey(name: 'total_distance_m') double totalDistanceM,
    @JsonKey(name: 'court_coverage_pct') double courtCoveragePct,
    @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
    List<List<double>> heatmap,
  });
}

/// @nodoc
class _$PlayerAnalysisCopyWithImpl<$Res, $Val extends PlayerAnalysis>
    implements $PlayerAnalysisCopyWith<$Res> {
  _$PlayerAnalysisCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackId = null,
    Object? totalDistanceM = null,
    Object? courtCoveragePct = null,
    Object? heatmap = null,
  }) {
    return _then(
      _value.copyWith(
            trackId: null == trackId
                ? _value.trackId
                : trackId // ignore: cast_nullable_to_non_nullable
                      as String,
            totalDistanceM: null == totalDistanceM
                ? _value.totalDistanceM
                : totalDistanceM // ignore: cast_nullable_to_non_nullable
                      as double,
            courtCoveragePct: null == courtCoveragePct
                ? _value.courtCoveragePct
                : courtCoveragePct // ignore: cast_nullable_to_non_nullable
                      as double,
            heatmap: null == heatmap
                ? _value.heatmap
                : heatmap // ignore: cast_nullable_to_non_nullable
                      as List<List<double>>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlayerAnalysisImplCopyWith<$Res>
    implements $PlayerAnalysisCopyWith<$Res> {
  factory _$$PlayerAnalysisImplCopyWith(
    _$PlayerAnalysisImpl value,
    $Res Function(_$PlayerAnalysisImpl) then,
  ) = __$$PlayerAnalysisImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'track_id') String trackId,
    @JsonKey(name: 'total_distance_m') double totalDistanceM,
    @JsonKey(name: 'court_coverage_pct') double courtCoveragePct,
    @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
    List<List<double>> heatmap,
  });
}

/// @nodoc
class __$$PlayerAnalysisImplCopyWithImpl<$Res>
    extends _$PlayerAnalysisCopyWithImpl<$Res, _$PlayerAnalysisImpl>
    implements _$$PlayerAnalysisImplCopyWith<$Res> {
  __$$PlayerAnalysisImplCopyWithImpl(
    _$PlayerAnalysisImpl _value,
    $Res Function(_$PlayerAnalysisImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlayerAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trackId = null,
    Object? totalDistanceM = null,
    Object? courtCoveragePct = null,
    Object? heatmap = null,
  }) {
    return _then(
      _$PlayerAnalysisImpl(
        trackId: null == trackId
            ? _value.trackId
            : trackId // ignore: cast_nullable_to_non_nullable
                  as String,
        totalDistanceM: null == totalDistanceM
            ? _value.totalDistanceM
            : totalDistanceM // ignore: cast_nullable_to_non_nullable
                  as double,
        courtCoveragePct: null == courtCoveragePct
            ? _value.courtCoveragePct
            : courtCoveragePct // ignore: cast_nullable_to_non_nullable
                  as double,
        heatmap: null == heatmap
            ? _value._heatmap
            : heatmap // ignore: cast_nullable_to_non_nullable
                  as List<List<double>>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerAnalysisImpl implements _PlayerAnalysis {
  const _$PlayerAnalysisImpl({
    @JsonKey(name: 'track_id') required this.trackId,
    @JsonKey(name: 'total_distance_m') required this.totalDistanceM,
    @JsonKey(name: 'court_coverage_pct') required this.courtCoveragePct,
    @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
    required final List<List<double>> heatmap,
  }) : _heatmap = heatmap;

  factory _$PlayerAnalysisImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerAnalysisImplFromJson(json);

  @override
  @JsonKey(name: 'track_id')
  final String trackId;
  @override
  @JsonKey(name: 'total_distance_m')
  final double totalDistanceM;
  @override
  @JsonKey(name: 'court_coverage_pct')
  final double courtCoveragePct;
  final List<List<double>> _heatmap;
  @override
  @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
  List<List<double>> get heatmap {
    if (_heatmap is EqualUnmodifiableListView) return _heatmap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_heatmap);
  }

  @override
  String toString() {
    return 'PlayerAnalysis(trackId: $trackId, totalDistanceM: $totalDistanceM, courtCoveragePct: $courtCoveragePct, heatmap: $heatmap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerAnalysisImpl &&
            (identical(other.trackId, trackId) || other.trackId == trackId) &&
            (identical(other.totalDistanceM, totalDistanceM) ||
                other.totalDistanceM == totalDistanceM) &&
            (identical(other.courtCoveragePct, courtCoveragePct) ||
                other.courtCoveragePct == courtCoveragePct) &&
            const DeepCollectionEquality().equals(other._heatmap, _heatmap));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    trackId,
    totalDistanceM,
    courtCoveragePct,
    const DeepCollectionEquality().hash(_heatmap),
  );

  /// Create a copy of PlayerAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerAnalysisImplCopyWith<_$PlayerAnalysisImpl> get copyWith =>
      __$$PlayerAnalysisImplCopyWithImpl<_$PlayerAnalysisImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerAnalysisImplToJson(this);
  }
}

abstract class _PlayerAnalysis implements PlayerAnalysis {
  const factory _PlayerAnalysis({
    @JsonKey(name: 'track_id') required final String trackId,
    @JsonKey(name: 'total_distance_m') required final double totalDistanceM,
    @JsonKey(name: 'court_coverage_pct') required final double courtCoveragePct,
    @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
    required final List<List<double>> heatmap,
  }) = _$PlayerAnalysisImpl;

  factory _PlayerAnalysis.fromJson(Map<String, dynamic> json) =
      _$PlayerAnalysisImpl.fromJson;

  @override
  @JsonKey(name: 'track_id')
  String get trackId;
  @override
  @JsonKey(name: 'total_distance_m')
  double get totalDistanceM;
  @override
  @JsonKey(name: 'court_coverage_pct')
  double get courtCoveragePct;
  @override
  @JsonKey(name: 'heatmap', fromJson: _heatmapFromJson)
  List<List<double>> get heatmap;

  /// Create a copy of PlayerAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerAnalysisImplCopyWith<_$PlayerAnalysisImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ProcessingMeta _$ProcessingMetaFromJson(Map<String, dynamic> json) {
  return _ProcessingMeta.fromJson(json);
}

/// @nodoc
mixin _$ProcessingMeta {
  @JsonKey(name: 'duration_s')
  double get durationS => throw _privateConstructorUsedError;
  @JsonKey(name: 'frames_processed')
  int get framesProcessed => throw _privateConstructorUsedError;
  List<String> get warnings => throw _privateConstructorUsedError;

  /// Serializes this ProcessingMeta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProcessingMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProcessingMetaCopyWith<ProcessingMeta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProcessingMetaCopyWith<$Res> {
  factory $ProcessingMetaCopyWith(
    ProcessingMeta value,
    $Res Function(ProcessingMeta) then,
  ) = _$ProcessingMetaCopyWithImpl<$Res, ProcessingMeta>;
  @useResult
  $Res call({
    @JsonKey(name: 'duration_s') double durationS,
    @JsonKey(name: 'frames_processed') int framesProcessed,
    List<String> warnings,
  });
}

/// @nodoc
class _$ProcessingMetaCopyWithImpl<$Res, $Val extends ProcessingMeta>
    implements $ProcessingMetaCopyWith<$Res> {
  _$ProcessingMetaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProcessingMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? durationS = null,
    Object? framesProcessed = null,
    Object? warnings = null,
  }) {
    return _then(
      _value.copyWith(
            durationS: null == durationS
                ? _value.durationS
                : durationS // ignore: cast_nullable_to_non_nullable
                      as double,
            framesProcessed: null == framesProcessed
                ? _value.framesProcessed
                : framesProcessed // ignore: cast_nullable_to_non_nullable
                      as int,
            warnings: null == warnings
                ? _value.warnings
                : warnings // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProcessingMetaImplCopyWith<$Res>
    implements $ProcessingMetaCopyWith<$Res> {
  factory _$$ProcessingMetaImplCopyWith(
    _$ProcessingMetaImpl value,
    $Res Function(_$ProcessingMetaImpl) then,
  ) = __$$ProcessingMetaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'duration_s') double durationS,
    @JsonKey(name: 'frames_processed') int framesProcessed,
    List<String> warnings,
  });
}

/// @nodoc
class __$$ProcessingMetaImplCopyWithImpl<$Res>
    extends _$ProcessingMetaCopyWithImpl<$Res, _$ProcessingMetaImpl>
    implements _$$ProcessingMetaImplCopyWith<$Res> {
  __$$ProcessingMetaImplCopyWithImpl(
    _$ProcessingMetaImpl _value,
    $Res Function(_$ProcessingMetaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProcessingMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? durationS = null,
    Object? framesProcessed = null,
    Object? warnings = null,
  }) {
    return _then(
      _$ProcessingMetaImpl(
        durationS: null == durationS
            ? _value.durationS
            : durationS // ignore: cast_nullable_to_non_nullable
                  as double,
        framesProcessed: null == framesProcessed
            ? _value.framesProcessed
            : framesProcessed // ignore: cast_nullable_to_non_nullable
                  as int,
        warnings: null == warnings
            ? _value._warnings
            : warnings // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProcessingMetaImpl implements _ProcessingMeta {
  const _$ProcessingMetaImpl({
    @JsonKey(name: 'duration_s') required this.durationS,
    @JsonKey(name: 'frames_processed') required this.framesProcessed,
    final List<String> warnings = const [],
  }) : _warnings = warnings;

  factory _$ProcessingMetaImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProcessingMetaImplFromJson(json);

  @override
  @JsonKey(name: 'duration_s')
  final double durationS;
  @override
  @JsonKey(name: 'frames_processed')
  final int framesProcessed;
  final List<String> _warnings;
  @override
  @JsonKey()
  List<String> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  @override
  String toString() {
    return 'ProcessingMeta(durationS: $durationS, framesProcessed: $framesProcessed, warnings: $warnings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProcessingMetaImpl &&
            (identical(other.durationS, durationS) ||
                other.durationS == durationS) &&
            (identical(other.framesProcessed, framesProcessed) ||
                other.framesProcessed == framesProcessed) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    durationS,
    framesProcessed,
    const DeepCollectionEquality().hash(_warnings),
  );

  /// Create a copy of ProcessingMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProcessingMetaImplCopyWith<_$ProcessingMetaImpl> get copyWith =>
      __$$ProcessingMetaImplCopyWithImpl<_$ProcessingMetaImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProcessingMetaImplToJson(this);
  }
}

abstract class _ProcessingMeta implements ProcessingMeta {
  const factory _ProcessingMeta({
    @JsonKey(name: 'duration_s') required final double durationS,
    @JsonKey(name: 'frames_processed') required final int framesProcessed,
    final List<String> warnings,
  }) = _$ProcessingMetaImpl;

  factory _ProcessingMeta.fromJson(Map<String, dynamic> json) =
      _$ProcessingMetaImpl.fromJson;

  @override
  @JsonKey(name: 'duration_s')
  double get durationS;
  @override
  @JsonKey(name: 'frames_processed')
  int get framesProcessed;
  @override
  List<String> get warnings;

  /// Create a copy of ProcessingMeta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProcessingMetaImplCopyWith<_$ProcessingMetaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
