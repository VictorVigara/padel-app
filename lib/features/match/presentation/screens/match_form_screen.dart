import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/features/player_profile/presentation/widgets/player_search_field.dart';
import 'package:padel_app/features/rating/domain/services/rating_service.dart';
import 'package:padel_app/features/rating/presentation/providers/rating_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

/// Match form for creating or editing a match.
/// Pass [matchId] to edit an existing match.
class MatchFormScreen extends ConsumerStatefulWidget {
  final String? matchId;

  const MatchFormScreen({super.key, this.matchId});

  @override
  ConsumerState<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends ConsumerState<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;
  bool _isCreator = true;

  // Match info
  DateTime _matchDate = DateTime.now();
  final _locationController = TextEditingController();
  String _courtSurface = 'glass';
  String _matchType = 'friendly';
  String _matchFormat = 'best_of_3';
  bool _isDoubles = true;
  bool _won = true;

  // Player tracking: name + optional profile ID for registered players
  String _opponent1Name = '';
  String? _opponent1Id;
  String _opponent2Name = '';
  String? _opponent2Id;
  String _partnerName = '';
  String? _partnerId;
  final _notesController = TextEditingController();

  // Set scores
  List<SetScore> _sets = [const SetScore(team1Games: 0, team2Games: 0)];

  // Stats
  bool _showStats = false;
  int _firstServeIn = 0;
  int _firstServeTotal = 0;
  int _aces = 0;
  int _doubleFaults = 0;
  int _winners = 0;
  int _unforcedErrors = 0;
  int _bandejaWinners = 0;
  int _viboraWinners = 0;
  int _smashWinners = 0;
  int _lobWinners = 0;
  int _volleyWinners = 0;
  String? _existingStatsId;

  bool get _isEditing => widget.matchId != null;

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _maxSets {
    switch (_matchFormat) {
      case 'best_of_3':
        return 3;
      case 'best_of_5':
        return 5;
      case 'single_set':
        return 1;
      default:
        return 3;
    }
  }

  void _loadMatch(PadelMatch match, List<MatchStats> stats) {
    if (_initialized) return;
    _initialized = true;

    final currentUserId = ref.read(currentUserProvider)?.id;
    _isCreator = currentUserId == match.createdBy;

    // Determine if the current user is on team 1 or team 2
    final userOnTeam1 = currentUserId == match.team1Player1Id ||
        currentUserId == match.team1Player2Id;

    _matchDate = match.matchDate;
    _locationController.text = match.location ?? '';
    _courtSurface = match.courtSurface ?? 'glass';
    _matchType = match.matchType;
    _matchFormat = match.matchFormat;
    _isDoubles =
        match.team1Player2Id != null || match.team2Player2Id != null;

    // Parse names from notes (always from creator's perspective)
    String? noteOpp1, noteOpp2, notePartner;
    final noteLines = <String>[];
    if (match.notes != null) {
      for (final line in match.notes!.split('\n')) {
        if (line.startsWith('Opponent 1: ')) {
          noteOpp1 = line.substring('Opponent 1: '.length);
        } else if (line.startsWith('Opponent 2: ')) {
          noteOpp2 = line.substring('Opponent 2: '.length);
        } else if (line.startsWith('Opponent: ')) {
          noteOpp1 = line.substring('Opponent: '.length);
        } else if (line.startsWith('Partner: ')) {
          notePartner = line.substring('Partner: '.length);
        } else if (line.startsWith("Opponent's partner: ")) {
          noteOpp2 = line.substring("Opponent's partner: ".length);
        } else {
          noteLines.add(line);
        }
      }
    }
    _notesController.text = noteLines.join('\n');

    if (userOnTeam1) {
      // Creator's perspective — use notes directly
      _won = match.winnerTeam == 1;
      _sets = match.setScores.isNotEmpty
          ? List.of(match.setScores)
          : [const SetScore(team1Games: 0, team2Games: 0)];

      _opponent1Name = noteOpp1 ?? '';
      _opponent2Name = noteOpp2 ?? '';
      _partnerName = notePartner ?? '';

      if (match.team2Player1Id != match.createdBy) {
        _opponent1Id = match.team2Player1Id;
      }
      if (match.team2Player2Id != null &&
          match.team2Player2Id != match.createdBy) {
        _opponent2Id = match.team2Player2Id;
      }
      if (match.team1Player2Id != null &&
          match.team1Player2Id != match.createdBy) {
        _partnerId = match.team1Player2Id;
      }
    } else {
      // Viewer is on team 2 — swap perspective
      _won = match.winnerTeam == 2;
      // Swap set scores so "Your Team" column shows team 2 games
      _sets = match.setScores.isNotEmpty
          ? match.setScores
              .map((s) => SetScore(
                    team1Games: s.team2Games,
                    team2Games: s.team1Games,
                  ))
              .toList()
          : [const SetScore(team1Games: 0, team2Games: 0)];

      // Opponents are team 1 players (the creator's team)
      _opponent1Id = match.team1Player1Id;
      if (match.team1Player2Id != null) {
        _opponent2Id = match.team1Player2Id;
      }

      // Partner is the OTHER team 2 player (not the viewer).
      final viewerIsT2P1 = currentUserId == match.team2Player1Id;
      final partnerId = viewerIsT2P1
          ? match.team2Player2Id
          : match.team2Player1Id;
      if (partnerId != null && partnerId != match.createdBy) {
        _partnerId = partnerId;
      }
      // Note fallback for partner: noteOpp1=team2Player1, noteOpp2=team2Player2
      final partnerNoteFallback = viewerIsT2P1 ? noteOpp2 : noteOpp1;

      // Fetch names — use profiles for linked players, notes for unlinked
      _opponent1Name = '';
      _opponent2Name = '';
      _partnerName = '';
      _fetchPlayerName(match.team1Player1Id, (name) {
        if (mounted) setState(() => _opponent1Name = name);
      });
      if (match.team1Player2Id != null) {
        if (match.team1Player2Id != match.createdBy) {
          _fetchPlayerName(match.team1Player2Id!, (name) {
            if (mounted) setState(() => _opponent2Name = name);
          });
        } else if (notePartner != null) {
          _opponent2Name = notePartner;
        }
      }
      if (_partnerId != null) {
        _fetchPlayerName(_partnerId!, (name) {
          if (mounted) setState(() => _partnerName = name);
        });
      } else if (partnerNoteFallback != null) {
        _partnerName = partnerNoteFallback;
      }
    }

    // Load stats if present
    if (stats.isNotEmpty) {
      final s = stats.first;
      _existingStatsId = s.id;
      _showStats = true;
      _firstServeIn = s.firstServeIn;
      _firstServeTotal = s.firstServeTotal;
      _aces = s.aces;
      _doubleFaults = s.doubleFaults;
      _winners = s.winners;
      _unforcedErrors = s.unforcedErrors;
      _bandejaWinners = s.bandejaWinners;
      _viboraWinners = s.viboraWinners;
      _smashWinners = s.smashWinners;
      _lobWinners = s.lobWinners;
      _volleyWinners = s.volleyWinners;
    }
  }

