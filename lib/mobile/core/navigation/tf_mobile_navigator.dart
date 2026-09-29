import 'package:flutter/material.dart';
import 'mobile_routes.dart';
import '../../modules/tasks/mobile_task_detail_screen.dart';
import '../../modules/schedule/mobile_schedule_screen.dart';
import '../../modules/schedule/models/mobile_agenda_view_mode.dart';

/// Centralizador e orquestrador de navegação interna do TaskFlow Mobile.
/// Elimina chamadas soltas de Navigator.push e garante fluxos previsíveis em smartphone.
class TFMobileNavigator {
  final BuildContext context;
  final ValueChanged<TFMobileTab>? onSwitchTab;
  final ValueChanged<int>? onNavigateToSidebarIndex;

  const TFMobileNavigator({
    required this.context,
    this.onSwitchTab,
    this.onNavigateToSidebarIndex,
  });

  /// Alterna diretamente para uma das 4 abas principais do shell.
  void goToTab(TFMobileTab tab) {
    onSwitchTab?.call(tab);
  }

  /// Navega para a aba de Atividades.
  void goToTasks() {
    goToTab(TFMobileTab.tasks);
  }

  /// Navega para a aba do Feed Corporativo.
  void goToFeed() {
    goToTab(TFMobileTab.feed);
  }

  /// Abre a tela de chat ou mensagem específica.
  void openChat({String? conversationId, String? title}) {
    goToTab(TFMobileTab.feed);
  }

  /// Navega para um módulo do sistema existente (reutilizando a lógica segura do MainScreen).
  void openLegacyModule(int sidebarIndex) {
    onNavigateToSidebarIndex?.call(sidebarIndex);
  }

  /// Abre detalhes de uma atividade operacional em tela cheia (Fase 3).
  Future<dynamic> openTaskDetail(
    String taskId, {
    String? taskTitle,
    dynamic initialTask,
  }) async {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MobileTaskDetailScreen(
          taskId: taskId,
          initialTaskTitle: taskTitle,
          initialTask: initialTask,
          navigator: this,
        ),
      ),
    );
  }

  /// Abre a tela de Programação & Agenda Mobile (Fase 4).
  Future<dynamic> openSchedule({
    DateTime? initialDate,
    MobileAgendaViewMode initialMode = MobileAgendaViewMode.timeline,
  }) async {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MobileScheduleScreen(
          initialDate: initialDate,
          initialMode: initialMode,
          navigator: this,
        ),
      ),
    );
  }

  /// Abre o preenchimento de checklist de campo.
  void openChecklist({String? activityId}) {
    openLegacyModule(11); // Índice do Checklist no TaskFlow
  }

  /// Abre preenchimento de APR (Análise Preliminar de Risco).
  void openApr({String? activityId}) {
    openLegacyModule(11);
  }

  /// Abre captura e envio de evidências fotográficas.
  void openMediaCapture({String? activityId}) {
    openLegacyModule(22); // Índice de Álbuns / Mídia
  }

  /// Abre apontamento de horas SAP.
  void openTimesheet() {
    openLegacyModule(20); // Horas SAP
  }

  /// Abre Notas SAP.
  void openNotasSap() {
    openLegacyModule(16);
  }

  /// Abre Ordens SAP.
  void openOrdensSap() {
    openLegacyModule(17);
  }

  /// Abre Demandas.
  void openDemandas() {
    openLegacyModule(3);
  }
}
