import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:padel_app/features/recording/domain/models/court_keypoints.dart';

/// Screen that lets the user position a fixed crosshair over each court
/// keypoint by panning/zooming the image, then tapping Place to confirm.
///
/// Flow:
///   1. Frame displayed inside InteractiveViewer. Fixed crosshair overlaid
///      on the centre of the viewport area.
///   2. Instruction bar prompts each keypoint in order with Place/Skip/Undo.
///   3. Place → records pixel coord under crosshair, advances to next point.
///   4. After all 12 steps, Confirm button appears (requires ≥4 non-null).
///   5. Confirm POSTs keypoints JSON to backend (placeholder URL), then
///      navigates to /matches/:id/edit regardless of POST outcome.
///   6. If framePath is null, skips calibration and goes straight to edit.
class CourtCalibrationScreen extends StatefulWidget {
  final String matchId;
  final String? framePath;

  const CourtCalibrationScreen({
    super.key,
    required this.matchId,
    required this.framePath,
  });

  @override
  State<CourtCalibrationScreen> createState() => _CourtCalibrationScreenState();
}

class _CourtCalibrationScreenState extends State<CourtCalibrationScreen> {
  final TransformationController _transformController =
      TransformationController();

  // Key on the InteractiveViewer itself. Its RenderBox size is the viewport
  // size and its local origin is definitionally the viewport origin — making
  // M⁻¹ × viewportCentre unambiguously correct.
  final GlobalKey _viewportKey = GlobalKey();

  // Key on the Stack inside InteractiveViewer. Used by _getImageRect() to
  // get the container size for the applyBoxFit letterbox calculation.
  final GlobalKey _stackKey = GlobalKey();

  // Normalised positions (0–1) within the image rect — for dot rendering.
  final List<Offset?> _normTaps = List.filled(12, null);

  // Original image pixel coordinates — sent to the backend.
  final List<Offset?> _pixelTaps = List.filled(12, null);

  int _currentIndex = 0;
  bool _submitting = false;

