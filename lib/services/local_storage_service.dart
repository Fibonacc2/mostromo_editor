import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class LocalStorageService {
  static late Directory _notesDirectory;

  /// Uygulama başlarken klasör yollarını oluşturur
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _notesDirectory = Directory('${docsDir.path}/MostromoNotes');

    if (!await _notesDirectory.exists()) {
      await _notesDirectory.create(recursive: true);
    }
  }

  /// Notu fiziksel olarak diske yazar (Uzantıya göre .mro veya .mrb olarak)
  static Future<void> saveNote(MostromoNote note) async {
    final file = File('${_notesDirectory.path}/${note.id}${note.extension}');

    // Bulut senkronizasyonu için tüm metadataları da diske yazıyoruz
    final Map<String, dynamic> fileData = {
      'id': note.id,
      'title': note.title,
      'previewText': note.previewText,
      'lastUpdated': note.lastUpdated.toIso8601String(),
      'isSynced': note.isSynced,
      'extension': note.extension,
    };

    // Hangi motorsa onun verisini string'den çözüp JSON (Obje/Dizi) olarak 'engine' içine gömüyoruz
    try {
      if (note.extension == '.mrb') {
        fileData['engine'] = note.mrbData.isNotEmpty
            ? jsonDecode(note.mrbData)
            : [];
      } else {
        fileData['engine'] = note.mroData.isNotEmpty
            ? jsonDecode(note.mroData)
            : {};
      }
    } catch (e) {
      // Çeviri hatası olursa boş veri atar
      fileData['engine'] = note.extension == '.mrb' ? [] : {};
    }

    await file.writeAsString(jsonEncode(fileData));
  }

  /// Klasördeki TÜM dosyaları (.mro ve .mrb) okuyup Pano (Dashboard) için listeye çevirir
  static Future<List<MostromoNote>> loadAllNotes() async {
    final List<MostromoNote> notes = [];
    if (!await _notesDirectory.exists()) return notes;

    // Hem .mro hem de .mrb uzantılı dosyaları bul
    final files = _notesDirectory.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.mro') || f.path.endsWith('.mrb'),
    );

    for (final file in files) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);

        // Eğer dosyada extension bilgisi yoksa dosya adından çıkar (Geriye dönük uyumluluk)
        final String ext =
            json['extension'] ?? (file.path.endsWith('.mrb') ? '.mrb' : '.mro');

        notes.add(
          MostromoNote(
            id: json['id'],
            title: json['title'],
            previewText: json['previewText'] ?? '',
            lastUpdated: DateTime.parse(json['lastUpdated']),
            isSynced: json['isSynced'] ?? false,
            extension: ext,
            // Dosyanın içindeki engine verisini asıl sahibine (mroData veya mrbData) String olarak geri paketle
            mroData: ext == '.mro' ? jsonEncode(json['engine'] ?? {}) : '',
            mrbData: ext == '.mrb' ? jsonEncode(json['engine'] ?? []) : '',
          ),
        );
      } catch (e) {
        debugPrint('Dosya okunamadı: ${file.path}');
      }
    }

    // Okunan dosyaları son güncellenme tarihine göre sırala
    notes.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return notes;
  }

  /// İstenilen notu diskten fiziksel olarak siler
  static Future<void> deleteNote(String id, String extension) async {
    final file = File('${_notesDirectory.path}/$id$extension');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- BULUT (CLOUD) SERVİSİ İÇİN YARDIMCI METOTLAR ---

  /// Buluta gönderilmek üzere dosyanın ham (raw) JSON içeriğini okur
  static Future<String> readNoteContentForCloud(
    String id,
    String extension,
  ) async {
    final file = File('${_notesDirectory.path}/$id$extension');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  /// Buluttan gelen ham JSON verisini anında fiziksel diske yazar
  static Future<void> saveRawCloudData(
    String id,
    String extension,
    String rawJsonData,
  ) async {
    final file = File('${_notesDirectory.path}/$id$extension');
    await file.writeAsString(rawJsonData);
  }
}
