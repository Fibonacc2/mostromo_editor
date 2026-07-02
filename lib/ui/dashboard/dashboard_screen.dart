import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/note.dart';
import '../../services/local_storage_service.dart';
import '../../services/cloud_sync_service.dart';

import '../editor/block_editor_screen.dart';
import '../editor/editor_screen.dart';
import '../reader/offline_reader_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// 🌟 YENİ: WidgetsBindingObserver eklendi (Uygulamanın uykuya dalmasını dinlemek için)
class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isGridView = true;
  List<MostromoNote> _notes = [];

  static const platform = MethodChannel('mostromo/file_intent');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🌟 Dinleyiciyi başlat

    _loadNotesFromDisk();
    _runCloudSync();
    _listenForFileIntents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🌟 Dinleyiciyi yok et
    super.dispose();
  }

  // 🌟 YENİ: KULLANICI UYGULAMAYI ARKA PLANA ATTIĞINDA ÇALIŞIR (KATMAN 3)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
        "💤 Uygulama arka plana atıldı. Postacı (Sync) son kez çalıştırılıyor...",
      );
      CloudSyncService.syncAllNotes();
    }
  }

  Future<void> _runCloudSync() async {
    await CloudSyncService.syncAllNotes();
    if (mounted) {
      _loadNotesFromDisk();
    }
  }

  Future<void> _loadNotesFromDisk() async {
    final notes = await LocalStorageService.loadAllNotes();
    setState(() {
      _notes = notes;
    });
  }

  void _listenForFileIntents() async {
    try {
      final String? filePath = await platform.invokeMethod('getInitialFile');
      if (filePath != null && filePath.isNotEmpty) {
        _openExternalReader(filePath);
      }
    } catch (e) {
      debugPrint("Intent Başlatma Hatası: $e");
    }

    platform.setMethodCallHandler((call) async {
      if (call.method == "onFileOpened") {
        final String filePath = call.arguments;
        _openExternalReader(filePath);
      }
    });
  }

  void _openExternalReader(String filePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OfflineReaderScreen(filePath: filePath),
      ),
    );
  }

  // 🌟 GÜNCELLENDİ: ARTIK KÖRÜ KÖRÜNE YÜKLEME YOK, POSTACI ÇAĞRILIYOR
  void _handleReturnedNote(dynamic returnedNote) async {
    if (returnedNote != null && returnedNote is MostromoNote) {
      // EditorScreen zaten diske kaydetti, biz sadece listeyi yenileyip Postacıyı dürtüyoruz.
      _loadNotesFromDisk();

      // 🌟 YENİ: Sadece bu dosyayı değil, tüm sistemi akıllıca kontrol et (Hash Kalkanı vs.)
      CloudSyncService.syncAllNotes().then((_) {
        if (mounted) _loadNotesFromDisk();
      });
    } else {
      // Değişiklik yapılmadan (Sıfır yer değiştirme) dönülmüşse bile listeyi yenile
      _loadNotesFromDisk();
    }
  }

  void _openEditor(BuildContext context, [MostromoNote? existingNote]) async {
    final returnedNote = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => EditorScreen(note: existingNote)),
    );

    _handleReturnedNote(returnedNote);
  }

  void _createNewNote({required bool isBlockMode}) async {
    if (isBlockMode) {
      final returnedNote = await Navigator.of(context, rootNavigator: true)
          .push(
            MaterialPageRoute(
              builder: (context) => const BlockEditorScreen(initialData: null),
            ),
          );

      _handleReturnedNote(returnedNote);
    } else {
      _openEditor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isMobile),
            Expanded(
              child: _notes.isEmpty
                  ? const Center(
                      child: Text(
                        'Henüz buralar çok sessiz...',
                        style: TextStyle(
                          color: MostromoTheme.textMuted,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : (_isGridView
                        ? _buildGridView(isMobile)
                        : _buildListView(isMobile)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tüm Notlar',
                  style: TextStyle(
                    color: MostromoTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MostromoTheme.accentColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showNewNoteOptions(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Yeni Not',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: MostromoTheme.textSecondary,
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: MostromoTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isGridView
                                  ? Icons.view_list_rounded
                                  : Icons.grid_view_rounded,
                            ),
                            color: MostromoTheme.textPrimary,
                            onPressed: () =>
                                setState(() => _isGridView = !_isGridView),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tüm Notlar',
                  style: TextStyle(
                    color: MostromoTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MostromoTheme.accentColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showNewNoteOptions(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Yeni Not',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(
                        Icons.search_rounded,
                        color: MostromoTheme.textSecondary,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: MostromoTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isGridView
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                        ),
                        color: MostromoTheme.textPrimary,
                        onPressed: () =>
                            setState(() => _isGridView = !_isGridView),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildGridView(bool isMobile) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 8,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 200 : 320,
        mainAxisExtent: isMobile ? 160 : 190,
        crossAxisSpacing: isMobile ? 12 : 20,
        mainAxisSpacing: isMobile ? 12 : 20,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) => _buildNoteCard(_notes[index]),
    );
  }

  Widget _buildListView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 8,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) => _buildNoteListItem(_notes[index]),
    );
  }

  Widget _buildNoteCard(MostromoNote note) {
    return Card(
      color: MostromoTheme.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MostromoTheme.dividerColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(context, note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        color: MostromoTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (note.isSynced)
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: Colors.greenAccent,
                      size: 15,
                    )
                  else
                    const Icon(
                      Icons.cloud_upload_rounded,
                      color: Colors.orangeAccent,
                      size: 15,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.previewText,
                  style: const TextStyle(
                    color: MostromoTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(note.lastUpdated),
                style: const TextStyle(
                  color: MostromoTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteListItem(MostromoNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MostromoTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MostromoTheme.dividerColor),
      ),
      child: InkWell(
        onTap: () => _openEditor(context, note),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: const TextStyle(
                        color: MostromoTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.previewText,
                      style: const TextStyle(
                        color: MostromoTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (note.isSynced)
                const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.greenAccent,
                  size: 15,
                )
              else
                const Icon(
                  Icons.cloud_upload_rounded,
                  color: Colors.orangeAccent,
                  size: 15,
                ),
              const SizedBox(width: 12),
              Text(
                _formatDate(note.lastUpdated),
                style: const TextStyle(
                  color: MostromoTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewNoteOptions(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text(
          'Yeni Çalışma Alanı',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: screenWidth > 500 ? 450 : screenWidth * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNoteTypeCard(
                context,
                icon: Icons.article_outlined,
                title: 'Klasik Belge (.mro)',
                description: 'A4 formatında, satır tabanlı kelime işlemci.',
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  _createNewNote(isBlockMode: false);
                },
              ),
              const SizedBox(height: 16),
              _buildNoteTypeCard(
                context,
                icon: Icons.view_agenda_outlined,
                title: 'Özgür Defter (.mrb)',
                description: 'Sonsuz kaydırmalı, blok tabanlı modern alan.',
                color: MostromoTheme.accentColor,
                onTap: () {
                  Navigator.pop(context);
                  _createNewNote(isBlockMode: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // 🌟 YENİ: UTC'den yerel saate çevirerek ekranda göster
    final localDate = date.toLocal();
    return '${localDate.day.toString().padLeft(2, '0')}.${localDate.month.toString().padLeft(2, '0')}.${localDate.year}';
  }
}
