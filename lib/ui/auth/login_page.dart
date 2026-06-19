import 'dart:io' show Platform, exit;
import 'dart:ui'; // 🌟 YENİ: Buzlu cam efekti (BackdropFilter) için
import 'dart:math' as math; // 🌟 YENİ: Baloncukların dairesel hareketi için

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_view_model.dart';
import '../../core/app_theme.dart';
import '../editor/mostromo_title_bar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// 🌟 YENİ: Arka plan animasyonu için "SingleTickerProviderStateMixin" eklendi
class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // 🌟 YENİ: Arka plandaki baloncukları hareket ettirecek motor
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    // Animasyon 12 saniyede bir tam tur (360 derece) atacak ve sürekli tekrarlayacak
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Lütfen e-posta ve şifrenizi girin.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authVM = context.read<AuthViewModel>();
    final error = await authVM.login(email, password);

    if (error != null) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MostromoTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // =========================================================
          // 🌟 1. KATMAN: METAMORPH (AKAN BALONCUKLAR) ARKA PLANI
          // =========================================================
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              // Animasyonun 0 ile 2*Pi (360 derece) arasındaki anlık değeri
              final double time = _bgAnimController.value * 2 * math.pi;

              return Stack(
                children: [
                  // Zemin Rengi
                  Container(color: MostromoTheme.backgroundColor),

                  // 1. Baloncuk (Yeşilimsi Mostromo Vurgu Rengi) - Saat yönünde döner
                  Align(
                    alignment: Alignment(math.sin(time), math.cos(time)),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MostromoTheme.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                  // 2. Baloncuk (Koyu Mor) - Ters ve daha geniş döner
                  Align(
                    alignment: Alignment(math.cos(time), -math.sin(time)),
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),

                  // 3. Baloncuk (Mavimsi) - Çapraz döner
                  Align(
                    alignment: Alignment(-math.sin(time), -math.cos(time)),
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                      ),
                    ),
                  ),

                  // SİHİRLİ DOKUNUŞ: Bütün baloncukları aşırı derecede bulanıklaştırıp birbirine eritir
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              );
            },
          ),

          // =========================================================
          // 🌟 2. KATMAN: ARAYÜZ (GİRİŞ EKRANI VE ÜST ÇUBUK)
          // =========================================================
          SafeArea(
            child: Column(
              children: [
                // Platform Kontrollü Masaüstü Çubuğu
                if (!kIsWeb &&
                    (Platform.isWindows ||
                        Platform.isMacOS ||
                        Platform.isLinux))
                  MostromoTitleBar(
                    isEditor: false,
                    backgroundColor: Colors.transparent,
                    onClose: () => exit(0),
                  ),

                // Form Alanı
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          // Arka plandaki renkler görünsün diye panel hafif şeffaf yapıldı
                          color: const Color(
                            0xFF161616,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white10, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 50,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- Logo Bölümü ---
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: MostromoTheme.accentColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: MostromoTheme.accentColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_document,
                                  size: 48,
                                  color: MostromoTheme.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- Başlıklar ---
                            const Text(
                              "Mostromo Notes",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Çalışma alanınıza erişmek için\nlütfen giriş yapın.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // --- Form ---
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: "E-Posta",
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: MostromoTheme.accentColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: "Şifre",
                                labelStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: MostromoTheme.accentColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),

                            // --- Hata Mesajı ---
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 32),

                            // --- Giriş Butonu ---
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MostromoTheme.accentColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Giriş Yap",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
