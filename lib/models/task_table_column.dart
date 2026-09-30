import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum que representa as colunas disponíveis na tabela de atividades.
enum TaskTableColumn {
  acoes(
    id: 'acoes',
    label: 'Ações',
    headerTitle: 'AÇÕES',
    defaultWidth: 60,
    mobileWidth: 50,
    icon: Icons.touch_app_outlined,
    isRequired: false,
  ),
  status(
    id: 'status',
    label: 'Status',
    headerTitle: 'STATUS',
    defaultWidth: 70,
    mobileWidth: 60,
    icon: Icons.flag_outlined,
    isRequired: true,
  ),
  local(
    id: 'local',
    label: 'Local',
    headerTitle: 'LOCAL',
    defaultWidth: 90,
    mobileWidth: 80,
    icon: Icons.place_outlined,
    isRequired: false,
  ),
  tipo(
    id: 'tipo',
    label: 'Tipo',
    headerTitle: 'TIPO',
    defaultWidth: 100,
    mobileWidth: 90,
    icon: Icons.category_outlined,
    isRequired: false,
  ),
  tarefa(
    id: 'tarefa',
    label: 'Tarefa',
    headerTitle: 'TAREFA',
    defaultWidth: 184,
    mobileWidth: 150,
    icon: Icons.assignment_outlined,
    isRequired: true,
  ),
  executor(
    id: 'executor',
    label: 'Executor',
    headerTitle: 'EXECUTOR',
    defaultWidth: 150,
    mobileWidth: 120,
    icon: Icons.person_outline,
    isRequired: false,
  ),
  coordenador(
    id: 'coordenador',
    label: 'Coordenador',
    headerTitle: 'COORDENADOR',
    defaultWidth: 110,
    mobileWidth: 85,
    icon: Icons.supervisor_account_outlined,
    isRequired: false,
  ),
  frota(
    id: 'frota',
    label: 'Frota',
    headerTitle: 'FROTA',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.directions_car_outlined,
    isRequired: false,
  ),
  chat(
    id: 'chat',
    label: 'Chat',
    headerTitle: 'CHAT',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.chat_bubble_outline,
    isRequired: false,
  ),
  anexos(
    id: 'anexos',
    label: 'Anexos',
    headerTitle: 'ANEXOS',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.attach_file,
    isRequired: false,
  ),
  nota(
    id: 'nota',
    label: 'Nota SAP',
    headerTitle: 'NOTA',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.receipt_long_outlined,
    isRequired: false,
  ),
  ordem(
    id: 'ordem',
    label: 'Ordem SAP',
    headerTitle: 'ORDEM',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.build_outlined,
    isRequired: false,
  ),
  at(
    id: 'at',
    label: 'AT (Autorização)',
    headerTitle: 'AT',
    defaultWidth: 42,
    mobileWidth: 38,
    icon: Icons.security_outlined,
    isRequired: false,
  ),
  si(
    id: 'si',
    label: 'SI (Intervenção)',
    headerTitle: 'SI',
    defaultWidth: 42,
    mobileWidth: 38,
    icon: Icons.flash_on_outlined,
    isRequired: false,
  ),
  alertas(
    id: 'alertas',
    label: 'Alertas',
    headerTitle: 'ALERTAS',
    defaultWidth: 50,
    mobileWidth: 45,
    icon: Icons.warning_amber_outlined,
    isRequired: false,
  );

  final String id;
  final String label;
  final String headerTitle;
  final double defaultWidth;
  final double mobileWidth;
  final IconData icon;
  final bool isRequired;

  const TaskTableColumn({
    required this.id,
    required this.label,
    required this.headerTitle,
    required this.defaultWidth,
    required this.mobileWidth,
    required this.icon,
    this.isRequired = false,
  });

  double width(bool isMobile) => isMobile ? mobileWidth : defaultWidth;

  static TaskTableColumn? fromId(String id) {
    for (final col in TaskTableColumn.values) {
      if (col.id == id) return col;
    }
    return null;
  }
}

/// Representa um preset de configuração de colunas da tabela.
class TaskTablePreset {
  final String id;
  final String name;
  final String description;
  final Set<TaskTableColumn> columns;
  final bool isCustom;

  const TaskTablePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.columns,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'columns': columns.map((c) => c.id).toList(),
        'isCustom': isCustom,
      };

  factory TaskTablePreset.fromJson(Map<String, dynamic> json) {
    final colIds = (json['columns'] as List<dynamic>?)?.cast<String>() ?? [];
    final cols = colIds
        .map((id) => TaskTableColumn.fromId(id))
        .whereType<TaskTableColumn>()
        .toSet();
    cols.add(TaskTableColumn.status);
    cols.add(TaskTableColumn.tarefa);

    return TaskTablePreset(
      id: json['id'] as String? ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Personalizado',
      description: json['description'] as String? ?? '',
      columns: cols,
      isCustom: true,
    );
  }
}

/// Serviço responsável por carregar, salvar e notificar alterações nas colunas visíveis e presets da tabela.
class TaskTableColumnService {
  static const String _prefsKey = 'taskflow_table_visible_columns_v1';
  static const String _activePresetKey = 'taskflow_table_active_preset_v1';
  static const String _customPresetsKey = 'taskflow_table_custom_presets_v1';
  static const double safetyPadding = 32.0;

  static final TaskTableColumnService instance = TaskTableColumnService._internal();
  TaskTableColumnService._internal() {
    loadColumns();
  }

  Set<TaskTableColumn> _visibleColumns = TaskTableColumn.values.toSet();
  String _activePresetId = 'all';
  List<TaskTablePreset> _customPresets = [];

