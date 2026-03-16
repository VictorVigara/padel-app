import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:padel_app/core/network/supabase_client.dart';

class AuthRepository {
  GoTrueClient get _auth => SupabaseConfig.auth;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  /// Check if a display name is already taken by another user.
  Future<bool> isDisplayNameTaken(String displayName) async {
    final result = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .ilike('display_name', displayName)
        .limit(1);
    return (result as List).isNotEmpty;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await _auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }
}
