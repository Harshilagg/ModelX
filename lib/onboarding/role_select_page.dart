import 'package:flutter/material.dart';

import '../ui/app_type.dart';
import '../widgets/kit/kit.dart';
import 'onboarding_theme.dart';
import 'splash_page.dart' show kWordmark;

/// Which kind of account is being created.
enum SignupRole {
  model,
  brand,
  agency;

  String get label => switch (this) {
    SignupRole.model => 'Model',
    SignupRole.brand => 'Brand',
    SignupRole.agency => 'Agency',
  };

  String get category => switch (this) {
    SignupRole.model => 'Talent',
    SignupRole.brand => 'Business',
    SignupRole.agency => 'Management',
  };

  String get blurb => switch (this) {
    SignupRole.model =>
      'Build your profile. Showcase your work. Get discovered by the right people.',
    SignupRole.brand =>
      'Find talent. Create castings. Build campaigns with the right creative people.',
    SignupRole.agency =>
      'Manage talent. Discover opportunities. Streamline your casting workflow.',
  };

  String get photo => switch (this) {
    SignupRole.model => OnboardingPhotos.model,
    SignupRole.brand => OnboardingPhotos.brand,
    SignupRole.agency => OnboardingPhotos.agency,
  };

  /// Where to crop the photograph vertically.
  ///
  /// Per role rather than a single value: the supplied images put their
  /// subject at different heights, and a card collapsed to 100-odd
  /// points shows only a narrow band, so one global crop point would
  /// leave at least one card showing an empty wall.
  Alignment get crop => switch (this) {
    // A wide studio scene with the sitter around the middle.
    SignupRole.model => const Alignment(0, 0.15),
    // Heads and shoulders sit high in the frame.
    SignupRole.brand => const Alignment(0, -0.25),
    // An all-over texture of polaroids; any band reads.
    SignupRole.agency => Alignment.center,
  };

  /// The stored `userType` for this role.
  ///
  /// Capitalised because that is what existing documents contain.
  /// Normalising it would be a data migration, which this is not.
  String get userType => switch (this) {
    SignupRole.model => 'Model',
    SignupRole.brand => 'Brand',
    SignupRole.agency => 'Agency',
  };
}

/// "How will you use ModelX?"
///
/// Replaces the three flat cards of the old portfolio picker. Choosing
/// is a two-step gesture on purpose: tapping a card only selects it, and
/// the button at the bottom commits. A single tap that navigated made it
/// far too easy to land in the wrong signup from a mis-tap, and there is
/// no way back out of signup without losing what you typed.
class RoleSelectPage extends StatefulWidget {
  final ValueChanged<SignupRole> onSelected;
  final VoidCallback onBack;
  final VoidCallback? onLogIn;

  const RoleSelectPage({
    super.key,
    required this.onSelected,
    required this.onBack,
    this.onLogIn,
  });

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  SignupRole _selected = SignupRole.model;

