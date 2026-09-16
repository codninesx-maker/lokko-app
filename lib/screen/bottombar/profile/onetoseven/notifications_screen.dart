import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Required for ConsumerStatefulWidget
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/screen/chat/chat_list_screen.dart';
import 'package:lokko_market/screen/topbar/notification_bell_red_dot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;



class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _notificationStream;

  // Banner Ad Configuration Instance Variables
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    final userId = _supabase.auth.currentUser?.id;

    // Realtime Stream for the List
    _notificationStream = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false)
        .handleError((e) => debugPrint("LOKKO_UI_STREAM_ERROR: $e"));


    // Clear red dot on entry
    _clearRedDot();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose(); // Clean up graphics/hardware rendering memory leaks
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      // Standard AdMob Test Banner ID. Swap to your production ID when building live release APK bundles.
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner, // 320x100 Frame size matching Account and Search views
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Notifications Bottom Large Banner Ad lifecycle failure: $error');
        },
      ),
    )..load();
  }

  Future<void> _markAsRead(String id) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
    // Invalidate so the bell updates if user clicks an individual item
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> _clearRedDot() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      // 1. Wrap the provider modification in a microtask
      // This prevents the "Tried to modify a provider while building" error
      Future.microtask(() {
        ref.read(unreadNotificationCountProvider.notifier).clearLocal();
      });

      try {
        // 2. Update the Database
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);

        debugPrint("LOKKO_DATABASE: Red dot cleared successfully.");
      } catch (e) {
        debugPrint("LOKKO_ERROR: $e");
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    debugPrint("LOKKO_DEBUG: Delete clicked for User: $userId"); // Check if this prints

    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear all?"),
        content: const Text("This will permanently delete all notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      debugPrint("LOKKO_DEBUG: Confirmation received, sending delete request...");
      try {
        final response = await _supabase
            .from('notifications')
            .delete()
            .eq('user_id', userId);

        debugPrint("LOKKO_DEBUG: Delete request finished.");

        ref.invalidate(unreadNotificationCountProvider);
      } catch (e) {
        debugPrint("LOKKO_DELETE_ERROR: $e"); // Watch for this!
      }
    } else {
      debugPrint("LOKKO_DEBUG: Delete cancelled by user.");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Manually refresh the notification stream/count here
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332), // LOKKO Green
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _deleteAllNotifications,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: "Clear All",
          ),
        ],
      ),
      // FIXED: Wrapped using a multi-child layout stack layout column with secure safe zones
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332)));
                  }

                  final notifications = snapshot.data ?? [];
                  if (notifications.isEmpty) return _buildEmptyState();

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    color: const Color(0xFF1aa332),
                    child: ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final bool isRead = item['is_read'] ?? false;
                        final DateTime createdAt = DateTime.parse(item['created_at']);

                        return Dismissible(
                          key: Key(item['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            await _supabase.from('notifications').delete().eq('id', item['id']);
                            ref.invalidate(unreadNotificationCountProvider);
                          },
                          child: Container(
                            color: isRead ? Colors.white : const Color(0xFF1aa332).withOpacity(0.05),
                            child: ListTile(
                              onTap: () async {
                                if (!isRead) {
                                  await _markAsRead(item['id']);
                                }

                                final String title = (item['title'] ?? "").toLowerCase();
                                final String body = (item['body'] ?? "").toLowerCase();

                                if (title.contains("message") || title.contains("chat") || body.contains("sent you")) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ChatListScreen()),
                                  );
                                }
                              },
                              leading: Badge(
                                showBadge: !isRead,
                                badgeColor: const Color(0xFF1aa332),
                                child: CircleAvatar(
                                  backgroundColor: isRead ? Colors.grey[100] : const Color(0xFF1aa332).withOpacity(0.1),
                                  child: Icon(
                                    _getIcon(item['title']),
                                    color: isRead ? Colors.grey : const Color(0xFF1aa332),
                                  ),
                                ),
                              ),
                              title: Text(
                                item['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['body'] ?? '', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(createdAt),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            // FIXED: Placed rendering placeholder down directly below bounded top layouts
            _buildPersistentBottomAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentBottomAd() {
    if (_isBannerAdLoaded && _bottomLargeBannerAd != null) {
      return Container(
        color: Colors.white,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        height: 112, // 100px ad frame height + 12px padding buffer
        child: SizedBox(
          width: 320, // Explicit layout constraints matching AdSize.largeBanner
          height: 100,
          child: AdWidget(ad: _bottomLargeBannerAd!),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  IconData _getIcon(dynamic title) {
    final t = title.toString().toLowerCase();
    if (t.contains("message") || t.contains("chat")) return Icons.mail_outline;
    if (t.contains("sold") || t.contains("ad")) return Icons.campaign_outlined;
    if (t.contains("favorite") || t.contains("like")) return Icons.favorite_border;
    return Icons.notifications_none;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No notifications yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final Widget child;
  final bool showBadge;
  final Color badgeColor;
  const Badge({super.key, required this.child, required this.showBadge, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showBadge)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}