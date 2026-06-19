class MostromoNote {
  String id;
  String title;
  String previewText;
  DateTime lastUpdated;

  // Bulut ve Çoklu Motor (Dual-Engine) Metadataları
  bool isSynced;
  String extension;

  // Motor Verileri (Uyumluluk için geri eklendi)
  String mroData; // Klasik A4 Motoru verisi (.mro)
  String mrbData; // Özgür Tuval verisi (.mrb)

  MostromoNote({
    required this.id,
    required this.title,
    this.previewText = '',
    required this.lastUpdated,
    this.isSynced = false,
    this.extension = '.mro',
    this.mroData = '',
    this.mrbData = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'previewText': previewText,
    'lastUpdated': lastUpdated.toIso8601String(),
    'isSynced': isSynced,
    'extension': extension,
    'mroData': mroData,
    'mrbData': mrbData,
  };

  factory MostromoNote.fromJson(Map<String, dynamic> json) => MostromoNote(
    id: json['id'],
    title: json['title'],
    previewText: json['previewText'] ?? '',
    lastUpdated: DateTime.parse(json['lastUpdated']),
    isSynced: json['isSynced'] ?? false,
    extension: json['extension'] ?? '.mro',
    mroData: json['mroData'] ?? '',
    mrbData: json['mrbData'] ?? '',
  );

  MostromoNote copyWith({
    String? id,
    String? title,
    String? previewText,
    DateTime? lastUpdated,
    bool? isSynced,
    String? extension,
    String? mroData,
    String? mrbData,
  }) {
    return MostromoNote(
      id: id ?? this.id,
      title: title ?? this.title,
      previewText: previewText ?? this.previewText,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSynced: isSynced ?? this.isSynced,
      extension: extension ?? this.extension,
      mroData: mroData ?? this.mroData,
      mrbData: mrbData ?? this.mrbData,
    );
  }
}
