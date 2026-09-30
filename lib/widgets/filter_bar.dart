import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/responsive.dart';
import '../models/task.dart';
import 'multi_select_filter_dialog.dart';
import '../models/task_sort_rule.dart';
import 'common/task_sort_rules_dialog.dart';

class FilterBar extends StatefulWidget {
  final Function(Map<String, String?>) onFiltersChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, String?>? initialFilters; // Filtros iniciais para restaurar
  final Function(String, bool)? onSortChanged; // Callback para mudança de ordenação
  final String? currentSortColumn; // Coluna de ordenação atual
  final bool? currentSortAscending; // Direção de ordenação atual
  final bool isFiltering; // Indica se os filtros estão sendo processados
  final VoidCallback? onToggleGantt; // Callback para alternar visibilidade do Gantt
  final bool? showGantt; // Se o Gantt está visível
  final String? currentViewMode; // Modo de visualização atual
  final List<Task>? visibleTasks; // Tarefas já carregadas para preencher opções localmente
  /// Quando true, mostra apenas filtros da tela de Frota: REGIONAL, DIVISAO, SEGMENTO, FROTA.
  final bool fleetMode;
  /// Opções dos dropdowns na tela Frota (mesmos valores da tabela): regionais, divisoes, frotas, locais.
  final Map<String, List<String>>? fleetFilterOptions;
  /// Quando true, mostra apenas filtros da tela de Equipes: DIVISAO, EMPRESA, FUNÇÃO, MATRÍCULA, NOME.
  final bool teamMode;
  /// Opções dos dropdowns na tela Equipes (mesmos valores da tabela).
  final Map<String, List<String>>? teamFilterOptions;
  /// Toggle "Mostrar apenas tarefas com alerta" (tela Atividades).
  final bool? filterOnlyWithWarnings;
  /// Callback ao alterar o toggle de alertas.
  final ValueChanged<bool>? onFilterOnlyWithWarnings;
  /// Quantidade de tarefas com alerta na lista atual (exibida ao lado do toggle).
  final int? warningsCountInTable;
  /// Total de tarefas com alerta retornadas pelo RPC (para exibir "7 de 19" e deixar coerente).
  final int? warningsTotalCount;
  /// Lista de nomes de equipes disponíveis para o perfil do usuário logado.
  final List<String>? equipesDisponiveis;

