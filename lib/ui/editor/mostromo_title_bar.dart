import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/app_theme.dart';
import '../../providers/editor_provider.dart';
import '../../providers/block_editor_provider.dart';

class MostromoTitleBar extends StatelessWidget {
  final double height;
  final Color? backgroundColor;
  final bool isEditor;
  final bool isBlockMode;
  final TextEditingController? titleController;
  final VoidCallback? onSave;
  final VoidCallback onClose;

  // 🌟 KORUMALI GÖRÜNÜM (READ-ONLY) PARAMETRELERİ
  final bool isExternal;
  final VoidCallback? onImport;

  const MostromoTitleBar({
    super.key,
    this.height = 48.0,
    this.backgroundColor,
    this.isEditor = false,
    this.isBlockMode = false,
    this.titleController,
    this.onSave,
    required this.onClose,
    this.isExternal = false,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    // 1. İŞLETİM SİSTEMİNİ KONTROL ET
    final bool isDesktopOS =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // Üst barın kendisini (Mobil veya Masaüstü) oluşturuyoruz
    Widget topBar;

    // ==========================================
    // 📱 MOBİL ARAYÜZ (Senin Orijinal Kodun)
    // ==========================================
    if (!isDesktopOS) {
      topBar = SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                // 🌟 DÜZELTME 1: Dışarıdan açıldıysa (Preview) Geri Oku değil Çarpı (X) çıkar
                icon: Icon(
                  (isExternal || !isEditor)
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: onClose,
              ),
              const Spacer(),
              if (titleController != null)
                Expanded(
                  child: Text(
                    titleController!.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 🌟 DÜZELTME 2: Mobildeki "İndir" ikonunu sildik çünkü altına Altın Şerit ekleyeceğiz
              if (!isExternal && onSave != null) _buildDynamicSaveIcon(),

              const Spacer(),
              const SizedBox(width: 48), // Başlığı ortalamak için boşluk
            ],
          ),
        ),
      );
    }
    // ==========================================
    // 🖥️ MASAÜSTÜ ARAYÜZÜ (Senin Orijinal Kodun + window_manager)
    // ==========================================
    else {
      topBar = Container(
        height: height,
        color: backgroundColor ?? MostromoTheme.backgroundColor,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(
              Icons.dashboard_rounded,
              color: MostromoTheme.accentColor,
              size: 20,
            ),
            const SizedBox(width: 16),

            if (isEditor && !isBlockMode && !isExternal) ...[
              Consumer<EditorProvider>(
                builder: (context, provider, _) => IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  color: provider.canUndo ? Colors.white : Colors.white24,
                  onPressed: provider.canUndo
                      ? () => provider.executeUndo()
                      : null,
                  tooltip: 'Geri Al (Ctrl+Z)',
                ),
              ),
              Consumer<EditorProvider>(
                builder: (context, provider, _) => IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  color: provider.canRedo ? Colors.white : Colors.white24,
                  onPressed: provider.canRedo
                      ? () => provider.executeRedo()
                      : null,
                  tooltip: 'İleri Al (Ctrl+Shift+Z)',
                ),
              ),
            ] else if (isEditor && isBlockMode && !isExternal) ...[
              const IconButton(
                icon: Icon(Icons.undo_rounded, size: 18),
                color: Colors.white24,
                onPressed: null,
              ),
              const IconButton(
                icon: Icon(Icons.redo_rounded, size: 18),
                color: Colors.white24,
                onPressed: null,
              ),
            ] else ...[
              Text(
                isExternal
                    ? 'Korumalı Görünüm (Sadece Okunur)'
                    : 'Mostromo Workspace',
                style: TextStyle(
                  color: isExternal ? Colors.orangeAccent : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],

            // 🌟 SENİN window_manager SÜRÜKLEME ALANIN
            const Expanded(child: DragToMoveArea(child: SizedBox.expand())),

            if (isEditor && titleController != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: titleController,
                      textAlign: TextAlign.center,
                      readOnly:
                          isExternal, // Dışarıdan açıldıysa başlık değiştirilemez
                      cursorColor: MostromoTheme.accentColor,
                      style: TextStyle(
                        color: isExternal ? Colors.white54 : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                        hoverColor: isExternal
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.06),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isExternal
                                ? Colors.transparent
                                : MostromoTheme.accentColor,
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 🌟 DÜZELTME 3: Çirkin butonu buradan sildik, sadece kendi dosyalarımızda Kaydet ikonunu gösteriyoruz.
                  if (!isExternal && onSave != null) _buildDynamicSaveIcon(),
                ],
              ),

            const Expanded(child: DragToMoveArea(child: SizedBox.expand())),

            // 🌟 SENİN PENCERE BUTONLARIN
            _buildWindowButton(
              Icons.minimize_rounded,
              () => windowManager.minimize(),
            ),
            _buildWindowButton(Icons.crop_square_rounded, () async {
              if (await windowManager.isMaximized())
                windowManager.unmaximize();
              else
                windowManager.maximize();
            }),
            _buildWindowButton(Icons.close_rounded, onClose, isClose: true),
          ],
        ),
      );
    }

    // ==========================================
    // 🌟 3. BİRLEŞTİRME: EĞER KORUMALI GÖRÜNÜM İSE ALTIN ŞERİDİ ALTINA EKLE
    // ==========================================
    if (!isExternal) {
      return topBar; // Kendi dosyamızsa hiçbir şey eklemeden direkt döndür
    }

    // Dışarıdan geldiyse: Orijinal barı üste, altın şeridi alta koy
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [topBar, _buildProtectedViewBanner(isMobile)],
    );
  }

  // -----------------------------------------------------------------
  // YARDIMCI WIDGET'LAR
  // -----------------------------------------------------------------

  Widget _buildDynamicSaveIcon() {
    if (isBlockMode) {
      return Consumer<BlockEditorProvider>(
        builder: (context, provider, _) => _saveIconUI(provider.isDirty),
      );
    } else {
      return Consumer<EditorProvider>(
        builder: (context, provider, _) => _saveIconUI(provider.isDirty),
      );
    }
  }

  Widget _saveIconUI(bool isDirty) {
    return Tooltip(
      message: isDirty ? 'Kaydedilmemiş Değişiklikler (Ctrl+S)' : 'Kaydedildi',
      child: InkWell(
        onTap: isDirty ? onSave : null,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            isDirty ? Icons.save_rounded : Icons.cloud_done_outlined,
            color: isDirty ? MostromoTheme.accentColor : Colors.white38,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildWindowButton(
    IconData icon,
    VoidCallback onTap, {
    bool isClose = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isClose ? Colors.redAccent : Colors.white10,
        child: Container(
          width: 46,
          height: double.infinity,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
      ),
    );
  }

  // 🌟 YENİ: EFSANEVİ ALTIN SARISI KORUMALI GÖRÜNÜM ŞERİDİ
  Widget _buildProtectedViewBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF332B00),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFFFD54F), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "KORUMALI GÖRÜNÜM",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Bu dosya salt okunur modda açıldı. Değişiklik yapmak için çalışma alanınıza kaydedin.",
                  style: TextStyle(
                    color: Colors.amber.shade100,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: isMobile ? 2 : 1,
                ),
              ],
            ),
          ),
          if (!isMobile) const SizedBox(width: 24),
          ElevatedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.edit_document, size: 16),
            label: const Text(
              "Düzenle",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
