import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/editor_provider.dart';
import '../ui/editor/editor_menus.dart';

class EditorKeyboardHandler {
  static bool handle(
    KeyEvent event,
    EditorProvider provider, {
    required VoidCallback onSave,
    required VoidCallback onHideMiniToolbar,
    required VoidCallback onStartBlinking,
    required VoidCallback onResetIme,
    required VoidCallback onClearIntendedX,
    required int Function(bool isUp) onCalculateVerticalMove,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    onHideMiniToolbar();

    final logicalKey = event.logicalKey;
    final character = event.character;
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    onStartBlinking();

    if (isCtrl) {
      if (logicalKey == LogicalKeyboardKey.keyS) {
        onSave();
        return true;
      } else if (logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShift) {
          provider.executeRedo();
        } else {
          provider.executeUndo();
        }
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
    }

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
      onResetIme();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.tab) {
      provider.insertText('    ');
      return true;
    }

    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!isMobile) {
      if (logicalKey == LogicalKeyboardKey.backspace) {
        provider.deleteCharacter();
        return true;
      }
      if (logicalKey == LogicalKeyboardKey.enter) {
        provider.insertText('\n');
        return true;
      }
      if (character != null && character.isNotEmpty && !isCtrl) {
        provider.insertText(character);
        return true;
      }
    }
    return false;
  }
}
