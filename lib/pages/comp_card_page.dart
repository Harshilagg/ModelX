import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/comp_card_templates.dart';
import '../widgets/state_views.dart';

/// The comp card generator (style board 6a).
///
/// Three steps: pick four shots, choose a layout, export. A comp card is
/// the one artefact a model is actually judged on, and the industry
/// standard is one headshot plus three looks — so the tool's whole job
/// is to assemble that from what the profile already holds and get out
/// of the way.
///
/// It writes nothing. Every value on the card is read from the existing
/// `users` document and the existing `portfolio` collection, which is
/// also why the readiness percentage doubles as a nudge to finish a
/// sparse profile: the number only moves when real fields get filled.
class CompCardPage extends StatefulWidget {
  /// Whose card. Defaults to the signed-in model.
  final String? uid;

  const CompCardPage({super.key, this.uid});

  @override
  State<CompCardPage> createState() => _CompCardPageState();
}

class _CompCardPageState extends State<CompCardPage> {
  int _step = 0;
  CompCardTemplate _template = CompCardTemplate.maison;

  /// One portfolio document id per named slot, so "this one is the
  /// headshot" is a decision rather than a consequence of tap order.
  /// Index matches [compCardSlots]; null means the slot is still empty.
  final List<String?> _assigned = List<String?>.filled(
    compCardSlots.length,
    null,
  );

  /// The slot the next photograph tapped will fill.
  int _activeSlot = 0;

  late final PageController _templatePages = PageController(
    viewportFraction: 0.92,
  );

  Map<String, dynamic>? _user;
  List<QueryDocumentSnapshot> _portfolio = [];
  bool _loading = true;
  String? _error;

  String get _uid => widget.uid ?? FirebaseAuth.instance.currentUser!.uid;

  /// Slots the chosen template actually prints. Switching template
  /// grows or shrinks this without losing what's already assigned.
  int get _slotCount => _template.totalShots;

  List<String?> get _shots => [
    for (var i = 0; i < _slotCount; i++) _urlFor(_assigned[i]),
  ];

