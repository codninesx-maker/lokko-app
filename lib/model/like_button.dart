import 'package:flutter/material.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeButton extends StatefulWidget {
  final String adId;
  const LikeButton({super.key, required this.adId});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool isLiked = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  // Check if this specific ad is already in the user's favorites
  Future<void> _checkIfLiked() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .eq('ad_id', widget.adId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          isLiked = data != null;
        });
      }
    } catch (e) {
      debugPrint("Error checking like status: $e");
    }
  }

  Future<void> _toggleLike() async {
    final user = supabase.auth.currentUser;

    // 1. If not logged in, show a message
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to save ads")),
      );
      return;
    }

    // 2. Optimistic UI: Change color immediately for a fast feel
    setState(() {
      isLiked = !isLiked;
    });

    try {
      if (isLiked) {
        // Add to favorites
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'ad_id': widget.adId,
        });
      } else {
        // Remove from favorites
        await supabase.from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('ad_id', widget.adId);
      }
    } catch (e) {
      // 3. If the DB call fails, revert the heart color
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
        });
        debugPrint("Toggle Like Error: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleLike,
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Makes it easier to tap
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          // If liked, show Red. If not, show White (to match your Share icon)
          color: isLiked ? Colors.red : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}