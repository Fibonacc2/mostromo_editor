import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../providers/editor_provider.dart';
import '../core/page_layout.dart';
import '../core/editor_painter.dart';
import '../editor_keyboard_handler.dart';
import '../../ui/editor/editor_menus.dart';

enum DragHandle { none, left, right }

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
  late FocusNode _focusNode;
  double _currentMaxWidth = 1000.0;
  Timer? _cursorTimer;
  bool _showCursor = true;
  double? _intendedCursorX;

  // 📱 MOBİLE ÖZEL: Sanal klavye (IME) yakalayıcısı
  final TextEditingController _imeController = TextEditingController(
    text: '\u200B',
  );
  bool _isImeUpdating = false;
  String _previousImeText = '\u200B';

  // 📱 MOBİLE ÖZEL: Parmakla metin seçme kolları
  DragHandle _currentDragHandle = DragHandle.none;
  int _dragAnchorIndex = 0;
  bool _isDraggingHandle = false;

  TextPainter? _cachedTextPainter;
  PageLayout? _cachedLayout;
  OverlayEntry? _miniToolbarEntry;
  Offset? _lastPanGlobalPos;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (!mounted || widget.isReadingMode) return KeyEventResult.ignored;

        bool handled = EditorKeyboardHandler.handle(
          event,
          context.read<EditorProvider>(),
          onSave: () => widget.onSave?.call(),
          onHideMiniToolbar: _hideMiniToolbar,
          onStartBlinking: _startBlinking,
          onResetIme: _resetIme,
          onClearIntendedX: () => _intendedCursorX = null,
          onCalculateVerticalMove: (isUp) =>
              _calculateVerticalMove(context.read<EditorProvider>(), isUp),
        );
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !widget.isReadingMode) {
        _startBlinking();
      } else {
        _cursorTimer?.cancel();
        if (mounted) setState(() => _showCursor = false);
      }
    });

    if (widget.isActive && !widget.isReadingMode) _startBlinking();
  }

  @override
  void didUpdateWidget(covariant MobileEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReadingMode && !oldWidget.isReadingMode) {
      _hideMiniToolbar();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.unfocus();
        final provider = context.read<EditorProvider>();
        provider.updateSelection(provider.cursorIndex, null);
      });
    }
  }

  @override
  void dispose() {
    _hideMiniToolbar();
    _focusNode.dispose();
    _cursorTimer?.cancel();
    _imeController.dispose();
    super.dispose();
  }

  void _hideMiniToolbar() {
    if (_miniToolbarEntry != null) {
      _miniToolbarEntry!.remove();
      _miniToolbarEntry = null;
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

  void _resetIme() {
    _isImeUpdating = true;
    _previousImeText = '\u200B';
    _imeController.value = const TextEditingValue(
      text: '\u200B',
      selection: TextSelection.collapsed(offset: 1),
    );
    _isImeUpdating = false;
  }

  void _onImeChanged(String value, EditorProvider provider) {
    if (_isImeUpdating || widget.isReadingMode) return;
    _hideMiniToolbar();

    if (value.startsWith(_previousImeText)) {
      String added = value.substring(_previousImeText.length);
      provider.insertText(added);
    } else {
      int commonPrefixLen = 0;
      int minLen = math.min(_previousImeText.length, value.length);
      while (commonPrefixLen < minLen &&
          _previousImeText[commonPrefixLen] == value[commonPrefixLen]) {
        commonPrefixLen++;
      }

      int charsToDelete = _previousImeText.length - commonPrefixLen;
      for (int i = 0; i < charsToDelete; i++) {
        provider.deleteCharacter();
      }

      String charsToAdd = value.substring(commonPrefixLen);
      if (charsToAdd.isNotEmpty) {
        provider.insertText(charsToAdd);
      }
    }

    _previousImeText = value;
    _startBlinking();
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
    if (_cachedTextPainter == null || _cachedLayout == null)
      return provider.cursorIndex;
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

    final double mLeft = provider.isPageMode ? 16.0 : provider.marginLeft;
    final double mRight = provider.isPageMode ? 16.0 : provider.marginRight;
    final double mTop = provider.isPageMode ? 24.0 : provider.marginTop;
    final double mBottom = provider.isPageMode ? 24.0 : provider.marginBottom;

    Widget editorContent = LayoutBuilder(
      builder: (context, constraints) {
        _currentMaxWidth = constraints.maxWidth;
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

        double customPaintHeight = _cachedLayout!.physicalHeight;
        if (!provider.isPageMode && customPaintHeight < constraints.maxHeight)
          customPaintHeight = constraints.maxHeight;

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
              physics: _isDraggingHandle
                  ? const NeverScrollableScrollPhysics()
                  : null,
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
                child: GestureDetector(
                  onTapDown: widget.isReadingMode
                      ? null
                      : (details) {
                          _hideMiniToolbar();
                          _focusNode.requestFocus();
                          _intendedCursorX = null;
                        },
                  onPanDown: widget.isReadingMode
                      ? null
                      : (details) {
                          _currentDragHandle = DragHandle.none;
                          if (provider.hasSelection &&
                              _cachedTextPainter != null &&
                              _cachedLayout != null) {
                            int startIdx = math.min(
                              provider.selectionBase!,
                              provider.cursorIndex,
                            );
                            int endIdx = math.max(
                              provider.selectionBase!,
                              provider.cursorIndex,
                            );

                            double logicalY = _cachedLayout!.physicalToLogicalY(
                              details.localPosition.dy,
                            );
                            double logicalX =
                                details.localPosition.dx -
                                (provider.isPageMode
                                    ? _cachedLayout!.marginLeft
                                    : 32.0);
                            Offset logicalTouch = Offset(logicalX, logicalY);

                            final boxes = _cachedTextPainter!
                                .getBoxesForSelection(
                                  TextSelection(
                                    baseOffset: startIdx,
                                    extentOffset: endIdx,
                                  ),
                                );

                            if (boxes.isNotEmpty) {
                              Offset leftHandlePos = Offset(
                                boxes.first.left,
                                boxes.first.bottom + 6,
                              );
                              Offset rightHandlePos = Offset(
                                boxes.last.right,
                                boxes.last.bottom + 6,
                              );

                              if ((logicalTouch - leftHandlePos).distance <
                                  70) {
                                _currentDragHandle = DragHandle.left;
                                _dragAnchorIndex = endIdx;
                                setState(() => _isDraggingHandle = true);
                                return;
                              } else if ((logicalTouch - rightHandlePos)
                                      .distance <
                                  70) {
                                _currentDragHandle = DragHandle.right;
                                _dragAnchorIndex = startIdx;
                                setState(() => _isDraggingHandle = true);
                                return;
                              }
                            }
                          }
                        },
                  onTapUp: widget.isReadingMode
                      ? null
                      : (details) {
                          if (_currentDragHandle != DragHandle.none) return;
                          int idx = _getOffsetIndex(
                            details.localPosition,
                            provider,
                          );

                          if (provider.hasSelection) {
                            int min = math.min(
                              provider.selectionBase!,
                              provider.cursorIndex,
                            );
                            int max = math.max(
                              provider.selectionBase!,
                              provider.cursorIndex,
                            );
                            if (idx >= min && idx <= max) {
                              EditorMenus.showMobileContextMenu(
                                context,
                                details.globalPosition,
                                provider,
                              );
                              return;
                            }
                          }
                          provider.updateSelection(idx, null);
                          _resetIme();
                          _startBlinking();
                        },
                  onLongPressStart: widget.isReadingMode
                      ? null
                      : (details) {
                          _focusNode.requestFocus();
                          int idx = _getOffsetIndex(
                            details.localPosition,
                            provider,
                          );
                          if (!provider.hasSelection) {
                            provider.selectWordAt(idx);
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
                              provider.selectWordAt(idx);
                            }
                          }
                          _resetIme();
                          EditorMenus.showMobileContextMenu(
                            context,
                            details.globalPosition,
                            provider,
                          );
                        },
                  onPanUpdate: widget.isReadingMode
                      ? null
                      : (details) {
                          _lastPanGlobalPos = details.globalPosition;
                          int idx = _getOffsetIndex(
                            details.localPosition,
                            provider,
                          );
                          if (_currentDragHandle != DragHandle.none) {
                            provider.updateSelection(idx, _dragAnchorIndex);
                          } else {
                            provider.updateSelection(
                              idx,
                              provider.selectionBase,
                            );
                          }
                        },
                  onPanEnd: widget.isReadingMode
                      ? null
                      : (details) {
                          _currentDragHandle = DragHandle.none;
                          setState(() => _isDraggingHandle = false);
                        },
                  onPanCancel: widget.isReadingMode
                      ? null
                      : () {
                          _currentDragHandle = DragHandle.none;
                          setState(() => _isDraggingHandle = false);
                        },
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
                      showCursor: widget.isReadingMode ? false : _showCursor,
                      currentFontSize: provider.currentFontSize ?? 16.0,
                      imageCache: provider.imageCache,
                      isMobile: true, // 📱 Mobil cihaz olduğunu belirtiyoruz!
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
        // 🌟 GİZLİ TEXTFIELD HİLESİ SADECE MOBİLDE ÇALIŞIYOR
        Positioned(
          top: -1000,
          left: -1000,
          child: SizedBox(
            width: 10,
            height: 10,
            child: TextField(
              readOnly: widget.isReadingMode,
              focusNode: _focusNode,
              controller: _imeController,
              autofocus: widget.isActive,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              enableSuggestions: true,
              onChanged: (val) => _onImeChanged(val, provider),
            ),
          ),
        ),
        Positioned.fill(child: editorContent),
      ],
    );
  }
}
