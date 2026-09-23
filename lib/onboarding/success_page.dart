import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/app_type.dart';
import '../ui/board_theme.dart';
import '../widgets/kit/kit.dart';
import 'onboarding_theme.dart';

enum SuccessRole { model, brand, agency }

/// The screen after an account is made.
///
/// It exists to answer the question people actually have at this point,
/// which is not "did that work" but "what now". So the headline is short
/// and most of the screen is three concrete next steps.
class SuccessPage extends StatelessWidget {
  final SuccessRole role;

  /// The user's own first photograph, if they added one. It turns from
  /// black-and-white into colour, which is the same gesture the splash
  /// and the role picker use -- here it is their picture rather than a
  /// stock one.
  final String? photoUrl;

  final VoidCallback onContinue;

  const SuccessPage({
    super.key,
    required this.role,
    required this.onContinue,
    this.photoUrl,
  });

  (String, String, String, List<String>) get _copy => switch (role) {
    SuccessRole.model => (
      "You're all set.",
      'Your profile is live. A few more steps and '
          "you're ready for your first casting.",
      'Explore castings',
      [
        'Add more photos to your portfolio',
        'Apply to castings that fit you',
        "Follow agencies you'd like to work with",
      ],
    ),
    SuccessRole.brand => (
      'Welcome aboard.',
      "Your brand account is ready. Here's how to find your first talent.",
      'Browse talent',
      [
        'Post your first casting',
        'Browse and shortlist talent',
        'Complete your brand page',
      ],
    ),
    SuccessRole.agency => (
      'Your agency is live.',
      "Your agency account is ready. Here's how to get started.",
      'Go to dashboard',
      [
        'Add models to your roster',
        'Share castings with your talent',
        'Complete your agency page',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final (title, subtitle, cta, next) = _copy;

    return OnboardingTheme(
      child: Scaffold(
        backgroundColor: p.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.gutter,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Mark(role: role, photoUrl: photoUrl),
                      const SizedBox(height: 28),
                      _Rise(
                        delay: const Duration(milliseconds: 500),
                        child: Text(
                          title,
                          style: AppType.display(color: p.onSurface),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Rise(
                        delay: const Duration(milliseconds: 600),
                        child: Text(
                          subtitle,
                          style: AppType.body(
                            fontSize: 16,
                            color: p.onSurfaceSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _Rise(
                        delay: const Duration(milliseconds: 720),
                        child: _WhatsNext(steps: next),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppMetrics.gutter,
                  8,
                  AppMetrics.gutter,
                  AppMetrics.bottomInset(context, minimum: 24),
                ),
                child: _Rise(
                  delay: const Duration(milliseconds: 850),
                  child: AppPillButton(label: cta, onPressed: onContinue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsNext extends StatelessWidget {
  final List<String> steps;
  const _WhatsNext({required this.steps});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's next",
          style: AppType.label(color: p.onSurface.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: p.line),
              bottom: BorderSide(color: p.line),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: p.line)),
                        ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: AppType.tabular(color: p.onSurfaceFaint),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: AppType.body(color: p.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Either the user's photograph turning to colour, or a tick that draws
/// itself.
class _Mark extends StatelessWidget {
  final SuccessRole role;
  final String? photoUrl;

  const _Mark({required this.role, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    if (photoUrl == null) {
      return _DrawnTick(colour: p.onSurface);
    }

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            // A model's photograph is a portrait crop like the rest of
            // their portfolio; a brand or agency reads as a logo.
            borderRadius: role == SuccessRole.model
                ? BorderRadius.circular(18)
                : BorderRadius.circular(48),
            child: _DelayedReveal(
              child: Image.network(
                photoUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: p.surfaceField),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: p.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: p.surface, width: 2),
              ),
              child: Icon(Icons.check, size: 16, color: p.surface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds the photo grey for a beat, then lets the colour in.
class _DelayedReveal extends StatefulWidget {
  final Widget child;
  const _DelayedReveal({required this.child});

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) => GreyscaleReveal(
    amount: _revealed ? 1 : 0,
    dimmedBrightness: 0.7,
    duration: const Duration(milliseconds: 1200),
    child: widget.child,
  );
}

/// The circle-and-tick, drawn rather than faded in.
class _DrawnTick extends StatefulWidget {
  final Color colour;
  const _DrawnTick({required this.colour});

  @override
  State<_DrawnTick> createState() => _DrawnTickState();
}

class _DrawnTickState extends State<_DrawnTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _TickPainter(progress: _c.value, colour: widget.colour),
      ),
    ),
  );
}

class _TickPainter extends CustomPainter {
  final double progress;
  final Color colour;

  const _TickPainter({required this.progress, required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    // The ring draws first and the tick follows, so it reads as being
    // written rather than appearing.
    final ring = ((progress - 0.125) / 0.583).clamp(0.0, 1.0);
    final tick = ((progress - 0.625) / 0.35).clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - 1,
        ),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        paint
          ..color = colour.withValues(alpha: 0.4)
          ..strokeWidth = 1.5,
      );
    }

    if (tick > 0) {
      final w = size.width;
      final a = Offset(w * 0.30, w * 0.51);
      final b = Offset(w * 0.44, w * 0.65);
      final c = Offset(w * 0.71, w * 0.37);

      // The two legs are drawn in sequence along one length, so the
      // stroke does not jump at the corner.
      final firstLeg = (b - a).distance;
      final total = firstLeg + (c - b).distance;
      final drawn = total * tick;

      final path = Path()..moveTo(a.dx, a.dy);
      if (drawn <= firstLeg) {
        final t = drawn / firstLeg;
        path.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
      } else {
        path.lineTo(b.dx, b.dy);
        final t = (drawn - firstLeg) / (total - firstLeg);
        path.lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
      }

      canvas.drawPath(
        path,
        paint
          ..color = colour
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.colour != colour;
}

/// Fades and lifts its child after a delay, so the screen arrives in
/// order rather than all at once.
class _Rise extends StatelessWidget {
  final Duration delay;
  final Widget child;

  const _Rise({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520) + delay,
      curve: Interval(
        delay.inMilliseconds / (520 + delay.inMilliseconds),
        1,
        curve: AppMotion.settle,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
