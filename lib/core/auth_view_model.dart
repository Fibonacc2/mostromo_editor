import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  int? _userId;
  String? _userName;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthViewModel() {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');

    _isLoggedIn = _userId != null;
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com//loginAoth.php"),
        body: {'email': email, 'pwd': password, 'is_app': '1'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          var rawId = data['userID'];
          if (rawId is int) {
            _userId = rawId;
          } else {
            _userId = int.tryParse(rawId.toString()) ?? 0;
          }
          _userName = data['nick'];
          _userEmail = email;
          _isLoggedIn = true;

          // Hafızaya kaydet
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', _userId!);
          await prefs.setString('user_name', _userName!);
          await prefs.setString('user_email', _userEmail!);

          notifyListeners();
          return null; // Başarılı
        } else {
          return data['message'];
        }
      } else {
        return "Sunucu yanıt vermedi (Kod: ${response.statusCode})";
      }
    } catch (e) {
      return "Bağlantı hatası: İnternetinizi kontrol edin.";
    }
  }

  // 🌟 GÜNCELLENDİ: Tüm ayarları sıfırlamak (clear) yerine sadece hesap verilerini temizler.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');

    _isLoggedIn = false;
    _userId = null;
    _userName = null;
    _userEmail = null;

    // Uygulamanın geri kalanına "Çıkış Yapıldı" bilgisini yayınlar!
    notifyListeners();
  }
}
