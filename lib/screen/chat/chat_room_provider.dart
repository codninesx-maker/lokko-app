import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/model/chat_room_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomNotifier extends AsyncNotifier<List<ChatRoomModel>> {
    @override
    Future<List<ChatRoomModel>> build() async {
        return _fetchRooms();
    }

    // Inside ChatRoomNotifier
    Future<List<ChatRoomModel>> _fetchRooms() async {
        try {
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (userId == null) return [];

            final response = await Supabase.instance.client
                .from('rooms')
                .select('''
      *,
      ads:ad_id (
        *,
        location:districts!ads_location_id_fkey (
          name, 
          district:parent_id (name)
        ),
        profiles:user_id (full_name, is_verified), 
        categories:category_id (name)             
      ),
      seller:seller_id (id, full_name, avatar_public_id),
      buyer:buyer_id (id, full_name, avatar_public_id)
    ''')
                .or('seller_id.eq.$userId,buyer_id.eq.$userId')
                .order('updated_at', ascending: false);

            debugPrint("LOKKO_CHAT_FETCH: Found ${response.length} rooms");
            return response.map((json) => ChatRoomModel.fromJson(json)).toList();
        } catch (e) {
            debugPrint("LOKKO_CHAT_FETCH_CRITICAL: $e");
            return [];
        }
    }

    // THIS PREVENTS THE RED SCREEN CRASH
    Future<void> deleteRoom(String roomId) async {
        // Access the current list of rooms safely
        final previousState = state.value ?? [];

        // 1. Update UI Instantly (Optimistic Update)
        // We filter out the room locally so the Dismissible is happy immediately
        state = AsyncData(previousState.where((r) => r.id != roomId).toList());

        try {
            // 2. Delete from Supabase Database
            await Supabase.instance.client
                .from('rooms')
                .delete()
                .eq('id', roomId);

            // Optional: If you want to ensure the UI is perfectly in sync with DB
            // ref.invalidateSelf();
        } catch (e) {
            // 3. Rollback: If the database call fails, put the item back in the list
            state = AsyncData(previousState);

            debugPrint("LOKKO_DELETE_ERROR: $e");
        }
    }
}

final chatRoomProvider = AsyncNotifierProvider<ChatRoomNotifier, List<ChatRoomModel>>(
        () => ChatRoomNotifier(),
);