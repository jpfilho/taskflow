import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/nota_sap.dart';
import '../services/nota_sap_service.dart';
import '../utils/responsive.dart';
import 'task_form_dialog.dart';
import 'task_selection_dialog.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../services/status_service.dart';
import '../services/auth_service_simples.dart';
import '../services/executor_service.dart';
import 'task_view_dialog.dart';
import 'multi_select_filter_dialog.dart';
import 'notas_sap_calendar_view.dart';
import 'notas_sap_dashboard_view.dart';

class NotasSAPView extends StatefulWidget {
  final String? searchQuery;
  final String? modoVisualizacao;
  final ValueChanged<String>? onModoChange;

  const NotasSAPView({
    super.key,
    this.searchQuery,
    this.modoVisualizacao,
    this.onModoChange,
  });

  @override
  State<NotasSAPView> createState() => _NotasSAPViewState();
}

class _NotasSAPViewState extends State<NotasSAPView> {
  final NotaSAPService _service = NotaSAPService();
  final StatusService _statusService = StatusService();
  List<NotaSAP> _notas = [];
  List<NotaSAP> _todasNotas = []; // Todas as notas para calcular estatísticas
  Set<String> _notasProgramadasIds = {}; // IDs das notas vinculadas a tarefas
  Map<String, List<Map<String, dynamic>>> _notasProgramadasInfo = {}; // Lista de vinculações por nota
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  final Set<String> _notasVinculando = {}; // IDs das notas que estão sendo vinculadas
  Set<String> _notasSelecionadas = {}; // IDs das notas selecionadas para vinculação múltipla
  String? _filtroTipoNota = 'abertas'; // null = todas, 'abertas' = abertas, 'concluidas' = concluídas
  String? _filtroProgramacao; // null = todas, 'programadas' = programadas, 'nao_programadas' = não programadas
  Set<String> _filtroLocais = {}; // Multi-seleção para LOCAL
  Set<String> _filtroSalas = {}; // Multi-seleção para SALA
  Set<String> _filtroTipos = {}; // Multi-seleção para TIPO
  Set<String> _filtroNotas = {}; // Multi-seleção para NOTA
  Set<String> _filtroPrioridades = {}; // Multi-seleção para PRIORIDADE
  Set<String> _filtroStatusUsuario = {}; // Multi-seleção para STATUS USUARIO
  Set<String> _filtroResponsaveis = {}; // Multi-seleção para RESPONSAVEL
  Set<String> _filtroGPMs = {}; // Multi-seleção para GPM
  Set<String> _filtroStatusTarefa = {}; // Multi-seleção para STATUS da TAREFA
  bool _filtrosExpandidos = false;
  int _totalNotas = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  List<String> _locaisDisponiveis = [];
  List<String> _salasDisponiveis = [];
  List<String> _tiposDisponiveis = [];
  List<String> _notasDisponiveis = [];
  List<String> _prioridadesDisponiveis = [];
  List<String> _statusUsuarioDisponiveis = [];
  List<String> _responsaveisDisponiveis = [];
  List<String> _gpmsDisponiveis = [];
  List<String> _statusTarefaDisponiveis = [];
  bool _visualizacaoTabela = false; // false = cards, true = tabela
  String _modoVisualizacao = 'tabela'; // 'tabela', 'cards', 'calendario', 'dashboard'
  String? _tipoFiltro; // null = todos, 'vegetacao', 'trator', 'manutencao'
  int _contadorVegetacao = 0;
  int _contadorTrator = 0;
  int _contadorManutencao = 0;
  String _searchQuery = ''; // Termo de busca do HeaderBar
  List<NotaSAP> _todasNotasOrdenadas = []; // Todas as notas ordenadas (para paginação)
  bool _ordenacaoAscendente = true; // Direção da ordenação por prazo
  bool _canEditTasks = false; // Permissão para criar/editar tarefas
  bool _canEditTasksChecked = false; // Indica se a permissão já foi verificada
  bool _isCheckingTaskPermission = false; // Evita múltiplas verificações simultâneas
  bool _temSegmentoLinhasTransmissao = false; // Indica se o usuário tem o segmento "Linhas de Transmissão"
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ExecutorService _executorService = ExecutorService();

  int _totalFiltrosAtivos() {
    return _filtroLocais.length +
        _filtroSalas.length +
        _filtroTipos.length +
        _filtroNotas.length +
        _filtroPrioridades.length +
        _filtroStatusUsuario.length +
        _filtroResponsaveis.length +
        _filtroGPMs.length +
        _filtroStatusTarefa.length;
  }

  /// Retorna true se todas as listas de opções dos filtros estão vazias.
  /// Usado para recarregar filtros ao expandir o painel no mobile.
  bool _opcoesFiltrosEstaoVazias() {
    return _locaisDisponiveis.isEmpty &&
        _salasDisponiveis.isEmpty &&
        _tiposDisponiveis.isEmpty &&
        _notasDisponiveis.isEmpty &&
        _prioridadesDisponiveis.isEmpty &&
        _statusUsuarioDisponiveis.isEmpty &&
        _responsaveisDisponiveis.isEmpty &&
        _gpmsDisponiveis.isEmpty &&
        _statusTarefaDisponiveis.isEmpty;
  }

  List<String> _getOpcoesParaFiltro(String label) {
    switch (label) {
      case 'Local':
        return _locaisDisponiveis;
      case 'Sala':
        return _salasDisponiveis;
      case 'Tipo':
        return _tiposDisponiveis;
      case 'Nota':
        return _notasDisponiveis;
      case 'Prioridade':
        return _prioridadesDisponiveis;
      case 'Status Usuário':
        return _statusUsuarioDisponiveis;
      case 'Responsável':
        return _responsaveisDisponiveis;
      case 'GPM':
        return _gpmsDisponiveis;
      case 'Status (Tarefa)':
        return _statusTarefaDisponiveis;
      default:
        return [];
    }
  }

  void _atualizarStatusTarefaDisponiveis() {
    final statusSet = <String>{};
    // Status vindos das notas carregadas
    statusSet.addAll(_todasNotasOrdenadas
        .map((n) => n.tarefaStatus)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty));
    // Status vindos das notas programadas (tarefas)
    for (final entry in _notasProgramadasInfo.values) {
      for (final vinc in entry) {
        final tarefa = vinc['tarefa'] as Map<String, dynamic>?;
        final st = tarefa?['status'] as String?;
        if (st != null && st.trim().isNotEmpty) statusSet.add(st.trim());
      }
    }
    // Se ainda vazio, usar lista padrão de códigos de status de tarefa
    if (statusSet.isEmpty) {
      statusSet.addAll({'ANDA', 'PROG', 'CONC', 'RPAR', 'CANC'});
    }

