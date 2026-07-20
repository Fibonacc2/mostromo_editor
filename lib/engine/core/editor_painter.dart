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
  final ScrollController scrollController;
  final bool showPageNumbers;
  final Alignment pageNumberAlignment;

  final List<int> searchMatches;
  final String currentSearchQuery;

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
    required this.scrollController,
    required this.showPageNumbers,
    required this.pageNumberAlignment,
    required this.searchMatches,
    required this.currentSearchQuery,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    double viewportTop = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    double viewportBottom = viewportTop + size.height;
    double cullStart = viewportTop - 500.0;
    double cullEnd = viewportBottom + 500.0;

    // --- 1. AŞAMA: ZEMİN VE SAYFA ÇİZİMİ (ARKA PLAN) ---
    if (layout.isPageMode) {
      for (int i = 0; i < layout.totalPages; i++) {
        double pageTop = i.toDouble() * (layout.a4Height + layout.pageGap);
        double pageBottom = pageTop + layout.a4Height;

        if (pageBottom < cullStart || pageTop > cullEnd) continue;

        Rect pageRect = Rect.fromLTWH(
          0.0,
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
            ..strokeWidth = 1.0,
        );

        // 🌟 SAYFA NUMARALARI ÇİZİMİ
        if (showPageNumbers) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: "${i + 1}",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          double px = 0.0;
          double py = 0.0;

          if (pageNumberAlignment.x == -1.0) {
            px = layout.marginLeft;
          } else if (pageNumberAlignment.x == 0.0) {
            px =
                (layout.a4Width - textPainter.width) /
                2.0; // 🌟 Type-cast hatası için .0 eklendi
          } else if (pageNumberAlignment.x == 1.0) {
            px = layout.a4Width - layout.marginRight - textPainter.width;
          }

          if (pageNumberAlignment.y == -1.0) {
            py =
                pageTop +
                ((layout.marginTop - textPainter.height) / 2.0); // Üst Boşluk
          } else {
            py =
                pageTop +
                layout.a4Height -
                ((layout.marginBottom + textPainter.height) /
                    2.0); // Alt Boşluk
          }

          textPainter.paint(canvas, Offset(px, py));
        }
      }
    } else {
      canvas.drawRect(
        Offset.zero & Size(size.width, layout.physicalHeight),
        Paint()..color = MostromoTheme.backgroundColor,
      );
    }

    // --- 2. AŞAMA: SATIRLARIN (İÇERİĞİN) ÇİZİMİ ---
    double dxOffset = layout.isPageMode ? layout.marginLeft : 32.0;

    // 🌟 'i' eksikliği hatası için döngü 'for (int i=0;...)' formatına çevrildi
    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      if (line.dy + line.height < cullStart || line.dy > cullEnd) continue;

      canvas.save();
      canvas.translate(dxOffset, line.dy);

      final linePainter = line.textPainter;

      // SEÇİM ÇİZİMİ
      if (selectionBase != null && selectionBase != cursorIndex) {
        int start = math.min(selectionBase!, cursorIndex);
        int end = math.max(selectionBase!, cursorIndex);

        if (end >= line.startOffset &&
            start <= line.startOffset + line.length + 1) {
          int localStart = math.max(0, start - line.startOffset);
          int localEnd = math.min(line.length, end - line.startOffset);

          final boxes = linePainter.getBoxesForSelection(
            TextSelection(baseOffset: localStart, extentOffset: localEnd),
          );
          final selectionPaint = Paint()
            ..color = MostromoTheme.accentColor.withValues(alpha: 0.3);

          for (final box in boxes)
            canvas.drawRect(box.toRect(), selectionPaint);

          if (end > line.startOffset + line.length) {
            double trailingX = boxes.isNotEmpty ? boxes.last.right : 0.0;
            if (line.length == 0) trailingX = 0.0;
            canvas.drawRect(
              Rect.fromLTRB(trailingX, 0.0, trailingX + 8.0, line.height),
              selectionPaint,
            );
          }
        }
      }

      // 🌟 YENİ: ARAMA EŞLEŞMELERİNİ VURGULA (FIND HIGHLIGHT)
      if (searchMatches.isNotEmpty && currentSearchQuery.isNotEmpty) {
        for (int matchStart in searchMatches) {
          int matchEnd = matchStart + currentSearchQuery.length;

          if (matchEnd >= line.startOffset &&
              matchStart <= line.startOffset + line.length) {
            int localStart = math.max(0, matchStart - line.startOffset);
            int localEnd = math.min(line.length, matchEnd - line.startOffset);

            final boxes = linePainter.getBoxesForSelection(
              TextSelection(baseOffset: localStart, extentOffset: localEnd),
            );

            // Aktif seçilen eşleşme mi yoksa diğerleri mi? (İsteğe bağlı turuncu/sarı ayrımı yapılabilir)
            final searchHighlightPaint = Paint()
              ..color = Colors.amber.withValues(alpha: 0.4);

            for (final box in boxes) {
              canvas.drawRect(box.toRect(), searchHighlightPaint);
            }
          }
        }
      }
      // METİN ÇİZİMİ
      linePainter.paint(canvas, Offset.zero);

      // İMLEÇ ÇİZİMİ
      if (showCursor &&
          (selectionBase == null || selectionBase == cursorIndex)) {
        int nextLineStart = (i + 1 < lines.length)
            ? lines[i + 1].startOffset
            : plainTextLength + 1;

        if (cursorIndex >= line.startOffset && cursorIndex < nextLineStart) {
          int localCursor = cursorIndex - line.startOffset;
          if (localCursor > line.length) localCursor = line.length;

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

          canvas.drawLine(
            Offset(caretOffset.dx, 0.0),
            Offset(caretOffset.dx, cursorHeight),
            cursorPaint,
          );
        }
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.plainTextLength != plainTextLength ||
        oldDelegate.cursorIndex != cursorIndex ||
        oldDelegate.selectionBase != selectionBase ||
        oldDelegate.showCursor != showCursor ||
        oldDelegate.layout != layout ||
        oldDelegate.showPageNumbers != showPageNumbers ||
        oldDelegate.pageNumberAlignment != pageNumberAlignment ||
        oldDelegate.currentFontSize != currentFontSize;
  }
}
