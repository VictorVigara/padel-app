import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/player_profile/presentation/providers/profile_providers.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  String _position = 'both';
  String _handedness = 'right';
  String _level = 'beginner';
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        userId: user.id,
        data: {
          'preferred_position': _position,
          'handedness': _handedness,
          'level': _level,
        },
      );
      if (mounted) context.go('/matches');
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sports_tennis, size: 60, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Set Up Your Profile',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your padel game',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Preferred Position'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'left', label: Text('Left')),
                      ButtonSegment(value: 'right', label: Text('Right')),
                      ButtonSegment(value: 'both', label: Text('Both')),
                    ],
                    selected: {_position},
                    onSelectionChanged: (v) => setState(() => _position = v.first),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Handedness'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'right', label: Text('Right')),
                      ButtonSegment(value: 'left', label: Text('Left')),
                    ],
                    selected: {_handedness},
                    onSelectionChanged: (v) => setState(() => _handedness = v.first),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Level'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'beginner', label: Text('Beginner')),
                      ButtonSegment(value: 'intermediate', label: Text('Inter.')),
                      ButtonSegment(value: 'advanced', label: Text('Advanced')),
                      ButtonSegment(value: 'pro', label: Text('Pro')),
                    ],
                    selected: {_level},
                    onSelectionChanged: (v) => setState(() => _level = v.first),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
    );
  }
}
