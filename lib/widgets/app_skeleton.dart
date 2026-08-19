import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// A shimmering placeholder shape — the app's skeleton-loading
/// primitive. Prefer this over a bare spinner ([LoadingState] in
/// `state_views.dart`) whenever a screen's real content shape is
/// already known (a list of cards, a profile header, a row of
/// avatars) — "no bare spinners" wherever the layout can be shown
/// before the data arrives.
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
  });

  factory AppSkeleton.circle(double size) => AppSkeleton(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );

  /// A single card-shaped placeholder, matching `AppCard`'s radius.
  static Widget card({double height = 140}) {
    return AppSkeleton(height: height, borderRadius: BorderRadius.circular(AppRadius.lg));
  }

  /// An avatar beside two text lines — for post/comment/chat rows
  /// before their real data arrives.
  static Widget avatarRow({double avatarSize = 40}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppSkeleton.circle(avatarSize),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSkeleton(width: 120, height: 13),
              const SizedBox(height: 6),
              const AppSkeleton(width: 80, height: 11),
            ],
          ),
        ),
      ],
    );
  }

  /// A single `ListTile`-shaped row (leading circle + two lines).
  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          AppSkeleton.circle(44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                AppSkeleton(width: double.infinity, height: 14),
                SizedBox(height: 6),
                AppSkeleton(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [lines] stacked text-line placeholders, the last one shorter so
  /// the block doesn't look like a rigid grid.
  static Widget text({int lines = 3, double lineHeight = 12}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
          child: AppSkeleton(width: isLast ? 140 : double.infinity, height: lineHeight),
        );
      }),
    );
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: AppColors.paperRaised, borderRadius: widget.borderRadius),
    );

    if (MediaQuery.of(context).disableAnimations) return base;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 - t * 2, 0),
            end: Alignment(1 - t * 2, 0),
            colors: const [AppColors.paperRaised, AppColors.line, AppColors.paperRaised],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: base,
        );
      },
    );
  }
}