    setState(() {
      _statusTarefaDisponiveis = statusSet.toList()..sort();
    });
  }

  Future<void> _copiarNota(String notaNumero) async {
    try {
      await Clipboard.setData(ClipboardData(text: notaNumero));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota copiada!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar a nota: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.modoVisualizacao != null) {
      _modoVisualizacao = widget.modoVisualizacao!;
      _visualizacaoTabela = widget.modoVisualizacao == 'tabela';
    }
    _searchQuery = widget.searchQuery ?? '';
    _loadTaskEditPermission();
    _verificarSegmentoLinhasTransmissao();
    _loadStatus();
    _loadFiltros();
    _loadNotas();
    _loadNotasProgramadas();
    _loadTodasNotasParaEstatisticas();
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _visualizacaoTabela = true;
          _modoVisualizacao = 'tabela';
        });
      } else {
        setState(() {
          _modoVisualizacao = 'cards';
        });
      }
    });
  }

  Future<void> _verificarSegmentoLinhasTransmissao() async {
    try {
      final usuario = _authService.currentUser;
      if (usuario == null) {
        setState(() {
          _temSegmentoLinhasTransmissao = false;
        });
        return;
      }

      // Verificar se o usuário tem o segmento "Linhas de Transmissão"
      // Normalizar para comparação (remover acentos e converter para minúsculas)
      final temSegmento = usuario.segmentos.any((segmento) {
        final segmentoNormalizado = segmento
            .toLowerCase()
            .replaceAll('ã', 'a')
            .replaceAll('á', 'a')
            .replaceAll('à', 'a')
            .replaceAll('â', 'a')
            .replaceAll('é', 'e')
            .replaceAll('ê', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ô', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('ç', 'c');
        return segmentoNormalizado.contains('linhas') &&
            segmentoNormalizado.contains('transmissao');
      });

      setState(() {
        _temSegmentoLinhasTransmissao = temSegmento;
      });
    } catch (e) {
      print('❌ Erro ao verificar segmento Linhas de Transmissão: $e');
      setState(() {
        _temSegmentoLinhasTransmissao = false;
      });
    }
  }

  Future<void> _loadTaskEditPermission() async {
    if (_isCheckingTaskPermission) return;
    _isCheckingTaskPermission = true;

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
    } catch (e, stackTrace) {
      print('❌ Erro ao verificar permissão de edição de tarefas: $e');
      print('   Stack trace: $stackTrace');
      _canEditTasks = false;
      _canEditTasksChecked = true;
    } finally {
      _isCheckingTaskPermission = false;
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

  @override
  void didUpdateWidget(NotasSAPView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualizar busca quando o searchQuery mudar
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _searchQuery = widget.searchQuery ?? '';
        _paginaAtual = 0;
      });
      _loadNotas();
      _loadTodasNotasParaEstatisticas();
    }
    if (widget.modoVisualizacao != oldWidget.modoVisualizacao &&
        widget.modoVisualizacao != null) {
      setState(() {
        _modoVisualizacao = widget.modoVisualizacao!;
        _visualizacaoTabela = widget.modoVisualizacao == 'tabela';
      });
    }
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
      print('❌ Erro ao carregar status: $e');
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


  Future<void> _loadNotasProgramadas() async {
    try {
      final programadas = await _service.getNotasProgramadas();
      final ids = <String>{};
      final info = <String, List<Map<String, dynamic>>>{};
      
      for (final item in programadas) {
        final nota = item['nota'] as NotaSAP;
        ids.add(nota.id);
        
        // Adicionar à lista de vinculações desta nota
        if (!info.containsKey(nota.id)) {
          info[nota.id] = [];
        }
        info[nota.id]!.add(item);
      }
      
      // Ordenar cada lista por data de vinculação (mais recente primeiro)
      for (final notaId in info.keys) {
        info[notaId]!.sort((a, b) {
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
          _notasProgramadasIds = ids;
          _notasProgramadasInfo = info;
        });
        _atualizarStatusTarefaDisponiveis();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar notas programadas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFiltros() async {
    // Se já temos notas carregadas, calcular valores dos filtros a partir delas
    // Isso garante que os filtros sejam interdependentes baseados nos dados já filtrados
    if (_todasNotasOrdenadas.isNotEmpty) {
      final localSet = <String>{};
      final salaSet = <String>{};
      final tipoSet = <String>{};
      final notaSet = <String>{};
      final prioridadeSet = <String>{};
      final statusUsuarioSet = <String>{};
      final responsavelSet = <String>{};
      final gpmSet = <String>{};
      final statusTarefaSet = <String>{};
      
      for (var nota in _todasNotasOrdenadas) {
        if (nota.local != null && nota.local!.isNotEmpty) {
          localSet.add(nota.local!);
        }
        if (nota.sala != null && nota.sala!.isNotEmpty) {
          salaSet.add(nota.sala!);
        }
        if (nota.tipo != null && nota.tipo!.isNotEmpty) {
          tipoSet.add(nota.tipo!);
        }
        if (nota.nota.isNotEmpty) {
          notaSet.add(nota.nota);
        }
        if (nota.textPrioridade != null && nota.textPrioridade!.isNotEmpty) {
          prioridadeSet.add(nota.textPrioridade!);
        }
        if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty) {
          statusUsuarioSet.add(nota.statusUsuario!);
        }
        if (nota.denominacaoExecutor != null && nota.denominacaoExecutor!.isNotEmpty) {
          responsavelSet.add(nota.denominacaoExecutor!);
        }
        if (nota.gpm != null && nota.gpm!.isNotEmpty) {
          gpmSet.add(nota.gpm!);
        }
        if (nota.tarefaStatus != null && nota.tarefaStatus!.isNotEmpty) {
          statusTarefaSet.add(nota.tarefaStatus!);
        }
      }

      // Considerar também a página atual (_notas) para capturar qualquer status já exibido
      for (var nota in _notas) {
        if (nota.tarefaStatus != null && nota.tarefaStatus!.isNotEmpty) {
          statusTarefaSet.add(nota.tarefaStatus!);
        }
      }
      
      setState(() {
        _locaisDisponiveis = localSet.toList()..sort();
        _salasDisponiveis = salaSet.toList()..sort();
        _tiposDisponiveis = tipoSet.toList()..sort();
        _notasDisponiveis = notaSet.toList()..sort();
        _prioridadesDisponiveis = prioridadeSet.toList()..sort();
      _statusUsuarioDisponiveis = statusUsuarioSet.toList()..sort();
        _responsaveisDisponiveis = responsavelSet.toList()..sort();
        _gpmsDisponiveis = gpmSet.toList()..sort();
      // Somar também os status das tarefas programadas já carregadas
      for (final entry in _notasProgramadasInfo.values) {
        for (final vinc in entry) {
          final tarefa = vinc['tarefa'] as Map<String, dynamic>?;
          final st = tarefa?['status'] as String?;
          if (st != null && st.trim().isNotEmpty) statusTarefaSet.add(st.trim());
        }
      }
      _statusTarefaDisponiveis = statusTarefaSet.toList()..sort();
      });
    } else {
      // Se não temos notas carregadas, buscar do serviço
      try {
        final valores = await _service.getValoresFiltros(
          filtroTipoNota: _filtroTipoNota,
          filtroLocais: _filtroLocais.isNotEmpty ? _filtroLocais.toList() : null,
          filtroSalas: _filtroSalas.isNotEmpty ? _filtroSalas.toList() : null,
          filtroTipos: _filtroTipos.isNotEmpty ? _filtroTipos.toList() : null,
          filtroNotas: _filtroNotas.isNotEmpty ? _filtroNotas.toList() : null,
          filtroPrioridades: _filtroPrioridades.isNotEmpty ? _filtroPrioridades.toList() : null,
          filtroStatusUsuario: _filtroStatusUsuario.isNotEmpty ? _filtroStatusUsuario.toList() : null,
          filtroResponsaveis: _filtroResponsaveis.isNotEmpty ? _filtroResponsaveis.toList() : null,
          filtroGPMs: _filtroGPMs.isNotEmpty ? _filtroGPMs.toList() : null,
        );
        if (!mounted) return;
        setState(() {
          _locaisDisponiveis = valores['local'] ?? [];
          _salasDisponiveis = valores['sala'] ?? [];
          _tiposDisponiveis = valores['tipo'] ?? [];
          _notasDisponiveis = valores['nota'] ?? [];
          _prioridadesDisponiveis = valores['prioridade'] ?? [];
          _statusUsuarioDisponiveis = valores['status_usuario'] ?? [];
          _responsaveisDisponiveis = valores['responsavel'] ?? [];
          _gpmsDisponiveis = valores['gpm'] ?? [];
          _statusTarefaDisponiveis = valores['status_tarefa'] ?? [];
        });
      } catch (e, st) {
        debugPrint('❌ [NotasSAPView] Erro ao carregar opções dos filtros: $e');
        debugPrint('   Stack: $st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível carregar as opções dos filtros. Toque em Filtros novamente para tentar.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Tentar',
                onPressed: () => _loadFiltros(),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadNotas() async {
    final totalSw = Stopwatch()..start();
    print('⏱ [NotasSAPView] _loadNotas iniciado | pagina=$_paginaAtual | itensPorPagina=$_itensPorPagina');
    
    setState(() {
      _isLoading = true;
    });

    try {
      final querySw = Stopwatch()..start();
      // Carregar TODAS as notas (sem paginação) para ordenar corretamente
      var todasNotas = await _service.getAllNotas(
        filtroTipoNota: _filtroTipoNota,
        filtroLocais: _filtroLocais.isNotEmpty ? _filtroLocais.toList() : null,
        filtroSalas: _filtroSalas.isNotEmpty ? _filtroSalas.toList() : null,
        filtroTipos: _filtroTipos.isNotEmpty ? _filtroTipos.toList() : null,
        filtroNotas: _filtroNotas.isNotEmpty ? _filtroNotas.toList() : null,
        filtroPrioridades: _filtroPrioridades.isNotEmpty ? _filtroPrioridades.toList() : null,
        filtroStatusUsuario: _filtroStatusUsuario.isNotEmpty ? _filtroStatusUsuario.toList() : null,
        filtroResponsaveis: _filtroResponsaveis.isNotEmpty ? _filtroResponsaveis.toList() : null,
        filtroGPMs: _filtroGPMs.isNotEmpty ? _filtroGPMs.toList() : null,
        limit: null, // Sem limite para carregar todas
        offset: null, // Sem offset
      );

      querySw.stop();
      print('⏱ [NotasSAPView] Query getAllNotas concluída em ${querySw.elapsedMilliseconds}ms | notas=${todasNotas.length}');

      final filterSw = Stopwatch()..start();
      // Aplicar filtro de programação (programadas/não programadas)
      if (_filtroProgramacao != null) {
        todasNotas = todasNotas.where((nota) {
          final isProgramada = _notasProgramadasIds.contains(nota.id);
          if (_filtroProgramacao == 'programadas') {
            return isProgramada;
          } else if (_filtroProgramacao == 'nao_programadas') {
            return !isProgramada;
          }
          return true;
        }).toList();
      }

      // Aplicar filtro por tipo (vegetação, trator, manutenção) baseado na descrição
      if (_tipoFiltro != null) {
        todasNotas = todasNotas.where((nota) {
          final descricao = nota.descricao?.toUpperCase() ?? '';
          switch (_tipoFiltro) {
            case 'vegetacao':
              return descricao.startsWith('PD');
            case 'trator':
              return descricao.startsWith('TR');
            case 'manutencao':
              return descricao.startsWith('MT');
            default:
              return true;
          }
        }).toList();
      }

      // Aplicar filtro de busca se houver texto
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        todasNotas = todasNotas.where((nota) {
          return (nota.nota.toLowerCase().contains(lowerQuery)) ||
              (nota.ordem?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.descricao?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.localInstalacao?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.local?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.tipo?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.textPrioridade?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.statusUsuario?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.denominacaoExecutor?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.gpm?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.statusSistema?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.centroTrabalhoResponsavel?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.equipamento?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.tarefaStatus?.toLowerCase().contains(lowerQuery) ?? false) ||
              (nota.tarefaNome?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }

      filterSw.stop();
      print('⏱ [NotasSAPView] Filtros aplicados em ${filterSw.elapsedMilliseconds}ms | notas=${todasNotas.length}');

      final sortSw = Stopwatch()..start();
      // Ordenar TODAS as notas por prazo: pelos dias restantes em ordem crescente
      // Isso coloca automaticamente:
      // 1. Vencidas (negativas) primeiro: -219, -145, -114, -51 (do mais negativo para o menos negativo)
      // 2. Depois as que ainda não venceram (positivas): 49, 54, 54, 54 (em ordem crescente)
      // 3. Por último as sem prazo (NULL)
      todasNotas.sort((a, b) {
        final diasA = a.diasRestantes;
        final diasB = b.diasRestantes;
        
        // Se ambos são NULL, manter ordem original
        if (diasA == null && diasB == null) return 0;
        
        // Se A é NULL, A vai para o final
        if (diasA == null) return 1;
        
        // Se B é NULL, B vai para o final
        if (diasB == null) return -1;
        
        // Ambos têm prazo - ordenar pelos dias restantes em ordem crescente
        // compareTo já faz: negativos vêm antes de positivos, e ordena corretamente dentro de cada grupo
        return diasA.compareTo(diasB);
      });
      sortSw.stop();
      print('⏱ [NotasSAPView] Ordenação concluída em ${sortSw.elapsedMilliseconds}ms');

      // Calcular total após busca e ordenação
      final total = todasNotas.length;

      final countSw = Stopwatch()..start();
      // Calcular contadores por tipo (baseado nas notas filtradas que estão sendo exibidas)
      _contadorVegetacao = todasNotas.where((nota) {
        final descricao = nota.descricao?.toUpperCase() ?? '';
        return descricao.startsWith('PD');
      }).length;
      
      _contadorTrator = todasNotas.where((nota) {
        final descricao = nota.descricao?.toUpperCase() ?? '';
        return descricao.startsWith('TR');
      }).length;
      
      _contadorManutencao = todasNotas.where((nota) {
        final descricao = nota.descricao?.toUpperCase() ?? '';
        return descricao.startsWith('MT');
      }).length;

      // Salvar todas as notas ordenadas para paginação
      _todasNotasOrdenadas = todasNotas;
      countSw.stop();
      print('⏱ [NotasSAPView] Contadores calculados em ${countSw.elapsedMilliseconds}ms');

      // Popular opções de status da tarefa
      _atualizarStatusTarefaDisponiveis();

      final paginationSw = Stopwatch()..start();
      // Aplicar paginação manualmente após ordenação
      final inicio = _paginaAtual * _itensPorPagina;
      final fim = (inicio + _itensPorPagina).clamp(0, todasNotas.length);
      final notas = todasNotas.sublist(inicio, fim);
      paginationSw.stop();
      print('⏱ [NotasSAPView] Paginação aplicada em ${paginationSw.elapsedMilliseconds}ms | página $_paginaAtual: notas ${inicio + 1} a $fim de $total');

      final setStateSw = Stopwatch()..start();
      setState(() {
        _notas = notas;
        _totalNotas = total;
        _isLoading = false;
      });
      setStateSw.stop();
      totalSw.stop();
      print('⏱ [NotasSAPView] setState concluído em ${setStateSw.elapsedMilliseconds}ms');
      print('⏱ [NotasSAPView] _loadNotas TOTAL: ${totalSw.elapsedMilliseconds}ms | notas=${notas.length} de $total');
      
      // Recarregar filtros DEPOIS de atualizar _todasNotasOrdenadas
      // Isso garante que os valores disponíveis reflitam apenas as opções válidas
      _loadFiltros();
    } catch (e, stackTrace) {
      print('❌ DEBUG _loadNotas: Erro: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar notas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Aplicar ordenação e paginação nas notas já carregadas
  void _aplicarOrdenacaoEPaginacao() {
    if (_todasNotasOrdenadas.isEmpty) {
      // Se não há notas carregadas, recarregar
      _loadNotas();
      return;
    }

    // Ordenar todas as notas
    _todasNotasOrdenadas.sort((a, b) {
      final diasA = a.diasRestantes;
      final diasB = b.diasRestantes;
      
      // Se ambos são NULL, manter ordem original
      if (diasA == null && diasB == null) return 0;
      
      // Se A é NULL, A vai para o final
      if (diasA == null) return _ordenacaoAscendente ? 1 : -1;
      
      // Se B é NULL, B vai para o final
      if (diasB == null) return _ordenacaoAscendente ? -1 : 1;
      
      // Ambos têm prazo - ordenar pelos dias restantes
      return _ordenacaoAscendente ? diasA.compareTo(diasB) : diasB.compareTo(diasA);
    });

    // Aplicar paginação
    final inicio = _paginaAtual * _itensPorPagina;
    final fim = (inicio + _itensPorPagina).clamp(0, _todasNotasOrdenadas.length);
    final notas = _todasNotasOrdenadas.sublist(inicio, fim);

    setState(() {
      _notas = notas;
    });
  }

  // Função auxiliar para decodificar bytes como UTF-8
  // O arquivo está em UTF-8, mas pode ter alguns bytes malformados

  Future<void> _loadTodasNotasParaEstatisticas() async {
    try {
      // OTIMIZAÇÃO: Reutilizar notas já carregadas em _loadNotas() se disponíveis
      // Isso evita uma segunda chamada ao getAllNotas que estava duplicando o tempo de carregamento
      List<NotaSAP> todasNotas;
      
      if (_todasNotasOrdenadas.isNotEmpty) {
        // Reutilizar notas já carregadas e filtradas
        todasNotas = List.from(_todasNotasOrdenadas);
        print('⏱ [NotasSAPView] _loadTodasNotasParaEstatisticas: Reutilizando ${todasNotas.length} notas já carregadas');
      } else {
        // Se não há notas carregadas, carregar agora (caso raro)
        print('⏱ [NotasSAPView] _loadTodasNotasParaEstatisticas: Carregando notas (cache vazio)');
        todasNotas = await _service.getAllNotas(
          filtroTipoNota: _filtroTipoNota,
          filtroLocais: _filtroLocais.isNotEmpty ? _filtroLocais.toList() : null,
          filtroTipos: _filtroTipos.isNotEmpty ? _filtroTipos.toList() : null,
          filtroNotas: _filtroNotas.isNotEmpty ? _filtroNotas.toList() : null,
          filtroPrioridades: _filtroPrioridades.isNotEmpty ? _filtroPrioridades.toList() : null,
          filtroStatusUsuario: _filtroStatusUsuario.isNotEmpty ? _filtroStatusUsuario.toList() : null,
          filtroResponsaveis: _filtroResponsaveis.isNotEmpty ? _filtroResponsaveis.toList() : null,
          filtroGPMs: _filtroGPMs.isNotEmpty ? _filtroGPMs.toList() : null,
          limit: null,
          offset: null,
        );

        // Aplicar filtro de programação (programadas/não programadas)
        if (_filtroProgramacao != null) {
          todasNotas = todasNotas.where((nota) {
            final isProgramada = _notasProgramadasIds.contains(nota.id);
            if (_filtroProgramacao == 'programadas') {
              return isProgramada;
            } else if (_filtroProgramacao == 'nao_programadas') {
              return !isProgramada;
            }
            return true;
          }).toList();
        }
      }

      // Filtro de status da tarefa vinculada
      if (_filtroStatusTarefa.isNotEmpty) {
        todasNotas = todasNotas.where((nota) {
          final st = nota.tarefaStatus ?? '';
          return _filtroStatusTarefa.isEmpty || _filtroStatusTarefa.contains(st);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _todasNotas = todasNotas;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar todas as notas para estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isCompact = isMobile || isTablet;
    final viewOptions = [
      ('tabela', Icons.table_chart, 'Tabela'),
      ('cards', Icons.view_module, 'Cards'),
      ('calendario', Icons.calendar_today, 'Calendário'),
      ('dashboard', Icons.dashboard, 'Dashboard'),
    ];
    final tipoNotaSegments = isCompact
        ? const [
            ButtonSegment(value: null, icon: Icon(Icons.all_inclusive)),
            ButtonSegment(value: 'abertas', icon: Icon(Icons.hourglass_empty)),
            ButtonSegment(value: 'concluidas', icon: Icon(Icons.check_circle)),
          ]
        : const [
            ButtonSegment(value: null, label: Text('Todas')),
            ButtonSegment(value: 'abertas', label: Text('Abertas')),
            ButtonSegment(value: 'concluidas', label: Text('Concluídas')),
          ];
    final programacaoSegments = isCompact
        ? const [
            ButtonSegment(value: null, icon: Icon(Icons.all_inclusive)),
            ButtonSegment(value: 'programadas', icon: Icon(Icons.event_available)),
            ButtonSegment(value: 'nao_programadas', icon: Icon(Icons.event_busy)),
          ]
        : const [
            ButtonSegment(value: null, label: Text('Todas')),
            ButtonSegment(value: 'programadas', label: Text('Programadas')),
            ButtonSegment(value: 'nao_programadas', label: Text('Não Programadas')),
          ];
    return Scaffold(
      body: Column(
        children: [
          // Header com filtros principais (visualização controlada pelo footbar no mobile)
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
                    'Notas SAP',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                SegmentedButton<String?>(
                  segments: tipoNotaSegments,
                  selected: {_filtroTipoNota},
                  onSelectionChanged: (Set<String?> newSelection) {
                    setState(() {
                      _filtroTipoNota = newSelection.first;
                      _paginaAtual = 0;
                    });
                    _loadNotas();
                    _loadTodasNotasParaEstatisticas();
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
                SegmentedButton<String?>(
                  segments: programacaoSegments,
                  selected: {_filtroProgramacao},
                  onSelectionChanged: (Set<String?> newSelection) {
                    setState(() {
                      _filtroProgramacao = newSelection.first;
                      _paginaAtual = 0;
                    });
                    _loadNotas();
                    _loadTodasNotasParaEstatisticas();
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
                if (!isCompact) _buildTipoToggle(),
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
                      if (widget.onModoChange != null) {
                        widget.onModoChange!(_modoVisualizacao);
                      }
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              _visualizacaoTabela = _modoVisualizacao == 'tabela';
                            });
                            if (widget.onModoChange != null) {
                              widget.onModoChange!(_modoVisualizacao);
                            }
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
                    _loadNotas();
                    _loadTodasNotasParaEstatisticas();
                  },
                  icon: const Icon(Icons.refresh),
                  label: isCompact ? const SizedBox.shrink() : const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(isCompact ? 44 : 0, 36),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: 12,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Filtros'),
                            if (_totalFiltrosAtivos() > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_totalFiltrosAtivos()}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(isCompact ? 44 : 0, 36),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    final willExpand = !_filtrosExpandidos;
                    setState(() {
                      _filtrosExpandidos = willExpand;
                    });
                    if (willExpand && _opcoesFiltrosEstaoVazias()) {
                      _loadFiltros();
                    }
                  },
                ),
                if (!isCompact)
                  Text(
                    _filtrosExpandidos ? 'Ocultar' : 'Mostrar',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Filtros (versão revertida; pode gerar overflow no mobile)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
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
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
              SizedBox(
                width: isMobile ? double.infinity : 220,
                child: _buildMultiSelectFilterField(
                        'Local',
                        _filtroLocais,
                        _locaisDisponiveis,
                        (values) {
                          setState(() {
                            _filtroLocais = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar local...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 180,
                child: _buildMultiSelectFilterField(
                  'Sala',
                  _filtroSalas,
                  _salasDisponiveis,
                  (values) {
                    setState(() {
                      _filtroSalas = values;
                      _paginaAtual = 0;
                    });
                    _loadNotas();
                    _loadTodasNotasParaEstatisticas();
                  },
                  searchHint: 'Pesquisar sala...',
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 180,
                child: _buildMultiSelectFilterField(
                        'Tipo',
                        _filtroTipos,
                        _tiposDisponiveis,
                        (values) {
                          setState(() {
                            _filtroTipos = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar tipo...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 180,
                child: _buildMultiSelectFilterField(
                        'Nota',
                        _filtroNotas,
                        _notasDisponiveis,
                        (values) {
                          setState(() {
                            _filtroNotas = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar nota...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 180,
                child: _buildMultiSelectFilterField(
                        'Prioridade',
                        _filtroPrioridades,
                        _prioridadesDisponiveis,
                        (values) {
                          setState(() {
                            _filtroPrioridades = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar prioridade...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 180,
                child: _buildMultiSelectFilterField(
                        'Status Usuário',
                        _filtroStatusUsuario,
                        _statusUsuarioDisponiveis,
                        (values) {
                          setState(() {
                            _filtroStatusUsuario = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar status usuário...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 220,
                child: _buildMultiSelectFilterField(
                        'Responsável',
                        _filtroResponsaveis,
                        _responsaveisDisponiveis,
                        (values) {
                          setState(() {
                            _filtroResponsaveis = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar responsável...',
                      ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 150,
                child: _buildMultiSelectFilterField(
                        'GPM',
                        _filtroGPMs,
                        _gpmsDisponiveis,
                        (values) {
                          setState(() {
                            _filtroGPMs = values;
                            _paginaAtual = 0;
                          });
                          _loadNotas();
                          _loadTodasNotasParaEstatisticas();
                        },
                        searchHint: 'Pesquisar GPM...',
                      ),
              ),
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: _buildMultiSelectFilterField(
                    'Status (Tarefa)',
                    _filtroStatusTarefa,
                  _statusTarefaDisponiveis,
                    (values) {
                      setState(() {
                        _filtroStatusTarefa = values;
                      _paginaAtual = 0;
                      });
                    _loadNotas();
                    _loadTodasNotasParaEstatisticas();
                    },
                  searchHint: 'Pesquisar status da tarefa...',
                  ),
                ),
              OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtroLocais.clear();
                        _filtroSalas.clear();
                        _filtroTipos.clear();
                        _filtroNotas.clear();
                        _filtroPrioridades.clear();
                        _filtroStatusUsuario.clear();
                        _filtroResponsaveis.clear();
                        _filtroGPMs.clear();
                    _filtroStatusTarefa.clear();
                        _paginaAtual = 0;
                      });
                      _loadNotas();
                      _loadTodasNotasParaEstatisticas();
                    },
                    icon: const Icon(Icons.clear),
                label: const Text('Limpar filtros'),
                  ),
              ],
            ),
        ),
        crossFadeState: _filtrosExpandidos ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 200),
          ),

          // Contador de resultados (não mostrar no dashboard; ocultar no mobile)
          if (_modoVisualizacao != 'dashboard' && !Responsive.isMobile(context))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Row(
                      children: [
                        Text(
                          'Total: $_totalNotas notas (${_notas.length} nesta página)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (_notasSelecionadas.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Text(
                                  '${_notasSelecionadas.length} selecionada${_notasSelecionadas.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _notasSelecionadas.clear();
                                    });
                                  },
                                  child: Icon(Icons.close, size: 16, color: Colors.blue[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  const Spacer(),
                  Text(
                    'Página ${_paginaAtual + 1} de ${(_totalNotas / _itensPorPagina).ceil()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

          // Lista de notas (Cards ou Tabela)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma nota encontrada',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalNotas == 0
                                  ? 'Não há notas cadastradas ou você não tem permissão para visualizá-las.'
                                  : 'Total de notas: $_totalNotas',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            if (_filtroTipoNota != null ||
                                _filtroLocais.isNotEmpty || _filtroTipos.isNotEmpty || _filtroNotas.isNotEmpty || _filtroPrioridades.isNotEmpty ||
                                _filtroStatusUsuario.isNotEmpty || _filtroResponsaveis.isNotEmpty || _filtroGPMs.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filtroTipoNota = null;
                                    _filtroProgramacao = null;
                                    _filtroLocais.clear();
                                    _filtroTipos.clear();
                                    _filtroNotas.clear();
                                    _filtroPrioridades.clear();
                                    _filtroStatusUsuario.clear();
                                    _filtroResponsaveis.clear();
                                    _filtroGPMs.clear();
                                    _paginaAtual = 0;
                                  });
                                  _loadNotas();
                                  _loadTodasNotasParaEstatisticas();
                                  // _loadFiltros() será chamado automaticamente no final de _loadNotas()
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Limpar Filtros'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _modoVisualizacao == 'calendario'
                        ? NotasSAPCalendarView(
                            notas: _todasNotasOrdenadas,
                            onNotaTap: (nota) => _mostrarDetalhesNota(nota),
                          )
                        : _modoVisualizacao == 'dashboard'
                            ? NotasSAPDashboardView(
                                key: ValueKey('dashboard_${_todasNotasOrdenadas.length}_${_filtroTipoNota}_${_filtroLocais.length}_${_filtroTipos.length}_${_filtroNotas.length}_${_filtroPrioridades.length}_${_filtroStatusUsuario.length}_${_filtroResponsaveis.length}_${_filtroGPMs.length}_$_searchQuery'),
                                notas: _todasNotasOrdenadas,
                              )
                            : _visualizacaoTabela
                                ? _buildTabelaView()
                                : ListView.builder(
                                itemCount: _notas.length,
                                itemBuilder: (context, index) {
                                  final nota = _notas[index];
                                  final isProgramada = _notasProgramadasIds.contains(nota.id);
                                  return _buildNotaCard(nota, isProgramada: isProgramada);
                                },
                              ),
          ),

          // Paginação (não mostrar no dashboard)
          if (_modoVisualizacao != 'dashboard' && _totalNotas > _itensPorPagina)
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
                            // Se já temos notas carregadas, apenas aplicar paginação
                            if (_todasNotasOrdenadas.isNotEmpty) {
                              _aplicarOrdenacaoEPaginacao();
                            } else {
                              _loadNotas();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalNotas / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalNotas
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            // Se já temos notas carregadas, apenas aplicar paginação
                            if (_todasNotasOrdenadas.isNotEmpty) {
                              _aplicarOrdenacaoEPaginacao();
                            } else {
                              _loadNotas();
                            }
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

  Widget _buildNotaCard(NotaSAP nota, {bool isProgramada = false}) {
    final programadasList = isProgramada ? _notasProgramadasInfo[nota.id] : null;
    // Pegar a vinculação mais recente para exibir no card (primeira da lista ordenada)
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
              backgroundColor: _getStatusColor(nota.statusSistema),
              child: Text(
                nota.tipo ?? '?',
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
                'Nota: ${nota.nota}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarNota(nota.nota),
              tooltip: 'Copiar nota',
            ),
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
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nota.descricao != null)
              Text(
                nota.descricao!,
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
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor ?? Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tarefaStatus ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tarefa: ${tarefa['tarefa'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor ?? Colors.blue[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: statusColor ?? Colors.blue[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (nota.criadoEm != null)
                  Text(
                    'Criado: ${_formatDate(nota.criadoEm!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (nota.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(nota.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      nota.statusSistema!,
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
                _buildInfoRow('Tipo', nota.tipo),
                _buildInfoRow('Prioridade', nota.textPrioridade),
                _buildInfoRow('Ordem', nota.ordem),
                _buildInfoRow('Local', nota.localInstalacao),
                _buildInfoRow('Sala', nota.sala),
                _buildInfoRow('Equipamento', nota.equipamento),
                _buildInfoRow('Status Usuário', nota.statusUsuario),
                _buildInfoRow('Centro', nota.centro),
                _buildInfoRow('Executor', nota.denominacaoExecutor),
                if (nota.inicioDesejado != null)
                  _buildInfoRow('Início Desejado', _formatDate(nota.inicioDesejado!)),
                if (nota.conclusaoDesejada != null)
                  _buildInfoRow('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
                if (nota.dataReferencia != null)
                  _buildInfoRow('Data Referência', _formatDate(nota.dataReferencia!)),
                
                // Informações das tarefas vinculadas (se programada)
                if (isProgramada && programadasList != null && programadasList.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Tarefas Vinculadas (${programadasList.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  // Mostrar todas as vinculações
                  ...programadasList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final vinculacao = entry.value;
                    final tarefaVinculada = vinculacao['tarefa'] as Map<String, dynamic>?;
                    final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
                    final statusTarefa = tarefaVinculada?['status'] as String?;
                    final statusColorTarefa = statusTarefa != null ? _getTaskStatusColor(statusTarefa) : null;
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: index < programadasList.length - 1 ? 16 : 0),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColorTarefa ?? Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusTarefa ?? 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _navegarParaTarefa(tarefaVinculada?['id'] as String?),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColorTarefa ?? Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.open_in_new, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Tarefa', tarefaVinculada?['tarefa']?.toString()),
                          _buildInfoRow('Regional', tarefaVinculada?['regional']?.toString()),
                          _buildInfoRow('Divisão', tarefaVinculada?['divisao']?.toString()),
                          _buildInfoRow('Local', tarefaVinculada?['local']?.toString()),
                          _buildInfoRow('Tipo', tarefaVinculada?['tipo']?.toString()),
                          _buildInfoRow('Ordem', tarefaVinculada?['ordem']?.toString()),
                          if (tarefaVinculada?['data_inicio'] != null && tarefaVinculada?['data_fim'] != null)
                            _buildInfoRow(
                              'Período',
                              '${_formatDate(tarefaVinculada!['data_inicio'] is String ? DateTime.parse(tarefaVinculada['data_inicio']) : tarefaVinculada['data_inicio'] as DateTime)} - ${_formatDate(tarefaVinculada['data_fim'] is String ? DateTime.parse(tarefaVinculada['data_fim']) : tarefaVinculada['data_fim'] as DateTime)}',
                            ),
                          if (vinculadoEm != null)
                            _buildInfoRow(
                              'Vinculado em',
                              '${_formatDate(vinculadoEm)} ${vinculadoEm.hour.toString().padLeft(2, '0')}:${vinculadoEm.minute.toString().padLeft(2, '0')}',
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                
                const SizedBox(height: 16),
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                  ElevatedButton.icon(
                    onPressed: _canEditTasks ? () => _criarTarefaDaNota(nota) : null,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _notasVinculando.contains(nota.id) 
                          ? null 
                          : () => _vincularNotasSelecionadas(nota),
                      icon: _notasVinculando.contains(nota.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link, size: 18),
                      label: const Text('Vincular a Tarefa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
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
            child: Text(
              value,
              maxLines: label == 'Detalhes' ? null : 3,
              overflow: label == 'Detalhes' ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Toggle switch com 3 ícones (vegetação, trator, manutenção)
  // Só aparece se o usuário tiver o segmento "Linhas de Transmissão"
  Widget _buildTipoToggle() {
    // Só mostrar se o usuário tiver o segmento "Linhas de Transmissão"
    if (!_temSegmentoLinhasTransmissao) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTipoToggleButton(
            icon: Icons.eco, // Vegetação
            value: 'vegetacao',
            tooltip: 'Vegetação (PD)',
            contador: _contadorVegetacao,
          ),
          _buildTipoToggleButton(
            icon: Icons.agriculture, // Trator
            value: 'trator',
            tooltip: 'Trator (TR)',
            contador: _contadorTrator,
          ),
          _buildTipoToggleButton(
            icon: Icons.build, // Manutenção
            value: 'manutencao',
            tooltip: 'Manutenção (MT)',
            contador: _contadorManutencao,
          ),
        ],
      ),
    );
  }

  Widget _buildTipoToggleButton({
    required IconData icon,
    required String value,
    required String tooltip,
    required int contador,
  }) {
    final isSelected = _tipoFiltro == value;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            // Se clicar no mesmo, deseleciona (mostra todos)
            _tipoFiltro = _tipoFiltro == value ? null : value;
          });
          // Recarregar notas com o novo filtro
          _loadNotas();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[600] : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              // Badge abaixo do ícone
              if (contador > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 16,
                  ),
                  child: Text(
                    contador > 99 ? '99+' : contador.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                const SizedBox(height: 20), // Espaço para manter alinhamento
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewButton(String label, IconData icon, String value, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _modoVisualizacao = value;
          _visualizacaoTabela = value == 'tabela';
        });
        widget.onModoChange?.call(value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Footbar de visualização para mobile
  Widget _buildMobileViewSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // mobile view switcher removido (footbar global cuida no mobile)
        ],
      ),
    );
  }

  // _buildMobileViewButton removido



  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('MSPR')) return Colors.orange;
    if (status.contains('MSPN')) return Colors.blue;
    return Colors.grey;
  }

  Color _getStatusUsuarioColor(String? statusUsuario) {
    if (statusUsuario == null) return Colors.grey;
    final status = statusUsuario.toUpperCase();
    if (status.contains('REGI')) return Colors.red;
    if (status.contains('EMAN')) return Colors.orange;
    if (status.contains('ANLS')) return Colors.yellow[700] ?? Colors.amber;
    if (status.contains('CONC')) return Colors.green;
    if (status.contains('CANC')) return Colors.black;
    return Colors.grey;
  }

  Color _getLocalColor(String? local) {
    if (local == null || local.isEmpty) return Colors.grey[300]!;
    
    // Usar hash do local para gerar cores consistentes
    final hash = local.hashCode;
    final colors = [
      Colors.blue[200]!,
      Colors.green[200]!,
      Colors.orange[200]!,
      Colors.purple[200]!,
      Colors.teal[200]!,
      Colors.pink[200]!,
      Colors.indigo[200]!,
      Colors.cyan[200]!,
      Colors.amber[200]!,
      Colors.lime[200]!,
    ];
    return colors[hash.abs() % colors.length];
  }

  Color _getLocalTextColor(Color backgroundColor) {
    // Retornar cor de texto com bom contraste baseada na cor de fundo
    final brightness = backgroundColor.computeLuminance();
    return brightness > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildMultiSelectFilterField(
    String label,
    Set<String> selectedValues,
    List<String> options,
    Function(Set<String>) onChanged, {
    String? searchHint,
  }) {
    // Função para calcular valores disponíveis dinamicamente a partir de _todasNotasOrdenadas
    List<String> calcularOpcoesDisponiveis(String campo) {
      if (_todasNotasOrdenadas.isEmpty) {
        return options; // Fallback para valores iniciais
      }
      
      final valoresSet = <String>{};
      for (var nota in _todasNotasOrdenadas) {
        String? valor;
        switch (campo) {
          case 'Local':
            valor = nota.local;
            break;
          case 'Tipo':
            valor = nota.tipo;
            break;
          case 'Nota':
            valor = nota.nota;
            break;
          case 'Prioridade':
            valor = nota.textPrioridade;
            break;
          case 'Status Usuário':
            valor = nota.statusUsuario;
            break;
          case 'Responsável':
            valor = nota.denominacaoExecutor;
            break;
          case 'GPM':
            valor = nota.gpm;
            break;
        }
        if (valor != null && valor.isNotEmpty) {
          valoresSet.add(valor);
        }
      }
      return valoresSet.toList()..sort();
    }
    
    return InkWell(
      onTap: () async {
        // Calcular opções disponíveis dinamicamente no momento de abrir o diálogo
        var opcoesAtualizadas = calcularOpcoesDisponiveis(label);
        // No mobile, se opções vazias e notas ainda não carregadas, forçar carregamento dos filtros
        if (opcoesAtualizadas.isEmpty && _todasNotasOrdenadas.isEmpty) {
          await _loadFiltros();
          if (!mounted) return;
          opcoesAtualizadas = _getOpcoesParaFiltro(label);
        }
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => MultiSelectFilterDialog(
            title: label,
            options: opcoesAtualizadas,
            selectedValues: selectedValues,
            onSelectionChanged: (newValues) {
              onChanged(newValues);
              setState(() {
                _paginaAtual = 0;
              });
              _loadNotas();
              _loadTodasNotasParaEstatisticas();
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _navegarParaTarefa(String? taskId) async {
    if (taskId == null) return;
    
    try {
      final taskService = TaskService();
      final task = await taskService.getTaskById(taskId);
      
      if (task != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => TaskViewDialog(task: task),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarefa não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
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

  void _mostrarTodasVinculacoes(NotaSAP nota, List<Map<String, dynamic>> vinculacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.task, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tarefas Vinculadas à Nota ${nota.nota}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: vinculacoes.asMap().entries.map((entry) {
                final index = entry.key;
                final vinculacao = entry.value;
                final tarefa = vinculacao['tarefa'] as Map<String, dynamic>?;
                final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
                final statusTarefa = tarefa?['status'] as String?;
                final statusColorTarefa = statusTarefa != null ? _getTaskStatusColor(statusTarefa) : null;
                
                return Container(
                  margin: EdgeInsets.only(bottom: index < vinculacoes.length - 1 ? 16 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColorTarefa?.withOpacity(0.1) ?? Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColorTarefa ?? Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColorTarefa ?? Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusTarefa ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context); // Fechar este diálogo
                              _navegarParaTarefa(tarefa?['id'] as String?);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColorTarefa ?? Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_in_new, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ver Tarefa',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Tarefa', tarefa?['tarefa']?.toString()),
                      _buildInfoRow('Regional', tarefa?['regional']?.toString()),
                      _buildInfoRow('Divisão', tarefa?['divisao']?.toString()),
                      _buildInfoRow('Local', tarefa?['local']?.toString()),
                      _buildInfoRow('Tipo', tarefa?['tipo']?.toString()),
                      _buildInfoRow('Ordem', tarefa?['ordem']?.toString()),
                      if (tarefa?['data_inicio'] != null && tarefa?['data_fim'] != null)
                        _buildInfoRow(
                          'Período',
                          '${_formatDate(tarefa!['data_inicio'] is String ? DateTime.parse(tarefa['data_inicio']) : tarefa['data_inicio'] as DateTime)} - ${_formatDate(tarefa['data_fim'] is String ? DateTime.parse(tarefa['data_fim']) : tarefa['data_fim'] as DateTime)}',
                        ),
                      if (vinculadoEm != null)
                        _buildInfoRow(
                          'Vinculado em',
                          '${_formatDate(vinculadoEm)} ${vinculadoEm.hour.toString().padLeft(2, '0')}:${vinculadoEm.minute.toString().padLeft(2, '0')}',
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
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

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: [
            DataColumn(
              label: Checkbox(
                value: _notasSelecionadas.length == _notas.length && _notas.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _notasSelecionadas = _notas.map((n) => n.id).toSet();
                    } else {
                      _notasSelecionadas.clear();
                    }
                  });
                },
              ),
            ),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tarefa Vinculada', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Sala', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: Text('Prazo', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _ordenacaoAscendente = ascending;
                  _paginaAtual = 0; // Resetar para primeira página ao ordenar
                });
                // Reordenar todas as notas e aplicar paginação
                _aplicarOrdenacaoEPaginacao();
              },
            ),
            DataColumn(label: Text('Nota', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Criado em', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Prioridade', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Responsável', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local da Instalação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Centro Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status do Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Detalhes', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _notas.map((nota) {
            final isProgramada = _notasProgramadasIds.contains(nota.id);
            final programadasList = isProgramada ? _notasProgramadasInfo[nota.id] : null;
            // Pegar a vinculação mais recente para exibir na tabela (primeira da lista ordenada)
            final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
            final totalVinculacoes = programadasList?.length ?? 0;
            
            final isSelected = _notasSelecionadas.contains(nota.id);
            return DataRow(
              selected: isSelected,
              color: isProgramada && statusColor != null
                  ? WidgetStateProperty.all(statusColor.withOpacity(0.1))
                  : null,
              cells: [
                // 0. CHECKBOX DE SELEÇÃO
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _notasSelecionadas.add(nota.id);
                        } else {
                          _notasSelecionadas.remove(nota.id);
                        }
                      });
                    },
                  ),
                ),
                // 1. AÇÕES
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Visualizar',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _mostrarDetalhesNota(nota),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple[300]!),
                              ),
                              child: const Icon(Icons.visibility, size: 20, color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Criar Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _canEditTasks ? () => _criarTarefaDaNota(nota) : null,
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
                            onTap: _notasVinculando.contains(nota.id)
                                ? null
                                : () => _vincularNotasSelecionadas(nota),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _notasVinculando.contains(nota.id)
                                    ? Colors.grey[200]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _notasVinculando.contains(nota.id)
                                      ? Colors.grey[300]!
                                      : Colors.blue[300]!,
                                ),
                              ),
                              child: _notasVinculando.contains(nota.id)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.link, size: 20, color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. STATUS
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
                // 3. TAREFA VINCULADA
                DataCell(
                  isProgramada && tarefa != null
                      ? InkWell(
                          onTap: totalVinculacoes > 1
                              ? () => _mostrarTodasVinculacoes(nota, programadasList!)
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
                                const SizedBox(width: 4),
                                Icon(
                                  totalVinculacoes > 1 ? Icons.list : Icons.open_in_new,
                                  size: 14,
                                  color: totalVinculacoes > 1 ? Colors.orange : Colors.blue[700],
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text('-', style: TextStyle(color: Colors.grey)),
                ),
                // 4. LOCAL
                DataCell(
                  Builder(
                    builder: (context) {
                      final localColor = _getLocalColor(nota.local);
                      final textColor = _getLocalTextColor(localColor);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: localColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: nota.local != null && nota.local!.isNotEmpty 
                                ? localColor.withOpacity(0.8)
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          nota.local ?? '-',
                          style: TextStyle(
                            fontWeight: nota.local != null && nota.local!.isNotEmpty 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 5. SALA
                DataCell(
                  SizedBox(
                    width: 89, // redução adicional ~10%
                    child: Text(
                      (nota.sala ?? '-').trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 6. DESCRIÇÃO
                DataCell(
                  SizedBox(
                    width: 243, // redução adicional ~10%
                    child: Text(
                      nota.descricao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 7. TIPO
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(nota.tipo ?? '-'),
                  ),
                ),
                // 8. PRAZO
                DataCell(
                  _buildPrazoBadge(nota),
                ),
                // 9. NOTA
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nota.nota,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copiarNota(nota.nota),
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                  onTap: () => _mostrarDetalhesNota(nota),
                ),
                // 10. CRIADO EM
                DataCell(
                  Text(nota.criadoEm != null ? _formatDate(nota.criadoEm!) : '-'),
                ),
                // 11. PRIORIDADE
                DataCell(Text(nota.textPrioridade ?? '-')),
                // 12. STATUS USUÁRIO
                DataCell(
                  Builder(
                    builder: (context) {
                      final statusColor = _getStatusUsuarioColor(nota.statusUsuario);
                      final textColor = statusColor == Colors.black 
                          ? Colors.white 
                          : statusColor == (Colors.yellow[700] ?? Colors.amber)
                              ? Colors.black
                              : Colors.white;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nota.statusUsuario ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 13. RESPONSÁVEL
                DataCell(
                  SizedBox(
                    width: 162, // redução adicional ~10%
                    child: Text(
                      nota.denominacaoExecutor ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 14. LOCAL DA INSTALAÇÃO
                DataCell(
                  SizedBox(
                    width: 162, // redução adicional ~10%
                    child: Text(
                      nota.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 15. ORDEM
                DataCell(
                  Text(nota.ordem ?? '-'),
                ),
                // 16. CENTRO TRABALHO
                DataCell(
                  SizedBox(
                    width: 122, // redução adicional ~10%
                    child: Text(
                      (nota.centroTrabalhoResponsavel ?? '-').trim(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 17. GPM
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.2), // redução adicional ~10%
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      nota.gpm ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                // 18. STATUS DO SISTEMA
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(nota.statusSistema).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getStatusColor(nota.statusSistema),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      nota.statusSistema ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(nota.statusSistema),
                      ),
                    ),
                  ),
                ),
                // 19. DETALHES
                DataCell(
                  SizedBox(
                    width: 162, // redução adicional ~10%
                    child: Text(
                      nota.detalhes ?? '-',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // Construir badge de prazo
  Widget _buildPrazoBadge(NotaSAP nota) {
    if (nota.dataVencimento == null || nota.diasRestantes == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final diasRestantes = nota.diasRestantes!;
    final dataVencimento = nota.dataVencimento!;
    
    // Determinar cor baseado nos dias restantes
    Color badgeColor;
    Color textColor;
    
    if (diasRestantes <= 0) {
      // Preto: já passou da data ou vence hoje
      badgeColor = Colors.black;
      textColor = Colors.white;
    } else if (diasRestantes <= 30) {
      // Vermelho: vence em até 30 dias
      badgeColor = Colors.red;
      textColor = Colors.white;
    } else if (diasRestantes <= 90) {
      // Amarelo: vence em até 90 dias
      badgeColor = Colors.yellow[700] ?? Colors.amber;
      textColor = Colors.black;
    } else {
      // Azul: mais de 90 dias
      badgeColor = Colors.blue;
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            _formatDate(dataVencimento),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasRestantes < 0
                  ? '$diasRestantes dias' // Mostrar valor negativo quando vencido
                  : diasRestantes == 0
                      ? 'Vence hoje'
                      : diasRestantes == 1
                          ? '1 dia'
                          : '$diasRestantes dias',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalhesNota(NotaSAP nota) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da Nota SAP: ${nota.nota}'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarNota(nota.nota),
              tooltip: 'Copiar nota',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Tipo', nota.tipo),
              _buildInfoRow('Descrição', nota.descricao),
              _buildInfoRow('Detalhes', nota.detalhes),
              _buildInfoRow('Status Sistema', nota.statusSistema),
              _buildInfoRow('Status Usuário', nota.statusUsuario),
              _buildInfoRow('Prioridade', nota.textPrioridade),
              _buildInfoRow('Ordem', nota.ordem),
              _buildInfoRow('Local de Instalação', nota.localInstalacao),
              _buildInfoRow('Local', nota.local),
              _buildInfoRow('Sala', nota.sala),
              _buildInfoRow('Equipamento', nota.equipamento),
              _buildInfoRow('Centro', nota.centro),
              _buildInfoRow('Centro Trabalho Responsável', nota.centroTrabalhoResponsavel),
              _buildInfoRow('Executor', nota.denominacaoExecutor),
              _buildInfoRow('GPM', nota.gpm),
              if (nota.criadoEm != null)
                _buildInfoRow('Criado em', _formatDate(nota.criadoEm!)),
              if (nota.inicioDesejado != null)
                _buildInfoRow('Início Desejado', _formatDate(nota.inicioDesejado!)),
              if (nota.conclusaoDesejada != null)
                _buildInfoRow('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
              if (nota.dataReferencia != null)
                _buildInfoRow('Data Referência', _formatDate(nota.dataReferencia!)),
              if (nota.inicioAvaria != null)
                _buildInfoRow('Início Avaria', _formatDate(nota.inicioAvaria!)),
              if (nota.fimAvaria != null)
                _buildInfoRow('Fim Avaria', _formatDate(nota.fimAvaria!)),
              if (nota.encerramento != null)
                _buildInfoRow('Encerramento', _formatDate(nota.encerramento!)),
              if (nota.modificadoEm != null)
                _buildInfoRow('Modificado em', _formatDate(nota.modificadoEm!)),
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

  // Criar tarefa a partir de uma nota SAP (ou múltiplas notas selecionadas)
  Future<void> _criarTarefaDaNota(NotaSAP nota) async {
    try {
      if (!await _ensureCanEditTasks()) return;
      
      // Verificar se há notas selecionadas
      final notasParaVincular = _notasSelecionadas.isNotEmpty 
          ? _notas.where((n) => _notasSelecionadas.contains(n.id)).toList()
          : [nota];
      
      // Se há múltiplas notas selecionadas, usar a primeira para pré-preencher o formulário
      final notaPrincipal = notasParaVincular.first;
      
      // Calcular datas padrão baseado na primeira nota
      final dataInicio = notaPrincipal.inicioDesejado ?? DateTime.now();
      final dataFim = notaPrincipal.conclusaoDesejada ?? dataInicio.add(const Duration(days: 1));
      
      // Mostrar formulário de criação de tarefa pré-preenchido com dados da nota principal
      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          startDate: dataInicio,
          endDate: dataFim,
          notaSAP: notaPrincipal, // Passar a nota SAP principal para pré-preencher o formulário
        ),
      );
      
      if (taskCriada != null) {
        // Mostrar diálogo de progresso se houver múltiplas notas
        final progressDialogContext = context;
        StateSetter? setDialogState;
        int notasProcessadas = 0;
        String statusAtual = 'Criando tarefa...';
        
        if (notasParaVincular.length > 1) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return StatefulBuilder(
                builder: (context, setState) {
                  setDialogState = setState;
                  return AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          'Criando tarefa e vinculando ${notasParaVincular.length} notas...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tarefa: ${taskCriada.tarefa}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: notasParaVincular.isNotEmpty 
                              ? notasProcessadas / (notasParaVincular.length + 1) // +1 para a criação da tarefa
                              : 0.0,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          statusAtual,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        }
        
        // A tarefa retornada ainda não tem ID real (é um ID temporário)
        // Precisamos criar a tarefa primeiro e depois vincular
        final taskService = TaskService();
        try {
          // Atualizar progresso: criando tarefa
          if (notasParaVincular.length > 1 && setDialogState != null) {
            statusAtual = 'Criando tarefa...';
            setDialogState!(() {});
          }
          
          final createdTask = await taskService.createTask(taskCriada);
          notasProcessadas++;
          
          // Atualizar progresso: tarefa criada, iniciando vinculação
          if (notasParaVincular.length > 1 && setDialogState != null) {
            statusAtual = 'Vinculando notas...';
            setDialogState!(() {});
          }
          
          // Vincular todas as notas selecionadas (ou apenas a nota clicada)
          int vinculadasComSucesso = 0;
          int vinculadasComErro = 0;
          
          for (final notaParaVincular in notasParaVincular) {
            try {
              await _service.vincularNotaATarefa(createdTask.id, notaParaVincular.id);
              vinculadasComSucesso++;
              notasProcessadas++;
              
              // Atualizar progresso no diálogo
              if (notasParaVincular.length > 1 && setDialogState != null) {
                statusAtual = 'Vinculando notas... ($notasProcessadas/${notasParaVincular.length + 1})';
                setDialogState!(() {});
              }
            } catch (e) {
              print('❌ Erro ao vincular nota ${notaParaVincular.nota}: $e');
              vinculadasComErro++;
              notasProcessadas++;
              
              // Atualizar progresso mesmo em caso de erro
              if (notasParaVincular.length > 1 && setDialogState != null) {
                statusAtual = 'Vinculando notas... ($notasProcessadas/${notasParaVincular.length + 1})';
                setDialogState!(() {});
              }
            }
          }
          
          // Fechar diálogo de progresso se foi aberto
          if (notasParaVincular.length > 1 && mounted) {
            Navigator.of(progressDialogContext, rootNavigator: true).pop();
          }
          
          // Recarregar notas programadas para atualizar a visualização
          await _loadNotasProgramadas();
          
          // Limpar seleção
          if (mounted) {
            setState(() {
              _notasSelecionadas.clear();
            });
          }
          
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            if (vinculadasComErro == 0) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    vinculadasComSucesso == 1
                        ? 'Tarefa criada e vinculada à nota ${notaPrincipal.nota} com sucesso!'
                        : 'Tarefa criada e $vinculadasComSucesso notas vinculadas com sucesso!',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Tarefa criada. $vinculadasComSucesso nota(s) vinculada(s) com sucesso. $vinculadasComErro erro(s).',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          // Fechar diálogo de progresso se foi aberto
          if (notasParaVincular.length > 1 && mounted) {
            Navigator.of(progressDialogContext, rootNavigator: true).pop();
          }
          
          print('⚠️ Erro ao criar/vincular tarefa: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao criar tarefa ou vincular nota: $e'),
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

  // Vincular notas selecionadas (ou apenas a nota clicada se nenhuma estiver selecionada)
  Future<void> _vincularNotasSelecionadas(NotaSAP nota) async {
    // Se há notas selecionadas, vincular todas elas
    if (_notasSelecionadas.isNotEmpty) {
      await _vincularMultiplasNotas(_notasSelecionadas.toList());
    } else {
      // Se não há seleção, vincular apenas a nota clicada
      await _vincularNotaATarefaExistente(nota);
    }
  }

  // Vincular múltiplas notas a uma tarefa
  Future<void> _vincularMultiplasNotas(List<String> notaIds) async {
    if (!mounted || notaIds.isEmpty) {
      return;
    }

    // Verificar se alguma nota já está sendo vinculada
    final notasEmProcessamento = notaIds.where((id) => _notasVinculando.contains(id)).toList();
    if (notasEmProcessamento.isNotEmpty) {
      return;
    }

    // Marcar todas como processando
    setState(() {
      for (final id in notaIds) {
        _notasVinculando.add(id);
      }
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Buscar as notas selecionadas
      final notasSelecionadas = _notas.where((n) => notaIds.contains(n.id)).toList();
      if (notasSelecionadas.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Nenhuma nota selecionada encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Usar o local da primeira nota para filtrar tarefas (ou todas se não houver local)
      final localComum = notasSelecionadas.first.local;
      
      // Buscar tarefas disponíveis
      final taskService = TaskService();
      final todasTarefas = await taskService.getAllTasks();

      if (todasTarefas.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Não há tarefas disponíveis para vincular'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Filtrar tarefas já vinculadas a qualquer uma das notas selecionadas
      final tarefasVinculadasSet = <String>{};
      for (final nota in notasSelecionadas) {
        final tarefasVinculadas = await _service.getTarefasPorNota(nota.id);
        tarefasVinculadasSet.addAll(tarefasVinculadas);
      }

      var tarefasDisponiveis = todasTarefas
          .where((t) => !tarefasVinculadasSet.contains(t.id))
          .toList();

      // Filtrar tarefas do mesmo local (se houver local comum)
      if (localComum != null && localComum.isNotEmpty) {
        tarefasDisponiveis = tarefasDisponiveis
            .where((t) => t.locais.contains(localComum))
            .toList();
      }

      if (tarefasDisponiveis.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                localComum != null && localComum.isNotEmpty
                    ? 'Não há tarefas disponíveis do mesmo local ($localComum) para vincular'
                    : 'Todas as tarefas já estão vinculadas às notas selecionadas',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Remover do conjunto de processamento antes de abrir o diálogo
      if (mounted) {
        setState(() {
          for (final id in notaIds) {
            _notasVinculando.remove(id);
          }
        });
      }

      if (!mounted) {
        return;
      }

      // Mostrar diálogo de seleção de tarefa
      final tarefaSelecionada = await showDialog<Task>(
        context: context,
        barrierDismissible: true,
        builder: (context) => TaskSelectionDialog(
          tasks: tarefasDisponiveis,
          title: 'Vincular ${notaIds.length} Nota${notaIds.length > 1 ? 's' : ''} a Tarefa',
          notaSapNumero: notasSelecionadas.length == 1 ? notasSelecionadas.first.nota : null,
        ),
      );

      if (tarefaSelecionada != null && mounted) {
        // Mostrar diálogo de progresso com StatefulBuilder para atualização dinâmica
        int notasProcessadas = 0;
        final progressDialogContext = context;
        StateSetter? setDialogState;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setState) {
                setDialogState = setState;
                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Vinculando ${notasSelecionadas.length} nota${notasSelecionadas.length > 1 ? 's' : ''}...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tarefa: ${tarefaSelecionada.tarefa}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: notasSelecionadas.isNotEmpty ? notasProcessadas / notasSelecionadas.length : 0.0,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$notasProcessadas de ${notasSelecionadas.length} vinculada${notasSelecionadas.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

        // Vincular todas as notas selecionadas
        int vinculadasComSucesso = 0;
        int vinculadasComErro = 0;

        for (int i = 0; i < notasSelecionadas.length; i++) {
          final nota = notasSelecionadas[i];
          try {
            await _service.vincularNotaATarefa(tarefaSelecionada.id, nota.id);
            vinculadasComSucesso++;
            notasProcessadas++;
            
            // Atualizar progresso no diálogo
            if (mounted && setDialogState != null) {
              setDialogState!(() {});
            }
          } catch (e) {
            print('❌ Erro ao vincular nota ${nota.nota}: $e');
            vinculadasComErro++;
            notasProcessadas++;
            
            // Atualizar progresso mesmo em caso de erro
            if (mounted && setDialogState != null) {
              setDialogState!(() {});
            }
          }
        }

        // Fechar diálogo de progresso
        if (mounted) {
          Navigator.of(progressDialogContext, rootNavigator: true).pop();
        }

        // Recarregar notas programadas
        await _loadNotasProgramadas();

        // Limpar seleção
        setState(() {
          _notasSelecionadas.clear();
        });

        if (mounted) {
          if (vinculadasComErro == 0) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  vinculadasComSucesso == 1
                      ? 'Nota vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'
                      : '$vinculadasComSucesso notas vinculadas à tarefa "${tarefaSelecionada.tarefa}" com sucesso!',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  '$vinculadasComSucesso nota(s) vinculada(s) com sucesso. $vinculadasComErro erro(s).',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar tarefas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Remover do conjunto de processamento
      if (mounted) {
        setState(() {
          for (final id in notaIds) {
            _notasVinculando.remove(id);
          }
        });
      }
    }
  }

  // Vincular nota a uma tarefa existente
  Future<void> _vincularNotaATarefaExistente(NotaSAP nota) async {
    if (!mounted || _notasVinculando.contains(nota.id)) {
      return;
    }
    
    // CAPTURAR O ID E NÚMERO DA NOTA ANTES DE QUALQUER OPERAÇÃO ASSÍNCRONA
    // Isso garante que mesmo se houver múltiplas chamadas, cada uma usa a nota correta
    final notaIdParaVincular = nota.id;
    final notaNumeroParaVincular = nota.nota;
    final notaLocalParaFiltro = nota.local;
    
    // Marcar como processando
    setState(() {
      _notasVinculando.add(notaIdParaVincular);
    });
    
    // Capturar o contexto antes de operações assíncronas
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Executar operações em paralelo para ser mais rápido
      final taskService = TaskService();
      final results = await Future.wait([
        taskService.getAllTasks(),
        _service.getTarefasPorNota(notaIdParaVincular),
      ]);
      
      final todasTarefas = results[0] as List<Task>;
      final tarefasVinculadas = results[1] as List<String>;
      
      if (todasTarefas.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Não há tarefas disponíveis para vincular'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Filtrar tarefas já vinculadas
      var tarefasDisponiveis = todasTarefas
          .where((t) => !tarefasVinculadas.contains(t.id))
          .toList();
      
      // Filtrar tarefas do mesmo local da nota (se a nota tiver local)
      if (notaLocalParaFiltro != null && notaLocalParaFiltro.isNotEmpty) {
        tarefasDisponiveis = tarefasDisponiveis
            .where((t) => t.locais.contains(notaLocalParaFiltro))
            .toList();
      }
      
      if (tarefasDisponiveis.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                notaLocalParaFiltro != null && notaLocalParaFiltro.isNotEmpty
                    ? 'Não há tarefas disponíveis do mesmo local ($notaLocalParaFiltro) para vincular'
                    : 'Todas as tarefas já estão vinculadas a esta nota',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Remover do conjunto de processamento antes de abrir o diálogo
      if (mounted) {
        setState(() {
          _notasVinculando.remove(notaIdParaVincular);
        });
      }
      
      // Mostrar diálogo imediatamente
      if (!mounted) {
        return;
      }
      
      final tarefaSelecionada = await showDialog<Task>(
        context: context,
        barrierDismissible: true,
        builder: (context) => TaskSelectionDialog(
          tasks: tarefasDisponiveis,
          title: 'Vincular Nota a Tarefa',
          notaSapNumero: notaNumeroParaVincular,
        ),
      );
      
      if (tarefaSelecionada != null && mounted) {
        try {
          // Mostrar diálogo de progresso
          final progressDialogContext = context;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Vinculando nota...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tarefa: ${tarefaSelecionada.tarefa}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nota: $notaNumeroParaVincular',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );

          // IMPORTANTE: Usar APENAS o ID da nota específica que foi clicada
          // Não usar sala, local ou qualquer outro critério - apenas o ID único da nota
          print('🔗 Vinculando nota específica: ID=$notaIdParaVincular, Número=$notaNumeroParaVincular');
          print('🔗 Tarefa selecionada: ID=${tarefaSelecionada.id}, Nome=${tarefaSelecionada.tarefa}');
          
          await _service.vincularNotaATarefa(tarefaSelecionada.id, notaIdParaVincular);
          
          // Fechar diálogo de progresso
          if (mounted) {
            Navigator.of(progressDialogContext, rootNavigator: true).pop();
          }
          
          // Recarregar notas programadas para atualizar a visualização
          await _loadNotasProgramadas();
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Nota $notaNumeroParaVincular vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular nota: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar tarefas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Remover do conjunto de processamento usando o ID capturado
      if (mounted) {
        setState(() {
          _notasVinculando.remove(notaIdParaVincular);
        });
      }
    }
  }

}

