import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}
