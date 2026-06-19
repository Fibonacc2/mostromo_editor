import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// GÜVENLİK VE YÖNLENDİRİCİ
import 'core/auth_view_model.dart';
import 'core/app_router.dart';

// TEMALAR VE SERVİSLER
import 'core/app_theme.dart';
import 'services/local_storage_service.dart';

// EDİTÖR MOTORLARI
import 'providers/editor_provider.dart';
import 'providers/block_editor_provider.dart';

// DIŞARIDAN DOSYA AÇILIŞINI YAKALAMAK İÇİN args EKLENDİ
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();

  // --- BAŞLANGIÇ ROTASI YAKALAYICI (OFFLINE READER) ---
  String initialRoute = '/';
  if (args.isNotEmpty) {
    // Windows'ta dosyaya çift tıklanınca args[0] dosya yolunu verir
    String filePath = args[0];
    if (filePath.endsWith('.mro') || filePath.endsWith('.mrb')) {
      initialRoute = '/reader?path=${Uri.encodeComponent(filePath)}';
    }
  }

  // --- SADECE MASAÜSTÜ İÇİN PENCERE YÖNETİCİSİ (MOBİL ÇÖKMESİNİ ENGELLER) ---
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // STANDART ÇERÇEVEYİ GİZLE
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => EditorProvider()),
        ChangeNotifierProvider(create: (_) => BlockEditorProvider()),
      ],
      child: MostromoEditorApp(
        initialRoute: initialRoute,
      ), // Rotayı içeri fırlatıyoruz
    ),
  );
}

class MostromoEditorApp extends StatelessWidget {
  final String initialRoute;
  const MostromoEditorApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();

    // AppRouter'ı başlangıç rotasıyla başlat
    final appRouter = AppRouter(authViewModel, initialRoute: initialRoute);

    return MaterialApp.router(
      title: 'Mostromo Notes',
      debugShowCheckedModeBanner: false,
      theme: MostromoTheme.darkTheme,
      routerConfig: appRouter.router,
    );
  }
}
