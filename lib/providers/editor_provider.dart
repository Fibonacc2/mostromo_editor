import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:math' as math;
import '../engine/piece_table.dart';
import '../engine/piece.dart';

class EditorProvider extends ChangeNotifier {
  PieceTable engine = PieceTable(initialText: '');

  bool get canUndo => engine.canUndo();
  bool get canRedo => engine.canRedo();

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  Color? _currentColor;
  double? _currentFontSize = 16.0;
  String? _currentLinkUrl;
  String? _currentFontFamily;

  List<String> loadedFonts = [
    'Sistem Varsayılanı',
    'Roboto',
    'Times New Roman',
    'Courier',
  ];

  int cursorIndex = 0;
  int? selectionBase;

  bool get isBold => _isBold;
  bool get isItalic => _isItalic;
  bool get isUnderline => _isUnderline;
  Color? get currentColor => _currentColor;
  double? get currentFontSize => _currentFontSize;
  String? get currentLinkUrl => _currentLinkUrl;
  String? get currentFontFamily => _currentFontFamily;

  bool _isDirty = false;
  bool get isDirty => _isDirty;

  bool get hasSelection =>
      selectionBase != null && selectionBase != cursorIndex;

  void markAsSaved() {
    _isDirty = false;
    notifyListeners();
  }

