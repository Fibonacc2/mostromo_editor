import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../providers/editor_provider.dart';
import '../core/page_layout.dart';
import '../core/editor_painter.dart';
import '../core/custom_layout.dart';
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

  // 🌟 YENİ: Kaydırma Sayfası Göstergesi için Değişkenler
  final ValueNotifier<int?> _scrollPageNotifier = ValueNotifier<int?>(null);
  Timer? _scrollIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'desktop_editor_focus');

    _lineBreaker = LineBreaker(_measurer);
    _layouter = DocumentLayouter(_lineBreaker);

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
    _measurer.clearCache();
    _scrollPageNotifier.dispose(); // Bellek sızıntısını önle
    _scrollIndicatorTimer?.cancel();
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

  void _extractOutline(EditorProvider provider) {
    if (_cachedLines == null || _cachedLayout == null) return;

    List<Map<String, dynamic>> outline = [];
    String fullText = provider.engine.getText();

    for (var line in _cachedLines!) {
      if (line.length == 0 || line.words.isEmpty) continue;

      var style = line.words.first.style;
      double size = style.fontSize ?? 16.0;

      bool isBold =
          style.fontWeight == FontWeight.bold ||
          style.fontWeight == FontWeight.w700;

      if (isBold && size > 18.0) {
        String text = fullText
            .substring(line.startOffset, line.startOffset + line.length)
            .trim();
        if (text.isNotEmpty) {
          int level;
          if (size >= 24.0) {
            level = 1;
          } else if (size >= 20.0) {
            level = 2;
          } else {
            level = 3;
          }

          if (outline.isNotEmpty &&
              outline.last['offset'] + outline.last['text'].length >=
                  line.startOffset) {
            outline.last['text'] += " $text";
          } else {
            outline.add({
              'text': text,
              'level': level,
              'dy': line.dy,
              'offset': line.startOffset,
            });
          }
        }
      }
    }
    provider.updateOutline(outline);
  }

  int _getOffsetIndex(Offset localPosition, EditorProvider provider) {
    if (_cachedLines == null || _cachedLayout == null) {
      return provider.cursorIndex;
    }

    double logicalY = localPosition.dy;
    double logicalX;

    if (provider.isPageMode) {
      logicalX = localPosition.dx - _cachedLayout!.marginLeft;
    } else {
      logicalX = localPosition.dx - 32.0;
    }

    LogicalLine? targetLine;
    for (var line in _cachedLines!) {
      if (logicalY >= line.dy && logicalY <= line.dy + line.height) {
        targetLine = line;
        break;
      }
    }

    if (targetLine == null) {
      if (logicalY < 0) {
        return 0;
      } else {
        return provider.engine.getText().length;
      }
    }

    final position = targetLine.textPainter.getPositionForOffset(
      Offset(logicalX, 0),
    );
    int localOffset = position.offset;

    if (localOffset > targetLine.length) {
      localOffset = targetLine.length;
    }

    return (targetLine.startOffset + localOffset).clamp(
      0,
      provider.engine.getText().length,
    );
  }

  int _calculateVerticalMove(EditorProvider provider, bool isUp) {
    if (_cachedLines == null || _cachedLines!.isEmpty) {
      return provider.cursorIndex;
    }

    int len = provider.engine.getText().length;

    int currentLineIdx = -1;
    for (int i = 0; i < _cachedLines!.length; i++) {
      int start = _cachedLines![i].startOffset;
      int end;
      if (i + 1 < _cachedLines!.length) {
        end = _cachedLines![i + 1].startOffset;
      } else {
        end = len + 1;
      }

      if (provider.cursorIndex >= start && provider.cursorIndex < end) {
        currentLineIdx = i;
        break;
      }
    }

    if (currentLineIdx == -1) {
      return provider.cursorIndex;
    }

    LogicalLine currentLine = _cachedLines![currentLineIdx];

    int localOffset = provider.cursorIndex - currentLine.startOffset;

    if (localOffset > currentLine.length) {
      localOffset = currentLine.length;
    }

    final currentOffset = currentLine.textPainter.getOffsetForCaret(
      TextPosition(offset: localOffset, affinity: TextAffinity.downstream),
      Rect.zero,
    );

    _intendedCursorX ??= currentOffset.dx;

    int targetLineIdx;
    if (isUp) {
      targetLineIdx = currentLineIdx - 1;
    } else {
      targetLineIdx = currentLineIdx + 1;
    }

    if (targetLineIdx < 0) {
      return 0;
    }
    if (targetLineIdx >= _cachedLines!.length) {
      return len;
    }

    LogicalLine targetLine = _cachedLines![targetLineIdx];

    final newPosition = targetLine.textPainter.getPositionForOffset(
      Offset(_intendedCursorX!, 0),
    );
    int newLocalOffset = newPosition.offset;

    if (newLocalOffset > targetLine.length) {
      newLocalOffset = targetLine.length;
    }

    return (targetLine.startOffset + newLocalOffset).clamp(0, len);
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

        if (isPageMode) {
          _currentMaxWidth = 800.0;
        } else {
          _currentMaxWidth = constraints.maxWidth;
        }

        if (_cachedLines == null ||
            _cachedVersion != provider.engine.version ||
            _cachedPlainText != currentText ||
            _cachedMaxWidth != _currentMaxWidth ||
            _cachedIsPageMode != isPageMode) {
          double a4Width = _currentMaxWidth;
          double a4Height = a4Width * 1.4142;

          double printableWidth;
          if (isPageMode) {
            printableWidth = a4Width - mLeft - mRight;
          } else {
            printableWidth = a4Width - 64;
          }

          if (printableWidth < 100) printableWidth = 100;

          double printableHeight;
          if (isPageMode) {
            printableHeight = a4Height - mTop - mBottom;
          } else {
            printableHeight = double.infinity;
          }

          if (printableHeight < 100) printableHeight = 100;

          final result = _layouter.layout(
            fullText: currentText,
            blocks: provider.engine.getParagraphBlocks(),
            printableWidth: printableWidth,
            printableHeight: printableHeight,
            isPageMode: isPageMode,
            a4Height: a4Height,
            marginTop: mTop,
            pageGap: 32.0,
          );

          _cachedLines = result.lines;

          _cachedLayout = PageLayout(
            isPageMode: isPageMode,
            a4Width: a4Width,
            a4Height: isPageMode ? a4Height : 0,
            pageGap: isPageMode ? 32.0 : 0,
            marginTop: isPageMode ? mTop : 32,
            marginBottom: isPageMode ? mBottom : 32,
            marginLeft: isPageMode ? mLeft : 32,
            marginRight: isPageMode ? mRight : 32,
            totalPages: result.totalPages,
            physicalHeight: result.totalPhysicalHeight,
          );

          _cachedVersion = provider.engine.version;
          _cachedPlainText = currentText;
          _cachedMaxWidth = _currentMaxWidth;
          _cachedIsPageMode = isPageMode;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _extractOutline(provider);
          });
        }

        if (_cachedLines != null) {
          int currentLineIdx = -1;

          for (int i = 0; i < _cachedLines!.length; i++) {
            int start = _cachedLines![i].startOffset;
            int end;
            if (i + 1 < _cachedLines!.length) {
              end = _cachedLines![i + 1].startOffset;
            } else {
              end = currentText.length + 1;
            }

            if (provider.cursorIndex >= start && provider.cursorIndex < end) {
              currentLineIdx = i;
              break;
            }
          }

          if (currentLineIdx != -1) {
            LogicalLine cl = _cachedLines![currentLineIdx];
            int localOffset = provider.cursorIndex - cl.startOffset;

            if (localOffset > cl.length) {
              localOffset = cl.length;
            }

            int globalLine = currentLineIdx + 1;
            int visualCol = math.max(1, localOffset + 1);

            provider.updateLineAndColumn(globalLine, visualCol);
          }
        }

        double customPaintHeight = _cachedLayout!.physicalHeight;
        if (!isPageMode && customPaintHeight < constraints.maxHeight) {
          customPaintHeight = constraints.maxHeight;
        }

        int finalCursorIndex = provider.cursorIndex.clamp(
          0,
          currentText.length,
        );
        int? finalSelectionBase;
        if (widget.isReadingMode || provider.selectionBase == null) {
          finalSelectionBase = null;
        } else {
          finalSelectionBase = provider.selectionBase!.clamp(
            0,
            currentText.length,
          );
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
              // 🌟 YENİ: Kaydırma miktarını dinle ve sayfayı hesapla
              if (provider.isPageMode &&
                  _cachedLayout != null &&
                  scrollInfo is ScrollUpdateNotification) {
                double physicalY = scrollInfo.metrics.pixels;
                double pageAndGap =
                    _cachedLayout!.a4Height + _cachedLayout!.pageGap;
                int currentPage = (physicalY / pageAndGap).floor() + 1;
                currentPage = currentPage.clamp(1, _cachedLayout!.totalPages);

                if (_scrollPageNotifier.value != currentPage) {
                  _scrollPageNotifier.value = currentPage;
                }

                // Kaydırma bitince göstergeyi kaybetmek için sayacı sıfırla
                _scrollIndicatorTimer?.cancel();
                _scrollIndicatorTimer = Timer(
                  const Duration(milliseconds: 1200),
                  () {
                    if (mounted) _scrollPageNotifier.value = null;
                  },
                );
              }
              return false;
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: provider.scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Container(
                    width: constraints.maxWidth,
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
                            bool cursorState;
                            if (widget.isReadingMode) {
                              cursorState = false;
                            } else {
                              cursorState = showCursor;
                            }

                            return RepaintBoundary(
                              child: CustomPaint(
                                size: Size(_currentMaxWidth, customPaintHeight),
                                painter: EditorPainter(
                                  lines: _cachedLines!,
                                  layout: _cachedLayout!,
                                  plainTextLength: currentText.length,
                                  cursorIndex: finalCursorIndex,
                                  selectionBase: finalSelectionBase,
                                  showCursor: cursorState,
                                  currentFontSize:
                                      provider.currentFontSize ?? 16.0,
                                  imageCache: provider.imageCache,
                                  isMobile: false,
                                  scrollController: provider.scrollController,
                                  showPageNumbers: provider.showPageNumbers,
                                  pageNumberAlignment:
                                      provider.pageNumberAlignment,
                                  searchMatches: provider.searchMatches,
                                  currentSearchQuery:
                                      provider.currentSearchQuery,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 🌟 YENİ: YÜZEN SAYFA GÖSTERGESİ (Floating Badge)
                ValueListenableBuilder<int?>(
                  valueListenable: _scrollPageNotifier,
                  builder: (context, page, child) {
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      right: page != null
                          ? 32.0
                          : -100.0, // Kaydırma yoksa ekran dışına uçar
                      top:
                          constraints.maxHeight / 2 -
                          20, // Ekranın dikey merkezinde durur
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: page != null ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.1),
                            ), // Temamızın (MostromoTheme) accent rengi
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            "Sayfa ${page ?? 1}",
                            style: const TextStyle(
                              color: Color.fromARGB(170, 179, 175, 175),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (widget.isReadingMode) return KeyEventResult.ignored;

        bool handled = DesktopKeyboardHandler.handle(
          event,
          context.read<EditorProvider>(),
          context,
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
