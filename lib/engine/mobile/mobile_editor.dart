import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../providers/editor_provider.dart';
import '../core/page_layout.dart';
import '../core/editor_painter.dart';
import '../core/custom_layout.dart';
import '../../ui/editor/editor_menus.dart';
// import 'mobile_keyboard.dart'; // Eğer mobil için özel bir klavye dinleyicin varsa buraya ekle

class MobileEditorWidget extends StatefulWidget {
  final VoidCallback? onSave;
  final bool isActive;
  final bool isReadingMode;

  const MobileEditorWidget({
    super.key,
    this.onSave,
    this.isActive = true,
    this.isReadingMode = false,
  });

  @override
  State<MobileEditorWidget> createState() => _MobileEditorWidgetState();
}

class _MobileEditorWidgetState extends State<MobileEditorWidget> {
  double _currentMaxWidth = 1000.0;
  Timer? _cursorTimer;

  final ValueNotifier<bool> _showCursorNotifier = ValueNotifier<bool>(true);

  // 🌟 YENİ MOTOR NESNELERİ
  final CustomTextMeasurer _measurer = CustomTextMeasurer();
  late LineBreaker _lineBreaker;
  late DocumentLayouter _layouter;

  String? _cachedPlainText;
  double? _cachedMaxWidth;
  bool? _cachedIsPageMode;
  int? _cachedVersion;

  List<LogicalLine>? _cachedLines;
  PageLayout? _cachedLayout;
  OverlayEntry? _miniToolbarEntry;

  bool _isDraggingSelection = false;
  Offset? _lastPanGlobalPos;

  @override
  void initState() {
    super.initState();
    _lineBreaker = LineBreaker(_measurer);
    _layouter = DocumentLayouter(_lineBreaker);

    if (widget.isActive && !widget.isReadingMode) {
      _startBlinking();
    }
  }

