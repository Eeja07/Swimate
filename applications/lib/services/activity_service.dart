import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_model.dart';


final logger = Logger();

class ActivityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Ambil aktivitas terbaru berdasarkan user yang sedang login
  Future<ActivityModel?> getLatestActivity() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('activity_table')
          .select()
          .eq('id_user', userId)
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      return ActivityModel.fromJson(response);
    } catch (e) {
      logger.e('Error fetching latest activity', error: e);
      return null;
    }
  }

  // Ambil semua aktivitas user
  Future<List<ActivityModel>> getAllActivities() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('activity_table')
          .select()
          .eq('id_user', userId)
          .order('timestamp', ascending: false);

      return (response as List)
          .map((json) => ActivityModel.fromJson(json))
          .toList();
    } catch (e) {
      logger.e('Error fetching activities', error: e);
      return [];
    }
  }
}