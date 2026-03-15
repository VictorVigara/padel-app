class MatchFilter {
  final String? result; // 'won', 'lost', or null (all)
  final String? matchType; // 'friendly', 'league', 'tournament', or null
  final String? courtSurface; // 'glass', 'cement', 'turf', 'other', or null
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const MatchFilter({
    this.result,
    this.matchType,
    this.courtSurface,
    this.dateFrom,
    this.dateTo,
  });

  bool get isActive =>
      result != null ||
      matchType != null ||
      courtSurface != null ||
      dateFrom != null ||
      dateTo != null;

  MatchFilter copyWith({
    String? Function()? result,
    String? Function()? matchType,
    String? Function()? courtSurface,
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
  }) {
    return MatchFilter(
      result: result != null ? result() : this.result,
      matchType: matchType != null ? matchType() : this.matchType,
      courtSurface: courtSurface != null ? courtSurface() : this.courtSurface,
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
    );
  }

  static const empty = MatchFilter();
}