  @override
  void didUpdateWidget(covariant MobileEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReadingMode && !oldWidget.isReadingMode) {
      _hideMiniToolbar();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<EditorProvider>();
        provider.updateSelection(provider.cursorIndex, null);
      });
    }
  }

  @override
  void dispose() {
    _hideMiniToolbar();
    _cursorTimer?.cancel();
    _showCursorNotifier.dispose();
    _measurer.clearCache();
    super.dispose();
  }

  void _hideMiniToolbar() {
    if (_miniToolbarEntry != null) {
      _miniToolbarEntry!.remove();
      _miniToolbarEntry = null;
    }
  }

  void _showMiniToolbarWrapper(Offset globalPos, EditorProvider provider) {
    _hideMiniToolbar();
    _miniToolbarEntry = EditorMenus.showMiniToolbar(
      context,
      globalPos,
      provider,
      _hideMiniToolbar,
    );
  }

  void _startBlinking() {
    _cursorTimer?.cancel();
    _showCursorNotifier.value = true;
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        _showCursorNotifier.value = !_showCursorNotifier.value;
      }
    });
  }

  int _getOffsetIndex(Offset localPosition, EditorProvider provider) {
    if (_cachedLines == null || _cachedLayout == null) {
      return provider.cursorIndex;
    }

    double logicalY = _cachedLayout!.physicalToLogicalY(localPosition.dy);
    double logicalX =
        localPosition.dx -
        (provider.isPageMode ? _cachedLayout!.marginLeft : 16.0);

    LogicalLine? targetLine;
    for (var line in _cachedLines!) {
      if (logicalY >= line.dy && logicalY <= line.dy + line.height) {
        targetLine = line;
        break;
      }
    }

    if (targetLine == null) {
      return logicalY < 0 ? 0 : provider.engine.getText().length;
    }

    final spans = targetLine.words
        .map((w) => TextSpan(text: w.text, style: w.style))
        .toList();
    final painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();

    final position = painter.getPositionForOffset(Offset(logicalX, 0));
    int localOffset = position.offset;

    if (localOffset > targetLine.length) {
      localOffset = targetLine.length;
    }

    return (targetLine.startOffset + localOffset).clamp(
      0,
      provider.engine.getText().length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    // Mobil ekranlar için kenar boşlukları biraz daha daraltıldı
    final double mLeft = provider.isPageMode ? provider.marginLeft : 16.0;
    final double mRight = provider.isPageMode ? provider.marginRight : 16.0;
    final double mTop = provider.isPageMode ? provider.marginTop : 16.0;
    final double mBottom = provider.isPageMode ? provider.marginBottom : 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        String currentText = provider.engine.getText();
        bool isPageMode = provider.isPageMode;

        _currentMaxWidth = isPageMode ? 800.0 : constraints.maxWidth;

        if (_cachedLines == null ||
            _cachedVersion != provider.engine.version ||
            _cachedPlainText != currentText ||
            _cachedMaxWidth != _currentMaxWidth ||
            _cachedIsPageMode != isPageMode) {
          double a4Width = _currentMaxWidth;
          double a4Height = a4Width * 1.4142;
          double printableWidth = isPageMode
              ? a4Width - mLeft - mRight
              : a4Width - (mLeft + mRight);
          if (printableWidth < 100) printableWidth = 100;
          double printableHeight = isPageMode
              ? a4Height - mTop - mBottom
              : double.infinity;
          if (printableHeight < 100) printableHeight = 100;

          final result = _layouter.layout(
            fullText: currentText,
            blocks: provider.engine.getParagraphBlocks(),
            printableWidth: printableWidth,
            printableHeight: printableHeight,
            isPageMode: isPageMode,
          );

          _cachedLines = result.lines;

          _cachedLayout = PageLayout(
            isPageMode: isPageMode,
            a4Width: a4Width,
            a4Height: isPageMode ? a4Height : 0,
            pageGap: isPageMode ? 16.0 : 0,
            marginTop: mTop,
            marginBottom: mBottom,
            marginLeft: mLeft,
            marginRight: mRight,
            pageBreaks: result.pageBreaks,
            logicalHeight: isPageMode
                ? result.totalLogicalHeight
                : result.totalLogicalHeight + 64,
          );

          _cachedVersion = provider.engine.version;
          _cachedPlainText = currentText;
          _cachedMaxWidth = _currentMaxWidth;
          _cachedIsPageMode = isPageMode;
        }

        double customPaintHeight = _cachedLayout!.physicalHeight;
        if (!isPageMode && customPaintHeight < constraints.maxHeight) {
          customPaintHeight = constraints.maxHeight;
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            _hideMiniToolbar();
            return false;
          },
          child: SingleChildScrollView(
            controller: provider.scrollController,
            physics: const BouncingScrollPhysics(),
            child: Container(
              width: constraints.maxWidth,
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              alignment: Alignment.topCenter,
              color: provider.isPageMode
                  ? const Color(0xFF050505)
                  : Colors.transparent,
              padding: provider.isPageMode
                  ? const EdgeInsets.symmetric(vertical: 16)
                  : EdgeInsets.zero,
              child: GestureDetector(
                onTapDown: widget.isReadingMode
                    ? null
                    : (details) {
                        _hideMiniToolbar();
                        int idx = _getOffsetIndex(
                          details.localPosition,
                          provider,
                        );
                        provider.updateSelection(idx, null);
                        _isDraggingSelection = true;
                        _startBlinking();
                      },
                onPanUpdate: widget.isReadingMode
                    ? null
                    : (details) {
                        _lastPanGlobalPos = details.globalPosition;
                        if (!_isDraggingSelection) return;
                        int idx = _getOffsetIndex(
                          details.localPosition,
                          provider,
                        );

                        if (provider.selectionBase == null) {
                          provider.updateSelection(idx, provider.cursorIndex);
                        } else {
                          provider.updateSelection(idx, provider.selectionBase);
                        }
                        _startBlinking();
                      },
                onPanEnd: widget.isReadingMode
                    ? null
                    : (details) {
                        _isDraggingSelection = false;
                        if (provider.hasSelection &&
                            _lastPanGlobalPos != null) {
                          _showMiniToolbarWrapper(_lastPanGlobalPos!, provider);
                        }
                      },
                onLongPressStart: widget.isReadingMode
                    ? null
                    : (details) {
                        _hideMiniToolbar();
                        int idx = _getOffsetIndex(
                          details.localPosition,
                          provider,
                        );
                        provider.selectWordAt(idx);
                        _showMiniToolbarWrapper(
                          details.globalPosition,
                          provider,
                        );
                        _startBlinking();
                      },
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showCursorNotifier,
                  builder: (context, showCursor, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: Size(_currentMaxWidth, customPaintHeight),
                        painter: EditorPainter(
                          lines: _cachedLines!,
                          layout: _cachedLayout!,
                          plainTextLength: provider.engine.getText().length,
                          cursorIndex: provider.cursorIndex,
                          selectionBase: widget.isReadingMode
                              ? null
                              : provider.selectionBase,
                          showCursor: widget.isReadingMode ? false : showCursor,
                          currentFontSize: provider.currentFontSize ?? 16.0,
                          imageCache: provider.imageCache,
                          isMobile: true, // Mobil platform
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
