import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The five comp card templates.
///
/// Each is its own piece of design — own typeface pairing, own palette,
/// own rhythm — not a recolour of the app. That is the point: a comp card
/// leaves the app and is judged next to cards from every other agency, so
/// it should look like print, not like a screen.
///
/// All five take the same data, so switching template costs nothing.
enum CompCardTemplate {
  maison(
    label: 'Maison',
    blurb: 'Bodoni Moda + Jost · ivory and black · couture and beauty',
    backShots: 4,
  ),
  grid(
    label: 'Grid',
    blurb: 'Space Grotesk + Space Mono · one red rule · Swiss booking sheet',
    backShots: 5,
  ),
  runway(
    label: 'Runway',
    blurb: 'Instrument Serif + Jost · warm stone · fashion and editorial',
    backShots: 3,
  ),
  range(
    label: 'Range',
    blurb: 'DM Sans + DM Mono · cream and terracotta · commercial and acting',
    backShots: 6,
  ),
  signal(
    label: 'Signal',
    blurb:
        'Syne + JetBrains Mono · carbon and chartreuse · made to be forwarded',
    backShots: 4,
  );

  const CompCardTemplate({
    required this.label,
    required this.blurb,
    required this.backShots,
  });

  final String label;
  final String blurb;

  /// How many shots this template's reverse is designed around. The
  /// front always takes one.
  final int backShots;

  int get totalShots => backShots + 1;
}

/// The named slots a comp card fills, in order. Slot 0 is the front.
///
/// Templates draw whatever their design calls for; this is the vocabulary
/// the model assigns photographs with, so "which one is the headshot" is
/// a decision they make rather than a consequence of tap order.
const compCardSlots = <String>[
  'HEADSHOT',
  'FULL LENGTH',
  'PROFILE',
  'EDITORIAL',
  'LIFESTYLE',
  'BEAUTY',
  'SMILE',
];

/// How ready a profile is to print a comp card.
///
/// One definition, used by the tool, the profile's spec sheet and the
/// Network nudge — they used to compute three different numbers from
/// three different field lists, so the same card could be "38% ready" on
/// one screen and "75%" on another.
///
/// Scored only on fields the five templates actually print. Weight, for
/// instance, appears on no card, so filling it in shouldn't move a number
/// that claims to describe the card.
class CompCardReadiness {
  const CompCardReadiness._();

  /// Field key → the name a model would recognise.
  static const printed = <String, String>{
    'height': 'Height',
    'measurements': 'Bust, waist, hips',
    'shoeSize': 'Shoe size',
    'hairColor': 'Hair colour',
    'eyeColor': 'Eye colour',
    'location': 'City',
    'contact': 'Phone',
    'username': 'Handle',
  };

  static bool _has(Map<String, dynamic> user, String key) {
    final raw = (user[key] ?? '').toString().trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') return true;

    // Measurements can arrive either as the free-text triple or as the
    // separate waist and hips fields; the card prints the same either way.
    if (key == 'measurements') {
      return _has(user, 'waist') && _has(user, 'hips');
    }
    return false;
  }

  /// 0–100 across the printed fields.
  static int statsPercent(Map<String, dynamic> user) {
    final filled = printed.keys.where((k) => _has(user, k)).length;
    return (filled / printed.length * 100).round();
  }

  /// The human-readable names of what's still missing, so a nudge can say
  /// what to do rather than only how far along you are.
  static List<String> missing(Map<String, dynamic> user) => [
    for (final entry in printed.entries)
      if (!_has(user, entry.key)) entry.value,
  ];
}

/// Everything the five cards print, resolved once from the profile.
///
/// No field here is invented: each maps to a key the `users` document
/// already stores, and anything missing prints as an em dash rather than
/// collapsing the layout.
class CompCardData {
  final String name;
  final String city;
  final String agency;
  final String handle;
  final String phone;
  final String height;
  final String bust;
  final String waist;
  final String hips;
  final String shoe;
  final String hair;
  final String eyes;
  final List<String?> images;

