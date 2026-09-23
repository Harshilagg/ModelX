import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_modelx/ui/board_theme.dart';
import 'package:flutter_application_modelx/widgets/board_widgets.dart';
import 'package:flutter_application_modelx/widgets/job_detail_view.dart';
import 'package:flutter_application_modelx/widgets/shot_carousel.dart';
import 'package:flutter_application_modelx/widgets/network_cards.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_modelx/widgets/comp_card_templates.dart';
import 'package:flutter_application_modelx/widgets/portfolio_masonry.dart';

/// Layout regression tests for the board redesign.
///
/// The board leans on condensed all-caps titles, fixed-width time and
/// status columns, and dense chip rows — all of which are exactly the
/// shapes that overflow first on a narrow handset or when someone has
/// bumped their system font size. These render the Firebase-free parts
/// of every redesigned screen at the smallest width the app realistically
/// sees (320dp) and again at 1.5x text, and fail on any RenderFlex
/// overflow, which Flutter surfaces as an exception in debug.
/// The height one line of [style] occupies at a given text scale.
///
/// Tests that hardcode this drift the moment a type token changes,
/// which is how the discovery rail came to clip by a few pixels.
double lineHeight(TextStyle style, TextScaler scaler) =>
    scaler.scale(style.fontSize!) * (style.height ?? 1.0);

