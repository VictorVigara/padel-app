import 'package:padel_app/core/network/supabase_client.dart';

class ProfileRepository {
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<double> getCurrentRating(String userId) async {
    final response = await SupabaseConfig.client
        .from('ratings')
        .select('rating')
        .eq('player_id', userId)
        .order('calculated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return 1200.0;
    return (response['rating'] as num).toDouble();
  }

  /// Search players by display name (ILIKE), excluding the current user.
  /// Returns up to 10 matching profiles with their latest rating.
  Future<List<Map<String, dynamic>>> searchPlayers(
      String query, String currentUserId) async {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .ilike('display_name', '%$query%')
        .neq('id', currentUserId)
        .limit(10);
    final profiles = List<Map<String, dynamic>>.from(response as List);

    // Fetch latest rating for each profile
    for (final profile in profiles) {
      final rating = await getCurrentRating(profile['id'] as String);
      profile['rating'] = rating;
    }
    return profiles;
  }

  /// Batch fetch profiles by IDs. Returns a map of id → profile data.
  Future<Map<String, Map<String, dynamic>>> getProfilesByIds(
      List<String> ids) async {
    if (ids.isEmpty) return {};
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .inFilter('id', ids);
    final profiles = <String, Map<String, dynamic>>{};
    for (final row in response as List) {
      final map = row as Map<String, dynamic>;
      profiles[map['id'] as String] = map;
    }
    return profiles;
  }
}
