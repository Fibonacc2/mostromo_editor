import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../providers/editor_provider.dart';
import '../core/page_layout.dart';
import '../core/editor_painter.dart';
import '../core/custom_layout.dart';
import '../../ui/editor/editor_menus.dart';

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
      if (mounted) {
        _showCursorNotifier.value = !_showCursorNotifier.value;
      }
    });
  }

  int _getOffsetIndex(Offset localPosition, EditorProvider provider) {
    if (_cachedLines == null || _cachedLayout == null) {
      return provider.cursorIndex;
    }

    double logicalY = localPosition.dy;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

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
            a4Height: a4Height,
            marginTop: mTop,
            pageGap: 16.0,
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
            totalPages: result.totalPages,
            physicalHeight: result.totalPhysicalHeight,
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

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            _hideMiniToolbar();
            // 🌟 YENİ: Mobil cihazlarda kaydırma pozisyonu dinleyicisi
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
                        bool cursorState = widget.isReadingMode
                            ? false
                            : showCursor;

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
                              currentFontSize: provider.currentFontSize ?? 16.0,
                              imageCache: provider.imageCache,
                              isMobile: true,
                              scrollController: provider.scrollController,
                              showPageNumbers: provider.showPageNumbers,
                              pageNumberAlignment: provider.pageNumberAlignment,
                              searchMatches: provider.searchMatches,
                              currentSearchQuery: provider.currentSearchQuery,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 🌟 YENİ: MOBİL YÜZEN SAYFA GÖSTERGESİ (Floating Badge)
              ValueListenableBuilder<int?>(
                valueListenable: _scrollPageNotifier,
                builder: (context, page, child) {
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    right: page != null
                        ? 16.0
                        : -100.0, // Mobilde biraz daha dar kenar boşluğu
                    top: constraints.maxHeight / 2 - 20,
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
                            ).withValues(alpha: 0.5),
                          ),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
