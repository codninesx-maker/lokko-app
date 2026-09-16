import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/screen/chat/chat_screen.dart';
import 'package:lokko_market/model/chat_room_model.dart'; // Strict Model Import

class ChatRoomTile extends StatelessWidget {
  final ChatRoomModel room;

  const ChatRoomTile({super.key, required this.room});

  // 🔽 RESTORED: Lazy fetch helper if the ad is null 🔽
  Future<dynamic> _fetchFallbackAd(String adId) async {
    try {
      final response = await Supabase.instance.client
          .from('ads')
          .select()
          .eq('id', adId)
          .maybeSingle();

      if (response != null) {
        return AdModel.fromMap(response);
      }
    } catch (e) {
      debugPrint("LOKKO_TILE_LAZY_FETCH_ERROR: $e");
    }
    return null;
  }

  // 🔽 RESTORED: Navigation routing abstraction 🔽
  void _navigateToChat(BuildContext context, dynamic validAd) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          ad: validAd,
          receiverName: room.receiverName,
          receiverId: room.receiverId,
          roomId: room.id,
          receiverAvatarPublicId: room.receiverAvatarPublicId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = room.receiverName;

    // --- RESOLVE THE AVATAR IMAGE URL ---
    String? avatarUrl;
    final String? pubId = room.receiverAvatarPublicId;

    if (pubId != null && pubId.isNotEmpty) {
      avatarUrl = CloudinaryHelper.getProfileAvatar(pubId);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1aa332), width: 1.5), // LOKKO Green Border
        ),
        child: ClipOval(
          child: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1aa332),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[100],
              child: const Icon(Icons.person, color: Colors.grey, size: 26),
            ),
          )
              : Container(
            color: Colors.grey[100],
            child: const Icon(Icons.person, color: Color(0xFF1aa332), size: 26),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (room.ad?.isVerified ?? false)
            const Icon(Icons.verified, size: 16, color: Colors.blue),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${room.ad?.title ?? 'Inquiry'} • ${room.ad?.locationName ?? 'Bangladesh'}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF1aa332), fontSize: 12),
          ),
          Text(
            room.lastMessage ?? "Tap to view messages",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {
        if (room.ad == null) {
          _fetchFallbackAd(room.adId).then((lazyAd) {
            if (lazyAd != null) {
              _navigateToChat(context, lazyAd);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ad information is unavailable...")),
              );
            }
          });
          return;
        }

        _navigateToChat(context, room.ad!);
      },
    );
  }
}