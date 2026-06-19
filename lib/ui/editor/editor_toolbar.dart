import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
        color: Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: MostromoTheme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kısım: SEKMELER (TABS)
          _buildTabBar(provider),

          // 2. Kısım: SEKME İÇERİĞİ (RIBBON CONTENT)
          Container(
            height: 48, // Şerit yüksekliği
            width: double.infinity, // Ekranı tam kaplaması için
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildTabContent(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  // --- SEKMELERİ ÇİZEN BÖLÜM ---
  Widget _buildTabBar(EditorProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      // 🌟 YENİ: Sekmeler sığmazsa diye yatay kaydırma koruması eklendi
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton('Giriş', 0, provider),
            _buildTabButton('Ekle', 1, provider),
            _buildTabButton('Düzen', 2, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, EditorProvider provider) {
    final isActive = provider.activeTab == index;
    return GestureDetector(
      onTap: () => provider.setActiveTab(index),
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

  // --- SEKME İÇERİKLERİ ---
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

  // SEKME 1: GİRİŞ (Metin, Font, Stil, Renk)
  Widget _buildHomeTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_home'),
      width: double.infinity,
      // 🌟 YENİ: İçerik taşarsa parmakla sağa-sola kaydırılsın
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStyleDropdown(provider),
            _buildDivider(),

            _buildFontSizeDropdown(provider),
            _buildDivider(),

            _buildToolbarIcon(
              Icons.format_bold,
              provider.isBold,
              provider.toggleBold,
            ),
            _buildToolbarIcon(
              Icons.format_italic,
              provider.isItalic,
              provider.toggleItalic,
            ),
            _buildToolbarIcon(
              Icons.format_underlined,
              provider.isUnderline,
              provider.toggleUnderline,
            ),
            _buildDivider(),

            _buildColorPicker(context, provider),
          ],
        ),
      ),
    );
  }

  // SEKME 2: EKLE (Resim, Tablo, Ayırıcı, Link)
  Widget _buildInsertTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_insert'),
      width: double.infinity,
      // 🌟 YENİ: Yatay kaydırma koruması
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionIcon(Icons.image_outlined, 'Resim Ekle', () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Resim motoru, daha serbest bir tasarım için yeniden inşa ediliyor. Şimdilik askıda!',
                  ),
                ),
              );
            }),

            _buildActionIcon(Icons.table_chart_outlined, 'Tablo', () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tablo sistemi yakında eklenecek.'),
                ),
              );
            }),
            _buildDivider(),

            _buildActionIcon(
              Icons.link_rounded,
              'Bağlantı (Link) Ekle',
              () => _showLinkDialog(context, provider),
              isActive: provider.currentLinkUrl != null,
            ),
            _buildActionIcon(
              Icons.horizontal_rule_rounded,
              'Ayırıcı Çizgi Ekle',
              () => provider.insertDivider(),
            ),
          ],
        ),
      ),
    );
  }

  // SEKME 3: DÜZEN (Sayfa Ayarları, Kenarlıklar)
  Widget _buildLayoutTab(BuildContext context, EditorProvider provider) {
    return SizedBox(
      key: const ValueKey('tab_layout'),
      width: double.infinity,
      // 🌟 YENİ: Yatay kaydırma koruması
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionIcon(
              provider.isPageMode
                  ? Icons.fit_screen_rounded
                  : Icons.fullscreen_rounded,
              provider.isPageMode ? 'Tam Ekran Modu' : 'Sayfa (A4) Modu',
              provider.togglePageMode,
              isActive: provider.isPageMode,
            ),
            _buildDivider(),
            _buildActionIcon(
              Icons.settings_overscan_rounded,
              'Sayfa Kenarlıkları',
              () => _showMarginDialog(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  // --- BAĞLANTI (LİNK) EKRANI ---
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

  // --- KOMPONENTLER (Görsel Araçlar) ---

  Widget _buildStyleDropdown(EditorProvider provider) {
    final Map<int, String> styles = {
      0: 'Normal Metin',
      1: 'Başlık 1',
      2: 'Başlık 2',
      3: 'Başlık 3',
    };

    return PopupMenuButton<int>(
      initialValue: provider.currentHeadingLevel,
      tooltip: 'Metin Stili',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (level) => provider.applyHeading(level),
      itemBuilder: (context) => styles.entries.map((entry) {
        return PopupMenuItem<int>(
          value: entry.key,
          height: 36,
          child: Text(
            entry.value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: entry.key > 0 ? FontWeight.bold : FontWeight.normal,
              fontSize: entry.key == 1
                  ? 18
                  : entry.key == 2
                  ? 16
                  : 14,
            ),
          ),
        );
      }).toList(),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              styles[provider.currentHeadingLevel]!,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildActionIcon(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? MostromoTheme.accentColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? MostromoTheme.accentColor : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  tooltip,
                  style: TextStyle(
                    color: isActive
                        ? MostromoTheme.accentColor
                        : Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarIcon(
    IconData icon,
    bool isActive,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: isActive
            ? MostromoTheme.accentColor
            : MostromoTheme.textSecondary,
        style: IconButton.styleFrom(
          backgroundColor: isActive
              ? MostromoTheme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: MostromoTheme.dividerColor,
    );
  }

  Widget _buildColorPicker(BuildContext context, EditorProvider provider) {
    return InkWell(
      onTap: () {
        Color pickerColor = provider.currentColor ?? Colors.white;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: MostromoTheme.surfaceColor,
            title: const Text(
              'Metin Rengi',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: BlockPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  pickerColor = color;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  provider.setTextColor(pickerColor);
                  Navigator.pop(context);
                },
                child: const Text('Uygula'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.format_color_text,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: provider.currentColor ?? Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- KENARLIK (MARGIN) AYAR PENCERESİ ---
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
}
