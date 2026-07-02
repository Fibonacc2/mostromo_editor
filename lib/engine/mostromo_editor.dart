import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/editor_provider.dart';
import 'page_layout.dart';
import 'editor_painter.dart';

enum DragHandle { none, left, right }

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

  final TextEditingController _imeController = TextEditingController(
    text: '\u200B',
  );
  bool _isImeUpdating = false;
  String _previousImeText = '\u200B';

  DragHandle _currentDragHandle = DragHandle.none;
  int _dragAnchorIndex = 0;
  bool _isDraggingHandle = false;

  TextPainter? _cachedTextPainter;
  PageLayout? _cachedLayout;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (!mounted) {
          return KeyEventResult.ignored;
        }
        bool handled = _handleKeyEvent(event, context.read<EditorProvider>());
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _startBlinking();
      } else {
        _cursorTimer?.cancel();
        if (mounted) {
          setState(() => _showCursor = false);
        }
      }
    });

    if (widget.isActive) {
      _startBlinking();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _cursorTimer?.cancel();
    _imeController.dispose();
    super.dispose();
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
    if (_isImeUpdating) {
      return;
    }

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

  void _showContextMenu(
    BuildContext context,
    Offset globalPosition,
    EditorProvider provider,
  ) async {
    double menuY = globalPosition.dy + 45;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx - 50,
        menuY,
        globalPosition.dx + 50,
        menuY,
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

    if (value == 'copy' && provider.hasSelection) {
      final start = math.min(provider.selectionBase!, provider.cursorIndex);
      final end = math.max(provider.selectionBase!, provider.cursorIndex);
      Clipboard.setData(
        ClipboardData(text: provider.engine.getText().substring(start, end)),
      );
      provider.updateSelection(provider.cursorIndex, null);
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

  Future<void> _pasteFromClipboard(EditorProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      provider.insertText(data.text!);
    }
  }

  bool _handleKeyEvent(KeyEvent event, EditorProvider provider) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

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
        if (newCursor > 0) {
          newCursor--;
        }
        _intendedCursorX = null;
      } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
        if (newCursor < provider.engine.getText().length) {
          newCursor++;
        }
        _intendedCursorX = null;
      } else {
        newCursor = _calculateVerticalMove(
          provider,
          logicalKey == LogicalKeyboardKey.arrowUp,
        );
      }
      provider.updateSelection(newCursor, newBase);
      _resetIme();
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

    if (printableWidth < 100) {
      printableWidth = 100;
    }

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
    if (printableHeight < 100) {
      printableHeight = 100;
    }

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
    if (_cachedTextPainter == null) {
      return provider.cursorIndex;
    }

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

    if (metrics.isEmpty) {
      return isUp ? 0 : len;
    }

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

    if (targetLine < 0) {
      return provider.cursorIndex;
    }
    if (targetLine >= metrics.length) {
      return provider.cursorIndex;
    }

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
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    final double mLeft = isMobile && provider.isPageMode
        ? 16.0
        : provider.marginLeft;
    final double mRight = isMobile && provider.isPageMode
        ? 16.0
        : provider.marginRight;
    final double mTop = isMobile && provider.isPageMode
        ? 24.0
        : provider.marginTop;
    final double mBottom = isMobile && provider.isPageMode
        ? 24.0
        : provider.marginBottom;

    Widget editorContent = LayoutBuilder(
      builder: (context, constraints) {
        _currentMaxWidth = provider.isPageMode
            ? (isMobile ? constraints.maxWidth : 800.0)
            : constraints.maxWidth;

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
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: GestureDetector(
                  onPanDown: (details) {
                    _focusNode.requestFocus();
                    _intendedCursorX = null;
                    _currentDragHandle = DragHandle.none;

                    if (isMobile &&
                        provider.hasSelection &&
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

                      final boxes = _cachedTextPainter!.getBoxesForSelection(
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

                        if ((logicalTouch - leftHandlePos).distance < 70) {
                          _currentDragHandle = DragHandle.left;
                          _dragAnchorIndex = endIdx;
                          setState(() => _isDraggingHandle = true);
                          return;
                        } else if ((logicalTouch - rightHandlePos).distance <
                            70) {
                          _currentDragHandle = DragHandle.right;
                          _dragAnchorIndex = startIdx;
                          setState(() => _isDraggingHandle = true);
                          return;
                        }
                      }
                    }
                  },
                  onTapUp: (details) {
                    if (_currentDragHandle != DragHandle.none) {
                      return;
                    }

                    int idx = _getOffsetIndex(details.localPosition, provider);

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
                        _showContextMenu(
                          context,
                          details.globalPosition,
                          provider,
                        );
                        return;
                      }
                    }

                    context.read<EditorProvider>().updateSelection(idx, null);
                    _resetIme();
                    _startBlinking();
                  },
                  onDoubleTapDown: (details) {
                    _focusNode.requestFocus();
                    _intendedCursorX = null;
                    int idx = _getOffsetIndex(details.localPosition, provider);
                    context.read<EditorProvider>().selectWordAt(idx);
                    _resetIme();
                    _startBlinking();
                  },
                  onLongPressStart: (details) {
                    _focusNode.requestFocus();
                    int idx = _getOffsetIndex(details.localPosition, provider);

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
                    _resetIme();
                    _showContextMenu(context, details.globalPosition, provider);
                  },
                  onPanStart: (details) {
                    if (_currentDragHandle == DragHandle.none) {
                      int idx = _getOffsetIndex(
                        details.localPosition,
                        provider,
                      );
                      context.read<EditorProvider>().updateSelection(idx, idx);
                      _resetIme();
                    }
                  },
                  onPanUpdate: (details) {
                    int idx = _getOffsetIndex(details.localPosition, provider);

                    if (_currentDragHandle != DragHandle.none) {
                      context.read<EditorProvider>().updateSelection(
                        idx,
                        _dragAnchorIndex,
                      );
                    } else {
                      context.read<EditorProvider>().updateSelection(
                        idx,
                        provider.selectionBase,
                      );
                    }
                  },
                  onPanEnd: (details) {
                    _currentDragHandle = DragHandle.none;
                    setState(() => _isDraggingHandle = false);
                  },
                  onPanCancel: () {
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
                      selectionBase: provider.selectionBase,
                      showCursor: _showCursor,
                      currentFontSize: provider.currentFontSize ?? 16.0,
                      imageCache: provider.imageCache,
                      isMobile: isMobile,
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
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                enableSuggestions: true,
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
