import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/responsive.dart';
import '../models/task.dart';
import 'multi_select_filter_dialog.dart';

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
    _executoresTotais = [];
    _frotasTotais = [];
    _coordenadoresTotais = [];

    String _normalize(String s) => s.trim();
    void _splitAndAdd(Set<String> target, String raw) {
      if (raw.isEmpty) return;
      for (final part in raw.split(',')) {
        final v = _normalize(part);
        if (v.isNotEmpty) target.add(v);
      }
    }
    void _splitListAndAdd(Set<String> target, Iterable<String> values) {
      for (final v in values) {
        _splitAndAdd(target, v);
      }
    }

    Set<String> regionais = {};
    Set<String> divisoes = {};
    Set<String> status = {};
    Set<String> locais = {};
    Set<String> tipos = {};
    Set<String> executores = {};
    Set<String> frotas = {};
    Set<String> coordenadores = {};

    for (final t in effective) {
      if (t.regional.isNotEmpty) regionais.add(t.regional);
      if (t.divisao.isNotEmpty) divisoes.add(t.divisao);
      if (t.status.isNotEmpty) _splitAndAdd(status, t.status);
      if (t.locais.isNotEmpty) locais.addAll(t.locais.where((e) => e.isNotEmpty));
      if (t.tipo.isNotEmpty) _splitAndAdd(tipos, t.tipo); // tipos também podem vir concatenados
      if (t.executor.isNotEmpty) _splitAndAdd(executores, t.executor);
      if (t.executores.isNotEmpty) _splitListAndAdd(executores, t.executores.where((e) => e.isNotEmpty));
      if (t.frota.isNotEmpty) frotas.add(t.frota);
      if (t.coordenador.isNotEmpty) _splitAndAdd(coordenadores, t.coordenador);
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
      'status': _selectedStatus.isEmpty ? null : _selectedStatus.join(','),
      'local': _selectedLocal.isEmpty ? null : _selectedLocal.join(','),
      'tipo': _selectedTipo.isEmpty ? null : _selectedTipo.join(','),
      'executor': _selectedExecutor.isEmpty ? null : _selectedExecutor.join(','),
      'frota': _selectedFrota.isEmpty ? null : _selectedFrota.join(','),
      'coordenador': _selectedCoordenador.isEmpty ? null : _selectedCoordenador.join(','),
      'minhasTarefas': _minhasTarefas ? 'true' : null,
    };

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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterValues({bool loadTotais = false}) async {
    // Sempre que possível, use somente as tarefas visíveis (evita chamadas ao Supabase)
    _loadFromVisibleTasks();
  }

  @override
  void initState() {
    super.initState();
    // Restaurar valores dos filtros se fornecidos (multiseleção: vírgula-separado)
    if (widget.initialFilters != null) {
      _selectedRegional = _parseFilterSet(widget.initialFilters!['regional']);
      _selectedDivisao = _parseFilterSet(widget.initialFilters!['divisao']);
      _selectedStatus = _parseFilterSet(widget.initialFilters!['status']);
      _selectedLocal = _parseFilterSet(widget.initialFilters!['local']);
      _selectedTipo = _parseFilterSet(widget.initialFilters!['tipo']);
      _selectedExecutor = _parseFilterSet(widget.initialFilters!['executor']);
      _selectedFrota = _parseFilterSet(widget.initialFilters!['frota']);
      _selectedCoordenador = _parseFilterSet(widget.initialFilters!['coordenador']);
      _minhasTarefas = widget.initialFilters!['minhasTarefas'] == 'true';
    }
    // Carregar valores iniciais a partir das tarefas visíveis (se houver)
    Future.microtask(() => _loadFilterValues(loadTotais: true));
  }

  @override
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalcular sempre que props mudarem (garante sincronização com tabela atual)
    _loadFilterValues(loadTotais: true);
    // Se o período mudou, recarregar (ainda assim apenas localmente)
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadFilterValues(loadTotais: true);
    }
    // Se os filtros iniciais mudaram, restaurar os valores
    if (widget.initialFilters != null && oldWidget.initialFilters != widget.initialFilters) {
      setState(() {
        _selectedRegional = _parseFilterSet(widget.initialFilters!['regional']);
        _selectedDivisao = _parseFilterSet(widget.initialFilters!['divisao']);
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
    final isCompact = isMobile;
    
    // Sempre mostrar os filtros, mesmo durante o carregamento
    // Os dados serão atualizados em background quando chegarem
    
    if (isCompact) {
      // Contar quantos filtros estão ativos (multiseleção: conjunto não vazio)
      final activeFiltersCount = [
        _selectedRegional.isNotEmpty,
        _selectedDivisao.isNotEmpty,
        _selectedStatus.isNotEmpty,
        _selectedLocal.isNotEmpty,
        _selectedTipo.isNotEmpty,
        _selectedExecutor.isNotEmpty,
        _selectedFrota.isNotEmpty,
        _selectedCoordenador.isNotEmpty,
        _minhasTarefas,
      ].where((f) => f).length;

      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de loading
            if (widget.isFiltering)
              Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (activeFiltersCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeFiltersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Indicador de loading (mobile)
                    if (widget.isFiltering)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      ),
                    // Toggle Minhas Tarefas (sempre visível no mobile)
                    _buildMinhasTarefasToggle(),
                    // Botão para mostrar/ocultar Gantt (apenas quando o modo for 'split')
                    if (widget.onToggleGantt != null && widget.currentViewMode == 'split') ...[
                      const SizedBox(width: 8),
                      _buildGanttToggle(),
                    ],
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
                            _selectedExecutor = {};
                            _selectedFrota = {};
                            _selectedCoordenador = {};
                            _minhasTarefas = false;
                            _updateFilters();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Limpar',
                          style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
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
      // Desktop e tablet: usar todo o espaço horizontal com Expanded (altura suficiente para label + valor sem overflow)
      return Container(
        width: double.infinity,
        height: 72,
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Stack(
              children: [
                if (widget.isFiltering)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: widget.isFiltering ? 3 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSortSelector(isMobile: false),
                      const SizedBox(width: 16),
                      _buildMinhasTarefasToggle(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'REGIONAL', _regionaisTotais, _selectedRegional, (v) {
                            setState(() { _selectedRegional = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'DIVISAO', _divisoesTotais, _selectedDivisao, (v) {
                            setState(() { _selectedDivisao = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'STATUS', _statusTotais, _selectedStatus, (v) {
                            setState(() { _selectedStatus = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'LOCAL', _locaisTotais, _selectedLocal, (v) {
                            setState(() { _selectedLocal = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'TIPO', _tiposTotais, _selectedTipo, (v) {
                            setState(() { _selectedTipo = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'EXECUTOR', _executoresTotais, _selectedExecutor, (v) {
                            setState(() { _selectedExecutor = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'FROTA', _frotasTotais, _selectedFrota, (v) {
                            setState(() { _selectedFrota = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMultiSelectFilterField(
                          'COORDENADOR', _coordenadoresTotais, _selectedCoordenador, (v) {
                            setState(() { _selectedCoordenador = v; _updateFilters(); });
                          },
                          isMobile: false,
                        ),
                      ),
                    ],
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
    final padH = isMobile ? 6.0 : 10.0;
    final padV = isMobile ? 4.0 : 8.0;
    final iconSz = isMobile ? 14.0 : 20.0;
    final fontSz = isMobile ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue, width: isMobile ? 1 : 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: iconSz, color: Colors.blue[700]),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: currentSortColumn,
            isDense: !isMobile,
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
            constraints: BoxConstraints(
              minWidth: isMobile ? 20 : 28,
              minHeight: isMobile ? 20 : 28,
            ),
            tooltip: currentSortAscending ? 'Crescente' : 'Decrescente',
          ),
        ],
      ),
    );
  }

  Widget _buildMinhasTarefasToggle() {
    final isCompact = Responsive.isMobile(context);
    final padH = isCompact ? 8.0 : 12.0;
    final padV = isCompact ? 4.0 : 8.0;
    final iconSz = isCompact ? 16.0 : 20.0;
    final fontSz = isCompact ? 11.0 : 12.0;
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

  Widget _buildGanttToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            size: 16,
            color: widget.showGantt == true ? Colors.blue[700] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            widget.showGantt == true ? 'Gantt' : 'Gantt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: widget.showGantt == true ? FontWeight.bold : FontWeight.normal,
              color: widget.showGantt == true ? Colors.blue[700] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 6),
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
