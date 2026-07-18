import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mostromo_editor/providers/editor_provider.dart';
import 'package:mostromo_editor/ui/editor/document_outline_panel.dart';

// Klasörleri oluşturduktan sonra yolları kendine göre ayarlayabilirsin
import 'desktop/desktop_editor.dart';
import 'mobile/mobile_editor.dart';

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
      final provider = context.watch<EditorProvider>();

      return Stack(
        children: [
          // 1. ANA KATMAN: Editör ve Animasyonlu Panel
          Row(
            children: [
              // 🌟 ANİMASYONLU PANEL
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: provider.isOutlineVisible ? 250.0 : 0.0,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 250,
                    maxWidth: 250,
                    alignment: Alignment.topLeft,
                    child: const DocumentOutlinePanel(),
                  ),
                ),
              ),

              // ANA EDİTÖR GÖVDESİ
              Expanded(
                child: DesktopEditorWidget(
                  key: const ValueKey('desktop_editor'),
                  onSave: onSave,
                  isActive: isActive,
                  isReadingMode: isReadingMode,
                ),
              ),
            ],
          ),

          // 2. YÜZEY KATMANI: Yarım Oval Açma Butonu
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: provider.isOutlineVisible ? -40.0 : 0.0,
            child: const Center(
              child:
                  _OutlineToggleButton(), // 🌟 Kodu temizlemek için ayırdığımız widget
            ),
          ),
        ],
      );
    }
  }
}

// 🌟 YENİ: Hover durumunu ve renkleri if-else ile yöneten ayrı buton sınıfı
class _OutlineToggleButton extends StatefulWidget {
  const _OutlineToggleButton();

  @override
  State<_OutlineToggleButton> createState() => _OutlineToggleButtonState();
}

class _OutlineToggleButtonState extends State<_OutlineToggleButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // ? : operatörleri yerine standart if-else değişken atamaları
    Color bgColor;
    Color borderColor;
    double shadowOpacity;
    double blur;
    Color iconColor;

    if (isHovered) {
      bgColor = const Color(0xFF2C2C2C);
      borderColor = Colors.white30;
      shadowOpacity = 0.6;
      blur = 8.0;
      iconColor = Colors.white;
    } else {
      bgColor = const Color(0xFF1E1E1E);
      borderColor = Colors.white10;
      shadowOpacity = 0.4;
      blur = 6.0;
      iconColor = Colors.white70;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            isHovered = false; // Tıklanınca hover efektini kaldır
          });
          context.read<EditorProvider>().toggleOutlineVisible();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadowOpacity),
                blurRadius: blur,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.chevron_right_rounded,
              color: iconColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
