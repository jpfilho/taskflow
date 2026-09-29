import 'package:flutter/material.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import 'mobile_task_list_screen.dart';

/// Host da aba Atividades dentro do MobileShell.
/// Delega a exibição para a nova tela operacional de Atividades (Fase 3).
class MobileTasksTab extends StatelessWidget {
  final TFMobileNavigator navigator;

  const MobileTasksTab({
    super.key,
    required this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    return MobileTaskListScreen(navigator: navigator);
  }
}
