import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import '../providers/editor_provider.dart';
import '../core/app_theme.dart';

// --- YENİ: SATIR DUYARLI SAYFALAMA MİMARİSİ (PAGE LAYOUT) ---
class PageLayout {
  final bool isPageMode;
  final double a4Width;
  final double a4Height;
  final double pageGap;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final List<double>
  pageBreaks; // Satırların sayfa değiştirdiği 'Mantıksal Y' noktaları
  final double logicalHeight; // Metnin toplam yüksekliği

  PageLayout({
    required this.isPageMode,
    required this.a4Width,
    required this.a4Height,
    required this.pageGap,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.pageBreaks,
    required this.logicalHeight,
  });

  int get totalPages => isPageMode ? pageBreaks.length : 1;

  double get physicalHeight {
    if (!isPageMode) return logicalHeight;
    return (totalPages * a4Height) + ((totalPages - 1) * pageGap);
  }

  // Fare tıklamasını, aradaki fiziksel boşlukları çıkartarak gerçek metin hizasına dönüştürür
  double physicalToLogicalY(double physicalY) {
    if (!isPageMode) return physicalY - 32.0;

    int pageIndex = (physicalY / (a4Height + pageGap)).floor();
    if (pageIndex < 0) pageIndex = 0;
    if (pageIndex >= pageBreaks.length) pageIndex = pageBreaks.length - 1;

    double localY = physicalY - (pageIndex * (a4Height + pageGap));
    double offsetInPrintable = localY - marginTop;

    double maxContentOnPage =
        ((pageIndex + 1 < pageBreaks.length)
            ? pageBreaks[pageIndex + 1]
            : logicalHeight) -
        pageBreaks[pageIndex];

    if (offsetInPrintable < 0) offsetInPrintable = 0;
    if (offsetInPrintable > maxContentOnPage)
      offsetInPrintable = maxContentOnPage;

    return pageBreaks[pageIndex] + offsetInPrintable;
  }
}

class MostromoEditorWidget extends StatefulWidget {
  final VoidCallback? onSave;
  final bool isActive; // YENİ: Dışarıdan (Bloktan) odağı kontrol etmek için

  const MostromoEditorWidget({super.key, this.onSave, this.isActive = true});

  @override
  State<MostromoEditorWidget> createState() => _MostromoEditorWidgetState();
}

