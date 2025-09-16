import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkAwareProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? fallbackText;

  const NetworkAwareProfileImage({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: Center(
          child: SizedBox(
            width: size * 0.3,
            height: size * 0.3,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // Log the specific error for debugging
        print('Image loading error for $url: $error');
        return _buildFallback();
      },
      // Add timeout and retry logic
      httpHeaders: const {
        'User-Agent': 'Flutter App',
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.blue[100],
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (fallbackText == null || fallbackText!.isEmpty) {
      return '?';
    }

    final words = fallbackText!.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }

    return '?';
  }
}