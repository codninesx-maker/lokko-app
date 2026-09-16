import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/screen/chat/chat_room_tile.dart';
import 'package:lokko_market/screen/chat/chat_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRoomsAsync = ref.watch(chatRoomProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // The chat list expands to fill all available space above the bottom ad
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(chatRoomProvider.future),
              child: chatRoomsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => _buildErrorState(err, ref),
                data: (rooms) {
                  if (rooms.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return Dismissible(
                        key: Key(room.id),
                        // 🔽 FIXED: Reverted back to stable SDK direction classification 🔽
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) => _showDeleteConfirmation(context),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          // 🔑 FIXED: Call your provider's custom method directly.
                          // It triggers your built-in optimistic update instantly.
                          ref.read(chatRoomProvider.notifier).deleteRoom(room.id);
                        },
                        child: ChatRoomTile(room: room),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 🔽 INJECTED: Bottom Side Ad Banner placement 🔽
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: RepaintBoundary(
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const LokkoTestBanner(key: ValueKey('chat_list_bottom_ad')),
              ),
            ),
          ),
          // 🔼 END OF BOTTOM AD PLACEMENT 🔼
        ],
      ),
    );
  }

  // UI for when there are no chats
  Widget _buildEmptyState() {
    return ListView( // Needs to be scrollable for RefreshIndicator to work
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 200),
        Center(
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text("No messages yet", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // UI for when a logic error occurs
  Widget _buildErrorState(Object err, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              "Chat Loading Failed",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(), // The raw error for debugging
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(chatRoomProvider),
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1aa332), // LOKKO Green
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This will remove the conversation from your list."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

