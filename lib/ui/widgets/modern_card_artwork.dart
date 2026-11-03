import 'package:flutter/material.dart';

import '../theme/vibrance.dart';
import 'bounded_network_image.dart';
import 'image_source.dart';

/// One background is cropped at rest and revealed as the card widens.
/// Independent title artwork follows the same clock, outside the image crop.
class ModernCardArtwork extends StatefulWidget {
  final String? imageUrl;
  final String? logoImageUrl;
  final String? fallbackTitle;
  final double collapsedWidth;
  final double expandedWidth;
  final double imageHeight;
  final double expansionProgress;
  final BoxFit fit;
  final Widget placeholder;

  @visibleForTesting
  final ImageProvider Function(String imageUrl, int cacheWidth)?
  imageProviderBuilder;

  const ModernCardArtwork({
    super.key,
    required this.imageUrl,
    this.logoImageUrl,
    this.fallbackTitle,
    required this.collapsedWidth,
    required this.expandedWidth,
    required this.imageHeight,
    required this.expansionProgress,
    this.fit = BoxFit.cover,
    this.placeholder = const SizedBox.shrink(),
    this.imageProviderBuilder,
  });

  @override
  State<ModernCardArtwork> createState() => _ModernCardArtworkState();
}

class _ModernCardArtworkState extends State<ModernCardArtwork> {
  ImageProvider? _background;
  ImageProvider? _logo;
  double? _devicePixelRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr != _devicePixelRatio) {
      _devicePixelRatio = dpr;
      _resolveProviders();
    }
  }

  @override
  void didUpdateWidget(covariant ModernCardArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.logoImageUrl != widget.logoImageUrl ||
        oldWidget.collapsedWidth != widget.collapsedWidth ||
        oldWidget.expandedWidth != widget.expandedWidth ||
        oldWidget.imageProviderBuilder != widget.imageProviderBuilder) {
      _resolveProviders();
    }
  }

  ImageProvider? _provider(String? url, double width, int maxWidth) {
    if (url == null || url.isEmpty) return null;
    final cacheWidth = BoundedNetworkImage.cacheWidthFor(
      width,
      _devicePixelRatio!,
      maxWidth: maxWidth,
    );
    return widget.imageProviderBuilder?.call(url, cacheWidth) ??
        offlineAwareImageProvider(url, maxWidth: cacheWidth);
  }

  void _resolveProviders() {
    _background = _provider(widget.imageUrl, widget.expandedWidth, 960);
    _logo = _provider(widget.logoImageUrl, widget.collapsedWidth - 24, 640);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.expansionProgress.clamp(0.0, 1.0);
    final title = widget.fallbackTitle;
    final fallback = title == null || title.isEmpty
        ? const SizedBox.shrink()
        : Align(
            alignment: Alignment.lerp(
              Alignment.center,
              Alignment.bottomLeft,
              progress,
            )!,
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: widget.expandedWidth,
            maxWidth: widget.expandedWidth,
            minHeight: widget.imageHeight,
            maxHeight: widget.imageHeight,
            child: Vibrance.wrap(
              _background == null
                  ? widget.placeholder
                  : Image(
                      image: _background!,
                      fit: widget.fit,
                      excludeFromSemantics: true,
                      frameBuilder: (_, child, frame, synchronous) =>
                          frame != null || synchronous
                          ? child
                          : widget.placeholder,
                      errorBuilder: (_, _, _) => widget.placeholder,
                    ),
            ),
          ),
        ),
        if (_logo != null || title != null) ...[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.lerp(
                const Alignment(0, 0.55),
                Alignment.bottomLeft,
                progress,
              )!,
              child: SizedBox(
                key: const ValueKey('modern-card-title'),
                width: widget.collapsedWidth - 24,
                height: widget.imageHeight * 0.25,
                child: _logo == null
                    ? fallback
                    : Image(
                        image: _logo!,
                        fit: BoxFit.contain,
                        alignment: Alignment.lerp(
                          Alignment.center,
                          Alignment.bottomLeft,
                          progress,
                        )!,
                        excludeFromSemantics: true,
                        frameBuilder: (_, child, frame, synchronous) =>
                            frame != null || synchronous ? child : fallback,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