  void _move(int delta) {
    final next = (_selected.index + delta).clamp(
      0,
      SignupRole.values.length - 1,
    );
    if (next != _selected.index) {
      setState(() => _selected = SignupRole.values[next]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;

    return OnboardingTheme(
      child: Scaffold(
        backgroundColor: p.surface,
        body: SafeArea(
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -60) _move(1);
              if (v > 60) _move(-1);
            },
            child: Column(
              children: [
                _Header(onBack: widget.onBack, onLogIn: widget.onLogIn),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    16,
                    AppMetrics.gutter,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How will you use $kWordmark?',
                        style: AppType.display(
                          // At 30 this wraps to three lines on a
                          // 360pt phone, which both looks wrong and
                          // squeezes the cards below it off the screen.
                          fontSize: MediaQuery.sizeOf(context).width < 380
                              ? 26
                              : 30,
                          color: p.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pick one to set up your account.',
                        style: AppType.body(color: p.onSurfaceSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Semantics(
                      container: true,
                      label: 'Account type',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Flex on an Expanded is an int and relayouts
                          // instantly, so the accordion is driven by
                          // explicit heights instead. The chosen card
                          // takes 2.2 shares against 1 each for the
                          // other two, which is the prototype's ratio.
                          const gap = 8.0;
                          const floor = 76.0;
                          final free =
                              constraints.maxHeight -
                              gap * (SignupRole.values.length - 1);

                          // The three heights must add up to exactly
                          // the space available. Giving each card a
                          // minimum independently does not work: on a
                          // short phone the floors sum to more than
                          // there is and the overflow simply moves up
                          // to the parent. So when the ratio would put
                          // an unselected card below the floor, the
                          // selected card gives up the difference.
                          var plain = free / 4.2;
                          var grown = plain * 2.2;
                          if (plain < floor) {
                            plain = floor;
                            grown = free - plain * 2;
                            if (grown < floor) {
                              // Genuinely no room to tell them apart.
                              plain = grown = free / 3;
                            }
                          }

                          return Column(
                            children: [
                              for (final role in SignupRole.values) ...[
                                if (role.index > 0) const SizedBox(height: gap),
                                _RoleCard(
                                  role: role,
                                  selected: role == _selected,
                                  height: role == _selected ? grown : plain,
                                  onTap: () => setState(() => _selected = role),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    16,
                    AppMetrics.gutter,
                    AppMetrics.bottomInset(context, minimum: 24),
                  ),
                  child: Column(
                    children: [
                      // Reserved height so the button does not shift as
                      // blurbs of different lengths swap in.
                      ConstrainedBox(
                        // Capped at three lines as well as reserved
                        // for three, so a long blurb cannot push the
                        // button off a short screen.
                        constraints: const BoxConstraints(minHeight: 63),
                        child: Text(
                          _selected.blurb,
                          key: ValueKey(_selected),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(
                            fontSize: 14,
                            color: p.onSurfaceSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppPillButton(
                        label: 'Continue as ${_selected.label.toLowerCase()}',
                        onPressed: () => widget.onSelected(_selected),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onLogIn;

  const _Header({required this.onBack, this.onLogIn});

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.chevron_left,
            onPressed: onBack,
            semanticLabel: 'Go back',
          ),
          Expanded(
            child: Text(
              kWordmark.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppType.label(
                color: p.onSurface,
              ).copyWith(letterSpacing: 4.4),
            ),
          ),
          // A fixed 44 here balanced the back button so the wordmark
          // sat centred -- but it also clamped the button to 44 wide
          // when there was one, and "Log in" wrapped to a letter a
          // line. The width is a floor now, not a cap.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppMetrics.tapTarget),
            child: onLogIn == null
                ? const SizedBox(height: AppMetrics.tapTarget)
                : Semantics(
                    button: true,
                    label: 'Log in',
                    child: GestureDetector(
                      onTap: onLogIn,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.pill,
                          border: Border.all(color: p.lineStrong),
                        ),
                        child: Text(
                          'Log in',
                          maxLines: 1,
                          softWrap: false,
                          style: AppType.label(color: p.onSurface),
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

/// One role, as a photograph that comes alive when chosen.
///
/// The selected card grows to roughly twice the height of the other two
/// and its photograph resolves from black-and-white into colour. It is
/// the same gesture as the splash spotlight, which is why they share
/// [GreyscaleReveal].
class _RoleCard extends StatelessWidget {
  final SignupRole role;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    final reduced = AppMotion.reduced(context);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${role.label}. ${role.blurb}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AppMotion.slow,
          curve: AppMotion.settle,
          height: height < 76 ? 76 : height,
          child: ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GreyscaleReveal(
                  amount: selected ? 1 : 0,
                  // Unselected cards sit further down than the masonry
                  // does, so the chosen one clearly wins.
                  dimmedBrightness: 0.55,
                  child: Image.asset(
                    role.photo,
                    fit: BoxFit.cover,
                    alignment: role.crop,
                    errorBuilder: (_, __, ___) =>
                        ColoredBox(color: p.surfaceField),
                  ),
                ),

                // The supplied photographs are high-key -- bright
                // studio white -- and the prototype's bottom-only
                // gradient assumed dark, moody images. Without a veil
                // at the top the frame number and the radio dot land
                // on white and vanish.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.32, 0.62, 1],
                        colors: [
                          p.ink.withValues(alpha: 0.55),
                          p.ink.withValues(alpha: 0.12),
                          p.ink.withValues(alpha: 0.42),
                          p.ink.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),

                // Positioned rather than a Column with a Spacer: a
                // collapsed card is only 76pt tall and the two rows plus
                // padding want slightly more than that, which a Column
                // reports as an overflow. Raising the minimum height
                // instead just moves the overflow up to the parent,
                // because the three card heights have to sum to the
                // space available.
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Row(
                    children: [
                      Text(
                        (role.index + 1).toString().padLeft(2, '0'),
                        style: AppType.tabular(
                          fontSize: 12,
                          color: p.onPanel.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      _RadioDot(selected: selected),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          role.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.display(
                            fontSize: 26,
                            color: p.onPanel,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: AppMotion.medium,
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 7, bottom: 4),
                          decoration: BoxDecoration(
                            // Brass on all three. The prototype
                            // gave brand and agency the green and
                            // amber of the status palette, which
                            // would teach the wrong association on
                            // the very first screen a user sees.
                            color: p.brass,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          role.category,
                          style: AppType.label(
                            color: p.onPanel.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Inside the clip so the ring cannot be cut by the
                // card's own rounded corners.
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(
                        color: p.onPanel.withValues(
                          alpha: selected ? 0.85 : 0.08,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = OnboardingTheme.palette;
    return AnimatedContainer(
      duration: AppMotion.medium,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.onPanel : Colors.transparent,
        border: Border.all(
          color: selected ? p.onPanel : p.onPanel.withValues(alpha: 0.45),
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 15, color: p.ink)
          : const SizedBox.shrink(),
    );
  }
}
