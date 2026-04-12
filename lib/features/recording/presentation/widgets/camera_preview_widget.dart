import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Fullscreen camera preview that fills its parent.
///
/// Shows a centered loading indicator while the controller initialises.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox.expand(
      child: AspectRatio(
        aspectRatio: 1 / ctrl.value.aspectRatio,
        child: CameraPreview(ctrl),
      ),
    );
  }
}
