import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/app_type.dart';
import '../ui/board_theme.dart';
import '../widgets/kit/kit.dart';
import 'masonry_background.dart';
import 'onboarding_theme.dart';

/// The product name, in one place.
///
/// The prototypes were inconsistent -- the splash said one thing and the
/// login another -- so it is a constant rather than a string typed into
/// six screens.
const String kWordmark = 'ModelX';

class SplashSlide {
  final String title;
  final String subtitle;
  const SplashSlide(this.title, this.subtitle);
}

/// The first screen a new user sees.
///
/// Replaces the old three-slide gradient onboarding. Both ways out --
/// create an account, and log in -- are present from the first slide, so
/// the carousel never stands between a returning user and the login
/// form.
class SplashPage extends StatefulWidget {
  final VoidCallback onCreateAccount;
  final VoidCallback onLogIn;

  const SplashPage({
    super.key,
    required this.onCreateAccount,
    required this.onLogIn,
  });

  static const Duration slideDuration = Duration(seconds: 4);

  static const List<SplashSlide> slides = [
    SplashSlide('Talent moves\nthe world.', 'People. Brands. Opportunities.'),
    SplashSlide(
      'More than\na profile.',
      'Build your presence. Showcase your work. Get discovered.',
    ),
    SplashSlide(
      'Where casting\nbegins.',
      'Models. Brands. Agencies. Creatives.',
    ),
  ];

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int _index = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  /// Advances until the last slide, then stops.
  ///
  /// A carousel that loops forever gives no sense of how much there is,
  /// and someone who looks away comes back to the same three slides
  /// cycling. Stopping on the last is the prototype's behaviour and the
  /// right one.
  void _schedule() {
    _timer?.cancel();
    if (AppMotion.reduced(context)) return;
    if (_index >= SplashPage.slides.length - 1) return;
    _timer = Timer(SplashPage.slideDuration, () {
      if (mounted) _goTo(_index + 1);
    });
  }

  void _goTo(int next) {
    final clamped = next.clamp(0, SplashPage.slides.length - 1);
    if (clamped == _index) return;
    setState(() => _index = clamped);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final slide = SplashPage.slides[_index];

    return OnboardingTheme(
      child: Scaffold(
        backgroundColor: p.surface,
        body: GestureDetector(
          // Threshold rather than velocity: a slow deliberate drag
          // should still turn the page.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -60) _goTo(_index + 1);
            if (v > 60) _goTo(_index - 1);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: MasonryBackground()),

              // Darkens the top so the progress rail and wordmark read,
              // leaves a clear window through the middle, and goes solid
              // behind the copy. Without the solid foot, headline text
              // lands on whatever photo happens to be passing.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.14, 0.34, 0.58, 0.74],
                        colors: [
                          p.surface.withValues(alpha: 0.70),
                          p.surface.withValues(alpha: 0),
                          p.surface.withValues(alpha: 0),
                          p.surface.withValues(alpha: 0.90),
                          p.surface,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _Header(
                      index: _index,
                      total: SplashPage.slides.length,
                      onJump: _goTo,
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppMetrics.gutter,
                        0,
                        AppMetrics.gutter,
                        AppMetrics.bottomInset(context, minimum: 28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SlideCopy(key: ValueKey(_index), slide: slide),
                          const SizedBox(height: 28),
                          AppPillButton(
                            label: 'Create an account',
                            onPressed: widget.onCreateAccount,
                          ),
                          const SizedBox(height: 10),
                          AppPillButton(
                            label: 'Log in',
                            kind: AppButtonKind.outlined,
                            onPressed: widget.onLogIn,
                          ),
                          const SizedBox(height: 16),
                          const _TermsLine(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int index;
  final int total;
  final ValueChanged<int> onJump;

  const _Header({
    required this.index,
    required this.total,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        12,
        AppMetrics.gutter,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: AppMetrics.progressGap),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Slide ${i + 1} of $total',
                    child: GestureDetector(
                      onTap: () => onJump(i),
                      behavior: HitTestBehavior.opaque,
                      // The visible rail is 2px; the tappable area is
                      // not, or these would be impossible to hit.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: AnimatedContainer(
                          duration: AppMotion.medium,
                          height: AppMetrics.progressBar,
                          decoration: BoxDecoration(
                            color: i <= index
                                ? p.onSurface
                                : p.onSurface.withValues(alpha: 0.25),
                            borderRadius: AppRadii.pill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kWordmark.toUpperCase(),
            style: AppType.label(
              fontSize: 15,
              color: p.onSurface,
            ).copyWith(letterSpacing: 5.1),
          ),
        ],
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  final SplashSlide slide;

  const _SlideCopy({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final reduced = AppMotion.reduced(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 360),
      curve: AppMotion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slide.title,
            style: AppType.display(fontSize: 40, color: p.onSurface),
          ),
          const SizedBox(height: 12),
          // Reserved height, so the buttons below do not jump when one
          // slide's subtitle wraps to two lines and the next does not.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Text(
              slide.subtitle,
              style: AppType.body(color: p.onSurfaceSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsLine extends StatelessWidget {
  const _TermsLine();

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Text(
      'By continuing you agree to our Terms and Privacy Policy.',
      textAlign: TextAlign.center,
      style: AppType.caption(color: p.onSurfaceFaint),
    );
  }
}
