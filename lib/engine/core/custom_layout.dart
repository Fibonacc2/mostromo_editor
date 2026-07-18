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

  WordItem({
    required this.text,
    required this.style,
    required this.width,
    required this.height,
    required this.startIndex,
  });
}

class LogicalLine {
  final List<WordItem> words;
  final double width;
  final double height;
  final double dy;
  final int startOffset;
  final int length;

  LogicalLine({
    required this.words,
    required this.width,
    required this.height,
    required this.dy,
    required this.startOffset,
    required this.length,
  });
}

// --- 2. ÖLÇÜM MOTORU (MEASURER) ---

class CustomTextMeasurer {
  final Map<String, Size> _measurementCache = {};

  Size measure(String text, TextStyle style) {
    if (text.isEmpty) return const Size(0, 0);

    // Satırlar arası mesafeyi daraltmak için yükseklik çarpanını 1.2'ye sabitleme
    final TextStyle appliedStyle = style.height == null
        ? style.copyWith(height: 1.2)
        : style;

    final String cacheKey =
        '${text}_${appliedStyle.fontSize}_${appliedStyle.fontWeight}_${appliedStyle.fontFamily}_${appliedStyle.height}';

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

  // 🌟 GÜNCELLEME: Artık tek bir TextStyle yerine paragrafa ait tüm Zengin Metin Span'lerini alıyor
  List<LogicalLine> breakIntoLines({
    required List<TextSpan> spans,
    required double maxWidth,
    required int paragraphStartOffset,
  }) {
    List<LogicalLine> lines = [];
    List<WordItem> currentLineWords = [];

    double currentLineWidth = 0.0;
    double currentLineHeight = 0.0;
    int currentLength = 0;
    int wordStartOffset = paragraphStartOffset;

    // Eğer paragraf tamamen boşsa (Boş Enter satırı)
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
      lines.add(
        LogicalLine(
          words: [],
          width: 0.0,
          height: size.height,
          dy: 0.0,
          startOffset: paragraphStartOffset,
          length: 0,
        ),
      );
      return lines;
    }

    // Paragrafın içindeki tüm zengin metin parçalarını tek tek dön
    for (var span in spans) {
      final String spanText = span.text ?? '';
      if (spanText.isEmpty) continue;

      // Her parçanın kendi özgün stilini koru ve satır aralığını sıkıştır (height: 1.2)
      final TextStyle spanStyle =
          (span.style ?? const TextStyle(fontSize: 16, color: Colors.white))
              .copyWith(height: 1.2);

      final matches = RegExp(r'(\s+|\S+)').allMatches(spanText);

      for (final match in matches) {
        final String chunk = match.group(0)!;
        final Size size = measurer.measure(chunk, spanStyle);

        if (currentLineWidth + size.width > maxWidth &&
            currentLineWords.isNotEmpty) {
          lines.add(
            LogicalLine(
              words: List.from(currentLineWords),
              width: currentLineWidth,
              height: currentLineHeight,
              dy: 0.0,
              startOffset: currentLineWords.first.startIndex,
              length: currentLength,
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
          ),
        );

        currentLineWidth += size.width;
        currentLineHeight = math.max(currentLineHeight, size.height);
        currentLength += chunk.length;
        wordStartOffset += chunk.length;
      }
    }

    if (currentLineWords.isNotEmpty) {
      lines.add(
        LogicalLine(
          words: List.from(currentLineWords),
          width: currentLineWidth,
          height: currentLineHeight,
          dy: 0.0,
          startOffset: currentLineWords.first.startIndex,
          length: currentLength,
        ),
      );
    }

    return lines;
  }
}

// --- 4. SAYFA DİZGİCİSİ (DOCUMENT LAYOUTER) ---

class DocumentLayoutResult {
  final List<LogicalLine> lines;
  final double totalLogicalHeight;
  final List<double> pageBreaks;

  DocumentLayoutResult({
    required this.lines,
    required this.totalLogicalHeight,
    required this.pageBreaks,
  });
}

class DocumentLayouter {
  final LineBreaker breaker;

  DocumentLayouter(this.breaker);

  DocumentLayoutResult layout({
    required String fullText,
    required List<ParagraphBlock> blocks,
    required double printableWidth,
    required double printableHeight,
    required bool isPageMode,
  }) {
    List<LogicalLine> allLines = [];
    double currentY = 0.0;
    List<double> breaks = [0.0];
    double currentSubHeight = 0.0;

    for (var block in blocks) {
      // 🌟 DÜZELTME: Tüm zengin metin span'lerini doğrudan kırıcıya gönderiyoruz, sızıntı engellendi!
      List<LogicalLine> pLines = breaker.breakIntoLines(
        spans: block.spans,
        maxWidth: printableWidth,
        paragraphStartOffset: block.startOffset,
      );

      for (var line in pLines) {
        if (isPageMode &&
            currentSubHeight + line.height > printableHeight &&
            currentSubHeight > 0) {
          breaks.add(currentY);
          currentSubHeight = 0.0;
        }

        LogicalLine positionedLine = LogicalLine(
          words: line.words,
          width: line.width,
          height: line.height,
          dy: currentY,
          startOffset: line.startOffset,
          length: line.length,
        );

        allLines.add(positionedLine);
        currentY += line.height;
        currentSubHeight += line.height;
      }
    }

    return DocumentLayoutResult(
      lines: allLines,
      totalLogicalHeight: currentY,
      pageBreaks: breaks,
    );
  }
}
