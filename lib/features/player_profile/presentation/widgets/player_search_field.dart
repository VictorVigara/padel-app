import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';

/// A text field that searches registered players as the user types.
/// When a registered player is selected, [onPlayerSelected] fires with their
/// profile ID and display name. The user can also type a free-text name for
/// unregistered opponents — in that case the ID will be null.
class PlayerSearchField extends ConsumerStatefulWidget {
  final String label;
  final String? initialName;
  final String? initialPlayerId;
  final void Function(String? playerId, String displayName) onPlayerSelected;
  final String? Function(String?)? validator;

  const PlayerSearchField({
    super.key,
    required this.label,
    required this.onPlayerSelected,
    this.initialName,
    this.initialPlayerId,
    this.validator,
  });

  @override
  ConsumerState<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends ConsumerState<PlayerSearchField> {
  late TextEditingController _controller;
  String? _selectedId;
  List<Map<String, dynamic>> _results = [];
  bool _showResults = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _selectedId = widget.initialPlayerId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String query) {
    // Clear previous selection when user edits
    if (_selectedId != null) {
      _selectedId = null;
      widget.onPlayerSelected(null, query.trim());
    }

    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      widget.onPlayerSelected(null, query.trim());
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchPlayers(query);
    });
  }

  Future<void> _searchPlayers(String query) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repo = ref.read(profileRepositoryProvider);
    try {
      final results = await repo.searchPlayers(query, user.id);
      if (mounted) {
        setState(() {
          _results = results;
          _showResults = results.isNotEmpty;
        });
      }
    } catch (_) {
      // Silently fail — user can still type free text
    }
  }

  void _selectPlayer(Map<String, dynamic> profile) {
    final id = profile['id'] as String;
    final name = profile['display_name'] as String;
    setState(() {
      _controller.text = name;
      _selectedId = id;
      _results = [];
      _showResults = false;
    });
    widget.onPlayerSelected(id, name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.person_outline),
            suffixIcon: _selectedId != null
                ? const Icon(Icons.verified, color: AppColors.primary, size: 20)
                : null,
          ),
          onChanged: _onTextChanged,
          onTap: () {
            if (_controller.text.length >= 2 && _results.isNotEmpty) {
              setState(() => _showResults = true);
            }
          },
          validator: widget.validator,
        ),
        if (_showResults && _results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final profile = _results[index];
                final name = profile['display_name'] as String;
                final level = profile['level'] as String?;
                final rating = profile['rating'] as num?;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 14),
                    ),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    [
                      ?level,
                      if (rating != null) '${rating.toInt()} ELO',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                  onTap: () => _selectPlayer(profile),
                );
              },
            ),
          ),
      ],
    );
  }
}
