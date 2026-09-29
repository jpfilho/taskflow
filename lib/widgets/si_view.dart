import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../models/si.dart';
import '../services/si_service.dart';
import '../services/auth_service_simples.dart';
import '../services/executor_service.dart';
import '../utils/responsive.dart';
import 'task_form_dialog.dart';
import 'task_selection_dialog.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../services/status_service.dart';
import 'task_view_dialog.dart';
import 'multi_select_filter_dialog.dart';
import '../utils/clipboard_helper.dart';
import '../design_system/taskflow_design_system.dart';
import 'gantt_chart.dart';
import 'resizable_panel.dart';
import 'si_dashboard_view.dart';
import 'si_calendar_view.dart';

class SIView extends StatefulWidget {
  const SIView({super.key});

  @override
  State<SIView> createState() => _SIViewState();
}

class _SIViewState extends State<SIView> {
  final SIService _service = SIService();
  final StatusService _statusService = StatusService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ExecutorService _executorService = ExecutorService();

  bool _canEditTasks = false;
  bool _canEditTasksChecked = false;
  final Set<String> _sisVinculando = {};

  List<SI> _sis = [];
  List<SI> _todasSIs = []; // Todas as SIs para calcular estatísticas
  Set<String> _sisProgramadasIds = {}; // IDs das SIs vinculadas a tarefas
  Map<String, List<Map<String, dynamic>>> _sisProgramadasInfo = {}; // Lista de vinculações por SI
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  Set<String> _filtroStatus = {};
  Set<String> _filtroLocal = {};
  Set<String> _filtroStatusUsuario = {};
  DateTime? _dataInicio;
  DateTime? _dataFim;
  int _totalSIs = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  List<String> _statusDisponiveis = [];
  List<String> _locaisDisponiveis = [];
  List<String> _statusUsuarioDisponiveis = [];
  String _modoVisualizacao = 'tabela'; // 'tabela', 'cards', 'calendario', 'dashboard'
  String _filtroTipoSI = 'abertas'; // 'todas', 'abertas', 'concluidas'
  bool _filtrosVisiveis = false;
  StreamSubscription<String>? _statusChangeSubscription;

  // Variáveis para integração do Gantt Chart
  bool _exibirGantt = false;
  GanttScale _ganttScale = GanttScale.daily;
  final ScrollController _tableVerticalScrollController = ScrollController();
  final ScrollController _ganttVerticalScrollController = ScrollController();

  final viewOptions = [
    ('tabela', Icons.table_chart, 'Tabela'),
    ('cards', Icons.view_module, 'Cards'),
    ('calendario', Icons.calendar_today, 'Calendário'),
    ('dashboard', Icons.dashboard, 'Dashboard'),
  ];

  int? _sortColumnIndex = 9; // Coluna Data Início
  bool _ordenacaoAscendente = false; // Decrescente por padrão (mais recentes primeiro!)

  String _getSortColumnName() {
    switch (_sortColumnIndex) {
      case 2:
        return 'solicitacao';
      case 3:
        return 'tipo';
      case 4:
        return 'texto_breve';
      case 5:
        return 'status_sistema';
      case 6:
        return 'status_usuario';
      case 7:
        return 'local_instalacao';
      case 9:
        return 'data_inicio';
      case 10:
        return 'data_fim';
      case 11:
        return 'cen';
      default:
        return 'data_inicio';
    }
  }