  const CompCardData({
    required this.name,
    required this.city,
    required this.agency,
    required this.handle,
    required this.phone,
    required this.height,
    required this.bust,
    required this.waist,
    required this.hips,
    required this.shoe,
    required this.hair,
    required this.eyes,
    required this.images,
  });

  static const dash = '—';

  static String _clean(dynamic v) {
    final s = (v ?? '').toString().trim();
    return (s.isEmpty || s.toLowerCase() == 'null') ? '' : s;
  }

  /// Reads a bust/waist/hips triple out of the free-text `measurements`
  /// field when it looks like one ("82-60-88", "82 / 60 / 88").
  ///
  /// There is no separate bust field on the profile, and adding one would
  /// touch the backend — so this reads what models already type rather
  /// than asking them to type it twice.
  static List<String> _triple(String measurements) {
    final numbers = RegExp(
      r'\d+',
    ).allMatches(measurements).map((m) => m.group(0)!).toList();
    return numbers.length >= 3 ? numbers.take(3).toList() : const [];
  }

  factory CompCardData.fromUser(
    Map<String, dynamic> user, {
    required List<String?> images,
  }) {
    final measurements = _clean(user['measurements']);
    final triple = _triple(measurements);

    final waist = triple.isNotEmpty ? triple[1] : _clean(user['waist']);
    final hips = triple.isNotEmpty ? triple[2] : _clean(user['hips']);
    final bust = triple.isNotEmpty ? triple[0] : '';

    final height = _clean(user['height']);
    final heightUnit = _clean(user['heightUnit']);
    final shoe = _clean(user['shoeSize']);
    final shoeUnit = _clean(user['shoeSizeUnit']);

    final agencies = user['agencies'];
    final agency = agencies is List && agencies.isNotEmpty
        ? _clean(agencies.first)
        : _clean(agencies);

    var name = _clean(user['fullName']);
    if (name.isEmpty) {
      name = [
        _clean(user['firstName']),
        _clean(user['lastName']),
      ].where((s) => s.isNotEmpty).join(' ');
    }

    String or(String v) => v.isEmpty ? dash : v;

    return CompCardData(
      name: name.isEmpty ? 'Your Name' : name,
      city: or(_clean(user['location'])),
      agency: agency.isEmpty ? 'The Board' : agency,
      handle: _clean(user['username']).isEmpty
          ? dash
          : '@${_clean(user['username'])}',
      phone: or(_clean(user['contact'])),
      height: height.isEmpty
          ? dash
          : (heightUnit.isEmpty
                ? height
                : '$height ${heightUnit.toUpperCase()}'),
      bust: or(bust),
      waist: or(waist),
      hips: or(hips),
      shoe: shoe.isEmpty
          ? dash
          : (shoeUnit.isEmpty ? shoe : '$shoe ${shoeUnit.toUpperCase()}'),
      hair: or(_clean(user['hairColor'])).toUpperCase(),
      eyes: or(_clean(user['eyeColor'])).toUpperCase(),
      images: images,
    );
  }

  String? shot(int index) =>
      (index >= 0 && index < images.length) ? images[index] : null;

  /// Height without its unit — the stat grids label the row already, and
  /// "175 CM" in a four-up cell wraps where "175" does not.
  String get heightNumber {
    final match = RegExp(r'[\d.]+').firstMatch(height);
    return match?.group(0) ?? height;
  }
}

/// One face of one card, drawn at true trim: 396 × 612 px is 5.5 × 8.5 in
/// at 72 px to the inch, the standard comp card size.
///
/// Fixed size on purpose — [CompCardFace] scales it to whatever space it
/// is given, so a thumbnail and a full-bleed preview are the same
/// drawing and can never drift apart.
class CompCardFaceView extends StatelessWidget {
  final CompCardTemplate template;
  final CompCardData data;
  final bool back;

  const CompCardFaceView({
    super.key,
    required this.template,
    required this.data,
    this.back = false,
  });

