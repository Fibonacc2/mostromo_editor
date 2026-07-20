import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/editor_provider.dart';
import '../../core/app_theme.dart';

class EditorMenus {
  // =========================================================================
  // 🌟 MİNİ ARAÇ ÇUBUĞU (YÜZEN TASARIM)
  // =========================================================================
  static OverlayEntry showMiniToolbar(
    BuildContext context,
    Offset globalPos,
    EditorProvider provider,
    VoidCallback hideSelf,
  ) {
    double top = globalPos.dy - 65;
    if (top < 0) top = globalPos.dy + 25;
    double left = globalPos.dx - 60;
    if (left < 0) left = 10;

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: top,
          left: left,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniToolbarIcon(
                    Icons.format_bold_rounded,
                    provider.isBold,
                    () {
                      provider.toggleBold();
                      hideSelf();
                    },
                  ),
                  _miniToolbarIcon(
                    Icons.format_italic_rounded,
                    provider.isItalic,
                    () {
                      provider.toggleItalic();
                      hideSelf();
                    },
                  ),
                  _miniToolbarIcon(
                    Icons.format_underlined_rounded,
                    provider.isUnderline,
                    () {
                      provider.toggleUnderline();
                      hideSelf();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(entry);
    return entry;
  }

  static Widget _miniToolbarIcon(
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? MostromoTheme.accentColor.withValues(alpha: 0.2)
                    : (isHovered ? Colors.white10 : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? MostromoTheme.accentColor
                    : (isHovered ? Colors.white : Colors.white70),
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 🌟 SAĞ TIK VE UZUN BASMA MENÜLERİ (CONTEXT MENUS)
  // =========================================================================
  static PopupMenuEntry<String> _buildSleekMenuItem(
    String value,
    IconData icon,
    String text,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 34,
      padding: EdgeInsets.zero,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: Container(
              width: double.infinity,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isHovered
                    ? MostromoTheme.accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isHovered
                        ? MostromoTheme.accentColor
                        : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      color: isHovered
                          ? MostromoTheme.accentColor
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> showMobileContextMenu(
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
      color: const Color(0xFF1A1A1A),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      items: [
        if (provider.hasSelection)
          _buildSleekMenuItem('cut', Icons.cut_rounded, 'Kes'),
        if (provider.hasSelection)
          _buildSleekMenuItem('copy', Icons.copy_rounded, 'Kopyala'),
        _buildSleekMenuItem('paste', Icons.paste_rounded, 'Yapıştır'),
        const PopupMenuDivider(height: 8),
        _buildSleekMenuItem(
          'select_all',
          Icons.select_all_rounded,
          'Tümünü Seç',
        ),

        if (provider.hasSelection) const PopupMenuDivider(height: 8),
        if (provider.hasSelection)
          _buildSleekMenuItem('bold', Icons.format_bold_rounded, 'Kalın Yap'),
        if (provider.hasSelection)
          _buildSleekMenuItem(
            'italic',
            Icons.format_italic_rounded,
            'İtalik Yap',
          ),
      ],
    );

    _processMenuSelection(value, provider);
  }

  static Future<void> showDesktopContextMenu(
    BuildContext context,
    Offset globalPosition,
    EditorProvider provider,
    VoidCallback hideMiniToolbar,
  ) async {
    hideMiniToolbar();

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: const Color(0xFF1A1A1A),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      items: [
        if (provider.hasSelection)
          _buildSleekMenuItem('cut', Icons.cut_rounded, 'Kes'),
        if (provider.hasSelection)
          _buildSleekMenuItem('copy', Icons.copy_rounded, 'Kopyala'),
        _buildSleekMenuItem('paste', Icons.paste_rounded, 'Yapıştır'),
        const PopupMenuDivider(height: 8),
        _buildSleekMenuItem(
          'select_all',
          Icons.select_all_rounded,
          'Tümünü Seç',
        ),

        if (provider.hasSelection) const PopupMenuDivider(height: 8),
        if (provider.hasSelection)
          _buildSleekMenuItem('bold', Icons.format_bold_rounded, 'Kalın Yap'),
        if (provider.hasSelection)
          _buildSleekMenuItem(
            'italic',
            Icons.format_italic_rounded,
            'İtalik Yap',
          ),
        if (provider.hasSelection)
          _buildSleekMenuItem(
            'underline',
            Icons.format_underlined_rounded,
            'Altı Çizili Yap',
          ),
      ],
    );

    _processMenuSelection(value, provider);
  }

  static void _processMenuSelection(String? value, EditorProvider provider) {
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
      pasteFromClipboard(provider);
    } else if (value == 'select_all') {
      provider.updateSelection(provider.engine.getText().length, 0);
    } else if (value == 'bold') {
      provider.toggleBold();
    } else if (value == 'italic') {
      provider.toggleItalic();
    } else if (value == 'underline') {
      provider.toggleUnderline();
    }
  }

  static Future<void> pasteFromClipboard(EditorProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      provider.insertText(data.text!);
    }
  }

  // 🌟 YENİ: Arama Çubuğu Overlay Bileşeni
  static OverlayEntry? _findBarEntry;
  static bool isFindBarOpen() => _findBarEntry != null;

  // 🌟 YENİ: Arama çubuğunu kapat (ESC veya harici çağrı için)
  static void closeFindBar(BuildContext context) {
    if (_findBarEntry != null) {
      _findBarEntry!.remove();
      _findBarEntry = null;
      // Provider'ı bul ve arama vurgularını temizle
      try {
        final provider = Provider.of<EditorProvider>(context, listen: false);
        provider.clearSearch();
      } catch (e) {
        // Eğer context geçerli değilse sessiz geç
      }
    }
  }

  // lib/ui/editor/editor_menus.dart

  static void toggleFindBar(
    BuildContext context,
    EditorProvider provider,
    VoidCallback hideContextMenu,
  ) {
    hideContextMenu();

    if (_findBarEntry != null) {
      closeFindBar(context);
      return;
    }

    final TextEditingController searchCtrl = TextEditingController(
      text: provider.currentSearchQuery,
    );
    final TextEditingController replaceCtrl = TextEditingController();
    final FocusNode focusNode = FocusNode(
      onKey: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          closeFindBar(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );

    // Replace butonuna basıldığında ikinci satırı göster/gizle
    ValueNotifier<bool> showReplace = ValueNotifier<bool>(false);

    _findBarEntry = OverlayEntry(
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Positioned(
              top: 60,
              right: 48,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 480, // Biraz genişlettik
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MostromoTheme.accentColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- 1. SATIR: Arama ---
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              focusNode: focusNode,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Belgede ara...',
                                hintStyle: TextStyle(color: Colors.white54),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) => provider.findText(val),
                              onSubmitted: (_) => provider.findNext(),
                            ),
                          ),

                          // Eşleşme Sayacı
                          ListenableBuilder(
                            listenable: provider,
                            builder: (context, _) {
                              int count = provider.searchMatches.length;
                              int current = count > 0
                                  ? provider.currentSearchMatchIndex + 1
                                  : 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  count > 0 ? '$current/$count' : '0/0',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Case Sensitive
                          ListenableBuilder(
                            listenable: provider,
                            builder: (context, _) {
                              return IconButton(
                                icon: const Icon(Icons.text_fields, size: 18),
                                color: provider.isCaseSensitive
                                    ? MostromoTheme.accentColor
                                    : Colors.white54,
                                onPressed: provider.toggleCaseSensitive,
                                tooltip: 'Büyük/Küçük Harf Duyarlılığı',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              );
                            },
                          ),

                          // Whole Word
                          ListenableBuilder(
                            listenable: provider,
                            builder: (context, _) {
                              return IconButton(
                                icon: const Icon(Icons.abc, size: 18),
                                color: provider.isWholeWord
                                    ? MostromoTheme.accentColor
                                    : Colors.white54,
                                onPressed: provider.toggleWholeWord,
                                tooltip: 'Tam Kelime Eşleşmesi',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              );
                            },
                          ),

                          // Önceki / Sonraki
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => provider.findPrevious(),
                            tooltip: 'Önceki Eşleşme',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => provider.findNext(),
                            tooltip: 'Sonraki Eşleşme',
                          ),

                          // 🌟 REPLACE BUTONU (Toggle)
                          IconButton(
                            icon: const Icon(Icons.repeat, size: 18),
                            color: showReplace.value
                                ? MostromoTheme.accentColor
                                : Colors.white54,
                            onPressed: () {
                              showReplace.value = !showReplace.value;
                              setState(() {});
                            },
                            tooltip: 'Değiştir',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),

                          // Kapat
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => closeFindBar(ctx),
                          ),
                        ],
                      ),

                      // --- 2. SATIR: Değiştir (showReplace true ise) ---
                      if (showReplace.value) ...[
                        const Divider(height: 8, color: Colors.white24),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: replaceCtrl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Değiştirilecek metin...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) {
                                  // Enter'a basınca değiştir
                                  if (replaceCtrl.text.isNotEmpty) {
                                    provider.replaceCurrentMatch(
                                      replaceCtrl.text,
                                    );
                                  }
                                },
                              ),
                            ),
                            // "Değiştir" Butonu
                            ListenableBuilder(
                              listenable: provider,
                              builder: (context, _) {
                                bool hasMatch =
                                    provider.searchMatches.isNotEmpty;
                                return ElevatedButton(
                                  onPressed:
                                      hasMatch && replaceCtrl.text.isNotEmpty
                                      ? () {
                                          provider.replaceCurrentMatch(
                                            replaceCtrl.text,
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MostromoTheme.accentColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text('Değiştir'),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // "Tümünü Değiştir" Butonu
                            ListenableBuilder(
                              listenable: provider,
                              builder: (context, _) {
                                bool hasMatch =
                                    provider.searchMatches.isNotEmpty;
                                return OutlinedButton(
                                  onPressed:
                                      hasMatch && replaceCtrl.text.isNotEmpty
                                      ? () {
                                          provider.replaceAllMatches(
                                            replaceCtrl.text,
                                          );
                                        }
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text('Tümünü Değiştir'),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_findBarEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }
}