  final ValueNotifier<Set<TaskTableColumn>> columnsNotifier =
      ValueNotifier<Set<TaskTableColumn>>(TaskTableColumn.values.toSet());
  final ValueNotifier<String> activePresetNotifier = ValueNotifier<String>('all');

  Set<TaskTableColumn> get visibleColumns => _visibleColumns;
  String get activePresetId => _activePresetId;
  List<TaskTablePreset> get customPresets => List.unmodifiable(_customPresets);

  bool isVisible(TaskTableColumn col) => _visibleColumns.contains(col);

  // ── Presets do Sistema ────────────────────────────────────────────────────

  static final TaskTablePreset presetGanttFocus = TaskTablePreset(
    id: 'gantt_focus',
    name: '🎯 Foco no Gantt',
    description: 'Status, Tarefa, Executor e Ações (~496px)',
    columns: {
      TaskTableColumn.acoes,
      TaskTableColumn.status,
      TaskTableColumn.tarefa,
      TaskTableColumn.executor,
    },
  );

  static final TaskTablePreset presetOperacional = TaskTablePreset(
    id: 'operacional',
    name: '📋 Operacional',
    description: 'Status, Local, Tipo, Tarefa, Executor, Frota e Alertas (~600px)',
    columns: {
      TaskTableColumn.acoes,
      TaskTableColumn.status,
      TaskTableColumn.local,
      TaskTableColumn.tipo,
      TaskTableColumn.tarefa,
      TaskTableColumn.executor,
      TaskTableColumn.frota,
      TaskTableColumn.alertas,
    },
  );

  static final TaskTablePreset presetMinimal = TaskTablePreset(
    id: 'minimal',
    name: '⚡ Mínimo',
    description: 'Apenas Status e Tarefa (~286px)',
    columns: {
      TaskTableColumn.status,
      TaskTableColumn.tarefa,
    },
  );

  static final TaskTablePreset presetAll = TaskTablePreset(
    id: 'all',
    name: '🔍 Completo',
    description: 'Todas as 15 colunas originais (~1.030px)',
    columns: TaskTableColumn.values.toSet(),
  );

  /// Retorna todos os presets disponíveis (sistema + criados pelo usuário).
  List<TaskTablePreset> get allPresets => [
        presetGanttFocus,
        presetOperacional,
        presetMinimal,
        presetAll,
        ..._customPresets,
      ];

  // ── Persistência em SharedPreferences ─────────────────────────────────────

  Future<void> loadColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Carregar preset ativo
      final savedPresetId = prefs.getString(_activePresetKey);
      if (savedPresetId != null && savedPresetId.isNotEmpty) {
        _activePresetId = savedPresetId;
        activePresetNotifier.value = _activePresetId;
      }

      // Carregar presets customizados do usuário
      final customJson = prefs.getString(_customPresetsKey);
      if (customJson != null && customJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(customJson) as List<dynamic>;
          _customPresets = decoded
              .map((item) => TaskTablePreset.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('⚠️ Erro ao decodificar presets customizados: $e');
        }
      }

      // Carregar colunas visíveis
      final list = prefs.getStringList(_prefsKey);
      if (list != null && list.isNotEmpty) {
        final loaded = list
            .map((id) => TaskTableColumn.fromId(id))
            .whereType<TaskTableColumn>()
            .toSet();

        // Garantir que as obrigatórias sempre existam
        loaded.add(TaskTableColumn.status);
        loaded.add(TaskTableColumn.tarefa);

        _visibleColumns = loaded;
        columnsNotifier.value = Set.unmodifiable(_visibleColumns);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar colunas e presets do SharedPreferences: $e');
    }
  }

  Future<void> saveColumns(Set<TaskTableColumn> columns, {String? presetId}) async {
    final toSave = columns.toSet();
    toSave.add(TaskTableColumn.status);
    toSave.add(TaskTableColumn.tarefa);

    _visibleColumns = toSave;
    columnsNotifier.value = Set.unmodifiable(_visibleColumns);

    if (presetId != null) {
      _activePresetId = presetId;
      activePresetNotifier.value = _activePresetId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _visibleColumns.map((c) => c.id).toList(),
      );
      if (presetId != null) {
        await prefs.setString(_activePresetKey, presetId);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar colunas e preset ativo no SharedPreferences: $e');
    }
  }

  Future<void> saveCustomPreset(String name, Set<TaskTableColumn> cols) async {
    final cleanCols = cols.toSet();
    cleanCols.add(TaskTableColumn.status);
    cleanCols.add(TaskTableColumn.tarefa);

    final newPreset = TaskTablePreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: '${cleanCols.length} colunas personalizadas',
      columns: cleanCols,
      isCustom: true,
    );

    _customPresets.add(newPreset);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_customPresets.map((p) => p.toJson()).toList());
      await prefs.setString(_customPresetsKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar preset customizado no SharedPreferences: $e');
    }

    // Aplica o novo preset imediatamente
    await saveColumns(cleanCols, presetId: newPreset.id);
  }

  Future<void> deleteCustomPreset(String id) async {
    _customPresets.removeWhere((p) => p.id == id);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_customPresets.map((p) => p.toJson()).toList());
      await prefs.setString(_customPresetsKey, encoded);

      if (_activePresetId == id) {
        _activePresetId = 'all';
        activePresetNotifier.value = 'all';
        await prefs.setString(_activePresetKey, 'all');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao excluir preset customizado do SharedPreferences: $e');
    }
  }

  double calculateTotalWidth(bool isMobile, [Set<TaskTableColumn>? customCols]) {
    final cols = customCols ?? _visibleColumns;
    double total = 0;
    for (final col in TaskTableColumn.values) {
      if (cols.contains(col)) {
        total += col.width(isMobile);
      }
    }
    return total + safetyPadding;
  }
}
