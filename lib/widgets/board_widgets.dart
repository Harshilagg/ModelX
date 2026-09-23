import 'package:flutter/material.dart';
import '../ui/app_type.dart';
import '../ui/board_theme.dart';

/// ---------------------------------------------------------------------
/// Split-flap tile
/// ---------------------------------------------------------------------

/// A single split-flap cell — the board's signature. Used for times and
/// statuses only, never for prose, so the flap seam always reads as
/// "this value can change" rather than as decoration.
class FlapTile extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final double fontSize;
  final EdgeInsets padding;

  /// "Open" carries no fill in this palette — it is the default state,
  /// not news — so it draws as an outline instead.
  final bool outlined;

  const FlapTile({
    super.key,
    required this.text,
    this.background = BoardColors.slate,
    this.foreground = BoardColors.onInk,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    this.outlined = false,
  });

  /// Maps an application or posting status onto the palette's three
  /// signals, so a status reads identically wherever it appears — board,
  /// notifications, jobs.
  ///
  /// The hues are fills, never text: all three sit in one lightness band
  /// so a mixed board reads flat, which only holds if nothing is tinted
  /// on top of them.
  factory FlapTile.status(String status, {double fontSize = 9}) {
    final s = status.trim().toLowerCase();

    Color bg = BoardColors.applied;
    Color fg = BoardColors.onInk;
    bool outlined = false;

    final isBooked =
        s.contains('book') ||
        s.contains('confirm') ||
        s.contains('accept') ||
        (s.contains('select') && !s.contains('not'));
    final isNegotiating =
        s.contains('callback') ||
        s.contains('shortlist') ||
        s.contains('invite') ||
        s.contains('negotiat') ||
        s.contains('review');
    final isRejected =
        s.contains('reject') ||
        s.contains('declin') ||
        s.contains('not selected') ||
        s.contains('closed');

    if (isBooked) {
      bg = BoardColors.booked;
      fg = BoardColors.onInk;
    } else if (isRejected) {
      bg = BoardColors.rejected;
      fg = BoardColors.onInk;
    } else if (isNegotiating) {
      bg = BoardColors.negotiating;
      fg = BoardColors.ink;
    } else if (s.contains('open')) {
      bg = Colors.transparent;
      fg = BoardColors.onInk;
      outlined = true;
    }

    return FlapTile(
      text: status,
      background: bg,
      foreground: fg,
      fontSize: fontSize,
      outlined: outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(BoardRadius.tile),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: background,
              border: outlined
                  ? Border.all(color: BoardColors.onInk.withValues(alpha: 0.45))
                  : null,
              borderRadius: BorderRadius.circular(BoardRadius.tile),
            ),
            padding: padding,
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.mono(
                fontSize: fontSize,
                color: foreground,
                letterSpacing: 0.55,
              ),
            ),
          ),
          // The flap seam, at the vertical midpoint of whatever height
          // the text ended up needing. An unfilled tile has no flap to
          // crease, so it gets no seam.
          if (!outlined)
            Positioned.fill(
              child: Center(
                child: Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// Labels, chips, rows
/// ---------------------------------------------------------------------

/// The mono eyebrow that opens every section.
class BoardSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;

  const BoardSectionLabel(this.text, {super.key, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: BoardType.sectionLabel(color: color),
    );

    if (trailing == null) return label;
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        trailing!,
      ],
    );
  }
}

/// A flat mono tag. [filled] paints it in the screen's accent; otherwise
/// it sits quietly in a well.
class MonoChip extends StatelessWidget {
  final String text;
  final bool filled;
  final Color accent;
  final bool onDark;
  final EdgeInsets padding;
  final double fontSize;

  /// A mushroom fill: present and selected, but carrying no signal. Used
  /// where a chip states a fact (a required look, a skill) rather than a
  /// status, so the three signal hues stay meaningful.
  final bool neutral;