  void setDirty() {
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }
  }

  int _activeTab = 0;
  int get activeTab => _activeTab;

  void setActiveTab(int index) {
    _activeTab = index;
    notifyListeners();
  }

  bool _isPageMode = false;
  bool get isPageMode => _isPageMode;

  double _marginTop = 96.0;
  double _marginBottom = 96.0;
  double _marginLeft = 96.0;
  double _marginRight = 96.0;

  double get marginTop => _marginTop;
  double get marginBottom => _marginBottom;
  double get marginLeft => _marginLeft;
  double get marginRight => _marginRight;

  void togglePageMode() {
    _isPageMode = !_isPageMode;
    setDirty();
    notifyListeners();
  }

  void updateMargins({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    if (top != null) _marginTop = top;
    if (bottom != null) _marginBottom = bottom;
    if (left != null) _marginLeft = left;
    if (right != null) _marginRight = right;
    setDirty();
    notifyListeners();
  }

  int get currentHeadingLevel {
    if (_currentFontSize == 32.0 && _isBold) return 1;
    if (_currentFontSize == 24.0 && _isBold) return 2;
    if (_currentFontSize == 20.0 && _isBold) return 3;
    return 0;
  }

  final Map<int, ui.Image> _imageCache = {};
  Map<int, ui.Image> get imageCache => _imageCache;

  void initialize(String mroDataOrText) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(mroDataOrText);
      engine = PieceTable.fromMroJson(jsonMap);
      _isPageMode = jsonMap['pm'] ?? false;
      _marginTop = (jsonMap['mt'] ?? 96.0).toDouble();
      _marginBottom = (jsonMap['mb'] ?? 96.0).toDouble();
      _marginLeft = (jsonMap['ml'] ?? 96.0).toDouble();
      _marginRight = (jsonMap['mr'] ?? 96.0).toDouble();
    } catch (e) {
      engine = PieceTable(initialText: mroDataOrText);
    }

    cursorIndex = engine.getText().length;
    selectionBase = null;
    _syncToolbarWithCursor();
    preloadImages();
  }

  Map<String, dynamic> generateMroData() {
    final data = engine.toMroJson();
    data['pm'] = _isPageMode;
    data['mt'] = _marginTop;
    data['mb'] = _marginBottom;
    data['ml'] = _marginLeft;
    data['mr'] = _marginRight;
    return data;
  }

  Future<void> _decodeAndCacheImage(int offset, String base64Str) async {
    if (_imageCache.containsKey(offset)) return;
    try {
      final bytes = base64Decode(base64Str);
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      _imageCache[offset] = frameInfo.image;
      notifyListeners();
    } catch (e) {
      debugPrint("Resim yükleme hatası: $e");
    }
  }

  void preloadImages() {
    int currentOffset = 0;
    for (var piece in engine.internalPieces) {
      if (piece.style?.imageBase64 != null) {
        _decodeAndCacheImage(currentOffset, piece.style!.imageBase64!);
      }
      currentOffset += piece.length;
    }
  }

  void insertImage(String base64Str, double width, double height) {
    insertText('\u200B');
    int targetIndex = cursorIndex - 1;
    int startIndex = engine.splitAtForProvider(targetIndex);
    int endIndex = engine.splitAtForProvider(targetIndex + 1);

    for (int i = startIndex; i < endIndex; i++) {
      final piece = engine.internalPieces[i];
      piece.style ??= MostromoStyle();
      piece.style!.imageBase64 = base64Str;
      piece.style!.imageWidth = width;
      piece.style!.imageHeight = height;
    }

    _decodeAndCacheImage(targetIndex, base64Str);
    setDirty();
    notifyListeners();
  }

  void insertDivider() {
    String divider = '\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    insertText(divider);
    engine.formatText(
      cursorIndex - divider.length,
      divider.length,
      color: Colors.white24,
    );
    setDirty();
    notifyListeners();
  }

  void applyLink(String url) {
    if (hasSelection) {
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);
      engine.formatText(start, end - start, linkUrl: url);
      _currentLinkUrl = url;
      setDirty();
      notifyListeners();
    }
  }

  void removeLink() {
    if (hasSelection) {
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);
      engine.formatText(start, end - start, clearLink: true);
      _currentLinkUrl = null;
      setDirty();
      notifyListeners();
    }
  }

  void _syncToolbarWithCursor() {
    if (hasSelection) {
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);

      final firstStyle = engine.getStyleAt(start);
      _isBold = firstStyle.isBold;
      _isItalic = firstStyle.isItalic;
      _isUnderline = firstStyle.isUnderline;
      _currentColor = firstStyle.color;
      _currentLinkUrl = firstStyle.linkUrl;
      _currentFontFamily = firstStyle.fontFamily;

      double? firstSize;
      bool isMixed = false;

      for (int i = start; i < end; i++) {
        double size = engine.getStyleAt(i).fontSize ?? 16.0;
        if (i == start) {
          firstSize = size;
        } else if (firstSize != size) {
          isMixed = true;
          break;
        }
      }
      _currentFontSize = isMixed ? null : firstSize;
    } else {
      int targetIndex = cursorIndex > 0 ? cursorIndex - 1 : 0;
      final currentStyle = engine.getStyleAt(targetIndex);

      _isBold = currentStyle.isBold;
      _isItalic = currentStyle.isItalic;
      _isUnderline = currentStyle.isUnderline;
      _currentColor = currentStyle.color;
      _currentFontSize = currentStyle.fontSize ?? 16.0;
      _currentLinkUrl = currentStyle.linkUrl;
      _currentFontFamily = currentStyle.fontFamily;
    }
  }

  void updateSelection(int cursor, int? base) {
    bool cursorMoved = cursor != cursorIndex;
    cursorIndex = cursor;
    selectionBase = base;

    if (cursorMoved || hasSelection) {
      _syncToolbarWithCursor();
    } else {
      notifyListeners();
    }
  }

  // 🌟 YENİ: ÇİFT TIKLAMA VEYA BASILI TUTMA İLE KELİME SEÇME MOTORU
  void selectWordAt(int index) {
    String text = engine.getText();
    if (text.isEmpty) return;

    int safeIndex = index.clamp(0, text.length - 1);

    // Eğer boşluğa veya noktalama işaretine tıkladıysa kelime seçme, sadece imleci koy
    if (RegExp(r'\s').hasMatch(text[safeIndex])) {
      updateSelection(safeIndex, null);
      return;
    }

    int start = safeIndex;
    int end = safeIndex;

    // Sola doğru kelimenin başını bul
    while (start > 0 &&
        !RegExp(r'[\s.,!?;:()[\]{}<>"' + "'" + ']').hasMatch(text[start - 1])) {
      start--;
    }

    // Sağa doğru kelimenin sonunu bul
    while (end < text.length &&
        !RegExp(r'[\s.,!?;:()[\]{}<>"' + "'" + ']').hasMatch(text[end])) {
      end++;
    }

    if (start != end) {
      updateSelection(end, start);
    }
  }

  int get currentLine {
    String text = engine.getText();
    int safeCursor = cursorIndex.clamp(0, text.length);
    String textUpToCursor = text.substring(0, safeCursor);
    return RegExp(r'\n').allMatches(textUpToCursor).length + 1;
  }

  int get currentColumn {
    String text = engine.getText();
    int safeCursor = cursorIndex.clamp(0, text.length);
    String textUpToCursor = text.substring(0, safeCursor);
    int lastNewline = textUpToCursor.lastIndexOf('\n');
    if (lastNewline == -1) return safeCursor + 1;
    return safeCursor - lastNewline;
  }

  int get totalCharacters => engine.getText().length;

  int get wordCount {
    String text = engine.getText().trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  void deleteSelection() {
    if (!hasSelection) return;
    int start = math.min(selectionBase!, cursorIndex);
    int end = math.max(selectionBase!, cursorIndex);

    for (int i = start; i < end; i++) {
      if (_imageCache.containsKey(i)) _imageCache.remove(i);
    }

    engine.delete(start, end - start);
    cursorIndex = start;
    selectionBase = null;
    _syncToolbarWithCursor();
  }

  void insertText(String text) {
    if (hasSelection) deleteSelection();

    engine.insert(
      cursorIndex,
      text,
      MostromoStyle(
        isBold: _isBold,
        isItalic: _isItalic,
        isUnderline: _isUnderline,
        color: _currentColor,
        fontSize: _currentFontSize,
        linkUrl: _currentLinkUrl,
        fontFamily: _currentFontFamily,
      ),
    );
    cursorIndex += text.length;
    setDirty();
    notifyListeners();
  }

  void deleteCharacter() {
    if (hasSelection) {
      deleteSelection();
    } else if (cursorIndex > 0) {
      int targetIndex = cursorIndex - 1;
      if (_imageCache.containsKey(targetIndex)) _imageCache.remove(targetIndex);
      engine.delete(targetIndex, 1);
      cursorIndex--;
      _syncToolbarWithCursor();
    }
    setDirty();
    notifyListeners();
  }

  void executeUndo() {
    if (engine.undo()) {
      if (cursorIndex > engine.getText().length)
        cursorIndex = engine.getText().length;
      selectionBase = null;
      _syncToolbarWithCursor();
      preloadImages();
      setDirty();
      notifyListeners();
    }
  }

  void executeRedo() {
    if (engine.redo()) {
      if (cursorIndex > engine.getText().length)
        cursorIndex = engine.getText().length;
      selectionBase = null;
      _syncToolbarWithCursor();
      preloadImages();
      setDirty();
      notifyListeners();
    }
  }

  void _applyFormatToSelection({
    bool? bold,
    bool? italic,
    bool? underline,
    Color? color,
    double? fontSize,
    String? fontFamily,
  }) {
    if (!hasSelection) return;
    int start = math.min(selectionBase!, cursorIndex);
    int end = math.max(selectionBase!, cursorIndex);
    engine.formatText(
      start,
      end - start,
      isBold: bold,
      isItalic: italic,
      isUnderline: underline,
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    setDirty();
  }

  void toggleBold() {
    _isBold = !_isBold;
    if (hasSelection) _applyFormatToSelection(bold: _isBold);
    notifyListeners();
  }

  void toggleItalic() {
    _isItalic = !_isItalic;
    if (hasSelection) _applyFormatToSelection(italic: _isItalic);
    notifyListeners();
  }

  void toggleUnderline() {
    _isUnderline = !_isUnderline;
    if (hasSelection) _applyFormatToSelection(underline: _isUnderline);
    notifyListeners();
  }

  void setTextColor(Color color) {
    _currentColor = color;
    if (hasSelection) _applyFormatToSelection(color: color);
    notifyListeners();
  }

  void applyFontFamily(String family) {
    String? finalFamily = family == 'Sistem Varsayılanı' ? null : family;

    if (hasSelection) {
      _applyFormatToSelection(fontFamily: finalFamily);
      _syncToolbarWithCursor();
    } else {
      _currentFontFamily = finalFamily;
    }
    setDirty();
    notifyListeners();
  }

  Future<void> pickAndLoadCustomFont(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null) {
        final file = result.files.single;
        final fontName = file.name.split('.').first;
        Uint8List fontBytes;

        if (kIsWeb) {
          fontBytes = file.bytes!;
        } else {
          fontBytes = await File(file.path!).readAsBytes();
        }

        final fontLoader = FontLoader(fontName);
        fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await fontLoader.load();

        if (!loadedFonts.contains(fontName)) {
          loadedFonts.add(fontName);
        }
        applyFontFamily(fontName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fontName" fontu başarıyla yüklendi ve uygulandı!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Font yüklenirken bir hata oluştu.')),
      );
    }
  }

  void applyHeading(int level) {
    double size = 16.0;
    bool bold = false;

    if (level == 1) {
      size = 32.0;
      bold = true;
    } else if (level == 2) {
      size = 24.0;
      bold = true;
    } else if (level == 3) {
      size = 20.0;
      bold = true;
    }

    if (hasSelection) {
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);
      engine.formatText(start, end - start, isBold: bold, fontSize: size);
    } else {
      String text = engine.getText();
      int start =
          text.lastIndexOf('\n', cursorIndex > 0 ? cursorIndex - 1 : 0) + 1;
      if (start < 0) start = 0;
      int end = text.indexOf('\n', cursorIndex);
      if (end == -1) end = text.length;

      if (end > start) {
        engine.formatText(start, end - start, isBold: bold, fontSize: size);
      }
      _currentFontSize = size;
      _isBold = bold;
    }
    setDirty();
    notifyListeners();
  }

  void applyFontSize(double size) {
    if (hasSelection) {
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);
      engine.formatText(start, end - start, fontSize: size);
      _syncToolbarWithCursor();
    } else {
      _currentFontSize = size;
    }
    setDirty();
    notifyListeners();
  }
}
