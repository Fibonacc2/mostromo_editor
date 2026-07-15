import 'package:flutter/material.dart';

class MostromoStyle {
  bool isBold;
  bool isItalic;
  bool isUnderline;
  Color? color;
  double? fontSize;
  String? linkUrl;

  // 🌟 YENİ: FONT AİLESİ
  String? fontFamily;

  // --- RESİM VERİLERİ ---
  String? imageBase64;
  double? imageWidth;
  double? imageHeight;

  MostromoStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.color,
    this.fontSize,
    this.linkUrl,
    this.fontFamily, // 🌟 YENİ
    this.imageBase64,
    this.imageWidth,
    this.imageHeight,
  });

  MostromoStyle clone() {
    return MostromoStyle(
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      color: color,
      fontSize: fontSize,
      linkUrl: linkUrl,
      fontFamily: fontFamily, // 🌟 YENİ
      imageBase64: imageBase64,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'b': isBold,
      'i': isItalic,
      'u': isUnderline,
      'c': color?.toARGB32(),
      'fs': fontSize,
      'l': linkUrl,
      'ff': fontFamily, // 🌟 YENİ: JSON kısaltması
      'img': imageBase64,
      'iw': imageWidth,
      'ih': imageHeight,
    };
  }

  factory MostromoStyle.fromJson(Map<String, dynamic> json) {
    return MostromoStyle(
      isBold: json['b'] ?? false,
      isItalic: json['i'] ?? false,
      isUnderline: json['u'] ?? false,
      color: json['c'] != null ? Color(json['c']) : null,
      fontSize: json['fs']?.toDouble(),
      linkUrl: json['l'],
      fontFamily: json['ff'], // 🌟 YENİ
      imageBase64: json['img'],
      imageWidth: json['iw']?.toDouble(),
      imageHeight: json['ih']?.toDouble(),
    );
  }
}

enum BufferType { original, add }

class Piece {
  BufferType buffer;
  int start;
  int length;
  MostromoStyle? style;

  Piece({
    required this.buffer,
    required this.start,
    required this.length,
    this.style,
  });

  Piece clone() {
    return Piece(
      buffer: buffer,
      start: start,
      length: length,
      style: style?.clone(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'t': buffer.index, 's': start, 'l': length, 'sty': style?.toJson()};
  }

  factory Piece.fromJson(Map<String, dynamic> json) {
    return Piece(
      buffer: BufferType.values[json['t'] ?? 0],
      start: json['s'] ?? 0,
      length: json['l'] ?? 0,
      style: json['sty'] != null ? MostromoStyle.fromJson(json['sty']) : null,
    );
  }

  @override
  String toString() {
    return 'Piece(${buffer.name}, start: $start, len: $length, style: $style)';
  }
}