  /// Fetch a player's display name from their profile.
  void _fetchPlayerName(String playerId, void Function(String) onName) {
    final repo = ref.read(profileRepositoryProvider);
    repo.getProfile(playerId).then((profile) {
      if (profile != null) {
        final name = profile['display_name'] as String? ?? '';
        if (name.isNotEmpty) onName(name);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _matchDate = picked);
    }
  }

  Future<void> _saveMatch() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Build notes with player info (names stored as fallback display)
      final parts = <String>[];
      if (_opponent1Name.isNotEmpty) {
        parts.add('Opponent 1: $_opponent1Name');
      }
      if (_isDoubles && _opponent2Name.isNotEmpty) {
        parts.add('Opponent 2: $_opponent2Name');
      }
      if (_isDoubles && _partnerName.isNotEmpty) {
        parts.add('Partner: $_partnerName');
      }
      if (_notesController.text.isNotEmpty) {
        parts.add(_notesController.text.trim());
      }

      final match = PadelMatch(
        id: widget.matchId,
        createdBy: user.id,
        matchDate: _matchDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        courtSurface: _courtSurface,
        matchType: _matchType,
        matchFormat: _matchFormat,
        team1Player1Id: user.id,
        team1Player2Id: _isDoubles ? _partnerId : null,
        team2Player1Id: _opponent1Id ?? user.id,
        team2Player2Id: _isDoubles ? _opponent2Id : null,
        winnerTeam: _won ? 1 : 2,
        isCompleted: true,
        setScores: _sets,
        notes: parts.isEmpty ? null : parts.join('\n'),
      );

      MatchStats? stats;
      if (_showStats) {
        stats = MatchStats(
          id: _existingStatsId,
          matchId: widget.matchId ?? '',
          playerId: user.id,
          firstServeIn: _firstServeIn,
          firstServeTotal: _firstServeTotal,
          aces: _aces,
          doubleFaults: _doubleFaults,
          winners: _winners,
          unforcedErrors: _unforcedErrors,
          bandejaWinners: _bandejaWinners,
          viboraWinners: _viboraWinners,
          smashWinners: _smashWinners,
          lobWinners: _lobWinners,
          volleyWinners: _volleyWinners,
        );
      }

      final repo = ref.read(matchRepositoryProvider);
      if (_isEditing) {
        await repo.updateMatch(match, stats: stats);
      } else {
        final created = await repo.createMatch(match, stats: stats);
        // Calculate and save ELO rating for new matches
        final ratingService =
            RatingService(ref.read(ratingRepositoryProvider));
        await ratingService.calculateAndSaveRating(
          userId: user.id,
          match: created,
          opponentIds: [
            ?_opponent1Id,
            if (_isDoubles) ?_opponent2Id,
          ],
        );
        ref.invalidate(currentRatingProvider);
        ref.invalidate(ratingHistoryProvider);
      }

      if (mounted) {
        ref.invalidate(matchListProvider);
        if (_isEditing) {
          ref.invalidate(matchDetailProvider(widget.matchId!));
          ref.invalidate(matchStatsProvider(widget.matchId!));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.matchSaved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // If editing, load existing match data
    if (_isEditing && !_initialized) {
      final matchAsync = ref.watch(matchDetailProvider(widget.matchId!));
      final statsAsync = ref.watch(matchStatsProvider(widget.matchId!));

      return matchAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: Text(l10n.edit)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(l10n.edit)),
          body: Center(child: Text('Error: $e')),
        ),
        data: (match) {
          if (match == null) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.edit)),
              body: const Center(child: Text('Match not found')),
            );
          }
          final stats = statsAsync.valueOrNull ?? [];
          // Schedule loadMatch after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialized) {
              setState(() => _loadMatch(match, stats));
            }
          });
          return Scaffold(
            appBar: AppBar(title: Text(l10n.edit)),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (_isCreator ? l10n.edit : l10n.matchDetails)
            : l10n.newMatch),
      ),
      body: AbsorbPointer(
        absorbing: !_isCreator && _isEditing,
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Date ---
              _sectionTitle(l10n.date),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${_matchDate.day}/${_matchDate.month}/${_matchDate.year}',
                ),
              ),

              const SizedBox(height: 20),

              // --- Location ---
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: '${l10n.location} (${l10n.optional})',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // --- Singles/Doubles ---
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(l10n.doubles)),
                  ButtonSegment(value: false, label: Text(l10n.singles)),
                ],
                selected: {_isDoubles},
                onSelectionChanged: (v) =>
                    setState(() => _isDoubles = v.first),
              ),

              const SizedBox(height: 20),

              // --- Players ---
              _sectionTitle(l10n.players),
              const SizedBox(height: 8),
              PlayerSearchField(
                key: ValueKey('opp1_${_isDoubles}_$_initialized'),
                label: _isDoubles ? l10n.opponent1 : l10n.opponentName,
                initialName: _opponent1Name,
                initialPlayerId: _opponent1Id,
                onPlayerSelected: (id, name) {
                  _opponent1Id = id;
                  _opponent1Name = name;
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              if (_isDoubles) ...[
                const SizedBox(height: 12),
                PlayerSearchField(
                  key: ValueKey('opp2_${_isDoubles}_$_initialized'),
                  label: l10n.opponent2,
                  initialName: _opponent2Name,
                  initialPlayerId: _opponent2Id,
                  onPlayerSelected: (id, name) {
                    _opponent2Id = id;
                    _opponent2Name = name;
                  },
                ),
                const SizedBox(height: 12),
                PlayerSearchField(
                  key: ValueKey('partner_${_isDoubles}_$_initialized'),
                  label: '${l10n.partner} (${l10n.optional})',
                  initialName: _partnerName,
                  initialPlayerId: _partnerId,
                  onPlayerSelected: (id, name) {
                    _partnerId = id;
                    _partnerName = name;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // --- Match type ---
              _sectionTitle(l10n.matchType),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'friendly', label: Text(l10n.friendly)),
                  ButtonSegment(value: 'league', label: Text(l10n.league)),
                  ButtonSegment(
                      value: 'tournament', label: Text(l10n.tournament)),
                ],
                selected: {_matchType},
                onSelectionChanged: (v) =>
                    setState(() => _matchType = v.first),
              ),

              const SizedBox(height: 20),

              // --- Format ---
              _sectionTitle(l10n.matchFormat),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'best_of_3', label: Text(l10n.bestOf3)),
                  ButtonSegment(
                      value: 'best_of_5', label: Text(l10n.bestOf5)),
                  ButtonSegment(
                      value: 'single_set', label: Text(l10n.singleSet)),
                ],
                selected: {_matchFormat},
                onSelectionChanged: (v) {
                  setState(() {
                    _matchFormat = v.first;
                    if (_sets.length > _maxSets) {
                      _sets = _sets.sublist(0, _maxSets);
                    }
                  });
                },
              ),

              const SizedBox(height: 20),

              // --- Court surface ---
              _sectionTitle(l10n.courtSurface),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'glass', label: Text(l10n.glass)),
                  ButtonSegment(value: 'cement', label: Text(l10n.cement)),
                  ButtonSegment(value: 'turf', label: Text(l10n.turf)),
                  ButtonSegment(value: 'other', label: Text(l10n.other)),
                ],
                selected: {_courtSurface},
                onSelectionChanged: (v) =>
                    setState(() => _courtSurface = v.first),
              ),

              const SizedBox(height: 20),

              // --- Result ---
              _sectionTitle(l10n.result),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.won),
                    icon: const Icon(Icons.emoji_events),
                  ),
                  ButtonSegment(value: false, label: Text(l10n.lost)),
                ],
                selected: {_won},
                onSelectionChanged: (v) => setState(() => _won = v.first),
              ),

              const SizedBox(height: 20),

              // --- Set scores ---
              _sectionTitle(l10n.sets),
              const SizedBox(height: 8),
              ..._buildSetScoreInputs(l10n),

              if (_sets.length < _maxSets) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _sets = [
                        ..._sets,
                        const SetScore(team1Games: 0, team2Games: 0),
                      ]),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addSet),
                ),
              ],

              const SizedBox(height: 20),

              // --- Notes ---
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '${l10n.notes} (${l10n.optional})',
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),

              const SizedBox(height: 20),

              // --- Optional stats ---
              _buildStatsSection(l10n),

              const SizedBox(height: 24),

              // --- Save button (only for creator) ---
              if (_isCreator) ...[
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveMatch,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      ),
    );
  }

  List<Widget> _buildSetScoreInputs(AppLocalizations l10n) {
    return List.generate(_sets.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(
              '${l10n.set} ${i + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 60,
              child: TextFormField(
                key: ValueKey('set_${i}_t1_${_sets[i].team1Games}'),
                initialValue: _sets[i].team1Games.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: l10n.team1,
                  labelStyle: const TextStyle(fontSize: 10),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                ),
                onChanged: (v) {
                  final games = int.tryParse(v) ?? 0;
                  setState(() {
                    _sets[i] = SetScore(
                      team1Games: games,
                      team2Games: _sets[i].team2Games,
                    );
                  });
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-', style: TextStyle(fontSize: 20)),
            ),
            SizedBox(
              width: 60,
              child: TextFormField(
                key: ValueKey('set_${i}_t2_${_sets[i].team2Games}'),
                initialValue: _sets[i].team2Games.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: l10n.team2,
                  labelStyle: const TextStyle(fontSize: 10),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                ),
                onChanged: (v) {
                  final games = int.tryParse(v) ?? 0;
                  setState(() {
                    _sets[i] = SetScore(
                      team1Games: _sets[i].team1Games,
                      team2Games: games,
                    );
                  });
                },
              ),
            ),
            const Spacer(),
            if (_sets.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () {
                  setState(() => _sets = [..._sets]..removeAt(i));
                },
              ),
          ],
        ),
      );
    });
  }

  Widget _buildStatsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _showStats = !_showStats),
          icon: Icon(_showStats ? Icons.expand_less : Icons.expand_more),
          label: Text(l10n.addStats),
        ),
        if (_showStats) ...[
          const SizedBox(height: 16),
          _sectionTitle(l10n.serves),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statField(l10n.firstServeIn, _firstServeIn,
                      (v) => _firstServeIn = v)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statField(l10n.firstServeTotal, _firstServeTotal,
                      (v) => _firstServeTotal = v)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statField(l10n.aces, _aces, (v) => _aces = v)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statField(l10n.doubleFaults, _doubleFaults,
                      (v) => _doubleFaults = v)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle(l10n.shots),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statField(
                      l10n.winners, _winners, (v) => _winners = v)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statField(l10n.unforcedErrors, _unforcedErrors,
                      (v) => _unforcedErrors = v)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle(l10n.padelShots),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statField(l10n.bandeja, _bandejaWinners,
                      (v) => _bandejaWinners = v)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statField(l10n.vibora, _viboraWinners,
                      (v) => _viboraWinners = v)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _statField(l10n.smash, _smashWinners,
                      (v) => _smashWinners = v)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statField(
                      l10n.lob, _lobWinners, (v) => _lobWinners = v)),
            ],
          ),
          const SizedBox(height: 8),
          _statField(
              l10n.volley, _volleyWinners, (v) => _volleyWinners = v),
        ],
      ],
    );
  }

  Widget _statField(String label, int value, void Function(int) onChanged) {
    return TextFormField(
      key: ValueKey('stat_${label}_$value'),
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (v) => setState(() => onChanged(int.tryParse(v) ?? 0)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
    );
  }
}
