import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:mostromo_editor/engine/core/custom_layout.dart';
import 'dart:math' as math;
import 'dart:async';

import '../engine/core/piece_table.dart';
import '../engine/core/piece.dart';
import '../core/sync_utils.dart';

class EditorProvider extends ChangeNotifier {
  PieceTable engine = PieceTable(initialText: '');

  String _documentTitle = '';
  String _initialHash = '';
  Timer? _autoSaveTimer;

  Function(String title, String mroData)? onLocalSaveTriggered;

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

  String get documentTitle => _documentTitle;
  bool get isBold => _isBold;
  bool get isItalic => _isItalic;
  bool get isUnderline => _isUnderline;
  Color? get currentColor => _currentColor;
  double? get currentFontSize => _currentFontSize;
  String? get currentLinkUrl => _currentLinkUrl;
  String? get currentFontFamily => _currentFontFamily;

  TextAlign _currentTextAlign = TextAlign.left;
  TextAlign get currentTextAlign => _currentTextAlign;

  bool _isDirty = false;
  bool get isDirty => _isDirty;
  bool get hasSelection =>
      selectionBase != null && selectionBase != cursorIndex;

  // --- İMLEÇ GEÇMİŞİ (UNDO/REDO SENKRONİZASYONU) ---
  final List<int> _undoCursorStack = [];
  final List<int> _redoCursorStack = [];

  // Metne yazı eklendiğinde veya silindiğinde çağrılır
  void registerActionForHistory() {
    _undoCursorStack.add(cursorIndex);
    _redoCursorStack
        .clear(); // Yeni eylem yapıldığında ileri alma geçmişi silinir
  }

  void updateTitle(String newTitle) {
    if (_documentTitle != newTitle) {
      _documentTitle = newTitle;
      setDirty();
    }
  }

  // 🌟 KİLİT ÇÖZÜM 1: Sadece düz metni değil, tüm biçimlendirmeleri (JSON) hashe dahil et!
  String _calculateCurrentHash() {
    return SyncUtils.generateHash(
      _documentTitle,
      jsonEncode(generateMroData()),
    );
  }

  void attemptLocalSave() {
    String currentHash = _calculateCurrentHash();

    if (currentHash == _initialHash) {
      debugPrint(
        "SİSTEM: Hash aynı. Sıfır yer değiştirme tespit edildi. Kayıt iptal!",
      );
      _isDirty = false;
      notifyListeners();
      return;
    }

    debugPrint("SİSTEM: Hash değişti. Yerel Diske kaydediliyor...");
    _initialHash = currentHash;
    _isDirty = false;
    notifyListeners();

    if (onLocalSaveTriggered != null) {
      onLocalSaveTriggered!(_documentTitle, jsonEncode(generateMroData()));
    }
  }

  void forceSave() {
    _autoSaveTimer?.cancel();
    attemptLocalSave();
  }

  void markAsSaved() {
    _initialHash = _calculateCurrentHash();
    _isDirty = false;
    notifyListeners();
  }

