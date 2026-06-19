import 'package:flutter/material.dart';
import 'piece.dart';

class PieceTable {
  final String _originalBuffer;
  String _addBuffer = '';
  List<Piece> _pieces = [];

  // --- ZAMAN MAKİNESİ (UNDO / REDO) HAFIZALARI ---
  final List<List<Piece>> _undoStack = [];
  final List<List<Piece>> _redoStack = []; // İleri alma yığını
  final int _maxHistorySteps = 200;

  bool canUndo() => _undoStack.isNotEmpty;
  bool canRedo() => _redoStack.isNotEmpty;

  // Paket içi kullanım için parçaları (pieces) dışarı açıyoruz (Provider'daki resim ekleme için gerekli)
  List<Piece> get internalPieces => _pieces;

  PieceTable({String initialText = ''}) : _originalBuffer = initialText {
    if (_originalBuffer.isNotEmpty) {
      _pieces.add(
        Piece(
          buffer: BufferType.original,
          start: 0,
          length: _originalBuffer.length,
          style: MostromoStyle(),
        ),
      );
    }
  }

  /// Değişiklik yapılmadan hemen önce mevcut durumu kaydeder
  void _saveSnapshot() {
    if (_undoStack.length >= _maxHistorySteps) {
      _undoStack.removeAt(0);
    }
    _undoStack.add(_pieces.map((p) => p.clone()).toList());

    // Zaman çizelgesi değiştiği için ileri alma hafızası silinir
    _redoStack.clear();
  }

  /// Geri Al (Undo)
  bool undo() {
    if (_undoStack.isEmpty) return false;
    // Geriye gitmeden önce "şu anki" durumu İleri Al yığınına atıyoruz
    _redoStack.add(_pieces.map((p) => p.clone()).toList());
    // Geçmişi yüklüyoruz
    _pieces = _undoStack.removeLast();
    return true;
  }

  /// İleri Al (Redo)
  bool redo() {
    if (_redoStack.isEmpty) return false;
    // İleriye gitmeden önce "şu anki" durumu tekrar Geri Al yığınına atıyoruz
    _undoStack.add(_pieces.map((p) => p.clone()).toList());
    // Geleceği yüklüyoruz
    _pieces = _redoStack.removeLast();
    return true;
  }

  void insert(int offset, String text, [MostromoStyle? customStyle]) {
    if (text.isEmpty) return;

    _saveSnapshot(); // Değişiklikten hemen önce snapshot al

    final int addBufferStart = _addBuffer.length;
    _addBuffer += text;

    int insertIndex = _splitAt(offset);

    MostromoStyle? styleToApply = customStyle;
    if (styleToApply == null && insertIndex > 0) {
      styleToApply = _pieces[insertIndex - 1].style?.clone() ?? MostromoStyle();
    } else {
      styleToApply ??= MostromoStyle();
    }

    final newPiece = Piece(
      buffer: BufferType.add,
      start: addBufferStart,
      length: text.length,
      style: styleToApply,
    );

    _pieces.insert(insertIndex, newPiece);
  }

  void delete(int offset, int length) {
    if (length <= 0) return;

    _saveSnapshot(); // Değişiklikten hemen önce snapshot al

    List<Piece> newPieces = [];
    int currentOffset = 0;
    int deleteEnd = offset + length;

    for (var piece in _pieces) {
      int pieceStartOffset = currentOffset;
      int pieceEndOffset = currentOffset + piece.length;

      if (pieceEndOffset <= offset) {
        newPieces.add(piece);
      } else if (pieceStartOffset >= deleteEnd) {
        newPieces.add(piece);
      } else {
        if (pieceStartOffset < offset) {
          int keepLength = offset - pieceStartOffset;
          newPieces.add(
            Piece(
              buffer: piece.buffer,
              start: piece.start,
              length: keepLength,
              style: piece.style?.clone(),
            ),
          );
        }
        if (pieceEndOffset > deleteEnd) {
          int keepLength = pieceEndOffset - deleteEnd;
          int skipLength = deleteEnd - pieceStartOffset;
          newPieces.add(
            Piece(
              buffer: piece.buffer,
              start: piece.start + skipLength,
              length: keepLength,
              style: piece.style?.clone(),
            ),
          );
        }
      }
      currentOffset += piece.length;
    }

    _pieces.clear();
    _pieces.addAll(newPieces);
  }

  void formatText(
    int offset,
    int length, {
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    Color? color,
    double? fontSize,
    String? linkUrl, // Bağlantı (Link) eklemek için
    bool clearLink = false, // Bağlantıyı temizlemek için
  }) {
    if (length <= 0) return;

    _saveSnapshot(); // Renk/stil değişmeden hemen önce snapshot al

    int startIndex = _splitAt(offset);
    int endIndex = _splitAt(offset + length);

    for (int i = startIndex; i < endIndex; i++) {
      final piece = _pieces[i];
      piece.style ??= MostromoStyle();

      if (isBold != null) piece.style!.isBold = isBold;
      if (isItalic != null) piece.style!.isItalic = isItalic;
      if (isUnderline != null) piece.style!.isUnderline = isUnderline;
      if (color != null) piece.style!.color = color;
      if (fontSize != null) piece.style!.fontSize = fontSize;

      // Link işlemleri
      if (linkUrl != null) piece.style!.linkUrl = linkUrl;
      if (clearLink) piece.style!.linkUrl = null;
    }
  }

