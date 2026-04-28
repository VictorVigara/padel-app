import 'package:flutter/material.dart';

class CourtHeatmapPainter extends CustomPainter {
  final List<List<double>> heatmap; // 10 rows × 10 cols (half-court)
  final Color playerColor;

  CourtHeatmapPainter({required this.heatmap, required this.playerColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (heatmap.isEmpty) return;

    final rows = heatmap.length;
    final cols = heatmap[0].length;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    double maxVal = 0;
    for (final row in heatmap) {
      for (final v in row) {
        if (v > maxVal) maxVal = v;
      }
    }

    final cellPaint = Paint();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final intensity =
            maxVal > 0 ? (heatmap[r][c] / maxVal).clamp(0.0, 1.0) : 0.0;
        cellPaint.color = playerColor.withAlpha((intensity * 200).round());
        canvas.drawRect(
          Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH),
          cellPaint,
        );
      }
    }

    final interiorPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), interiorPaint);

    final midX = size.width / 2;
    canvas.drawLine(Offset(midX, midY), Offset(midX, size.height), interiorPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(CourtHeatmapPainter oldDelegate) =>
      oldDelegate.heatmap != heatmap || oldDelegate.playerColor != playerColor;
}

class CourtHeatmapWidget extends StatefulWidget {
  final List<List<double>> fullHeatmap;
  final Color playerColor;

  /// When true, "Your Side" and "Opponents' Side" row slices are swapped.
  final bool flipCourt;

  const CourtHeatmapWidget({
    super.key,
    required this.fullHeatmap,
    required this.playerColor,
    this.flipCourt = false,
  });

  @override
  State<CourtHeatmapWidget> createState() => _CourtHeatmapWidgetState();
}

class _CourtHeatmapWidgetState extends State<CourtHeatmapWidget> {
  bool _showYourSide = true;

  List<List<double>> get _halfHeatmap {
    final full = widget.fullHeatmap;
    if (full.length < 20) return full;

    final yourRows = full.sublist(0, 10);
    final oppRows = full.sublist(10, 20);

    if (widget.flipCourt) {
      return _showYourSide ? oppRows : yourRows;
    }
    return _showYourSide ? yourRows : oppRows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Your Side'),
              selected: _showYourSide,
              onSelected: (_) => setState(() => _showYourSide = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("Opponents' Side"),
              selected: !_showYourSide,
              onSelected: (_) => setState(() => _showYourSide = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: CourtHeatmapPainter(
              heatmap: _halfHeatmap,
              playerColor: widget.playerColor,
            ),
          ),
        ),
      ],
    );
  }
}