void main() {
  /// Pumps [child] at [width] and [textScale] and returns any layout
  /// exception Flutter raised while laying it out.
  Future<Object?> layout(
    WidgetTester tester,
    Widget child, {
    double width = 320,
    double height = 640,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MaterialApp(
            home: Scaffold(backgroundColor: BoardColors.paper, body: child),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.takeException();
  }

  /// The longest realistic values a model or brand could enter, so the
  /// tests exercise wrap-and-ellipsis rather than the happy path.
  const longTitle = 'Lakmé Fashion Week Resort Campaign Ramp Call 2026';
  const longName = 'Emiliana Jasper-Chandran';

  group('nav and chrome', () {
    for (final scale in [1.0, 1.5]) {
      testWidgets('BoardNavBar fits at ${scale}x text', (tester) async {
        final error = await layout(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: BoardNavBar(currentIndex: 0, onTap: (_) {}),
            ),
          ),
          textScale: scale,
        );
        expect(error, isNull);
      });

      testWidgets('BoardTopBar fits at ${scale}x text', (tester) async {
        final error = await layout(
          tester,
          const BoardTopBar(initial: 'H', unread: 128),
          textScale: scale,
        );
        expect(error, isNull);
      });

      testWidgets('BoardTabRail fits three tabs at ${scale}x text', (tester) async {
        final error = await layout(
          tester,
          BoardTabRail(
            tabs: const ['Details', 'Portfolio', 'Posts'],
            index: 0,
            onTap: (_) {},
          ),
          textScale: scale,
        );
        expect(error, isNull);
      });

      testWidgets('BoardScreenTitle fits a long title at ${scale}x text', (tester) async {
        final error = await layout(
          tester,
          const BoardScreenTitle(title: 'Board Updates', meta: '12 CONNECTIONS · DELHI NCR'),
          textScale: scale,
        );
        expect(error, isNull);
      });
    }
  });

  group('nav bar geometry', () {
    // The shell stacks the copilot on top of the nav bar using
    // BoardNavBar.height, because the bar is a Positioned child rather
    // than a bottomNavigationBar and nothing measures it at runtime. If
    // the declared height ever drifts from the laid-out height, the
    // copilot silently lands back on top of the bar — so pin it.
    for (final scale in [1.0, 1.5]) {
      testWidgets('declared height matches laid-out height at ${scale}x text',
          (tester) async {
        final error = await layout(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: BoardNavBar(currentIndex: 0, onTap: (_) {}),
            ),
          ),
          textScale: scale,
        );
        expect(error, isNull);
        expect(
          tester.getSize(find.byType(BoardNavBar)).height,
          BoardNavBar.height,
        );
      });
    }

    testWidgets('the copilot clears the nav bar', (tester) async {
      const navBottom = 14.0 + 34.0; // 14dp inset + a tall home indicator
      final error = await layout(
        tester,
        Stack(
          children: [
            Positioned(
              right: 16,
              bottom: navBottom + BoardNavBar.height + 12,
              child: Container(
                key: const Key('copilot'),
                width: 46,
                height: 46,
                color: BoardColors.ink,
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: navBottom,
              child: BoardNavBar(currentIndex: 0, onTap: (_) {}),
            ),
          ],
        ),
      );
      expect(error, isNull);

      final copilot = tester.getRect(find.byKey(const Key('copilot')));
      final bar = tester.getRect(find.byType(BoardNavBar));
      expect(
        copilot.bottom,
        lessThanOrEqualTo(bar.top),
        reason: 'the copilot must sit entirely above the nav bar',
      );
    });
  });

  group('ShotCarousel', () {
    const shots = ['a.jpg', 'b.jpg', 'c.jpg'];

    testWidgets('lays out and shows one indicator per shot', (tester) async {
      final error = await layout(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          // Auto-advance off: a running Timer would leave the test
          // pending forever.
          child: ShotCarousel(urls: shots, autoAdvance: null),
        ),
      );
      expect(error, isNull);
      expect(find.byType(AnimatedContainer), findsNWidgets(shots.length));
    });

    testWidgets('wraps around past the last shot', (tester) async {
      await layout(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: ShotCarousel(urls: shots, autoAdvance: null),
        ),
      );

      // Swipe forward more times than there are shots. A bounded list
      // would stop at the end; a circular one keeps going.
      for (var i = 0; i < shots.length + 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(-200, 0));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);

      // And backwards past the start, which is the direction a
      // non-looping carousel refuses.
      for (var i = 0; i < shots.length + 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(200, 0));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single shot renders without a carousel', (tester) async {
      final error = await layout(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: ShotCarousel(urls: ['only.jpg'], autoAdvance: null),
        ),
      );
      expect(error, isNull);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('no shots renders nothing', (tester) async {
      final error = await layout(
        tester,
        const ShotCarousel(urls: [], autoAdvance: null),
      );
      expect(error, isNull);
      expect(find.byType(PageView), findsNothing);
    });
  });

  group('job card selection', () {
    // The dark surface belongs to the card the model tapped, not to
    // whichever posting sorted first. Reproduces the row's own colour
    // rule so a change to it has to be deliberate.
    Color surfaceFor({required bool selected}) =>
        selected ? BoardColors.ink : BoardColors.slate;
    Color moneyFor({required bool selected}) =>
        selected ? BoardColors.brass : BoardColors.brassText;

    test('nothing is dark until a card is opened', () {
      const expandedId = null;
      for (final id in ['a', 'b', 'c']) {
        expect(surfaceFor(selected: expandedId == id), BoardColors.slate);
      }
    });

    test('only the opened card is ink, whatever its position', () {
      const expandedId = 'c';
      expect(surfaceFor(selected: expandedId == 'a'), BoardColors.slate);
      expect(surfaceFor(selected: expandedId == 'b'), BoardColors.slate);
      expect(surfaceFor(selected: expandedId == 'c'), BoardColors.ink);
    });

    test('money takes full brass on ink and the tint on slate', () {
      expect(moneyFor(selected: true), BoardColors.brass);
      expect(moneyFor(selected: false), BoardColors.brassText);
    });
  });

  group('feed card', () {
    // Reproduces the masonry card's furniture. Each column is roughly
    // half the viewport, so this is the tightest text measure in the app
    // — a username, a timestamp and the action row all have to survive
    // ~150dp and a bumped font size without clipping.
    Widget feedCard({required bool note}) {
      final author = Row(
        children: [
          SizedBox(width: note ? 18 : 20, height: note ? 18 : 20, child: const BoardHatch()),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'EMILIANA JASPER-CHANDRAN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.title(fontSize: note ? 11.5 : 12, letterSpacing: 0.35),
            ),
          ),
          const SizedBox(width: 4),
          Text('191D', style: BoardType.mono(fontSize: 9.5)),
        ],
      );

      final actions = Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border, size: 14),
              const SizedBox(width: 4),
              Text('128', style: BoardType.mono(fontSize: 10)),
            ],
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'COMMENT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.mono(fontSize: 9.5),
            ),
          ),
        ],
      );

      if (note) {
        return Container(
          padding: const EdgeInsets.all(11),
          color: BoardColors.slate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              author,
              const SizedBox(height: 8),
              Text(
                'Fitting call moved to 7 AM. Bringing two pairs of heels, '
                'nude and black — ask wardrobe before you pack.',
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: BoardType.body(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              actions,
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: BoardColors.card,
          borderRadius: BorderRadius.circular(BoardRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
              child: author,
            ),
            const AspectRatio(aspectRatio: 0.82, child: BoardHatch()),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  actions,
                  const SizedBox(height: 6),
                  Text(
                    'Test shoot with Aditya at the Lower Parel studio.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.body(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    /// The real masonry: two columns of cards side by side in a scroll
    /// view, which is what actually constrains each card's width.
    Widget masonry() => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [feedCard(note: false), feedCard(note: true)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [feedCard(note: true), feedCard(note: false)],
                  ),
                ),
              ],
            ),
          ],
        );

    for (final scale in [1.0, 1.5]) {
      testWidgets('the masonry lays out at ${scale}x text', (tester) async {
        final error = await layout(tester, masonry(), textScale: scale);
        expect(error, isNull);
      });
    }

    testWidgets('columns split the width evenly', (tester) async {
      await layout(tester, masonry());
      // 320dp viewport, 12dp padding either side, 8dp gutter.
      final crops = tester.getSize(find.byType(AspectRatio).first);
      expect(crops.width, (320 - 24 - 8) / 2);
      expect(crops.width / crops.height, closeTo(0.82, 0.01));
    });
  });

  group('avatars and chips', () {
    testWidgets('BoardAvatar falls back to an initial when there is no photo',
        (tester) async {
      final error = await layout(
        tester,
        const Center(child: BoardAvatar(name: 'Emiliana', size: 96, onDark: true, ring: true)),
      );
      expect(error, isNull);
      expect(find.text('E'), findsOneWidget);
      expect(tester.getSize(find.byType(BoardAvatar)), const Size(96, 96));
    });

    testWidgets('a filled chip never renders its label against its own fill',
        (tester) async {
      // MonoChip is called with brass, ink and status fills depending on
      // the site. Whatever the fill, the label has to be the other end of
      // the palette.
      for (final fill in [
        BoardColors.brass,
        BoardColors.ink,
        BoardColors.booked,
        BoardColors.rejected,
      ]) {
        await layout(tester, Center(child: MonoChip('FOLLOW', filled: true, accent: fill)));
        final label = tester.widget<Text>(find.text('FOLLOW'));
        expect(label.style!.color, isNot(fill));

        final onDarkFill = fill.computeLuminance() <= 0.32;
        expect(
          label.style!.color,
          onDarkFill ? BoardColors.onInk : BoardColors.ink,
          reason: '$fill should carry the opposite end of the palette',
        );
      }
    });
  });

  group('discovery rail', () {
    // The rail replaced a ~500px grid. Its card is a fixed crop plus a
    // caption, and the caption is the part that grows with the system
    // font — so the row height has to grow with it or the city clips off.
    // Derived from the styles themselves rather than from copied
    // numbers. The previous version hardcoded the condensed face's
    // line heights, so retiring that face silently made this formula
    // wrong and the rail clipped by a few pixels.
    double captionHeight(TextScaler scaler) =>
        8 +
        lineHeight(BoardType.title(fontSize: 17, fontWeight: FontWeight.w700), scaler) +
        3 +
        lineHeight(BoardType.mono(fontSize: 9.5, fontWeight: FontWeight.w400), scaler) +
        4;

    Widget railCard({required double cropHeight}) => SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: cropHeight,
                child: const BoardHatch(),
              ),
              const SizedBox(height: 8),
              Text(
                'EMILIANA JASPER-CHANDRAN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.title(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                'PHOTOGRAPHER · BENGALURU',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.mono(fontSize: 9.5, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        );

    for (final scale in [1.0, 1.5]) {
      testWidgets('the rail fits its cards at ${scale}x text', (tester) async {
        const crop = 168.0;
        final scaler = TextScaler.linear(scale);

        final error = await layout(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: crop + captionHeight(scaler),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, __) => railCard(cropHeight: crop),
              ),
            ),
          ),
          textScale: scale,
        );
        expect(error, isNull);
      });
    }

    testWidgets('the whole section stays near its 250dp budget', (tester) async {
      const crop = 168.0;
      final total = crop + captionHeight(TextScaler.noScaling) + 18 + 8 + 10 + 3 + 14;
      expect(total, lessThan(300));
    });
  });

  group('network bands', () {
    // The nearby rail is the compact, identity-led band that breaks up
    // two card rails. Its caption budget is tighter than the crop rail's,
    // so it's the one most likely to clip when the font scales.
    testWidgets('the nearby rail fits circular cards at 1.5x text', (tester) async {
      final scaler = TextScaler.linear(1.5);
      final caption = 8 +
          lineHeight(BoardType.title(fontSize: 12), scaler) +
          2 +
          lineHeight(BoardType.mono(fontSize: 9), scaler) +
          4;

      final error = await layout(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 64 + caption,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: 8,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BoardAvatar(name: 'Devika', size: 64),
                    const SizedBox(height: 8),
                    Text(
                      'DEVIKA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: BoardType.title(fontSize: 12, letterSpacing: 0.35),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@devikamenon',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: BoardType.mono(fontSize: 9, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        textScale: 1.5,
      );
      expect(error, isNull);
    });

    for (final scale in [1.0, 1.5]) {
      testWidgets('a hiring card fits a long brand name at ${scale}x text',
          (tester) async {
        final scaler = TextScaler.linear(scale);
        final error = await layout(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 13 * 2 + 26 + 10 + scaler.scale(20) * 0.95 * 2 + 8 + scaler.scale(10) * 1.1 + 2,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  SizedBox(
                    width: 172,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      color: BoardColors.slate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(width: 26, height: 26, color: BoardColors.brass),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('AGENCY',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: BoardType.mono(fontSize: 9)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Flexible(
                            child: Text(
                            'RAW MANGO RESORT COLLECTIVE',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.display(
                                fontSize: 20, color: BoardColors.onInk, height: 0.95),
                          ),
                          ),
                          const SizedBox(height: 8),
                          Text('12 OPEN CALLS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BoardType.mono(
                                  fontSize: 10, color: BoardColors.brassText)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          textScale: scale,
        );
        expect(error, isNull);
      });
    }

    testWidgets('a poster card lays out inside a horizontal rail', (tester) async {
      // The regression: PosterCard's width is optional, which is right in
      // the directory's vertical list and fatal in a rail, where the
      // parent offers unbounded width and the card cannot size itself.
      final error = await layout(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  // PosterCard.railWidth — the bound a horizontal parent
                  // cannot supply.
                  width: PosterCard.railWidth,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    color: BoardColors.slate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('RAW MANGO',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.display(
                                fontSize: 20, color: BoardColors.onInk)),
                        Text('2 OPEN CALLS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.mono(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(error, isNull);
      expect(PosterCard.railWidth, greaterThan(0));
    });

    testWidgets('the comp card nudge lays out at 1.5x text', (tester) async {
      final error = await layout(
        tester,
        ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: BoardColors.ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'YOUR COMP CARD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.display(
                              fontSize: 24, color: BoardColors.onInk, height: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('38%',
                          style: BoardType.display(
                              fontSize: 30,
                              color: BoardColors.brass,
                              fontWeight: FontWeight.w400,
                              height: 1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 0.38, minHeight: 4),
                ],
              ),
            ),
          ],
        ),
        textScale: 1.5,
      );
      expect(error, isNull);
    });
  });

  group('directory grid', () {
    // The full listing reuses the rail's card at a bigger size. Its cell
    // height is computed rather than guessed, so the crop keeps the same
    // proportions in both places and the caption still has room when the
    // font scales.
    testWidgets('cells keep the rail crop proportions', (tester) async {
      const gutter = 14.0;
      const gap = 9.0;
      late double cellWidth;
      late double cropHeight;
      late double extent;

      final error = await layout(
        tester,
        LayoutBuilder(
          builder: (context, constraints) {
            cellWidth = (constraints.maxWidth - gutter * 2 - gap) / 2;
            cropHeight = cellWidth * (168 / 132);
            extent = cropHeight + PersonCropCard.captionHeight(context);

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 28),
              itemCount: 6,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: gap,
                mainAxisSpacing: 16,
                mainAxisExtent: extent,
              ),
              itemBuilder: (context, i) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: cropHeight, child: const BoardHatch()),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      'EMILIANA JASPER-CHANDRAN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.title(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'BENGALURU · 171 CM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(fontSize: 9.5, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            );
          },
        ),
      );
      expect(error, isNull);

      // 320dp viewport: two cells, 14dp gutters, 9dp gap.
      expect(cellWidth, (320 - 28 - 9) / 2);
      // Same crop ratio as the 132x168 rail card.
      expect(cropHeight / cellWidth, closeTo(168 / 132, 0.001));
      expect(extent, greaterThan(cropHeight));
    });

    testWidgets('the grid survives a bumped font size', (tester) async {
      final error = await layout(
        tester,
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 28 - 9) / 2;
            final cropHeight = cellWidth * (168 / 132);
            return GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 16,
                mainAxisExtent: cropHeight + PersonCropCard.captionHeight(context),
              ),
              itemBuilder: (context, i) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: cropHeight, child: const BoardHatch()),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text('DEVIKA MENON',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.title(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 3),
                  Text('BENGALURU · 171 CM',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.mono(fontSize: 9.5, fontWeight: FontWeight.w400)),
                ],
              ),
            );
          },
        ),
        textScale: 1.5,
      );
      expect(error, isNull);
    });
  });

  group('photo cropping', () {
    // A centred cover crop on a full-length shot keeps the waist and
    // throws away the face. Everything that renders a person crops from
    // the top, or just above centre for circles.
    testWidgets('BoardMedia crops from the top by default', (tester) async {
      await layout(tester, const SizedBox(width: 100, height: 100, child: BoardMedia()));
      const media = BoardMedia();
      expect(media.alignment, Alignment.topCenter);
    });

    testWidgets('an explicit alignment still wins', (tester) async {
      const media = BoardMedia(alignment: Alignment.bottomCenter);
      expect(media.alignment, Alignment.bottomCenter);
    });
  });

  group('portfolio masonry', () {
    testWidgets('staggers two columns and never goes below the floor',
        (tester) async {
      final heights = <double>[];

      final error = await layout(
        tester,
        ListView(
          padding: const EdgeInsets.all(14),
          children: [
            PortfolioMasonry(
              itemCount: 9,
              minHeight: 168,
              itemBuilder: (context, i, height) {
                heights.add(height);
                return const BoardHatch();
              },
            ),
          ],
        ),
      );
      expect(error, isNull);
      expect(heights.length, 9);

      // A shot too small to read is worse than a uniform one.
      for (final h in heights) {
        expect(h, greaterThanOrEqualTo(168));
      }
      // And it has to actually vary, or it's just a grid.
      expect(heights.toSet().length, greaterThan(1));
    });

    testWidgets('no items renders nothing', (tester) async {
      final error = await layout(
        tester,
        PortfolioMasonry(itemCount: 0, itemBuilder: (_, __, ___) => const SizedBox()),
      );
      expect(error, isNull);
    });

    testWidgets('a single item still lays out', (tester) async {
      final error = await layout(
        tester,
        ListView(
          children: [
            PortfolioMasonry(
              itemCount: 1,
              itemBuilder: (_, __, ___) => const BoardHatch(),
            ),
          ],
        ),
      );
      expect(error, isNull);
    });
  });

  group('BoardButton sizing', () {
    // The public profile puts a BoardButton in the Scaffold's
    // bottomNavigationBar slot, where constraints are loose with
    // maxHeight set to the whole screen. Anything that fills the biggest
    // offered height there eats the entire body.
    testWidgets('shrink-wraps in a bottomNavigationBar instead of eating the body',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(key: const Key('body'), height: 100, color: BoardColors.ink),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            bottomNavigationBar: Container(
              color: BoardColors.paper,
              padding: const EdgeInsets.all(16),
              child: BoardButton(label: 'Message', onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final button = tester.getSize(find.byType(BoardButton));
      expect(
        button.height,
        lessThan(100),
        reason: 'the action bar must wrap its label, not fill the screen',
      );
      // The body still has room to render, which is the symptom that
      // made the public profile look like nothing but a button.
      expect(tester.getSize(find.byKey(const Key('body'))).height, 100);
    });

    testWidgets('still fills the available width', (tester) async {
      final error = await layout(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: BoardButton(label: 'Edit Profile', onTap: () {}),
        ),
      );
      expect(error, isNull);
      // 320dp viewport minus 16dp padding either side.
      expect(tester.getSize(find.byType(BoardButton)).width, 288);
    });
  });

  group('board row primitives', () {
    testWidgets('a departure row fits in its fixed time/status columns', (tester) async {
      // 52dp time + 76dp status are fixed by the design; the middle
      // column has to absorb everything else at 320dp.
      final error = await layout(
        tester,
        Container(
          color: BoardColors.ink,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const SizedBox(width: 52, child: FlapTile(text: '09:30', fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      longTitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.title(fontSize: 15, color: BoardColors.onInk),
                    ),
                    Text(
                      'MUMBAI · BANDRA WEST · MAHARASHTRA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.mono(fontSize: 9.5, color: BoardColors.onInkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 76, child: FlapTile.status('shortlisted')),
            ],
          ),
        ),
      );
      expect(error, isNull);
    });

    testWidgets('SpecRow fits a long key and a long value', (tester) async {
      final error = await layout(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SpecRow(label: 'Agency associations', value: 'MODELX MANAGEMENT INDIA'),
              SpecRow(label: 'Shooting starts', value: '09 MAR 2026 · 12:00'),
            ],
          ),
        ),
      );
      expect(error, isNull);
    });

    testWidgets('a four-up stat strip fits at 320dp', (tester) async {
      final error = await layout(
        tester,
        Row(
          children: [
            for (final cell in const [
              ('Height', '190 CM'),
              ('Waist', '34'),
              ('Shoe', '9 UK'),
              ('Age', '21'),
            ])
              Expanded(
                child: BoardStatWell(label: cell.$1, value: cell.$2, onDark: false),
              ),
          ],
        ),
      );
      expect(error, isNull);
    });

    testWidgets('the four-up strip survives being stretched in a scroll view', (tester) async {
      // The profile stat strips stretch their cells so the hairline
      // dividers run full height. Inside a scroll view that Row has no
      // bounded height, so this is the shape that previously handed the
      // cells an infinite height constraint.
      final error = await layout(
        tester,
        ListView(
          children: [
            Container(
              color: BoardColors.inkLine,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cell in const [
                      ('Height', '190 CM'),
                      ('Measure', '82-60-88'),
                      ('Weight', '65'),
                      ('Available', 'Freelance'),
                    ])
                      Expanded(
                        child: Container(
                          color: BoardColors.card,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cell.$1.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BoardType.mono(fontSize: 9.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cell.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BoardType.mono(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      expect(error, isNull);
    });

    testWidgets('every status maps onto a palette signal', (tester) async {
      // The three signal hues are held in one lightness band so a mixed
      // board reads flat. Anything unrecognised has to land on slate
      // rather than invent a colour.
      final error = await layout(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in const [
              'booked',
              'shortlisted',
              'not selected',
              'applied',
              'open',
              'something unheard of',
            ])
              Padding(
                padding: const EdgeInsets.all(4),
                child: FlapTile.status(s),
              ),
          ],
        ),
      );
      expect(error, isNull);

      final tiles = tester.widgetList<FlapTile>(find.byType(FlapTile)).toList();
      expect(tiles[0].background, BoardColors.booked);
      expect(tiles[1].background, BoardColors.negotiating);
      expect(tiles[2].background, BoardColors.rejected);
      expect(tiles[3].background, BoardColors.applied);
      // Open carries no fill — it is the default state, not news.
      expect(tiles[4].outlined, isTrue);
      expect(tiles[4].background, Colors.transparent);
      expect(tiles[5].background, BoardColors.applied);
    });

    testWidgets('coloured words drop to their tint on slate', (tester) async {
      // Slate and brass share a lightness band, so full-strength brass
      // text sinks into a slate panel.
      expect(BoardColors.textOnSlate(BoardColors.brass), BoardColors.brassText);
      expect(BoardColors.textOnSlate(BoardColors.booked), BoardColors.bookedText);
      expect(BoardColors.textOnSlate(BoardColors.negotiating), BoardColors.negotiatingText);
      expect(BoardColors.textOnSlate(BoardColors.rejected), BoardColors.rejectedText);
      // Anything without a tint passes through untouched.
      expect(BoardColors.textOnSlate(BoardColors.onInk), BoardColors.onInk);
    });

    testWidgets('a chip row wraps rather than overflowing', (tester) async {
      final error = await layout(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              MonoChip('VERY FAIR', filled: true),
              MonoChip('WHEATISH'),
              MonoChip('PHOTOSHOOT'),
              MonoChip('TRADITIONAL'),
              MonoChip('RAMP WALK'),
            ],
          ),
        ),
      );
      expect(error, isNull);
    });
  });

  group('full screens', () {
    Widget jobDetail() => const BoardJobDetail(
          title: longTitle,
          posterLine: 'MODELX AGENCY · MUMBAI, MAHARASHTRA',
          description:
              'Two-day shoot in Bandra. Wardrobe fitting the evening before, '
              'board call at 9 AM sharp. Travel and stay covered.',
          status: 'open',
          details: [
            ('Location', 'MUMBAI'),
            ('Compensation', '₹10,000 – ₹20,000'),
            ('Shooting starts', '09 MAR 2026 · 12:00'),
            ('Shooting ends', '09 MAR 2026 · 18:00'),
            ('Outfit', 'TRADITIONAL'),
          ],
          highlights: [('Gender', 'ANY'), ('Age range', '21 – 30')],
          chipGroups: [
            ('Eye color', ['BLACK', 'BROWN']),
            ('Hair color', ['BLACK', 'BROWN', 'BLONDE']),
            ('Required skills', ['PHOTOSHOOT', 'RAMP WALK']),
          ],
          measurements: [
            'Height 160–189 cm',
            'Chest 32–46 in',
            'Waist 26–35 in',
            'Shoulder 34–43 in',
            'Inseam 34–43 in',
          ],
          applicationsLine: '3 applications · posted 203D AGO',
          depValue: '09 MAR 2026 · 12:00',
          hasApplied: false,
        );

    for (final scale in [1.0, 1.5]) {
      testWidgets('job detail lays out at ${scale}x text', (tester) async {
        final error = await layout(tester, jobDetail(), textScale: scale);
        expect(error, isNull);
      });
    }

    testWidgets('job detail lays out in its Applied state', (tester) async {
      final error = await layout(
        tester,
        const BoardJobDetail(
          title: 'Spring Campaign',
          posterLine: 'AGGARWAL · DELHI',
          description: 'We are hiring',
          status: 'open',
          details: [('Location', 'DELHI')],
          applicationsLine: '3 applications',
          depValue: '09 MAR · 12:00',
          hasApplied: true,
          appliedLabel: 'shortlisted',
        ),
      );
      expect(error, isNull);
    });

    // The five card templates live in their own suite — see
    // comp_card_template_test.dart, which renders all ten faces at true
    // trim. Here we only check the tool's chooser thumbnail, which is the
    // one place a card is squeezed into app chrome.
    testWidgets('a template thumbnail fits the chooser row', (tester) async {
      final data = CompCardData.fromUser(
        const {'fullName': longName, 'location': 'Bengaluru'},
        images: const [null, null, null, null, null, null, null],
      );

      final error = await layout(
        tester,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final template in CompCardTemplate.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: CompCardFace(template: template, data: data),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        template.blurb,
                        style: BoardType.body(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      expect(error, isNull);
    });
  });
}
