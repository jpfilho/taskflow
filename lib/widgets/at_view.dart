import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../models/at.dart';
import '../services/at_service.dart';
import '../utils/responsive.dart';
import 'task_form_dialog.dart';
import 'task_selection_dialog.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../services/status_service.dart';
import 'task_view_dialog.dart';

class ATView extends StatefulWidget {
  const ATView({super.key});

  @override
  State<ATView> createState() => _ATViewState();
}

class _ATViewState extends State<ATView> {
  final ATService _service = ATService();
  final StatusService _statusService = StatusService();
  List<AT> _ats = [];
  List<AT> _todasATs = []; // Todas as ATs para calcular estatísticas
  Set<String> _atsProgramadasIds = {}; // IDs das ATs vinculadas a tarefas
  Map<String, List<Map<String, dynamic>>> _atsProgramadasInfo = {}; // Lista de vinculações por AT
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  String? _filtroStatus;
  String? _filtroLocal;
  String? _filtroStatusUsuario;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  int? _filtroAnoFim;
  int? _filtroMesFim;
  int _totalATs = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  List<String> _statusDisponiveis = [];
  List<String> _locaisDisponiveis = [];
  List<String> _statusUsuarioDisponiveis = [];
  List<int> _anosFimDisponiveis = [];
  bool _visualizacaoTabela = false; // false = cards, true = tabela
  bool _filtrosVisiveis = false;
  bool _tabelaExpandida = false;
  StreamSubscription<String>? _statusChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadFiltros();
    _loadATs();
    _loadTodasATsParaEstatisticas();
    _loadATsProgramadas();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _visualizacaoTabela = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final statuses = await _statusService.getAllStatus();
      final statusMap = <String, Status>{};
      for (final status in statuses) {
        statusMap[status.codigo] = status;
      }
      if (mounted) {
        setState(() {
          _statusMap = statusMap;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar status: $e');
    }
  }

  Future<void> _loadATsProgramadas() async {
    try {
      final programadas = await _service.getATsProgramadas();
      final ids = <String>{};
      final info = <String, List<Map<String, dynamic>>>{};
      
      for (final item in programadas) {
        final at = item['at'] as Map<String, dynamic>;
        final atId = at['id'] as String;
        ids.add(atId);
        
        // Adicionar à lista de vinculações desta AT
        if (!info.containsKey(atId)) {
          info[atId] = [];
        }
        info[atId]!.add(item);
      }
      
      // Ordenar cada lista por data de vinculação (mais recente primeiro)
      for (final atId in info.keys) {
        info[atId]!.sort((a, b) {
          final dataA = a['vinculado_em'] as DateTime?;
          final dataB = b['vinculado_em'] as DateTime?;
          if (dataA == null && dataB == null) return 0;
          if (dataA == null) return 1;
          if (dataB == null) return -1;
          return dataB.compareTo(dataA); // Mais recente primeiro
        });
      }
      
      if (mounted) {
        setState(() {
          _atsProgramadasIds = ids;
          _atsProgramadasInfo = info;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar ATs programadas: $e');
    }
  }

  Color _getTaskStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      return statusObj.color;
    }
    
    // Fallback para cores padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return Colors.orange;
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      case 'RPAR':
        return Colors.teal;
      case 'CANC':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  Future<void> _loadFiltros() async {
    final valores = await _service.getValoresFiltros();
    setState(() {
      _statusDisponiveis = valores['status'] ?? [];
      _locaisDisponiveis = valores['local'] ?? [];
      _statusUsuarioDisponiveis = valores['statusUsuario'] ?? [];
    });
  }

  Future<void> _loadATs() async {
    setState(() {
      _isLoading = true;
    });

    final periodo = _calcularPeriodo();

    try {
      final ats = await _service.getAllATs(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        filtroStatusUsuario: _filtroStatusUsuario,
        dataInicio: periodo['inicio'],
        dataFim: periodo['fim'],
        limit: _itensPorPagina,
        offset: _paginaAtual * _itensPorPagina,
      );

      final total = await _service.contarATs(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        filtroStatusUsuario: _filtroStatusUsuario,
        dataInicio: periodo['inicio'],
        dataFim: periodo['fim'],
      );

      setState(() {
        _ats = ats;
        _totalATs = total;
        _isLoading = false;
      });
      // Recarregar ATs programadas quando carregar ATs
      _loadATsProgramadas();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar ATs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTodasATsParaEstatisticas() async {
    try {
      final periodo = _calcularPeriodo();
      // Carregar todas as ATs sem paginação para calcular estatísticas, usando os mesmos filtros
      final todasATs = await _service.getAllATs(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        filtroStatusUsuario: _filtroStatusUsuario,
        dataInicio: periodo['inicio'],
        dataFim: periodo['fim'],
        limit: null, // Sem limite
        offset: null,
      );

      if (mounted) {
        setState(() {
          _todasATs = todasATs;
        });
        _recalcularAnosMesesFim();
      }
    } catch (e) {
      print('⚠️ Erro ao carregar todas as ATs para estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    // Calcular estatísticas para os dashboards usando as ATs filtradas
    final totalATs = _todasATs.length;
    // Contar apenas as ATs programadas que estão na lista filtrada
    final atsProgramadas = _todasATs.where((at) => _atsProgramadasIds.contains(at.id)).length;
    final atsNaoProgramadas = totalATs > 0 ? totalATs - atsProgramadas : 0;
    
    // Contar por status sistema e usuário
    final atsPorStatus = <String, int>{};
    final concluidas = _todasATs.where((at) => (at.statusUsuario ?? '').toUpperCase().contains('CONC')).length;
    for (final at in _todasATs) {
      final status = at.statusSistema ?? 'Sem Status';
      atsPorStatus[status] = (atsPorStatus[status] ?? 0) + 1;
    }
    

    return Scaffold(
      body: Column(
        children: [
          // Header com botões
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'ATs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.start,
                    children: [
                      _buildDashboardCardGrande(
                        'ATs Programadas',
                        atsProgramadas,
                        totalATs > 0 ? (atsProgramadas / totalATs) * 100 : 0,
                    Colors.blue,
                  ),
                      _buildDashboardCardGrande(
                        'AT\'s Concluídas',
                        concluidas,
                        totalATs > 0 ? (concluidas / totalATs) * 100 : 0,
                    Colors.green,
                  ),
                      _buildDashboardCardGrande(
                    'Não Programadas',
                        atsNaoProgramadas,
                        totalATs > 0 ? (atsNaoProgramadas / totalATs) * 100 : 0,
                    Colors.orange,
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() {
                      _filtrosVisiveis = !_filtrosVisiveis;
                    });
                  },
                  icon: Icon(
                    _filtrosVisiveis ? Icons.filter_alt_off : Icons.filter_alt,
                    color: Colors.blue,
                  ),
                  label: Text(
                    _filtrosVisiveis ? 'Esconder filtros' : 'Mostrar filtros',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                  ),
                  ),
                ),
                const Spacer(),
                // Botão de alternar visualização
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visualizacaoTabela = !_visualizacaoTabela;
                    });
                  },
                  icon: Icon(_visualizacaoTabela ? Icons.view_module : Icons.table_chart),
                  tooltip: _visualizacaoTabela ? 'Visualização em Cards' : 'Visualização em Tabela',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtroStatus = null;
                      _filtroLocal = null;
                      _filtroStatusUsuario = null;
                      _dataInicio = null;
                      _dataFim = null;
                      _filtroAnoFim = null;
                      _filtroMesFim = null;
                      _paginaAtual = 0;
                    });
                    _loadATs();
                    _loadTodasATsParaEstatisticas();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),

          // Filtros
          if (_filtrosVisiveis)
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: isMobile
                ? ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 20),
                        const SizedBox(width: 8),
                        const Text('Filtros', style: TextStyle(fontSize: 16)),
                        if (_filtroStatus != null || _filtroLocal != null || _filtroStatusUsuario != null || _dataInicio != null || _dataFim != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              [
                                if (_filtroStatus != null) '1',
                                if (_filtroLocal != null) '1',
                                if (_filtroStatusUsuario != null) '1',
                                if (_dataInicio != null) '1',
                                if (_dataFim != null) '1',
                              ].length.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.all(8),
                    children: [
                      _buildFilterField(
                        'Status Sistema',
                        _filtroStatus,
                        _statusDisponiveis,
                        (value) {
                          setState(() {
                            _filtroStatus = value;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildFilterField(
                        'Local de Instalação',
                        _filtroLocal,
                        _locaisDisponiveis,
                        (value) {
                          setState(() {
                            _filtroLocal = value;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildFilterField(
                          'Status Usuário',
                        _filtroStatusUsuario,
                        _statusUsuarioDisponiveis,
                        (value) {
                          setState(() {
                            _filtroStatusUsuario = value;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildDateFilterField(
                        'Data Início',
                        _dataInicio,
                        (date) {
                          setState(() {
                            _dataInicio = date;
                              _filtroAnoFim = null;
                              _filtroMesFim = null;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildDateFilterField(
                        'Data Fim',
                        _dataFim,
                        (date) {
                          setState(() {
                            _dataFim = date;
                              _filtroAnoFim = null;
                              _filtroMesFim = null;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        },
                      ),
                        const SizedBox(height: 8),
                        _buildAnoFimDropdown(isMobile: true),
                        const SizedBox(height: 8),
                        _buildMesFimDropdown(isMobile: true),
                    ],
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                // Filtro Status
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    value: _filtroStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status Sistema',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        const Text('Todos'),
                        ..._statusDisponiveis.map((status) => Text(
                              status.length > 25 ? '${status.substring(0, 25)}...' : status,
                              overflow: TextOverflow.ellipsis,
                            )),
                      ];
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._statusDisponiveis.map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroStatus = value;
                        _paginaAtual = 0;
                      });
                      _loadATs();
                      _loadTodasATsParaEstatisticas();
                    },
                  ),
                ),

                // Filtro Local
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: DropdownButtonFormField<String>(
                    value: _filtroLocal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Local',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        const Text('Todos'),
                        ..._locaisDisponiveis.map((local) => Text(
                              local.length > 30 ? '${local.substring(0, 30)}...' : local,
                              overflow: TextOverflow.ellipsis,
                            )),
                      ];
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._locaisDisponiveis.map((local) => DropdownMenuItem<String>(
                            value: local,
                            child: Text(local.length > 40 ? '${local.substring(0, 40)}...' : local),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroLocal = value;
                        _paginaAtual = 0;
                      });
                      _loadATs();
                      _loadTodasATsParaEstatisticas();
                    },
                  ),
                ),

                // Filtro Tipo
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    value: _filtroStatusUsuario,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status Usuário',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._statusUsuarioDisponiveis.map((tipo) => DropdownMenuItem<String>(
                            value: tipo,
                            child: Text(tipo),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroStatusUsuario = value;
                        _paginaAtual = 0;
                      });
                      _loadATs();
                      _loadTodasATsParaEstatisticas();
                    },
                  ),
                ),

                // Filtro Data Início
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dataInicio ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dataInicio = date;
                          _filtroAnoFim = null;
                          _filtroMesFim = null;
                          _paginaAtual = 0;
                        });
                        _loadATs();
                        _loadTodasATsParaEstatisticas();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Início',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dataInicio != null
                            ? '${_dataInicio!.day}/${_dataInicio!.month}/${_dataInicio!.year}'
                            : 'Selecione',
                      ),
                    ),
                  ),
                ),

                // Filtro Data Fim
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dataFim ?? DateTime.now(),
                        firstDate: _dataInicio ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dataFim = date;
                          _filtroAnoFim = null;
                          _filtroMesFim = null;
                          _paginaAtual = 0;
                        });
                        _loadATs();
                        _loadTodasATsParaEstatisticas();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Fim',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dataFim != null
                            ? '${_dataFim!.day}/${_dataFim!.month}/${_dataFim!.year}'
                            : 'Selecione',
                      ),
                    ),
                  ),
                ),

                // Filtro Ano (Data Fim)
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: _buildAnoFimDropdown(isMobile: isMobile),
                ),

                // Filtro Mês (Data Fim)
                SizedBox(
                  width: isMobile ? double.infinity : 140,
                  child: _buildMesFimDropdown(isMobile: isMobile),
                ),

                // Botão Limpar Filtros
                if (!isMobile)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtroStatus = null;
                        _filtroLocal = null;
                        _filtroStatusUsuario = null;
                        _dataInicio = null;
                        _dataFim = null;
                        _filtroAnoFim = null;
                        _filtroMesFim = null;
                        _paginaAtual = 0;
                      });
                      _loadATs();
                      _loadTodasATsParaEstatisticas();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar Filtros'),
                  ),
                    ],
                  ),
          ),

          // Tabs: Barras x Distribuição
          // Abas de gráficos (ocultadas se tabela expandida)
          if (!_tabelaExpandida)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 16,
                vertical: isMobile ? 4 : 8,
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            labelColor: Colors.blue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blue,
                            tabs: const [
                              Tab(text: 'Barras'),
                              Tab(text: 'Distribuição'),
                              Tab(text: 'Evolução'),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Expandir tabela',
                          onPressed: () {
                            setState(() {
                              _tabelaExpandida = true;
                            });
                          },
                          icon: const Icon(Icons.fullscreen, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: isMobile ? 260 : 320,
                      child: TabBarView(
                        children: [
                          _buildATsPorFimBaseChart(isMobile),
                          _buildDistribuicaoATsHeatmap(isMobile),
                          _buildEvolucaoATsAcumulada(isMobile),
                        ],
                      ),
                    ),
                  ],
                ),
                  ),
          ),

          // Contador de resultados
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Text(
                  'Total: $_totalATs ATs (${_ats.length} nesta página)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Text(
                  'Página ${_paginaAtual + 1} de ${(_totalATs / _itensPorPagina).ceil()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Lista de ats (Cards ou Tabela)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ats.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma at encontrada',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _visualizacaoTabela || _tabelaExpandida
                        ? Stack(
                            children: [
                              _buildTabelaView(),
                              if (_tabelaExpandida)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: IconButton(
                                    tooltip: 'Restaurar gráficos',
                                    onPressed: () {
                                      setState(() {
                                        _tabelaExpandida = false;
                                      });
                                    },
                                    icon: const Icon(Icons.fullscreen_exit, color: Colors.blue),
                                  ),
                                ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _ats.length,
                            itemBuilder: (context, index) {
                              final at = _ats[index];
                              return _buildATCard(at);
                            },
                          ),
          ),

          // Paginação
          if (_totalATs > _itensPorPagina)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _paginaAtual > 0
                        ? () {
                            setState(() {
                              _paginaAtual--;
                            });
                            _loadATs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalATs / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalATs
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            _loadATs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistribuicaoATsHeatmap(bool isMobile) {
    // Agrupar por centro de trabalho (cntr_trab) e mês/ano de data_fim
    final grupos = <String, Map<DateTime, int>>{};
    final meses = <DateTime>{};

    for (final at in _todasATs) {
      final fim = at.dataFim;
      if (fim == null) continue;
      final mes = DateTime(fim.year, fim.month);
      meses.add(mes);
      final centro = at.cntrTrab ?? 'Sem Centro';
      grupos.putIfAbsent(centro, () => {});
      grupos[centro]![mes] = (grupos[centro]![mes] ?? 0) + 1;
    }

    final mesesOrdenados = meses.toList()..sort((a, b) => a.compareTo(b));
    if (mesesOrdenados.isEmpty || grupos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sem dados para distribuição de ATs programadas.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    // Descobrir máximo para escala de cor
    int maxValor = 0;
    for (final mapa in grupos.values) {
      for (final v in mapa.values) {
        if (v > maxValor) maxValor = v;
      }
    }
    maxValor = maxValor == 0 ? 1 : maxValor;

    Color corValor(int v) {
      final t = (v / maxValor).clamp(0, 1).toDouble();
      return Color.lerp(Colors.white, Colors.blue, t) ?? Colors.white;
    }

    String labelMes(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

    final centrosOrdenados = grupos.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.grid_on, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Distribuição de ATs Programadas (Heatmap)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header meses
                Row(
                  children: [
                    const SizedBox(width: 140), // espaço para label do centro
                    ...mesesOrdenados.map(
                      (m) => Container(
                        width: 90,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          labelMes(m),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Linhas por centro
                ...centrosOrdenados.map((centro) {
                  final mapa = grupos[centro]!;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            centro,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...mesesOrdenados.map((m) {
                          final v = mapa[m] ?? 0;
                          return Container(
                            width: 90,
                            height: 36,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: corValor(v),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Text(
                              v.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: v > maxValor * 0.6 ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolucaoATsAcumulada(bool isMobile) {
    // Montar meses ordenados a partir das datas fim
    final meses = <DateTime>{};
    for (final at in _todasATs) {
      final fim = at.dataFim;
      if (fim != null) {
        meses.add(DateTime(fim.year, fim.month));
      }
    }
    final mesesOrdenados = meses.toList()..sort((a, b) => a.compareTo(b));
    if (mesesOrdenados.isEmpty) {
      return Center(
        child: Text(
          'Sem dados para evolução.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Contagem mensal
    final programadasPorMes = <DateTime, int>{};
    final concluidasPorMes = <DateTime, int>{};
    for (final at in _todasATs) {
      final fim = at.dataFim;
      if (fim == null) continue;
      final chave = DateTime(fim.year, fim.month);
      if (_atsProgramadasIds.contains(at.id)) {
        programadasPorMes[chave] = (programadasPorMes[chave] ?? 0) + 1;
      }
      if ((at.statusUsuario ?? '').toUpperCase().contains('CONC')) {
        concluidasPorMes[chave] = (concluidasPorMes[chave] ?? 0) + 1;
      }
    }

    // Acumulado
    double acumuladoProg = 0;
    double acumuladoConc = 0;
    final spotsProg = <FlSpot>[];
    final spotsConc = <FlSpot>[];
    for (int i = 0; i < mesesOrdenados.length; i++) {
      final m = mesesOrdenados[i];
      acumuladoProg += (programadasPorMes[m] ?? 0);
      acumuladoConc += (concluidasPorMes[m] ?? 0);
      spotsProg.add(FlSpot(i.toDouble(), acumuladoProg));
      spotsConc.add(FlSpot(i.toDouble(), acumuladoConc));
    }

    final maxY = [
      ...spotsProg.map((e) => e.y),
      ...spotsConc.map((e) => e.y),
    ].fold<double>(0, (p, c) => c > p ? c : p);

    const nomesMes = [
      'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'
    ];
    String labelMes(DateTime d) => '${nomesMes[d.month - 1]}/${d.year.toString().substring(2)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: isMobile ? 200 : 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (maxY + 1).clamp(1, double.infinity),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsProg,
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                  LineChartBarData(
                    spots: spotsConc,
                    isCurved: false,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: (maxY / 4).clamp(1, maxY),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= mesesOrdenados.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labelMes(mesesOrdenados[idx]),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  verticalInterval: 1,
                  horizontalInterval: (maxY / 4).clamp(1, maxY),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        final idx = barSpot.x.toInt();
                        final mesLabel = idx >= 0 && idx < mesesOrdenados.length
                            ? labelMes(mesesOrdenados[idx])
                            : '';
                        return LineTooltipItem(
                          '$mesLabel\n${barSpot.y.toInt()}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.circle, size: 10, color: Colors.blue),
              SizedBox(width: 4),
              Text('ATs Programadas', style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: Colors.green),
              SizedBox(width: 4),
              Text('ATs Concluídas', style: TextStyle(fontSize: 12)),
            ],
            ),
        ],
      ),
    );
  }

  // Criar tarefa a partir de uma at
  Future<void> _criarTarefaDaAT(AT at) async {
    try {
      // Calcular datas padrão
      final dataInicio = at.dataInicio ?? DateTime.now();
      final dataFim = at.dataFim ?? dataInicio.add(const Duration(days: 1));
      
      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          startDate: dataInicio,
          endDate: dataFim,
        ),
      );
      
      if (taskCriada != null) {
        final taskService = TaskService();
        try {
          final createdTask = await taskService.createTask(taskCriada);
          await _service.vincularATATarefa(createdTask.id, at.id);
          await _loadATsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarefa criada e vinculada à AT ${at.autorzTrab} com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          print('⚠️ Erro ao criar/vincular tarefa: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao criar tarefa ou vincular at: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar tarefa: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Vincular at a uma tarefa existente
  Future<void> _vincularATATarefaExistente(AT at) async {
    try {
      final taskService = TaskService();
      final todasTarefas = await taskService.getAllTasks();
      
      if (todasTarefas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não há tarefas disponíveis para vincular'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final tarefaSelecionada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskSelectionDialog(
          tasks: todasTarefas,
        ),
      );
      
      if (tarefaSelecionada != null) {
        try {
          await _service.vincularATATarefa(tarefaSelecionada.id, at.id);
          await _loadATsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('AT ${at.autorzTrab} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao vincular at: $e');
          print('❌ Stack trace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular at: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular at: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Navegar para tarefa vinculada
  Future<void> _navegarParaTarefa(String? taskId) async {
    if (taskId == null) return;
    
    try {
      final taskService = TaskService();
      final task = await taskService.getTaskById(taskId);
      
      if (task != null && mounted) {
        await showDialog(
          context: context,
          builder: (context) => TaskViewDialog(task: task),
        );
      }
    } catch (e) {
      print('⚠️ Erro ao carregar tarefa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar todas as vinculações de uma at
  void _mostrarTodasVinculacoes(AT at, List<Map<String, dynamic>> vinculacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarefas vinculadas à at ${at.autorzTrab}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vinculacoes.length,
            itemBuilder: (context, index) {
              final vinculacao = vinculacoes[index];
              final tarefa = vinculacao['tarefa'] as Map<String, dynamic>?;
              final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
              
              if (tarefa == null) return const SizedBox.shrink();
              
              final status = tarefa['status'] as String?;
              final statusColor = status != null ? _getTaskStatusColor(status) : Colors.grey;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(Icons.task, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    tarefa['tarefa']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      if (vinculadoEm != null)
                        Text(
                          'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _navegarParaTarefa(tarefa['id'] as String?);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildATCard(AT at) {
    final isProgramada = _atsProgramadasIds.contains(at.id);
    final programadasList = isProgramada ? _atsProgramadasInfo[at.id] : null;
    final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
    final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
    final tarefaStatus = tarefa?['status'] as String?;
    final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: isProgramada && statusColor != null 
          ? statusColor.withOpacity(0.1) 
          : null,
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(at.statusSistema),
              child: Text(
                at.statusUsuario ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (isProgramada && statusColor != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'AT: ${at.autorzTrab}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: at.autorzTrab));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AT copiada!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copiar AT',
            ),
            if (isProgramada && tarefaStatus != null && statusColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      tarefaStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (at.textoBreve != null)
              Text(
                at.textoBreve!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (isProgramada && tarefa != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _navegarParaTarefa(tarefa['id'] as String?),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor != null 
                        ? statusColor.withOpacity(0.15)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor ?? Colors.blue[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: statusColor ?? Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tarefa['tarefa']?.toString() ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: statusColor ?? Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (at.dataInicio != null)
                  Text(
                    'Início: ${_formatDate(at.dataInicio!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (at.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(at.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      at.statusSistema!,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Status Sistema', at.statusSistema),
                _buildInfoRow('Status Usuário', at.statusUsuario),
                _buildInfoRow('Edificação', at.edificacao),
                _buildInfoRow('Texto Breve', at.textoBreve),
                _buildInfoRow('Local Instalação', at.localInstalacao),
                _buildInfoRow('SI', at.si),
                _buildInfoRow('Cen', at.cen),
                _buildInfoRow('CntrTrab', at.cntrTrab),
                if (at.dataInicio != null)
                  _buildInfoRow('Data Início', _formatDate(at.dataInicio!)),
                if (at.dataFim != null)
                  _buildInfoRow('Data Fim', _formatDate(at.dataFim!)),
                
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _criarTarefaDaAT(at),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _vincularATATarefaExistente(at),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Vincular a Tarefa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                
                // Mostrar tarefas vinculadas se houver
                if (isProgramada && programadasList != null && programadasList.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Tarefas Vinculadas (${programadasList.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...programadasList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final vinculacao = entry.value;
                    final tarefaVinculada = vinculacao['tarefa'] as Map<String, dynamic>?;
                    final statusTarefa = tarefaVinculada?['status'] as String?;
                    final statusColorTarefa = statusTarefa != null ? _getTaskStatusColor(statusTarefa) : null;
                    final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: index < programadasList.length - 1 ? 16 : 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColorTarefa?.withOpacity(0.1) ?? Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColorTarefa ?? Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _navegarParaTarefa(tarefaVinculada?['id'] as String?),
                                  child: Text(
                                    tarefaVinculada?['tarefa']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: statusColorTarefa ?? Colors.blue[700],
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              if (statusTarefa != null && statusColorTarefa != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColorTarefa,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusTarefa,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                          if (vinculadoEm != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCardGrande(String title, int valor, double percentual, Color color) {
    final percStr = '${percentual.isFinite ? percentual.toStringAsFixed(0) : '0'}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
        mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valor.toString(),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                ),
              ),
                const SizedBox(width: 6),
              Text(
                  percStr,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }


  Widget _buildFilterField(String label, String? value, List<String> options, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todos'),
        ),
        ...options.map((option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option.length > 40 ? '${option.substring(0, 40)}...' : option),
            )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDateFilterField(String label, DateTime? value, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          onChanged(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.calendar_today),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          value != null
              ? '${value.day}/${value.month}/${value.year}'
              : 'Selecione',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Map<String, DateTime?> _calcularPeriodo() {
    DateTime? inicio = _dataInicio;
    DateTime? fim = _dataFim;

    if (_filtroAnoFim != null) {
      final ano = _filtroAnoFim!;
      final mes = _filtroMesFim;
      if (mes != null) {
        inicio = DateTime(ano, mes, 1);
        fim = DateTime(ano, mes + 1, 0); // último dia do mês
      } else {
        inicio = DateTime(ano, 1, 1);
        fim = DateTime(ano, 12, 31);
      }
    }

    return {'inicio': inicio, 'fim': fim};
  }

  void _recalcularAnosMesesFim() {
    final anos = _todasATs
        .where((at) => at.dataFim != null)
        .map((at) => at.dataFim!.year)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _anosFimDisponiveis = anos;

      if (_filtroAnoFim != null && !_anosFimDisponiveis.contains(_filtroAnoFim)) {
        _filtroAnoFim = null;
        _filtroMesFim = null;
      }

      if (_filtroAnoFim != null && _filtroMesFim != null) {
        final mesesAno = _mesesDisponiveisParaAno(_filtroAnoFim!);
        if (!mesesAno.contains(_filtroMesFim)) {
          _filtroMesFim = null;
        }
      }
    });
  }

  List<int> _mesesDisponiveisParaAno(int ano) {
    final meses = _todasATs
        .where((at) => at.dataFim != null && at.dataFim!.year == ano)
        .map((at) => at.dataFim!.month)
        .toSet()
        .toList()
      ..sort();

    return meses.isEmpty ? List.generate(12, (index) => index + 1) : meses;
  }

  Widget _buildAnoFimDropdown({required bool isMobile}) {
    final anos = _anosFimDisponiveis;
    return DropdownButtonFormField<int?>(
      value: _filtroAnoFim,
      decoration: const InputDecoration(
        labelText: 'Ano (Data Fim)',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos'),
        ),
        ...anos.map(
          (ano) => DropdownMenuItem<int?>(
            value: ano,
            child: Text(ano.toString()),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _filtroAnoFim = value;
          _filtroMesFim = null; // reset mês ao trocar ano
          _dataInicio = null;
          _dataFim = null;
          _paginaAtual = 0;
        });
        _loadATs();
        _loadTodasATsParaEstatisticas();
      },
    );
  }

  Widget _buildMesFimDropdown({required bool isMobile}) {
    final meses = _filtroAnoFim != null
        ? _mesesDisponiveisParaAno(_filtroAnoFim!)
        : List.generate(12, (index) => index + 1);
    const nomesMes = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];

    return DropdownButtonFormField<int?>(
      value: _filtroMesFim,
      decoration: const InputDecoration(
        labelText: 'Mês (Data Fim)',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos'),
        ),
        ...meses.map(
          (mes) => DropdownMenuItem<int?>(
            value: mes,
            child: Text(nomesMes[mes - 1]),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _filtroMesFim = value;
          if (_filtroAnoFim == null && value != null) {
            // Se escolher mês sem ano, usa ano atual
            _filtroAnoFim = DateTime.now().year;
          }
          _dataInicio = null;
          _dataFim = null;
          _paginaAtual = 0;
        });
        _loadATs();
        _loadTodasATsParaEstatisticas();
      },
    );
  }

  Widget _buildATsPorFimBaseChart(bool isMobile) {
    // Contagem por mês/ano:
    // - Barras: CRSI + CONC (ignora CANC)
    // - Linha: CONC
    final contagemBarra = <DateTime, int>{};
    final contagemCONC = <DateTime, int>{};
    for (final at in _todasATs) {
      final fim = at.dataFim;
      if (fim == null) continue;
      final chave = DateTime(fim.year, fim.month);
      final status = (at.statusUsuario ?? '').toUpperCase();
      if (status.contains('CANC')) continue; // ignorar canceladas
      if (status.contains('CRSI')) {
        contagemBarra[chave] = (contagemBarra[chave] ?? 0) + 1;
      } else if (status.contains('CONC')) {
        contagemBarra[chave] = (contagemBarra[chave] ?? 0) + 1;
        contagemCONC[chave] = (contagemCONC[chave] ?? 0) + 1;
      } else {
        // Outros status não entram no gráfico atual
      }
    }

    final chaves = <DateTime>{
      ...contagemBarra.keys,
      ...contagemCONC.keys,
    }.toList()
      ..sort((a, b) => a.compareTo(b));

    int maxBarra = 0;
    int maxCONC = 0;
    for (final chave in chaves) {
      final c1 = contagemBarra[chave] ?? 0;
      final c2 = contagemCONC[chave] ?? 0;
      if (c1 > maxBarra) maxBarra = c1;
      if (c2 > maxCONC) maxCONC = c2;
    }
    final maxQtd = [maxBarra, maxCONC].reduce((a, b) => a > b ? a : b);

    String mesAnoLabel(DateTime dt) =>
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    if (maxQtd == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sem dados (CRSI/CONC) para o período selecionado.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'ATs por Fim Base (mês/ano)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_todasATs.length} ATs',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          SizedBox(
            height: isMobile ? 192 : 228, // reduzido ~40%
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barMaxHeight = constraints.maxHeight - 60; // espaço para labels/valores
                final n = chaves.isEmpty ? 1 : chaves.length;
                final step = constraints.maxWidth / n;
                final double barWidth = (step * 0.5).clamp(16, 28).toDouble();
                final totalWidth = step * n;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: totalWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(chaves.length, (index) {
                            final chave = chaves[index];
                            final valor = contagemBarra[chave] ?? 0;
                            final valorConc = contagemCONC[chave] ?? 0;
                            final fator = maxQtd > 0 ? (valor / maxQtd) : 0.0;
                            final barHeight = barMaxHeight * fator;
                            final double barHeightClamped =
                                barHeight.clamp(0.0, barMaxHeight).toDouble();
                            final fatorConc = maxQtd > 0 ? (valorConc / maxQtd) : 0.0;
                            final double barHeightConc =
                                (barMaxHeight * fatorConc).clamp(0.0, barMaxHeight).toDouble();
                            final mesRef = DateTime(chave.year, chave.month);
                            final mesAtual = DateTime(DateTime.now().year, DateTime.now().month);
                            final bool atrasado = (valor != valorConc) && mesRef.isBefore(mesAtual);
                            final Color corBarra = atrasado ? Colors.red : Colors.blue;
                            final Color corTextoBarra = atrasado ? Colors.red[800]! : Colors.blue[800]!;

                            return SizedBox(
                              width: step,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: barMaxHeight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          height: barHeightClamped,
                                          width: barWidth,
                                          decoration: BoxDecoration(
                                            color: corBarra,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.topCenter,
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              valor.toString(),
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 11,
                                                fontWeight: FontWeight.w600,
                                                color: corTextoBarra,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: barHeightConc,
                                          width: barWidth,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.topCenter,
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              valorConc.toString(),
                                              style: TextStyle(
                                                fontSize: isMobile ? 9 : 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mesAnoLabel(chave),
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('ABER')) return Colors.orange;
    if (status.contains('CAPC')) return Colors.blue;
    if (status.contains('DMNV')) return Colors.red;
    if (status.contains('ERRD')) return Colors.red;
    if (status.contains('SCDM')) return Colors.green;
    return Colors.grey;
  }

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tarefa Vinculada', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('AT', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local Instalação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Início Base', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Fim Base', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _ats.map((at) {
            final isProgramada = _atsProgramadasIds.contains(at.id);
            final programadasList = isProgramada ? _atsProgramadasInfo[at.id] : null;
            final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
            final totalVinculacoes = programadasList?.length ?? 0;
            
            return DataRow(
              color: isProgramada && statusColor != null
                  ? MaterialStateProperty.all(statusColor.withOpacity(0.1))
                  : null,
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Criar Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _criarTarefaDaAT(at),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: const Icon(Icons.add_task, size: 20, color: Colors.green),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Vincular a Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _vincularATATarefaExistente(at),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[300]!),
                              ),
                              child: const Icon(Icons.link, size: 20, color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  isProgramada && tarefaStatus != null && statusColor != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.task, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                tarefaStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (totalVinculacoes > 1) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${totalVinculacoes - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.grey[600], size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Não Programada',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                DataCell(
                  isProgramada && tarefa != null
                      ? InkWell(
                          onTap: totalVinculacoes > 1
                              ? () => _mostrarTodasVinculacoes(at, programadasList!)
                              : () => _navegarParaTarefa(tarefa['id'] as String?),
                          child: SizedBox(
                            width: 200,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    tarefa['tarefa']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: totalVinculacoes > 1 ? Colors.orange : Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (totalVinculacoes > 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$totalVinculacoes',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const Text('-', style: TextStyle(color: Colors.grey)),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        at.autorzTrab,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: at.autorzTrab));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('AT copiada!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                  onTap: () => _mostrarDetalhesAT(at),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(at.statusUsuario ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      at.textoBreve ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(at.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      at.statusSistema ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  Text(at.statusUsuario ?? '-'),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      at.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(at.dataInicio != null ? _formatDate(at.dataInicio!) : '-'),
                ),
                DataCell(
                  Text(at.dataFim != null ? _formatDate(at.dataFim!) : '-'),
                ),
                DataCell(
                  Text(at.cen ?? '-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostrarDetalhesAT(AT at) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da AT: ${at.autorzTrab}'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: at.autorzTrab));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AT copiada!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copiar AT',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('AT', at.autorzTrab),
              _buildInfoRow('Tipo', at.statusUsuario),
              _buildInfoRow('Status Sistema', at.statusSistema),
              _buildInfoRow('Status Usuário', at.statusUsuario),
              _buildInfoRow('Texto Breve', at.textoBreve),
              _buildInfoRow('Denominação Local', at.edificacao),
              _buildInfoRow('Denominação Objeto', at.textoBreve),
              _buildInfoRow('Local Instalação', at.localInstalacao),
              _buildInfoRow('Código SI', at.si),
              _buildInfoRow('GPM', at.cen),
              if (at.dataInicio != null)
                _buildInfoRow('Início Base', _formatDate(at.dataInicio!)),
              if (at.dataFim != null)
                _buildInfoRow('Fim Base', _formatDate(at.dataFim!)),
              if (at.dataImportacao != null)
                _buildInfoRow('Data Importação', _formatDate(at.dataImportacao!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }



}

