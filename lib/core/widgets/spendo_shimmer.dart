import 'package:flutter/material.dart';

/// Dark Obsidian shimmer color palette.
/// Highlights subtly from `#18181B` to `#27272A` and back to `#18181B`.
const Color kSpendoShimmerBaseColor = Color(0xFF18181B);
const Color kSpendoShimmerHighlightColor = Color(0xFF27272A);

/// An inherited scope for cascading shimmer properties to nested [SpendoShimmerCard]s.
class _SpendoShimmerScope extends InheritedWidget {
  const _SpendoShimmerScope({
    required super.child,
    required this.enabled,
    required this.baseColor,
    required this.highlightColor,
  });

  final bool enabled;
  final Color baseColor;
  final Color highlightColor;

  static _SpendoShimmerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SpendoShimmerScope>();
  }

  @override
  bool updateShouldNotify(_SpendoShimmerScope oldWidget) {
    return enabled != oldWidget.enabled ||
        baseColor != oldWidget.baseColor ||
        highlightColor != oldWidget.highlightColor;
  }
}

/// A high-performance, elegant Shimmer animation wrapper using pure Flutter.
///
/// Sweeps a smooth linear gradient across its child widget using [ShaderMask].
/// Designed specifically for the Spendo Dark Obsidian theme.
class SpendoShimmer extends StatefulWidget {
  /// The widget subtree across which the shimmer gradient will sweep.
  final Widget child;

  /// Base dark obsidian tone. Defaults to `#18181B`.
  final Color baseColor;

  /// Shimmer highlight tone. Defaults to `#27272A`.
  final Color highlightColor;

  /// Duration of one complete shimmer sweep cycle. Defaults to 1500ms.
  final Duration duration;

  /// Whether the shimmer animation is actively running.
  final bool enabled;

  const SpendoShimmer({
    super.key,
    required this.child,
    this.baseColor = kSpendoShimmerBaseColor,
    this.highlightColor = kSpendoShimmerHighlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  /// Check if the current context is inside a [SpendoShimmer].
  static bool isInShimmer(BuildContext context) {
    return _SpendoShimmerScope.maybeOf(context) != null;
  }

  @override
  State<SpendoShimmer> createState() => _SpendoShimmerState();
}

class _SpendoShimmerState extends State<SpendoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpendoShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SpendoShimmerScope(
      enabled: widget.enabled,
      baseColor: widget.baseColor,
      highlightColor: widget.highlightColor,
      child: widget.enabled
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: const Alignment(-1.0, -0.3),
                      end: const Alignment(1.0, 0.3),
                      colors: [
                        widget.baseColor,
                        widget.highlightColor,
                        widget.baseColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      tileMode: TileMode.clamp,
                      transform: _SlidingGradientTransform(
                        slidePercent: _controller.value,
                      ),
                    ).createShader(bounds);
                  },
                  child: child,
                );
              },
              child: widget.child,
            )
          : widget.child,
    );
  }
}

/// Custom gradient transform that slides the gradient along the horizontal axis.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Smooth translation across bounds: enters from left (-bounds.width) to right (+bounds.width)
    final double translationX = bounds.width * (-1.2 + 2.4 * slidePercent);
    return Matrix4.translationValues(translationX, 0.0, 0.0);
  }
}

/// A preset Obsidian Shimmer Card placeholder.
///
/// Automatically participates in an enclosing [SpendoShimmer] sweep animation,
/// or creates its own self-contained animation when used standalone.
class SpendoShimmerCard extends StatelessWidget {
  /// Width of the placeholder card. If null, expands to parent constraints.
  final double? width;

  /// Height of the placeholder card.
  final double? height;

  /// Border radius of the card. Defaults to 16.0 for modern obsidian cards.
  final BorderRadiusGeometry? borderRadius;

  /// Outer shape of the shimmer card (rectangle or circle).
  final BoxShape shape;

  /// Optional margin around the card.
  final EdgeInsetsGeometry? margin;

  /// Optional padding inside the card.
  final EdgeInsetsGeometry? padding;

  /// Optional custom border.
  final BoxBorder? border;

  /// Custom base color (overrides default `#18181B`).
  final Color? baseColor;

  /// Custom highlight color (overrides default `#27272A`).
  final Color? highlightColor;

  /// Optional child content inside the card.
  final Widget? child;

  const SpendoShimmerCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.padding,
    this.border,
    this.baseColor,
    this.highlightColor,
    this.child,
  });

  /// Preset for a circular placeholder (e.g. avatars, icon buttons).
  const SpendoShimmerCard.circular({
    super.key,
    required double size,
    this.margin,
    this.padding,
    this.border,
    this.baseColor,
    this.highlightColor,
    this.child,
  })  : width = size,
        height = size,
        shape = BoxShape.circle,
        borderRadius = null;

  /// Preset for a rectangular placeholder line (e.g. text skeletons).
  const SpendoShimmerCard.rectangular({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.margin,
    this.padding,
    this.border,
    this.baseColor,
    this.highlightColor,
    this.child,
  }) : shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    final scope = _SpendoShimmerScope.maybeOf(context);
    final effectiveBase = baseColor ?? scope?.baseColor ?? kSpendoShimmerBaseColor;
    final effectiveHighlight =
        highlightColor ?? scope?.highlightColor ?? kSpendoShimmerHighlightColor;

    final effectiveRadius = shape == BoxShape.circle
        ? null
        : (borderRadius ?? BorderRadius.circular(16));

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white, // Target alpha mask for ShaderMask
        shape: shape,
        borderRadius: effectiveRadius,
        border: border,
      ),
      child: child,
    );

    // If already inside an active SpendoShimmer parent, simply return the mask child.
    if (scope != null) {
      return cardContent;
    }

    // Otherwise, wrap in an independent SpendoShimmer instance.
    return SpendoShimmer(
      baseColor: effectiveBase,
      highlightColor: effectiveHighlight,
      child: cardContent,
    );
  }
}
