import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LokkoImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool isCircle;
  final IconData fallbackIcon;

  const LokkoImage({
    super.key,
    required this.imageUrl,
    this.size = 70,
    this.isCircle = true,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    // Trim to handle accidental whitespace in database strings
    final cleanUrl = imageUrl?.trim();

    if (cleanUrl == null || cleanUrl.isEmpty || !cleanUrl.toLowerCase().startsWith('http')) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(isCircle ? size / 2 : 8),
      child: CachedNetworkImage(
        // Adding a Key here is the SECRET to fixing the "not updating" issue
        key: ValueKey(cleanUrl),
        imageUrl: cleanUrl,
        width: size,
        height: size,
        // Reduced to 200 for profile icons to stop the TECNO frame skipping
        memCacheWidth: isCircle ? 200 : 350,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) {
          debugPrint("LOKKO_IMAGE_ERROR: $error for $url");
          return _buildPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(8),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1aa332)),
        )
            : Icon(fallbackIcon, size: size * 0.5, color: Colors.grey[400]),
      ),
    );
  }
}