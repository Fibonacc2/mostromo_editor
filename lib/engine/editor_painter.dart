import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../core/app_theme.dart';
import 'page_layout.dart';

class EditorPainter extends CustomPainter {
  final TextPainter textPainter;
  final PageLayout layout;
  final int plainTextLength;
  final int cursorIndex;
  final int? selectionBase;
  final bool showCursor;
  final double currentFontSize;
  final Map<int, ui.Image> imageCache;
  final bool isMobile;

  EditorPainter({
    required this.textPainter,
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
    void drawContent() {
      if (selectionBase != null && selectionBase != cursorIndex) {
        final start = math.min(selectionBase!, cursorIndex);
        final end = math.max(selectionBase!, cursorIndex);
        final boxes = textPainter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        final selectionPaint = Paint()
          ..color = MostromoTheme.accentColor.withValues(alpha: 0.3);

        for (final box in boxes) {
          canvas.drawRect(box.toRect(), selectionPaint);
        }

        if (isMobile && boxes.isNotEmpty) {
          final handlePaint = Paint()..color = MostromoTheme.accentColor;

          final firstBox = boxes.first;
          final leftBottom = Offset(firstBox.left, firstBox.bottom);
          canvas.drawCircle(
            Offset(leftBottom.dx, leftBottom.dy + 6),
            7,
            handlePaint,
          );
          canvas.drawLine(
            Offset(firstBox.left, firstBox.top),
            leftBottom,
            handlePaint..strokeWidth = 2,
          );

          final lastBox = boxes.last;
          final rightBottom = Offset(lastBox.right, lastBox.bottom);
          canvas.drawCircle(
            Offset(rightBottom.dx, rightBottom.dy + 6),
            7,
            handlePaint,
          );
          canvas.drawLine(
            Offset(lastBox.right, lastBox.top),
            rightBottom,
            handlePaint..strokeWidth = 2,
          );
        }
      }

      textPainter.paint(canvas, Offset.zero);

      if (imageCache.isNotEmpty) {
        final paint = Paint()..filterQuality = FilterQuality.high;
        imageCache.forEach((offsetIndex, uiImage) {
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(
              baseOffset: offsetIndex,
              extentOffset: offsetIndex + 1,
            ),
          );
          if (boxes.isNotEmpty) {
            final rect = boxes.first.toRect();
            canvas.drawImageRect(
              uiImage,
              Rect.fromLTWH(
                0,
                0,
                uiImage.width.toDouble(),
                uiImage.height.toDouble(),
              ),
              rect,
              paint,
            );
          }
        });
      }

      if (showCursor &&
          (selectionBase == null || selectionBase == cursorIndex)) {
        final caretOffset = textPainter.getOffsetForCaret(
          TextPosition(offset: cursorIndex, affinity: TextAffinity.downstream),
          Rect.zero,
        );
        final cursorPaint = Paint()
          ..color = MostromoTheme.accentColor
          ..strokeWidth = 2.0;
        double cursorHeight = currentFontSize * 1.15;
        double cursorTop = caretOffset.dy;

        int leftIndex = cursorIndex - 1;
        int rightIndex = cursorIndex;
        Rect? validBox;

        if (leftIndex >= 0 && leftIndex < plainTextLength) {
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(baseOffset: leftIndex, extentOffset: leftIndex + 1),
          );
          if (boxes.isNotEmpty && (boxes.last.top - cursorTop).abs() < 5.0) {
            validBox = boxes.last.toRect();
          }
        }
        if (validBox == null && rightIndex < plainTextLength) {
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(baseOffset: rightIndex, extentOffset: rightIndex + 1),
          );
          if (boxes.isNotEmpty && (boxes.first.top - cursorTop).abs() < 5.0) {
            validBox = boxes.first.toRect();
          }
        }

        if (validBox != null) {
          cursorTop = validBox.top;
          cursorHeight = validBox.height;
        }
        canvas.drawLine(
          Offset(caretOffset.dx, cursorTop),
          Offset(caretOffset.dx, cursorTop + cursorHeight),
          cursorPaint,
        );
      }
    }

    if (!layout.isPageMode) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = MostromoTheme.backgroundColor,
      );
      canvas.translate(32, 32);
      drawContent();
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
        double contentHeightForThisPage = (i + 1 < layout.pageBreaks.length)
            ? (layout.pageBreaks[i + 1] - startLogicalY)
            : (layout.logicalHeight - startLogicalY);

        Rect printableRect = Rect.fromLTWH(
          layout.marginLeft,
          pageTop + layout.marginTop,
          layout.a4Width - layout.marginLeft - layout.marginRight,
          contentHeightForThisPage,
        );

        canvas.clipRect(printableRect.inflate(30.0));
        canvas.translate(
          layout.marginLeft,
          pageTop + layout.marginTop - startLogicalY,
        );

        drawContent();
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
