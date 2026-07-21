import 'package:flutter/material.dart';
import 'package:mostromo_editor/ui/editor/color_picker_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/editor_provider.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(
          0xFF1E1E1E,
        ), // Eski temanın rengi korunarak daha koyu bir arka plan
        border: Border(
          bottom: BorderSide(color: MostromoTheme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kısım: SEKME BAŞLIKLARI (RIBBON TABS)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 8, top: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TabHeader(
                    title: 'Giriş',
                    isActive: provider.activeTab == 0,
                    onTap: () => provider.setActiveTab(0),
                  ),
                  _TabHeader(
                    title: 'Ekle',
                    isActive: provider.activeTab == 1,
                    onTap: () => provider.setActiveTab(1),
                  ),
                  _TabHeader(
                    title: 'Düzen',
                    isActive: provider.activeTab == 2,
                    onTap: () => provider.setActiveTab(2),
                  ),
                ],
              ),
            ),
          ),

          // 2. Kısım: SEKME İÇERİĞİ (RIBBON CONTENT)
          Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF1A1A1A), // İçeriğin hafif farklı tonu
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildTabContent(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, EditorProvider provider) {
    switch (provider.activeTab) {
      case 0:
        return _buildHomeTab(context, provider);
      case 1:
        return _buildInsertTab(context, provider);
      case 2:
        return _buildLayoutTab(context, provider);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // SEKME 1: GİRİŞ (Metin Biçimlendirme)
  // ==========================================
  Widget _buildHomeTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_home'),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFontFamilyDropdown(context, provider),
            const SizedBox(width: 8),
            _buildFontSizeDropdown(provider),

            _buildDivider(),

            _ToolbarButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Kalın (Ctrl+B)',
              isActive: provider.isBold,
              onPressed: provider.toggleBold,
            ),
            _ToolbarButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'İtalik (Ctrl+I)',
              isActive: provider.isItalic,
              onPressed: provider.toggleItalic,
            ),
            _ToolbarButton(
              icon: Icons.format_underline_rounded,
              tooltip: 'Altı Çizili (Ctrl+U)',
              isActive: provider.isUnderline,
              onPressed: provider.toggleUnderline,
            ),

            _buildDivider(),

            // 🌟 ÇÖZÜLEN KISIM: Başlık aktifse, tekrar basınca '0' (Normal Metin) göndersin.
            _ToolbarButton(
              icon: Icons.looks_one_rounded,
              tooltip: 'Başlık 1',
              isActive: provider.currentHeadingLevel == 1,
              onPressed: () => provider.applyHeading(
                provider.currentHeadingLevel == 1 ? 0 : 1,
              ),
            ),
            _ToolbarButton(
              icon: Icons.looks_two_rounded,
              tooltip: 'Başlık 2',
              isActive: provider.currentHeadingLevel == 2,
              onPressed: () => provider.applyHeading(
                provider.currentHeadingLevel == 2 ? 0 : 2,
              ),
            ),
            _ToolbarButton(
              icon: Icons.looks_3_rounded,
              tooltip: 'Başlık 3',
              isActive: provider.currentHeadingLevel == 3,
              onPressed: () => provider.applyHeading(
                provider.currentHeadingLevel == 3 ? 0 : 3,
              ),
            ),

            _buildDivider(),

            _buildColorPicker(context, provider),
            const SizedBox(width: 8), // Boşluk
            _buildHighlightPicker(context, provider), // 🌟 YENİ EKLENDİ
            _buildDivider(), // _buildHomeTab içine:
            _buildDivider(),
            _ToolbarButton(
              icon: Icons.format_align_left_rounded,
              tooltip: 'Sola Yasla',
              isActive: provider.currentTextAlign == TextAlign.left,
              onPressed: () => provider.applyTextAlign(TextAlign.left),
            ),
            _ToolbarButton(
              icon: Icons.format_align_center_rounded,
              tooltip: 'Ortala',
              isActive: provider.currentTextAlign == TextAlign.center,
              onPressed: () => provider.applyTextAlign(TextAlign.center),
            ),
            _ToolbarButton(
              icon: Icons.format_align_right_rounded,
              tooltip: 'Sağa Yasla',
              isActive: provider.currentTextAlign == TextAlign.right,
              onPressed: () => provider.applyTextAlign(TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SEKME 2: EKLE (Resim, Tablo, Link)
  // ==========================================
  Widget _buildInsertTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_insert'),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ToolbarButton(
              icon: Icons.image_outlined,
              tooltip: 'Resim Ekle',
              isActive: false,
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Resim motoru yapım aşamasında.'),
                  ),
                );
              },
            ),
            _ToolbarButton(
              icon: Icons.table_chart_outlined,
              tooltip: 'Tablo',
              isActive: false,
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tablo sistemi yakında eklenecek.'),
                  ),
                );
              },
            ),

            _buildDivider(),

            _ToolbarButton(
              icon: Icons.link_rounded,
              tooltip: 'Bağlantı (Link) Ekle',
              isActive: provider.currentLinkUrl != null,
              onPressed: () => _showLinkDialog(context, provider),
            ),
            _ToolbarButton(
              icon: Icons.horizontal_rule_rounded,
              tooltip: 'Ayırıcı Çizgi Ekle',
              isActive: false,
              onPressed: () => provider.insertDivider(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SEKME 3: DÜZEN (Sayfa Yapısı)
  // ==========================================
  Widget _buildLayoutTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_layout'),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ToolbarButton(
              icon: provider.isPageMode
                  ? Icons.fit_screen_rounded
                  : Icons.fullscreen_rounded,
              tooltip: provider.isPageMode
                  ? 'Tam Ekran Modu'
                  : 'Sayfa (A4) Modu',
              isActive: provider.isPageMode,
              onPressed: provider.togglePageMode,
            ),

            _buildDivider(),

            _ToolbarButton(
              icon: Icons.settings_overscan_rounded,
              tooltip: 'Sayfa Kenarlıkları',
              isActive: false,
              onPressed: () => _showMarginDialog(context, provider),
            ),
            _buildDivider(),
            _ToolbarButton(
              icon: Icons.list_alt,
              isActive: provider.isOutlineVisible,
              tooltip: 'İçindekiler Panelini Aç/Kapat',
              onPressed: () {
                context.read<EditorProvider>().toggleOutlineVisible();
              },
            ),

            _buildDivider(),

            _ToolbarButton(
              icon: Icons.settings_overscan_rounded,
              tooltip: 'Sayfa Kenarlıkları',
              isActive: false,
              onPressed: () => _showMarginDialog(context, provider),
            ),
            _buildDivider(), // 🌟 Araya ayırıcı çizgi
            // 🌟 YENİ: SAYFA NUMARASI BUTONU
            _ToolbarButton(
              icon: Icons.numbers_rounded,
              tooltip: 'Sayfa Numaraları',
              isActive: provider.showPageNumbers,
              onPressed: () => _showPageNumberDialog(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  // --- KOMPONENTLER ---

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: MostromoTheme.dividerColor,
    );
  }

  Widget _buildFontFamilyDropdown(
    BuildContext context,
    EditorProvider provider,
  ) {
    final currentFont = provider.currentFontFamily ?? 'Sistem Varsayılanı';

    return PopupMenuButton<String>(
      tooltip: 'Yazı Tipi (Font)',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (font) {
        if (font == 'UPLOAD_NEW_FONT') {
          provider.pickAndLoadCustomFont(context);
        } else {
          provider.applyFontFamily(font);
        }
      },
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [];
        for (String font in provider.loadedFonts) {
          items.add(
            PopupMenuItem<String>(
              value: font,
              height: 36,
              child: Text(
                font,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: font == 'Sistem Varsayılanı' ? null : font,
                ),
              ),
            ),
          );
        }
        items.add(const PopupMenuDivider());
        items.add(
          const PopupMenuItem<String>(
            value: 'UPLOAD_NEW_FONT',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: MostromoTheme.accentColor,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  "Özel Font Yükle (.ttf)",
                  style: TextStyle(
                    color: MostromoTheme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
        return items;
      },
      child: Container(
        width: 140,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                currentFont,
                style: TextStyle(
                  color: MostromoTheme.textPrimary,
                  fontSize: 13,
                  fontFamily: currentFont == 'Sistem Varsayılanı'
                      ? null
                      : currentFont,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: MostromoTheme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeDropdown(EditorProvider provider) {
    return PopupMenuButton<double>(
      initialValue: provider.currentFontSize ?? 16.0,
      tooltip: 'Font Boyutu',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (size) => provider.applyFontSize(size),
      itemBuilder: (context) =>
          [12, 14, 16, 18, 20, 24, 28, 32, 48, 64].map((size) {
            return PopupMenuItem<double>(
              value: size.toDouble(),
              height: 36,
              child: Text(
                size.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
      child: Container(
        width: 60,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              provider.currentFontSize?.toInt().toString() ?? '-',
              style: const TextStyle(
                color: MostromoTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: MostromoTheme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 YENİ: Görsel Sayfa Numarası Ayar Menüsü
  void _showPageNumberDialog(BuildContext context, EditorProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Sayfa Numaraları',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text(
                    'Numaraları Göster',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: provider.showPageNumbers,
                  activeColor: MostromoTheme.accentColor,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    provider.togglePageNumbers();
                    setState(() {}); // Diyalog içindeki UI'ı yenile
                  },
                ),
                if (provider.showPageNumbers) ...[
                  const Divider(color: Colors.white10, height: 24),
                  const Text(
                    "Konum Seçin",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),

                  // 🌟 İNTERAKTİF A4 ŞABLONU
                  Center(
                    child: Container(
                      width: 140,
                      height: 198, // A4 Kağıdı oranı
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white24, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // İçerikteki sahte (dummy) çizgiler
                          Center(
                            child: Container(
                              width: 80,
                              height: 120,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  6,
                                  (index) => Container(
                                    height: 2,
                                    width: 60,
                                    color: Colors.white10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Etkileşimli Köşeler
                          _buildAlignDot(provider, Alignment.topLeft, setState),
                          _buildAlignDot(
                            provider,
                            Alignment.topCenter,
                            setState,
                          ),
                          _buildAlignDot(
                            provider,
                            Alignment.topRight,
                            setState,
                          ),
                          _buildAlignDot(
                            provider,
                            Alignment.bottomLeft,
                            setState,
                          ),
                          _buildAlignDot(
                            provider,
                            Alignment.bottomCenter,
                            setState,
                          ),
                          _buildAlignDot(
                            provider,
                            Alignment.bottomRight,
                            setState,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlignDot(
    EditorProvider provider,
    Alignment align,
    void Function(void Function()) setState,
  ) {
    final bool isSelected = provider.pageNumberAlignment == align;
    return Align(
      alignment: align,
      child: GestureDetector(
        onTap: () {
          provider.setPageNumberAlignment(align);
          setState(() {}); // Anlık olarak tıklanan noktayı parlatır
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? MostromoTheme.accentColor
                : const Color(0xFF161616),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white38,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: MostromoTheme.accentColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.numbers_rounded, size: 14, color: Colors.black)
              : null,
        ),
      ),
    );
  }

  // --- GÜNCEL: Metin Rengi Seçici Butonu ---
  Widget _buildColorPicker(BuildContext context, EditorProvider provider) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MostromoColorPickerDialog(
            title: 'Metin Rengi',
            initialColor: provider.currentColor ?? Colors.white,
            isBackground: false,
            onColorApplied: (color) {
              // Eğer temizle dendiyse varsayılan olarak beyaza (veya siyah) döndür
              if (color == null) {
                provider.setTextColor(Colors.white);
              } else {
                provider.setTextColor(color);
              }
            },
          ),
        );
      },
      child: Tooltip(
        message: 'Metin Rengi',
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.format_color_text,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: provider.currentColor ?? Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- GÜNCEL: Fosforlu Kalem Seçici Butonu ---
  Widget _buildHighlightPicker(BuildContext context, EditorProvider provider) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MostromoColorPickerDialog(
            title: 'Arka Plan Rengi',
            initialColor: provider.currentBackgroundColor ?? Colors.yellow,
            isBackground: true,
            onColorApplied: (color) {
              provider.setHighlightColor(
                color,
              ); // Null gelirse fosforu temizler
            },
          ),
        );
      },
      child: Tooltip(
        message: 'Metin Vurgu Rengi',
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: provider.currentBackgroundColor != null
                ? provider.currentBackgroundColor!.withValues(alpha: 0.2)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: provider.currentBackgroundColor ?? Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.border_color,
                size: 16,
                color: provider.currentBackgroundColor ?? Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarginDialog(BuildContext context, EditorProvider provider) {
    final topCtrl = TextEditingController(
      text: provider.marginTop.toInt().toString(),
    );
    final botCtrl = TextEditingController(
      text: provider.marginBottom.toInt().toString(),
    );
    final leftCtrl = TextEditingController(
      text: provider.marginLeft.toInt().toString(),
    );
    final rightCtrl = TextEditingController(
      text: provider.marginRight.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Kenarlıklar (Piksel)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMarginInput('Üst Boşluk', topCtrl),
            _buildMarginInput('Alt Boşluk', botCtrl),
            _buildMarginInput('Sol Boşluk', leftCtrl),
            _buildMarginInput('Sağ Boşluk', rightCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MostromoTheme.accentColor,
            ),
            onPressed: () {
              provider.updateMargins(
                top: double.tryParse(topCtrl.text),
                bottom: double.tryParse(botCtrl.text),
                left: double.tryParse(leftCtrl.text),
                right: double.tryParse(rightCtrl.text),
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Uygula',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 70,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkDialog(BuildContext context, EditorProvider provider) {
    if (!provider.hasSelection && provider.currentLinkUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı eklemek için önce metin seçmelisiniz.'),
        ),
      );
      return;
    }

    final urlCtrl = TextEditingController(
      text: provider.currentLinkUrl ?? 'https://',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Bağlantı (URL)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.blueAccent),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          if (provider.currentLinkUrl != null)
            TextButton(
              onPressed: () {
                provider.removeLink();
                Navigator.pop(context);
              },
              child: const Text(
                'Bağlantıyı Kaldır',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MostromoTheme.accentColor,
            ),
            onPressed: () {
              if (urlCtrl.text.isNotEmpty) provider.applyLink(urlCtrl.text);
              Navigator.pop(context);
            },
            child: const Text(
              'Uygula',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🌟 SEKME BAŞLIĞI WIDGET'I (TASARIMI GELİŞTİRİLDİ)
class _TabHeader extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabHeader({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? MostromoTheme.accentColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// 🌟 HOVER EFEKTLİ YENİ BUTON TASARIMI
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      textStyle: const TextStyle(fontSize: 11, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MostromoTheme.dividerColor),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            height: 32,
            width: 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? MostromoTheme.accentColor.withValues(alpha: 0.2)
                  : _isHovering
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isActive
                    ? MostromoTheme.accentColor.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.isActive
                  ? MostromoTheme.accentColor
                  : _isHovering
                  ? Colors.white
                  : MostromoTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
