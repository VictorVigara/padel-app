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

    // Half-court is rendered with the NET at the top and the back wall at
    // the bottom (matches the row slicing in `_halfHeatmap`). In padel the
    // service line is 3 m from the back wall (≈ 7 m from the net), so on a
    // 10 m half-court it sits at 7/10 of the height from the top.
    const serviceLineRatio = 7.0 / 10.0;
    final serviceLineY = size.height * serviceLineRatio;
    canvas.drawLine(
        Offset(0, serviceLineY), Offset(size.width, serviceLineY), interiorPaint);

    // Center service line divides the two service boxes (the area between
    // the net and the service line), so it runs from the net down to the
    // service line.
    final midX = size.width / 2;
    canvas.drawLine(
        Offset(midX, 0), Offset(midX, serviceLineY), interiorPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // Net: highlighted top edge so the orientation is unambiguous.
    final netPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), netPaint);
  }

  @override
  bool shouldRepaint(CourtHeatmapPainter oldDelegate) =>
      oldDelegate.heatmap != heatmap || oldDelegate.playerColor != playerColor;
}

class CourtHeatmapWidget extends StatelessWidget {
  final List<List<double>> fullHeatmap;
  final Color playerColor;
  final bool showYourSide;
  final ValueChanged<bool> onSideChanged;

  const CourtHeatmapWidget({
    super.key,
    required this.fullHeatmap,
    required this.playerColor,
    required this.showYourSide,
    required this.onSideChanged,
  });

  List<List<double>> get _halfHeatmap {
    if (fullHeatmap.length < 20) return fullHeatmap;

    if (showYourSide) {
      // Near half (rows 0–9), reversed so the net sits at the top of the
      // display and the near baseline at the bottom.
      return fullHeatmap.sublist(0, 10).reversed.toList();
    }
    // Far half (rows 10–19): net already at top (row 10). Mirror columns
    // so the display reads from the opponent's own forward-facing POV —
    // display col 0 = opponent's left.
    return fullHeatmap
        .sublist(10, 20)
        .map((row) => row.reversed.toList())
        .toList();
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
              selected: showYourSide,
              onSelected: (_) => onSideChanged(true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("Opponents' Side"),
              selected: !showYourSide,
              onSelected: (_) => onSideChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: CourtHeatmapPainter(
              heatmap: _halfHeatmap,
              playerColor: playerColor,
            ),
          ),
        ),
      ],
    );
  }
}