  int get _filledSlots => _assigned.take(_slotCount).whereType<String>().length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _templatePages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(_uid).get(),
        FirebaseFirestore.instance
            .collection('portfolio')
            .where('uid', isEqualTo: _uid)
            .get(),
      ]);

      if (!mounted) return;
      final userDoc = results[0] as DocumentSnapshot;
      final folio = results[1] as QuerySnapshot;

      setState(() {
        _user = userDoc.data() as Map<String, dynamic>? ?? {};
        _portfolio = folio.docs;
        // Deliberately not pre-filled. Auto-assigning made the card look
        // finished before the model had chosen anything, and it made the
        // readiness reading dishonest — the shots half was already full
        // on open.
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your profile and portfolio.';
        _loading = false;
      });
    }
  }

  // ---- values read straight off the profile -------------------------
  //
  // Resolving lives in CompCardData.fromUser now, so the five templates
  // and the export preview can never disagree about what a field means.

  /// Stats readiness comes from the one shared definition, so the number
  /// here matches the profile's spec sheet and the Network nudge. Shots
  /// are reported separately rather than blended in: a single percentage
  /// mixing "fields filled" with "photos chosen" can't tell you which of
  /// the two to go and fix.
  int get _statsPercent => CompCardReadiness.statsPercent(_user ?? const {});

  List<String> get _missingStats =>
      CompCardReadiness.missing(_user ?? const {});

  /// Resolved once per build so the chooser's previews and the export
  /// preview are all drawing the same values.
  CompCardData get _cardData =>
      CompCardData.fromUser(_user ?? const {}, images: _shots);

  String? _urlFor(String? docId) {
    if (docId == null) return null;
    for (final d in _portfolio) {
      if (d.id == docId) {
        return ((d.data() as Map<String, dynamic>)['mediaUrl'] ?? '')
            .toString();
      }
    }
    return null;
  }

  /// Puts a photograph in the active slot, then moves to the next empty
  /// one so assigning a whole card is a run of taps rather than a
  /// tap-a-slot-tap-a-photo pair each time.
  void _assign(String docId) {
    setState(() {
      // A photo can only hold one role; clear it from wherever it was.
      for (var i = 0; i < _assigned.length; i++) {
        if (_assigned[i] == docId) _assigned[i] = null;
      }
      _assigned[_activeSlot] = docId;

      final nextEmpty = _assigned
          .take(_slotCount)
          .toList()
          .indexWhere((id) => id == null);
      _activeSlot = nextEmpty == -1
          ? (_activeSlot + 1).clamp(0, _slotCount - 1)
          : nextEmpty;
    });
  }

  void _clearSlot(int slot) {
    setState(() {
      _assigned[slot] = null;
      _activeSlot = slot;
    });
  }

  int? _slotOf(String docId) {
    for (var i = 0; i < _slotCount; i++) {
      if (_assigned[i] == docId) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const LoadingState()
                  : _error != null
                  ? ErrorStateView(message: _error!, onRetry: _load)
                  : _body(),
            ),
            if (!_loading && _error == null) _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: BoardColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: BoardColors.onInk,
                ),
              ),
              const Spacer(),
              Text(
                'FREE · NO WATERMARK',
                style: BoardType.mono(
                  fontSize: 9.5,
                  color: BoardColors.brass,
                  letterSpacing: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'COMP CARD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BoardType.display(
              fontSize: 38,
              color: BoardColors.onInk,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  height: 4,
                  color: i <= _step
                      ? BoardColors.brass
                      : BoardColors.onInk.withValues(alpha: 0.2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Template first, then shots.
  ///
  /// Assigning first meant the number of slots changed underneath you the
  /// moment you picked a design — choose Maison, fill five, switch to
  /// Grid and two more appear that you have to go back for. Choosing the
  /// design first fixes the slot count before a single photograph is
  /// placed.
  Widget _body() {
    switch (_step) {
      case 0:
        return _stepLayout();
      case 1:
        return _stepShots();
      default:
        return _stepExport();
    }
  }

  // ---- Step 01 ------------------------------------------------------

  Widget _stepShots() {
    if (_portfolio.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _stepIntro(
            'STEP 02 · ASSIGN YOUR SHOTS',
            'A comp card is one headshot and a set of looks.',
          ),
          const SizedBox(height: 20),
          const EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No portfolio shots yet',
            message: 'Add shots to your portfolio and you can place them here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepIntro(
          'STEP 02 · ASSIGN YOUR SHOTS',
          'Pick a slot, then tap the photograph that belongs in it. '
              '${_template.label} prints $_slotCount.',
        ),
        const SizedBox(height: 14),
        _slotStrip(),
        const SizedBox(height: 16),
        BoardSectionLabel('Your portfolio · ${_portfolio.length} shots'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _portfolio.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, i) {
            final doc = _portfolio[i];
            final url = ((doc.data() as Map<String, dynamic>)['mediaUrl'] ?? '')
                .toString();
            final slot = _slotOf(doc.id);
            final assigned = slot != null;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => assigned ? _clearSlot(slot) : _assign(doc.id),
              child: Container(
                foregroundDecoration: assigned
                    ? BoxDecoration(
                        border: Border.all(color: BoardColors.ink, width: 3),
                      )
                    : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BoardMedia(url: url, dark: i.isOdd),
                    if (assigned)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          color: BoardColors.ink,
                          child: Text(
                            compCardSlots[slot],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.mono(
                              fontSize: 8.5,
                              color: BoardColors.brass,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          assignedHint,
          style: BoardType.body(fontSize: 12, color: BoardColors.inkSoft),
        ),
      ],
    );
  }

  String get assignedHint => _filledSlots == _slotCount
      ? 'All $_slotCount slots filled. Tap a photograph to take it back off the card.'
      : 'Tap a slot above, then the photograph for it.';

  /// The slots, as a strip you assign into. Shows what each role
  /// currently holds, which is the thing tap-order ordering could never
  /// communicate.
  Widget _slotStrip() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _slotCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == _activeSlot;
          final url = _urlFor(_assigned[i]);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _activeSlot = i),
            child: SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      foregroundDecoration: BoxDecoration(
                        border: Border.all(
                          color: active ? BoardColors.ink : BoardColors.inkLine,
                          width: active ? 3 : 1,
                        ),
                      ),
                      child: url == null
                          ? Container(
                              color: BoardColors.shell,
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: BoardType.mono(
                                  fontSize: 13,
                                  color: BoardColors.inkSoft,
                                ),
                              ),
                            )
                          : BoardMedia(url: url),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    compCardSlots[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 8,
                      color: active ? BoardColors.ink : BoardColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Step 02 ------------------------------------------------------

  Widget _stepLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _stepIntro(
            'STEP 01 · CHOOSE YOUR CARD',
            'Swipe to compare. Each is its own piece of design, and each '
                'prints a different number of shots.',
          ),
        ),
        const SizedBox(height: 14),
        // A page each, showing both faces at a size you can actually
        // judge. The old chooser showed one 92px-wide front, which told
        // you a template's colour and nothing else.
        Expanded(
          child: PageView.builder(
            controller: _templatePages,
            itemCount: CompCardTemplate.values.length,
            onPageChanged: (i) => setState(() {
              _template = CompCardTemplate.values[i];
              // A template that prints fewer shots would otherwise leave
              // photographs assigned to slots it never draws — invisible,
              // but still counted against the model's own portfolio.
              for (var slot = _slotCount; slot < _assigned.length; slot++) {
                _assigned[slot] = null;
              }
              _activeSlot = _activeSlot.clamp(0, _slotCount - 1);
            }),
            itemBuilder: (context, i) {
              final template = CompCardTemplate.values[i];
              final selected = template == _template;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _faceWithCaption(
                              template,
                              'Front',
                              back: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _faceWithCaption(
                              template,
                              'Back',
                              back: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.display(fontSize: 24, height: 1),
                          ),
                        ),
                        if (selected)
                          const MonoChip(
                            'SELECTED',
                            filled: true,
                            accent: BoardColors.ink,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.body(
                        fontSize: 12,
                        color: BoardColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MonoChip(
                          'PRINTS ${template.totalShots} SHOTS',
                          neutral: true,
                        ),
                        const SizedBox(width: 6),
                        MonoChip(
                          '${template.backShots} ON THE BACK',
                          fontSize: 9,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < CompCardTemplate.values.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: CompCardTemplate.values[i] == _template ? 18 : 6,
                height: 4,
                color: CompCardTemplate.values[i] == _template
                    ? BoardColors.ink
                    : BoardColors.inkLine,
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _faceWithCaption(
    CompCardTemplate template,
    String caption, {
    required bool back,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CompCardFace(template: template, data: _cardData, back: back),
        const SizedBox(height: 6),
        Text(
          caption.toUpperCase(),
          style: BoardType.mono(fontSize: 9, color: BoardColors.inkSoft),
        ),
      ],
    );
  }

  // ---- Step 03 ------------------------------------------------------

  Widget _stepExport() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepIntro(
          'STEP 03 · YOUR CARD',
          '${_template.label}, at true trim — 5.5 × 8.5 in, the size every '
              'agency prints.',
        ),
        const SizedBox(height: 14),
        _readinessPanel(),
        const SizedBox(height: 16),

        // Both faces, full width and stacked. A comp card is two sides;
        // showing one and hiding the other behind a toggle made the back
        // feel optional when it carries most of the information.
        const BoardSectionLabel('Front'),
        const SizedBox(height: 7),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openFullScreen(back: false),
          child: CompCardFace(template: _template, data: _cardData),
        ),
        const SizedBox(height: 18),
        const BoardSectionLabel('Back'),
        const SizedBox(height: 7),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openFullScreen(back: true),
          child: CompCardFace(template: _template, data: _cardData, back: true),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap either side to see it full screen.',
          style: BoardType.body(fontSize: 12, color: BoardColors.inkSoft),
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _explainPdf,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  color: BoardColors.brass,
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: BoardColors.ink, width: 3),
                  ),
                  child: Text(
                    'DOWNLOAD PDF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.35,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _copyLink,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: BoardColors.ink,
                child: Text(
                  'LINK',
                  style: BoardType.title(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.35,
                    color: BoardColors.onInk,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          color: BoardColors.ink,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WHY THE LINK MATTERS',
                style: BoardType.mono(
                  fontSize: 9.5,
                  color: BoardColors.onInkSoft,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Every card you send outside the app carries a link back to '
                'your live profile. A brand that opens it lands on your '
                'current portfolio, not a dead file.',
                style: BoardType.body(
                  fontSize: 12.5,
                  color: BoardColors.onInk.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Two separate readings rather than one blended percentage.
  ///
  /// The old number mixed "fields filled" with "photos chosen", so it
  /// could sit at 60% without telling you which half to go and fix — and
  /// it disagreed with the number the profile and Network showed for the
  /// same card.
  Widget _readinessPanel() {
    final shotsDone = _filledSlots == _slotCount;
    final statsDone = _statsPercent == 100;
    final missing = _missingStats;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BoardColors.ink,
        borderRadius: BorderRadius.circular(BoardRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _readingRow(
                  'SHOTS',
                  '$_filledSlots of $_slotCount',
                  done: shotsDone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _readingRow(
                  'CARD DETAILS',
                  '$_statsPercent%',
                  done: statsDone,
                ),
              ),
            ],
          ),
          if (!statsDone) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: BoardColors.onInkLine),
            const SizedBox(height: 10),
            Text(
              'Still blank on the card: ${missing.join(', ')}.',
              style: BoardType.body(fontSize: 12, color: BoardColors.onInkSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readingRow(String label, String value, {required bool done}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BoardType.mono(
            fontSize: 9.5,
            color: BoardColors.onInkSoft,
            letterSpacing: 0.95,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.display(
                  fontSize: 24,
                  color: done ? BoardColors.booked : BoardColors.brass,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
            if (done) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 15, color: BoardColors.booked),
            ],
          ],
        ),
      ],
    );
  }

  void _openFullScreen({required bool back}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                maxScale: 4,
                child: CompCardFace(
                  template: _template,
                  data: _cardData,
                  back: back,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(dialogContext).padding.top + 12,
            right: 16,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'CLOSE',
                style: BoardType.mono(fontSize: 11, color: BoardColors.brass),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: 'modelx://profile/$_uid'));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile link copied')));
  }

  void _explainPdf() {
    // Rendering a real PDF needs the `pdf` + `printing` packages, which
    // this project doesn't depend on yet. Saying so beats a button that
    // quietly does nothing.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PDF export needs the pdf + printing packages added to pubspec.',
        ),
      ),
    );
  }

  Widget _stepIntro(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardSectionLabel(label),
        const SizedBox(height: 4),
        Text(body, style: BoardType.body(fontSize: 13)),
      ],
    );
  }

  Widget _footer() {
    return Container(
      color: BoardColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _step--),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  color: BoardColors.shell,
                  child: Text(
                    'BACK',
                    style: BoardType.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _step < 2
                    ? setState(() => _step++)
                    : Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  color: _step < 2 ? BoardColors.ink : BoardColors.shell,
                  child: Text(
                    _step < 2 ? 'CONTINUE' : 'DONE',
                    style: BoardType.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.35,
                      color: _step < 2 ? BoardColors.onInk : BoardColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
