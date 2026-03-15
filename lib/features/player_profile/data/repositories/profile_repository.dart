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
}
