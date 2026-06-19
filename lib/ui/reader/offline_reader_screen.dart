import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../models/note.dart';
import '../../services/local_storage_service.dart';
import '../editor/editor_screen.dart';
import '../editor/block_editor_screen.dart';

class OfflineReaderScreen extends StatefulWidget {
  final String filePath;

  const OfflineReaderScreen({super.key, required this.filePath});

  @override
  State<OfflineReaderScreen> createState() => _OfflineReaderScreenState();
}

// 🌟 YENİ: Animasyonlar için "SingleTickerProviderStateMixin" eklendi
class _OfflineReaderScreenState extends State<OfflineReaderScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';
  MostromoNote? _loadedNote;
  bool _isOurFile = false;

  // 🌟 YENİ: Nefes alma (Pulsing) efekti için animasyon kontrolcüsü
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();

    // Animasyonu başlat (1.5 saniyede bir yanıp sönecek)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _loadFile();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    if (widget.filePath.isEmpty) {
      setState(() {
        _errorMessage = "Dosya yolu bulunamadı.";
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = "Dosya fiziksel olarak mevcut değil veya silinmiş.";
          _isLoading = false;
        });
        return;
      }

      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);

      final String ext =
          json['extension'] ??
          (widget.filePath.endsWith('.mrb') ? '.mrb' : '.mro');
      final String fileId =
          json['id'] ?? 'external_${DateTime.now().millisecondsSinceEpoch}';

      _loadedNote = MostromoNote(
        id: fileId,
        title: json['title'] ?? 'Dışarıdan Gelen Not',
        previewText: json['previewText'] ?? '',
        lastUpdated: DateTime.parse(
          json['lastUpdated'] ?? DateTime.now().toIso8601String(),
        ),
        isSynced: false,
        extension: ext,
        mroData: ext == '.mro' ? jsonEncode(json['engine'] ?? {}) : '',
        mrbData: ext == '.mrb' ? jsonEncode(json['engine'] ?? []) : '',
      );

      // 🌟 YENİ: KİMLİK VE OTURUM KONTROLÜ
      final prefs = await SharedPreferences.getInstance();
      final int currentUserId = prefs.getInt('user_id') ?? 0;

      if (currentUserId == 0) {
        // 1. DURUM: Çıkış yapılmışsa, her dosya YABANCIDIR (Korumalı modda açılır)
        _isOurFile = false;
      } else {
        // 2. DURUM: Giriş yapılmışsa, dosya gerçekten bize mi ait ona bak
        final List<MostromoNote> localNotes =
            await LocalStorageService.loadAllNotes();
        _isOurFile = localNotes.any((note) => note.id == fileId);
      }

      // Dosya başarıyla okundu, aracı ekranı gizle ve doğrudan Editörü aç!
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openInEditor();
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            "Bu dosya geçerli bir Mostromo belgesi değil veya içeriği bozulmuş.";
        _isLoading = false;
      });
    }
  }

  void _openInEditor() async {
    if (_loadedNote == null) return;

    final returnedNote = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) {
          if (_loadedNote!.extension == '.mrb') {
            return BlockEditorScreen(
              note: _loadedNote,
              isExternal: !_isOurFile,
            );
          } else {
            return EditorScreen(note: _loadedNote, isExternal: !_isOurFile);
          }
        },
      ),
    );

    if (returnedNote != null && returnedNote is MostromoNote) {
      await LocalStorageService.saveNote(returnedNote);
      if (mounted) context.go('/');
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MostromoTheme.backgroundColor,
      body: Center(
        child: _isLoading
            ? _buildLoadingState() // 🌟 ŞIK YÜKLEME EKRANI
            : _errorMessage.isNotEmpty
            ? _buildErrorState(context) // 🌟 RESPONSIVE HATA EKRANI
            : const SizedBox.shrink(),
      ),
    );
  }

  // --- 1. PREMIUM YÜKLEME (SPLASH) EKRANI ---
  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _animController,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MostromoTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dashboard_rounded, // Mostromo logosunu temsil eden ikon
              color: MostromoTheme.accentColor,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Çalışma Alanı Hazırlanıyor...",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // --- 2. RESPONSIVE VE MODERN HATA KARTI ---
  Widget _buildErrorState(BuildContext context) {
    // Telefon ekranı kontrolü
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 450),
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kırmızı Hata İkonu Çerçevesi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.broken_image_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Dosya Açılamadı",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Çıkış / Kapatma Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => exit(0),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text(
                "Pencereyi Kapat",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
