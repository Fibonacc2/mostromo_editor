import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../core/app_theme.dart';
import 'page_layout.dart';
import 'custom_layout.dart';

class EditorPainter extends CustomPainter {
  final List<LogicalLine> lines;
  final PageLayout layout;
  final int plainTextLength;
  final int cursorIndex;
  final int? selectionBase;
  final bool showCursor;
  final double currentFontSize;
  final Map<int, ui.Image> imageCache;
  final bool isMobile;

  EditorPainter({
    required this.lines,
    required this.layout,
    required this.plainTextLength,
    required this.cursorIndex,
    required this.showCursor,
    this.selectionBase,
    required this.currentFontSize,
    required this.imageCache,
    required this.isMobile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawContent(double logicalStart, double logicalEnd) {
      for (int i = 0; i < lines.length; i++) {
        var line = lines[i];

        if (layout.isPageMode &&
            (line.dy + line.height < logicalStart || line.dy > logicalEnd)) {
          continue;
        }

        canvas.save();
        canvas.translate(0, line.dy);

        final List<TextSpan> spans = line.words.map((w) {
          return TextSpan(text: w.text, style: w.style);
        }).toList();

        final linePainter = TextPainter(
          text: TextSpan(children: spans),
          textDirection: TextDirection.ltr,
        )..layout();

        // 1. SEÇİM (SELECTION) ÇİZİMİ
        if (selectionBase != null && selectionBase != cursorIndex) {
          int start = math.min(selectionBase!, cursorIndex);
          int end = math.max(selectionBase!, cursorIndex);

          if (end >= line.startOffset &&
              start <= line.startOffset + line.length) {
            int localStart = math.max(0, start - line.startOffset);
            int localEnd = math.min(line.length, end - line.startOffset);

            final boxes = linePainter.getBoxesForSelection(
              TextSelection(baseOffset: localStart, extentOffset: localEnd),
            );

            final selectionPaint = Paint()
              ..color = MostromoTheme.accentColor.withValues(alpha: 0.3);

            for (final box in boxes) {
              canvas.drawRect(box.toRect(), selectionPaint);
            }
          }
        }

        // 2. SATIRI ÇİZ
        linePainter.paint(canvas, Offset.zero);

        // 3. İMLECİ (CURSOR) ÇİZ
        if (showCursor &&
            (selectionBase == null || selectionBase == cursorIndex)) {
          // 🌟 ÇÖZÜM: İmleç hesabı! Bu satırın sorumluluk alanı, bir sonraki satırın başına kadardır.
          int nextLineStart = (i + 1 < lines.length)
              ? lines[i + 1].startOffset
              : plainTextLength + 1;
          bool inThisLine =
              (cursorIndex >= line.startOffset && cursorIndex < nextLineStart);

          if (inThisLine) {
            int localCursor = cursorIndex - line.startOffset;

            // Eğer indeks "\n" gibi görünmez bir karakterdeyse, onu çizilebilecek en son harfe (satır sonuna) kenetle
            if (localCursor > line.length) {
              localCursor = line.length;
            }

            final caretOffset = linePainter.getOffsetForCaret(
              TextPosition(
                offset: localCursor,
                affinity: TextAffinity.downstream,
              ),
              Rect.zero,
            );

            final cursorPaint = Paint()
              ..color = MostromoTheme.accentColor
              ..strokeWidth = 2.0;

            final metrics = linePainter.computeLineMetrics();
            double cursorHeight = metrics.isNotEmpty
                ? metrics.first.height
                : line.height;
            double cursorTop = 0;

            canvas.drawLine(
              Offset(caretOffset.dx, cursorTop),
              Offset(caretOffset.dx, cursorTop + cursorHeight),
              cursorPaint,
            );
          }
        }

        canvas.restore();
      }
    }

    if (!layout.isPageMode) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = MostromoTheme.backgroundColor,
      );
      canvas.translate(32, 32);
      drawContent(0, double.infinity);
    } else {
      for (int i = 0; i < layout.totalPages; i++) {
        canvas.save();
        double pageTop = i * (layout.a4Height + layout.pageGap);
        Rect pageRect = Rect.fromLTWH(
          0,
          pageTop,
          layout.a4Width,
          layout.a4Height,
        );

        canvas.drawShadow(
          Path()..addRect(pageRect),
          Colors.black.withValues(alpha: 0.6),
          16.0,
          true,
        );
        canvas.drawRect(
          pageRect,
          Paint()..color = MostromoTheme.backgroundColor,
        );
        canvas.drawRect(
          pageRect,
          Paint()
            ..color = Colors.white10
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        double startLogicalY = layout.pageBreaks[i];
        double endLogicalY = (i + 1 < layout.pageBreaks.length)
            ? layout.pageBreaks[i + 1]
            : layout.logicalHeight;
        double contentHeightForThisPage = endLogicalY - startLogicalY;

        double bleedPadding = 5.0;
        double topClipOffset = (i > 0) ? bleedPadding : 0.0;
        double bottomClipOffset = bleedPadding;

        Rect printableRect = Rect.fromLTWH(
          layout.marginLeft,
          pageTop + layout.marginTop + topClipOffset,
          layout.a4Width - layout.marginLeft - layout.marginRight,
          contentHeightForThisPage - topClipOffset + bottomClipOffset,
        );

        canvas.clipRect(printableRect);
        canvas.translate(
          layout.marginLeft,
          pageTop + layout.marginTop - startLogicalY,
        );

        drawContent(startLogicalY, endLogicalY);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.plainTextLength != plainTextLength ||
        oldDelegate.cursorIndex != cursorIndex ||
        oldDelegate.selectionBase != selectionBase ||
        oldDelegate.showCursor != showCursor ||
        oldDelegate.layout != layout ||
        oldDelegate.currentFontSize != currentFontSize;
  }
}
