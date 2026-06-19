import 'dart:convert';
import 'package:flutter/material.dart';
import '../engine/block_engine/mostromo_block.dart';
import '../engine/block_engine/mostromo_block_engine.dart';

class BlockEditorProvider extends ChangeNotifier {
  // 1. ÇEKİRDEK MOTOR VE DURUM DEĞİŞKENLERİ
  final MostromoBlockEngine _engine = MostromoBlockEngine();

  // --- YENİ: SABİT SAYFA (CANVAS) BOYUTLARI ---
  double _pageWidth = 1200.0;
  double _pageHeight = 800.0;

  double get pageWidth => _pageWidth;
  double get pageHeight => _pageHeight;

  void updatePageSize(double width, double height) {
    _pageWidth = width;
    _pageHeight = height;
    _setDirty();
    notifyListeners();
  }

  bool _isDirty = false;
  String? _focusedBlockId; // O an üzerinde işlem yapılan/seçilen blok

  // --- GETTER'LAR ---
  List<MostromoBlock> get blocks => _engine.blocks;
  bool get isDirty => _isDirty;
  String? get focusedBlockId => _focusedBlockId;

  // 2. BAŞLATMA VE DOSYA OKUMA
  // 2. BAŞLATMA VE DOSYA OKUMA
  void initialize(String mrbDataOrEmpty) {
    _isDirty = false;
    _focusedBlockId = null;

    try {
      if (mrbDataOrEmpty.trim().isEmpty) throw Exception("Boş veri");

      // YENİ: JSON artık bir Array değil, Map (Obje) olarak okunuyor
      final Map<String, dynamic> jsonData = jsonDecode(mrbDataOrEmpty);

      // Sayfa boyutlarını hafızaya al
      _pageWidth = (jsonData['pw'] ?? 1200.0).toDouble();
      _pageHeight = (jsonData['ph'] ?? 800.0).toDouble();

      final List<dynamic> blocksList = jsonData['blocks'] ?? [];
      final List<MostromoBlock> loadedBlocks = blocksList
          .map((item) => MostromoBlock.fromJson(item))
          .toList();

      _engine.loadFromBlocks(loadedBlocks);
    } catch (e) {
      // Dosya boşsa veya eski formattaysa varsayılan ayarlarla başlar
      _pageWidth = 1200.0;
      _pageHeight = 800.0;

      final initialBlock = MostromoBlock(
        id: 'blk_${DateTime.now().microsecondsSinceEpoch}',
        type: BlockType.paragraph,
        data: {
          'text': '',
          'x': (_pageWidth / 2) - 150.0,
          'y': (_pageHeight / 2) - 75.0,
          'w': 300.0,
          'h': 150.0,
        },
      );
      _engine.loadFromBlocks([initialBlock]);
      _focusedBlockId = initialBlock.id;
    }
    notifyListeners();
  }

  // 3. ODAK VE DURUM YÖNETİMİ
  void setFocusedBlock(String? blockId) {
    if (_focusedBlockId != blockId) {
      _focusedBlockId = blockId;
      notifyListeners();
    }
  }

  void markAsSaved() {
    _isDirty = false;
    notifyListeners();
  }

  void _setDirty() {
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }
  }

  // 4. BLOK MANİPÜLASYONLARI (CRUD)

  /// Yeni bir blok ekler ve isteğe bağlı olarak odağı ona taşır
  /// Yeni bir blok ekler ve isteğe bağlı olarak odağı ona taşır
  void addBlock(BlockType type, {Map<String, dynamic>? initialData}) {
    // DÜZELTİLDİ: Değişkenin başına açıkça Map<String, dynamic> tipini yazdık
    final Map<String, dynamic> defaultData = {
      'text': '',
      'x': (_pageWidth / 2) - 150.0,
      'y': (_pageHeight / 2) - 75.0 + (_engine.blocks.length * 20),
      'w': 300.0,
      'h': type == BlockType.divider ? 40.0 : 150.0,
    };

    if (initialData != null) defaultData.addAll(initialData);

    final newBlock = MostromoBlock(
      id: 'blk_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      data: defaultData,
    );

    _engine.insertBlock(_engine.blocks.length, newBlock);
    _focusedBlockId = newBlock.id;

    _setDirty();
    notifyListeners();
  }

  // Sürükle-bırak ve yeniden boyutlandırma yapıldığında çağrılacak
  void updateBlockGeometry(
    String blockId,
    double newX,
    double newY,
    double newW,
    double newH,
  ) {
    updateBlockData(blockId, {'x': newX, 'y': newY, 'w': newW, 'h': newH});
  }

  /// Bir bloğu siler. Eğer silinen blok aktif odaksa, odağı temizler.
  void removeBlock(String blockId) {
    if (_engine.blocks.length <= 1) return; // Son bloğun silinmesini engelle

    _engine.removeBlock(blockId);

    if (_focusedBlockId == blockId) {
      _focusedBlockId = null;
    }

    _setDirty();
    notifyListeners();
  }

  /// Bloğun verilerini derinlemesine (eski verileri koruyarak) günceller
  void updateBlockData(String blockId, Map<String, dynamic> newUpdates) {
    final blockIndex = _engine.blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex == -1) return;

    // Mevcut verileri al
    final currentBlock = _engine.blocks[blockIndex];

    // DÜZELTİLDİ: Dart'ın Map kısıtlamalarını aşmak için güvenli klonlama yöntemi
    final Map<String, dynamic> mergedData = Map<String, dynamic>.from(
      currentBlock.data,
    );
    mergedData.addAll(newUpdates); // Yeni verilerle üzerine yaz

    _engine.updateBlockData(blockId, mergedData);
    _setDirty();
    notifyListeners();
  }

  /// Sürükle Bırak (Reorder) yeteneği
  void reorderBlocks(int oldIndex, int newIndex) {
    _engine.moveBlock(oldIndex, newIndex);
    _setDirty();
    notifyListeners();
  }

  // 5. DİSKE YAZMA
  /// Sistemi .mrb formatında JSON string'ine çevirir
  String generateMrbData() {
    // YENİ: Sayfa boyutları ve blokları tek bir pakette birleştir
    final data = {
      'pw': _pageWidth,
      'ph': _pageHeight,
      'blocks': _engine.toMrbJson(),
    };
    return jsonEncode(data);
  }
}