  const FilterBar({
    super.key,
    required this.onFiltersChanged,
    this.startDate,
    this.endDate,
    this.initialFilters,
    this.onSortChanged,
    this.currentSortColumn,
    this.currentSortAscending,
    this.isFiltering = false,
    this.onToggleGantt,
    this.showGantt,
    this.currentViewMode,
    this.visibleTasks,
    this.fleetMode = false,
    this.fleetFilterOptions,
    this.teamMode = false,
    this.teamFilterOptions,
    this.filterOnlyWithWarnings,
    this.onFilterOnlyWithWarnings,
    this.warningsCountInTable,
    this.warningsTotalCount,
    this.equipesDisponiveis,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  Set<String> _selectedRegional = {};
  Set<String> _selectedDivisao = {};
  Set<String> _selectedStatus = {};
  Set<String> _selectedLocal = {};
  Set<String> _selectedTipo = {};
  Set<String> _selectedExecutor = {};
  Set<String> _selectedFrota = {};
  Set<String> _selectedSegmento = {}; // Modo Frota
  Set<String> _selectedPropriedade = {}; // Modo Frota
  Set<String> _selectedEmpresa = {}; // Modo Equipes
  Set<String> _selectedEquipe = {}; // Modo Equipes
  Set<String> _selectedFuncao = {}; // Modo Equipes
  Set<String> _selectedMatricula = {}; // Modo Equipes
  Set<String> _selectedNome = {}; // Modo Equipes
  Set<String> _selectedCoordenador = {};
  Map<String, String?> _lastSentFilters = {};
  Timer? _debounceTimer;
  bool _isExpanded = false; // Para mobile: controla se os filtros estão expandidos
  bool _minhasTarefas = false; // Toggle para filtrar apenas minhas tarefas
  
  // Opções de ordenação disponíveis
  final List<String> _sortOptions = [
    'PERÍODO',
    'STATUS',
    'LOCAL',
    'TIPO',
    'TAREFA',
    'EXECUTOR',
    'COORDENADOR',
  ];
  
  // Valores totais possíveis para cada filtro (para multiseleção com pesquisa)
  List<String> _regionaisTotais = [];
  List<String> _divisoesTotais = [];
  List<String> _statusTotais = [];
  List<String> _locaisTotais = [];
  List<String> _tiposTotais = [];
  List<String> _executoresTotais = [];
  List<String> _frotasTotais = [];
  List<String> _segmentosTotais = []; // Usado no modo Frota (após DIVISAO)
  List<String> _propriedadesTotais = []; // Usado no modo Frota
  List<String> _empresasTotais = []; // Modo Equipes
  List<String> _equipesTotais = []; // Modo Equipes
  List<String> _funcoesTotais = []; // Modo Equipes
  List<String> _matriculasTotais = []; // Modo Equipes
  List<String> _nomesTotais = []; // Modo Equipes
  List<String> _coordenadoresTotais = [];
  
  void _loadFromVisibleTasks() {
    final tasks = widget.visibleTasks;

    // Sempre recalcular (inclusive para lista vazia) para refletir exatamente a tabela atual
    List<Task> effective = tasks ?? const [];

    // Restringir às tarefas dentro do período selecionado (como na tabela)
    if (widget.startDate != null || widget.endDate != null) {
      final start = widget.startDate;
      final end = widget.endDate;

      bool overlaps(DateTime aStart, DateTime aEnd) {
        if (start != null && aEnd.isBefore(DateTime(start.year, start.month, start.day))) return false;
        if (end != null && aStart.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59))) return false;
        return true;
      }

      effective = effective.where((t) {
        if (t.ganttSegments.isNotEmpty) {
          return t.ganttSegments.any((seg) => overlaps(seg.dataInicio, seg.dataFim));
        }
        return overlaps(t.dataInicio, t.dataFim);
      }).toList();
    }

    _regionaisTotais = [];
    _divisoesTotais = [];
    _statusTotais = [];
    _locaisTotais = [];
    _tiposTotais = [];
    _equipesTotais = [];
    _executoresTotais = [];
    _frotasTotais = [];
    _coordenadoresTotais = [];

    String normalize(String s) => s.trim();
    void splitAndAdd(Set<String> target, String raw) {
      if (raw.isEmpty) return;
      for (final part in raw.split(',')) {
        final v = normalize(part);
        if (v.isNotEmpty) target.add(v);
      }
    }
    void splitListAndAdd(Set<String> target, Iterable<String> values) {
      for (final v in values) {
        splitAndAdd(target, v);
      }
    }

    Set<String> regionais = {};
    Set<String> divisoes = {};
    Set<String> status = {};
    Set<String> locais = {};
    Set<String> tipos = {};
    Set<String> equipes = {};
    Set<String> executores = {};
    Set<String> frotas = {};
    Set<String> coordenadores = {};

    for (final t in effective) {
      if (t.regional.isNotEmpty) regionais.add(t.regional);
      if (t.divisao.isNotEmpty) divisoes.add(t.divisao);
      if (t.status.isNotEmpty) splitAndAdd(status, t.status);
      if (t.locais.isNotEmpty) locais.addAll(t.locais.where((e) => e.isNotEmpty));
      if (t.tipo.isNotEmpty) splitAndAdd(tipos, t.tipo); // tipos também podem vir concatenados
      if (t.equipes.isNotEmpty) splitListAndAdd(equipes, t.equipes.where((e) => e.isNotEmpty));
      if (t.executor.isNotEmpty) splitAndAdd(executores, t.executor);
      if (t.executores.isNotEmpty) splitListAndAdd(executores, t.executores.where((e) => e.isNotEmpty));
      if (t.frota.isNotEmpty) frotas.add(t.frota);
      if (t.coordenador.isNotEmpty) splitAndAdd(coordenadores, t.coordenador);
    }

    // Se fornecido via widget.equipesDisponiveis (escopo perfil do usuário), usar prioritariamente
    if (widget.equipesDisponiveis != null && widget.equipesDisponiveis!.isNotEmpty) {
      equipes.addAll(widget.equipesDisponiveis!);
    }

    List<String> sortSet(Set<String> s) {
      final list = s.toList();
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return list;
    }

    _regionaisTotais = sortSet(regionais);
    _divisoesTotais = sortSet(divisoes);
    _statusTotais = sortSet(status);
    _locaisTotais = sortSet(locais);
    _tiposTotais = sortSet(tipos);
    _equipesTotais = sortSet(equipes);
    _executoresTotais = sortSet(executores);
    _frotasTotais = sortSet(frotas);
    _coordenadoresTotais = sortSet(coordenadores);

    if (mounted) setState(() {});
  }