class _MostromoEditorWidgetState extends State<MostromoEditorWidget> {
  late FocusNode _focusNode;
  double _currentMaxWidth = 1000.0;
  Timer? _cursorTimer;
  bool _showCursor = true;
  double? _intendedCursorX;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // YENİ: Sadece odaklandığında yanıp sönsün, aksi halde imleci gizlesin
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _startBlinking();
      } else {
        _cursorTimer?.cancel();
        if (mounted) setState(() => _showCursor = false);
      }
    });

    if (widget.isActive)
      _startBlinking();
    else
      _showCursor = false;
  }

  // YENİ: Dışarıdaki Blok seçildiğinde veya bırakıldığında motoru uyandır/uyut
  @override
  void didUpdateWidget(MostromoEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _focusNode.requestFocus();
      _startBlinking();
    } else if (!widget.isActive && oldWidget.isActive) {
      _focusNode.unfocus();
      _cursorTimer?.cancel();
      setState(() => _showCursor = false);
    }
  }

  void _startBlinking() {
    _cursorTimer?.cancel();
    setState(() => _showCursor = true);
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // YENİ: Sadece odak varsa yanıp sönmeye devam et
      if (mounted && _focusNode.hasFocus) {
        setState(() => _showCursor = !_showCursor);
      }
    });
  }

  Future<void> _pasteFromClipboard(EditorProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      provider.insertText(data.text!);
    }
  }

  void _handleKeyEvent(KeyEvent event, EditorProvider provider) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final logicalKey = event.logicalKey;
    final character = event.character;
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    _startBlinking();

    if (isCtrl) {
      if (logicalKey == LogicalKeyboardKey.keyS) {
        widget.onSave?.call();
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShift) {
          provider.executeRedo();
        } else {
          provider.executeUndo();
        }
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyY) {
        provider.executeRedo();
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyA) {
        provider.updateSelection(provider.engine.getText().length, 0);
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyC) {
        if (provider.hasSelection) {
          final start = math.min(provider.selectionBase!, provider.cursorIndex);
          final end = math.max(provider.selectionBase!, provider.cursorIndex);
          Clipboard.setData(
            ClipboardData(
              text: provider.engine.getText().substring(start, end),
            ),
          );
        }
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyX) {
        if (provider.hasSelection) {
          final start = math.min(provider.selectionBase!, provider.cursorIndex);
          final end = math.max(provider.selectionBase!, provider.cursorIndex);
          Clipboard.setData(
            ClipboardData(
              text: provider.engine.getText().substring(start, end),
            ),
          );
          provider.deleteSelection();
        }
        return;
      } else if (logicalKey == LogicalKeyboardKey.keyV) {
        _pasteFromClipboard(provider);
        return;
      }
    }

    if (logicalKey == LogicalKeyboardKey.arrowLeft ||
        logicalKey == LogicalKeyboardKey.arrowRight ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowDown) {
      int? newBase = isShift
          ? (provider.selectionBase ?? provider.cursorIndex)
          : null;
      int newCursor = provider.cursorIndex;

      if (logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (newCursor > 0) newCursor--;
        _intendedCursorX = null;
      } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
        if (newCursor < provider.engine.getText().length) newCursor++;
        _intendedCursorX = null;
      } else {
        newCursor = _calculateVerticalMove(
          provider,
          logicalKey == LogicalKeyboardKey.arrowUp,
        );
      }
      provider.updateSelection(newCursor, newBase);
      return;
    }

    _intendedCursorX = null;

    if (logicalKey == LogicalKeyboardKey.tab) {
      provider.insertText('    ');
      return;
    }
    if (logicalKey == LogicalKeyboardKey.backspace) {
      provider.deleteCharacter();
      return;
    }
    if (logicalKey == LogicalKeyboardKey.enter) {
      provider.insertText('\n');
      return;
    }
    if (character != null && character.isNotEmpty && !isCtrl) {
      provider.insertText(character);
    }
  }

  // --- ÇEKİRDEK (CORE) HESAPLAYICILAR ---
  TextPainter _buildPainter(EditorProvider provider, double maxWidth) {
    List<TextSpan> combinedSpans = List.from(
      provider.engine.getRichTextSpans(),
    );
    combinedSpans.add(
      TextSpan(
        text: '\u200B',
        style: TextStyle(fontSize: provider.currentFontSize ?? 16.0),
      ),
    );
    final textSpan = TextSpan(
      children: combinedSpans,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );

    // Motor metni dizerken kenarlıkları çıkartarak sadece "yazdırılabilir alana" sıkıştırır
    double printableWidth = provider.isPageMode
        ? maxWidth - provider.marginLeft - provider.marginRight
        : maxWidth - 64;
    if (printableWidth < 100) printableWidth = 100;

    return TextPainter(text: textSpan, textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: printableWidth);
  }

  PageLayout _computeLayout(
    TextPainter textPainter,
    EditorProvider provider,
    double maxWidth,
  ) {
    double a4Height = maxWidth * 1.4142;
    double pageGap = 32.0;

    if (!provider.isPageMode) {
      return PageLayout(
        isPageMode: false,
        a4Width: maxWidth,
        a4Height: 0,
        pageGap: 0,
        marginTop: 32,
        marginBottom: 32,
        marginLeft: 32,
        marginRight: 32,
        pageBreaks: [0.0],
        logicalHeight: textPainter.height + 64,
      );
    }

    double printableHeight =
        a4Height - provider.marginTop - provider.marginBottom;
    if (printableHeight < 100) printableHeight = 100; // Güvenlik sınırı

    List<double> breaks = [0.0];
    double currentSubHeight = 0.0;
    double accumulatedY = 0.0;

    // SATIR DUYARLI KESİM: Taşan satırlar tam ortadan kesilmez, alt sayfaya itilir
    final metrics = textPainter.computeLineMetrics();
    for (var m in metrics) {
      if (currentSubHeight + m.height > printableHeight &&
          currentSubHeight > 0) {
        breaks.add(accumulatedY);
        currentSubHeight = 0.0;
      }
      currentSubHeight += m.height;
      accumulatedY += m.height;
    }

    return PageLayout(
      isPageMode: true,
      a4Width: maxWidth,
      a4Height: a4Height,
      pageGap: pageGap,
      marginTop: provider.marginTop,
      marginBottom: provider.marginBottom,
      marginLeft: provider.marginLeft,
      marginRight: provider.marginRight,
      pageBreaks: breaks,
      logicalHeight: accumulatedY,
    );
  }

  int _calculateVerticalMove(EditorProvider provider, bool isUp) {
    int len = provider.engine.getText().length;
    final textPainter = _buildPainter(provider, _currentMaxWidth);

    final currentOffset = textPainter.getOffsetForCaret(
      TextPosition(
        offset: provider.cursorIndex,
        affinity: TextAffinity.downstream,
      ),
      Rect.zero,
    );

    _intendedCursorX ??= currentOffset.dx;

    final metrics = textPainter.computeLineMetrics();
    if (metrics.isEmpty) return isUp ? 0 : len;

    double accumulatedY = 0;
    int currentLineIdx = metrics.length - 1;
    List<double> lineCenters = [];

    for (int i = 0; i < metrics.length; i++) {
      double h = metrics[i].height;
      lineCenters.add(accumulatedY + (h / 2));
      if (currentLineIdx == metrics.length - 1 &&
          currentOffset.dy < accumulatedY + h - 1.0) {
        currentLineIdx = i;
      }
      accumulatedY += h;
    }

    int targetLine = isUp ? currentLineIdx - 1 : currentLineIdx + 1;
    if (targetLine < 0) return provider.cursorIndex;
    if (targetLine >= metrics.length) return provider.cursorIndex;

    double targetY = lineCenters[targetLine];
    final newPosition = textPainter.getPositionForOffset(
      Offset(_intendedCursorX!, targetY),
    );
    return newPosition.offset.clamp(0, len);
  }

  int _getOffsetIndex(Offset localPosition, EditorProvider provider) {
    final textPainter = _buildPainter(provider, _currentMaxWidth);
    final layout = _computeLayout(textPainter, provider, _currentMaxWidth);

    double logicalY = layout.physicalToLogicalY(localPosition.dy);
    double logicalX =
        localPosition.dx - (provider.isPageMode ? layout.marginLeft : 32.0);

    final position = textPainter.getPositionForOffset(
      Offset(logicalX, logicalY),
    );
    return position.offset.clamp(0, provider.engine.getText().length);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.isActive,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event, context.read<EditorProvider>());
        return KeyEventResult.handled;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _currentMaxWidth = provider.isPageMode ? 800.0 : constraints.maxWidth;

          final textPainter = _buildPainter(provider, _currentMaxWidth);
          final layout = _computeLayout(
            textPainter,
            provider,
            _currentMaxWidth,
          );

          double customPaintHeight = layout.physicalHeight;
          if (!provider.isPageMode &&
              customPaintHeight < constraints.maxHeight) {
            customPaintHeight = constraints.maxHeight;
          }

          return Theme(
            data: Theme.of(context).copyWith(
              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.24),
                ),
                thickness: WidgetStateProperty.all(8),
                radius: const Radius.circular(8),
                crossAxisMargin: 2,
              ),
            ),
            child: SingleChildScrollView(
              child: Container(
                width: constraints.maxWidth,
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                alignment: Alignment.topCenter,
                color: provider.isPageMode
                    ? const Color(0xFF050505)
                    : Colors.transparent,
                padding: provider.isPageMode
                    ? const EdgeInsets.symmetric(vertical: 32)
                    : EdgeInsets.zero,

                child: MouseRegion(
                  cursor: SystemMouseCursors.text,
                  child: GestureDetector(
                    onTapDown: (details) {
                      _focusNode.requestFocus();
                      _intendedCursorX = null;
                      context.read<EditorProvider>().updateSelection(
                        _getOffsetIndex(details.localPosition, provider),
                        null,
                      );
                      _startBlinking();
                    },
                    onPanStart: (details) {
                      _focusNode.requestFocus();
                      int idx = _getOffsetIndex(
                        details.localPosition,
                        provider,
                      );
                      context.read<EditorProvider>().updateSelection(idx, idx);
                    },
                    onPanUpdate: (details) {
                      int idx = _getOffsetIndex(
                        details.localPosition,
                        provider,
                      );
                      context.read<EditorProvider>().updateSelection(
                        idx,
                        provider.selectionBase,
                      );
                    },
                    child: CustomPaint(
                      size: Size(_currentMaxWidth, customPaintHeight),
                      painter: EditorPainter(
                        textPainter: textPainter,
                        layout: layout,
                        plainTextLength: provider.engine.getText().length,
                        cursorIndex: provider.cursorIndex,
                        selectionBase: provider.selectionBase,
                        showCursor: _showCursor,
                        currentFontSize: provider.currentFontSize ?? 16.0,
                        imageCache: provider.imageCache, // YENİ EKLENDİ
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditorPainter extends CustomPainter {
  final TextPainter textPainter;
  final PageLayout layout;
  final int plainTextLength;
  final int cursorIndex;
  final int? selectionBase;
  final bool showCursor;
  final double currentFontSize;
  final Map<int, ui.Image> imageCache; // YENİ EKLENDİ

  EditorPainter({
    required this.textPainter,
    required this.layout,
    required this.plainTextLength,
    required this.cursorIndex,
    required this.showCursor,
    this.selectionBase,
    required this.currentFontSize,
    required this.imageCache, // YENİ EKLENDİ
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
          canvas.drawRect(
            box.toRect(),
            selectionPaint,
          ); // Çeviri Canvas'ta yapıldığı için offset'e gerek yok
        }
      }

      textPainter.paint(canvas, Offset.zero);
      // --- SİHİR: RESİMLERİ (IMAGE CACHE) EKRANA ÇİZME ---
      // Metin çizildikten sonra, bellekteki resimlerin tam koordinatlarını bulup yerleştiririz
      if (imageCache.isNotEmpty) {
        final paint = Paint()
          ..filterQuality = FilterQuality.high; // Resmi pürüzsüz yapar

        imageCache.forEach((offsetIndex, uiImage) {
          // Resmin olduğu o gizli karakterin (\u200B) ekrandaki fiziksel kutusunu (Bounding Box) bul!
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(
              baseOffset: offsetIndex,
              extentOffset: offsetIndex + 1,
            ),
          );

          if (boxes.isNotEmpty) {
            final rect = boxes.first.toRect();
            // Resmi, metin motorunun onun için açtığı o boşluk kutusunun tam içine çiziyoruz
            canvas.drawImageRect(
              uiImage,
              Rect.fromLTWH(
                0,
                0,
                uiImage.width.toDouble(),
                uiImage.height.toDouble(),
              ), // Resmin kendi boyutu
              rect, // Ekranda çizileceği yer (Kutu)
              paint,
            );
          }
        });
      }
      if (showCursor) {
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
          if (boxes.isNotEmpty && (boxes.last.top - cursorTop).abs() < 5.0)
            validBox = boxes.last.toRect();
        }
        if (validBox == null && rightIndex < plainTextLength) {
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(baseOffset: rightIndex, extentOffset: rightIndex + 1),
          );
          if (boxes.isNotEmpty && (boxes.first.top - cursorTop).abs() < 5.0)
            validBox = boxes.first.toRect();
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

        // Kağıt, Gölge ve Sınır (A4 Boyutu Fiziksel Olarak Çizilir)
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

        // --- SİHİRLİ DOKUNUŞ BURADA ---
        // Pencerenin boyunu (Clip), kağıdın dibine kadar değil,
        // SADECE o sayfaya sığan satırların bittiği milimetrik noktaya kadar açıyoruz!
        double startLogicalY = layout.pageBreaks[i];
        double contentHeightForThisPage = (i + 1 < layout.pageBreaks.length)
            ? (layout.pageBreaks[i + 1] - startLogicalY)
            : (layout.logicalHeight - startLogicalY);

        Rect printableRect = Rect.fromLTWH(
          layout.marginLeft,
          pageTop + layout.marginTop,
          layout.a4Width - layout.marginLeft - layout.marginRight,
          contentHeightForThisPage, // Eskiden burası (a4Height - marginTop - marginBottom) idi
        );

        // Pencereyi tam satırın bittiği yerde kapat ki alt satırın kafası gözükmesin!
        canvas.clipRect(printableRect);

        // Metni yukarı doğru kaydır
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
