import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Ensure this path points to where your NotificationsScreen is located
import 'package:lokko_market/screen/bottombar/profile/onetoseven/notifications_screen.dart';

final unreadNotificationCountProvider = NotifierProvider<UnreadNotificationNotifier, int>(() {
  return UnreadNotificationNotifier();
});

class UnreadNotificationNotifier extends Notifier<int> {
  final _supabase = Supabase.instance.client;

  @override
  int build() {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    Future.microtask(() => _fetchInitialCount(user.id));

    final stream = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id);

    final subscription = stream.listen((data) {
      final unreadCount = data.where((row) => row['is_read'] == false).length;

      // Only update state inside the listener callback
      state = unreadCount;
    }, onError: (error) {
      debugPrint("LOKKO_REALTIME_ERROR: $error");
    });

    ref.onDispose(() => subscription.cancel());

    return 0; // Return the initial state immediately
  }


  Future<void> _fetchInitialCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      state = (response as List).length;
      debugPrint("LOKKO_REALTIME_COUNT: Initial count is $state");
    } catch (e) {
      debugPrint("LOKKO_FETCH_ERROR: $e");
    }
  }

  void clearLocal() => state = 0;
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This is now a plain integer, not an AsyncValue
    final count = ref.watch(unreadNotificationCountProvider);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none, color: Colors.white, size: 28),
            if (count > 0)
              Positioned(
                right: -2,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    // Keeping your LOKKO green border
                    border: Border.all(color: const Color(0xFF1aa332), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}