  // Sadece Provider'ın erişebilmesi için paket içi (_splitAt) public yapıldı
  int splitAtForProvider(int offset) => _splitAt(offset);

  int _splitAt(int offset) {
    if (offset <= 0) return 0;
    int totalLength = getText().length;
    if (offset >= totalLength) return _pieces.length;

    int currentOffset = 0;
    for (int i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];

      if (currentOffset + piece.length == offset) {
        return i + 1;
      }

      if (offset > currentOffset && offset < currentOffset + piece.length) {
        int splitPoint = offset - currentOffset;

        final leftPiece = Piece(
          buffer: piece.buffer,
          start: piece.start,
          length: splitPoint,
          style: piece.style?.clone(),
        );

        final rightPiece = Piece(
          buffer: piece.buffer,
          start: piece.start + splitPoint,
          length: piece.length - splitPoint,
          style: piece.style?.clone(),
        );

        _pieces[i] = leftPiece;
        _pieces.insert(i + 1, rightPiece);

        return i + 1;
      }
      currentOffset += piece.length;
    }
    return _pieces.length;
  }

  List<TextSpan> getRichTextSpans() {
    List<TextSpan> spans = [];
    for (final piece in _pieces) {
      String pieceText;
      if (piece.buffer == BufferType.original) {
        pieceText = _originalBuffer.substring(
          piece.start,
          piece.start + piece.length,
        );
      } else {
        pieceText = _addBuffer.substring(
          piece.start,
          piece.start + piece.length,
        );
      }

      // --- SİHİRLİ GÖRÜNMEZ KUTU (PHANTOM BOX) VE LİNK SİSTEMİ ---
      final bool hasImage = piece.style?.imageBase64 != null;
      final double letterSpacing = hasImage
          ? (piece.style!.imageWidth ?? 300.0)
          : 0.0;
      final double fontSize = hasImage
          ? (piece.style!.imageHeight ?? 200.0)
          : (piece.style?.fontSize ?? 16.0);
      final bool hasLink = piece.style?.linkUrl != null;

      spans.add(
        TextSpan(
          text: pieceText,
          style: TextStyle(
            fontWeight: piece.style?.isBold == true
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: piece.style?.isItalic == true
                ? FontStyle.italic
                : FontStyle.normal,
            // Resim varsa altını çizme, link varsa altını çiz
            decoration:
                (piece.style?.isUnderline == true || hasLink) && !hasImage
                ? TextDecoration.underline
                : TextDecoration.none,
            // Resim varsa metni TAMAMEN ŞEFFAF yap (Görünmez Kutu). Değilse normal/link rengini ver.
            color: hasImage
                ? Colors.transparent
                : (hasLink
                      ? Colors.blueAccent
                      : (piece.style?.color ?? Colors.white)),
            fontSize: fontSize,
            letterSpacing: letterSpacing,
          ),
        ),
      );
    }
    return spans;
  }

  String getText() {
    final StringBuffer result = StringBuffer();
    for (final piece in _pieces) {
      if (piece.buffer == BufferType.original) {
        result.write(
          _originalBuffer.substring(piece.start, piece.start + piece.length),
        );
      } else {
        result.write(
          _addBuffer.substring(piece.start, piece.start + piece.length),
        );
      }
    }
    return result.toString();
  }

  MostromoStyle getStyleAt(int offset) {
    if (_pieces.isEmpty) return MostromoStyle();
    if (offset < 0) return _pieces.first.style?.clone() ?? MostromoStyle();

    int currentOffset = 0;
    for (final piece in _pieces) {
      currentOffset += piece.length;
      if (offset < currentOffset) {
        return piece.style?.clone() ?? MostromoStyle();
      }
    }
    return _pieces.last.style?.clone() ?? MostromoStyle();
  }

  Map<String, dynamic> toMroJson() {
    return {
      'ob': _originalBuffer,
      'ab': _addBuffer,
      'pieces': _pieces.map((p) => p.toJson()).toList(),
    };
  }

  factory PieceTable.fromMroJson(Map<String, dynamic> json) {
    final original = json['ob'] as String? ?? '';
    final added = json['ab'] as String? ?? '';

    PieceTable restoredTable = PieceTable(initialText: original);
    restoredTable._addBuffer = added;
    restoredTable._pieces.clear();

    if (json['pieces'] != null) {
      final List<dynamic> piecesList = json['pieces'];
      for (var pJson in piecesList) {
        restoredTable._pieces.add(Piece.fromJson(pJson));
      }
    }
    return restoredTable;
  }
}