  const MonoChip(
    this.text, {
    super.key,
    this.filled = false,
    this.accent = BoardColors.brass,
    this.onDark = false,
    this.neutral = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (neutral) {
      bg = BoardColors.mushroom;
      fg = BoardColors.ink;
    } else if (filled) {
      bg = accent;
      // Derived, not assumed. A filled chip can be brass, ink or a status
      // hue depending on the call site, and hardcoding ink text made an
      // ink-filled chip render invisibly against itself.
      fg = accent.computeLuminance() > 0.32
          ? BoardColors.ink
          : BoardColors.onInk;
    } else if (onDark) {
      bg = BoardColors.onInkWell;
      fg = BoardColors.onInk.withValues(alpha: 0.85);
    } else {
      bg = BoardColors.shell;
      fg = BoardColors.inkSoft;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BoardRadius.chip),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BoardType.mono(
          fontSize: fontSize,
          color: fg,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}

/// A `KEY — value` row: the spec-sheet primitive, used in job details and
/// in every profile sheet.
class SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final bool onDark;
  final bool topBorder;
  final bool bottomBorder;

  const SpecRow({
    super.key,
    required this.label,
    required this.value,
    this.onDark = false,
    this.topBorder = true,
    this.bottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final line = onDark ? BoardColors.onInkLine : BoardColors.inkLine;
    final keyColor = onDark ? BoardColors.onInkSoft : BoardColors.inkSoft;
    final valueColor = onDark ? BoardColors.onInk : BoardColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          top: topBorder ? BorderSide(color: line) : BorderSide.none,
          bottom: bottomBorder ? BorderSide(color: line) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: BoardType.mono(
                fontSize: 11,
                color: keyColor,
                letterSpacing: 0.66,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: BoardType.mono(
                fontSize: 11,
                color: valueColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled well — the small stat boxes in profile heroes and the
/// talent-requirement pair on a job detail.
class BoardStatWell extends StatelessWidget {
  final String label;
  final String value;
  final bool onDark;
  final bool flap;
  final double valueSize;

  const BoardStatWell({
    super.key,
    required this.label,
    required this.value,
    this.onDark = true,
    this.flap = true,
    this.valueSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(8),
      color: onDark ? BoardColors.slate : BoardColors.card,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BoardType.mono(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: onDark ? BoardColors.onInkFaint : BoardColors.inkSoft,
              letterSpacing: 0.72,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BoardType.mono(
              fontSize: valueSize,
              color: onDark ? BoardColors.onInk : BoardColors.ink,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: flap
          ? Stack(
              children: [
                content,
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: 1,
                      color: Colors.black.withValues(
                        alpha: onDark ? 0.5 : 0.08,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : content,
    );
  }
}

/// ---------------------------------------------------------------------
/// Spec sheet
/// ---------------------------------------------------------------------

/// The ink bottom sheet every "tap to open" spec row lifts. The body
/// scrolls and the whole sheet is height-capped, so a sheet with many
/// rows can never run past the screen.
Future<void> showBoardSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  Color accent = BoardColors.brass,

  /// Offers an EDIT action beside CLOSE. A spec sheet is where somebody
  /// notices a field is wrong, so it should also be where they can fix
  /// it — rather than sending them to a form at the foot of the page.
  VoidCallback? onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: BoardColors.scrim,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.82;
      return Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: BoardColors.ink,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BoardRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: BoardColors.onInk.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.display(
                          fontSize: 26,
                          color: BoardColors.onInk,
                          height: 1.0,
                        ),
                      ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onEdit();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: MonoChip(
                          'EDIT',
                          filled: true,
                          accent: accent,
                          fontSize: 9.5,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Close',
                          style: BoardType.mono(
                            fontSize: 11,
                            color: BoardColors.onInkSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// ---------------------------------------------------------------------
/// Media
/// ---------------------------------------------------------------------

/// A network image that degrades to the board's hatch fill instead of a
/// broken-image glyph, optionally cut to the comp-card silhouette.
class BoardMedia extends StatelessWidget {
  final String? url;
  final bool dark;
  final double? cut;
  final BorderRadius? radius;
  final Widget? overlay;
  final BoxFit fit;

  /// Where the crop is taken from.
  ///
  /// Defaults to the top, not the centre. These are photographs of people
  /// standing up: a centred cover crop on a full-length shot keeps the
  /// waist and throws away the face, which is the one part a booker is
  /// looking for.
  final Alignment alignment;

  const BoardMedia({
    super.key,
    this.url,
    this.dark = false,
    this.cut,
    this.radius,
    this.overlay,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url!.isNotEmpty)
          Image.network(
            url!,
            fit: fit,
            alignment: alignment,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : BoardHatch(dark: dark),
            errorBuilder: (_, __, ___) => BoardHatch(dark: dark),
          )
        else
          BoardHatch(dark: dark),
        if (overlay != null) overlay!,
      ],
    );

    if (cut != null) {
      content = ClipPath(
        clipper: CompCardClipper(cut: cut!),
        child: content,
      );
    } else if (radius != null) {
      content = ClipRRect(borderRadius: radius!, child: content);
    }
    return content;
  }
}

/// A circular portrait.
///
/// The board draws people two ways, and the shape is the distinction:
/// a **circle is a person** — an identity, in a hero or a list of people
/// you already know — while the **comp-card cut is their work**, a card
/// you are being asked to judge. Mixing them makes a contact row look
/// like a portfolio tile, which is how the network ended up reading as a
/// wall of assets rather than a list of humans.
class BoardAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  /// Draws the fallback against a dark band rather than paper.
  final bool onDark;

  /// A hairline so a dark photo doesn't bleed into an ink hero.
  final bool ring;

  const BoardAvatar({
    super.key,
    this.url,
    this.name = '',
    this.size = 44,
    this.onDark = false,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final hasImage = url != null && url!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring
            ? Border.all(
                color: onDark ? BoardColors.onInkLine : BoardColors.inkLine,
                width: 1,
              )
            : null,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                // Just above centre: a hard top clips the crown on a
                // headshot that is already framed tightly, but centring
                // loses the face on a full-length shot used as an avatar.
                alignment: const Alignment(0, -0.35),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _fallback(initial),
                errorBuilder: (_, __, ___) => _fallback(initial),
              )
            : _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) => Container(
    color: onDark ? BoardColors.slate : BoardColors.shell,
    alignment: Alignment.center,
    child: Text(
      initial,
      style: BoardType.title(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
        color: onDark ? BoardColors.onInk : BoardColors.inkSoft,
      ),
    ),
  );
}

/// ---------------------------------------------------------------------
/// Navigation chrome
/// ---------------------------------------------------------------------

/// The persistent top bar: your avatar, the search field, and the unread
/// message count. Shared by Home, Notifications, Network and Jobs.
class BoardTopBar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final String hint;
  final int unread;
  final VoidCallback? onAvatar;
  final VoidCallback? onSearch;
  final VoidCallback? onMessages;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const BoardTopBar({
    super.key,
    this.avatarUrl,
    this.initial = '?',
    this.hint = 'SEARCH USERS OR @USERNAME',
    this.unread = 0,
    this.onAvatar,
    this.onSearch,
    this.onMessages,
    this.controller,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatar,
            child: SizedBox(
              width: 30,
              height: 30,
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.35),
                        errorBuilder: (_, __, ___) => _initialAvatar(),
                      )
                    : _initialAvatar(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: BoardColors.shell,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BoardColors.inkSoft,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onTap: onSearch,
                      cursorColor: BoardColors.ink,
                      cursorHeight: 14,
                      style: BoardType.mono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.35,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle: BoardType.mono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: BoardColors.inkSoft,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Messages, with the unread count as a badge.
          //
          // This used to be the count on its own in a square box, which
          // said nothing about what it counted or where it went -- and
          // at zero it read as a broken counter rather than an inbox
          // with nothing in it. The badge is hidden at zero for the
          // same reason.
          Semantics(
            button: true,
            label: unread == 0 ? 'Messages' : 'Messages, $unread unread',
            child: GestureDetector(
              onTap: onMessages,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                // The visible mark is 30px; the tap target is not.
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 22,
                      color: BoardColors.ink,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 6,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: BoardColors.rejected,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            textAlign: TextAlign.center,
                            style: AppType.tabular(
                              fontSize: 10,
                              color: BoardColors.onInk,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar() => Container(
    color: BoardColors.ink,
    alignment: Alignment.center,
    child: Text(
      initial.toUpperCase(),
      style: BoardType.mono(fontSize: 11, color: BoardColors.onInk),
    ),
  );
}

/// The floating pill nav. Five destinations, drawn as shapes rather than
/// Material glyphs so the bar keeps the board's flat, geometric voice.
/// The active item takes that screen's accent — this is the one place
/// where all four accents are allowed to appear over a session.
class BoardNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The accent for the active destination.
  final Color accent;

  const BoardNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.accent = BoardColors.brass,
  });

  static const _labels = [
    'Home',
    'Notifications',
    'Network',
    'Jobs',
    'Profile',
  ];

  /// The bar's laid-out height: 11dp of container padding top and bottom
  /// around the tallest destination (the 34dp "me" circle plus its own
  /// 6dp touch padding). The glyphs are drawn shapes rather than text, so
  /// this doesn't move with the system font scale — which is what lets
  /// the shell position the copilot above the bar without measuring it.
  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BoardColors.slate,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final active = i == currentIndex;
          final color = active ? accent : BoardColors.onInkFaint;
          return Semantics(
            label: _labels[i],
            selected: active,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                // Widens the touch target to ~44px without widening the
                // painted glyph.
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                child: i == 4
                    ? Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? accent : BoardColors.onInkWell,
                        ),
                        child: ClipPath(
                          clipper: const CompCardClipper(cut: 5),
                          child: Container(
                            width: 14,
                            height: 17,
                            color: active
                                ? BoardColors.ink
                                : BoardColors.onInkFaint,
                          ),
                        ),
                      )
                    : _glyph(i, color),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _glyph(int i, Color color) {
    switch (i) {
      case 0: // Home — a pentagon roofline.
        return CustomPaint(
          size: const Size(17, 15),
          painter: _HousePainter(color),
        );
      case 1: // Notifications — bell + clapper.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(3),
                ),
              ),
            ),
          ],
        );
      case 2: // Network — two heads.
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 2),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        );
      default: // Jobs — a case with a handle.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 19,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        );
    }
  }
}

class _HousePainter extends CustomPainter {
  final Color color;
  _HousePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.45)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height * 0.45)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HousePainter oldDelegate) => oldDelegate.color != color;
}

/// The screen title block — oversized condensed title with a mono count
/// on the right, used on Notifications, Network and Jobs.
class BoardScreenTitle extends StatelessWidget {
  final String title;
  final String? meta;
  final EdgeInsets padding;