  void _mudarOrdenacao(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _ordenacaoAscendente = ascending;
      _paginaAtual = 0;
    });
    _loadSIs();
  }

  @override
  void initState() {
    super.initState();
    _sincronizarScrolls();
    _loadTaskEditPermission();
    _loadStatus();
    _loadFiltros();
    _loadSIs();
    _loadTodasSIsParaEstatisticas();
    _loadSIsProgramadas();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _modoVisualizacao = Responsive.isDesktop(context) ? 'tabela' : 'cards';
        });
      }
    });
  }

  Future<void> _loadTaskEditPermission() async {
    try {
      final usuario = _authService.currentUser;
      if (usuario == null) {
        _canEditTasks = false;
        _canEditTasksChecked = true;
        return;
      }
      if (usuario.isRoot) {
        _canEditTasks = true;
        _canEditTasksChecked = true;
        return;
      }
      final email = usuario.email;
      if (email.isEmpty) {
        _canEditTasks = false;
        _canEditTasksChecked = true;
        return;
      }
      final permitido = await _executorService.isCoordenadorOuGerentePorLogin(email);
      _canEditTasks = permitido;
      _canEditTasksChecked = true;
    } catch (e) {
      _canEditTasks = false;
      _canEditTasksChecked = true;
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<bool> _ensureCanEditTasks() async {
    if (!_canEditTasksChecked) {
      await _loadTaskEditPermission();
    }
    if (!_canEditTasks) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apenas coordenador ou gerente pode criar/editar tarefas.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _sincronizarScrolls() {
    _tableVerticalScrollController.addListener(() {
      if (_tableVerticalScrollController.hasClients &&
          _ganttVerticalScrollController.hasClients &&
          _tableVerticalScrollController.position.isScrollingNotifier.value) {
        final targetOffset = _tableVerticalScrollController.offset.clamp(
          0.0,
          _ganttVerticalScrollController.position.maxScrollExtent,
        );
        _ganttVerticalScrollController.jumpTo(targetOffset);
      }
    });

    _ganttVerticalScrollController.addListener(() {
      if (_ganttVerticalScrollController.hasClients &&
          _tableVerticalScrollController.hasClients &&
          _ganttVerticalScrollController.position.isScrollingNotifier.value) {
        final targetOffset = _ganttVerticalScrollController.offset.clamp(
          0.0,
          _tableVerticalScrollController.position.maxScrollExtent,
        );
        _tableVerticalScrollController.jumpTo(targetOffset);
      }
    });
  }

  int _totalFiltrosAtivos() {
    return _filtroStatus.length +
        _filtroLocal.length +
        _filtroStatusUsuario.length +
        (_dataInicio != null ? 1 : 0) +
        (_dataFim != null ? 1 : 0);
  }

  Color _getLocalColor(String? local) {
    if (local == null || local.isEmpty) return Colors.grey.shade200;
    final hash = local.hashCode.abs();
    final colors = [
      const Color(0xFFE0F2FE),
      const Color(0xFFDCFCE7),
      const Color(0xFFFEF3C7),
      const Color(0xFFFEE2E2),
      const Color(0xFFF3E8FF),
      const Color(0xFFE0E7FF),
      const Color(0xFFCCFBF1),
      const Color(0xFFFFEDD5),
    ];
    return colors[hash % colors.length];
  }

  Color _getLocalTextColor(String? local) {
    if (local == null || local.isEmpty) return Colors.grey.shade700;
    final hash = local.hashCode.abs();
    final textColors = [
      const Color(0xFF0369A1),
      const Color(0xFF15803D),
      const Color(0xFFB45309),
      const Color(0xFFB91C1C),
      const Color(0xFF6B21A8),
      const Color(0xFF3730A3),
      const Color(0xFF0F766E),
      const Color(0xFFC2410C),
    ];
    return textColors[hash % textColors.length];
  }

  Task _convertSIToTask(SI si) {
    final listVinc = _sisProgramadasInfo[si.id];
    final programadaInfo = listVinc?.isNotEmpty == true ? listVinc!.first : null;
    final tarefaVinc = programadaInfo?['tarefa'] as Map<String, dynamic>?;

    DateTime? inicio = si.dataInicio ?? si.dataCriacao;
    if (tarefaVinc?['data_inicio'] != null) {
      inicio = tarefaVinc!['data_inicio'] is String
          ? DateTime.parse(tarefaVinc['data_inicio'] as String)
          : tarefaVinc['data_inicio'] as DateTime;
    }

    DateTime? fim = si.dataFim;
    if (tarefaVinc?['data_fim'] != null) {
      fim = tarefaVinc!['data_fim'] is String
          ? DateTime.parse(tarefaVinc['data_fim'] as String)
          : tarefaVinc['data_fim'] as DateTime;
    }

    inicio ??= DateTime.now();
    fim ??= inicio.add(const Duration(days: 1));
    if (fim.isBefore(inicio)) fim = inicio.add(const Duration(days: 1));

    final tarefaNome = tarefaVinc?['tarefa'] ?? si.textoBreve ?? si.solicitacao;
    final tarefaStatus = (tarefaVinc?['status'] as String?) ??
        (si.statusUsuario?.isNotEmpty == true ? si.statusUsuario! : 'CRI.');

    final localStr = si.local ?? si.localInstalacao;

    return Task(
      id: si.id,
      tarefa: 'SI ${si.solicitacao} - $tarefaNome',
      dataInicio: inicio,
      dataFim: fim,
      status: tarefaStatus,
      regional: 'TODAS',
      divisao: si.cen ?? 'SI',
      tipo: si.tipo ?? 'SI',
      coordenador: si.criadoPor ?? 'N/A',
      si: si.solicitacao,
      observacoes: si.textoBreve ?? '',
      locais: [if (localStr != null && localStr.isNotEmpty) localStr],
    );
  }

  @override
  void dispose() {
    _statusChangeSubscription?.cancel();
    _tableVerticalScrollController.dispose();
    _ganttVerticalScrollController.dispose();
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

  Future<void> _loadSIsProgramadas() async {
    try {
      final programadas = await _service.getSIsProgramadas();
      final ids = <String>{};
      final info = <String, List<Map<String, dynamic>>>{};
      
      for (final item in programadas) {
        final si = item['si'] as SI;
        final siId = si.id;
        ids.add(siId);
        
        // Adicionar à lista de vinculações desta SI
        if (!info.containsKey(siId)) {
          info[siId] = [];
        }
        info[siId]!.add(item);
      }
      
      // Ordenar cada lista por data de vinculação (mais recente primeiro)
      for (final siId in info.keys) {
        info[siId]!.sort((a, b) {
          DateTime? parseDate(dynamic v) {
            if (v == null) return null;
            if (v is DateTime) return v;
            if (v is String) return DateTime.tryParse(v);
            return null;
          }
          final dataA = parseDate(a['vinculado_em']);
          final dataB = parseDate(b['vinculado_em']);
          if (dataA == null && dataB == null) return 0;
          if (dataA == null) return 1;
          if (dataB == null) return -1;
          return dataB.compareTo(dataA); // Mais recente primeiro
        });
      }
      
      if (mounted) {
        setState(() {
          _sisProgramadasIds = ids;
          _sisProgramadasInfo = info;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar SIs programadas: $e');
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

  Future<void> _loadSIs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Set<String> baseStatusSistema = _statusDisponiveis.isNotEmpty
          ? _statusDisponiveis.toSet()
          : {'CRI.', 'PREP', 'LIBE', 'ENCE', 'ENTE'};
      if (_filtroStatus.isNotEmpty) {
        baseStatusSistema = _filtroStatus;
      }

      List<String>? backendFiltroStatus;
      if (_filtroTipoSI == 'abertas') {
        backendFiltroStatus = baseStatusSistema
            .where(
              (s) =>
                  !s.toUpperCase().contains('ENCE') &&
                  !s.toUpperCase().contains('ENTE'),
            )
            .toList();
        if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
      } else if (_filtroTipoSI == 'concluidas') {
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

      final sis = await _service.getAllSIs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: _itensPorPagina,
        offset: _paginaAtual * _itensPorPagina,
        orderBy: _getSortColumnName(),
        ascending: _ordenacaoAscendente,
      );

      final total = await _service.contarSIs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
      );

      setState(() {
        _sis = sis;
        _totalSIs = total;
        _isLoading = false;
      });
      // Recarregar SIs programadas quando carregar SIs
      _loadSIsProgramadas();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar SIs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Função auxiliar para decodificar bytes como UTF-8
  // O arquivo está em UTF-8, mas pode ter alguns bytes malformados
  String _decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    
    // Detectar encoding: verificar se há caracteres típicos de Latin-1
    // que não são válidos em UTF-8
    bool pareceLatin1 = false;
    for (int i = 0; i < bytes.length && i < 1000; i++) {
      if (bytes[i] > 127 && bytes[i] < 160) {
        pareceLatin1 = true;
        break;
      }
    }
    
    // Se parece Latin-1, tentar primeiro como Latin-1
    if (pareceLatin1) {
      try {
        final latin1Result = latin1.decode(bytes);
        print('✅ Arquivo decodificado como Latin-1 (ISO-8859-1)');
        return latin1Result;
      } catch (e) {
        print('⚠️ Erro ao decodificar como Latin-1: $e');
      }
    }
    
    // Tentar decodificar como UTF-8 sem allowMalformed primeiro
    try {
      final utf8Result = utf8.decode(bytes);
      // Verificar se não há caracteres de substituição (indicando encoding errado)
      if (!utf8Result.contains('')) {
        print('✅ Arquivo decodificado como UTF-8');
        return utf8Result;
      } else {
        print('⚠️ UTF-8 contém caracteres de substituição, tentando Latin-1...');
        throw FormatException('UTF-8 contém caracteres de substituição');
      }
    } catch (e) {
      print('⚠️ Erro ao decodificar UTF-8: $e');
      print('   Tentando como Latin-1...');
      
      // Tentar Latin-1
      try {
        final latin1Result = latin1.decode(bytes);
        print('✅ Arquivo decodificado como Latin-1 (ISO-8859-1)');
        return latin1Result;
      } catch (e2) {
        print('❌ Erro ao decodificar como Latin-1: $e2');
        // Último recurso: UTF-8 com allowMalformed e remover caracteres de substituição
        try {
          final utf8Malformed = utf8.decode(bytes, allowMalformed: true);
          final cleaned = utf8Malformed.replaceAll('', '');
          print('⚠️ Fallback: Arquivo decodificado como UTF-8 (com limpeza)');
          return cleaned;
        } catch (e3) {
          print('❌ Erro crítico ao decodificar arquivo: $e3');
          // Último recurso absoluto: tentar Latin-1 mesmo com erro
          try {
            return latin1.decode(bytes);
          } catch (e4) {
            // Se tudo falhar, retornar string vazia ou tentar UTF-8 com allowMalformed
            return utf8.decode(bytes, allowMalformed: true).replaceAll('', '');
          }
        }
      }
    }
  }

  Future<void> _importarCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        String csvContent;

        try {
          // Web: usar bytes (path não está disponível)
          if (kIsWeb) {
            if (file.bytes == null || file.bytes!.isEmpty) {
              throw Exception('Arquivo vazio ou não foi possível ler');
            }
            csvContent = _decodeBytes(file.bytes!);
          } else {
            // Mobile/Desktop: usar path
            if (file.path == null) {
              throw Exception('Caminho do arquivo não disponível');
            }
            final fileObj = File(file.path!);
            // Ler como bytes primeiro para poder tentar diferentes encodings
            final bytes = await fileObj.readAsBytes();
            if (bytes.isEmpty) {
              throw Exception('Arquivo vazio');
            }
            csvContent = _decodeBytes(bytes);
          }

          if (csvContent.isEmpty) {
            throw Exception('Conteúdo do arquivo está vazio após decodificação');
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao ler arquivo: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }

        Map<String, dynamic> resultado;
        try {
          resultado = await _service.importarSIsDoCSV(csvContent);
        } catch (e) {
          print('❌ Erro crítico na importação: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao processar CSV: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resultado['sucesso'] == true
                    ? 'Importação concluída: ${resultado['importadas']} SIs importados, ${resultado['duplicatas']} duplicatas ignoradas'
                    : 'Erro na importação: ${resultado['erro'] ?? 'Erro desconhecido'}',
              ),
              backgroundColor: resultado['sucesso'] == true ? Colors.green : Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        if (resultado['sucesso'] == true && mounted) {
          try {
            await _loadFiltros();
            await _loadSIs();
            await _loadTodasSIsParaEstatisticas();
            await _loadSIsProgramadas();
          } catch (e) {
            print('⚠️ Erro ao recarregar dados após importação: $e');
            // Não mostrar erro ao usuário, pois a importação foi bem-sucedida
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro crítico em _importarCSV: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadTodasSIsParaEstatisticas() async {
    try {
      Set<String> baseStatusSistema = _statusDisponiveis.isNotEmpty
          ? _statusDisponiveis.toSet()
          : {'CRI.', 'PREP', 'LIBE', 'ENCE', 'ENTE'};
      if (_filtroStatus.isNotEmpty) {
        baseStatusSistema = _filtroStatus;
      }

      List<String>? backendFiltroStatus;
      if (_filtroTipoSI == 'abertas') {
        backendFiltroStatus = baseStatusSistema
            .where(
              (s) =>
                  !s.toUpperCase().contains('ENCE') &&
                  !s.toUpperCase().contains('ENTE'),
            )
            .toList();
        if (backendFiltroStatus.isEmpty) backendFiltroStatus = ['DUMMY_EMPTY'];
      } else if (_filtroTipoSI == 'concluidas') {
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

      // Carregar todas as SIs sem paginação para calcular estatísticas, usando os mesmos filtros
      final todasSIs = await _service.getAllSIs(
        filtroStatus: backendFiltroStatus,
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: null, // Sem limite
        offset: null,
      );

      if (mounted) {
        setState(() {
          _todasSIs = todasSIs;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar todas as SIs para estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isMobile = Responsive.isMobile(context);
    final isCompact = isMobile || MediaQuery.of(context).size.width < 900;
    final totalFiltros = _totalFiltrosAtivos();

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Toolbar superior moderna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Título e seletor rápido (Todas, Abertas, Concluídas)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SIs',
                      style: typography.pageTitle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'abertas', label: Text('Abertas')),
                        ButtonSegment(value: 'concluidas', label: Text('Concluídas')),
                        ButtonSegment(value: 'todas', label: Text('Todas')),
                      ],
                      selected: {_filtroTipoSI},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _filtroTipoSI = newSelection.first;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: colors.surface,
                        selectedBackgroundColor: colors.primary,
                        selectedForegroundColor: Colors.white,
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.borderSubtle, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                      ),
                    ),
                  ],
                ),

                // Modos de visualização e ações
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Seletor de modo de visualização
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
                          });
                        },
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: colors.surface,
                          selectedBackgroundColor: colors.primary.withValues(alpha: 0.12),
                          selectedForegroundColor: colors.primary,
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.borderSubtle, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                          ),
                        ),
                      )
                    else
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.borderSubtle),
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                          ),
                          child: DropdownButton<String>(
                            value: _modoVisualizacao,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            dropdownColor: colors.surface,
                            items: viewOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt.$1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(opt.$2, size: 18, color: colors.primary),
                                    const SizedBox(width: 8),
                                    Text(opt.$3, style: typography.bodySmall),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _modoVisualizacao = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                    // Botão de alternância do Gantt desabilitado temporariamente
                    /*
                    if (_modoVisualizacao == 'tabela')
                      IconButton(
                        icon: Icon(
                          _exibirGantt ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                          color: _exibirGantt ? colors.primary : colors.textSecondary,
                        ),
                        tooltip: _exibirGantt ? 'Ocultar Gantt' : 'Exibir Gantt',
                        onPressed: () {
                          setState(() {
                            _exibirGantt = !_exibirGantt;
                          });
                        },
                      ),
                    */

                    // Importar CSV
                    OutlinedButton.icon(
                      onPressed: _importarCSV,
                      icon: const Icon(Icons.upload_file),
                      label: isCompact ? const SizedBox.shrink() : const Text('Importar CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.borderDefault),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                        minimumSize: Size(isCompact ? 40 : 0, 36),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 14,
                          vertical: 10,
                        ),
                      ),
                    ),

                    // Atualizar
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                      icon: const Icon(Icons.refresh),
                      label: isCompact ? const SizedBox.shrink() : const Text('Atualizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                        minimumSize: Size(isCompact ? 40 : 0, 36),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 16,
                          vertical: 10,
                        ),
                      ),
                    ),

                    // Filtros
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _filtrosVisiveis = !_filtrosVisiveis;
                        });
                      },
                      icon: Badge(
                        isLabelVisible: totalFiltros > 0,
                        label: Text('$totalFiltros'),
                        child: Icon(
                          _filtrosVisiveis ? Icons.filter_alt_off : Icons.filter_alt,
                          color: totalFiltros > 0 ? colors.primary : colors.textSecondary,
                        ),
                      ),
                      label: isCompact ? const SizedBox.shrink() : const Text('Filtros'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _filtrosVisiveis
                            ? colors.primary.withValues(alpha: 0.08)
                            : colors.surface,
                        side: BorderSide(
                          color: _filtrosVisiveis ? colors.primary : colors.borderDefault,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                        ),
                        minimumSize: Size(isCompact ? 40 : 0, 36),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filtros
          if (_filtrosVisiveis)
            Container(
              padding: const EdgeInsets.all(TFSpacing.s12),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                border: Border(
                  bottom: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 220,
                    child: _buildMultiSelectFilterField(
                      'Local / Instalação',
                      _filtroLocal,
                      _locaisDisponiveis,
                      (newValues) {
                        setState(() {
                          _filtroLocal = newValues;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 180,
                    child: _buildMultiSelectFilterField(
                      'Status Usuário',
                      _filtroStatusUsuario,
                      _statusUsuarioDisponiveis,
                      (newValues) {
                        setState(() {
                          _filtroStatusUsuario = newValues;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 140,
                    child: _buildDateFilterField(
                      'Data Início',
                      _dataInicio,
                      (date) {
                        setState(() {
                          _dataInicio = date;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 140,
                    child: _buildDateFilterField(
                      'Data Fim',
                      _dataFim,
                      (date) {
                        setState(() {
                          _dataFim = date;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                    ),
                  ),
                  if (totalFiltros > 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _filtroStatus.clear();
                          _filtroLocal.clear();
                          _filtroStatusUsuario.clear();
                          _dataInicio = null;
                          _dataFim = null;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Limpar Filtros'),
                    ),
                ],
              ),
            ),

          // Barra de status com total
          if (_modoVisualizacao != 'dashboard')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$_totalSIs SIs encontradas (${_sis.length} nesta página)',
                    style: typography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_modoVisualizacao != 'calendario')
                    Text(
                      'Página ${_paginaAtual + 1} de ${(_totalSIs / _itensPorPagina).ceil().clamp(1, 9999)}',
                      style: typography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

          // Conteúdo Principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _modoVisualizacao == 'dashboard'
                    ? SiDashboardView(
                        sis: _todasSIs,
                        sisProgramadasIds: _sisProgramadasIds,
                      )
                    : _modoVisualizacao == 'calendario'
                        ? SiCalendarView(
                            sis: _todasSIs,
                            onSITap: _mostrarDetalhesSI,
                          )
                        : _sis.isEmpty
                            ? Center(
                                child: TFEmptyState(
                                  icon: Icons.search_off,
                                  title: 'Nenhuma SI encontrada',
                                  description: totalFiltros > 0
                                      ? 'Não há SIs correspondentes aos filtros aplicados.'
                                      : 'Não há SIs cadastradas.',
                                  action: totalFiltros > 0
                                      ? OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _filtroStatus.clear();
                                              _filtroLocal.clear();
                                              _filtroStatusUsuario.clear();
                                              _dataInicio = null;
                                              _dataFim = null;
                                              _paginaAtual = 0;
                                            });
                                            _loadSIs();
                                            _loadTodasSIsParaEstatisticas();
                                          },
                                          child: const Text('Limpar Filtros'),
                                        )
                                      : null,
                                ),
                              )
                            : _modoVisualizacao == 'tabela'
                                ? (_exibirGantt
                                    ? _buildSplitTabelaGanttView()
                                    : _buildTabelaView(controller: _tableVerticalScrollController))
                                : ListView.builder(
                                    itemCount: _sis.length,
                                    itemBuilder: (context, index) {
                                      final si = _sis[index];
                                      return _buildSICard(si);
                                    },
                                  ),
          ),

          // Paginação (oculta no dashboard e calendário)
          if (_modoVisualizacao != 'dashboard' &&
              _modoVisualizacao != 'calendario' &&
              _totalSIs > _itensPorPagina)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.borderSubtle),
                ),
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
                            _loadSIs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalSIs / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalSIs
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            _loadSIs();
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
  Future<void> _criarTarefaDaSI(SI si) async {
    if (!await _ensureCanEditTasks()) return;
    try {
      // Calcular datas padrão
      final dataInicio = si.dataInicio ?? DateTime.now();
      final dataFim = si.dataFim ?? dataInicio.add(const Duration(days: 1));
      
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
          await _service.vincularSITarefa(createdTask.id, si.id);
          await _loadSIsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarefa criada e vinculada à SI ${si.solicitacao} com sucesso!'),
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

  // Vincular SI a uma tarefa existente
  Future<void> _vincularSITarefaExistente(SI si) async {
    if (_sisVinculando.contains(si.id)) return;
    setState(() {
      _sisVinculando.add(si.id);
    });

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
      
      // Extrair local da SI para pré-filtrar tarefas do mesmo local (apenas local e localInstalacao)
      final locaisSI = <String>[];
      if (si.local != null && si.local!.trim().isNotEmpty) {
        locaisSI.add(si.local!.trim());
      }
      if (si.localInstalacao != null && si.localInstalacao!.trim().isNotEmpty) {
        locaisSI.add(si.localInstalacao!.trim());
      }

      final localSIPrincipal = (si.local != null && si.local!.trim().isNotEmpty)
          ? si.local!.trim()
          : (locaisSI.isNotEmpty ? locaisSI.first : null);

      if (!mounted) return;

      final tarefaSelecionada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskSelectionDialog(
          tasks: todasTarefas,
          siSolicitacao: si.solicitacao,
          localPadrao: localSIPrincipal,
          locaisPadrao: locaisSI,
        ),
      );
      
      if (tarefaSelecionada != null) {
        try {
          await _service.vincularSITarefa(tarefaSelecionada.id, si.id);
          await _loadSIsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('SI ${si.solicitacao} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao vincular SI: $e');
          print('❌ Stack trace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular SI: ${e.toString()}'),
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
            content: Text('Erro ao vincular SI: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sisVinculando.remove(si.id);
        });
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
          builder: (context) => TaskViewDialog(
            task: task,
            onUpdated: (updatedTask) {
              _loadSIsProgramadas();
            },
          ),
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

  // Mostrar todas as vinculações de uma SI
  void _mostrarTodasVinculacoes(SI si, List<Map<String, dynamic>> vinculacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarefas vinculadas à SI ${si.solicitacao}'),
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

  Future<void> _copiarParaAreaTransferencia(String texto, String mensagemSucesso) async {
    await ClipboardHelper.copyAndNotify(
      context,
      texto,
      successMessage: mensagemSucesso,
      errorMessage: 'Não foi possível copiar o texto.',
      duration: const Duration(seconds: 1),
    );
  }

  Widget _buildSICard(SI si) {
    final colors = context.tfColors;
    final isProgramada = _sisProgramadasIds.contains(si.id);
    final programadasList = isProgramada ? _sisProgramadasInfo[si.id] : null;
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
              backgroundColor: _getStatusColor(si.statusSistema),
              child: Text(
                si.statusUsuario ?? '?',
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
                'SI: ${si.solicitacao}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
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
            if (si.textoBreve != null)
              Text(
                si.textoBreve!,
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
                if (si.dataInicio != null)
                  Text(
                    'Início: ${_formatDate(si.dataInicio!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (si.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(si.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      si.statusSistema!,
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
                _buildInfoRow('Status Sistema', si.statusSistema),
                _buildInfoRow('Status Usuário', si.statusUsuario),
                _buildInfoRow('Tipo', si.tipo),
                _buildInfoRow('Texto Breve', si.textoBreve),
                _buildInfoRow('Local Instalação', si.localInstalacao),
                _buildInfoRow('Cen', si.cen),
                _buildInfoRow('CntrTrab', si.cntrTrab),
                if (si.dataInicio != null)
                  _buildInfoRow('Data Início', _formatDate(si.dataInicio!)),
                if (si.dataFim != null)
                  _buildInfoRow('Data Fim', _formatDate(si.dataFim!)),
                
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _canEditTasks ? () => _criarTarefaDaSI(si) : null,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: colors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _sisVinculando.contains(si.id)
                          ? null
                          : () => _vincularSITarefaExistente(si),
                      icon: _sisVinculando.contains(si.id)
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                            )
                          : const Icon(Icons.link, size: 18),
                      label: const Text('Vincular a Tarefa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r8)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('ABER')) return Colors.orange;
    if (status.contains('CAPC')) return Colors.blue;
    if (status.contains('DMNV')) return Colors.red;
    if (status.contains('ERRD')) return Colors.red;
    if (status.contains('SCDM')) return Colors.green;
    return Colors.grey;
  }

  Widget _buildSplitTabelaGanttView() {
    final List<Task> tasksForGantt = _sis.map((si) => _convertSIToTask(si)).toList();

    DateTime ganttStartDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime ganttEndDate = DateTime.now().add(const Duration(days: 30));

    if (_sis.isNotEmpty) {
      DateTime? minDate;
      DateTime? maxDate;
      for (final task in tasksForGantt) {
        final inicio = task.dataInicio;
        final fim = task.dataFim;
        if (minDate == null || inicio.isBefore(minDate)) minDate = inicio;
        if (maxDate == null || fim.isAfter(maxDate)) maxDate = fim;
      }
      if (minDate != null) ganttStartDate = minDate.subtract(const Duration(days: 2));
      if (maxDate != null) ganttEndDate = maxDate.add(const Duration(days: 5));
    }

    return ResizablePanel(
      initialLeftWidth: MediaQuery.of(context).size.width * 0.5,
      minLeftWidth: 250,
      minRightWidth: 250,
      leftChild: _buildTabelaView(controller: _tableVerticalScrollController),
      rightChild: GanttChart(
        key: ValueKey('gantt_chart_sis_${tasksForGantt.length}_$_ganttScale'),
        tasks: tasksForGantt,
        startDate: ganttStartDate,
        endDate: ganttEndDate,
        scale: _ganttScale,
        onScaleChanged: (v) => setState(() => _ganttScale = v),
        scrollController: _ganttVerticalScrollController,
      ),
    );
  }

  bool _isSiAtrasada(SI si) {
    if (si.dataFim == null) return false;
    final statusSis = si.statusSistema?.toUpperCase() ?? '';
    final statusUsr = si.statusUsuario?.toUpperCase() ?? '';
    final isConcluida = statusSis.contains('CONC') ||
        statusSis.contains('CANC') ||
        statusSis.contains('ENC') ||
        statusUsr.contains('CONC') ||
        statusUsr.contains('CANC');
    if (isConcluida) return false;
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return si.dataFim!.isBefore(hojeSemHora);
  }

  Widget _buildTabelaView({ScrollController? controller}) {
    final colors = context.tfColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: controller,
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _ordenacaoAscendente,
          headingRowColor: WidgetStateProperty.all(colors.primary.withValues(alpha: 0.08)),
          columns: [
            const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: const Text('Solicitação', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Status Sistema', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Local Instalação', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            const DataColumn(label: Text('Tarefa Vinculada', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: const Text('Data Início', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Data Fim', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
            DataColumn(
              label: const Text('Cen', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (col, asc) => _mudarOrdenacao(col, asc),
            ),
          ],
          rows: _sis.map((si) {
            final isProgramada = _sisProgramadasIds.contains(si.id);
            final programadasList = isProgramada ? _sisProgramadasInfo[si.id] : null;
            final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
            final totalVinculacoes = programadasList?.length ?? 0;
            final emAtraso = _isSiAtrasada(si);

            return DataRow(
              color: isProgramada && statusColor != null
                  ? WidgetStateProperty.all(statusColor.withValues(alpha: 0.1))
                  : null,
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Visualizar Detalhes',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _mostrarDetalhesSI(si),
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(TFRadius.r4),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Icon(Icons.visibility, size: 16, color: colors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Criar Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _canEditTasks ? () => _criarTarefaDaSI(si) : null,
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(TFRadius.r4),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Icon(
                                Icons.add_task,
                                size: 16,
                                color: _canEditTasks ? colors.success : colors.textDisabled,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Vincular a Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sisVinculando.contains(si.id)
                                ? null
                                : () => _vincularSITarefaExistente(si),
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(TFRadius.r4),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: _sisVinculando.contains(si.id)
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                                    )
                                  : Icon(Icons.link, size: 16, color: colors.info),
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
                                    color: Colors.white.withValues(alpha: 0.3),
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
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel_outlined, color: colors.textMuted, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Não Programada',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        si.solicitacao,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
                        child: Icon(Icons.copy, size: 16, color: colors.primary),
                      ),
                    ],
                  ),
                  onTap: () => _mostrarDetalhesSI(si),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      si.tipo ?? '-',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 280,
                    child: Text(
                      si.textoBreve ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(si.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      si.statusSistema ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  Text(si.statusUsuario ?? '-'),
                ),
                DataCell(
                  Builder(
                    builder: (context) {
                      final localTexto = (si.local != null && si.local!.isNotEmpty)
                          ? si.local!
                          : (si.localInstalacao ?? '-');
                      if (localTexto == '-') {
                        return const Text('-', style: TextStyle(color: Colors.grey));
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLocalColor(localTexto),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          localTexto,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getLocalTextColor(localTexto),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                DataCell(
                  isProgramada && tarefa != null
                      ? InkWell(
                          onTap: totalVinculacoes > 1
                              ? () => _mostrarTodasVinculacoes(si, programadasList!)
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
                                      color: totalVinculacoes > 1 ? Colors.orange : colors.primary,
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
                      : Text('-', style: TextStyle(color: colors.textMuted)),
                ),
                DataCell(
                  Text(si.dataInicio != null ? _formatDate(si.dataInicio!) : '-'),
                ),
                DataCell(
                  emAtraso
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(si.dataFim!),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(si.dataFim != null ? _formatDate(si.dataFim!) : '-'),
                ),
                DataCell(
                  Text(si.cen ?? '-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostrarDetalhesSI(SI si) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da SI: ${si.solicitacao}'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Solicitação', si.solicitacao),
              _buildInfoRow('Tipo', si.tipo),
              _buildInfoRow('Status Sistema', si.statusSistema),
              _buildInfoRow('Status Usuário', si.statusUsuario),
              _buildInfoRow('Texto Breve', si.textoBreve),
              _buildInfoRow('Local Instalação', si.localInstalacao),
              _buildInfoRow('Criado Por', si.criadoPor),
              _buildInfoRow('Cen', si.cen),
              _buildInfoRow('CntrTrab', si.cntrTrab),
              if (si.dataInicio != null)
                _buildInfoRow('Data Início', _formatDate(si.dataInicio!)),
              if (si.dataFim != null)
                _buildInfoRow('Data Fim', _formatDate(si.dataFim!)),
              if (si.dataImportacao != null)
                _buildInfoRow('Data Importação', _formatDate(si.dataImportacao!)),
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

