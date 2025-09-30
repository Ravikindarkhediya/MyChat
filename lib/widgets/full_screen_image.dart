import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String? url;
  final String? base64Data;
  const FullScreenImage({super.key, this.url, this.base64Data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Decode base64 if provided
    Uint8List? bytes;
    if ((base64Data ?? '').isNotEmpty) {
      try {
        bytes = base64Decode(base64Data!);
      } catch (_) {
        bytes = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black45,
      body: Stack(
        children: [
          // Backdrop blur over current route
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: const SizedBox.shrink(),
            ),
          ),

          // Dismiss when tapping outside the glass card
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.shrink(),
            ),
          ),

          // Centered glass container with the image and controls
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.08),
                    border: Border.all(color: cs.onSurface.withOpacity(0.12), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4,
                            child: Builder(
                              builder: (context) {
                                if (bytes != null) {
                                  return Image.memory(bytes!, fit: BoxFit.contain);
                                }
                                if ((url ?? '').isNotEmpty) {
                                  return CachedNetworkImage(
                                    imageUrl: url!,
                                    fit: BoxFit.contain,
                                    placeholder: (context, u) => const Center(
                                      child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, u, e) => Center(
                                      child: Icon(Icons.broken_image_rounded, color: cs.error, size: 48),
                                    ),
                                  );
                                }
                                return Center(
                                  child: Icon(Icons.broken_image_rounded, color: cs.error, size: 48),
                                );
                              },
                            ),
                          ),
                        ),

                        // Close button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.surface.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cs.onSurface.withOpacity(0.12)),
                                ),
                                child: Icon(Icons.close_rounded, color: cs.onSurface.withOpacity(0.9)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
