import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_model.dart';


class ChatRoomModel {
  final String id;
  final String adId;
  final DateTime updatedAt;
  final AdModel? ad;
  final String receiverName;
  final String? lastMessage;
  final String receiverId;
  final String? receiverAvatarPublicId;

  ChatRoomModel({
    required this.id,
    required this.adId,
    required this.updatedAt,
    required this.receiverName, // Added to constructor
    this.lastMessage,           // Added to constructor
    required this.receiverId,
    this.ad,
    this.receiverAvatarPublicId,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;

      // 1. Identify participants
      final sellerData = json['seller'] as Map<String, dynamic>?;
      final buyerData = json['buyer'] as Map<String, dynamic>?;

      // 2. THE FLIP: If I am the seller, show me the buyer.
      final bool amISeller = sellerData?['id'] == myId;
      final otherPersonData = amISeller ? buyerData : sellerData;

      // 3. Extract Ad & Location data safely
      final dynamic adRaw = json['ads'];
      Map<String, dynamic>? adMap;

      if (adRaw is List && adRaw.isNotEmpty) {
        adMap = adRaw.first;
      } else if (adRaw is Map<String, dynamic>) {
        adMap = adRaw;
      }

      return ChatRoomModel(
        id: json['id']?.toString() ?? '',
        adId: json['ad_id']?.toString() ?? '',
        // This will now correctly show Ibrahim Rana or the other participant
        receiverName: otherPersonData?['full_name'] ?? 'Lokko User',
        receiverId: otherPersonData?['id'] ?? '',
        receiverAvatarPublicId: otherPersonData?['avatar_public_id']?.toString(),
        lastMessage: json['last_message']?.toString() ?? 'Tap to view messages',
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
        ad: adMap != null ? AdModel.fromMap(adMap) : null,
      );
    } catch (e) {
      debugPrint("LOKKO_CHAT_MODEL_ERROR: $e");
      return ChatRoomModel(
        id: json['id']?.toString() ?? '',
        adId: '',
        receiverName: "Error Loading",
        receiverId: '',
        lastMessage: '',
        updatedAt: DateTime.now(),
        ad: null,
      );
    }
  }
}