  void setDirty() {
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      attemptLocalSave();
    });
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

  // --- SAYFA NUMARASI YÖNETİMİ ---
  bool _showPageNumbers = false;
  bool get showPageNumbers => _showPageNumbers;

  Alignment _pageNumberAlignment = Alignment.bottomCenter;
  Alignment get pageNumberAlignment => _pageNumberAlignment;

  void togglePageNumbers() {
    _showPageNumbers = !_showPageNumbers;
    setDirty();
    notifyListeners();
  }

  void setPageNumberAlignment(Alignment alignment) {
    _pageNumberAlignment = alignment;
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

  void initialize(String mroDataOrText, {String title = 'İsimsiz Not'}) {
    _documentTitle = title;
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(mroDataOrText);
      engine = PieceTable.fromMroJson(jsonMap);
      _isPageMode = jsonMap['pm'] ?? false;
      _marginTop = (jsonMap['mt'] ?? 96.0).toDouble();
      _marginBottom = (jsonMap['mb'] ?? 96.0).toDouble();
      _marginLeft = (jsonMap['ml'] ?? 96.0).toDouble();
      _marginRight = (jsonMap['mr'] ?? 96.0).toDouble();
      // 🌟 YENİ: Sayfa Numarası Yükleme
      _showPageNumbers = jsonMap['spn'] ?? false;
      double pnx = (jsonMap['pn_x'] ?? 0.0).toDouble();
      double pny = (jsonMap['pn_y'] ?? 1.0).toDouble();
      _pageNumberAlignment = Alignment(pnx, pny);
    } catch (e) {
      engine = PieceTable(initialText: mroDataOrText);
    }

    cursorIndex = engine.getText().length;
    selectionBase = null;

    _initialHash = _calculateCurrentHash();
    _isDirty = false;

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
    // 🌟 YENİ: Sayfa Numarası Kaydetme
    data['spn'] = _showPageNumbers;
    data['pn_x'] = _pageNumberAlignment.x;
    data['pn_y'] = _pageNumberAlignment.y;
    return data;
  }

  Future<void> _decodeAndCacheImage(int offset, String base64Str) async {
    if (_imageCache.containsKey(offset)) {
      return;
    }
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
      _currentTextAlign = firstStyle.textAlign ?? TextAlign.left;

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
      // 🌟 ÇÖZÜM BURADA: İmleç stilini belirleme algoritması akıllandırıldı
      String text = engine.getText();
      int targetIndex;

      if (cursorIndex == 0) {
        // En baştaysak ilk karakterin stilini al
        targetIndex = 0;
      } else if (cursorIndex > 0 &&
          cursorIndex <= text.length &&
          text[cursorIndex - 1] == '\n') {
        // İmleç yeni bir satırın EN BAŞINDA (kendisinden önceki karakter \n)
        // Bu durumda stili önceki satırdan (\n'den) değil, bulunduğumuz satırın ilk karakterinden almalıyız!
        targetIndex = (cursorIndex < text.length)
            ? cursorIndex
            : cursorIndex - 1;
      } else {
        // İmleç satırın ortasında veya sonunda, standart olarak solundaki karakterin stilini miras al
        targetIndex = cursorIndex - 1;
      }

      final currentStyle = engine.getStyleAt(targetIndex);

      _isBold = currentStyle.isBold;
      _isItalic = currentStyle.isItalic;
      _isUnderline = currentStyle.isUnderline;
      _currentColor = currentStyle.color;
      _currentFontSize = currentStyle.fontSize ?? 16.0;
      _currentLinkUrl = currentStyle.linkUrl;
      _currentFontFamily = currentStyle.fontFamily;
      _currentTextAlign = currentStyle.textAlign ?? TextAlign.left;
    }
  }

  void updateSelection(int cursor, int? base) {
    bool cursorMoved = cursor != cursorIndex;
    cursorIndex = cursor;
    selectionBase = base;

    if (cursorMoved || hasSelection) {
      _syncToolbarWithCursor();
    }
    notifyListeners();
  }

  void selectWordAt(int index) {
    String text = engine.getText();
    if (text.isEmpty) {
      return;
    }

    int safeIndex = index.clamp(0, text.length - 1);

    if (RegExp(r'\s').hasMatch(text[safeIndex])) {
      updateSelection(safeIndex, null);
      return;
    }

    int start = safeIndex;
    int end = safeIndex;

    while (start > 0 &&
        !RegExp(r'''[\s.,!?;:()[\]{}<>"']''').hasMatch(text[start - 1])) {
      start--;
    }

    while (end < text.length &&
        !RegExp(r'''[\s.,!?;:()[\]{}<>"']''').hasMatch(text[end])) {
      end++;
    }

    if (start != end) {
      updateSelection(end, start);
    }
  }

  // 🌟 YENİ: Görsel satır ve sütunu tutacak değişken
  String _currentLineAndColumn = "Satır 1, Sütun 1";
  String get currentLineAndColumn => _currentLineAndColumn;

  // 🌟 YENİ: Arayüzden (TextPainter'dan) gelen kesin koordinatları güncelleyen fonksiyon
  void updateLineAndColumn(int line, int col) {
    final newText = "Satır $line, Sütun $col";
    if (_currentLineAndColumn != newText) {
      _currentLineAndColumn = newText;
      // Build döngüsü sırasında çökme yaşamamak için güncellemeyi bir sonraki kareye erteliyoruz
      Future.microtask(() => notifyListeners());
    }
  }

  int get totalCharacters => engine.getText().length;

  int get wordCount {
    String text = engine.getText().trim();
    if (text.isEmpty) {
      return 0;
    }
    return text.split(RegExp(r'\s+')).length;
  }

  void deleteSelection() {
    if (!hasSelection) {
      return;
    }
    registerActionForHistory();
    int start = math.min(selectionBase!, cursorIndex);
    int end = math.max(selectionBase!, cursorIndex);

    for (int i = start; i < end; i++) {
      if (_imageCache.containsKey(i)) {
        _imageCache.remove(i);
      }
    }

    engine.delete(start, end - start);
    cursorIndex = start;
    selectionBase = null;
    _syncToolbarWithCursor();
  }

  void insertText(String text) {
    registerActionForHistory();
    if (hasSelection) {
      deleteSelection();
    }

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
        textAlign: _currentTextAlign,
      ),
    );
    cursorIndex += text.length;
    setDirty();
    notifyListeners();
  }

  void deleteCharacter() {
    registerActionForHistory();
    if (hasSelection) {
      deleteSelection();
    } else if (cursorIndex > 0) {
      int targetIndex = cursorIndex - 1;
      if (_imageCache.containsKey(targetIndex)) {
        _imageCache.remove(targetIndex);
      }
      engine.delete(targetIndex, 1);
      cursorIndex--;
      _syncToolbarWithCursor();
    }

    setDirty();
    notifyListeners();
  }

  void executeUndo() {
    if (engine.undo()) {
      // 🌟 KİLİT ÇÖZÜM: Geri almadan önce, mevcut imleci ileri alma (Redo) yığınına at
      _redoCursorStack.add(cursorIndex);

      // İmleci geçmişteki doğru konumuna geri çek
      if (_undoCursorStack.isNotEmpty) {
        cursorIndex = _undoCursorStack.removeLast();
      }

      // Güvenlik: İmleç hiçbir koşulda metnin sınırlarını aşamaz
      cursorIndex = cursorIndex.clamp(0, engine.getText().length);

      selectionBase = null;
      _syncToolbarWithCursor();
      preloadImages();
      setDirty();
      notifyListeners();
    }
  }

  void executeRedo() {
    if (engine.redo()) {
      // 🌟 KİLİT ÇÖZÜM: İleri almadan önce, mevcut imleci geri alma (Undo) yığınına at
      _undoCursorStack.add(cursorIndex);

      // İmleci ileri (gelecekteki) konumuna çek
      if (_redoCursorStack.isNotEmpty) {
        cursorIndex = _redoCursorStack.removeLast();
      }

      // Güvenlik: İmleç sınır koruması
      cursorIndex = cursorIndex.clamp(0, engine.getText().length);

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
    if (!hasSelection) {
      return;
    }
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

        if (!context.mounted) return;

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
      if (!context.mounted) return;
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
      // Eğer metin seçiliyse SADECE seçili kısmı büyüt
      int start = math.min(selectionBase!, cursorIndex);
      int end = math.max(selectionBase!, cursorIndex);
      engine.formatText(start, end - start, isBold: bold, fontSize: size);
      _syncToolbarWithCursor(); // Toolbar'ı güncel duruma senkronize et
    } else {
      // 🌟 KESİN ÇÖZÜM: Tüm satırı seçip dönüştürme mantığı tamamen silindi!
      // Sadece imlecin o anki stil belleğini güncelliyoruz.
      // Böylece sen başlığa tıkladıktan SONRA yazacağın şeyler başlık olur, öncekiler etkilenmez.
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

  void applyTextAlign(TextAlign alignment) {
    _currentTextAlign =
        alignment; // 🌟 Toolbar'ın anında yanması için belleği güncelle

    String text = engine.getText();
    if (text.isEmpty) {
      setDirty();
      notifyListeners();
      return;
    }

    int baseIndex = hasSelection
        ? math.min(selectionBase!, cursorIndex)
        : cursorIndex;
    int extIndex = hasSelection
        ? math.max(selectionBase!, cursorIndex)
        : cursorIndex;

    int start = text.lastIndexOf('\n', baseIndex > 0 ? baseIndex - 1 : 0);
    start = start == -1 ? 0 : start + 1;

    int end = text.indexOf('\n', extIndex);
    if (end != -1) {
      end +=
          1; // 🌟 KİLİT ÇÖZÜM: Boş satırın hizalanabilmesi için \n karakterini de formatlamaya dahil et!
    } else {
      end = text.length;
    }

    int length = end - start;
    if (length > 0) {
      engine.formatText(start, length, textAlign: alignment);
    }

    setDirty();
    notifyListeners();
  }

  // --- DÖKÜMAN SEKMELERİ (OUTLINE) VE SCROLL YÖNETİMİ ---
  final ScrollController scrollController = ScrollController();
  bool _isOutlineVisible = false;
  bool get isOutlineVisible => _isOutlineVisible;

  void toggleOutlineVisible() {
    _isOutlineVisible = !_isOutlineVisible;
    notifyListeners();
  }

  List<Map<String, dynamic>> _currentOutline = [];
  List<Map<String, dynamic>> get currentOutline => _currentOutline;

  void updateOutline(List<Map<String, dynamic>> outline) {
    // Sadece gerçekten bir değişiklik varsa UI'ı tetikle (Performans için)
    bool isChanged = false;
    if (_currentOutline.length != outline.length) {
      isChanged = true;
    } else {
      for (int i = 0; i < outline.length; i++) {
        if (_currentOutline[i]['text'] != outline[i]['text'] ||
            _currentOutline[i]['dy'] != outline[i]['dy']) {
          isChanged = true;
          break;
        }
      }
    }

    if (isChanged) {
      _currentOutline = outline;
      notifyListeners();
    }
  }

  void scrollToHeading(double physicalY) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        physicalY,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- BUL (FIND) MOTORU DEĞİŞKENLERİ ---
  List<int> _searchMatches = [];
  int _currentSearchMatchIndex = -1;
  String _currentSearchQuery = '';

  List<int> get searchMatches => _searchMatches;
  int get currentSearchMatchIndex => _currentSearchMatchIndex;
  String get currentSearchQuery => _currentSearchQuery;

  // YENİ: Cached Lines
  List<LogicalLine>? _cachedLines;

  // YENİ: Setter metodu
  void setCachedLines(List<LogicalLine> lines) {
    _cachedLines = lines;
  }

  void _jumpToMatch(int matchPos) {
    // Seçimi güncelle (vurgu için)
    updateSelection(matchPos + _currentSearchQuery.length, matchPos);

    if (!scrollController.hasClients) return;

    // 1. Önce cachedLines varsa onu kullan
    if (_cachedLines != null && _cachedLines!.isNotEmpty) {
      LogicalLine? targetLine;
      for (var line in _cachedLines!) {
        int start = line.startOffset;
        int end = start + line.length;
        // Eşleşme bu satırın aralığında mı?
        if (matchPos >= start && matchPos <= end) {
          targetLine = line;
          break;
        }
      }

      // Eğer bulunamazsa (nadir), son satıra git
      targetLine ??= _cachedLines!.last;

      double targetY = targetLine.dy;
      // Sayfa modunda da targetY zaten fiziksel Y, ekstra işlem yok
      scrollController.animateTo(
        targetY.clamp(0.0, scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }

    // 2. Fallback: cachedLines yoksa eski mantık (ama bu artık çalışmaz, koruma amaçlı)
    final blocks = engine.getParagraphBlocks();
    double targetDy = 0.0;
    bool found = false;
    for (var block in blocks) {
      if (matchPos >= block.startOffset &&
          matchPos <= block.startOffset + block.length) {
        found = true;
        break;
      }
      targetDy += (block.spans.isEmpty
          ? 20.0
          : 24.0 * math.max(1, block.spans.length));
    }
    if (found || targetDy > 0) {
      scrollController.animateTo(
        targetDy.clamp(0.0, scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  // 🌟 YENİ: Arama ayarları
  bool _isCaseSensitive = false;
  bool _isWholeWord = false;

  // Getter'lar
  bool get isCaseSensitive => _isCaseSensitive;
  bool get isWholeWord => _isWholeWord;

  // 🌟 YENİ: Toggle metotları (Aramayı otomatik yeniler)
  void toggleCaseSensitive() {
    _isCaseSensitive = !_isCaseSensitive;
    if (_currentSearchQuery.isNotEmpty) {
      findText(_currentSearchQuery); // Yeniden ara
    }
    notifyListeners();
  }

  void toggleWholeWord() {
    _isWholeWord = !_isWholeWord;
    if (_currentSearchQuery.isNotEmpty) {
      findText(_currentSearchQuery); // Yeniden ara
    }
    notifyListeners();
  }

  // 🌟 GÜNCELLENDİ: findText metodu (Case Sensitive ve Whole Word desteği)
  void findText(String query, {bool caseSensitive = false}) {
    _searchMatches.clear();
    _currentSearchMatchIndex = -1;
    _currentSearchQuery = query;

    if (query.isEmpty) {
      notifyListeners();
      return;
    }

    String text = engine.getText();
    bool useCase = _isCaseSensitive; // Ayarlardan al
    bool wholeWord = _isWholeWord;

    if (wholeWord) {
      // ✅ Tam kelime eşleşmesi (Regex ile)
      String pattern = r'\b' + RegExp.escape(query) + r'\b';
      RegExp regExp = RegExp(pattern, caseSensitive: useCase);
      int start = 0;
      while (true) {
        Match? match = regExp.firstMatch(text.substring(start));
        if (match == null) break;
        int index = start + match.start;
        _searchMatches.add(index);
        start = index + match.end - match.start;
        if (start >= text.length) break;
      }
    } else {
      // ✅ Normal eşleşme (indexOf ile)
      String targetText = useCase ? text : text.toLowerCase();
      String searchQuery = useCase ? query : query.toLowerCase();
      int startIndex = 0;
      while (true) {
        int matchIndex = targetText.indexOf(searchQuery, startIndex);
        if (matchIndex == -1) break;
        _searchMatches.add(matchIndex);
        startIndex = matchIndex + searchQuery.length;
      }
    }

    if (_searchMatches.isNotEmpty) {
      _currentSearchMatchIndex = 0;
      _jumpToMatch(_searchMatches[0]);
    }
    notifyListeners();
  }

  void findNext() {
    if (_searchMatches.isEmpty) return;
    _currentSearchMatchIndex =
        (_currentSearchMatchIndex + 1) % _searchMatches.length;
    int matchPos = _searchMatches[_currentSearchMatchIndex];
    _jumpToMatch(matchPos);
  }

  void findPrevious() {
    if (_searchMatches.isEmpty) return;
    _currentSearchMatchIndex =
        (_currentSearchMatchIndex - 1 + _searchMatches.length) %
        _searchMatches.length;
    int matchPos = _searchMatches[_currentSearchMatchIndex];
    _jumpToMatch(matchPos);
  }

  void clearSearch() {
    _searchMatches.clear();
    _currentSearchMatchIndex = -1;
    _currentSearchQuery = '';
    notifyListeners();
  }

  /// Geçerli seçili metni veya ilk eşleşmeyi değiştirir
  void replaceCurrentMatch(String replacement) {
    if (_searchMatches.isEmpty) return;

    int matchIndex = _searchMatches[_currentSearchMatchIndex];
    int matchLength = _currentSearchQuery.length;

    // Seçili metni sil ve yeni metni ekle
    engine.delete(matchIndex, matchLength);
    engine.insert(matchIndex, replacement);

    // Not: Metin değiştiği için tüm eşleşmeleri yeniden bulmak gerekir
    // Eski eşleşmeler geçersiz oldu, yeniden ara
    String newText = engine.getText();
    // İmleci yeni metnin sonuna koy (kullanıcı rahatça devam etsin)
    cursorIndex = matchIndex + replacement.length;
    selectionBase = null;
    setDirty();

    // Aramayı yeniden yap
    findText(_currentSearchQuery);
  }

  /// Tüm eşleşmeleri değiştirir
  void replaceAllMatches(String replacement) {
    if (_searchMatches.isEmpty) return;

    // Ters sırada değiştir (sondan başa) ki indeksler kaymasın
    List<int> reversedMatches = List.from(_searchMatches.reversed);
    for (int matchIndex in reversedMatches) {
      int matchLength = _currentSearchQuery.length;
      engine.delete(matchIndex, matchLength);
      engine.insert(matchIndex, replacement);
    }

    // İmleci en sona koy
    cursorIndex = engine.getText().length;
    selectionBase = null;
    setDirty();

    // Aramayı yeniden yap (yeni metinle)
    findText(_currentSearchQuery);
  }
}
