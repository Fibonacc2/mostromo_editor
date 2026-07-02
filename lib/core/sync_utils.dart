import 'dart:convert';
import 'package:crypto/crypto.dart';

class SyncUtils {
  /// İçerik ve başlıktan benzersiz bir dijital parmak izi (Hash) oluşturur.
  /// Örnek Çıktı: "a1b2c3d4e5f6g7h8"
  static String generateHash(String title, String content) {
    // Türkçe karakterler vs. bozulmasın diye UTF-8 formatına çeviriyoruz
    var bytes = utf8.encode(title + content);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Saat dilimi hatalarını önlemek için ZAMANI HER ZAMAN UTC formatında,
  /// milisaniye (Epoch Timestamp) cinsinden döndürür.
  static int getUtcTimestamp() {
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }
}
