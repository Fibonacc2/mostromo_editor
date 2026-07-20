import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'piece_table.dart';

// --- 1. VERİ MODELLERİ ---

class WordItem {
  final String text;
  final TextStyle style;
  final double width;
  final double height;
  final int startIndex;
  final Color? backgroundColor; // 🌟 ARKA PLAN RENGİ

  WordItem({
    required this.text,
    required this.style,
    required this.width,
    required this.height,
    required this.startIndex,
    this.backgroundColor, // 🌟 YENİ
  });
}

class LogicalLine {
  final List<WordItem> words;
  final double width;
  final double height;
  final double dy;
  final int startOffset;
  final int length;
  final TextAlign textAlign;
  final double layoutWidth;

  // 🌟 YENİ: Çizim Motoru Cache'i
  final TextPainter textPainter;

  // 🌟 YENİ: Tüm satırın arka plan rengi (tek renkse)
  final Color? backgroundColor;

  LogicalLine({
    required this.words,
    required this.width,
    required this.height,
    required this.dy,
    required this.startOffset,
    required this.length,
    required this.textAlign,
    required this.layoutWidth,
    required this.textPainter,
    this.backgroundColor, // 🌟 YENİ
  });
}

// --- 2. ÖLÇÜM MOTORU (MEASURER) ---

class CustomTextMeasurer {
  final Map<String, Size> _measurementCache = {};

  Size measure(String text, TextStyle style) {
    if (text.isEmpty) return const Size(0, 0);

    final TextStyle appliedStyle;
    if (style.height == null) {
      appliedStyle = style.copyWith(height: 1.2);
    } else {
      appliedStyle = style;
    }

    final String cacheKey =
        '${text}_${appliedStyle.fontSize}_${appliedStyle.fontWeight}_${appliedStyle.fontFamily}_${appliedStyle.height}_${appliedStyle.backgroundColor?.toARGB32()}';

    if (_measurementCache.containsKey(cacheKey)) {
      return _measurementCache[cacheKey]!;
    }

    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: appliedStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final Size size = Size(painter.width, painter.height);
    _measurementCache[cacheKey] = size;

    return size;
  }

  void clearCache() {
    _measurementCache.clear();
  }
}

// --- 3. SATIR KIRICI ALGORİTMA (LINE BREAKER) ---

class LineBreaker {
  final CustomTextMeasurer measurer;

  LineBreaker(this.measurer);

  // 🌟 YENİ: Tek seferlik TextPainter Üreticisi
  TextPainter _createLinePainter(
    List<WordItem> lineWords,
    TextAlign align,
    double width,
  ) {
    List<TextSpan> spans = [];
    for (var w in lineWords) {
      spans.add(TextSpan(text: w.text, style: w.style));
    }
    final painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    painter.layout(minWidth: width, maxWidth: width);
    return painter;
  }

  /// Bir satırdaki tüm kelimelerin arka plan rengini kontrol eder.
  /// Eğer tüm kelimeler aynı renge sahipse o rengi döndürür, değilse null döndürür.
  Color? _determineLineBackgroundColor(List<WordItem> words) {
    if (words.isEmpty) return null;

    Color? firstBg = words.first.backgroundColor;
    bool allSame = true;

    for (var word in words) {
      if (word.backgroundColor != firstBg) {
        allSame = false;
        break;
      }
    }

    return allSame ? firstBg : null;
  }

  List<LogicalLine> breakIntoLines({
    required List<TextSpan> spans,
    required double maxWidth,
    required int paragraphStartOffset,
    required TextAlign textAlign,
  }) {
    List<LogicalLine> lines = [];
    List<WordItem> currentLineWords = [];

    double currentLineWidth = 0.0;
    double currentLineHeight = 0.0;
    int currentLength = 0;
    int wordStartOffset = paragraphStartOffset;

    if (spans.isEmpty ||
        (spans.length == 1 && (spans.first.text ?? '').isEmpty)) {
      TextStyle defaultStyle = const TextStyle(
        fontSize: 16,
        color: Colors.white,
        height: 1.2,
      );
      if (spans.isNotEmpty && spans.first.style != null) {
        defaultStyle = spans.first.style!.copyWith(height: 1.2);
      }
      final Size size = measurer.measure(' ', defaultStyle);
      final emptyPainter = _createLinePainter([], textAlign, maxWidth);

      lines.add(
        LogicalLine(
          words: [],
          width: 0.0,
          height: size.height,
          dy: 0.0,
          startOffset: paragraphStartOffset,
          length: 0,
          textAlign: textAlign,
          layoutWidth: maxWidth,
          textPainter: emptyPainter,
          backgroundColor: null,
        ),
      );
      return lines;
    }

    for (var span in spans) {
      final String spanText = span.text ?? '';
      if (spanText.isEmpty) continue;

      final TextStyle spanStyle;
      if (span.style == null) {
        spanStyle = const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ).copyWith(height: 1.2);
      } else {
        spanStyle = span.style!.copyWith(height: 1.2);
      }

      final matches = RegExp(r'(\s+|\S+)').allMatches(spanText);

      for (final match in matches) {
        final String chunk = match.group(0)!;
        final Size size = measurer.measure(chunk, spanStyle);

        if (currentLineWidth + size.width > maxWidth &&
            currentLineWords.isNotEmpty) {
          final painter = _createLinePainter(
            currentLineWords,
            textAlign,
            maxWidth,
          );

          lines.add(
            LogicalLine(
              words: List.from(currentLineWords),
              width: currentLineWidth,
              height: currentLineHeight,
              dy: 0.0,
              startOffset: currentLineWords.first.startIndex,
              length: currentLength,
              textAlign: textAlign,
              layoutWidth: maxWidth,
              textPainter: painter,
              backgroundColor: _determineLineBackgroundColor(currentLineWords),
            ),
          );

          currentLineWords.clear();
          currentLineWidth = 0.0;
          currentLineHeight = 0.0;
          currentLength = 0;
        }

        currentLineWords.add(
          WordItem(
            text: chunk,
            style: spanStyle,
            width: size.width,
            height: size.height,
            startIndex: wordStartOffset,
            backgroundColor: spanStyle.backgroundColor, // 🌟 YENİ
          ),
        );

        currentLineWidth += size.width;
        currentLineHeight = math.max(currentLineHeight, size.height);
        currentLength += chunk.length;
        wordStartOffset += chunk.length;
      }
    }

