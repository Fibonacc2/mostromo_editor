/// Mostromo Özgür Defter ekosistemindeki tüm blok türleri
enum BlockType {
  paragraph, // Standart metin bloğu
  heading1, // Devasa Başlık (H1)
  heading2, // Orta Başlık (H2)
  heading3, // Küçük Başlık (H3)
  chart, // Dinamik Zaman Serisi Grafiği (3s, 8s, 12s)
  divider, // Ayırıcı Çizgi
  image, // Resim/Görsel Bloğu
}

/// Sayfadaki her bir bağımsız elemanın (Bloğun) şablonu
class MostromoBlock {
  final String
  id; // Flutter ListView'da 'Key' olarak kullanacağımız benzersiz ID
  final BlockType type; // Bloğun türü
  final Map<String, dynamic>
  data; // Bloğa özgü değişken verileri tutan esnek harita

  MostromoBlock({required this.id, required this.type, required this.data});

  /// Blok verilerini derinlemesine kopyalamak için (Eski veriyi bozmamak adıyla)
  MostromoBlock copyWith({
    String? id,
    BlockType? type,
    Map<String, dynamic>? data,
  }) {
    return MostromoBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? Map<String, dynamic>.from(this.data),
    );
  }

  /// Diske (.mrb dosyasına) kaydederken JSON objesine dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      't': type
          .index, // Türü minimum boyutta tutmak için enum indexi olarak saklıyoruz
      'd': data,
    };
  }

  /// Diskten (.mrb) okurken JSON objesini Dart nesnesine çevirir
  factory MostromoBlock.fromJson(Map<String, dynamic> json) {
    return MostromoBlock(
      id: json['id'] as String,
      type: BlockType.values[json['t'] as int],
      data: json['d'] as Map<String, dynamic>,
    );
  }
}
