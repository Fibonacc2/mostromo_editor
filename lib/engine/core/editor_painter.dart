import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../core/app_theme.dart';
import 'page_layout.dart';

// 🌟 YENİ: Paragrafların ekrandaki konumlarını tutan iletişim sınıfı
class PaintedParagraph {
  final TextPainter painter;
  final int startOffset;
  final int length;
  final double dy;
  final double height;

  PaintedParagraph({
    required this.painter,
    required this.startOffset,
    required this.length,
    required this.dy,
    required this.height,
  });
}

class EditorPainter extends CustomPainter {
  final List<PaintedParagraph>
  paragraphs; // 🌟 YENİ: Tek TextPainter yerine Paragraf Listesi
  final PageLayout layout;
  final int plainTextLength;
  final int cursorIndex;
  final int? selectionBase;
  final bool showCursor;
  final double currentFontSize;
  final Map<int, ui.Image> imageCache;
  final bool isMobile;

  EditorPainter({
    required this.paragraphs,
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
      for (var p in paragraphs) {
        // Bu paragraf şu an çizilen sayfa sınırlarının tamamen dışındaysa es geç (Optimizasyon)
        if (layout.isPageMode &&
            (p.dy + p.height < logicalStart || p.dy > logicalEnd)) {
          continue;
        }

        canvas.save();
        canvas.translate(0, p.dy); // Kalemi paragrafın Y konumuna kaydır

        // 1. SEÇİM (SELECTION) ÇİZİMİ
        if (selectionBase != null && selectionBase != cursorIndex) {
          int start = math.min(selectionBase!, cursorIndex);
          int end = math.max(selectionBase!, cursorIndex);

          // Seçim bu paragrafın içine taşıyor mu?
          if (end >= p.startOffset && start <= p.startOffset + p.length) {
            int localStart = math.max(0, start - p.startOffset);
            int localEnd = math.min(p.length, end - p.startOffset);

            final boxes = p.painter.getBoxesForSelection(
              TextSelection(baseOffset: localStart, extentOffset: localEnd),
            );
            final selectionPaint = Paint()
              ..color = MostromoTheme.accentColor.withValues(alpha: 0.3);

            for (final box in boxes) {
              canvas.drawRect(box.toRect(), selectionPaint);
            }
          }
        }

        // 2. PARAGRAFIN KENDİSİNİ ÇİZ (Sola, sağa veya ortaya yaslı olarak)
        p.painter.paint(canvas, Offset.zero);

        // 3. RESİMLERİ ÇİZ
        if (imageCache.isNotEmpty) {
          final paint = Paint()..filterQuality = FilterQuality.high;
          imageCache.forEach((offsetIndex, uiImage) {
            if (offsetIndex >= p.startOffset &&
                offsetIndex < p.startOffset + p.length) {
              int localOffset = offsetIndex - p.startOffset;
              final boxes = p.painter.getBoxesForSelection(
                TextSelection(
                  baseOffset: localOffset,
                  extentOffset: localOffset + 1,
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
            }
          });
        }

        // 4. İMLECİ (CURSOR) ÇİZ
        if (showCursor &&
            (selectionBase == null || selectionBase == cursorIndex)) {
          if (cursorIndex >= p.startOffset &&
              cursorIndex <= p.startOffset + p.length) {
            // Sadece imlecin tam olarak bulunduğu paragrafta çiz.
            // '\n' sınırlarında imlecin çift çizilmesini önlemek için:
            if (cursorIndex == p.startOffset + p.length &&
                p.length > 0 &&
                p != paragraphs.last) {
              // Eğer paragrafın en sonundaysa ve son paragraf değilse (enter atılmışsa), imleci bir sonraki boş paragrafta çizdir.
              canvas.restore();
              continue;
            }

            int localCursor = cursorIndex - p.startOffset;
            final caretOffset = p.painter.getOffsetForCaret(
              TextPosition(
                offset: localCursor,
                affinity: TextAffinity.downstream,
              ),
              Rect.zero,
            );

            final cursorPaint = Paint()
              ..color = MostromoTheme.accentColor
              ..strokeWidth = 2.0;
            double cursorHeight = currentFontSize * 1.15;
            double cursorTop = caretOffset.dy;

            // İmleç yüksekliği düzeltmesi
            final boxes = p.painter.getBoxesForSelection(
              TextSelection(
                baseOffset: math.max(0, localCursor - 1),
                extentOffset: localCursor,
              ),
            );
            if (boxes.isNotEmpty) {
              cursorTop = boxes.last.top;
              cursorHeight = boxes.last.toRect().height;
            }

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
