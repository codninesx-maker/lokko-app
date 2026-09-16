import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider to manage the notification toggle state
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, bool>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsNotifier extends StateNotifier<bool> {
  NotificationSettingsNotifier() : super(true) {
    _loadSettings();
  }

  // Load the saved preference when the app starts
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('push_notifications') ?? true; // Default to true
  }

  // Toggle and save the preference
  Future<void> toggleNotification(bool value) async {
    state = value;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'notifications_enabled': value})
          .eq('id', user.id);
    }
  }
}