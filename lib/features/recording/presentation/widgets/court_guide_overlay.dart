import 'package:flutter/material.dart';

/// Overlay banner shown at the top of the camera preview.
///
/// Green when the court angle looks good; amber when the user needs to adjust.
class CourtGuideOverlay extends StatelessWidget {
  final bool courtOk;
  final String? message;

  const CourtGuideOverlay({
    super.key,
    required this.courtOk,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    final color = courtOk
        ? const Color(0xFF388E3C) // deep green
        : const Color(0xFFF57F17); // amber

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(230),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                courtOk ? Icons.check_circle_outline : Icons.adjust,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