    if (currentLineWords.isNotEmpty) {
      final painter = _createLinePainter(currentLineWords, textAlign, maxWidth);

      lines.add(
        LogicalLine(
          words: List.from(currentLineWords),
          width: currentLineWidth,
          height: currentLineHeight,
          dy: 0.0,
          startOffset: currentLineWords.first.startIndex,
          length: currentLength,
          textAlign: textAlign,
          layoutWidth: maxWidth,
          textPainter: painter,
          backgroundColor: _determineLineBackgroundColor(currentLineWords),
        ),
      );
    }

    return lines;
  }
}

// --- 4. SAYFA DİZGİCİSİ (DOCUMENT LAYOUTER) ---

class DocumentLayoutResult {
  final List<LogicalLine> lines;
  final double totalPhysicalHeight; // 🌟 YENİ: Tam sayfa uzunluğu
  final int totalPages; // 🌟 YENİ: Toplam sayfa sayısı

  DocumentLayoutResult({
    required this.lines,
    required this.totalPhysicalHeight,
    required this.totalPages,
  });
}

class DocumentLayouter {
  final LineBreaker breaker;
  final Map<String, List<LogicalLine>> _blockCache = {};

  DocumentLayouter(this.breaker);

  DocumentLayoutResult layout({
    required String fullText,
    required List<ParagraphBlock> blocks,
    required double printableWidth,
    required double printableHeight,
    required bool isPageMode,
    double a4Height = 0.0,
    double marginTop = 0.0,
    double pageGap = 0.0,
  }) {
    List<LogicalLine> allLines = [];
    int currentPage = 0;
    double currentSubY = 0.0;
    double currentContinuousY = 32.0; // Sayfa modu kapalıysa üstten 32px boşluk
    Map<String, List<LogicalLine>> newCache = {};

    for (var block in blocks) {
      StringBuffer sigBuilder = StringBuffer(
        '${block.textAlign.index}_${printableWidth}_',
      );
      for (var span in block.spans) {
        sigBuilder.write(
          '${span.text}_${span.style?.fontWeight}_${span.style?.fontSize}_${span.style?.fontStyle}_${span.style?.decoration}_${span.style?.color?.toARGB32()}_${span.style?.backgroundColor?.toARGB32()}_',
        );
      }
      String signature = sigBuilder.toString();
      List<LogicalLine> templateLines;

      if (_blockCache.containsKey(signature)) {
        templateLines = _blockCache[signature]!;
      } else {
        templateLines = breaker.breakIntoLines(
          spans: block.spans,
          maxWidth: printableWidth,
          paragraphStartOffset: 0,
          textAlign: block.textAlign,
        );
      }
      newCache[signature] = templateLines;

      for (var template in templateLines) {
        double finalDy = 0.0;

        // Mutlak (Absolute) Y Koordinatı Ataması
        if (isPageMode) {
          // Sayfa sınırını aştıysak yeni sayfaya zıpla
          if (currentSubY + template.height > printableHeight &&
              currentSubY > 0) {
            currentPage++;
            currentSubY = 0.0;
          }

          double pageTop = currentPage * (a4Height + pageGap);
          // Satırın fiziksel konumu = Sayfa Başı + Üst Kenar Boşluğu + Sayfa İçi Konumu
          finalDy = pageTop + marginTop + currentSubY;
          currentSubY += template.height;
        } else {
          finalDy = currentContinuousY;
          currentContinuousY += template.height;
        }

        LogicalLine positionedLine = LogicalLine(
          words: template.words,
          width: template.width,
          height: template.height,
          dy: finalDy,
          startOffset: block.startOffset + template.startOffset,
          length: template.length,
          textAlign: template.textAlign,
          layoutWidth: template.layoutWidth,
          textPainter: template.textPainter,
          backgroundColor: template.backgroundColor,
        );

        allLines.add(positionedLine);
      }
    }

    _blockCache.clear();
    _blockCache.addAll(newCache);

    double totalHeight = isPageMode
        ? ((currentPage + 1) * (a4Height + pageGap))
        : currentContinuousY + 32.0;

    return DocumentLayoutResult(
      lines: allLines,
      totalPhysicalHeight: totalHeight,
      totalPages: isPageMode ? (currentPage + 1) : 1,
    );
  }
}
