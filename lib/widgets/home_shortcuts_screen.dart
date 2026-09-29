import 'package:flutter/material.dart';
import '../config/app_menu_config.dart';
import '../services/auth_service_simples.dart';
import '../design_system/taskflow_design_system.dart';
import 'perfil_usuario_view.dart';

/// Cores corporativas específicas por módulo (garantindo contraste e legibilidade perfeita)
Color _getModuleColor(int index, TFSemanticColors colors) {
  switch (index) {
    case 0:
      return colors.primary; // Programação / Atividades
    case 1:
      return const Color(0xFF4F46E5); // Equipe (Indigo)
    case 2:
      return const Color(0xFF0D9488); // Frota (Teal)
    case 20:
      return colors.success; // Horas SAP (Verde)
    case 27:
      return colors.warning; // Confirmação de Ordens (Âmbar)
    case 16:
      return const Color(0xFF7C3AED); // Notas SAP (Violeta)
    case 17:
      return const Color(0xFF1D4ED8); // Ordens (Azul Marinho)
    case 18:
      return const Color(0xFF2563EB); // ATs
    case 19:
      return const Color(0xFFEA580C); // SIs (Laranja)
    case 15:
      return const Color(0xFF0284C7); // Chat (Sky)
    case 23:
      return const Color(0xFFDB2777); // Mídia (Pink)
    case 26:
      return colors.danger; // Bugs e Melhorias (Vermelho)
    default:
      return colors.primary;
  }
}

/// Subtítulo funcional e contextual de cada módulo
String _getModuleSubtitle(int index) {
  switch (index) {
    case 0:
      return 'Gantt & Tarefas';
    case 1:
      return 'Escala & Recursos';
    case 2:
      return 'Veículos & Controle';
    case 20:
      return 'Apontamento SAP';
    case 27:
      return 'Conferência Ordens';
    case 16:
      return 'Notas de Manutenção';
    case 17:
      return 'Ordens de Serviço';
    case 18:
      return 'Autorizações Trab.';
    case 19:
      return 'Solicitações Interv.';
    case 15:
      return 'Canais & Mensagens';
    case 23:
      return 'Álbuns de Imagens';
    case 26:
      return 'Chamados & Suporte';
    case 14:
      return 'Preferências';
    default:
      return 'Gestão Operacional';
  }
}

/// Tela inicial de atalhos no mobile em total conformidade com o TaskFlow Design System.
/// Substitui os fundos com blur e cards genéricos por superfícies flat + border oficiais.
class HomeShortcutsScreen extends StatelessWidget {
  final void Function(int index, {String? viewMode, int? selectedTab}) onShortcutTap;
  /// Quantidade de alertas críticos (opcional). Se > 0, exibe card de alertas.
  final int? criticalAlertsCount;

  const HomeShortcutsScreen({
    super.key,
    required this.onShortcutTap,
    this.criticalAlertsCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final allItems = AppMenuConfig.getVisibleItemsForCurrentUser();
    final user = AuthServiceSimples().currentUser;
    final displayName = _displayName(user?.nome, user?.email);
    final isRoot = user?.isRoot ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header institucional com design limpo do TaskFlow
            Container(
              padding: EdgeInsets.fromLTRB(spacing.lg, spacing.lg, spacing.lg, spacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  // Avatar elegante com borda e inicial
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: TFRadius.borderRadiusMd,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                        style: typography.cardTitle.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  // Saudação e Papel do Usuário
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $displayName!',
                          style: typography.pageTitle.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRoot
                                    ? colors.danger.withValues(alpha: 0.12)
                                    : colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isRoot ? 'ADMINISTRADOR ROOT' : 'OPERADOR',
                                style: typography.labelSmall.copyWith(
                                  color: isRoot ? colors.danger : colors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            const TFSyncIndicator(
                              state: TFSyncState.online,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Ação rápida: Perfil
                  IconButton(
                    icon: Icon(Icons.account_circle_outlined, color: colors.textSecondary, size: 26),
                    tooltip: 'Meu Perfil',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PerfilUsuarioView()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Conteúdo scrollável com os atalhos
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(spacing.lg, spacing.lg, spacing.lg, 100),
                children: [
                  // Card de Alertas Críticos (quando houver)
                  if (criticalAlertsCount != null && criticalAlertsCount! > 0) ...[
                    TFCard(
                      variant: TFCardVariant.interactive,
                      onTap: () => onShortcutTap(9),
                      padding: EdgeInsets.all(spacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(spacing.sm),
                            decoration: BoxDecoration(
                              color: colors.danger.withValues(alpha: 0.12),
                              borderRadius: TFRadius.borderRadiusSm,
                            ),
                            child: Icon(TFIcons.warning, color: colors.danger, size: 22),
                          ),
                          SizedBox(width: spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PENDÊNCIAS CRÍTICAS',
                                  style: typography.labelSmall.copyWith(
                                    color: colors.danger,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$criticalAlertsCount atividades requerem atenção imediata.',
                                  style: typography.bodySmall.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(TFIcons.chevronRight, color: colors.textMuted, size: 18),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                  ],

                  // Título da Seção
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MÓDULOS OPERACIONAIS',
                        style: typography.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${allItems.length} disponíveis',
                        style: typography.labelSmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),

                  // Grid de Módulos Operacionais com TFCard oficial
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: allItems.length,
                    itemBuilder: (context, i) {
                      final item = allItems[i];
                      final moduleColor = _getModuleColor(item.index, colors);
                      final subtitle = _getModuleSubtitle(item.index);
                      final hasAlert = item.index == 0 && criticalAlertsCount != null && criticalAlertsCount! > 0;

                      return TFCard(
                        variant: TFCardVariant.interactive,
                        onTap: () => onShortcutTap(item.index),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Linha superior: Ícone com fundo temático + badge opcional
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: moduleColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: moduleColor,
                                    size: 20,
                                  ),
                                ),
                                if (hasAlert)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.danger,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$criticalAlertsCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    TFIcons.chevronRight,
                                    color: colors.textMuted.withValues(alpha: 0.5),
                                    size: 16,
                                  ),
                              ],
                            ),
                            // Informações do Módulo
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: typography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  style: typography.labelSmall.copyWith(
                                    color: colors.textMuted,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Barra de navegação inferior corporativa do TaskFlow
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.borderSubtle),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavButton(
                  icon: Icons.home_rounded,
                  label: 'Início',
                  isSelected: true,
                  colors: colors,
                  typography: typography,
                  onTap: () {},
                ),
                _NavButton(
                  icon: Icons.grid_view_rounded,
                  label: 'Programação',
                  isSelected: false,
                  colors: colors,
                  typography: typography,
                  onTap: () => onShortcutTap(0),
                ),
                _NavButton(
                  icon: Icons.dynamic_feed_rounded,
                  label: 'Feed',
                  isSelected: false,
                  colors: colors,
                  typography: typography,
                  onTap: () => onShortcutTap(0, viewMode: 'feed', selectedTab: 4),
                ),
                _NavButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  isSelected: false,
                  colors: colors,
                  typography: typography,
                  onTap: () => onShortcutTap(15),
                ),
                _NavButton(
                  icon: Icons.settings_rounded,
                  label: 'Config',
                  isSelected: false,
                  colors: colors,
                  typography: typography,
                  onTap: () => onShortcutTap(14),
                ),
              ],
            ),
          ),
        ),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final TFSemanticColors colors;
  final TFTypography typography;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = colors.primary;
    final inactiveColor = colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: typography.labelSmall.copyWith(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
