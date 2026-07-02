import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/editor_provider.dart';
import '../core/app_theme.dart';

class PageLayout {
  final bool isPageMode;
  final double a4Width;
  final double a4Height;
  final double pageGap;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final List<double> pageBreaks;
  final double logicalHeight;

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
    if (offsetInPrintable > maxContentOnPage) {
      offsetInPrintable = maxContentOnPage;
    }

    return pageBreaks[pageIndex] + offsetInPrintable;
  }
}

class MostromoEditorWidget extends StatefulWidget {
  final VoidCallback? onSave;
  final bool isActive;

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

  final TextEditingController _imeController = TextEditingController(text: ' ');
  bool _isImeUpdating = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (!mounted) return KeyEventResult.ignored;
        bool handled = _handleKeyEvent(event, context.read<EditorProvider>());
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _startBlinking();
      } else {
        _cursorTimer?.cancel();
        if (mounted) setState(() => _showCursor = false);
      }
    });

    if (widget.isActive) _startBlinking();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _cursorTimer?.cancel();
    _imeController.dispose();
    super.dispose();
  }

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
      if (mounted && _focusNode.hasFocus) {
        setState(() => _showCursor = !_showCursor);
      }
    });
  }

  // 🌟 YENİ: İKONLU VE GELİŞMİŞ YÜZEN MENÜ (CONTEXT MENU)
  void _showContextMenu(
    BuildContext context,
    Offset globalPosition,
    EditorProvider provider,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (provider.hasSelection)
          PopupMenuItem(
            value: 'cut',
            child: Row(
              children: const [
                Icon(Icons.cut_rounded, color: Colors.white70, size: 20),
                SizedBox(width: 12),
                Text('Kes', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (provider.hasSelection)
          PopupMenuItem(
            value: 'copy',
            child: Row(
              children: const [
                Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                SizedBox(width: 12),
                Text('Kopyala', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),

        PopupMenuItem(
          value: 'paste',
          child: Row(
            children: const [
              Icon(Icons.paste_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Yapıştır', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'select_all',
          child: Row(
            children: const [
              Icon(Icons.select_all_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Tümünü Seç', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),

        if (provider.hasSelection) const PopupMenuDivider(height: 1),
        if (provider.hasSelection)
          PopupMenuItem(
            value: 'bold',
            child: Row(
              children: const [
                Icon(
                  Icons.format_bold_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text('Kalın Yap', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (provider.hasSelection)
          PopupMenuItem(
            value: 'italic',
            child: Row(
              children: const [
                Icon(
                  Icons.format_italic_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text('İtalik Yap', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );

    // Seçime göre eylem yapma
    if (value == 'copy' && provider.hasSelection) {
      final start = math.min(provider.selectionBase!, provider.cursorIndex);
      final end = math.max(provider.selectionBase!, provider.cursorIndex);
      Clipboard.setData(
        ClipboardData(text: provider.engine.getText().substring(start, end)),
      );
      provider.updateSelection(provider.cursorIndex, null); // Seçimi bırak
    } else if (value == 'cut' && provider.hasSelection) {
      final start = math.min(provider.selectionBase!, provider.cursorIndex);
      final end = math.max(provider.selectionBase!, provider.cursorIndex);
      Clipboard.setData(
        ClipboardData(text: provider.engine.getText().substring(start, end)),
      );
      provider.deleteSelection();
    } else if (value == 'paste') {
      _pasteFromClipboard(provider);
    } else if (value == 'select_all') {
      provider.updateSelection(provider.engine.getText().length, 0);
    } else if (value == 'bold') {
      provider.toggleBold();
    } else if (value == 'italic') {
      provider.toggleItalic();
    }
  }

  void _onImeChanged(String value, EditorProvider provider) {
    if (_isImeUpdating) return;
    _isImeUpdating = true;

    if (value.length > 1) {
      String added = value.substring(1);
      provider.insertText(added);
    } else if (value.isEmpty) {
      provider.deleteCharacter();
    }

    _imeController.value = const TextEditingValue(
      text: ' ',
      selection: TextSelection.collapsed(offset: 1),
    );

    _startBlinking();
    _isImeUpdating = false;
  }

  Future<void> _pasteFromClipboard(EditorProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      provider.insertText(data.text!);
    }
  }

  bool _handleKeyEvent(KeyEvent event, EditorProvider provider) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

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
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShift) {
          provider.executeRedo();
        } else {
          provider.executeUndo();
        }
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyY) {
        provider.executeRedo();
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyA) {
        provider.updateSelection(provider.engine.getText().length, 0);
        return true;
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
        return true;
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
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyV) {
        _pasteFromClipboard(provider);
        return true;
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
      return true;
    }

    _intendedCursorX = null;

    if (logicalKey == LogicalKeyboardKey.tab) {
      provider.insertText('    ');
      return true;
    }

    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!isMobile) {
      if (logicalKey == LogicalKeyboardKey.backspace) {
        provider.deleteCharacter();
        return true;
      }
      if (logicalKey == LogicalKeyboardKey.enter) {
        provider.insertText('\n');
        return true;
      }
      if (character != null && character.isNotEmpty && !isCtrl) {
        provider.insertText(character);
        return true;
      }
    }

    return false;
  }

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
    if (printableHeight < 100) printableHeight = 100;

    List<double> breaks = [0.0];
    double currentSubHeight = 0.0;
    double accumulatedY = 0.0;

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
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    Widget editorContent = LayoutBuilder(
      builder: (context, constraints) {
        _currentMaxWidth = provider.isPageMode ? 800.0 : constraints.maxWidth;

        final textPainter = _buildPainter(provider, _currentMaxWidth);
        final layout = _computeLayout(textPainter, provider, _currentMaxWidth);

        double customPaintHeight = layout.physicalHeight;
        if (!provider.isPageMode && customPaintHeight < constraints.maxHeight) {
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
                  // 🌟 YENİ: ÇİFT TIKLAYINCA KELİMEYİ SEÇ
                  onDoubleTapDown: (details) {
                    _focusNode.requestFocus();
                    _intendedCursorX = null;
                    int idx = _getOffsetIndex(details.localPosition, provider);
                    context.read<EditorProvider>().selectWordAt(idx);
                    _startBlinking();
                  },
                  // 🌟 YENİ: BASILI TUTUNCA SEÇ VE MENÜYÜ AÇ
                  onLongPressStart: (details) {
                    _focusNode.requestFocus();
                    int idx = _getOffsetIndex(details.localPosition, provider);

                    // Eğer dokunulan yer seçili alanın dışındaysa veya hiç seçim yoksa, o kelimeyi seç!
                    if (!provider.hasSelection) {
                      context.read<EditorProvider>().selectWordAt(idx);
                    } else {
                      int minSel = math.min(
                        provider.selectionBase!,
                        provider.cursorIndex,
                      );
                      int maxSel = math.max(
                        provider.selectionBase!,
                        provider.cursorIndex,
                      );
                      if (idx < minSel || idx > maxSel) {
                        context.read<EditorProvider>().selectWordAt(idx);
                      }
                    }

                    // Kelimeyi seçtikten sonra hemen menüyü patlat
                    _showContextMenu(context, details.globalPosition, provider);
                  },
                  onPanStart: (details) {
                    _focusNode.requestFocus();
                    int idx = _getOffsetIndex(details.localPosition, provider);
                    context.read<EditorProvider>().updateSelection(idx, idx);
                  },
                  onPanUpdate: (details) {
                    int idx = _getOffsetIndex(details.localPosition, provider);
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
                      imageCache: provider.imageCache,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return Stack(
      children: [
        if (isMobile)
          Positioned(
            top: -1000,
            left: -1000,
            child: SizedBox(
              width: 10,
              height: 10,
              child: TextField(
                focusNode: _focusNode,
                controller: _imeController,
                autofocus: widget.isActive,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (val) => _onImeChanged(val, provider),
              ),
            ),
          ),

        Positioned.fill(
          child: isMobile
              ? editorContent
              : Focus(
                  focusNode: _focusNode,
                  autofocus: widget.isActive,
                  child: editorContent,
                ),
        ),
      ],
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
  final Map<int, ui.Image> imageCache;

  EditorPainter({
    required this.textPainter,
    required this.layout,
    required this.plainTextLength,
    required this.cursorIndex,
    required this.showCursor,
    this.selectionBase,
    required this.currentFontSize,
    required this.imageCache,
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

        canvas.clipRect(printableRect);
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
