import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../ui/board_theme.dart';
import 'board_widgets.dart';

/// Opens somebody's profile photograph.
///
/// A profile photo is shown as a circle everywhere else in the app, so
/// showing it full-bleed when tapped meant the framing you chose was not
/// the framing you got — the page cropped it again, differently. This
/// shows the same circle, larger, over a blur of the page you came from.
///
/// Tapping anywhere outside the circle closes it.
Future<void> showProfilePhoto(
  BuildContext context, {
  required String? url,
  required String name,

  /// Supplied only for your own profile: adds the pen.
  VoidCallback? onEdit,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      final size = MediaQuery.of(dialogContext).size.shortestSide * 0.78;

      // Transparent Material, not decoration: a dialog route has no
      // Material ancestor of its own, and Text without one is painted
      // with Flutter's yellow "missing style" underline.
      return Material(
        type: MaterialType.transparency,
        child: Stack(
        children: [
          // The blur is the backdrop *and* the dismiss target, so there
          // is no small close button to hunt for.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: BoardColors.ink.withValues(alpha: 0.55),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    // Absorbs its own taps so the photo isn't a dismiss
                    // target — only the blur around it is.
                    GestureDetector(
                      onTap: () {},
                      child: BoardAvatar(
                        url: url,
                        name: name,
                        size: size,
                        onDark: true,
                        ring: true,
                      ),
                    ),
                    if (onEdit != null)
                      Positioned(
                        right: size * 0.06,
                        bottom: size * 0.06,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onEdit();
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: BoardColors.brass,
                              shape: BoxShape.circle,
                              border: Border.all(color: BoardColors.ink, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 20, color: BoardColors.ink),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: BoardType.display(fontSize: 26, color: BoardColors.onInk, height: 1),
                ),
                const SizedBox(height: 10),
                Text(
                  'TAP ANYWHERE TO CLOSE',
                  style: BoardType.mono(fontSize: 9.5, color: BoardColors.onInkFaint),
                ),
              ],
            ),
          ),
        ],
        ),
      );
    },
  );
}

/// Choose which part of a photograph becomes the avatar.
///
/// Pan and pinch inside the circle; what you see is what is saved. The
/// app crops to a circle everywhere, so letting people frame that circle
/// themselves is the difference between a portrait and a picture of
/// somebody's shoulder.
class AvatarCropPage extends StatefulWidget {
  final File source;
  const AvatarCropPage({super.key, required this.source});

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _boundary = GlobalKey();
  final _controller = TransformationController();
  bool _saving = false;

  /// The photograph's own dimensions.
  ///
  /// Needed before anything can be framed: the child has to be laid out
  /// at the picture's real aspect so it *overflows* the circle on one
  /// axis. Sized to the circle instead — as this was — there is nothing
  /// outside the viewport to pan to, which is why zoom worked and drag
  /// did nothing.
  Size? _natural;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    _stream = FileImage(widget.source).resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _natural = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ));
    }, onError: (_, __) {
      if (!mounted) return;
      setState(() => _natural = const Size(1, 1));
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _controller.dispose();
    super.dispose();
  }

  /// The child's size: the shorter edge matches the circle, the longer
  /// one runs past it. That overflow is the room to pan.
  Size _childSize(double diameter) {
    final natural = _natural!;
    final aspect = natural.width / natural.height;
    return aspect >= 1
        ? Size(diameter * aspect, diameter)
        : Size(diameter, diameter / aspect);
  }

  /// Start centred, so the first thing shown is the middle of the
  /// picture rather than its top-left corner.
  void _centre(double diameter) {
    final child = _childSize(diameter);
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        -(child.width - diameter) / 2,
        -(child.height - diameter) / 2,
        0,
        1,
      );
  }

  /// Renders exactly what the circle is showing.
  ///
  /// Capturing the boundary rather than transforming the source file
  /// keeps this to `dart:ui` — no crop package, no extra platform
  /// configuration — and guarantees the saved image matches the preview
  /// because it *is* the preview.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final boundary =
          _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      // 3x so the avatar stays sharp when it is shown large.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode the crop');

      // Written beside the picked file, whose directory the picker
      // already gave us — so this needs no path_provider.
      final out = File(
        '${widget.source.parent.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      Navigator.of(context).pop(out);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that crop. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = MediaQuery.of(context).size.width - 48;

    return Scaffold(
      backgroundColor: BoardColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('CANCEL',
                        style: BoardType.mono(fontSize: 11, color: BoardColors.onInkSoft)),
                  ),
                  Expanded(
                    child: Text(
                      'FRAME YOUR PHOTO',
                      textAlign: TextAlign.center,
                      style: BoardType.title(
                          fontSize: 15, letterSpacing: 1.9, color: BoardColors.onInk),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _natural == null
                    ? const CircularProgressIndicator(color: BoardColors.brass)
                    : _viewport(diameter),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                'Drag to move, pinch to zoom. What fills the circle is what people see.',
                textAlign: TextAlign.center,
                style: BoardType.body(fontSize: 12.5, color: BoardColors.onInkSoft),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _natural == null ? null : () => setState(() => _centre(diameter)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      color: BoardColors.slate,
                      child: Text('RESET',
                          style: BoardType.mono(fontSize: 10, color: BoardColors.onInk)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BoardButton(
                      label: _saving ? 'Saving…' : 'Use this photo',
                      background: BoardColors.brass,
                      foreground: BoardColors.ink,
                      onTap: (_saving || _natural == null) ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewport(double diameter) {
    final child = _childSize(diameter);

    // Centre on the first build, once the size is known.
    if (_controller.value == Matrix4.identity()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centre(diameter);
      });
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        children: [
          // Only this is captured — the grid above it is not.
          RepaintBoundary(
            key: _boundary,
            child: ClipOval(
              child: InteractiveViewer(
                transformationController: _controller,
                // Unconstrained so the child keeps its own size and can
                // sit larger than the viewport, and an unbounded margin
                // so translation isn't clamped back inside it.
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.5,
                maxScale: 6,
                child: SizedBox(
                  width: child.width,
                  height: child.height,
                  child: Image.file(widget.source, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size(diameter, diameter),
              painter: _CropGuidePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rule-of-thirds inside the circle, and a rim to show where the crop
/// ends. Drawn over the capture, never into it.
class _CropGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rim = Paint()
      ..color = BoardColors.onInk.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 1, rim);

    final grid = Paint()
      ..color = BoardColors.onInk.withValues(alpha: 0.28)
      ..strokeWidth = 1;

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropGuidePainter oldDelegate) => false;
}

/// Kept so the capture path has a single named type at the call site.
typedef CroppedAvatar = Uint8List;
