import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/editor_provider.dart';

class MostromoStatusBar extends StatelessWidget {
  const MostromoStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Depodaki imleç hareketlerini dinliyoruz
    final provider = context.watch<EditorProvider>();

    return Container(
      height: 28, // Profesyonel ve kibar bir yükseklik
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161616), // Koyu alt taban rengi
        border: Border(
          top: BorderSide(color: MostromoTheme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // --- SOL ALAN: Canlı Satır ve Sütun Koordinatları ---
          Row(
            children: [
              const Icon(
                Icons.code_rounded,
                color: MostromoTheme.accentColor,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'Ln ${provider.currentLine}, Col ${provider.currentColumn}',
                style: const TextStyle(
                  color: MostromoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily:
                      'monospace', // Kod editörü hissiyatı için sabit genişlikli font
                ),
              ),
            ],
          ),

          // --- SAĞ ALAN: Belge İstatistikleri ve Dosya Künyesi ---
          Row(
            children: [
              Text(
                '${provider.wordCount} kelime',
                style: const TextStyle(
                  color: MostromoTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              _buildSeparator(),
              Text(
                '${provider.totalCharacters} karakter',
                style: const TextStyle(
                  color: MostromoTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              _buildSeparator(),
              const Text(
                'UTF-8',
                style: TextStyle(color: MostromoTheme.textMuted, fontSize: 11),
              ),
              _buildSeparator(),
              const Text(
                '.mro',
                style: TextStyle(
                  color: MostromoTheme.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              _buildSeparator(),
              InkWell(
                onTap: () => provider.togglePageMode(),
                child: Icon(
                  provider.isPageMode
                      ? Icons.fit_screen_rounded
                      : Icons.fullscreen_rounded,
                  color: provider.isPageMode
                      ? MostromoTheme.accentColor
                      : MostromoTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      height: 12,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: MostromoTheme.dividerColor,
    );
  }
}
