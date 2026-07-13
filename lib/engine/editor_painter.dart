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
    // 🌟 YENİ: Çizim metodumuz artık "Bu sayfanın başlangıç ve bitiş sınırları ne?" diye soruyor.
    void drawContent(double logicalStart, double logicalEnd) {
      // 1. SEÇİM (SELECTION) ÇİZİMİ
      if (selectionBase != null && selectionBase != cursorIndex) {
        final start = math.min(selectionBase!, cursorIndex);
        final end = math.max(selectionBase!, cursorIndex);
        final boxes = textPainter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        final selectionPaint = Paint()
          ..color = MostromoTheme.accentColor.withValues(alpha: 0.3);

        List<ui.TextBox> validBoxes = [];
        for (final box in boxes) {
          // Kutunun merkez (orta) noktasını bul
          double boxCenter = box.top + (box.bottom - box.top) / 2;

          // Eğer kutunun merkezi bu sayfanın sınırları içindeyse çiz! (Hayalet kutuları engeller)
          if (!layout.isPageMode ||
              (boxCenter >= logicalStart && boxCenter <= logicalEnd)) {
            canvas.drawRect(box.toRect(), selectionPaint);
            validBoxes.add(box);
          }
        }

        if (isMobile && validBoxes.isNotEmpty) {
          final handlePaint = Paint()..color = MostromoTheme.accentColor;

          final firstBox = validBoxes.first;
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

          final lastBox = validBoxes.last;
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

      // 2. METNİN KENDİSİNİ ÇİZ
      textPainter.paint(canvas, Offset.zero);

      // 3. RESİMLERİ ÇİZ
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
            double boxCenter = rect.top + (rect.height / 2);

            if (!layout.isPageMode ||
                (boxCenter >= logicalStart && boxCenter <= logicalEnd)) {
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
          }
        });
      }

      // 4. İMLECİ (CURSOR) ÇİZ
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
          final leftBoxes = textPainter.getBoxesForSelection(
            TextSelection(baseOffset: leftIndex, extentOffset: leftIndex + 1),
          );
          if (leftBoxes.isNotEmpty &&
              (leftBoxes.last.top - cursorTop).abs() < 5.0) {
            validBox = leftBoxes.last.toRect();
          }
        }
        if (validBox == null && rightIndex < plainTextLength) {
          final rightBoxes = textPainter.getBoxesForSelection(
            TextSelection(baseOffset: rightIndex, extentOffset: rightIndex + 1),
          );
          if (rightBoxes.isNotEmpty &&
              (rightBoxes.first.top - cursorTop).abs() < 5.0) {
            validBox = rightBoxes.first.toRect();
          }
        }

        if (validBox != null) {
          cursorTop = validBox.top;
          cursorHeight = validBox.height;
        }

        // 🌟 İMLEÇ KORUMASI: İmlecin merkezi bu sayfada mı?
        double cursorCenter = cursorTop + (cursorHeight / 2);
        if (!layout.isPageMode ||
            (cursorCenter >= logicalStart && cursorCenter <= logicalEnd)) {
          canvas.drawLine(
            Offset(caretOffset.dx, cursorTop),
            Offset(caretOffset.dx, cursorTop + cursorHeight),
            cursorPaint,
          );
        }
      }
    }

    if (!layout.isPageMode) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = MostromoTheme.backgroundColor,
      );
      canvas.translate(32, 32);
      // Serbest modda sonsuz sınır veriyoruz
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

        // 🌟 KANAMA KORUMASI (Bleed Protection)
        // 5 piksel hayat kurtarır.
        // 1. Üstten 5 piksel kısaltıyoruz ki önceki sayfanın g, ş, y gibi sarkan kuyrukları gizlensin.
        // 2. Alttan 5 piksel uzatıyoruz ki bu sayfanın son satırındaki kuyruklar temizce çizilsin.
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

        // UI çizim fonksiyonuna bu sayfanın geçerli sınırlarını gönder
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
