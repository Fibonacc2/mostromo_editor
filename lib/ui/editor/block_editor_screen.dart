import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../engine/block_engine/mostromo_block.dart';
import '../../providers/block_editor_provider.dart';
import '../../models/note.dart';

import 'mostromo_title_bar.dart';
import 'block_widget.dart';

class BlockEditorScreen extends StatefulWidget {
  final MostromoNote? note;
  final String? initialData;
  final bool isExternal;

  const BlockEditorScreen({
    super.key,
    this.note,
    this.initialData,
    this.isExternal = false,
  });

  @override
  State<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<BlockEditorScreen> {
  late TextEditingController _titleController;
  late bool _isReadOnly;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.isExternal;
    _titleController = TextEditingController(
      text: widget.note?.title ?? "İsimsiz Defter",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = widget.note?.mrbData ?? widget.initialData ?? '';
      context.read<BlockEditorProvider>().initialize(data);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    if (_isReadOnly) {
      Navigator.pop(context, null);
      return;
    }

    final String serializedMrb = context
        .read<BlockEditorProvider>()
        .generateMrbData();

    final updatedNote = MostromoNote(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim().isEmpty
          ? 'İsimsiz Defter'
          : _titleController.text,
      previewText: 'Özgür Tuval Çalışması',
      lastUpdated: DateTime.now(),
      extension: '.mrb',
      mrbData: serializedMrb,
    );

    Navigator.pop(context, updatedNote);
  }

  void _importAndUnlock() {
    setState(() => _isReadOnly = false);
    _saveAndClose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BlockEditorProvider>();
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: MostromoTheme.backgroundColor,
      // 🌟 YENİ: Mobilde klavye taşmasını engeller
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            MostromoTitleBar(
              height: 48,
              backgroundColor: const Color(0xFF161616),
              isEditor: true,
              isBlockMode: true,
              titleController: _titleController,
              onClose: _saveAndClose,
              isExternal: _isReadOnly,
              onImport: _importAndUnlock,
            ),

            Expanded(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.1,
                maxScale: 4.0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_isReadOnly) return;
                      provider.setFocusedBlock(null);
                      FocusScope.of(context).unfocus();
                    },
                    child: Container(
                      margin: EdgeInsets.all(
                        isMobile ? 16 : 64,
                      ), // Mobilde karanlık masayı daralt
                      width: provider.pageWidth,
                      height: provider.pageHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: AbsorbPointer(
                        absorbing: _isReadOnly,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: provider.blocks.map((block) {
                            return BlockWidget(
                              key: ValueKey(block.id),
                              block: block,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (!_isReadOnly) _buildBottomToolbar(provider, isMobile),
          ],
        ),
      ),
    );
  }

  // 🌟 YENİ: Mobilde Taşan Menüyü Kaydırılabilir Yaptık
  Widget _buildBottomToolbar(BlockEditorProvider provider, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      // 🌟 YATAY KAYDIRMA SİHRİ BURADA:
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Blok Ekle:',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(width: 16),
            _buildAddButton(
              Icons.text_fields,
              'Metin',
              () => provider.addBlock(BlockType.paragraph),
            ),
            _buildAddButton(
              Icons.title,
              'Başlık 1',
              () => provider.addBlock(BlockType.heading1),
            ),
            _buildAddButton(
              Icons.horizontal_rule,
              'Ayırıcı',
              () => provider.addBlock(BlockType.divider),
            ),
            _buildAddButton(
              Icons.bar_chart,
              'Grafik',
              () => provider.addBlock(BlockType.chart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: MostromoTheme.accentColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}
