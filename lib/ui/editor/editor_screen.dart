import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../core/app_theme.dart';
import '../../models/note.dart';
import '../../providers/editor_provider.dart';
import '../../engine/mostromo_editor.dart';
import '../../services/local_storage_service.dart';

import 'mostromo_status_bar.dart';
import 'mostromo_title_bar.dart';
import 'editor_toolbar.dart';

class EditorScreen extends StatefulWidget {
  final MostromoNote? note;
  final bool isExternal;

  const EditorScreen({super.key, this.note, this.isExternal = false});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late String _noteId;
  String _lastSavedTitle = '';
  late bool _isReadOnly;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.isExternal;
    _noteId =
        widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _lastSavedTitle = widget.note?.title ?? '';
    _titleController = TextEditingController(text: _lastSavedTitle);

    _titleController.addListener(() {
      if (!_isReadOnly && _titleController.text != _lastSavedTitle) {
        context.read<EditorProvider>().setDirty();
      }
    });

    context.read<EditorProvider>().initialize(widget.note?.mroData ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveNoteOnly() async {
    if (_isReadOnly) return;
    final provider = context.read<EditorProvider>();
    if (!provider.isDirty && _titleController.text == _lastSavedTitle) return;

    final String serializedMro = jsonEncode(provider.generateMroData());
    final updatedNote = MostromoNote(
      id: _noteId,
      title: _titleController.text.trim().isEmpty
          ? 'İsimsiz not'
          : _titleController.text,
      mroData: serializedMro,
      lastUpdated: DateTime.now(),
    );

    await LocalStorageService.saveNote(updatedNote);
    _lastSavedTitle = updatedNote.title;
    provider.markAsSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      double screenWidth = MediaQuery.of(context).size.width;
      double leftMargin = screenWidth > 300 ? screenWidth - 250 : 24;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.greenAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kaydedildi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: MostromoTheme.surfaceColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: leftMargin, right: 24, bottom: 24),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveAndClose() {
    if (_isReadOnly) {
      Navigator.pop(context, null);
      return;
    }

    final provider = context.read<EditorProvider>();
    final String serializedMro = jsonEncode(provider.generateMroData());
    final updatedNote = MostromoNote(
      id: _noteId,
      title: _titleController.text.trim().isEmpty
          ? 'İsimsiz not'
          : _titleController.text,
      mroData: serializedMro,
      lastUpdated: DateTime.now(),
    );
    Navigator.pop(context, updatedNote);
  }

  void _importAndUnlock() {
    setState(() => _isReadOnly = false);
    _saveAndClose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 EKRAN GENİŞLİĞİNİ ÖLÇ (Telefon mu?)
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: MostromoTheme.backgroundColor,
      // 🌟 YENİ: Telefonda klavye açıldığında uygulamanın çökmesini (Overflow) engeller
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            MostromoTitleBar(
              isEditor: true,
              height: 48,
              backgroundColor: const Color(0xFF161616),
              titleController: _titleController,
              onSave: _saveNoteOnly,
              onClose: _saveAndClose,
              isExternal: _isReadOnly,
              onImport: _importAndUnlock,
            ),

            if (!_isReadOnly) const EditorToolbar(),

            Expanded(
              child: FocusScope(
                canRequestFocus: !_isReadOnly,
                child: AbsorbPointer(
                  absorbing: _isReadOnly,
                  child: MostromoEditorWidget(onSave: _saveNoteOnly),
                ),
              ),
            ),

            // 🌟 YENİ: Alt Durum çubuğu çok yer kapladığı için telefonda gizliyoruz!
            if (!isMobile) const MostromoStatusBar(),
          ],
        ),
      ),
    );
  }
}
