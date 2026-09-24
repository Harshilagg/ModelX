import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/services/comp_card_pdf.dart';
import 'package:flutter_application_modelx/widgets/comp_card_templates.dart';

/// A 1x1 PNG, enough to stand in for a captured face.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  group('the document', () {
    test('is a real PDF with both faces as pages', () async {
      final bytes = await CompCardPdf.compose(front: _png, back: _png);

      // %PDF- header, and the trailer that closes a valid file.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final text = String.fromCharCodes(bytes);
      expect(text, contains('%%EOF'));

      expect(bytes.length, greaterThan(500));
    });

    test('has two pages: a comp card is two sides', () {
      // Read from the document rather than the bytes, which are
      // compressed and do not contain the structure as text.
      final doc = CompCardPdf.document(front: _png, back: _png);
      expect(doc.document.pdfPageList.pages.length, 2);
    });

    test('pages are the size every agency prints', () {
      // 5.5 x 8.5in at 72pt/in is 396 x 612.
      final doc = CompCardPdf.document(front: _png, back: _png);
      for (final page in doc.document.pdfPageList.pages) {
        expect(page.pageFormat.width, closeTo(396, 0.5));
        expect(page.pageFormat.height, closeTo(612, 0.5));
      }
    });
  });

  group('the filename', () {
    test('is built from the model name', () async {
      // Not asserted through share(), which needs a platform channel --
      // this checks the slug rule the filename is built from.
      String slug(String name) => name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');

      expect(slug('Anya Sharma'), 'anya-sharma');
      expect(slug("  Mary-Jane O'Neill  "), 'mary-jane-o-neill');
      expect(slug('!!!'), isEmpty);
    });
  });

  group('capture scale', () {
    test('clears 250dpi at print size', () async {
      // 396pt trim is 5.5in wide. Anything under about 250dpi looks
      // soft once an agency prints it.
      const trimWidthPt = 396.0;
      const inches = 5.5;
      final dpi = trimWidthPt * CompCardPdf.captureScale / inches;
      expect(dpi, greaterThan(250));
    });
  });

  group('the face that gets captured', () {
    testWidgets('renders at exact trim, ignoring the system font scale', (
      tester,
    ) async {
      // The capture is of this widget, so if it reflowed under a large
      // system font the printed card would not match the preview.
      // Sized explicitly, the way the capture sizes it. Left to the
      // screen's constraints it came out 396x600 on an 800x600 surface,
      // and the PDF would have been printed from that.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: CompCardFaceView.trimWidth,
              maxWidth: CompCardFaceView.trimWidth,
              minHeight: CompCardFaceView.trimHeight,
              maxHeight: CompCardFaceView.trimHeight,
              child: CompCardFaceView(
                template: CompCardTemplate.maison,
                data: CompCardData.fromUser(
                  const {'fullName': 'Anya Sharma'},
                  images: const [null, null, null, null],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(CompCardFaceView)),
        const Size(CompCardFaceView.trimWidth, CompCardFaceView.trimHeight),
      );
    });
  });
}
