import 'dart:math' as math;

import 'piece_table.dart';

import 'package:flutter/material.dart';

// --- 1. VERİ MODELLERİ ---

/// Tek bir kelimeyi, boşluğu veya heceyi temsil eden yapı taşı.
class WordItem {
  final String text;
  final TextStyle style;
  final double width;
  final double height;
  final int startIndex; // Kelimenin paragraftaki başlangıç indeksi

  WordItem({
    required this.text,
    required this.style,
    required this.width,
    required this.height,
    required this.startIndex,
  });
}

/// Kelimelerin yan yana gelmesiyle oluşan, ekrana çizilecek tek bir satır.
class LogicalLine {
  final List<WordItem> words;
  final double width; // Satırın toplam genişliği
  final double height; // Satırdaki en yüksek kelimenin yüksekliği
  final double dy; // Sayfa üzerindeki Y koordinatı
  final int startOffset; // Satırın genel metindeki başlangıç indeksi
  final int length; // Satırdaki toplam karakter sayısı

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

/// Kelimelerin ekranda kaç piksel kapladığını hesaplayan motor.
class CustomTextMeasurer {
  // Önbellek: Aynı kelimeyi ve stili defalarca ölçmemek için.
  // Anahtar: "Kelimemiz_FontSize_FontWeight_vb"
  final Map<String, Size> _measurementCache = {};

  /// Belirli bir metnin boyutlarını hesaplar.
  Size measure(String text, TextStyle style) {
    if (text.isEmpty) return const Size(0, 0);

    // Cache anahtarı oluştur (Performans için kilit nokta)
    final String cacheKey =
        '${text}_${style.fontSize}_${style.fontWeight}_${style.fontFamily}';

    if (_measurementCache.containsKey(cacheKey)) {
      return _measurementCache[cacheKey]!;
    }

    // Eğer cache'de yoksa, TextPainter ile arka planda hızlıca ölç
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final Size size = Size(painter.width, painter.height);

    // Hafızaya kaydet
    _measurementCache[cacheKey] = size;

    return size;
  }

  /// Cache'i temizlemek için (örneğin devasa bir doküman kapatıldığında)
  void clearCache() {
    _measurementCache.clear();
  }
}

/// Bir paragrafı alır, kelimeleri ölçer ve sayfa genişliğine göre satırlara (LogicalLine) böler.
class LineBreaker {
  final CustomTextMeasurer measurer;

  LineBreaker(this.measurer);