  static const trimWidth = 396.0;
  static const trimHeight = 612.0;
  static const aspect = trimWidth / trimHeight;

  @override
  Widget build(BuildContext context) {
    // MediaQuery is neutralised inside the card: this is print, and a
    // system font scale must not reflow a 5.5 × 8.5 in layout.
    return MediaQuery.withNoTextScaling(
      // A comp card is a print object and has to render identically in
      // any host. Without text defaults of its own it inherits
      // DefaultTextStyle.fallback(), which draws a yellow double
      // underline under every string -- harmless inside a Scaffold,
      // which supplies its own, and baked into the PDF when the card is
      // captured outside one.
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        child: SizedBox(
          width: trimWidth,
          height: trimHeight,
          child: switch (template) {
            CompCardTemplate.maison => back ? _maisonBack() : _maisonFront(),
            CompCardTemplate.grid => back ? _gridBack() : _gridFront(),
            CompCardTemplate.runway => back ? _runwayBack() : _runwayFront(),
            CompCardTemplate.range => back ? _rangeBack() : _rangeFront(),
            CompCardTemplate.signal => back ? _signalBack() : _signalFront(),
          },
        ),
      ),
    );
  }

  // ===================================================================
  // 01 · Maison — Bodoni Moda + Jost, ivory and black
  // ===================================================================

  static const _ivory = Color(0xFFFBF9F4);
  static const _ink = Color(0xFF141513);

  TextStyle _bodoni({
    double size = 40,
    Color color = _ink,
    bool italic = false,
  }) => GoogleFonts.bodoniModa(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  TextStyle _jost({
    double size = 10,
    Color color = _ink,
    double tracking = 0.3,
    FontWeight weight = FontWeight.w400,
    double height = 1,
  }) => GoogleFonts.jost(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: size * tracking,
    height: height,
  );

  Widget _maisonFront() {
    return Container(
      color: _ivory,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'THE BOARD',
            textAlign: TextAlign.center,
            style: _jost(size: 10, tracking: 0.42),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _photo(data.shot(0), const [
              Color(0xFFD8D4C9),
              Color(0xFFCDC9BE),
            ]),
          ),
          const SizedBox(height: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(data.name, maxLines: 1, style: _bodoni(size: 40)),
              ),
              const SizedBox(height: 9),
              Container(width: 28, height: 1, color: _ink),
              const SizedBox(height: 9),
              Text(
                data.city.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _jost(
                  size: 9.5,
                  tracking: 0.3,
                  color: _ink.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _maisonBack() {
    return Container(
      color: _ivory,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(data.name, maxLines: 1, style: _bodoni(size: 26)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              children: [
                for (var i = 0; i < 4; i++)
                  _photo(
                    data.shot(i + 1),
                    i.isEven
                        ? const [Color(0xFF2A2B27), Color(0xFF1D1E1A)]
                        : const [Color(0xFFD8D4C9), Color(0xFFCDC9BE)],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final stat in [
                ('Height', data.heightNumber),
                ('Bust', data.bust),
                ('Waist', data.waist),
                ('Hips', data.hips),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stat.$1.toUpperCase(),
                        maxLines: 1,
                        style: _jost(
                          size: 8,
                          tracking: 0.2,
                          color: _ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(stat.$2, maxLines: 1, style: _bodoni(size: 15)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: _ink.withValues(alpha: 0.3)),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${data.shoe} · ${data.hair} · ${data.eyes}\n${data.handle} · ${data.phone}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _jost(
                    size: 10,
                    tracking: 0.12,
                    weight: FontWeight.w300,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _qr(const Color(0xFF141513), _ivory, 40),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 02 · Grid — Space Grotesk + Space Mono, one red rule
  // ===================================================================

  static const _red = Color(0xFFD23B22);

  TextStyle _grotesk({
    double size = 15,
    Color color = _ink,
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -size * 0.025,
    height: 0.95,
  );

  TextStyle _spaceMono({double size = 9.5, Color color = _ink}) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1,
      );

  Widget _gridFront() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _ink, width: 3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'THE BOARD',
                    maxLines: 1,
                    style: _grotesk(size: 15),
                  ),
                ),
                Text(
                  '№ ${data.handle.replaceAll('@', '').toUpperCase()}',
                  maxLines: 1,
                  style: _spaceMono(color: _red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _photo(data.shot(0), const [
              Color(0xFFDEDAD0),
              Color(0xFFD3CFC5),
            ]),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.name.replaceFirst(' ', '\n'),
              style: _grotesk(size: 42),
            ),
          ),
          const SizedBox(height: 12),
          _cellRow(
            const ['HGT', 'BST', 'WST', 'HIP'],
            [data.heightNumber, data.bust, data.waist, data.hips],
          ),
        ],
      ),
    );
  }

  Widget _cellRow(List<String> labels, List<String> values) {
    return Container(
      color: _ink.withValues(alpha: 0.25),
      // IntrinsicHeight, not a bare stretch: this Row sits in a Column,
      // so its height is unbounded and stretching against an unbounded
      // cross axis asks each cell to lay out at infinite height. This
      // measures the tallest cell, then squares the rest to it so the
      // 1px rules between them run the full height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        maxLines: 1,
                        style: _spaceMono(
                          size: 8,
                          color: _ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        values[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _grotesk(size: 13),
                      ),
                    ],
                  ),
                ),
              ),
              if (i != labels.length - 1) const SizedBox(width: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gridBack() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _grotesk(size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${data.city.toUpperCase()} · IN',
                maxLines: 1,
                style: _spaceMono(size: 9),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _photo(data.shot(1), const [
                          Color(0xFF2A2B27),
                          Color(0xFF1D1E1A),
                        ]),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _photo(data.shot(2), const [
                          Color(0xFFDEDAD0),
                          Color(0xFFD3CFC5),
                        ]),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _photo(data.shot(3), const [
                          Color(0xFFDEDAD0),
                          Color(0xFFD3CFC5),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _photo(data.shot(4), const [
                          Color(0xFFDEDAD0),
                          Color(0xFFD3CFC5),
                        ]),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _photo(data.shot(5), const [
                          Color(0xFF2A2B27),
                          Color(0xFF1D1E1A),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _ink, width: 3)),
            ),
            child: Column(
              children: [
                _monoRow('SHOE', data.shoe),
                const SizedBox(height: 9),
                _monoRow('HAIR / EYES', '${data.hair} / ${data.eyes}'),
                const SizedBox(height: 9),
                _monoRow('BOOKINGS', data.phone, color: _red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoRow(String label, String value, {Color color = _ink}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            style: _spaceMono(
              size: 10,
              color: color == _red ? _red : _ink.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _spaceMono(size: 10, color: color),
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // 03 · Runway — Instrument Serif italic + Jost, warm stone
  // ===================================================================

  static const _stone = Color(0xFFEFE9DF);
  static const _gold = Color(0xFFC9A227);

  TextStyle _instrument({
    double size = 28,
    Color color = _ink,
    bool italic = false,
  }) => GoogleFonts.instrumentSerif(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    height: italic ? 0.86 : 1,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  );

  Widget _runwayFront() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photo(data.shot(0), const [Color(0xFF2A2B27), Color(0xFF1D1E1A)]),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THE BOARD',
                style: _jost(
                  size: 9.5,
                  tracking: 0.36,
                  color: _ivory.withValues(alpha: 0.9),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.name.replaceFirst(' ', '\n'),
                      style: _instrument(size: 62, color: _ivory, italic: true),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(width: 34, height: 1, color: _gold),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Text(
                          '${data.heightNumber} · ${data.bust} · ${data.waist} · ${data.hips}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _jost(
                            size: 9.5,
                            tracking: 0.24,
                            color: _ivory,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _runwayBack() {
    return Container(
      color: _stone,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _ink.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    data.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _instrument(size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  data.city.toUpperCase(),
                  maxLines: 1,
                  style: _jost(
                    size: 9,
                    tracking: 0.2,
                    color: _ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _photo(data.shot(1), const [
                          Color(0xFFD9D2C6),
                          Color(0xFFCEC7BB),
                        ]),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _photo(data.shot(2), const [
                          Color(0xFF2A2B27),
                          Color(0xFF1D1E1A),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: _photo(data.shot(3), const [
                    Color(0xFFD9D2C6),
                    Color(0xFFCEC7BB),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _runwayRow(
            'Height · Bust · Waist · Hips',
            '${data.heightNumber} · ${data.bust} · ${data.waist} · ${data.hips}',
          ),
          _runwayRow('Shoe', data.shoe),
          _runwayRow(
            'Hair · Eyes',
            '${data.hair} · ${data.eyes}',
            bottom: true,
          ),
          const SizedBox(height: 10),
          Text(
            '${data.handle} · ${data.phone}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _instrument(size: 15, italic: true),
          ),
        ],
      ),
    );
  }

  Widget _runwayRow(String label, String value, {bool bottom = false}) {
    final line = BorderSide(color: _ink.withValues(alpha: 0.18));
    return Container(
      padding: EdgeInsets.only(top: 9, bottom: bottom ? 9 : 0),
      decoration: BoxDecoration(
        border: Border(top: line, bottom: bottom ? line : BorderSide.none),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              style: _jost(
                size: 10.5,
                tracking: 0.14,
                color: _ink.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _jost(size: 10.5, tracking: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 04 · Range — DM Sans + DM Mono, cream and terracotta
  // ===================================================================

  static const _cream = Color(0xFFF7F1E6);
  static const _creamRaised = Color(0xFFEFE5D3);
  static const _terracotta = Color(0xFFB4532F);

  TextStyle _dmSans({
    double size = 18,
    Color color = _ink,
    FontWeight weight = FontWeight.w700,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -size * 0.025,
    height: 0.98,
  );

  TextStyle _dmMono({
    double size = 9,
    Color color = _ink,
    double tracking = 0.08,
  }) => GoogleFonts.dmMono(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: color,
    letterSpacing: size * tracking,
    height: 1.1,
  );

  Widget _rangeFront() {
    return Container(
      color: _cream,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _dmSans(size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: _terracotta,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'THE BOARD',
                  maxLines: 1,
                  style: _dmMono(color: _ivory),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _photo(data.shot(0), const [
                Color(0xFFE2D9C8),
                Color(0xFFD7CEBD),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final stat in [
                ('HEIGHT', data.heightNumber),
                ('BUST', data.bust),
                ('WAIST', data.waist),
                ('HIPS', data.hips),
              ]) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _creamRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stat.$1,
                          maxLines: 1,
                          style: _dmMono(
                            size: 8,
                            color: _ink.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stat.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _dmSans(size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                if (stat.$1 != 'HIPS') const SizedBox(width: 7),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeBack() {
    const labels = [
      'SMILE',
      'PROFILE',
      'BEAUTY',
      'FULL BODY',
      'LIFESTYLE',
      'EDITORIAL',
    ];

    return Container(
      color: _cream,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SIX LOOKS',
            style: _dmMono(size: 9, color: _terracotta, tracking: 0.14),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 0.82,
              children: [
                for (var i = 0; i < 6; i++)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _photo(
                      data.shot(i + 1),
                      i == 1 || i == 3
                          ? const [Color(0xFF2A2B27), Color(0xFF1D1E1A)]
                          : const [Color(0xFFE2D9C8), Color(0xFFD7CEBD)],
                      overlay: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            style: _dmMono(
                              size: 8,
                              color: i == 1 || i == 3
                                  ? _cream.withValues(alpha: 0.8)
                                  : _ink.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _creamRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _dmSans(size: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${data.shoe} · ${data.hair} · ${data.eyes}\n${data.phone} · ${data.handle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _dmMono(
                          size: 9.5,
                          tracking: 0.02,
                        ).copyWith(height: 1.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _qr(_terracotta, _ivory, 42, radius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 05 · Signal — Syne + JetBrains Mono, carbon and chartreuse
  // ===================================================================

  static const _carbon = Color(0xFF101210);
  static const _bone = Color(0xFFF2F0E9);
  static const _chartreuse = Color(0xFF556B2F);

  TextStyle _syne({
    double size = 34,
    Color color = _bone,
    FontWeight weight = FontWeight.w800,
  }) => GoogleFonts.syne(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -size * 0.02,
    height: 0.9,
  );

  TextStyle _jet({
    double size = 9.5,
    Color color = _bone,
    double tracking = 0.1,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: size * tracking,
    height: 1,
  );

  Widget _signalFront() {
    return Container(
      color: _carbon,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.name.toUpperCase().replaceFirst(' ', '\n'),
                        style: _syne(size: 34),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'THE BOARD · ${data.city.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _jet(
                        size: 9.5,
                        color: _chartreuse,
                        tracking: 0.14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _qr(_chartreuse, _carbon, 52),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _photo(data.shot(0), const [
              Color(0xFF25281F),
              Color(0xFF1B1E18),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final stat in [
                ('HEIGHT', data.heightNumber),
                ('BUST', data.bust),
                ('WAIST', data.waist),
                ('HIPS', data.hips),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat.$1,
                        maxLines: 1,
                        style: _jet(
                          size: 8.5,
                          color: _bone.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        stat.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _syne(size: 16, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signalBack() {
    return Container(
      color: _carbon,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SELECTED WORK',
                style: _syne(size: 18, weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${DateTime.now().year}',
                style: _jet(size: 9, color: _chartreuse),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  _photo(data.shot(i + 1), const [
                    Color(0xFF25281F),
                    Color(0xFF1B1E18),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _signalRow('SHOE', data.shoe),
          const SizedBox(height: 10),
          _signalRow('HAIR · EYES', '${data.hair} · ${data.eyes}'),
          const SizedBox(height: 10),
          Container(
            color: _chartreuse,
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            child: Text(
              data.handle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _syne(
                size: 14,
                color: _carbon,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 0.84),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _bone.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              style: _jet(size: 10.5, color: _bone.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _jet(size: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // Shared parts
  // ===================================================================

  /// A photo slot. Missing shots fall back to the template's own hatch
  /// tones rather than the app's, so an unfinished card still looks like
  /// the card it will become.
  Widget _photo(String? url, List<Color> tones, {Widget? overlay}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _Hatch(tones: tones),
            errorBuilder: (_, __, ___) => _Hatch(tones: tones),
          )
        else
          _Hatch(tones: tones),
        if (overlay != null) overlay,
      ],
    );
  }

  Widget _qr(
    Color background,
    Color foreground,
    double size, {
    double radius = 0,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        'QR',
        style: GoogleFonts.spaceMono(fontSize: 8, color: foreground, height: 1),
      ),
    );
  }
}

/// An unfilled photo slot.
///
/// Flat, not hatched. Diagonal stripes read as a corrupted image rather
/// than an empty frame — especially while a real photograph is still
/// downloading, where they flash over a card that is about to be fine.
/// A plain panel in the template's own tone looks like unprinted stock.
class _Hatch extends StatelessWidget {
  final List<Color> tones;
  const _Hatch({required this.tones});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: tones[1], child: const SizedBox.expand());
}

/// A card face scaled to whatever space it is given, keeping true trim
/// proportions. Use this everywhere rather than [CompCardFaceView]
/// directly, so a thumbnail and a full preview stay the same drawing.
class CompCardFace extends StatelessWidget {
  final CompCardTemplate template;
  final CompCardData data;
  final bool back;

  const CompCardFace({
    super.key,
    required this.template,
    required this.data,
    this.back = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CompCardFaceView.aspect,
      child: FittedBox(
        fit: BoxFit.contain,
        child: CompCardFaceView(template: template, data: data, back: back),
      ),
    );
  }
}
