import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/comp_card_templates.dart';

/// Turns a comp card into a print-ready PDF.
///
/// The two faces are captured from the same [CompCardFaceView] widgets
/// the app already draws, rather than being rebuilt in the pdf
/// package's own primitives. Five templates times two faces is ten
/// layouts; reimplementing them would create a second set that drifts
/// from the first, and the version an agency prints is the one that
/// must not be wrong. Capturing means the PDF is by construction what
/// the preview showed.
///
/// The cost is that the pages carry a bitmap rather than selectable
/// text. For a comp card that is the right trade: it is a photographic
/// object, printed and pinned to a board, never searched.
class CompCardPdf {
  const CompCardPdf._();

  /// 5.5 x 8.5 inches -- the size every agency prints.
  static const double _widthInches = 5.5;
  static const double _heightInches = 8.5;

  /// Capture scale over the 396pt trim width.
  ///
  /// 396 x 4 = 1584px across 5.5in, about 288dpi. Print wants 300 and
  /// gets close enough that no one can tell; going higher costs real
  /// memory, since each face is held uncompressed while it is encoded
  /// and 4x is already ~15MB a side.
  static const double captureScale = 4.0;

  /// Renders both faces and returns the finished document.
  ///
  /// Must be called with a [context] that can push a route: the faces
  /// have to be laid out and painted before they can be captured, and
  /// a widget that is not in a tree paints nothing.
  static Future<Uint8List> build({
    required BuildContext context,
    required CompCardTemplate template,
    required CompCardData data,
  }) async {
    final faces = await _capture(context, template, data);
    return compose(front: faces.$1, back: faces.$2);
  }

  /// Lays the two captured faces into a two-page document.
  ///
  /// Separate from the capture so it can be tested without a widget
  /// tree.
  static Future<Uint8List> compose({
    required Uint8List front,
    required Uint8List back,
  }) async => document(front: front, back: back).save();

  /// The document before it is serialised.
  ///
  /// Exposed because a saved PDF is compressed, so its page structure
  /// cannot be read back out of the bytes.
  static pw.Document document({
    required Uint8List front,
    required Uint8List back,
  }) {
    final doc = pw.Document();
    const format = PdfPageFormat(
      _widthInches * PdfPageFormat.inch,
      _heightInches * PdfPageFormat.inch,
    );

    for (final face in [front, back]) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          // No margin: the capture is already the full trim, and a
          // margin here would shrink the card inside the page and
          // throw off every measurement on it.
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(face), fit: pw.BoxFit.fill),
        ),
      );
    }

    return doc;
  }

  /// Hands the finished PDF to the system so it can be saved, printed
  /// or sent on.
  ///
  /// The share sheet rather than a silent write to disk: on both
  /// platforms it is the one path that reaches Files, Drive, mail and
  /// the printer, and it tells the user where the file went.
  static Future<void> share({
    required Uint8List bytes,
    required String modelName,
  }) async {
    final slug = modelName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    await Printing.sharePdf(
      bytes: bytes,
      filename: '${slug.isEmpty ? 'comp' : slug}-comp-card.pdf',
    );
  }

  /// Paints both faces offscreen and captures them as PNGs.
  static Future<(Uint8List, Uint8List)> _capture(
    BuildContext context,
    CompCardTemplate template,
    CompCardData data,
  ) async {
    final result = await Navigator.of(context).push<(Uint8List, Uint8List)>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _FaceCapture(template: template, data: data),
      ),
    );

    if (result == null) {
      throw StateError('Comp card capture was cancelled');
    }
    return result;
  }
}

/// Paints the two faces at trim size and captures them.
///
/// They are painted underneath an opaque cover rather than hidden.
/// Offstage and zero opacity both skip painting entirely, and a
/// [RepaintBoundary] that never painted has nothing to hand back.
class _FaceCapture extends StatefulWidget {
  final CompCardTemplate template;
  final CompCardData data;

  const _FaceCapture({required this.template, required this.data});

  @override
  State<_FaceCapture> createState() => _FaceCaptureState();
}

class _FaceCaptureState extends State<_FaceCapture> {
  final _front = GlobalKey();
  final _back = GlobalKey();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;

    try {
      final front = await _grab(_front);
      final back = await _grab(_back);
      if (!mounted) return;
      Navigator.of(context).pop((front, back));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<Uint8List> _grab(GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // A boundary can still be mid-paint on the frame it first appears
    // in; capturing then yields a blank or partial image.
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 32));
      return _grab(key);
    }

    final image = await boundary.toImage(pixelRatio: CompCardPdf.captureScale);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    Widget face(GlobalKey key, {required bool back}) => RepaintBoundary(
      key: key,
      child: CompCardFaceView(
        template: widget.template,
        data: widget.data,
        back: back,
      ),
    );

    return Stack(
      children: [
        // Painted, then covered.
        //
        // Width and height are given explicitly so the faces are laid
        // out at true trim whatever the screen is. With only left and
        // top, a Positioned passes the stack's own size down as a
        // maximum, so on a phone narrower than 396pt or shorter than
        // 612pt the card was squashed -- and the PDF would have been
        // printed from the squashed version.
        Positioned(
          left: 0,
          top: 0,
          width: CompCardFaceView.trimWidth,
          height: CompCardFaceView.trimHeight,
          child: face(_front, back: false),
        ),
        Positioned(
          left: 0,
          top: CompCardFaceView.trimHeight,
          width: CompCardFaceView.trimWidth,
          height: CompCardFaceView.trimHeight,
          child: face(_back, back: true),
        ),
        const Positioned.fill(child: ColoredBox(color: Color(0xE6141513))),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFF4F2EC)),
              SizedBox(height: 16),
              Text(
                'Preparing your comp card...',
                style: TextStyle(color: Color(0xFFF4F2EC), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
