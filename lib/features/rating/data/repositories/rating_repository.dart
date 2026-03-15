import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';

class RatingRepository {
  /// All ratings for a player, oldest first (for charting).
  Future<List<RatingRecord>> getRatingHistory(String userId) async {
    final response = await SupabaseConfig.client
        .from('ratings')
        .select()
        .eq('player_id', userId)
        .order('calculated_at', ascending: true);
    return (response as List)
        .map((json) => RatingRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Latest rating for a player, or null if none exists.
  Future<RatingRecord?> getLatestRating(String userId) async {
    final response = await SupabaseConfig.client
        .from('ratings')
        .select()
        .eq('player_id', userId)
        .order('calculated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return RatingRecord.fromJson(response);
  }

  /// Insert a new rating record.
  Future<void> insertRating(RatingRecord record) async {
    await SupabaseConfig.client.from('ratings').insert(record.toJson());
  }
}
