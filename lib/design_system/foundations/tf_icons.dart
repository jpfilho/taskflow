import 'package:flutter/material.dart';

/// Catálogo padronizado de ícones por intenção de uso no TaskFlow Design System.
/// Evita a dispersão de múltiplos ícones concorrentes para a mesma ação.
abstract class TFIcons {
  // Ações CRUD
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData save = Icons.check_rounded;
  static const IconData cancel = Icons.close_rounded;
  static const IconData close = Icons.close_rounded;

  // Busca e Filtros
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData filterActive = Icons.filter_alt_rounded;
  static const IconData clear = Icons.clear_rounded;

  // Ciclo de Vida e Sincronização
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData sync = Icons.sync_rounded;
  static const IconData syncProblem = Icons.sync_problem_rounded;
  static const IconData offline = Icons.cloud_off_rounded;

  // Comunicação e Arquivos
  static const IconData chat = Icons.chat_bubble_outline_rounded;
  static const IconData attachment = Icons.attach_file_rounded;
  static const IconData upload = Icons.upload_file_rounded;
  static const IconData download = Icons.download_rounded;

  // Navegação e Informações
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData more = Icons.more_vert_rounded;
  static const IconData moreHorizontal = Icons.more_horiz_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronDown = Icons.expand_more_rounded;

  // Severidades e Feedback
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData info = Icons.info_outline_rounded;

  // Módulos Especiais
  static const IconData ai = Icons.auto_awesome_rounded;
  static const IconData sap = Icons.description_outlined;
  static const IconData task = Icons.task_alt_rounded;
  static const IconData team = Icons.people_outline_rounded;
  static const IconData fleet = Icons.directions_car_outlined;
}