  // Decoded pixel dimensions of the source image.
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    if (widget.framePath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/matches/${widget.matchId}/edit');
      });
      return;
    }
    _loadImageSize();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _loadImageSize() {
    final stream =
        FileImage(File(widget.framePath!)).resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
    }));
  }

  bool get _allStepsDone => _currentIndex >= courtKeypoints.length;
  int get _nonNullCount => _normTaps.where((t) => t != null).length;

  // Compute the rendered rect of the image inside the inner Stack.
  // SizedBox.expand fills the Stack to the full viewport area, so box.size
  // is the full container — applyBoxFit gives the exact letterbox rect.
  Rect? _getImageRect() {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _imageSize == null) return null;
    final stackSize = box.size;
    final fitted = applyBoxFit(BoxFit.contain, _imageSize!, stackSize);
    return Alignment.center.inscribe(fitted.destination, Offset.zero & stackSize);
  }

  // Compute the image pixel coordinate currently under the crosshair centre.
  //
  // _viewportKey is on the InteractiveViewer — its RenderBox local origin IS
  // the viewport origin, so viewportBox.size.center(Offset.zero) is exactly
  // the crosshair position in the coordinate space that M operates on.
  //
  // Steps:
  //   1. Crosshair centre in viewport-local coords = viewportBox.size.center.
  //   2. Apply M⁻¹ → Stack-natural (image-layout) coordinates.
  //   3. Subtract letterbox offset, scale by imageSize/imageRect → pixels.
  Offset? _getCrosshairPixelCoords() {
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || _imageSize == null) return null;

    final imageRect = _getImageRect();
    if (imageRect == null) return null;

    // Centre of the InteractiveViewer viewport in its own local space.
    final crosshairInViewport = viewportBox.size.center(Offset.zero);

    // toScene() converts a viewport point to scene (inner Stack) coordinates,
    // accounting for the current pan and zoom. No manual matrix inversion needed.
    final sceneCoords = _transformController.toScene(crosshairInViewport);

    // Reject if the crosshair is over the letterbox rather than the image.
    if (!imageRect.contains(sceneCoords)) return null;

    // Normalise within image rect then scale to original pixel dimensions.
    final norm = Offset(
      (sceneCoords.dx - imageRect.left) / imageRect.width,
      (sceneCoords.dy - imageRect.top) / imageRect.height,
    );
    return Offset(
      norm.dx * _imageSize!.width,
      norm.dy * _imageSize!.height,
    );
  }

  void _place() {
    if (_allStepsDone || _submitting) return;
    final pixelCoords = _getCrosshairPixelCoords();
    if (pixelCoords == null) return; // crosshair outside image — ignore

    // Derive normalised coord for dot rendering from pixel coords.
    final norm = Offset(
      pixelCoords.dx / _imageSize!.width,
      pixelCoords.dy / _imageSize!.height,
    );

    setState(() {
      _normTaps[_currentIndex] = norm;
      _pixelTaps[_currentIndex] = pixelCoords;
      _currentIndex++;
    });

    // When all keypoints are done, reset zoom/pan so the confirm screen
    // shows the image at natural scale and dots align correctly.
    if (_currentIndex >= courtKeypoints.length) {
      _transformController.value = Matrix4.identity();
    }
  }

  void _skip() {
    if (_allStepsDone || _submitting) return;
    setState(() {
      _normTaps[_currentIndex] = null;
      _pixelTaps[_currentIndex] = null;
      _currentIndex++;
    });
  }

  void _undo() {
    if (_currentIndex == 0 || _submitting) return;
    setState(() {
      _currentIndex--;
      _normTaps[_currentIndex] = null;
      _pixelTaps[_currentIndex] = null;
    });
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);

    try {
      final keypoints = List.generate(12, (i) {
        final px = _pixelTaps[i];
        if (px == null) return null;
        final kp = courtKeypoints[i];
        return {
          'label': kp.label,
          'x_px': px.dx,
          'y_px': px.dy,
          'x_m': kp.xMeters,
          'y_m': kp.yMeters,
        };
      });

      final backendUrl = const String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://localhost:8000',
      );
      final calibrateUrl = '$backendUrl/calibrate';
      await http.post(
        Uri.parse(calibrateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'match_id': widget.matchId,
          'keypoints': keypoints,
        }),
      );
    } catch (_) {
      // Best-effort — calibration failure must not strand the user.
    }

    if (mounted) context.go('/matches/${widget.matchId}/edit');
  }

  // Build placed-keypoint dots, recomputed from normalised coords + current
  // image rect on every build so they track the image through pan/zoom.
  List<Widget> _buildDots(Rect imageRect) {
    final dots = <Widget>[];
    for (int i = 0; i < _currentIndex; i++) {
      final norm = _normTaps[i];
      if (norm == null) continue;
      final left = imageRect.left + norm.dx * imageRect.width;
      final top = imageRect.top + norm.dy * imageRect.height;
      dots.add(
        Positioned(
          left: left - 8,
          top: top - 8,
          child: _KeypointDot(label: courtKeypoints[i].label),
        ),
      );
    }
    return dots;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.framePath == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final kp = _allStepsDone ? null : courtKeypoints[_currentIndex];
    final canConfirm = _allStepsDone && _nonNullCount >= 4 && !_submitting;
    final imageRect = _getImageRect();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _InstructionBar(
              keypoint: kp,
              currentIndex: _currentIndex,
              allDone: _allStepsDone,
              nonNullCount: _nonNullCount,
              onPlace: (!_allStepsDone && !_submitting) ? _place : null,
              onSkip: (!_allStepsDone && !_submitting) ? _skip : null,
              onUndo: (_currentIndex > 0 && !_submitting) ? _undo : null,
              onConfirm: canConfirm ? _confirm : null,
              submitting: _submitting,
            ),
            Expanded(
              // Outer Stack so the crosshair overlay sits above
              // InteractiveViewer but within the Expanded viewport area.
              child: Stack(
                children: [
                  InteractiveViewer(
                    key: _viewportKey,
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 10.0,
                    child: Stack(
                      key: _stackKey,
                      children: [
                        // SizedBox.expand ensures the inner Stack always fills
                        // the full viewport, giving _getImageRect() a stable
                        // container size to work against.
                        SizedBox.expand(
                          child: Image.file(
                            File(widget.framePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (imageRect != null) ..._buildDots(imageRect),
                      ],
                    ),
                  ),
                  // Fixed crosshair centred on the viewport area.
                  // IgnorePointer so pan/zoom gestures pass through to
                  // InteractiveViewer underneath.
                  const IgnorePointer(
                    child: Center(
                      child: CustomPaint(
                        painter: _CrosshairPainter(),
                        size: Size(60, 60),
                      ),
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
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _InstructionBar extends StatelessWidget {
  final CourtKeypoint? keypoint;
  final int currentIndex;
  final bool allDone;
  final int nonNullCount;
  final VoidCallback? onPlace;
  final VoidCallback? onSkip;
  final VoidCallback? onUndo;
  final VoidCallback? onConfirm;
  final bool submitting;

  const _InstructionBar({
    required this.keypoint,
    required this.currentIndex,
    required this.allDone,
    required this.nonNullCount,
    required this.onPlace,
    required this.onSkip,
    required this.onUndo,
    required this.onConfirm,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    final text = allDone
        ? '$nonNullCount / 12 placed'
        : 'Centre on ${keypoint!.label}: ${keypoint!.name} (${currentIndex + 1}/12)';

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (onUndo != null)
            TextButton(
              onPressed: onUndo,
              child: const Text('Undo',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          if (onPlace != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ElevatedButton(
                onPressed: onPlace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Place',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ),
          if (allDone)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: submitting
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm',
                        style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 16×16 hollow circle with external crosshair arms. Court line visible
/// through the centre. Number label sits below the circle.
class _KeypointDot extends StatelessWidget {
  final String label;

  const _KeypointDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 22,
      child: CustomPaint(
        painter: _DotPainter(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            label.replaceFirst('k', ''),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const cy = 8.0;
    const r = 7.0;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    const gap = 2.0;
    const armLen = 5.0;
    canvas.drawLine(Offset(cx - r - armLen, cy), Offset(cx - r - gap, cy), paint);
    canvas.drawLine(Offset(cx + r + gap, cy), Offset(cx + r + armLen, cy), paint);
    canvas.drawLine(Offset(cx, cy - r - armLen), Offset(cx, cy - r - gap), paint);
    canvas.drawLine(Offset(cx, cy + r + gap), Offset(cx, cy + r + armLen), paint);
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => false;
}

/// Crosshair painted at the centre of its canvas (60×60).
/// Positioned via Center widget inside the Expanded's Stack — so the visual
/// centre coincides with the InteractiveViewer viewport centre used in the
/// pixel coordinate math.
class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Shadow pass for contrast on any court colour.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Foreground pass.
    final fg = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const armLen = 20.0;
    const gap = 6.0;

    for (final paint in [shadow, fg]) {
      // Horizontal arms
      canvas.drawLine(Offset(cx - armLen, cy), Offset(cx - gap, cy), paint);
      canvas.drawLine(Offset(cx + gap, cy), Offset(cx + armLen, cy), paint);
      // Vertical arms
      canvas.drawLine(Offset(cx, cy - armLen), Offset(cx, cy - gap), paint);
      canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + armLen), paint);
      // Centre dot
      canvas.drawCircle(
          Offset(cx, cy), 2.0, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) => false;
}
