import 'package:flutter/material.dart';
import 'package:mostromo_editor/core/app_theme.dart';
import 'package:mostromo_editor/providers/editor_provider.dart';
import 'package:mostromo_editor/ui/editor/color_picker_dialog.dart';
import 'package:provider/provider.dart';

class MobileEditorToolbar extends StatelessWidget {
  const MobileEditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    // Klavyenin açık olup olmadığını kontrol ediyoruz
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: 52, // Mobil baş parmak erişimi için ideal yükseklik
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      // Eğer padding eklemek istersen iPhone çentiği gibi alt boşlukları yönetebiliriz
      padding: EdgeInsets.only(
        bottom: bottomInset == 0 ? MediaQuery.of(context).padding.bottom : 0,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _buildIconBtn(
            icon: Icons.format_bold_rounded,
            isActive: provider.isBold,
            onTap: () => provider.toggleBold(),
          ),
          _buildIconBtn(
            icon: Icons.format_italic_rounded,
            isActive: provider.isItalic,
            onTap: () => provider.toggleItalic(),
          ),
          _buildIconBtn(
            icon: Icons.format_underline_rounded,
            isActive: provider.isUnderline,
            onTap: () => provider.toggleUnderline(),
          ),
          _buildDivider(),
          _buildHeadingCycle(provider),
          _buildDivider(),
          _buildColorPicker(context, provider),
          _buildHighlightPicker(context, provider),
          _buildDivider(),
          _buildAlignCycle(provider),
          _buildDivider(),
          _buildIconBtn(
            icon: Icons.undo_rounded,
            isActive: false,
            onTap: provider.canUndo ? () => provider.executeUndo() : null,
            isDisabled: !provider.canUndo,
          ),
          _buildIconBtn(
            icon: Icons.redo_rounded,
            isActive: false,
            onTap: provider.canRedo ? () => provider.executeRedo() : null,
            isDisabled: !provider.canRedo,
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required bool isActive,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? MostromoTheme.accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: MostromoTheme.accentColor.withValues(alpha: 0.5),
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isDisabled
                ? Colors.white24
                : (isActive ? MostromoTheme.accentColor : Colors.white70),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      color: Colors.white12,
    );
  }

  // Başlıklar arası geçiş (Aa -> H1 -> H2 -> H3)
  Widget _buildHeadingCycle(EditorProvider provider) {
    int level = provider.currentHeadingLevel;
    String text = level == 0 ? 'Aa' : 'H$level';
    bool isActive = level > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          int nextLevel = (level + 1) % 4; // 0, 1, 2, 3 döngüsü
          provider.applyHeading(nextLevel);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? MostromoTheme.accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: MostromoTheme.accentColor.withValues(alpha: 0.5),
                  )
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? MostromoTheme.accentColor : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // Hizalama arası geçiş (Sol -> Orta -> Sağ -> Yasla)
  Widget _buildAlignCycle(EditorProvider provider) {
    IconData icon = Icons.format_align_left_rounded;
    if (provider.currentTextAlign == TextAlign.center)
      icon = Icons.format_align_center_rounded;
    if (provider.currentTextAlign == TextAlign.right)
      icon = Icons.format_align_right_rounded;
    if (provider.currentTextAlign == TextAlign.justify)
      icon = Icons.format_align_justify_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          TextAlign nextAlign = TextAlign.left;
          if (provider.currentTextAlign == TextAlign.left)
            nextAlign = TextAlign.center;
          else if (provider.currentTextAlign == TextAlign.center)
            nextAlign = TextAlign.right;
          else if (provider.currentTextAlign == TextAlign.right)
            nextAlign = TextAlign.justify;

          provider.applyTextAlign(nextAlign);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context, EditorProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => MostromoColorPickerDialog(
              title: 'Metin Rengi',
              initialColor: provider.currentColor ?? Colors.white,
              isBackground: false,
              onColorApplied: (color) {
                provider.setTextColor(color ?? Colors.white);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.format_color_text_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(height: 3),
              Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: provider.currentColor ?? Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightPicker(BuildContext context, EditorProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => MostromoColorPickerDialog(
              title: 'Arka Plan Rengi',
              initialColor: provider.currentBackgroundColor ?? Colors.yellow,
              isBackground: true,
              onColorApplied: (color) {
                provider.setHighlightColor(color);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: provider.currentBackgroundColor != null
                ? provider.currentBackgroundColor!.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: provider.currentBackgroundColor != null
                ? Border.all(
                    color: provider.currentBackgroundColor!.withValues(
                      alpha: 0.5,
                    ),
                  )
                : null,
          ),
          child: Icon(
            Icons.border_color_rounded,
            size: 18,
            color: provider.currentBackgroundColor ?? Colors.white70,
          ),
        ),
      ),
    );
  }
}
