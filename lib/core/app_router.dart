import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostromo_editor/ui/settings/settings_screen.dart';
import 'package:window_manager/window_manager.dart';

// GÜVENLİK VE GİRİŞ
import 'auth_view_model.dart';
import '../models/note.dart';

// SAYFALAR
import '../ui/auth/login_page.dart';
import '../ui/dashboard/dashboard_screen.dart';
import '../ui/editor/editor_screen.dart';
import '../ui/editor/mostromo_title_bar.dart';
import '../ui/reader/offline_reader_screen.dart'; // YENİ: Okuyucu Ekranı

// TEMA
import '../core/app_theme.dart';

final bool isDesktopOS =
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class AppRouter {
  late final GoRouter router;
  final AuthViewModel authViewModel;
  final String initialRoute; // YENİ: Dinamik Rota

  AppRouter(this.authViewModel, {this.initialRoute = '/'}) {
    router = GoRouter(
      initialLocation: initialRoute, // Uygulama buradan başlar!
      refreshListenable: authViewModel,
      redirect: _handleRedirect,
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

        // YENİ: DIŞARIDAN DOSYA AÇMA (OFFLINE READER)
        GoRoute(
          path: '/reader',
          builder: (context, state) {
            final filePath = state.uri.queryParameters['path'] ?? '';
            return OfflineReaderScreen(filePath: filePath);
          },
        ),

        GoRoute(
          path: '/editor',
          builder: (context, state) {
            final note = state.extra as MostromoNote?;
            return EditorScreen(note: note);
          },
        ),

        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _MainWrapper(navigationShell: navigationShell);
          },
          branches: _buildBranches(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Center(
          child: Text(
            'Sayfa bulunamadı: ${state.error}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  List<StatefulShellBranch> _buildBranches() {
    return [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ];
  }

  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isLoggedIn = authViewModel.isLoggedIn;
    final path = state.uri.path;

    final isGoingToLogin = path == '/login';
    final isGoingToReader = path.startsWith('/reader');

    if (authViewModel.isLoading) return null;

    if (isGoingToReader) return null; // Reader'a izin ver

    if (!isLoggedIn && !isGoingToLogin) return '/login';
    if (isLoggedIn && isGoingToLogin) return '/';

    return null;
  }
}

class _MainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _MainWrapper({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Sadece ekran genişliği yetmez, işletim sistemi mobilse her zaman mobil arayüz ver
    if (isDesktopOS || MediaQuery.of(context).size.width > 800 && kIsWeb) {
      return _DesktopWrapper(navigationShell: navigationShell);
    } else {
      return _MobileWrapper(navigationShell: navigationShell);
    }
  }
}

class _DesktopWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _DesktopWrapper({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MostromoTheme.backgroundColor,
      body: Column(
        children: [
          // SADECE MASAÜSTÜNDE PENCEREYİ KAPATMAYA İZİN VER
          if (isDesktopOS)
            MostromoTitleBar(
              height: 40,
              backgroundColor: const Color(0xFF161616),
              isEditor: false,
              onClose: () => windowManager.close(),
            ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 230,
                  color: const Color(0xFF161616),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MostromoTheme.accentColor.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit_document,
                                size: 24,
                                color: MostromoTheme.accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Mostromo Notes",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildNavItem(
                        context,
                        0,
                        Icons.description_outlined,
                        Icons.description_rounded,
                        'Notlarım',
                      ),
                      const Spacer(),
                      _buildNavItem(
                        context,
                        1,
                        Icons.settings_outlined,
                        Icons.settings,
                        'Ayarlar',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Container(width: 1, color: Colors.white10),
                Expanded(child: ClipRRect(child: navigationShell)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final bool isSelected = navigationShell.currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          onTap: () => navigationShell.goBranch(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? MostromoTheme.accentColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected
                      ? MostromoTheme.accentColor
                      : Colors.white54,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? MostromoTheme.accentColor
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _MobileWrapper({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: navigationShell,
      ), // MOBİLDE ÇENTİKTEN KORUMAK İÇİN SAFEAREA
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: MostromoTheme.accentColor.withValues(alpha: 0.2),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined, color: Colors.white54),
            selectedIcon: Icon(
              Icons.description_rounded,
              color: MostromoTheme.accentColor,
            ),
            label: 'Notlarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Colors.white54),
            selectedIcon: Icon(
              Icons.settings,
              color: MostromoTheme.accentColor,
            ),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
