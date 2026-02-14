import 'package:flutter/material.dart';
import '../services/auth_service_simples.dart';
import '../modules/gtd/domain/gtd_session.dart';

/// Regras de visibilidade do menu conforme usuário logado.
/// Usado pelo Sidebar e pela tela de atalhos (Home Shortcuts) para exibir
/// apenas os itens permitidos ao usuário atual.
class MenuVisibility {
  final bool isRoot;
  final bool showGtd;
  final bool showGtdAndSupressao;

  const MenuVisibility({
    required this.isRoot,
    required this.showGtd,
    required this.showGtdAndSupressao,
  });

  /// Fonte única: mesmo critério do Sidebar (root, GTD/Supressão para usuários autorizados).
  static MenuVisibility getForCurrentUser() {
    final user = AuthServiceSimples().currentUser;
    return MenuVisibility(
      isRoot: user?.isRoot ?? false,
      showGtd: GtdSession.canAccessGtd,
      showGtdAndSupressao: GtdSession.canAccessGtd,
    );
  }
}

/// Item do menu principal (Sidebar + Home Shortcuts).
/// Centraliza ícone, rótulo e índice para evitar duplicação.
class AppMenuItem {
  final int index;
  final String label;
  final IconData icon;
  /// Visível apenas para usuário root.
  final bool forRootOnly;
  /// Visível quando showGtd é true (ex: GTD).
  final bool forGtdOnly;
  /// Visível quando showGtdAndSupressao é true (ex: Supressão de Vegetação).
  final bool forGtdAndSupressaoOnly;

  const AppMenuItem({
    required this.index,
    required this.label,
    required this.icon,
    this.forRootOnly = false,
    this.forGtdOnly = false,
    this.forGtdAndSupressaoOnly = false,
  });

  bool isVisible({required bool isRoot, required bool showGtd, required bool showGtdAndSupressao}) {
    if (forRootOnly && !isRoot) return false;
    if (forGtdOnly && !showGtd) return false;
    if (forGtdAndSupressaoOnly && !showGtdAndSupressao) return false;
    return true;
  }
}

/// Lista central de itens do menu (Sidebar e Home Shortcuts).
/// Ordem e visibilidade alinhados ao Sidebar.
class AppMenuConfig {
  static const List<AppMenuItem> allItems = [
    AppMenuItem(index: 0, label: 'Programação', icon: Icons.grid_view),
    AppMenuItem(index: 1, label: 'Equipe', icon: Icons.people),
    AppMenuItem(index: 2, label: 'Frota', icon: Icons.directions_car),
    AppMenuItem(index: 20, label: 'Horas', icon: Icons.access_time),
    AppMenuItem(index: 4, label: 'Dashboard', icon: Icons.dashboard, forRootOnly: true),
    AppMenuItem(index: 5, label: 'Documento', icon: Icons.description, forRootOnly: true),
    AppMenuItem(index: 6, label: 'Lista', icon: Icons.list, forRootOnly: true),
    AppMenuItem(index: 7, label: 'Gráfico', icon: Icons.pie_chart, forRootOnly: true),
    AppMenuItem(index: 8, label: 'Avançar', icon: Icons.arrow_forward, forRootOnly: true),
    AppMenuItem(index: 9, label: 'Alertas', icon: Icons.notifications_active, forRootOnly: true),
    AppMenuItem(index: 10, label: 'Histórico', icon: Icons.history, forRootOnly: true),
    AppMenuItem(index: 12, label: 'Checklist', icon: Icons.checklist, forRootOnly: true),
    AppMenuItem(index: 13, label: 'Custos', icon: Icons.attach_money, forRootOnly: true),
    AppMenuItem(index: 16, label: 'Notas SAP', icon: Icons.description),
    AppMenuItem(index: 17, label: 'Ordens', icon: Icons.list_alt),
    AppMenuItem(index: 18, label: 'ATs', icon: Icons.assignment),
    AppMenuItem(index: 19, label: 'SIs', icon: Icons.description),
    AppMenuItem(index: 3, label: 'Demandas', icon: Icons.checklist_rtl, forRootOnly: true),
    AppMenuItem(index: 21, label: 'Linhas de Transmissão', icon: Icons.alt_route, forRootOnly: true),
    AppMenuItem(index: 22, label: 'Supressão de Vegetação', icon: Icons.eco, forGtdAndSupressaoOnly: true),
    AppMenuItem(index: 24, label: 'Documentos', icon: Icons.folder, forRootOnly: true),
    AppMenuItem(index: 23, label: 'Álbuns de Imagens', icon: Icons.photo_library),
    AppMenuItem(index: 25, label: 'GTD', icon: Icons.check_circle_outline, forGtdOnly: true),
    AppMenuItem(index: 26, label: 'Melhorias e Bugs', icon: Icons.bug_report),
    // Chat e Configuração (índices 14 e 15 no Sidebar são acionados pelo HeaderBar)
    AppMenuItem(index: 15, label: 'Chat', icon: Icons.chat),
    AppMenuItem(index: 14, label: 'Configurações', icon: Icons.settings),
  ];

  /// Retorna itens visíveis para o usuário (mesma regra do Sidebar).
  static List<AppMenuItem> getVisibleItems({
    required bool isRoot,
    required bool showGtd,
    required bool showGtdAndSupressao,
  }) {
    return allItems.where((e) => e.isVisible(
      isRoot: isRoot,
      showGtd: showGtd,
      showGtdAndSupressao: showGtdAndSupressao,
    )).toList();
  }

  /// Itens visíveis para o usuário logado (usa MenuVisibility.getForCurrentUser).
  /// Use este método para garantir que Sidebar e atalhos sigam as mesmas regras.
  static List<AppMenuItem> getVisibleItemsForCurrentUser() {
    final v = MenuVisibility.getForCurrentUser();
    return getVisibleItems(
      isRoot: v.isRoot,
      showGtd: v.showGtd,
      showGtdAndSupressao: v.showGtdAndSupressao,
    );
  }
}