  static Set<String> _parseFilterSet(String? value) {
    if (value == null || value.trim().isEmpty) return {};
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  void _updateFilters() {
    final current = <String, String?>{
      'regional': _selectedRegional.isEmpty ? null : _selectedRegional.join(','),
      'divisao': _selectedDivisao.isEmpty ? null : _selectedDivisao.join(','),
      'empresa': widget.teamMode ? (_selectedEmpresa.isEmpty ? null : _selectedEmpresa.join(',')) : null,
      'equipe': _selectedEquipe.isEmpty ? null : _selectedEquipe.join(','),
      'funcao': widget.teamMode ? (_selectedFuncao.isEmpty ? null : _selectedFuncao.join(',')) : null,
      'matricula': widget.teamMode ? (_selectedMatricula.isEmpty ? null : _selectedMatricula.join(',')) : null,
      'nome': widget.teamMode ? (_selectedNome.isEmpty ? null : _selectedNome.join(',')) : null,
      'segmento': widget.fleetMode ? (_selectedSegmento.isEmpty ? null : _selectedSegmento.join(',')) : null,
      'propriedade': widget.fleetMode ? (_selectedPropriedade.isEmpty ? null : _selectedPropriedade.join(',')) : null,
      'status': widget.fleetMode ? null : (_selectedStatus.isEmpty ? null : _selectedStatus.join(',')),
      'local': widget.fleetMode ? null : (_selectedLocal.isEmpty ? null : _selectedLocal.join(',')),
      'tipo': _selectedTipo.isEmpty ? null : _selectedTipo.join(','),
      'executor': _selectedExecutor.isEmpty ? null : _selectedExecutor.join(','),
      'frota': _selectedFrota.isEmpty ? null : _selectedFrota.join(','),
      'coordenador': (_selectedCoordenador.isEmpty ? null : _selectedCoordenador.join(',')),
      'minhasTarefas': widget.fleetMode ? null : (_minhasTarefas ? 'true' : null),
    };
    if (widget.fleetMode) {
      current.removeWhere((k, v) => !['regional', 'divisao', 'segmento', 'propriedade', 'tipo', 'frota', 'equipe', 'executor', 'coordenador'].contains(k));
    }
    if (widget.teamMode) {
      current.removeWhere((k, v) => !['divisao', 'empresa', 'equipe', 'executor', 'funcao', 'matricula', 'nome', 'coordenador'].contains(k));
    }

    // Evitar disparar processamento se nada mudou
    bool changed = false;
    for (final key in current.keys) {
      if (_lastSentFilters[key] != current[key]) {
        changed = true;
        break;
      }
    }
    if (!changed) return;

    _lastSentFilters = Map.from(current);
    // Debounce para evitar reprocessar quando seleciona e volta rápido
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      widget.onFiltersChanged(current);
    });
  }

  Widget _buildFleetFilterRow(bool isMobile) {
    final activeCount = [
      _selectedRegional.isNotEmpty,
      _selectedDivisao.isNotEmpty,
      _selectedSegmento.isNotEmpty,
      _selectedPropriedade.isNotEmpty,
      _selectedTipo.isNotEmpty,
      _selectedFrota.isNotEmpty,
      _selectedEquipe.isNotEmpty,
      _selectedExecutor.isNotEmpty,
      _selectedCoordenador.isNotEmpty,
    ].where((f) => f).length;
    
    const double barHeight = 72.0;
    
    return Container(
      width: double.infinity,
      height: barHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1450;

          final regionalField = _buildTeamFilterField(
            'REGIONAL', 
            _regionaisTotais, 
            _selectedRegional, 
            (v) {
              setState(() { _selectedRegional = v; _updateFilters(); });
            }
          );

          final divisaoField = _buildTeamFilterField(
            'DIVISÃO', 
            _divisoesTotais, 
            _selectedDivisao, 
            (v) {
              setState(() { _selectedDivisao = v; _updateFilters(); });
            }
          );

          final segmentoField = _buildTeamFilterField(
            'SEGMENTO', 
            _segmentosTotais, 
            _selectedSegmento, 
            (v) {
              setState(() { _selectedSegmento = v; _updateFilters(); });
            }
          );

          final propriedadeField = _buildTeamFilterField(
            'PROPRIEDADE', 
            _propriedadesTotais, 
            _selectedPropriedade, 
            (v) {
              setState(() { _selectedPropriedade = v; _updateFilters(); });
            }
          );

          final tipoField = _buildTeamFilterField(
            'TIPO', 
            _tiposTotais, 
            _selectedTipo, 
            (v) {
              setState(() { _selectedTipo = v; _updateFilters(); });
            }
          );

          final frotaField = _buildTeamFilterField(
            'FROTA', 
            _frotasTotais, 
            _selectedFrota, 
            (v) {
              setState(() { _selectedFrota = v; _updateFilters(); });
            }
          );

          final equipeField = _buildTeamFilterField(
            'EQUIPE', 
            _equipesTotais, 
            _selectedEquipe, 
            (v) {
              setState(() { _selectedEquipe = v; _updateFilters(); });
            }
          );

          final executorField = _buildTeamFilterField(
            'EXECUTOR', 
            _executoresTotais, 
            _selectedExecutor, 
            (v) {
              setState(() { _selectedExecutor = v; _updateFilters(); });
            }
          );

          final coordenadorField = _buildTeamFilterField(
            'COORDENADOR', 
            _coordenadoresTotais, 
            _selectedCoordenador, 
            (v) {
              setState(() { _selectedCoordenador = v; _updateFilters(); });
            }
          );

          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 120, child: regionalField),
                  const SizedBox(width: 6),
                  SizedBox(width: 120, child: divisaoField),
                  const SizedBox(width: 6),
                  SizedBox(width: 120, child: segmentoField),
                  const SizedBox(width: 6),
                  SizedBox(width: 120, child: propriedadeField),
                  const SizedBox(width: 6),
                  SizedBox(width: 120, child: tipoField),
                  const SizedBox(width: 6),
                  SizedBox(width: 140, child: frotaField),
                  const SizedBox(width: 6),
                  SizedBox(width: 125, child: equipeField),
                  const SizedBox(width: 6),
                  SizedBox(width: 135, child: executorField),
                  const SizedBox(width: 6),
                  SizedBox(width: 135, child: coordenadorField),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildClearButton(activeCount),
                  ],
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: regionalField),
              const SizedBox(width: 6),
              Expanded(child: divisaoField),
              const SizedBox(width: 6),
              Expanded(child: segmentoField),
              const SizedBox(width: 6),
              Expanded(child: propriedadeField),
              const SizedBox(width: 6),
              Expanded(child: tipoField),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: frotaField),
              const SizedBox(width: 6),
              Expanded(child: equipeField),
              const SizedBox(width: 6),
              Expanded(child: executorField),
              const SizedBox(width: 6),
              Expanded(child: coordenadorField),
              if (activeCount > 0) ...[
                const SizedBox(width: 8),
                _buildClearButton(activeCount),
              ],
            ],
          );
        },
      ),
    );
  }

  void _clearFleetFilters() {
    setState(() {
      _selectedRegional = {};
      _selectedDivisao = {};
      _selectedSegmento = {};
      _selectedPropriedade = {};
      _selectedTipo = {};
      _selectedFrota = {};
      _selectedEquipe = {};
      _selectedExecutor = {};
      _selectedCoordenador = {};
      _updateFilters();
    });
  }

  Widget _buildTeamFilterRow(bool isMobile) {
    final activeCount = [
      _selectedDivisao.isNotEmpty,
      _selectedEmpresa.isNotEmpty,
      _selectedEquipe.isNotEmpty,
      _selectedExecutor.isNotEmpty,
      _selectedFuncao.isNotEmpty,
      _selectedMatricula.isNotEmpty,
      _selectedNome.isNotEmpty,
      _selectedCoordenador.isNotEmpty,
    ].where((f) => f).length;
    
    const double barHeight = 72.0;
    
    return Container(
      width: double.infinity,
      height: barHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1250;
          final searchWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[600], size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar...',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(fontSize: 12),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) {
                      setState(() {
                        _selectedNome = v.trim().isEmpty ? {} : {v.trim()};
                        _updateFilters();
                      });
                    },
                  ),
                ),
              ],
            ),
          );

          final divisaoField = _buildTeamFilterField(
            'DIVISÃO', 
            _divisoesTotais, 
            _selectedDivisao, 
            (v) {
              setState(() { _selectedDivisao = v; _updateFilters(); });
            }
          );

          final empresaField = _buildTeamFilterField(
            'EMPRESA', 
            _empresasTotais, 
            _selectedEmpresa, 
            (v) {
              setState(() { _selectedEmpresa = v; _updateFilters(); });
            }
          );

          final equipeField = _buildTeamFilterField(
            'EQUIPE', 
            _equipesTotais, 
            _selectedEquipe, 
            (v) {
              setState(() { _selectedEquipe = v; _updateFilters(); });
            }
          );

          final executorField = _buildTeamFilterField(
            'EXECUTOR', 
            _executoresTotais, 
            _selectedExecutor, 
            (v) {
              setState(() { _selectedExecutor = v; _updateFilters(); });
            }
          );

          final funcaoField = _buildTeamFilterField(
            'FUNÇÃO', 
            _funcoesTotais, 
            _selectedFuncao, 
            (v) {
              setState(() { _selectedFuncao = v; _updateFilters(); });
            }
          );

          final matriculaField = _buildTeamFilterField(
            'MATRÍCULA', 
            _matriculasTotais, 
            _selectedMatricula, 
            (v) {
              setState(() { _selectedMatricula = v; _updateFilters(); });
            }
          );

          final coordenadorField = _buildTeamFilterField(
            'COORDENADOR', 
            _coordenadoresTotais, 
            _selectedCoordenador, 
            (v) {
              setState(() { _selectedCoordenador = v; _updateFilters(); });
            }
          );

          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 170, child: searchWidget),
                  const SizedBox(width: 8),
                  SizedBox(width: 115, child: divisaoField),
                  const SizedBox(width: 6),
                  SizedBox(width: 115, child: empresaField),
                  const SizedBox(width: 6),
                  SizedBox(width: 115, child: equipeField),
                  const SizedBox(width: 6),
                  SizedBox(width: 125, child: executorField),
                  const SizedBox(width: 6),
                  SizedBox(width: 115, child: funcaoField),
                  const SizedBox(width: 6),
                  SizedBox(width: 115, child: matriculaField),
                  const SizedBox(width: 6),
                  SizedBox(width: 125, child: coordenadorField),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildClearButton(activeCount),
                  ],
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: searchWidget),
              const SizedBox(width: 10),
              Expanded(child: divisaoField),
              const SizedBox(width: 6),
              Expanded(child: empresaField),
              const SizedBox(width: 6),
              Expanded(child: equipeField),
              const SizedBox(width: 6),
              Expanded(child: executorField),
              const SizedBox(width: 6),
              Expanded(child: funcaoField),
              const SizedBox(width: 6),
              Expanded(child: matriculaField),
              const SizedBox(width: 6),
              Expanded(child: coordenadorField),
              if (activeCount > 0) ...[
                const SizedBox(width: 8),
                _buildClearButton(activeCount),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTeamFilterField(
    String label, 
    List<String> options, 
    Set<String> selectedValues, 
    ValueChanged<Set<String>> onChanged
  ) {
    final hasSelection = selectedValues.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasSelection ? Colors.blue[600]! : Colors.grey[300]!,
          width: hasSelection ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => MultiSelectFilterDialog(
              title: label,
              options: options,
              selectedValues: selectedValues,
              onSelectionChanged: onChanged,
              searchHint: 'Pesquisar $label...',
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      selectedValues.isEmpty
                          ? 'Todos'
                          : selectedValues.length == 1
                              ? selectedValues.first
                              : '${selectedValues.length} itens',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasSelection ? Colors.blue[800] : Colors.black87,
                        fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton(int count) {
    return Center(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDivisao = {};
            _selectedEmpresa = {};
            _selectedEquipe = {};
            _selectedExecutor = {};
            _selectedFuncao = {};
            _selectedMatricula = {};
            _selectedNome = {};
            _selectedCoordenador = {};
            _updateFilters();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_off, size: 16, color: Colors.red[700]),
              const SizedBox(width: 6),
              Text(
                'Limpar ($count)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSortRulesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    TaskSortService.instance.rulesNotifier.removeListener(_onSortRulesChanged);
    super.dispose();
  }

  void _applyFleetFilterOptions() {
    final opts = widget.fleetFilterOptions;
    if (opts == null) return;
    _regionaisTotais = List.from(opts['regionals'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _divisoesTotais = List.from(opts['divisoes'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _segmentosTotais = List.from(opts['segmentos'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (opts['propriedades'] != null) {
      _propriedadesTotais = List.from(opts['propriedades']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    if (opts['tipos'] != null) {
      _tiposTotais = List.from(opts['tipos']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    _frotasTotais = List.from(opts['frotas'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (opts['equipes'] != null) {
      _equipesTotais = List.from(opts['equipes']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    if (opts['executores'] != null) {
      _executoresTotais = List.from(opts['executores']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    if (opts['coordenadores'] != null) {
      _coordenadoresTotais = List.from(opts['coordenadores']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
  }

  void _applyTeamFilterOptions() {
    final opts = widget.teamFilterOptions;
    if (opts == null) return;
    _divisoesTotais = List.from(opts['divisoes'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _empresasTotais = List.from(opts['empresas'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (opts['equipes'] != null) {
      _equipesTotais = List.from(opts['equipes']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    if (opts['executores'] != null) {
      _executoresTotais = List.from(opts['executores']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    _funcoesTotais = List.from(opts['funcoes'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _matriculasTotais = List.from(opts['matriculas'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _nomesTotais = List.from(opts['nomes'] ?? [])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (opts['coordenadores'] != null) {
      _coordenadoresTotais = List.from(opts['coordenadores']!)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
  }

  Future<void> _loadFilterValues({bool loadTotais = false}) async {
    if (widget.fleetMode) {
      if (widget.fleetFilterOptions != null) {
        _applyFleetFilterOptions();
      }
      if (mounted) setState(() {});
      return;
    }
    if (widget.teamMode) {
      if (widget.teamFilterOptions != null) {
        _applyTeamFilterOptions();
      }
      if (mounted) setState(() {});
      return;
    }
    _loadFromVisibleTasks();
  }

  @override
  void initState() {
    super.initState();
    // Restaurar valores dos filtros se fornecidos (multiseleção: vírgula-separado)
    if (widget.initialFilters != null) {
      _selectedRegional = _parseFilterSet(widget.initialFilters!['regional']);
      _selectedDivisao = _parseFilterSet(widget.initialFilters!['divisao']);
      _selectedSegmento = _parseFilterSet(widget.initialFilters!['segmento']);
      _selectedEmpresa = _parseFilterSet(widget.initialFilters!['empresa']);
      _selectedEquipe = _parseFilterSet(widget.initialFilters!['equipe']);
      _selectedFuncao = _parseFilterSet(widget.initialFilters!['funcao']);
      _selectedMatricula = _parseFilterSet(widget.initialFilters!['matricula']);
      _selectedNome = _parseFilterSet(widget.initialFilters!['nome']);
      _selectedStatus = _parseFilterSet(widget.initialFilters!['status']);
      _selectedLocal = _parseFilterSet(widget.initialFilters!['local']);
      _selectedTipo = _parseFilterSet(widget.initialFilters!['tipo']);
      _selectedExecutor = _parseFilterSet(widget.initialFilters!['executor']);
      _selectedFrota = _parseFilterSet(widget.initialFilters!['frota']);
      _selectedCoordenador = _parseFilterSet(widget.initialFilters!['coordenador']);
      _minhasTarefas = widget.initialFilters!['minhasTarefas'] == 'true';
      _lastSentFilters = Map.from(widget.initialFilters!);
    }
    if (widget.fleetMode && widget.fleetFilterOptions != null) {
      _applyFleetFilterOptions();
    }
    if (widget.teamMode && widget.teamFilterOptions != null) {
      _applyTeamFilterOptions();
    }
    TaskSortService.instance.rulesNotifier.addListener(_onSortRulesChanged);
    // Carregar valores iniciais a partir das tarefas visíveis (se houver)
    Future.microtask(() => _loadFilterValues(loadTotais: true));
  }

  @override
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fleetMode && widget.fleetFilterOptions != null) {
      _applyFleetFilterOptions();
    }
    if (widget.teamMode && widget.teamFilterOptions != null) {
      _applyTeamFilterOptions();
    }
    _loadFilterValues(loadTotais: true);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadFilterValues(loadTotais: true);
    }
    if (widget.initialFilters != null && oldWidget.initialFilters != widget.initialFilters) {
      setState(() {
        _selectedRegional = _parseFilterSet(widget.initialFilters!['regional']);
        _selectedDivisao = _parseFilterSet(widget.initialFilters!['divisao']);
        _selectedSegmento = _parseFilterSet(widget.initialFilters!['segmento']);
        _selectedEmpresa = _parseFilterSet(widget.initialFilters!['empresa']);
        _selectedEquipe = _parseFilterSet(widget.initialFilters!['equipe']);
        _selectedFuncao = _parseFilterSet(widget.initialFilters!['funcao']);
        _selectedMatricula = _parseFilterSet(widget.initialFilters!['matricula']);
        _selectedNome = _parseFilterSet(widget.initialFilters!['nome']);
        _selectedStatus = _parseFilterSet(widget.initialFilters!['status']);
        _selectedLocal = _parseFilterSet(widget.initialFilters!['local']);
        _selectedTipo = _parseFilterSet(widget.initialFilters!['tipo']);
        _selectedExecutor = _parseFilterSet(widget.initialFilters!['executor']);
        _selectedFrota = _parseFilterSet(widget.initialFilters!['frota']);
        _selectedCoordenador = _parseFilterSet(widget.initialFilters!['coordenador']);
        _minhasTarefas = widget.initialFilters!['minhasTarefas'] == 'true';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    // Apenas mobile usa layout compacto (expandível); tablet e desktop usam barra completa
    final isCompact = isMobile && !widget.fleetMode;

    if (widget.fleetMode) {
      return _buildFleetFilterRow(isMobile);
    }
    if (widget.teamMode) {
      return _buildTeamFilterRow(isMobile);
    }
    
    // Sempre mostrar os filtros, mesmo durante o carregamento
    // Os dados serão atualizados em background quando chegarem
    
    if (isCompact) {
      // Contar quantos filtros estão ativos (multiseleção: conjunto não vazio; não inclui Minhas Tarefas)
      final activeFiltersCount = [
        _selectedRegional.isNotEmpty,
        _selectedDivisao.isNotEmpty,
        _selectedStatus.isNotEmpty,
        _selectedLocal.isNotEmpty,
        _selectedTipo.isNotEmpty,
        _selectedEquipe.isNotEmpty,
        _selectedExecutor.isNotEmpty,
        _selectedFrota.isNotEmpty,
        _selectedCoordenador.isNotEmpty,
        widget.filterOnlyWithWarnings == true,
      ].where((f) => f).length;

      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de loading
            if (widget.isFiltering)
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            // Botão para expandir/colapsar
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Esquerda: ordenação e toggles (gaps uniformes)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSortSelector(isMobile: true),
                        const SizedBox(width: 8),
                        _buildMinhasTarefasToggle(label: false),
                        if (widget.onFilterOnlyWithWarnings != null) ...[
                          const SizedBox(width: 8),
                          _buildAlertasToggle(label: false),
                        ],
                        if (widget.onToggleGantt != null && widget.currentViewMode == 'split') ...[
                          const SizedBox(width: 8),
                          _buildGanttToggle(),
                        ],
                      ],
                    ),
                    // Direita: filtro, indicador e limpar (gaps uniformes)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Filtros',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (activeFiltersCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$activeFiltersCount',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (widget.isFiltering)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (activeFiltersCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRegional = {};
                                _selectedDivisao = {};
                                _selectedStatus = {};
                                _selectedLocal = {};
                                _selectedTipo = {};
                                _selectedEquipe = {};
                                _selectedExecutor = {};
                                _selectedFrota = {};
                                _selectedCoordenador = {};
                                _minhasTarefas = false;
                                widget.onFilterOnlyWithWarnings?.call(false);
                                _updateFilters();
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Limpar',
                              style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Filtros expansíveis
            if (_isExpanded)
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Toggle Minhas Tarefas removido daqui pois já está no cabeçalho
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.8,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                    _buildMultiSelectFilterField('REGIONAL', _regionaisTotais, _selectedRegional, (v) {
                      setState(() { _selectedRegional = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('DIVISAO', _divisoesTotais, _selectedDivisao, (v) {
                      setState(() { _selectedDivisao = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('STATUS', _statusTotais, _selectedStatus, (v) {
                      setState(() { _selectedStatus = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('LOCAL', _locaisTotais, _selectedLocal, (v) {
                      setState(() { _selectedLocal = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('TIPO', _tiposTotais, _selectedTipo, (v) {
                      setState(() { _selectedTipo = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('EQUIPE', _equipesTotais, _selectedEquipe, (v) {
                      setState(() { _selectedEquipe = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('EXECUTOR', _executoresTotais, _selectedExecutor, (v) {
                      setState(() { _selectedExecutor = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('FROTA', _frotasTotais, _selectedFrota, (v) {
                      setState(() { _selectedFrota = v; _updateFilters(); });
                    }, isMobile: true),
                    _buildMultiSelectFilterField('COORDENADOR', _coordenadoresTotais, _selectedCoordenador, (v) {
                      setState(() { _selectedCoordenador = v; _updateFilters(); });
                    }, isMobile: true),
                      ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Desktop e tablet: usar todo o espaço horizontal com Expanded
      final activeFiltersCount = [
        _selectedRegional.isNotEmpty,
        _selectedDivisao.isNotEmpty,
        _selectedStatus.isNotEmpty,
        _selectedLocal.isNotEmpty,
        _selectedTipo.isNotEmpty,
        _selectedEquipe.isNotEmpty,
        _selectedExecutor.isNotEmpty,
        _selectedFrota.isNotEmpty,
        _selectedCoordenador.isNotEmpty,
        widget.filterOnlyWithWarnings == true,
      ].where((f) => f).length;

      return Container(
        width: double.infinity,
        height: 72,
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Stack(
              children: [
                if (widget.isFiltering)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: widget.isFiltering ? 3 : 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isNarrow = constraints.maxWidth < 1500;

                      final sortField = _buildSortSelector(isMobile: false);
                      final minhasTarefasField = _buildMinhasTarefasToggle(label: false);
                      final alertasField = widget.onFilterOnlyWithWarnings != null
                          ? _buildAlertasToggle(label: false)
                          : null;

                      final regionalField = _buildMultiSelectFilterField(
                        'REGIONAL', _regionaisTotais, _selectedRegional, (v) {
                          setState(() { _selectedRegional = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final divisaoField = _buildMultiSelectFilterField(
                        'DIVISAO', _divisoesTotais, _selectedDivisao, (v) {
                          setState(() { _selectedDivisao = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final statusField = _buildMultiSelectFilterField(
                        'STATUS', _statusTotais, _selectedStatus, (v) {
                          setState(() { _selectedStatus = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final localField = _buildMultiSelectFilterField(
                        'LOCAL', _locaisTotais, _selectedLocal, (v) {
                          setState(() { _selectedLocal = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final tipoField = _buildMultiSelectFilterField(
                        'TIPO', _tiposTotais, _selectedTipo, (v) {
                          setState(() { _selectedTipo = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final equipeField = _buildMultiSelectFilterField(
                        'EQUIPE', _equipesTotais, _selectedEquipe, (v) {
                          setState(() { _selectedEquipe = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final executorField = _buildMultiSelectFilterField(
                        'EXECUTOR', _executoresTotais, _selectedExecutor, (v) {
                          setState(() { _selectedExecutor = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final frotaField = _buildMultiSelectFilterField(
                        'FROTA', _frotasTotais, _selectedFrota, (v) {
                          setState(() { _selectedFrota = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      final coordenadorField = _buildMultiSelectFilterField(
                        'COORDENADOR', _coordenadoresTotais, _selectedCoordenador, (v) {
                          setState(() { _selectedCoordenador = v; _updateFilters(); });
                        },
                        isMobile: false,
                      );

                      Widget? clearButton;
                      if (activeFiltersCount > 0) {
                        clearButton = Center(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRegional = {};
                                _selectedDivisao = {};
                                _selectedStatus = {};
                                _selectedLocal = {};
                                _selectedTipo = {};
                                _selectedEquipe = {};
                                _selectedExecutor = {};
                                _selectedFrota = {};
                                _selectedCoordenador = {};
                                _minhasTarefas = false;
                                widget.onFilterOnlyWithWarnings?.call(false);
                                _updateFilters();
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red[200]!, width: 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.filter_alt_off, size: 13, color: Colors.red[700]),
                                      const SizedBox(width: 3),
                                      // Badge com contagem
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.red[600],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$activeFiltersCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Limpar',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (isNarrow) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sortField,
                              const SizedBox(width: 12),
                              minhasTarefasField,
                              if (alertasField != null) ...[
                                const SizedBox(width: 12),
                                alertasField,
                              ],
                              const SizedBox(width: 12),
                              SizedBox(width: 120, child: regionalField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: divisaoField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: statusField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: localField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: tipoField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: equipeField),
                              const SizedBox(width: 8),
                              SizedBox(width: 125, child: executorField),
                              const SizedBox(width: 8),
                              SizedBox(width: 120, child: frotaField),
                              const SizedBox(width: 8),
                              SizedBox(width: 125, child: coordenadorField),
                              if (clearButton != null) ...[
                                const SizedBox(width: 10),
                                clearButton,
                              ],
                            ],
                          ),
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          sortField,
                          const SizedBox(width: 12),
                          minhasTarefasField,
                          if (alertasField != null) ...[
                            const SizedBox(width: 12),
                            alertasField,
                          ],
                          const SizedBox(width: 12),
                          Expanded(child: regionalField),
                          const SizedBox(width: 8),
                          Expanded(child: divisaoField),
                          const SizedBox(width: 8),
                          Expanded(child: statusField),
                          const SizedBox(width: 8),
                          Expanded(child: localField),
                          const SizedBox(width: 8),
                          Expanded(child: tipoField),
                          const SizedBox(width: 8),
                          Expanded(child: equipeField),
                          const SizedBox(width: 8),
                          Expanded(child: executorField),
                          const SizedBox(width: 8),
                          Expanded(child: frotaField),
                          const SizedBox(width: 8),
                          Expanded(child: coordenadorField),
                          if (clearButton != null) ...[
                            const SizedBox(width: 10),
                            clearButton,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
    }
  }



  Widget _buildMultiSelectFilterField(
    String label,
    List<String> options,
    Set<String> selectedValues,
    ValueChanged<Set<String>> onChanged, {
    bool isMobile = false,
  }) {
    final hasSelection = selectedValues.isNotEmpty;
    final horizontalPad = isMobile ? 6.0 : 12.0;
    // Desktop: padding vertical menor para caber na barra (evitar overflow)
    final verticalPad = isMobile ? 6.0 : 6.0;
    final fontSize = isMobile ? 9.0 : 11.0;
    final labelSize = isMobile ? 7.0 : 9.0;
    final iconSize = isMobile ? 14.0 : 20.0;
    return Container(
      constraints: isMobile ? null : const BoxConstraints(minWidth: 56),
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hasSelection ? Colors.blue : Colors.grey[300]!, width: isMobile ? 1 : 1.2),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => MultiSelectFilterDialog(
              title: label,
              options: options,
              selectedValues: selectedValues,
              onSelectionChanged: (newValues) {
                onChanged(newValues);
              },
              searchHint: 'Pesquisar...',
            ),
          );
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelSize,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 2 : 3),
                  Text(
                    selectedValues.isEmpty
                        ? 'Todos'
                        : selectedValues.length == 1
                            ? selectedValues.first
                            : '${selectedValues.length} selecionado(s)',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: selectedValues.isEmpty ? Colors.grey[600] : Colors.black,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, size: iconSize, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSelector({bool isMobile = false}) {
    final currentSortColumn = widget.currentSortColumn ?? 'PERÍODO';
    final currentSortAscending = widget.currentSortAscending ?? true;
    if (isMobile) {
      // Versão ultra-compacta: ícone abre popup com colunas e toggle de ordem.
      return PopupMenuButton<String>(
        icon: Icon(Icons.sort, size: 18, color: Colors.blue[700]),
        padding: EdgeInsets.zero,
        itemBuilder: (context) => [
          ..._sortOptions.map(
            (o) => PopupMenuItem<String>(
              value: o,
              child: Text(
                o,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '__multi_sort__',
            child: Row(
              children: [
                Icon(
                  Icons.low_priority_rounded,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  TaskSortService.instance.rules.length > 1
                      ? 'Sub-ordenações (${TaskSortService.instance.rules.length} níveis)...'
                      : 'Sub-ordenações...',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: '__toggle_order__',
            child: Row(
              children: [
                Icon(
                  currentSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  currentSortAscending ? 'Ordem: Crescente' : 'Ordem: Decrescente',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == '__multi_sort__') {
            TaskSortRulesDialog.show(context, isMobile: true);
          } else if (value == '__toggle_order__') {
            widget.onSortChanged?.call(currentSortColumn, !currentSortAscending);
          } else {
            widget.onSortChanged?.call(value, currentSortAscending);
          }
        },
      );
    }

    // Versão desktop/tablet permanece mais completa.
    final padH = 10.0;
    final padV = 8.0;
    const iconSz = 20.0;
    const fontSz = 12.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: iconSz, color: Colors.blue[700]),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: currentSortColumn,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: TextStyle(
              fontSize: fontSz,
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
            items: _sortOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && widget.onSortChanged != null) {
                widget.onSortChanged!(value, currentSortAscending);
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              currentSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: iconSz,
              color: Colors.blue[700],
            ),
            onPressed: () {
              if (widget.onSortChanged != null) {
                widget.onSortChanged!(currentSortColumn, !currentSortAscending);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: currentSortAscending ? 'Crescente' : 'Decrescente',
          ),
          Container(
            height: 16,
            width: 1,
            color: Colors.blue.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Tooltip(
            message: TaskSortService.instance.rules.length > 1
                ? 'Sub-ordenações ativas (${TaskSortService.instance.rules.length} níveis configurados)'
                : 'Configurar sub-ordenações (desempates em múltiplos níveis)',
            child: InkWell(
              onTap: () => TaskSortRulesDialog.show(context, isMobile: isMobile),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.low_priority_rounded,
                      size: iconSz,
                      color: Colors.blue[700],
                    ),
                    if (TaskSortService.instance.rules.length > 1) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${TaskSortService.instance.rules.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinhasTarefasToggle({bool label = true}) {
    final isCompact = Responsive.isMobile(context);
    final padH = isCompact ? 6.0 : 10.0;
    final padV = isCompact ? 3.0 : 6.0;
    final iconSz = isCompact ? 14.0 : 18.0;
    final fontSz = isCompact ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: _minhasTarefas ? Colors.blue[100] : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _minhasTarefas ? Colors.blue : Colors.grey[300]!,
          width: _minhasTarefas ? 2 : 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: iconSz,
            color: _minhasTarefas ? Colors.blue[700] : Colors.grey[600],
          ),
          if (label) ...[
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              'Minhas Tarefas',
              style: TextStyle(
                fontSize: fontSz,
                fontWeight: _minhasTarefas ? FontWeight.bold : FontWeight.normal,
                color: _minhasTarefas ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
            SizedBox(width: isCompact ? 6 : 8),
          ] else
            SizedBox(width: isCompact ? 4 : 6),
          Switch(
            value: _minhasTarefas,
            onChanged: (value) {
              setState(() {
                _minhasTarefas = value;
                _updateFilters();
              });
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  /// Apenas a quantidade (número) de tarefas com alerta na tabela.
  Widget _buildAlertasCountText({required bool value, required double fontSz}) {
    final count = widget.warningsCountInTable ?? 0;
    final textStyle = TextStyle(
      fontSize: fontSz,
      fontWeight: value ? FontWeight.bold : FontWeight.normal,
      color: value ? Colors.orange[700] : Colors.grey[700],
    );
    return Text('$count', style: textStyle);
  }

  Widget _buildAlertasToggle({bool label = true}) {
    final isCompact = Responsive.isMobile(context);
    final padH = isCompact ? 6.0 : 10.0;
    final padV = isCompact ? 3.0 : 6.0;
    final iconSz = isCompact ? 14.0 : 18.0;
    final fontSz = isCompact ? 10.0 : 11.0;
    final value = widget.filterOnlyWithWarnings ?? false;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: value ? Colors.orange[100] : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? Colors.orange : Colors.grey[300]!,
          width: value ? 2 : 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: iconSz,
            color: value ? Colors.orange[700] : Colors.grey[600],
          ),
          SizedBox(width: isCompact ? 4 : 6),
          _buildAlertasCountText(value: value, fontSz: fontSz),
          SizedBox(width: isCompact ? 6 : 8),
          Switch(
            value: value,
            onChanged: (v) => widget.onFilterOnlyWithWarnings?.call(v),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildGanttToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: widget.showGantt == true ? Colors.blue[100] : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.showGantt == true ? Colors.blue : Colors.grey[300]!,
          width: widget.showGantt == true ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.showGantt == true ? Icons.timeline : Icons.timeline_outlined,
            size: 14,
            color: widget.showGantt == true ? Colors.blue[700] : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Switch(
            value: widget.showGantt ?? false,
            onChanged: (value) {
              widget.onToggleGantt?.call();
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
