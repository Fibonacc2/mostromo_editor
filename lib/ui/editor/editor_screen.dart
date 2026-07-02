import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;

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

    final provider = context.read<EditorProvider>();

    _titleController.addListener(() {
      if (!_isReadOnly && _titleController.text != _lastSavedTitle) {
        provider.updateTitle(
          _titleController.text,
        ); // 🌟 DÜZELTME: Provider'a başlığı bildiriyoruz
      }
    });

    // 🌟 DÜZELTME 1: Başlığı da gönderiyoruz ki Hash Kalkanı doğru çalışsın
    provider.initialize(widget.note?.mroData ?? '', title: _lastSavedTitle);

    // 🌟 DÜZELTME 2: 2 Saniyelik Sessiz Kayıt (Debounce) Dinleyicisi
    provider.onLocalSaveTriggered = (title, mroData) async {
      if (_isReadOnly) return;

      String plainText = provider.engine.getText();
      String preview = plainText
          .substring(0, math.min(100, plainText.length))
          .replaceAll('\n', ' ');

      final updatedNote = MostromoNote(
        id: _noteId,
        title: title.trim().isEmpty ? 'İsimsiz not' : title,
        previewText: preview, // Otomatik özet metni
        mroData: mroData,
        lastUpdated: DateTime.now().toUtc(), // 🌟 UTC STANDARDINA UYULDU
        isSynced: false, // 🌟 POSTACI İÇİN İŞARETLENDİ
      );

      await LocalStorageService.saveNote(updatedNote);
      _lastSavedTitle = updatedNote.title;
      provider.markAsSaved();
      // Not: Bu arka plan (sessiz) kaydı olduğu için bilerek SnackBar göstermiyoruz, kullanıcıyı darlamasın.
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Manuel "Kaydet" butonuna basıldığında (SnackBar gösterir)
  Future<void> _saveNoteOnly() async {
    if (_isReadOnly) return;
    final provider = context.read<EditorProvider>();

    // Hash Kalkanı üzerinden manuel kaydetmeyi zorla (Bu işlem onLocalSaveTriggered'ı tetikler)
    provider.forceSave();

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

    // Değişiklik varsa son bir kez kaydet
    if (provider.isDirty || _titleController.text != _lastSavedTitle) {
      String plainText = provider.engine.getText();
      String preview = plainText
          .substring(0, math.min(100, plainText.length))
          .replaceAll('\n', ' ');

      final updatedNote = MostromoNote(
        id: _noteId,
        title: _titleController.text.trim().isEmpty
            ? 'İsimsiz not'
            : _titleController.text,
        previewText: preview,
        mroData: jsonEncode(provider.generateMroData()),
        lastUpdated: DateTime.now().toUtc(), // 🌟 UTC
        isSynced: false, // 🌟 POSTACI İÇİN
      );
      Navigator.pop(context, updatedNote);
    } else {
      // Değişiklik yoksa boş dön, Dashboard boşuna diske yazmasın
      Navigator.pop(context, null);
    }
  }

  void _importAndUnlock() {
    setState(() => _isReadOnly = false);
    _saveAndClose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      // 🌟 DÜZELTME 3: Kullanıcı Android'in "Geri" tuşuna veya ekran kaydırmasına basarsa veri kaybolmasın diye araya giriyoruz.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: MostromoTheme.backgroundColor,
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

              if (!isMobile) const MostromoStatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}
