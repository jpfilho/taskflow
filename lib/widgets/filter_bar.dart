import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/task_service.dart';

class FilterBar extends StatefulWidget {
  final Function(Map<String, String?>) onFiltersChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, String?>? initialFilters; // Filtros iniciais para restaurar
  final Function(String, bool)? onSortChanged; // Callback para mudança de ordenação
  final String? currentSortColumn; // Coluna de ordenação atual
  final bool? currentSortAscending; // Direção de ordenação atual
  final bool isFiltering; // Indica se os filtros estão sendo processados

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
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  String? _selectedRegional;
  String? _selectedDivisao;
  String? _selectedStatus;
  String? _selectedLocal;
  String? _selectedTipo;
  String? _selectedExecutor;
  String? _selectedFrota;
  String? _selectedCoordenador;
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
  
  // Valores disponíveis para cada filtro (com resultados)
  List<String> _regionais = [];
  List<String> _divisoes = [];
  List<String> _status = [];
  List<String> _locais = [];
  List<String> _tipos = [];
  List<String> _executores = [];
  List<String> _frotas = [];
  List<String> _coordenadores = [];
  
  // Valores totais possíveis (para mostrar opções sem resultados em cinza)
  List<String> _regionaisTotais = [];
  List<String> _divisoesTotais = [];
  List<String> _statusTotais = [];
  List<String> _locaisTotais = [];
  List<String> _tiposTotais = [];
  List<String> _executoresTotais = [];
  List<String> _frotasTotais = [];
  List<String> _coordenadoresTotais = [];
  
  final TaskService _taskService = TaskService();

  void _updateFilters() {
    widget.onFiltersChanged({
      'regional': _selectedRegional,
      'divisao': _selectedDivisao,
      'status': _selectedStatus,
      'local': _selectedLocal,
      'tipo': _selectedTipo,
      'executor': _selectedExecutor,
      'frota': _selectedFrota,
      'coordenador': _selectedCoordenador,
      'minhasTarefas': _minhasTarefas ? 'true' : null,
    });
    
    // Recarregar valores filtrados após alteração (mantendo valores totais)
    _loadFilterValues(loadTotais: false);
  }

