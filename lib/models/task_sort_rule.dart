import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Representa uma regra individual de ordenação com coluna e direção.
class TaskSortRule {
  final String column;
  final bool ascending;

  const TaskSortRule({
    required this.column,
    this.ascending = true,
  });

  TaskSortRule copyWith({
    String? column,
    bool? ascending,
  }) {
    return TaskSortRule(
      column: column ?? this.column,
      ascending: ascending ?? this.ascending,
    );
  }

  Map<String, dynamic> toJson() => {
        'column': column,
        'ascending': ascending,
      };

  factory TaskSortRule.fromJson(Map<String, dynamic> json) => TaskSortRule(
        column: json['column'] as String? ?? 'LOCAL',
        ascending: json['ascending'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskSortRule &&
          runtimeType == other.runtimeType &&
          column == other.column &&
          ascending == other.ascending;

  @override
  int get hashCode => column.hashCode ^ ascending.hashCode;
}

/// Serviço responsável por persistir e notificar regras de ordenação em múltiplos níveis.
class TaskSortService {
  static const String _prefsKey = 'taskflow_multi_sort_rules_v1';

  static const List<String> availableColumns = [
    'LOCAL',
    'STATUS',
    'PERÍODO',
    'TIPO',
    'TAREFA',
    'EXECUTOR',
    'COORDENADOR',
  ];

  static final TaskSortService instance = TaskSortService._internal();
  TaskSortService._internal() {
    loadRules();
  }

  List<TaskSortRule> _rules = [
    const TaskSortRule(column: 'LOCAL', ascending: true),
  ];

  final ValueNotifier<List<TaskSortRule>> rulesNotifier =
      ValueNotifier<List<TaskSortRule>>([
    const TaskSortRule(column: 'LOCAL', ascending: true),
  ]);

  List<TaskSortRule> get rules => List.unmodifiable(_rules);
  String get primaryColumn => _rules.isNotEmpty ? _rules.first.column : 'LOCAL';
  bool get primaryAscending => _rules.isNotEmpty ? _rules.first.ascending : true;

  Future<void> loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = jsonDecode(savedJson) as List<dynamic>;
        final loaded = decoded
            .map((item) => TaskSortRule.fromJson(item as Map<String, dynamic>))
            .where((r) => availableColumns.contains(r.column))
            .toList();
        if (loaded.isNotEmpty) {
          _rules = loaded;
          rulesNotifier.value = List.unmodifiable(_rules);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar regras de ordenação: $e');
    }
  }

  Future<void> saveRules(List<TaskSortRule> newRules) async {
    if (newRules.isEmpty) {
      _rules = [const TaskSortRule(column: 'LOCAL', ascending: true)];
    } else {
      _rules = List<TaskSortRule>.from(newRules);
    }
    rulesNotifier.value = List.unmodifiable(_rules);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_rules.map((r) => r.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar regras de ordenação no SharedPreferences: $e');
    }
  }

  /// Atualiza apenas a regra primária, preservando as sub-regras existentes se não entrarem em conflito.
  Future<void> setPrimaryRule(String column, bool ascending) async {
    final updated = <TaskSortRule>[
      TaskSortRule(column: column, ascending: ascending),
    ];

    // Mantém as sub-ordenações que não sejam repetidas da coluna primária
    for (int i = 1; i < _rules.length; i++) {
      if (_rules[i].column != column) {
        updated.add(_rules[i]);
      }
    }

    await saveRules(updated);
  }
}
