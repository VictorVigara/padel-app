import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;

  final _displayNameController = TextEditingController();
  String _position = 'both';
  String _handedness = 'right';
  String _level = 'beginner';

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _loadProfile(Map<String, dynamic> profile) {
    if (_initialized) return;
    _initialized = true;
    _displayNameController.text =
        profile['display_name'] as String? ?? '';
    _position = profile['preferred_position'] as String? ?? 'both';
    _handedness = profile['handedness'] as String? ?? 'right';
    _level = profile['level'] as String? ?? 'beginner';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        userId: user.id,
        data: {
          'display_name': _displayNameController.text.trim(),
          'preferred_position': _position,
          'handedness': _handedness,
          'level': _level,
        },
      );

      if (mounted) {
        ref.invalidate(profileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.profileSaved)),
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
    final profileAsync = ref.watch(profileProvider);

    // Load existing profile data
    if (!_initialized) {
      return profileAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: Text(l10n.editProfile)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(l10n.editProfile)),
          body: Center(child: Text('Error: $e')),
        ),
        data: (profile) {
          if (profile == null) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.editProfile)),
              body: const Center(child: Text('Profile not found')),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialized) {
              setState(() => _loadProfile(profile));
            }
          });
          return Scaffold(
            appBar: AppBar(title: Text(l10n.editProfile)),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display name
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: l10n.displayName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Position
                _sectionTitle('Preferred Position'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'left', label: Text('Left')),
                    ButtonSegment(value: 'right', label: Text('Right')),
                    ButtonSegment(value: 'both', label: Text('Both')),
                  ],
                  selected: {_position},
                  onSelectionChanged: (v) =>
                      setState(() => _position = v.first),
                ),
                const SizedBox(height: 24),

                // Handedness
                _sectionTitle('Handedness'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'right', label: Text('Right')),
                    ButtonSegment(value: 'left', label: Text('Left')),
                  ],
                  selected: {_handedness},
                  onSelectionChanged: (v) =>
                      setState(() => _handedness = v.first),
                ),
                const SizedBox(height: 24),

                // Level
                _sectionTitle('Level'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'beginner', label: Text('Beginner')),
                    ButtonSegment(
                        value: 'intermediate', label: Text('Inter.')),
                    ButtonSegment(
                        value: 'advanced', label: Text('Advanced')),
                    ButtonSegment(value: 'pro', label: Text('Pro')),
                  ],
                  selected: {_level},
                  onSelectionChanged: (v) =>
                      setState(() => _level = v.first),
                ),
                const SizedBox(height: 40),

                // Save
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
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
