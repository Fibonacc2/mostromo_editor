import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../core/app_theme.dart';

class MostromoColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initialColor;
  final bool isBackground;
  final ValueChanged<Color?> onColorApplied;

  const MostromoColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColor,
    required this.isBackground,
    required this.onColorApplied,
  });

  @override
  State<MostromoColorPickerDialog> createState() =>
      _MostromoColorPickerDialogState();
}

class _MostromoColorPickerDialogState extends State<MostromoColorPickerDialog> {
  late Color _selectedColor;
  bool _isCustomMode = false;

  final List<Color> _modernPresets = [
    Colors.white,
    const Color(0xFFE0E0E0),
    const Color(0xFF9E9E9E),
    const Color(0xFF424242),
    const Color(0xFF000000),
    const Color(0xFFF44336),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF673AB7),
    const Color(0xFF3F51B5),
    const Color(0xFF2196F3),
    const Color(0xFF03A9F4),
    const Color(0xFF00BCD4),
    const Color(0xFF009688),
    const Color(0xFF4CAF50),
    const Color(0xFF8BC34A),
    const Color(0xFFCDDC39),
    const Color(0xFFFFEB3B),
    const Color(0xFFFFC107),
    const Color(0xFFFF9800),
    const Color(0xFFFF5722),
    const Color(0xFF795548),
    const Color(0xFF607D8B),
    const Color(0xFF00E5FF),
    const Color(0xFFFF4081),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor == Colors.transparent
        ? Colors.yellow
        : widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCustomMode = false),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isCustomMode
                              ? MostromoTheme.accentColor.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          "Hazır Renkler",
                          style: TextStyle(
                            color: !_isCustomMode
                                ? MostromoTheme.accentColor
                                : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCustomMode = true),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isCustomMode
                              ? MostromoTheme.accentColor.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          "Özel Renk",
                          style: TextStyle(
                            color: _isCustomMode
                                ? MostromoTheme.accentColor
                                : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              child: _isCustomMode
                  ? _buildCustomPicker()
                  : _buildPresetPicker(),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    widget.onColorApplied(null);
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.format_color_reset_rounded,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Rengi Temizle',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onColorApplied(_selectedColor);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MostromoTheme.accentColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Uygula',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _modernPresets.map((c) {
        bool isSelected = _selectedColor.value == c.value;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? MostromoTheme.accentColor
                      : Colors.white12,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: MostromoTheme.accentColor.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomPicker() {
    return ColorPicker(
      pickerColor: _selectedColor,
      onColorChanged: (color) => setState(() => _selectedColor = color),
      colorPickerWidth: 280,
      pickerAreaHeightPercent: 0.6,
      enableAlpha: widget.isBackground,
      displayThumbColor: true,
      paletteType: PaletteType.hsvWithHue,
      labelTypes: const [],
      pickerAreaBorderRadius: BorderRadius.circular(8),
      hexInputBar: true,
      portraitOnly: true, // 🌟 TAŞMA HATASININ KESİN ÇÖZÜMÜ
    );
  }
}
