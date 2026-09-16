import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart' show CloudinaryHelper;
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bottombar/profile/seller_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final AdModel ad;
  final String receiverName;
  final String receiverId;
  final String? roomId;
  final String? adId;
  final String? receiverAvatarPublicId;


  const ChatScreen({
    super.key,
    required this.ad,
    required this.receiverName,
    required this.receiverId,
    required this.roomId,
    this.adId,
    this.receiverAvatarPublicId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Stream<List<Map<String, dynamic>>>? _chatStream;
  String? _resolvedAvatarUrl;
  bool _isFetchingAvatar = false;


  @override
  void initState() {
    super.initState();

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == widget.receiverId) {
      debugPrint("LOKKO_CHAT: Self-viewing ad chat. Skipping stream init.");
      return;
    }

    // Calculate initial URL from parameters if available
    _resolveInitialAvatarUrl();

    Future.microtask(() => _setupInitialStream());
  }

  void _resolveInitialAvatarUrl() {
    final pId = widget.receiverAvatarPublicId;
    if (pId != null && pId.trim().isNotEmpty) {
      // If it looks like a full URL already, use it directly; otherwise parse it
      if (pId.startsWith('http')) {
        _resolvedAvatarUrl = pId;
      } else {
        _resolvedAvatarUrl = CloudinaryHelper.getSmartImageUrl(pId.trim());
      }
    }
  }

  @override
  void dispose() {
    // FIXED: Cleaned up controller memory allocation
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getSupabaseStream(String id) {
    return Stream.fromFuture(Future.delayed(const Duration(milliseconds: 800)))
        .asyncExpand((_) => Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', id)
        .order('created_at', ascending: false));
  }

  Future<void> _setupInitialStream() async {
    // Path A: We already have the ID (from Chat List)
    if (_resolvedAvatarUrl == null && !_isFetchingAvatar) {
      setState(() => _isFetchingAvatar = true);
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('avatar_public_id, avatar_url')
            .eq('id', widget.receiverId)
            .maybeSingle();

        if (profile != null && mounted) {
          String? targetUrl;
          final String? pubId = profile['avatar_public_id'];
          final String? rawUrl = profile['avatar_url'];

          if (pubId != null && pubId.trim().isNotEmpty) {
            targetUrl = CloudinaryHelper.getSmartImageUrl(pubId.trim());
          } else if (rawUrl != null && rawUrl.trim().isNotEmpty) {
            targetUrl = rawUrl.trim();
          }

          if (targetUrl != null) {
            setState(() {
              _resolvedAvatarUrl = targetUrl;
            });
            debugPrint("LOKKO_CHAT: Successfully resolved avatar url down from DB: $_resolvedAvatarUrl");
          }
        }
      } catch (e) {
        debugPrint("LOKKO_AVATAR_DB_FETCH_ERROR: $e");
      } finally {
        if (mounted) setState(() => _isFetchingAvatar = false);
      }
    }

    if (widget.roomId != null) {
      _initializeChatStream(widget.roomId!);
      return;
    }

    // Path B: No ID (from Ad Post). Let's see if a room exists already.
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final existingRoom = await Supabase.instance.client
          .from('rooms')
          .select('id')
          .eq('ad_id', widget.ad.id)
          .eq('buyer_id', user.id)
          .maybeSingle();

      if (existingRoom != null && mounted) {
        // Found it! Load history without needing a new message.
        _initializeChatStream(existingRoom['id']);
      }
    } catch (e) {
      debugPrint("LOKKO_INIT_CHECK_ERROR: $e");
    }
  }

  void _initializeChatStream(String id) {
    // CRITICAL: If the stream is already set for this room, do NOTHING.
    // Re-initializing the stream causes the UI to flicker and jump.
    if (_chatStream != null) return;

    debugPrint("LOKKO_CHAT: Initializing stream for room $id");
    setState(() {
      _chatStream = Supabase.instance.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', id)
          .order('created_at', ascending: false);
    });
  }

  void _navigateToSellerProfile() {
    debugPrint("LOKKO_CHAT: Navigating to profile for seller ID: ${widget.receiverId}");

    Navigator.push(
      context,
      MaterialPageRoute(
        // Fixed: Changed parameter name from sellerId to userId
        builder: (_) => SellerProfileScreen(userId: widget.receiverId),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (user.id == widget.receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot message yourself.")),
      );
      return;
    }

    // 1. Clear input instantly so the UI feels responsive
    _messageController.clear();

    // 2. Delay the scroll by 150ms.
    // This prevents the "jumping" conflict between the keyboard and the list update.
    Future.delayed(const Duration(milliseconds: 150), () => _scrollToBottom());

    try {
      String? currentRoomId = widget.roomId;

      // Room creation logic (only runs for the very first message)
      if (currentRoomId == null) {
        final existingRoom = await Supabase.instance.client
            .from('rooms')
            .select('id')
            .eq('ad_id', widget.ad.id)
            .eq('buyer_id', user.id)
            .maybeSingle();

        currentRoomId = existingRoom != null
            ? existingRoom['id']
            : (await Supabase.instance.client.from('rooms').insert({
          'ad_id': widget.ad.id,
          'seller_id': widget.receiverId,
          'buyer_id': user.id,
        }).select().single())['id'];

        if (mounted) _initializeChatStream(currentRoomId!);
      }

      // 3. Insert the message silently in the background
      await Supabase.instance.client.from('messages').insert({
        'room_id': currentRoomId,
        'ad_id': widget.ad.id,
        'sender_id': user.id,
        'receiver_id': widget.receiverId,
        'content': text,
      });

      // 4. ADD THIS: Insert into notifications table so the red dot appears
      await Supabase.instance.client.from('notifications').insert({
        'user_id': widget.receiverId, // Use the other person's ID now
        'title': 'New Message',
        'body': text,
        'is_read': false,
      });
    } catch (e) {
      debugPrint("LOKKO_CHAT_ERROR: $e");
      if (mounted) _messageController.text = text; // Restore text only on error
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // In a reversed list, 0.0 is the bottom
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? myId = Supabase.instance.client.auth.currentUser?.id;

    if (myId == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildItemPreview(),
          // 🔽 FIXED COLOR & WIDGET CONFIGURATION HERE 🔽
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RepaintBoundary(
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const SizedBox(
                  width: double.infinity,
                  child: LokkoTestBanner(), // Fixed: Removed positional / constant parameter mismatch
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)), // Fixed: Changed typo to actual HEX value
          // 🔼 FIXED SECTIONS 🔼
          Expanded(
            child: _chatStream == null
                ? _buildNewChatPlaceholder()
                : StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_chatStream?.hashCode ?? "empty_chat"),
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorState();
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) return _buildNewChatPlaceholder();

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true, // Crucial for your RepaintBoundary optimization
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _ChatBubble(
                      message: msg['content'] ?? '',
                      isMe: msg['sender_id'] == myId,
                      time: _formatTime(msg['created_at']),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    final localTime = DateTime.parse(timestamp).toLocal();
    final hour = localTime.hour > 12 ? (localTime.hour - 12) : (localTime.hour == 0 ? 12 : localTime.hour);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  Widget _buildTextFallback() {
    return Center(
      child: Text(
        widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
  // --- UI Components ---

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1aa332),
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      // Wrap the header content in an InkWell to make it clickable
      title: InkWell(
        onTap: _navigateToSellerProfile,
        splashColor: Colors.white24,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: _resolvedAvatarUrl == null
                    ? Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: _buildTextFallback(),
                )
                    : CachedNetworkImage(
                  imageUrl: _resolvedAvatarUrl!,
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint("LOKKO_AVATAR_RENDER_ERROR: $error URL: $_resolvedAvatarUrl");
                    return Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: _buildTextFallback(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.receiverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 16), // Gives a little padding at the right edge of the tap target
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview() {
    return InkWell(
      // The entire row is now clickable and handles the navigation
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdDetailsScreen(ad: widget.ad)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                CloudinaryHelper.getSmartImageUrl(widget.ad.images[0]),
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "৳ ${widget.ad.price}",
                    style: const TextStyle(color: Color(0xFF1aa332), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // TextButton has been cleanly removed, giving more space for the text fields
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1aa332)), onPressed: () {}),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Write a message...",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF1aa332)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off_rounded, color: Colors.grey, size: 40),
          const SizedBox(height: 10),
          const Text("Connection timed out"),
          TextButton(
            onPressed: () {
              // If we have a room ID, try to connect again
              if (widget.roomId != null) {
                _initializeChatStream(widget.roomId!);
              } else {
                setState(() {}); // Refresh if we're still waiting for a room
              }
            },
            child: const Text("RETRY"),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatPlaceholder() {
    return Center(
      child: Text("No messages yet. Say hi!", style: TextStyle(color: Colors.grey[500])),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;

  const _ChatBubble({required this.message, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    // Wrap the entire bubble in a RepaintBoundary
    return RepaintBoundary(
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1aa332) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                // Keep border instead of shadow for TECNO GPU performance
                border: isMe ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                message,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
              ),
            ),
            Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}