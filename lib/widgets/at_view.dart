import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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
import 'multi_select_filter_dialog.dart';
import 'ats_dashboard_view.dart';
import 'ats_calendar_view.dart';

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
  Map<String, List<Map<String, dynamic>>> _atsProgramadasInfo =
      {}; // Lista de vinculações por AT
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  Set<String> _filtroStatus = {};
  Set<String> _filtroLocal = {};
  Set<String> _filtroStatusUsuario = {};
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

  String _modoVisualizacao =
      'tabela'; // 'tabela', 'cards', 'calendario', 'dashboard'
  String _filtroProgramacao =
      'todas'; // 'todas', 'programadas', 'nao_programadas'
  String _filtroTipoAT = 'abertas'; // 'todas', 'abertas', 'concluidas'
  bool _visualizacaoTabela = true;
  bool _filtrosVisiveis = false;

  final viewOptions = [
    ('tabela', Icons.table_chart, 'Tabela'),
    ('cards', Icons.view_module, 'Cards'),
    ('calendario', Icons.calendar_today, 'Calendário'),
    ('dashboard', Icons.dashboard, 'Dashboard'),
  ];
  StreamSubscription<String>? _statusChangeSubscription;

  @override
  void initState() {
    super.initState();
    // Filtro default de datas removido para igualar o comportamento de Notas SAP
    // que carrega o histórico do usuário paginado.
    // _dataInicio = null;
    // _dataFim = null;

    _loadStatus();
    _loadFiltros();
    _loadATs();
    _loadTodasATsParaEstatisticas();
    _loadATsProgramadas();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão, mobile cards
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _modoVisualizacao = Responsive.isDesktop(context)
              ? 'tabela'
              : 'cards';
          _visualizacaoTabela = _modoVisualizacao == 'tabela';
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

    List<String>? backendFiltroStatus;
    Set<String> baseStatusSistema = _statusDisponiveis.isNotEmpty
        ? _statusDisponiveis.toSet()
        : {'PREP', 'LIBE', 'ENCE', 'ENTE'}; // fallback
    if (_filtroStatus.isNotEmpty) {
      baseStatusSistema = _filtroStatus;
    }

    if (_filtroTipoAT == 'abertas') {
      backendFiltroStatus = baseStatusSistema
          .where(
            (s) =>
                !s.toUpperCase().contains('ENCE') &&
                !s.toUpperCase().contains('ENTE'),
          )
          .toList();
      if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
    } else if (_filtroTipoAT == 'concluidas') {
      backendFiltroStatus = baseStatusSistema
          .where(
            (s) =>
                s.toUpperCase().contains('ENCE') ||
                s.toUpperCase().contains('ENTE'),
          )
          .toList();
      if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
    } else {
      backendFiltroStatus = _filtroStatus.isEmpty
          ? null
          : _filtroStatus.toList();
    }

    List<String>? backendFiltroStatusUsuario = _filtroStatusUsuario.isEmpty
        ? null
        : _filtroStatusUsuario.toList();

    try {
      final ats = await _service.getAllATs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: backendFiltroStatusUsuario,
        dataInicio: periodo['inicio'],
        dataFim: periodo['fim'],
        limit: _itensPorPagina,
        offset: _paginaAtual * _itensPorPagina,
      );

      final total = await _service.contarATs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: backendFiltroStatusUsuario,
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

      List<String>? backendFiltroStatus;
      Set<String> baseStatusSistema = _statusDisponiveis.isNotEmpty
          ? _statusDisponiveis.toSet()
          : {'PREP', 'LIBE', 'ENCE', 'ENTE'};
      if (_filtroStatus.isNotEmpty) {
        baseStatusSistema = _filtroStatus;
      }

      if (_filtroTipoAT == 'abertas') {
        backendFiltroStatus = baseStatusSistema
            .where(
              (s) =>
                  !s.toUpperCase().contains('ENCE') &&
                  !s.toUpperCase().contains('ENTE'),
            )
            .toList();
        if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
      } else if (_filtroTipoAT == 'concluidas') {
        backendFiltroStatus = baseStatusSistema
            .where(
              (s) =>
                  s.toUpperCase().contains('ENCE') ||
                  s.toUpperCase().contains('ENTE'),
            )
            .toList();
        if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
      } else {
        backendFiltroStatus = _filtroStatus.isEmpty
            ? null
            : _filtroStatus.toList();
      }

      List<String>? backendFiltroStatusUsuario = _filtroStatusUsuario.isEmpty
          ? null
          : _filtroStatusUsuario.toList();

      final todasATs = await _service.getAllATs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: backendFiltroStatusUsuario,
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
    final isTablet = Responsive.isTablet(context);
    final isCompact = isMobile || isTablet;

    // Listas locais re-filtradas para programadas
    List<AT> paginatedList = _ats;
    List<AT> allAtsList = _todasATs;

    if (_filtroProgramacao == 'programadas') {
      paginatedList = paginatedList
          .where((at) => _atsProgramadasIds.contains(at.id))
          .toList();
      allAtsList = allAtsList
          .where((at) => _atsProgramadasIds.contains(at.id))
          .toList();
    } else if (_filtroProgramacao == 'nao_programadas') {
      paginatedList = paginatedList
          .where((at) => !_atsProgramadasIds.contains(at.id))
          .toList();
      allAtsList = allAtsList
          .where((at) => !_atsProgramadasIds.contains(at.id))
          .toList();
    }

    final tipoATSegments = isCompact
        ? const [
            ButtonSegment(value: 'todas', icon: Icon(Icons.all_inclusive)),
            ButtonSegment(value: 'abertas', icon: Icon(Icons.hourglass_empty)),
            ButtonSegment(value: 'concluidas', icon: Icon(Icons.check_circle)),
          ]
        : const [
            ButtonSegment(value: 'todas', label: Text('Todas')),
            ButtonSegment(value: 'abertas', label: Text('Abertas')),
            ButtonSegment(value: 'concluidas', label: Text('Concluídas')),
          ];
    final programacaoSegments = isCompact
        ? const [
            ButtonSegment(value: 'todas', icon: Icon(Icons.all_inclusive)),
            ButtonSegment(
              value: 'programadas',
              icon: Icon(Icons.event_available),
            ),
            ButtonSegment(
              value: 'nao_programadas',
              icon: Icon(Icons.event_busy),
            ),
          ]
        : const [
            ButtonSegment(value: 'todas', label: Text('Todas')),
            ButtonSegment(value: 'programadas', label: Text('Programadas')),
            ButtonSegment(
              value: 'nao_programadas',
              label: Text('Não Programadas'),
            ),
          ];

    return Scaffold(
      body: Column(
        children: [
          // Header unificado igual Notas SAP
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
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!isCompact)
                  const Text(
                    'ATs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                SegmentedButton<String>(
                  segments: tipoATSegments,
                  selected: {_filtroTipoAT},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _filtroTipoAT = newSelection.first;
                      _paginaAtual = 0;
                    });
                    _loadATs();
                    _loadTodasATsParaEstatisticas();
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    selectedBackgroundColor: Colors.blue[600],
                    selectedForegroundColor: Colors.white,
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                SegmentedButton<String>(
                  segments: programacaoSegments,
                  selected: {_filtroProgramacao},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _filtroProgramacao = newSelection.first;
                      _paginaAtual =
                          0; // O filtro acontece ram, mas resetamos a página por precaução
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    selectedBackgroundColor: Colors.blue[600],
                    selectedForegroundColor: Colors.white,
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                if (!isCompact)
                  SegmentedButton<String>(
                    segments: viewOptions.map((opt) {
                      return ButtonSegment<String>(
                        value: opt.$1,
                        icon: Icon(opt.$2),
                        label: Text(opt.$3),
                      );
                    }).toList(),
                    selected: {_modoVisualizacao},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _modoVisualizacao = newSelection.first;
                        _visualizacaoTabela = _modoVisualizacao == 'tabela';
                      });
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white,
                      selectedBackgroundColor: Colors.blue[50],
                      selectedForegroundColor: Colors.blue[700],
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _modoVisualizacao,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: viewOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt.$1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(opt.$2, size: 18, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(opt.$3),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _modoVisualizacao = newValue;
                              _visualizacaoTabela =
                                  _modoVisualizacao == 'tabela';
                            });
                          }
                        },
                      ),
                    ),
                  ),

                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _paginaAtual = 0;
                    });
                    _loadATs();
                    _loadTodasATsParaEstatisticas();
                  },
                  icon: const Icon(Icons.refresh),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(isCompact ? 44 : 0, 36),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: 12,
                    ),
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtrosVisiveis = !_filtrosVisiveis;
                    });
                  },
                  icon: Icon(
                    _filtrosVisiveis ? Icons.filter_alt_off : Icons.filter_alt,
                  ),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Text(
                          _filtrosVisiveis
                              ? 'Esconder Filtros'
                              : 'Mostrar Filtros',
                        ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(isCompact ? 44 : 0, 36),
                  ),
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
                          if (_filtroStatus.isNotEmpty ||
                              _filtroLocal.isNotEmpty ||
                              _filtroStatusUsuario.isNotEmpty ||
                              _dataInicio != null ||
                              _dataFim != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                [
                                  if (_filtroStatus.isNotEmpty) '1',
                                  if (_filtroLocal.isNotEmpty) '1',
                                  if (_filtroStatusUsuario.isNotEmpty) '1',
                                  if (_dataInicio != null) '1',
                                  if (_dataFim != null) '1',
                                ].length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      initiallyExpanded: false,
                      childrenPadding: const EdgeInsets.all(8),
                      children: [
                        _buildMultiSelectFilterField(
                          'Status Sistema',
                          _filtroStatus,
                          _statusDisponiveis,
                          (newValues) {
                            setState(() {
                              _filtroStatus = newValues;
                              _paginaAtual = 0;
                            });
                            _loadATs();
                            _loadTodasATsParaEstatisticas();
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildMultiSelectFilterField(
                          'Local de Instalação',
                          _filtroLocal,
                          _locaisDisponiveis,
                          (newValues) {
                            setState(() {
                              _filtroLocal = newValues;
                              _paginaAtual = 0;
                            });
                            _loadATs();
                            _loadTodasATsParaEstatisticas();
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildMultiSelectFilterField(
                          'Status Usuário',
                          _filtroStatusUsuario,
                          _statusUsuarioDisponiveis,
                          (newValues) {
                            setState(() {
                              _filtroStatusUsuario = newValues;
                              _paginaAtual = 0;
                            });
                            _loadATs();
                            _loadTodasATsParaEstatisticas();
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildDateFilterField('Data Início', _dataInicio, (
                          date,
                        ) {
                          setState(() {
                            _dataInicio = date;
                            _filtroAnoFim = null;
                            _filtroMesFim = null;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        }),
                        const SizedBox(height: 8),
                        _buildDateFilterField('Data Fim', _dataFim, (date) {
                          setState(() {
                            _dataFim = date;
                            _filtroAnoFim = null;
                            _filtroMesFim = null;
                            _paginaAtual = 0;
                          });
                          _loadATs();
                          _loadTodasATsParaEstatisticas();
                        }),
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
                        SizedBox(
                          width: isMobile ? double.infinity : 200,
                          child: _buildMultiSelectFilterField(
                            'Status Sistema',
                            _filtroStatus,
                            _statusDisponiveis,
                            (newValues) {
                              setState(() {
                                _filtroStatus = newValues;
                                _paginaAtual = 0;
                              });
                              _loadATs();
                              _loadTodasATsParaEstatisticas();
                            },
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 250,
                          child: _buildMultiSelectFilterField(
                            'Local',
                            _filtroLocal,
                            _locaisDisponiveis,
                            (newValues) {
                              setState(() {
                                _filtroLocal = newValues;
                                _paginaAtual = 0;
                              });
                              _loadATs();
                              _loadTodasATsParaEstatisticas();
                            },
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 200,
                          child: _buildMultiSelectFilterField(
                            'Status Usuário',
                            _filtroStatusUsuario,
                            _statusUsuarioDisponiveis,
                            (newValues) {
                              setState(() {
                                _filtroStatusUsuario = newValues;
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
                                _filtroStatus = {};
                                _filtroLocal = {};
                                _filtroStatusUsuario = {};
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

          // Tabs: Barras x Distribuição e Header removido

          // Main View Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _modoVisualizacao == 'dashboard'
                ? AtsDashboardView(
                    ats: _todasATs,
                    atsProgramadasIds: _atsProgramadasIds,
                  )
                : _modoVisualizacao == 'calendario'
                ? AtsCalendarView(ats: _todasATs)
                : _ats.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma AT encontrada',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : _visualizacaoTabela
                ? CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width,
                            ),
                            child: _ats.isNotEmpty
                                // Temporarily use original method or rebuild table passing list
                                ? _buildTabelaView() // Let's keep original for now to avoid errors, we'll refactor it later if needed
                                : const SizedBox.shrink(),
                          ),
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

          // Paginação (somente para tabela/cards)
          if ((_modoVisualizacao == 'tabela' || _modoVisualizacao == 'cards') &&
              _totalATs > _itensPorPagina)
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
                  Text(
                    'Página ${_paginaAtual + 1} de ${(_totalATs / _itensPorPagina).ceil()}',
                  ),
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

  // Criar tarefa a partir de uma at
  Future<void> _criarTarefaDaAT(AT at) async {
    try {
      // Calcular datas padrão
      final dataInicio = at.dataInicio ?? DateTime.now();
      final dataFim = at.dataFim ?? dataInicio.add(const Duration(days: 1));

      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) =>
            TaskFormDialog(startDate: dataInicio, endDate: dataFim),
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
                content: Text(
                  'Tarefa criada e vinculada à AT ${at.autorzTrab} com sucesso!',
                ),
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
        builder: (context) => TaskSelectionDialog(tasks: todasTarefas),
      );

      if (tarefaSelecionada != null) {
        try {
          await _service.vincularATATarefa(tarefaSelecionada.id, at.id);
          await _loadATsProgramadas();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'AT ${at.autorzTrab} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!',
                ),
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
              final statusColor = status != null
                  ? _getTaskStatusColor(status)
                  : Colors.grey;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(
                      Icons.task,
                      color: Colors.white,
                      size: 20,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (vinculadoEm != null)
                        Text(
                          'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  Future<void> _copiarParaAreaTransferencia(
    String texto,
    String mensagemSucesso,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemSucesso),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildATCard(AT at) {
    final isProgramada = _atsProgramadasIds.contains(at.id);
    final programadasList = isProgramada ? _atsProgramadasInfo[at.id] : null;
    final programadaInfo = programadasList?.isNotEmpty == true
        ? programadasList!.first
        : null;
    final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
    final tarefaStatus = tarefa?['status'] as String?;
    final statusColor = tarefaStatus != null
        ? _getTaskStatusColor(tarefaStatus)
        : null;

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
              onPressed: () =>
                  _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                if (isProgramada &&
                    programadasList != null &&
                    programadasList.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Tarefas Vinculadas (${programadasList.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...programadasList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final vinculacao = entry.value;
                    final tarefaVinculada =
                        vinculacao['tarefa'] as Map<String, dynamic>?;
                    final statusTarefa = tarefaVinculada?['status'] as String?;
                    final statusColorTarefa = statusTarefa != null
                        ? _getTaskStatusColor(statusTarefa)
                        : null;
                    final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;

                    return Card(
                      margin: EdgeInsets.only(
                        bottom: index < programadasList.length - 1 ? 16 : 0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              statusColorTarefa?.withOpacity(0.1) ??
                              Colors.grey[50],
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
                                    onTap: () => _navegarParaTarefa(
                                      tarefaVinculada?['id'] as String?,
                                    ),
                                    child: Text(
                                      tarefaVinculada?['tarefa']?.toString() ??
                                          '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            statusColorTarefa ??
                                            Colors.blue[700],
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                if (statusTarefa != null &&
                                    statusColorTarefa != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColorTarefa,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      statusTarefa,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (vinculadoEm != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMultiSelectFilterField(
    String label,
    Set<String> selectedValues,
    List<String> options,
    Function(Set<String>) onChanged, {
    String? searchHint,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MultiSelectFilterDialog(
            title: label,
            options: options,
            selectedValues: selectedValues,
            onSelectionChanged: (newValues) {
              onChanged(newValues);
            },
            searchHint: searchHint,
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        child: Text(
          selectedValues.isEmpty
              ? 'Todos'
              : selectedValues.length == 1
              ? selectedValues.first
              : '${selectedValues.length} selecionado(s)',
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.grey[600] : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterField(
    String label,
    DateTime? value,
    Function(DateTime?) onChanged,
  ) {
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
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
    final anos =
        _todasATs
            .where((at) => at.dataFim != null)
            .map((at) => at.dataFim!.year)
            .toSet()
            .toList()
          ..sort();

    setState(() {
      _anosFimDisponiveis = anos;

      if (_filtroAnoFim != null &&
          !_anosFimDisponiveis.contains(_filtroAnoFim)) {
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
    final meses =
        _todasATs
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
      initialValue: _filtroAnoFim,
      decoration: const InputDecoration(
        labelText: 'Ano (Data Fim)',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
        ...anos.map(
          (ano) =>
              DropdownMenuItem<int?>(value: ano, child: Text(ano.toString())),
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
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return DropdownButtonFormField<int?>(
      initialValue: _filtroMesFim,
      decoration: const InputDecoration(
        labelText: 'Mês (Data Fim)',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
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
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(
              label: Text(
                'Ações',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Tarefa Vinculada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text('AT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'Tipo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Texto Breve',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status Sistema',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status Usuário',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Local Instalação',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Início Base',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Fim Base',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          rows: _ats.map((at) {
            final isProgramada = _atsProgramadasIds.contains(at.id);
            final programadasList = isProgramada
                ? _atsProgramadasInfo[at.id]
                : null;
            final programadaInfo = programadasList?.isNotEmpty == true
                ? programadasList!.first
                : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null
                ? _getTaskStatusColor(tarefaStatus)
                : null;
            final totalVinculacoes = programadasList?.length ?? 0;

            return DataRow(
              color: isProgramada && statusColor != null
                  ? WidgetStateProperty.all(statusColor.withOpacity(0.1))
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
                              child: const Icon(
                                Icons.add_task,
                                size: 20,
                                color: Colors.green,
                              ),
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
                              child: const Icon(
                                Icons.link,
                                size: 20,
                                color: Colors.blue,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.task,
                                color: Colors.white,
                                size: 14,
                              ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                color: Colors.grey[600],
                                size: 14,
                              ),
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
                              ? () => _mostrarTodasVinculacoes(
                                  at,
                                  programadasList!,
                                )
                              : () =>
                                    _navegarParaTarefa(tarefa['id'] as String?),
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
                                      color: totalVinculacoes > 1
                                          ? Colors.orange
                                          : Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (totalVinculacoes > 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
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
                        onTap: () => _copiarParaAreaTransferencia(
                          at.autorzTrab,
                          'AT copiada!',
                        ),
                        child: const Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _mostrarDetalhesAT(at),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                DataCell(Text(at.statusUsuario ?? '-')),
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
                  Text(
                    at.dataInicio != null ? _formatDate(at.dataInicio!) : '-',
                  ),
                ),
                DataCell(
                  Text(at.dataFim != null ? _formatDate(at.dataFim!) : '-'),
                ),
                DataCell(Text(at.cen ?? '-')),
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
            Expanded(child: Text('Detalhes da AT: ${at.autorzTrab}')),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
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
                _buildInfoRow(
                  'Data Importação',
                  _formatDate(at.dataImportacao!),
                ),
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
