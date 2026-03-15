import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/match/domain/models/match_filter.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';

class MatchFilterSheet extends ConsumerWidget {
  const MatchFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(matchFilterProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.filterMatches,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (filter.isActive)
                TextButton(
                  onPressed: () => ref.read(matchFilterProvider.notifier).state =
                      MatchFilter.empty,
                  child: Text(l10n.clearFilters),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Result filter
          Text(l10n.result, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: [
              ButtonSegment(value: null, label: Text(l10n.allResults)),
              ButtonSegment(value: 'won', label: Text(l10n.won)),
              ButtonSegment(value: 'lost', label: Text(l10n.lost)),
            ],
            selected: {filter.result},
            onSelectionChanged: (v) => ref
                .read(matchFilterProvider.notifier)
                .state = filter.copyWith(result: () => v.first),
          ),
          const SizedBox(height: 16),

          // Match type filter
          Text(l10n.matchType, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: [
              ButtonSegment(value: null, label: Text(l10n.allTypes)),
              ButtonSegment(value: 'friendly', label: Text(l10n.friendly)),
              ButtonSegment(value: 'league', label: Text(l10n.league)),
              ButtonSegment(value: 'tournament', label: Text(l10n.tournament)),
            ],
            selected: {filter.matchType},
            onSelectionChanged: (v) => ref
                .read(matchFilterProvider.notifier)
                .state = filter.copyWith(matchType: () => v.first),
          ),
          const SizedBox(height: 16),

          // Surface filter
          Text(l10n.courtSurface, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: [
              ButtonSegment(value: null, label: Text(l10n.allSurfaces)),
              ButtonSegment(value: 'glass', label: Text(l10n.glass)),
              ButtonSegment(value: 'cement', label: Text(l10n.cement)),
              ButtonSegment(value: 'turf', label: Text(l10n.turf)),
            ],
            selected: {filter.courtSurface},
            onSelectionChanged: (v) => ref
                .read(matchFilterProvider.notifier)
                .state = filter.copyWith(courtSurface: () => v.first),
          ),
          const SizedBox(height: 16),

          // Date range
          Text(l10n.date, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: filter.dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      ref.read(matchFilterProvider.notifier).state =
                          filter.copyWith(dateFrom: () => picked);
                    }
                  },
                  child: Text(filter.dateFrom != null
                      ? '${filter.dateFrom!.day}/${filter.dateFrom!.month}/${filter.dateFrom!.year}'
                      : l10n.dateFrom),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: filter.dateTo ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      ref.read(matchFilterProvider.notifier).state =
                          filter.copyWith(dateTo: () => picked);
                    }
                  },
                  child: Text(filter.dateTo != null
                      ? '${filter.dateTo!.day}/${filter.dateTo!.month}/${filter.dateTo!.year}'
                      : l10n.dateTo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
