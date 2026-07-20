import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../../providers/editor_provider.dart';
import '../../ui/editor/editor_menus.dart';

class DesktopKeyboardHandler {
  static bool handle(
    KeyEvent event,
    EditorProvider provider,
    BuildContext context, {
    required VoidCallback onSave,
    required VoidCallback onHideMiniToolbar,
    required VoidCallback onStartBlinking,
    required VoidCallback onClearIntendedX,
    required int Function(bool isUp) onCalculateVerticalMove,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    onHideMiniToolbar();
    onStartBlinking();

    final logicalKey = event.logicalKey;
    final character = event.character;

    // 🌟 OPTİMİZASYON 2: Doğrudan donanımdan (HardwareKeyboard) Ctrl/Shift durumunu çek
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // ==========================================
    // 1. KISAYOLLAR (CTRL / CMD KOMUTLARI)
    // ==========================================
    if (isCtrl) {
      if (logicalKey == LogicalKeyboardKey.keyS) {
        onSave();
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyF) {
        // 🌟 EKLENDİ: Ctrl+F ile Arama Çubuğunu Aç
        EditorMenus.toggleFindBar(context, provider, onHideMiniToolbar);
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyZ) {
        isShift ? provider.executeRedo() : provider.executeUndo();
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyY) {
        provider.executeRedo();
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyA) {
        provider.updateSelection(provider.engine.getText().length, 0);
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyC) {
        if (provider.hasSelection) {
          final start = math.min(provider.selectionBase!, provider.cursorIndex);
          final end = math.max(provider.selectionBase!, provider.cursorIndex);
          Clipboard.setData(
            ClipboardData(
              text: provider.engine.getText().substring(start, end),
            ),
          );
        }
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyX) {
        if (provider.hasSelection) {
          final start = math.min(provider.selectionBase!, provider.cursorIndex);
          final end = math.max(provider.selectionBase!, provider.cursorIndex);
          Clipboard.setData(
            ClipboardData(
              text: provider.engine.getText().substring(start, end),
            ),
          );
          provider.deleteSelection();
        }
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyV) {
        EditorMenus.pasteFromClipboard(provider);
        return true;
      }
      return true;
    }

    // ==========================================
    // 2. YÖN TUŞLARI VE KESKİN METİN SEÇİMİ
    // ==========================================
    if (logicalKey == LogicalKeyboardKey.arrowLeft ||
        logicalKey == LogicalKeyboardKey.arrowRight ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowDown) {
      int? newBase = isShift
          ? (provider.selectionBase ?? provider.cursorIndex)
          : null;
      int newCursor = provider.cursorIndex;

      if (logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (newCursor > 0) newCursor--;
        onClearIntendedX();
      } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
        if (newCursor < provider.engine.getText().length) newCursor++;
        onClearIntendedX();
      } else {
        newCursor = onCalculateVerticalMove(
          logicalKey == LogicalKeyboardKey.arrowUp,
        );
      }

      provider.updateSelection(newCursor, newBase);
      return true;
    }

    // ==========================================
    // 3. EYLEM TUŞLARI
    // ==========================================
    if (logicalKey == LogicalKeyboardKey.backspace) {
      provider.deleteCharacter();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      provider.insertText('\n');
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.tab) {
      provider.insertText('    ');
      return true;
    }

    // ==========================================
    // 4. SAF KARAKTER YAZIMI (BYPASS OS IME)
    // ==========================================
    if (character != null && character.isNotEmpty) {
      provider.insertText(character);
      return true;
    }

    return false;
  }
}