  List<LogicalLine> breakIntoLines({
    required String paragraphText,
    required TextStyle style,
    required double maxWidth,
    required int paragraphStartOffset,
  }) {
    List<LogicalLine> lines = [];
    List<WordItem> currentLineWords = [];

    double currentLineWidth = 0.0;
    double currentLineHeight = 0.0;
    int currentLength = 0;
    int wordStartOffset = paragraphStartOffset;

    // 🌟 KİLİT NOKTA: Regex ile metni "Kelime grupları" ve "Boşluk grupları" olarak ikiye ayırıyoruz.
    // Böylece "Merhaba    Dünya" gibi çoklu boşluklar kaybolmaz ve hepsi ölçülür.
    final matches = RegExp(r'(\s+|\S+)').allMatches(paragraphText);

    for (final match in matches) {
      final String chunk = match.group(0)!;
      final Size size = measurer.measure(chunk, style);

      // EĞER: Bu kelimeyi eklersek sayfa sınırını aşıyorsak VE satırda zaten kelime varsa
      // (Satırda hiç kelime yoksa ve ilk kelime sayfadan uzunsa, onu zorla eklemek zorundayız)
      if (currentLineWidth + size.width > maxWidth &&
          currentLineWords.isNotEmpty) {
        // 1. Mevcut satırı paketle ve listeye ekle
        lines.add(
          LogicalLine(
            words: List.from(currentLineWords),
            width: currentLineWidth,
            height: currentLineHeight == 0
                ? (style.fontSize ?? 16.0) * 1.15
                : currentLineHeight,
            dy: 0.0, // dy değerini (Y koordinatı) tüm belgeyi dizerken belirleyeceğiz
            startOffset: currentLineWords.first.startIndex,
            length: currentLength,
          ),
        );

        // 2. Yeni satır için değerleri sıfırla
        currentLineWords.clear();
        currentLineWidth = 0.0;
        currentLineHeight = 0.0;
        currentLength = 0;
      }

      // Kelimeyi veya boşluğu mevcut satıra ekle
      currentLineWords.add(
        WordItem(
          text: chunk,
          style: style,
          width: size.width,
          height: size.height,
          startIndex: wordStartOffset,
        ),
      );

      // Satır değerlerini güncelle
      currentLineWidth += size.width;
      currentLineHeight = math.max(currentLineHeight, size.height);
      currentLength += chunk.length;
      wordStartOffset += chunk.length;
    }

    // Paragraf bittiğinde, son satırda kalan kelimeler varsa onları da ekle
    if (currentLineWords.isNotEmpty) {
      lines.add(
        LogicalLine(
          words: List.from(currentLineWords),
          width: currentLineWidth,
          height: currentLineHeight == 0
              ? (style.fontSize ?? 16.0) * 1.15
              : currentLineHeight,
          dy: 0.0,
          startOffset: currentLineWords.first.startIndex,
          length: currentLength,
        ),
      );
    }

    // Paragraf tamamen boşsa (Enter'a basılmış boş bir satır), yükseklik için hayalet satır ekle
    if (lines.isEmpty) {
      lines.add(
        LogicalLine(
          words: [],
          width: 0.0,
          height: (style.fontSize ?? 16.0) * 1.15, // Varsayılan font yüksekliği
          dy: 0.0,
          startOffset: paragraphStartOffset,
          length: 0,
        ),
      );
    }

    return lines;
  }
}

/// Dizgi işleminin sonucunu tutan rapor sınıfı
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

/// Paragrafları satırlara bölüp 2D uzayda Y koordinatlarına (dy) yerleştiren motor.
class DocumentLayouter {
  final LineBreaker breaker;

  DocumentLayouter(this.breaker);

  DocumentLayoutResult layout({
    required String fullText,
    required List<ParagraphBlock> blocks,
    required double printableWidth,
    required double
    printableHeight, // Sayfa modu için (A4 yüksekliği - marjinler)
    required bool isPageMode,
  }) {
    List<LogicalLine> allLines = [];
    double currentY = 0.0;
    List<double> breaks = [0.0];
    double currentSubHeight = 0.0;

    for (var block in blocks) {
      // Bloğun (paragrafın) metnini al
      String pText = fullText.substring(
        block.startOffset,
        block.startOffset + block.length,
      );

      // Stili belirle (Şimdilik bloğun ilk span'inin stilini baz alıyoruz)
      TextStyle style = const TextStyle(fontSize: 16, color: Colors.white);
      if (block.spans.isNotEmpty && block.spans.first.style != null) {
        style = block.spans.first.style!;
      }

      // Satır kırıcıyı çağır ve paragrafı serbest satırlara böl
      List<LogicalLine> pLines = breaker.breakIntoLines(
        paragraphText: pText,
        style: style,
        maxWidth: printableWidth,
        paragraphStartOffset: block.startOffset,
      );

      // Elde edilen satırlara Y koordinatı (dy) ata ve evrene yerleştir
      for (var line in pLines) {
        // Sayfa modu açıksa ve bu satır sayfaya sığmıyorsa yeni sayfaya geç (Page Break)
        if (isPageMode &&
            currentSubHeight + line.height > printableHeight &&
            currentSubHeight > 0) {
          breaks.add(currentY);
          currentSubHeight = 0.0;
        }

        // Satırı yeni dy (Y ekseni) değeriyle kopyala ve mühürle
        LogicalLine positionedLine = LogicalLine(
          words: line.words,
          width: line.width,
          height: line.height,
          dy: currentY, // 🌟 İŞTE BURASI: Satırın dünyadaki gerçek Y konumu
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