  Future<void> _loadFilterValues({bool loadTotais = false}) async {
    if (widget.startDate == null || widget.endDate == null) return;
    
    // Não bloquear a UI - carregar em background
    // setState(() {
    //   _isLoading = true;
    // });

    try {
      // Carregar valores totais (sem filtros) na primeira vez ou quando solicitado
      if (loadTotais || _regionaisTotais.isEmpty) {
        final totalValues = await _taskService.getFilterValues(
          dataInicioMin: widget.startDate,
          dataFimMax: widget.endDate,
        );
        
        if (mounted) {
          setState(() {
            _regionaisTotais = totalValues['regionais'] ?? [];
            _divisoesTotais = totalValues['divisoes'] ?? [];
            _statusTotais = totalValues['status'] ?? [];
            _locaisTotais = totalValues['locais'] ?? [];
            _tiposTotais = totalValues['tipos'] ?? [];
            _executoresTotais = totalValues['executores'] ?? [];
            _frotasTotais = totalValues['frotas'] ?? [];
            _coordenadoresTotais = totalValues['coordenadores'] ?? [];
          });
        }
      }
      
      // Carregar valores filtrados (com filtros ativos)
      final filterValues = await _taskService.getFilterValues(
        dataInicioMin: widget.startDate,
        dataFimMax: widget.endDate,
        status: _selectedStatus,
        regional: _selectedRegional,
        divisao: _selectedDivisao,
        local: _selectedLocal,
        tipo: _selectedTipo,
        executor: _selectedExecutor,
        coordenador: _selectedCoordenador,
        frota: _selectedFrota,
      );

      if (mounted) {
        setState(() {
          _regionais = filterValues['regionais'] ?? [];
          _divisoes = filterValues['divisoes'] ?? [];
          _status = filterValues['status'] ?? [];
          _locais = filterValues['locais'] ?? [];
          _tipos = filterValues['tipos'] ?? [];
          _executores = filterValues['executores'] ?? [];
          _frotas = filterValues['frotas'] ?? [];
          _coordenadores = filterValues['coordenadores'] ?? [];
          
          // Limpar valores selecionados que não estão mais na lista
          if (_selectedRegional != null && !_regionais.contains(_selectedRegional)) {
            _selectedRegional = null;
          }
          if (_selectedDivisao != null && !_divisoes.contains(_selectedDivisao)) {
            _selectedDivisao = null;
          }
          if (_selectedStatus != null && !_status.contains(_selectedStatus)) {
            _selectedStatus = null;
          }
          if (_selectedLocal != null && !_locais.contains(_selectedLocal)) {
            _selectedLocal = null;
          }
          if (_selectedTipo != null && !_tipos.contains(_selectedTipo)) {
            _selectedTipo = null;
          }
          if (_selectedExecutor != null && !_executores.contains(_selectedExecutor)) {
            _selectedExecutor = null;
          }
          if (_selectedFrota != null && !_frotas.contains(_selectedFrota)) {
            _selectedFrota = null;
          }
          if (_selectedCoordenador != null && !_coordenadores.contains(_selectedCoordenador)) {
            _selectedCoordenador = null;
          }
        });
      }
    } catch (e) {
      print('Erro ao carregar valores de filtros: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Restaurar valores dos filtros se fornecidos
    if (widget.initialFilters != null) {
      _selectedRegional = widget.initialFilters!['regional'];
      _selectedDivisao = widget.initialFilters!['divisao'];
      _selectedStatus = widget.initialFilters!['status'];
      _selectedLocal = widget.initialFilters!['local'];
      _selectedTipo = widget.initialFilters!['tipo'];
      _selectedExecutor = widget.initialFilters!['executor'];
      _selectedFrota = widget.initialFilters!['frota'];
      _selectedCoordenador = widget.initialFilters!['coordenador'];
      _minhasTarefas = widget.initialFilters!['minhasTarefas'] == 'true';
    }
    // Sempre carregar valores totais no início
    _loadFilterValues(loadTotais: true);
  }

  @override
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o período mudou, recarregar valores totais e filtrados
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadFilterValues(loadTotais: true);
    }
    // Se os filtros iniciais mudaram, restaurar os valores
    if (widget.initialFilters != null && oldWidget.initialFilters != widget.initialFilters) {
      setState(() {
        _selectedRegional = widget.initialFilters!['regional'];
        _selectedDivisao = widget.initialFilters!['divisao'];
        _selectedStatus = widget.initialFilters!['status'];
        _selectedLocal = widget.initialFilters!['local'];
        _selectedTipo = widget.initialFilters!['tipo'];
        _selectedExecutor = widget.initialFilters!['executor'];
        _selectedFrota = widget.initialFilters!['frota'];
        _selectedCoordenador = widget.initialFilters!['coordenador'];
        _minhasTarefas = widget.initialFilters!['minhasTarefas'] == 'true';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    // Sempre mostrar os filtros, mesmo durante o carregamento
    // Os dados serão atualizados em background quando chegarem
    
    if (isMobile) {
      // Contar quantos filtros estão ativos
      final activeFiltersCount = [
        _selectedRegional,
        _selectedDivisao,
        _selectedStatus,
        _selectedLocal,
        _selectedTipo,
        _selectedExecutor,
        _selectedFrota,
        _selectedCoordenador,
        if (_minhasTarefas) 'minhasTarefas',
      ].where((f) => f != null).length;

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
                    const SizedBox(width: 8),
                    if (activeFiltersCount > 0)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRegional = null;
                            _selectedDivisao = null;
                            _selectedStatus = null;
                            _selectedLocal = null;
                            _selectedTipo = null;
                            _selectedExecutor = null;
                            _selectedFrota = null;
                            _selectedCoordenador = null;
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
                    // Toggle Minhas Tarefas
                    _buildMinhasTarefasToggle(),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.8,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                    _buildFilterDropdown('REGIONAL', _regionais, _selectedRegional, (value) {
                      setState(() {
                        _selectedRegional = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('DIVISAO', _divisoes, _selectedDivisao, (value) {
                      setState(() {
                        _selectedDivisao = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('STATUS', _status, _selectedStatus, (value) {
                      setState(() {
                        _selectedStatus = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('LOCAL', _locais, _selectedLocal, (value) {
                      setState(() {
                        _selectedLocal = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('TIPO', _tipos, _selectedTipo, (value) {
                      setState(() {
                        _selectedTipo = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('EXECUTOR', _executores, _selectedExecutor, (value) {
                      setState(() {
                        _selectedExecutor = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('FROTA', _frotas, _selectedFrota, (value) {
                      setState(() {
                        _selectedFrota = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                    _buildFilterDropdown('COORDENADOR', _coordenadores, _selectedCoordenador, (value) {
                      setState(() {
                        _selectedCoordenador = value;
                        _updateFilters();
                      });
                    }, isMobile: true),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (isTablet) {
      return Container(
        height: 110,
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Indicador de loading (tablet)
            if (widget.isFiltering)
              Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  // Seletor de Ordenação e Toggle Minhas Tarefas
                  Row(
                    children: [
                      Expanded(child: _buildSortSelector(isMobile: false)),
                      const SizedBox(width: 8),
                      _buildMinhasTarefasToggle(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildFilterDropdown('REGIONAL', _regionais, _selectedRegional, (value) {
                          setState(() {
                            _selectedRegional = value;
                            _updateFilters();
                          });
                        }, totalOptions: _regionaisTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('DIVISAO', _divisoes, _selectedDivisao, (value) {
                          setState(() {
                            _selectedDivisao = value;
                            _updateFilters();
                          });
                        }, totalOptions: _divisoesTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('STATUS', _status, _selectedStatus, (value) {
                          setState(() {
                            _selectedStatus = value;
                            _updateFilters();
                          });
                        }, totalOptions: _statusTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('LOCAL', _locais, _selectedLocal, (value) {
                          setState(() {
                            _selectedLocal = value;
                            _updateFilters();
                          });
                        }, totalOptions: _locaisTotais)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildFilterDropdown('TIPO', _tipos, _selectedTipo, (value) {
                          setState(() {
                            _selectedTipo = value;
                            _updateFilters();
                          });
                        }, totalOptions: _tiposTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('EXECUTOR', _executores, _selectedExecutor, (value) {
                          setState(() {
                            _selectedExecutor = value;
                            _updateFilters();
                          });
                        }, totalOptions: _executoresTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('FROTA', _frotas, _selectedFrota, (value) {
                          setState(() {
                            _selectedFrota = value;
                            _updateFilters();
                          });
                        }, totalOptions: _frotasTotais)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterDropdown('COORDENADOR', _coordenadores, _selectedCoordenador, (value) {
                          setState(() {
                            _selectedCoordenador = value;
                            _updateFilters();
                          });
                        }, totalOptions: _coordenadoresTotais)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 60,
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(
          children: [
            // Indicador de loading (desktop - no topo)
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
            // Conteúdo dos filtros
            Padding(
              padding: EdgeInsets.only(top: widget.isFiltering ? 3 : 0),
              child: Row(
          children: [
            // Seletor de Ordenação (desktop)
            _buildSortSelector(isMobile: false),
            const SizedBox(width: 12),
            // Toggle Minhas Tarefas
            _buildMinhasTarefasToggle(),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('REGIONAL', _regionais, _selectedRegional, (value) {
              setState(() {
                _selectedRegional = value;
                _updateFilters();
              });
            }, totalOptions: _regionaisTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('DIVISAO', _divisoes, _selectedDivisao, (value) {
              setState(() {
                _selectedDivisao = value;
                _updateFilters();
              });
            }, totalOptions: _divisoesTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('STATUS', _status, _selectedStatus, (value) {
              setState(() {
                _selectedStatus = value;
                _updateFilters();
              });
            }, totalOptions: _statusTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('LOCAL', _locais, _selectedLocal, (value) {
              setState(() {
                _selectedLocal = value;
                _updateFilters();
              });
            }, totalOptions: _locaisTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('TIPO', _tipos, _selectedTipo, (value) {
              setState(() {
                _selectedTipo = value;
                _updateFilters();
              });
            }, totalOptions: _tiposTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('EXECUTOR', _executores, _selectedExecutor, (value) {
              setState(() {
                _selectedExecutor = value;
                _updateFilters();
              });
            }, totalOptions: _executoresTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('FROTA', _frotas, _selectedFrota, (value) {
              setState(() {
                _selectedFrota = value;
                _updateFilters();
              });
            }, totalOptions: _frotasTotais)),
            const SizedBox(width: 12),
            Flexible(child: _buildFilterDropdown('COORDENADOR', _coordenadores, _selectedCoordenador, (value) {
              setState(() {
                _selectedCoordenador = value;
                _updateFilters();
              });
            }, totalOptions: _coordenadoresTotais)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFilterDropdown(String label, List<String> options, String? selectedValue, ValueChanged<String?> onChanged, {bool isMobile = false, List<String>? totalOptions}) {
    // SEMPRE usar opções totais se fornecidas para mostrar todas as opções
    // Se não houver opções totais, usar apenas as opções disponíveis (fallback)
    final opcoesParaMostrar = (totalOptions != null && totalOptions.isNotEmpty) ? totalOptions : options;
    
    // Validar se o valor selecionado está presente na lista de itens
    // Se estiver nas opções totais (mesmo sem resultados), manter o valor
    // Se não estiver em nenhuma lista, usar null
    String? valorValido;
    if (selectedValue != null) {
      // Se o valor está nas opções para mostrar (totais), usar diretamente
      // Isso permite que valores selecionados permaneçam mesmo quando não têm resultados
      if (opcoesParaMostrar.contains(selectedValue)) {
        valorValido = selectedValue;
      } else {
        // Se não está nas opções totais, usar null
        valorValido = null;
      }
    } else {
      valorValido = null;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 4, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: valorValido != null ? Colors.blue : Colors.grey[300]!),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: valorValido,
              hint: Padding(
                padding: EdgeInsets.only(left: isMobile ? 6 : 8, top: isMobile ? 8 : 10),
                child: Text(
                  'Todos',
                  style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              selectedItemBuilder: (context) {
                // selectedItemBuilder deve retornar um item para cada item na lista items
                // Retornar uma lista com o mesmo tamanho de items
                return [
                  // Item para "Todos" (null)
                  Padding(
                    padding: EdgeInsets.only(left: isMobile ? 6 : 8, top: isMobile ? 8 : 10),
                    child: Text(
                      valorValido ?? 'Todos',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 10,
                        color: valorValido == null ? Colors.grey[600] : Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Itens para cada opção (mostrar todas, mas marcar as sem resultados)
                  ...opcoesParaMostrar.map((option) {
                    final temResultados = options.contains(option);
                    return Padding(
                      padding: EdgeInsets.only(left: isMobile ? 6 : 8, top: isMobile ? 8 : 10),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: isMobile ? 9 : 10,
                          color: temResultados ? Colors.black : Colors.grey[400],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ];
              },
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 6 : 8),
                    child: Text('Todos', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.grey)),
                  ),
                ),
                ...opcoesParaMostrar.map((option) {
                  final temResultados = options.contains(option);
                  // IMPORTANTE: Sempre usar o valor da opção, mesmo se não tiver resultados
                  // Apenas desabilitar visualmente. Isso evita múltiplos valores null.
                  return DropdownMenuItem(
                    value: option, // Sempre usar o valor da opção
                    enabled: temResultados, // Desabilitar apenas visualmente/interativamente
                    child: Padding(
                      padding: EdgeInsets.only(left: isMobile ? 6 : 8),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: isMobile ? 9 : 10,
                          color: temResultados ? Colors.black : Colors.grey[400],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (String? newValue) {
                // Só permitir mudança se a opção tiver resultados ou for null (Todos)
                if (newValue == null || options.contains(newValue)) {
                  onChanged(newValue);
                }
                // Se tentar selecionar uma opção sem resultados, ignorar
              },
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, size: isMobile ? 14 : 16),
            ),
          ),
          // Label sempre visível no topo (sobreposto com fundo branco)
          Positioned(
            top: isMobile ? -5 : -6,
            left: isMobile ? 4 : 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              color: Colors.white,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 8,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSelector({bool isMobile = false}) {
    final currentSortColumn = widget.currentSortColumn ?? 'PERÍODO';
    final currentSortAscending = widget.currentSortAscending ?? true;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 4, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            size: isMobile ? 14 : 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: currentSortColumn,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
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
              size: isMobile ? 14 : 16,
              color: Colors.blue[700],
            ),
            onPressed: () {
              if (widget.onSortChanged != null) {
                widget.onSortChanged!(currentSortColumn, !currentSortAscending);
              }
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isMobile ? 20 : 24,
              minHeight: isMobile ? 20 : 24,
            ),
            tooltip: currentSortAscending ? 'Crescente' : 'Decrescente',
          ),
        ],
      ),
    );
  }

  Widget _buildMinhasTarefasToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _minhasTarefas ? Colors.blue[100] : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _minhasTarefas ? Colors.blue : Colors.grey[300]!,
          width: _minhasTarefas ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: _minhasTarefas ? Colors.blue[700] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            'Minhas Tarefas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: _minhasTarefas ? FontWeight.bold : FontWeight.normal,
              color: _minhasTarefas ? Colors.blue[700] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 6),
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
}
