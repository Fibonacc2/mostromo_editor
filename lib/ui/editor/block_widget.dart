import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../engine/block_engine/mostromo_block.dart';
import '../../providers/block_editor_provider.dart';
import '../../providers/editor_provider.dart';
import '../../engine/mostromo_editor.dart';

class BlockWidget extends StatefulWidget {
  final MostromoBlock block;
  const BlockWidget({super.key, required this.block});
  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  bool _isHovered = false;

  double _localX = 0;
  double _localY = 0;
  double _localW = 300;
  double _localH = 150;
  bool _isDraggingOrResizing = false;

  EditorProvider? _localEditorProvider;

  @override
  void initState() {
    super.initState();
    _syncGeometryFromBlock();

    if (widget.block.type == BlockType.paragraph ||
        widget.block.type == BlockType.heading1 ||
        widget.block.type == BlockType.heading2 ||
        widget.block.type == BlockType.heading3) {
      _localEditorProvider = EditorProvider();

      String mroData = widget.block.data['mroData'] ?? '';
      if (mroData.isNotEmpty) {
        _localEditorProvider!.initialize(mroData);
      } else {
        _localEditorProvider!.initialize('');

        if (widget.block.type == BlockType.heading1) {
          _localEditorProvider!.applyFontSize(32);
        } else if (widget.block.type == BlockType.heading2) {
          _localEditorProvider!.applyFontSize(24);
        } else if (widget.block.type == BlockType.heading3) {
          _localEditorProvider!.applyFontSize(20);
        }
      }

      _localEditorProvider!.addListener(_onLocalEditorChanged);
    }
  }

  void _syncGeometryFromBlock() {
    _localX = widget.block.data['x'] ?? 50.0;
    _localY = widget.block.data['y'] ?? 50.0;
    _localW = widget.block.data['w'] ?? 300.0;
    _localH = widget.block.data['h'] ?? 150.0;
  }

  @override
  void didUpdateWidget(BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDraggingOrResizing) {
      _syncGeometryFromBlock();
    }
  }

  void _onLocalEditorChanged() {
    if (_localEditorProvider != null && _localEditorProvider!.isDirty) {
      final mroJson = _localEditorProvider!.generateMroData();
      context.read<BlockEditorProvider>().updateBlockData(widget.block.id, {
        'mroData': jsonEncode(mroJson),
      });
      _localEditorProvider!.markAsSaved();
    }
  }

  @override
  void dispose() {
    _localEditorProvider?.removeListener(_onLocalEditorChanged);
    _localEditorProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BlockEditorProvider>();
    final isFocused = provider.focusedBlockId == widget.block.id;

    return Positioned(
      left: _localX,
      top: _localY,
      width: _localW,
      height: _localH,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => provider.setFocusedBlock(widget.block.id),
          child: Container(
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.transparent,
              border: Border.all(
                color: isFocused
                    ? MostromoTheme.accentColor.withValues(alpha: 0.5)
                    : (_isHovered ? Colors.white24 : Colors.transparent),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 24.0,
                      left: 8,
                      right: 8,
                      bottom: 8,
                    ),
                    child: _buildBlockContent(context, isFocused),
                  ),
                ),

                if (_isHovered || isFocused)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 24,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: GestureDetector(
                        onPanStart: (_) {
                          provider.setFocusedBlock(widget.block.id);
                          setState(() => _isDraggingOrResizing = true);
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _localX = (_localX + details.delta.dx).clamp(
                              0.0,
                              provider.pageWidth - _localW,
                            );
                            _localY = (_localY + details.delta.dy).clamp(
                              0.0,
                              provider.pageHeight - _localH,
                            );
                          });
                        },
                        onPanEnd: (_) {
                          setState(() => _isDraggingOrResizing = false);
                          provider.updateBlockGeometry(
                            widget.block.id,
                            _localX,
                            _localY,
                            _localW,
                            _localH,
                          );
                        },
                        child: Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_isHovered || isFocused)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        onPanStart: (_) {
                          provider.setFocusedBlock(widget.block.id);
                          setState(() => _isDraggingOrResizing = true);
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _localW = (_localW + details.delta.dx).clamp(
                              100.0,
                              provider.pageWidth - _localX,
                            );
                            _localH = (_localH + details.delta.dy).clamp(
                              40.0,
                              provider.pageHeight - _localY,
                            );
                          });
                        },
                        onPanEnd: (_) {
                          setState(() => _isDraggingOrResizing = false);
                          provider.updateBlockGeometry(
                            widget.block.id,
                            _localX,
                            _localY,
                            _localW,
                            _localH,
                          );
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.signal_cellular_4_bar_rounded,
                            color: Colors.white54,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockContent(BuildContext context, bool isFocused) {
    if (_localEditorProvider != null) {
      return ChangeNotifierProvider.value(
        value: _localEditorProvider!,
        child: MostromoEditorWidget(isActive: isFocused),
      );
    } else if (widget.block.type == BlockType.divider) {
      return const Divider(color: Colors.white24, thickness: 1, height: 32);
    } else if (widget.block.type == BlockType.chart) {
      return _buildChartPlaceholder();
    }
    return const SizedBox.shrink();
  }

  Widget _buildChartPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: MostromoTheme.accentColor,
              size: 48,
            ),
            SizedBox(height: 8),
            Text('Grafik (Yakında)', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
