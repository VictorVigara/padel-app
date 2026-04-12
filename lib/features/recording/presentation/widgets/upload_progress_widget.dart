import 'package:flutter/material.dart';

/// Progress overlay shown during video upload to Cloudflare R2.
class UploadProgressWidget extends StatelessWidget {
  final int bytesUploaded;
  final int totalBytes;

  const UploadProgressWidget({
    super.key,
    required this.bytesUploaded,
    required this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;
    final uploadedMb = bytesUploaded / (1024 * 1024);
    final totalMb = totalBytes / (1024 * 1024);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uploading match video…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can lock your phone — upload continues in background',
              style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6F00)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${uploadedMb.toStringAsFixed(0)} MB / ${totalMb.toStringAsFixed(0)} MB',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
