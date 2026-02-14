import 'package:flutter/material.dart';
import '../config/app_menu_config.dart';
import '../services/auth_service_simples.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';

// Cores do launcher (referência Task & Maintenance Launcher)
const _kPrimaryLauncher = Color(0xFF1132D4);
const _kBackgroundLight = Color(0xFFF6F6F8);
const _kBackgroundDark = Color(0xFF101322);

/// Cores por tile (índice % length): container bg e ícone
final _kTileColors = [
  (_kPrimaryLauncher, _kPrimaryLauncher),
  (const Color(0xFFDBEAFE), const Color(0xFF2563EB)), // blue
  (const Color(0xFFE0E7FF), const Color(0xFF4F46E5)), // indigo
  (const Color(0xFFD1FAE5), const Color(0xFF059669)), // emerald
  (const Color(0xFFFEF3C7), const Color(0xFFD97706)), // amber
  (const Color(0xFFFCE7F3), const Color(0xFFDB2777)), // rose
  (const Color(0xFFCCFBF1), const Color(0xFF0D9488)), // teal
  (const Color(0xFFEDE9FE), const Color(0xFF7C3AED)), // violet
];

/// Tela inicial de atalhos no mobile (estilo launcher).
/// Layout inspirado em Task & Maintenance Launcher: header com saudação, card de alertas, grid 2 colunas, bottom nav.
class HomeShortcutsScreen extends StatelessWidget {
  final ValueChanged<int> onShortcutTap;
  /// Quantidade de alertas críticos (opcional). Se > 0, exibe card de alertas.
  final int? criticalAlertsCount;

  const HomeShortcutsScreen({
    super.key,
    required this.onShortcutTap,
    this.criticalAlertsCount,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = AppMenuConfig.getVisibleItemsForCurrentUser();
    final user = AuthServiceSimples().currentUser;
    final displayName = _displayName(user?.nome, user?.email);
    final barBg = ThemeService.getBarBackgroundColorSync(currentTheme);
    final primary = _kPrimaryLauncher;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      body: Stack(
        children: [
          // Background sutil (blur circles)
          Positioned(
            top: -96,
            right: -96,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.15),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: -128,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.08),
                    blurRadius: 100,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Bem-vindo + nome + avatar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bem-vindo de volta,',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Olá, $displayName!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primary.withOpacity(0.3),
                            width: 2,
                          ),
                          color: barBg.withOpacity(0.9),
                        ),
                        child: Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card de alertas (quando há contagem)
                if (criticalAlertsCount != null && criticalAlertsCount! > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Material(
                      color: primary.withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onShortcutTap(9),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ALERTAS CRÍTICOS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: primary,
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'Você tem '),
                                    TextSpan(
                                      text: '$criticalAlertsCount pendências',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                    const TextSpan(
                                        text:
                                            ' que precisam de atenção imediata.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Título da seção
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'MÓDULOS DO SISTEMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Grid 2 colunas
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: allItems.length,
                      itemBuilder: (context, i) {
                        final item = allItems[i];
                        final colors = _kTileColors[i % _kTileColors.length];
                        return _LauncherTile(
                          label: item.label,
                          icon: item.icon,
                          tileColor: colors.$1,
                          iconColor: colors.$2,
                          badgeCount: item.index == 0 && criticalAlertsCount != null && criticalAlertsCount! > 0
                              ? criticalAlertsCount
                              : null,
                          onTap: () => onShortcutTap(item.index),
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          // Bottom navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: (isDark ? _kBackgroundDark : Colors.white)
                    .withOpacity(0.9),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: true,
                    primary: primary,
                  ),
                  _NavItem(
                    icon: Icons.search_rounded,
                    label: 'Buscar',
                    onTap: () => onShortcutTap(0),
                    primary: primary,
                  ),
                  _NavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Avisos',
                    badge: criticalAlertsCount != null && criticalAlertsCount! > 0,
                    onTap: () => onShortcutTap(9),
                    primary: primary,
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Perfil',
                    onTap: () => onShortcutTap(14),
                    primary: primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(String? nome, String? email) {
    if (nome != null && nome.trim().isNotEmpty) {
      final parts = nome.trim().split(RegExp(r'\s+'));
      return parts.first;
    }
    if (email != null && email.isNotEmpty) {
      final part = email.split('@').first;
      if (part.isNotEmpty) {
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }
    }
    return 'Usuário';
  }
}

class _LauncherTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final int? badgeCount;
  final VoidCallback onTap;
  final bool isDark;

  const _LauncherTile({
    required this.label,
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    this.badgeCount,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool badge;
  final Color primary;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.badge = false,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.white54 : Colors.grey),
                ),
                if (badge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF101322)
                              : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? primary
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
