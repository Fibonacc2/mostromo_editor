/*
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart'; // 🌟 YENİ EKLENDİ (Hash için)

import '../models/note.dart';
import 'local_storage_service.dart';

class CloudSyncService {
  static const String baseUrl =
      "https://mostromo.com/connect/android/notes_api.php";
  static int currentUserId = 0;

  static Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');

    if (id != null && id > 0) {
      currentUserId = id;
      return true;
    }
    return false;
  }

  // 🌟 HASH OLUŞTURUCU: ID + Başlık + İçerik metnini tek bir şifreye çevirir
  static String _generateHash(String id, String title, String content) {
    var bytes = utf8.encode(id + title + content);
    return md5.convert(bytes).toString();
  }

  /// 2. HASH BAZLI AKILLI SENKRONİZASYON MOTORU
  static Future<void> syncAllNotes() async {
    if (!await checkLoginStatus()) return;

    try {
      debugPrint(
        "🔄 [SYNC] Senkronizasyon Başladı (UserID: $currentUserId)...",
      );

      final List<MostromoNote> localNotes =
          await LocalStorageService.loadAllNotes();
      final response = await http.get(
        Uri.parse('$baseUrl?action=list&user_id=$currentUserId'),
      );

      if (response.statusCode != 200) {
        debugPrint(
          "❌ [SYNC] Hata. HTTP: ${response.statusCode} | Detay: ${response.body}",
        );
        return;
      }

      final List<dynamic> cloudData = jsonDecode(response.body)['notes'] ?? [];

      // Buluttaki verileri Hash ve Tarih ile birlikte bir haritaya koy
      Map<String, Map<String, dynamic>> cloudNotesMap = {};
      for (var item in cloudData) {
        cloudNotesMap[item['id']] = {
          'date': DateTime.parse(item['lastUpdated']),
          'hash': item['hash'] ?? '',
        };
      }

      for (var localNote in localNotes) {
        final cloudInfo = cloudNotesMap[localNote.id];

        // Yerel dosyanın içeriğini okuyup anlık Parmak İzini (Hash) çıkarıyoruz
        final fileContent = await LocalStorageService.readNoteContentForCloud(
          localNote.id,
          localNote.extension,
        );
        final localHash = _generateHash(
          localNote.id,
          localNote.title,
          fileContent,
        );

        if (cloudInfo == null) {
          // Bulutta hiç yoksa yükle (İçeriği iki kez okumasın diye fonksiyona direkt veriyoruz)
          debugPrint(
            "⬆️ [SYNC] '${localNote.title}' bulutta yok, yükleniyor...",
          );
          await uploadNote(localNote, localHash, fileContent);
        } else {
          final cloudHash = cloudInfo['hash'];
          final DateTime cloudDate = cloudInfo['date'];

          // 🌟 1. AŞAMA: HASH KONTROLÜ
          if (localHash == cloudHash && cloudHash.isNotEmpty) {
            // İki dosya birebir aynı! Ne yükle, ne de indir.
            debugPrint(
              "✅ [SYNC] '${localNote.title}' tamamen aynı (Hash eşleşti). Atlanıyor...",
            );
            if (!localNote.isSynced) {
              localNote.isSynced = true;
              await LocalStorageService.saveNote(localNote);
            }
          } else {
            // 🌟 2. AŞAMA: HASH FARKLIYSA TARİHLERİ KIYASLA
            final int localTimeSec =
                localNote.lastUpdated.millisecondsSinceEpoch ~/ 1000;
            final int cloudTimeSec = cloudDate.millisecondsSinceEpoch ~/ 1000;

            if (localTimeSec > cloudTimeSec) {
              debugPrint(
                "⬆️ [SYNC] '${localNote.title}' yerelde güncellenmiş. Buluta fırlatılıyor...",
              );
              await uploadNote(localNote, localHash, fileContent);
            } else if (localTimeSec < cloudTimeSec) {
              debugPrint(
                "⬇️ [SYNC] '${localNote.title}' bulutta daha yeni. İndiriliyor...",
              );
              await downloadAndSaveNoteLocally(localNote.id);
            } else {
              // Nadir durum: Saniyeler eşit ama içerik farklı. Değişiklik yerelden buluta aktarılır.
              debugPrint(
                "⬆️ [SYNC] '${localNote.title}' Çakışma düzeltiliyor...",
              );
              await uploadNote(localNote, localHash, fileContent);
            }
          }
        }
        cloudNotesMap.remove(localNote.id);
      }

      for (String missingLocalId in cloudNotesMap.keys) {
        debugPrint(
          "⬇️ [SYNC] Yerelde eksik dosya bulundu ($missingLocalId), indiriliyor...",
        );
        await downloadAndSaveNoteLocally(missingLocalId);
      }

      debugPrint("✅ [SYNC] Tüm Senkronizasyon Tamamlandı!");
    } catch (e) {
      debugPrint("❌ [SYNC] Kritik Hata: $e");
    }
  }

  /// 3. SUNUCUYA YÜKLEME
  static Future<void> uploadNote(
    MostromoNote note, [
    String? preCalcHash,
    String? preLoadedContent,
  ]) async {
    if (currentUserId == 0) return;

    try {
      // Okunmuş veri varsa onu kullan, yoksa kendin oku
      final fileContent =
          preLoadedContent ??
          await LocalStorageService.readNoteContentForCloud(
            note.id,
            note.extension,
          );
      final hashToSave =
          preCalcHash ?? _generateHash(note.id, note.title, fileContent);

      final requestUrl = '$baseUrl?action=sync&user_id=$currentUserId';

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': note.id,
          'title': note.title,
          'previewText': note.previewText,
          'lastUpdated': note.lastUpdated.toIso8601String(),
          'extension': note.extension,
          'hash': hashToSave, // 🌟 Hash'i sunucuya gönderiyoruz
          'fileData': fileContent,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint(
            "✅ [UPLOAD] '${note.title}' buluta kaydedildi (Hash: $hashToSave).",
          );
          note.isSynced = true;
          await LocalStorageService.saveNote(note);
        }
      }
    } catch (e) {
      debugPrint("❌ [UPLOAD] Beklenmeyen Hata: $e");
    }
  }

  /// 4. İNDİRME MOTORU
  static Future<void> downloadAndSaveNoteLocally(String noteId) async {
    try {
      final requestUrl =
          '$baseUrl?action=download&id=$noteId&user_id=$currentUserId';
      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final downloadedNote = MostromoNote(
            id: data['id'].toString(),
            title: data['title'] ?? 'İsimsiz Defter',
            previewText: data['previewText'] ?? '',
            lastUpdated: DateTime.parse(
              data['lastUpdated'] ?? DateTime.now().toIso8601String(),
            ),
            isSynced: true,
            extension: data['extension'] ?? '.mro',
          );

          await LocalStorageService.saveRawCloudData(
            downloadedNote.id,
            downloadedNote.extension,
            data['fileData'] ?? '{}',
          );

          debugPrint(
            "✅ [DOWNLOAD] '$noteId' indirildi (Sunucu Hash'i kabul edildi).",
          );
        }
      }
    } catch (e) {
      debugPrint("❌ [DOWNLOAD] Uygulama İçi Çökme: $e");
    }
  }
}
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import 'local_storage_service.dart';
import '../core/sync_utils.dart'; // 🌟 YENİ: Hash ve Zaman araçlarımız

class CloudSyncService {
  static const String baseUrl =
      "https://mostromo.com/connect/android/notes_api.php";
  static int currentUserId = 0;

  static Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');

    if (id != null && id > 0) {
      currentUserId = id;
      return true;
    }
    return false;
  }

  /// 🌟 POSTACI: Akıllı Senkronizasyon (Toplu İşlem)
  static Future<void> syncAllNotes() async {
    if (!await checkLoginStatus()) return;

    try {
      debugPrint("🔄 [POSTACI] Mesaiye Başladı (UserID: $currentUserId)...");

      final List<MostromoNote> localNotes =
          await LocalStorageService.loadAllNotes();

      // 1. Sunucudan sadece METADATA (Liste) çekiyoruz
      final response = await http.get(
        Uri.parse('$baseUrl?action=list&user_id=$currentUserId'),
      );

      if (response.statusCode != 200) {
        debugPrint("❌ [POSTACI] Sunucuya ulaşılamadı.");
        return;
      }

      final List<dynamic> cloudData = jsonDecode(response.body)['notes'] ?? [];

      // Buluttaki verileri UTC tarihlere çevirerek haritaya koy
      Map<String, Map<String, dynamic>> cloudNotesMap = {};
      for (var item in cloudData) {
        cloudNotesMap[item['id'].toString()] = {
          'date': DateTime.parse(
            item['lastUpdated'],
          ).toUtc(), // Sunucu tarihini UTC yap
          'hash': item['hash'] ?? '',
        };
      }

      // 2. Yerel Dosyaları Tarama
      for (var localNote in localNotes) {
        final cloudInfo = cloudNotesMap[localNote.id];

        if (cloudInfo == null) {
          // Sunucuda yok ama yerelde var. (Kullanıcı offline iken yeni not açmış)
          if (!localNote.isSynced) {
            debugPrint(
              "⬆️ [POSTACI] '${localNote.title}' yeni dosya, buluta fırlatılıyor...",
            );
            await uploadNote(localNote);
          }
        } else {
          final DateTime cloudDate = cloudInfo['date'];

          // Milisaniye bazında kesin kıyaslama
          final int localTimeMs = localNote.lastUpdated.millisecondsSinceEpoch;
          final int cloudTimeMs = cloudDate.millisecondsSinceEpoch;

          if (!localNote.isSynced) {
            // YERELDE DEĞİŞİKLİK YAPILMIŞ: Hangi dosya daha güncel? (Son Yazan Kazanır)
            if (localTimeMs >= cloudTimeMs) {
              debugPrint(
                "⬆️ [POSTACI] '${localNote.title}' yerelde güncellenmiş. Buluta fırlatılıyor...",
              );
              await uploadNote(localNote);
            } else {
              debugPrint(
                "⬇️ [POSTACI] '${localNote.title}' ÇAKIŞMA: Buluttaki dosya daha yeni. İndiriliyor...",
              );
              await downloadAndSaveNoteLocally(localNote.id);
            }
          } else {
            // YERELDE DEĞİŞİKLİK YOK (isSynced = true). Sadece bulutta yeni bir şey var mı diye bak.
            if (cloudTimeMs > localTimeMs) {
              debugPrint(
                "⬇️ [POSTACI] '${localNote.title}' bulutta güncellenmiş. İndiriliyor...",
              );
              await downloadAndSaveNoteLocally(localNote.id);
            }
          }
        }
        // İncelenen dosyayı haritadan sil ki geriye sadece yerelde olmayanlar kalsın
        cloudNotesMap.remove(localNote.id);
      }

      // 3. Yerelde olmayan (başka cihazdan açılmış) dosyaları indir
      for (String missingLocalId in cloudNotesMap.keys) {
        debugPrint(
          "⬇️ [POSTACI] Eksik dosya bulundu ($missingLocalId), indiriliyor...",
        );
        await downloadAndSaveNoteLocally(missingLocalId);
      }

      debugPrint("✅ [POSTACI] Mesaisi Bitti. Tüm dosyalar güncel!");
    } catch (e) {
      debugPrint("❌ [POSTACI] Kaza Yaptı: $e");
    }
  }

  /// 🌟 YÜKLEME MOTORU (Sadece güncellenmişleri gönderir)
  static Future<void> uploadNote(MostromoNote note) async {
    if (currentUserId == 0) return;

    try {
      final fileContent = await LocalStorageService.readNoteContentForCloud(
        note.id,
        note.extension,
      );

      // Merkezi alet çantasından Hash üretiyoruz
      final hashToSave = SyncUtils.generateHash(note.title, fileContent);

      final requestUrl = '$baseUrl?action=sync&user_id=$currentUserId';

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': note.id,
          'title': note.title,
          'previewText': note.previewText,
          // Sunucuya HER ZAMAN UTC formatında gönder
          'lastUpdated': note.lastUpdated.toUtc().toIso8601String(),
          'extension': note.extension,
          'hash': hashToSave,
          'fileData': fileContent,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint("✅ [UPLOAD] '${note.title}' başarıyla yüklendi.");

          // Yükleme başarılı olduğu için bayrağı tekrar kilitliyoruz
          note.isSynced = true;
          await LocalStorageService.saveNote(note);
        }
      }
    } catch (e) {
      debugPrint("❌ [UPLOAD] Beklenmeyen Hata: $e");
    }
  }

  /// 🌟 İNDİRME MOTORU
  static Future<void> downloadAndSaveNoteLocally(String noteId) async {
    try {
      final requestUrl =
          '$baseUrl?action=download&id=$noteId&user_id=$currentUserId';
      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final downloadedNote = MostromoNote(
            id: data['id'].toString(),
            title: data['title'] ?? 'İsimsiz Defter',
            previewText: data['previewText'] ?? '',
            // Buluttan geleni her zaman UTC olarak kabul edip diske bas
            lastUpdated: DateTime.parse(
              data['lastUpdated'] ?? DateTime.now().toUtc().toIso8601String(),
            ).toUtc(),
            isSynced: true, // Buluttan geldiği için taze ve güncel
            extension: data['extension'] ?? '.mro',
          );

          // Önce ham JSON'ı, sonra Note modelini fiziksel diske yazıyoruz
          await LocalStorageService.saveRawCloudData(
            downloadedNote.id,
            downloadedNote.extension,
            data['fileData'] ?? '{}',
          );
          await LocalStorageService.saveNote(downloadedNote);

          debugPrint("✅ [DOWNLOAD] '$noteId' başarıyla indirildi.");
        }
      }
    } catch (e) {
      debugPrint("❌ [DOWNLOAD] Çökme: $e");
    }
  }
}
