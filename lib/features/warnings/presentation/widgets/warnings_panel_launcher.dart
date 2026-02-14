import 'package:flutter/material.dart';
import '../../data/models/task_warning.dart';
import 'warnings_detail_panel.dart';

/// Abre o painel de alertas: drawer lateral no desktop, bottom sheet no mobile.
/// Usa addPostFrameCallback para evitar assertion no MouseTracker ao abrir durante evento de pointer.
/// [onUpdateStatus] / [onAdjustDates]: ao tocar, o caller deve fechar o painel (pop) e abrir edição.
/// [debugTaskId], [debugTaskStatus], [debugTaskStatusId]: opcionais para exibir bloco Debug no painel.
void showWarningsPanel({
  required BuildContext context,
  required String taskTarefaLabel,
  required List<TaskWarning> warnings,
  VoidCallback? onUpdateStatus,
  VoidCallback? onAdjustDates,
  VoidCallback? onSnooze,
  String? debugTaskId,
  String? debugTaskStatus,
  String? debugTaskStatusId,
}) {
  if (warnings.isEmpty) return;
  if (!context.mounted) return;

  final isNarrow = MediaQuery.of(context).size.width < 600;

  void open() {
    if (!context.mounted) return;
    final panel = WarningsDetailPanel(
      taskTarefaLabel: taskTarefaLabel,
      warnings: warnings,
      onClose: () => Navigator.of(context).pop(),
      onUpdateStatus: onUpdateStatus,
      onAdjustDates: onAdjustDates,
      onSnooze: onSnooze,
      debugTaskId: debugTaskId,
      debugTaskStatus: debugTaskStatus,
      debugTaskStatusId: debugTaskStatusId,
    );
    if (isNarrow) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => panel,
        ),
      );
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fechar alertas',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 8,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Container(
              width: 448,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: panel,
            ),
          ),
        ),
        transitionBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          );
        },
      );
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => open());
}
