import 'package:flutter/material.dart';
import 'piece.dart';

class PieceTable {
  final String _originalBuffer;
  String _addBuffer = '';
  List<Piece> _pieces = [];
  int version = 0;

  // --- ZAMAN MAKİNESİ (UNDO / REDO) HAFIZALARI ---
  final List<List<Piece>> _undoStack = [];
  final List<List<Piece>> _redoStack = [];
  final int _maxHistorySteps = 200;

  bool canUndo() => _undoStack.isNotEmpty;
  bool canRedo() => _redoStack.isNotEmpty;

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

  void _saveSnapshot() {
    if (_undoStack.length >= _maxHistorySteps) {
      _undoStack.removeAt(0);
    }
    _undoStack.add(_pieces.map((p) => p.clone()).toList());
    _redoStack.clear();
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    _redoStack.add(_pieces.map((p) => p.clone()).toList());
    _pieces = _undoStack.removeLast();
    version++;
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    _undoStack.add(_pieces.map((p) => p.clone()).toList());
    _pieces = _redoStack.removeLast();
    version++;
    return true;
  }

  void insert(int offset, String text, [MostromoStyle? customStyle]) {
    if (text.isEmpty) return;
    _saveSnapshot();
    version++;

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
    _saveSnapshot();
    version++;

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
    Color? backgroundColor,
    double? fontSize,
    String? fontFamily,
    String? linkUrl,
    TextAlign? textAlign,
    bool clearLink = false,
    bool clearBackground = false,
  }) {
    if (length <= 0) return;
    _saveSnapshot();
    version++;

    int startIndex = _splitAt(offset);
    int endIndex = _splitAt(offset + length);

    for (int i = startIndex; i < endIndex; i++) {
      final piece = _pieces[i];
      piece.style ??= MostromoStyle();

      if (isBold != null) piece.style!.isBold = isBold;
      if (isItalic != null) piece.style!.isItalic = isItalic;
      if (isUnderline != null) piece.style!.isUnderline = isUnderline;
      if (color != null) piece.style!.color = color;
      if (backgroundColor != null)
        piece.style!.backgroundColor = backgroundColor; // 🌟 YENİ
      if (fontSize != null) piece.style!.fontSize = fontSize;
      if (fontFamily != null) piece.style!.fontFamily = fontFamily;
      if (linkUrl != null) piece.style!.linkUrl = linkUrl;
      if (textAlign != null) piece.style!.textAlign = textAlign;

      if (clearLink) piece.style!.linkUrl = null;
      if (clearBackground) piece.style!.backgroundColor = null;
    }
  }

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
            fontFamily: piece.style?.fontFamily,
            fontWeight: piece.style?.isBold == true
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: piece.style?.isItalic == true
                ? FontStyle.italic
                : FontStyle.normal,
            decoration:
                (piece.style?.isUnderline == true || hasLink) && !hasImage
                ? TextDecoration.underline
                : TextDecoration.none,
            color: hasImage
                ? Colors.transparent
                : (hasLink
                      ? Colors.blueAccent
                      : (piece.style?.color ?? Colors.white)),
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            backgroundColor: piece.style?.backgroundColor,
          ),
        ),
      );
    }
    return spans;
  }

  List<ParagraphBlock> getParagraphBlocks() {
    List<ParagraphBlock> blocks = [];
    List<TextSpan> currentSpans = [];
    int currentStartOffset = 0;
    int currentLength = 0;
    int rawLength = 0;
    TextAlign? pendingAlign;

    for (final piece in _pieces) {
      String pieceText = (piece.buffer == BufferType.original)
          ? _originalBuffer.substring(piece.start, piece.start + piece.length)
          : _addBuffer.substring(piece.start, piece.start + piece.length);

      final style = piece.style ?? MostromoStyle();
      pendingAlign ??= style.textAlign ?? TextAlign.left;

      final bool hasImage = style.imageBase64 != null;
      final double letterSpacing = hasImage ? (style.imageWidth ?? 300.0) : 0.0;
      final double fontSize = hasImage
          ? (style.imageHeight ?? 200.0)
          : (style.fontSize ?? 16.0);
      final bool hasLink = style.linkUrl != null;

      TextStyle textStyle = TextStyle(
        fontFamily: style.fontFamily,
        fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: (style.isUnderline || hasLink) && !hasImage
            ? TextDecoration.underline
            : TextDecoration.none,
        color: hasImage
            ? Colors.transparent
            : (hasLink ? Colors.blueAccent : (style.color ?? Colors.white)),
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        backgroundColor: style.backgroundColor,
      );

      int searchIndex = 0;
      while (true) {
        int nlIndex = pieceText.indexOf('\n', searchIndex);
        if (nlIndex == -1) {
          String rest = pieceText.substring(searchIndex);
          if (rest.isNotEmpty) {
            String cleanRest = rest.replaceAll('\r', '');
            if (cleanRest.isNotEmpty) {
              currentSpans.add(TextSpan(text: cleanRest, style: textStyle));
              rawLength += cleanRest.length;
            }
            currentLength += rest.length;
          }
          break;
        } else {
          String part = pieceText.substring(searchIndex, nlIndex);
          if (part.isNotEmpty) {
            String cleanPart = part.replaceAll('\r', '');
            if (cleanPart.isNotEmpty) {
              currentSpans.add(TextSpan(text: cleanPart, style: textStyle));
              rawLength += cleanPart.length;
            }
            currentLength += part.length;
          }
          currentLength += 1;

          blocks.add(
            ParagraphBlock(
              spans: currentSpans,
              textAlign: pendingAlign ?? TextAlign.left,
              startOffset: currentStartOffset,
              length: currentLength,
              rawTextLength: rawLength,
            ),
          );

          currentStartOffset += currentLength;
          currentSpans = [];
          currentLength = 0;
          rawLength = 0;
          pendingAlign = null;
          searchIndex = nlIndex + 1;
        }
      }
    }

    blocks.add(
      ParagraphBlock(
        spans: currentSpans,
        textAlign: pendingAlign ?? TextAlign.left,
        startOffset: currentStartOffset,
        length: currentLength,
        rawTextLength: rawLength,
      ),
    );

    return blocks;
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

class ParagraphBlock {
  final List<TextSpan> spans;
  final TextAlign textAlign;
  final int startOffset;
  final int length;
  final int rawTextLength;

  ParagraphBlock({
    required this.spans,
    required this.textAlign,
    required this.startOffset,
    required this.length,
    required this.rawTextLength,
  });
}
