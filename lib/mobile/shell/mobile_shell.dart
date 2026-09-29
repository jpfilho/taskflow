import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sync_service.dart';
import '../core/theme/tf_mobile_typography.dart';
import '../core/theme/tf_mobile_colors.dart';
import '../core/theme/tf_mobile_status_colors.dart';
import '../core/widgets/tf_mobile_app_bar.dart';
import '../core/widgets/tf_mobile_offline_banner.dart';
import '../core/navigation/tf_mobile_navigator.dart';
import '../modules/home/mobile_today_screen.dart';
import '../modules/tasks/mobile_tasks_tab.dart';
import '../modules/feed/mobile_feed_screen.dart';
import '../modules/more/mobile_more_screen.dart';
import 'widgets/tf_field_quick_actions_sheet.dart';
import '../../services/connectivity_service.dart';

/// Shell principal de navegação para smartphones (Fase 2).
/// Persiste 4 abas no IndexedStack e utiliza o botão central 'Campo' como ação modal.
class TFMobileShell extends StatefulWidget {
  final VoidCallback onLogout;
  final ValueChanged<int>? onNavigateToSidebarIndex;

  const TFMobileShell({
    super.key,
    required this.onLogout,
    this.onNavigateToSidebarIndex,
  });

  @override
  State<TFMobileShell> createState() => _TFMobileShellState();
}

class _TFMobileShellState extends State<TFMobileShell> {
  int _currentTabIndex = 0; // 0: Hoje, 1: Atividades, 2: Feed, 3: Mais
  final SyncService _syncService = SyncService();
  final Set<int> _loadedTabs = {0}; // Lazy loading: carrega abas sob demanda

  late final TFMobileNavigator _navigator;

  @override
  void initState() {
    super.initState();
    _navigator = TFMobileNavigator(
      context: context,
      onSwitchTab: (tab) {
        _selectTab(tab.index);
      },
      onNavigateToSidebarIndex: widget.onNavigateToSidebarIndex,
    );
  }

  void _selectTab(int index) {
    if (index < 0 || index > 3) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentTabIndex = index;
      _loadedTabs.add(index);
    });
  }

  void _openFieldActions() {
    HapticFeedback.mediumImpact();
    TFFieldQuickActionsSheet.show(
      context: context,
      navigator: _navigator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _syncService.hasLocalChangesThisSession ? 1 : 0;
    final isOnline = ConnectivityService().isConnected;
    final isSyncing = _syncService.isSyncing;

    TFSyncStatus syncStatus;
    if (isSyncing) {
      syncStatus = TFSyncStatus.syncing;
    } else if (!isOnline) {
      syncStatus = TFSyncStatus.offline;
    } else if (pendingCount > 0) {
      syncStatus = TFSyncStatus.pending;
    } else {
      syncStatus = TFSyncStatus.synced;
    }

    return PopScope(
      canPop: _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentTabIndex != 0) {
          // No Android, se não estiver na aba Hoje, volta para Hoje antes de sair
          setState(() {
            _currentTabIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: TFMobileColors.background(context),
        appBar: _buildAppBarForTab(_currentTabIndex, syncStatus),
        body: Column(
          children: [
            // Banner Offline Contextual se houver desconexão ou pendências
            if (!isOnline || pendingCount > 0 || isSyncing)
              TFOfflineBanner(
                status: syncStatus,
                pendingCount: pendingCount,
                onSyncNow: () => _syncService.syncAll(),
              ),

            // Conteúdo Persistido das 4 Abas (Lazy loaded via IndexedStack)
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _loadedTabs.contains(0)
                      ? MobileTodayScreen(navigator: _navigator)
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(1)
                      ? MobileTasksTab(navigator: _navigator)
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(2)
                      ? MobileFeedScreen(navigator: _navigator)
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(3)
                      ? MobileMoreScreen(navigator: _navigator, onLogout: widget.onLogout)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBarForTab(int tabIndex, TFSyncStatus syncStatus) {
    switch (tabIndex) {
      case 0:
        return TFMobileAppBar(
          title: 'TaskFlow',
          subtitle: 'Central Operacional de Campo',
          syncStatus: syncStatus,
        );
      case 1:
        return TFMobileAppBar(
          title: 'Atividades',
          subtitle: 'Programação de Manutenção',
          syncStatus: syncStatus,
        );
      case 2:
        return TFMobileAppBar(
          title: 'Feed & Comunicação',
          subtitle: 'Rede Operacional de Turmas',
          syncStatus: syncStatus,
        );
      case 3:
      default:
        return TFMobileAppBar(
          title: 'Menu de Módulos',
          subtitle: 'Recursos, SAP e Engenharia',
          syncStatus: syncStatus,
        );
    }
  }

  /// Barra Inferior Ergonômica com 5 botões: [Hoje] [Atividades] [Campo (Ação)] [Feed] [Mais]
  Widget _buildBottomNavigationBar(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
            children: [
              // 1. Aba Hoje
              _buildNavButton(
                icon: Icons.calendar_today_rounded,
                label: 'Hoje',
                isSelected: _currentTabIndex == 0,
                onTap: () => _selectTab(0),
              ),

              // 2. Aba Atividades
              _buildNavButton(
                icon: Icons.assignment_rounded,
                label: 'Atividades',
                isSelected: _currentTabIndex == 1,
                onTap: () => _selectTab(1),
              ),

              // 3. Botão Central de Ação 'CAMPO' (Ação Modal, não é aba)
              Expanded(
                child: InkWell(
                  onTap: _openFieldActions,
                  borderRadius: BorderRadius.circular(20.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36.0,
                          height: 36.0,
                          decoration: const BoxDecoration(
                            color: TFMobileColors.primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x401D4ED8),
                                blurRadius: 8.0,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.construction_rounded,
                            color: Colors.white,
                            size: 20.0,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Campo',
                            style: TFMobileTypography.caption.copyWith(
                              color: TFMobileColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.0,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Aba Feed
              _buildNavButton(
                icon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                isSelected: _currentTabIndex == 2,
                onTap: () => _selectTab(2),
              ),

              // 5. Aba Mais
              _buildNavButton(
                icon: Icons.menu_rounded,
                label: 'Mais',
                isSelected: _currentTabIndex == 3,
                onTap: () => _selectTab(3),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? TFMobileColors.primaryBlue : TFMobileColors.textSecondary(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22.0, color: color),
              const SizedBox(height: 2.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TFMobileTypography.caption.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
