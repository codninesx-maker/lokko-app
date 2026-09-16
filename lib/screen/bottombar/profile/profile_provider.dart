import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. First, define an authStateProvider to listen for login/logout events
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// 2. Update userProfileProvider to watch the authState
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Use the specific user ID from your auth provider
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) return null;

  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  } catch (e) {
    debugPrint("LOKKO_DATABASE_ERROR: $e");
    return null;
  }
});