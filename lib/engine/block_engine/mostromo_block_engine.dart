import 'mostromo_block.dart';

class MostromoBlockEngine {
  final List<MostromoBlock> _blocks = [];

  List<MostromoBlock> get blocks => List.unmodifiable(_blocks);

  /// Motoru ilk verilerle veya boş olarak başlatır
  void loadFromBlocks(List<MostromoBlock> newBlocks) {
    _blocks.clear();
    _blocks.addAll(newBlocks);
  }

  /// Belirli bir indeksin arkasına yeni bir blok ekler
  void insertBlock(int index, MostromoBlock block) {
    if (index >= 0 && index <= _blocks.length) {
      _blocks.insert(index, block);
    }
  }

  /// Bir bloğu tamamen siler
  void removeBlock(String blockId) {
    _blocks.removeWhere((b) => b.id == blockId);
  }

  /// Bir bloğun içindeki veri (data) haritasını günceller (Örn: Metin yazıldıkça)
  void updateBlockData(String blockId, Map<String, dynamic> newData) {
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    if (idx != -1) {
      _blocks[idx] = _blocks[idx].copyWith(data: newData);
    }
  }

  /// Sürükle-bırak veya yukarı-aşağı butonları için blokların yerini değiştirir
  void moveBlock(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final MostromoBlock item = _blocks.removeAt(oldIndex);
    _blocks.insert(newIndex, item);
  }

  /// Tüm arayüzü diske yazılacak ham JSON listesine çevirir
  List<Map<String, dynamic>> toMrbJson() {
    return _blocks.map((b) => b.toJson()).toList();
  }
}
