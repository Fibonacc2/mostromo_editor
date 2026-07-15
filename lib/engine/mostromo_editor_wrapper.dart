import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Klasörleri oluşturduktan sonra yolları kendine göre ayarlayabilirsin
import 'desktop/desktop_editor.dart';
import 'mobile/mobile_editor.dart'; // Eski mostromo_editor.dart dosyan

class MostromoEditorWrapper extends StatelessWidget {
  final VoidCallback? onSave;
  final bool isActive;
  final bool isReadingMode;

  const MostromoEditorWrapper({
    super.key,
    this.onSave,
    this.isActive = true,
    this.isReadingMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (isMobile) {
      // 📱 DOKUNMATİK VE SANAL KLAVYE ODAKLI MOTOR
      return MobileEditorWidget(
        onSave: onSave,
        isActive: isActive,
        isReadingMode: isReadingMode,
      );
    } else {
      // 💻 FARE VE FİZİKSEL KLAVYE ODAKLI MOTOR
      return DesktopEditorWidget(
        onSave: onSave,
        isActive: isActive,
        isReadingMode: isReadingMode,
      );
    }
  }
}
