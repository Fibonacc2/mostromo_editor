import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/editor_provider.dart';

class DocumentOutlinePanel extends StatelessWidget {
  const DocumentOutlinePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final outline = provider.currentOutline;

    // 🌟 ÇÖZÜM: Animasyon sırasında genişlik daralırken metinlerin hata vermemesi için
    // İçeriği sabit genişlikli bir kutuya (250) alıp dışarıdan taşırma (ClipRect) uyguluyoruz.
    return SizedBox(
      width: 250,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(right: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'İÇİNDEKİLER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 🌟 YENİ: Paneli kapatmak için küçük bir çarpı butonu
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 18,
                    ),
                    onPressed: () => provider.toggleOutlineVisible(),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: outline.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Başlık bulunamadı.\n(Başlık oluşturmak için yazıyı seçip kalınlaştırın ve fontu büyütün)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: outline.length,
                      itemBuilder: (context, index) {
                        final heading = outline[index];
                        final int level = heading['level'];
                        final String text = heading['text'];
                        final double dy = heading['dy'];

                        return InkWell(
                          onTap: () => provider.scrollToHeading(dy),
                          hoverColor: Colors.white.withValues(alpha: 0.05),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 16.0 + ((level - 1) * 14.0),
                              right: 16.0,
                              top: 10.0,
                              bottom: 10.0,
                            ),
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: level == 1
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: level == 1 ? 14 : 13,
                                fontWeight: level == 1
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
