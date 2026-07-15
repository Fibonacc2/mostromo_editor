import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../providers/editor_provider.dart';
import '../core/page_layout.dart';
import '../core/editor_painter.dart';
import 'desktop_keyboard.dart';
import '../../ui/editor/editor_menus.dart';

class DesktopEditorWidget extends StatefulWidget {
  final VoidCallback? onSave;
  final bool isActive;
  final bool isReadingMode;

  const DesktopEditorWidget({
    super.key,
    this.onSave,
    this.isActive = true,
    this.isReadingMode = false,
  });

  @override
  State<DesktopEditorWidget> createState() => _DesktopEditorWidgetState();
}

class _DesktopEditorWidgetState extends State<DesktopEditorWidget> {
  late FocusNode _focusNode;
  double _currentMaxWidth = 1000.0;
  Timer? _cursorTimer;

  final ValueNotifier<bool> _showCursorNotifier = ValueNotifier<bool>(true);

  double? _intendedCursorX;

  String? _cachedPlainText;
  double? _cachedMaxWidth;
  bool? _cachedIsPageMode;

  TextPainter? _cachedTextPainter;
  PageLayout? _cachedLayout;
  OverlayEntry? _miniToolbarEntry;

  bool _isDraggingSelection = false;
  Offset? _lastPanGlobalPos;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'desktop_editor_focus');

    // 🌟 ODAK GARANTİSİ: Widget ekrana çizildiği an odağı zorla buraya çekiyoruz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive && !widget.isReadingMode) {
        _focusNode.requestFocus();
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !widget.isReadingMode) {
        _startBlinking();
      } else {
        _cursorTimer?.cancel();
        if (mounted) _showCursorNotifier.value = false;
      }
    });

    if (widget.isActive && !widget.isReadingMode) {
      _startBlinking();
    }
  }

  @override
  void didUpdateWidget(covariant DesktopEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReadingMode && !oldWidget.isReadingMode) {
      _hideMiniToolbar();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.unfocus();
        final provider = context.read<EditorProvider>();
        provider.updateSelection(provider.cursorIndex, null);
      });
    } else if (widget.isActive &&
        !oldWidget.isActive &&
        !widget.isReadingMode) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _hideMiniToolbar();
    _focusNode.dispose();
    _cursorTimer?.cancel();
    _showCursorNotifier.dispose();
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
      if (mounted && _focusNode.hasFocus) {
        _showCursorNotifier.value = !_showCursorNotifier.value;
      }
    });
  }

  TextPainter _buildPainter(
    EditorProvider provider,
    double maxWidth,
    double mLeft,
    double mRight,
  ) {
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
        ? maxWidth - mLeft - mRight
        : maxWidth - 64;
    if (printableWidth < 100) printableWidth = 100;

    return TextPainter(text: textSpan, textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: printableWidth);
  }

  PageLayout _computeLayout(
    TextPainter textPainter,
    EditorProvider provider,
    double maxWidth,
    double mLeft,
    double mRight,
    double mTop,
    double mBottom,
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

    double printableHeight = a4Height - mTop - mBottom;
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
      marginTop: mTop,
      marginBottom: mBottom,
      marginLeft: mLeft,
      marginRight: mRight,
      pageBreaks: breaks,
      logicalHeight: accumulatedY,
    );
  }

  int _calculateVerticalMove(EditorProvider provider, bool isUp) {
    if (_cachedTextPainter == null) return provider.cursorIndex;
    int len = provider.engine.getText().length;
    final textPainter = _cachedTextPainter!;
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
    if (_cachedTextPainter == null || _cachedLayout == null) {
      return provider.cursorIndex;
    }
    double logicalY = _cachedLayout!.physicalToLogicalY(localPosition.dy);
    double logicalX =
        localPosition.dx -
        (provider.isPageMode ? _cachedLayout!.marginLeft : 32.0);
    final position = _cachedTextPainter!.getPositionForOffset(
      Offset(logicalX, logicalY),
    );
    return position.offset.clamp(0, provider.engine.getText().length);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    final double mLeft = provider.marginLeft;
    final double mRight = provider.marginRight;
    final double mTop = provider.marginTop;
    final double mBottom = provider.marginBottom;

    Widget editorContent = LayoutBuilder(
      builder: (context, constraints) {
        String currentText = provider.engine.getText();
        bool isPageMode = provider.isPageMode;

        _currentMaxWidth = isPageMode ? 800.0 : constraints.maxWidth;

        if (_cachedTextPainter == null ||
            _cachedPlainText != currentText ||
            _cachedMaxWidth != _currentMaxWidth ||
            _cachedIsPageMode != isPageMode) {
          _cachedTextPainter = _buildPainter(
            provider,
            _currentMaxWidth,
            mLeft,
            mRight,
          );
          _cachedLayout = _computeLayout(
            _cachedTextPainter!,
            provider,
            _currentMaxWidth,
            mLeft,
            mRight,
            mTop,
            mBottom,
          );

          _cachedPlainText = currentText;
          _cachedMaxWidth = _currentMaxWidth;
          _cachedIsPageMode = isPageMode;
        }

        if (_cachedTextPainter != null) {
          final currentOffset = _cachedTextPainter!.getOffsetForCaret(
            TextPosition(
              offset: provider.cursorIndex,
              affinity: TextAffinity.downstream,
            ),
            Rect.zero,
          );

          final metrics = _cachedTextPainter!.computeLineMetrics();
          int currentLineIdx = 0;
          double currentLineCenterY = 0.0;
          double accY = 0.0;

          for (int i = 0; i < metrics.length; i++) {
            double h = metrics[i].height;
            if (currentOffset.dy < accY + h - 1.0) {
              currentLineIdx = i;
              currentLineCenterY = accY + (h / 2);
              break;
            }
            accY += h;
            if (i == metrics.length - 1) {
              currentLineIdx = i;
              currentLineCenterY = accY - (h / 2);
            }
          }

          int startOfLineOffset = _cachedTextPainter!
              .getPositionForOffset(Offset(0, currentLineCenterY))
              .offset;

          int visualCol = math.max(
            1,
            provider.cursorIndex - startOfLineOffset + 1,
          );
          int visualLine = currentLineIdx + 1;

          provider.updateLineAndColumn(visualLine, visualCol);
        }

        double customPaintHeight = _cachedLayout!.physicalHeight;
        if (!isPageMode && customPaintHeight < constraints.maxHeight) {
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              _hideMiniToolbar();
              return false;
            },
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
                  cursor: widget.isReadingMode
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.text,
                  child: GestureDetector(
                    onSecondaryTapDown: widget.isReadingMode
                        ? null
                        : (details) {
                            _hideMiniToolbar();
                            _focusNode.requestFocus();
                            int idx = _getOffsetIndex(
                              details.localPosition,
                              provider,
                            );

                            if (!provider.hasSelection) {
                              provider.updateSelection(idx, null);
                            } else {
                              int min = math.min(
                                provider.selectionBase!,
                                provider.cursorIndex,
                              );
                              int max = math.max(
                                provider.selectionBase!,
                                provider.cursorIndex,
                              );
                              if (idx < min || idx > max) {
                                provider.updateSelection(idx, null);
                              }
                            }
                            EditorMenus.showDesktopContextMenu(
                              context,
                              details.globalPosition,
                              provider,
                              _hideMiniToolbar,
                            );
                          },
                    onTapDown: widget.isReadingMode
                        ? null
                        : (details) {
                            _hideMiniToolbar();
                            _focusNode.requestFocus();
                            _intendedCursorX = null;
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
                              provider.updateSelection(
                                idx,
                                provider.cursorIndex,
                              );
                            } else {
                              provider.updateSelection(
                                idx,
                                provider.selectionBase,
                              );
                            }
                            _startBlinking();
                          },
                    onPanEnd: widget.isReadingMode
                        ? null
                        : (details) {
                            _isDraggingSelection = false;

                            if (provider.hasSelection &&
                                _lastPanGlobalPos != null) {
                              _showMiniToolbarWrapper(
                                _lastPanGlobalPos!,
                                provider,
                              );
                            }
                          },
                    onDoubleTapDown: widget.isReadingMode
                        ? null
                        : (details) {
                            _hideMiniToolbar();
                            _focusNode.requestFocus();
                            _intendedCursorX = null;
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
                              textPainter: _cachedTextPainter!,
                              layout: _cachedLayout!,
                              plainTextLength: provider.engine.getText().length,
                              cursorIndex: provider.cursorIndex,
                              selectionBase: widget.isReadingMode
                                  ? null
                                  : provider.selectionBase,
                              showCursor: widget.isReadingMode
                                  ? false
                                  : showCursor,
                              currentFontSize: provider.currentFontSize ?? 16.0,
                              imageCache: provider.imageCache,
                              isMobile: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // 🌟 KESİN ÇÖZÜM: KeyboardListener yerine doğrudan Focus widget'ı kullanıyoruz
    // ve tuş dinlemeyi doğrudan buraya (onKeyEvent) bağlıyoruz.
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (widget.isReadingMode) return KeyEventResult.ignored;

        bool handled = DesktopKeyboardHandler.handle(
          event,
          context.read<EditorProvider>(),
          // hasFocus parametresini buradan sildik
          onSave: () => widget.onSave?.call(),
          onHideMiniToolbar: _hideMiniToolbar,
          onStartBlinking: _startBlinking,
          onClearIntendedX: () => _intendedCursorX = null,
          onCalculateVerticalMove: (isUp) =>
              _calculateVerticalMove(context.read<EditorProvider>(), isUp),
        );

        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: editorContent,
    );
  }
}