  const BoardScreenTitle({
    super.key,
    required this.title,
    this.meta,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BoardType.display(fontSize: 34, height: 0.9),
            ),
          ),
          if (meta != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                meta!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: BoardType.mono(
                  fontSize: 9.5,
                  color: BoardColors.inkSoft,
                  letterSpacing: 0.95,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The underlined tab rail used on both profiles (4a / 7d).
class BoardTabRail extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onTap;
  final Color accent;

  const BoardTabRail({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTap,
    this.accent = BoardColors.brass,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BoardColors.inkLine)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 13, 2, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BoardType.title(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: active ? BoardColors.ink : BoardColors.inkSoft,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// The full-width ink action button that closes a screen (Edit Profile,
/// Message, Continue).
class BoardButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool outlined;
  final bool square;

  const BoardButton({
    super.key,
    required this.label,
    this.onTap,
    this.background = BoardColors.ink,
    this.foreground = BoardColors.onInk,
    this.outlined = false,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : background,
            borderRadius: BorderRadius.circular(square ? 0 : 26),
            border: outlined
                ? Border.all(
                    color: foreground.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          // A Row, not `alignment: Alignment.center`. Container's
          // alignment becomes an Align, and an Align with no size factors
          // takes the biggest height it is offered — which in a Scaffold's
          // bottomNavigationBar slot is the entire screen, leaving the
          // body zero height. A Row centres on the cross axis while still
          // shrink-wrapping vertically to the label.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BoardType.title(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.35,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
