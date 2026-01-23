import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../models/ordem.dart';
import '../services/ordem_service.dart';
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
import 'ordem_calendar_view.dart';

class OrdemView extends StatefulWidget {
  const OrdemView({super.key});

  @override
  State<OrdemView> createState() => _OrdemViewState();
}

class _OrdemViewState extends State<OrdemView> {
  final OrdemService _service = OrdemService();
  final StatusService _statusService = StatusService();
  List<Ordem> _ordens = [];
  List<Ordem> _ordensOriginais = [];
  List<Ordem> _todasOrdens = []; // Todas as ordens para calcular estatísticas
  List<Ordem> _todasOrdensOriginais = [];
  bool _ordenacaoAscendente = true; // Ordenação por prazo (tolerância)
  bool _filtrosExpandidos = false;
  Set<String> _ordensProgramadasIds = {}; // IDs das ordens vinculadas a tarefas
  bool _ordensProgramadasCarregadas = false; // Controle de carregamento (evitar limpar tabela enquanto carrega)
  Map<String, List<Map<String, dynamic>>> _ordensProgramadasInfo = {}; // Lista de vinculações por ordem
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  // Filtros (multi-seleção, padronizados com Notas)
  Set<String> _filtroStatusTarefa = {};
  Set<String> _filtroLocais = {};
  Set<String> _filtroSalas = {};
  Set<String> _filtroTipos = {};
  Set<String> _filtroOrdens = {};
  Set<String> _filtroGPMs = {};
  // Opções disponíveis
  List<String> _statusTarefaDisponiveis = [];
  List<String> _locaisDisponiveisFiltro = [];
  List<String> _salasDisponiveis = [];
  List<String> _tiposDisponiveisFiltro = [];
  List<String> _ordensDisponiveis = [];
  List<String> _gpmsDisponiveis = [];
  // Filtros antigos (mantidos nulos para compatibilidade de chamadas)
  String? _filtroStatus;
  String? _filtroLocal;
  String? _filtroTipo;
  String? _filtroTipoOrdem = 'abertas'; // null = todas, 'abertas' ou 'concluidas'
  String? _filtroProgramacao; // null = todas, 'programadas' ou 'nao_programadas'
  DateTime? _dataInicio;
  DateTime? _dataFim;
  int _totalOrdens = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  // Campos legados (mantidos para compatibilidade com carregamentos antigos)
  // ignore: unused_field
  List<String> _statusDisponiveis = [];
  // ignore: unused_field
  List<String> _locaisDisponiveis = [];
  // ignore: unused_field
  List<String> _tiposDisponiveis = [];
  String _modoVisualizacao = 'cards'; // cards, tabela, calendario
  StreamSubscription<String>? _statusChangeSubscription;
  bool _canEditTasks = false; // Permissão para criar/editar tarefas
  bool _canEditTasksChecked = false; // Indica se a permissão já foi verificada
  bool _isCheckingTaskPermission = false; // Evita múltiplas verificações simultâneas
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ExecutorService _executorService = ExecutorService();

  @override
  void initState() {
    super.initState();
    _loadTaskEditPermission();
    _loadStatus();
    _loadFiltros();
    _loadOrdens();
    _loadTodasOrdensParaEstatisticas();
    _loadOrdensProgramadas();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _modoVisualizacao = 'tabela';
        });
      }
    });
  }

  int _totalFiltrosAtivos() {
    return _filtroStatusTarefa.length +
        _filtroLocais.length +
        _filtroSalas.length +
        _filtroTipos.length +
        _filtroOrdens.length +
        _filtroGPMs.length;
  }

  Widget _buildViewButton(String label, IconData icon, String value, bool selected) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.blue[50] : Colors.white,
        foregroundColor: selected ? Colors.blue : Colors.grey[800],
        side: BorderSide(color: selected ? Colors.blue : Colors.grey[300]!),
      ),
      onPressed: () {
        setState(() {
          _modoVisualizacao = value;
          _paginaAtual = 0;
        });
      },
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _copiarOrdem(String ordemNumero) async {
    try {
      await Clipboard.setData(ClipboardData(text: ordemNumero));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem copiada!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar a ordem: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      if (email == null || email.isEmpty) {
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

  Future<void> _loadOrdensProgramadas() async {
    try {
      setState(() {
        _ordensProgramadasCarregadas = false;
      });

      final programadas = await _service.getOrdensProgramadas();
      final ids = <String>{};
      final info = <String, List<Map<String, dynamic>>>{};
      
      for (final item in programadas) {
        final ordem = item['ordem'] as Ordem;
        ids.add(ordem.id);
        
        // Adicionar à lista de vinculações desta ordem
        if (!info.containsKey(ordem.id)) {
          info[ordem.id] = [];
        }
        info[ordem.id]!.add(item);
      }
      
      // Ordenar cada lista por data de vinculação (mais recente primeiro)
      for (final ordemId in info.keys) {
        info[ordemId]!.sort((a, b) {
          final dataA = a['vinculado_em'] as DateTime?;
          final dataB = b['vinculado_em'] as DateTime?;
          if (dataA == null && dataB == null) return 0;
          if (dataA == null) return 1;
          if (dataB == null) return -1;
          return dataB.compareTo(dataA); // Mais recente primeiro
        });
      }
      
      if (mounted) {
        final precisaReaplicarFiltrosProgOuStatus =
            (_filtroProgramacao != null && _filtroProgramacao!.isNotEmpty) ||
            _filtroStatusTarefa.isNotEmpty;

        setState(() {
          _ordensProgramadasIds = ids;
          _ordensProgramadasInfo = info;
          _ordensProgramadasCarregadas = true;
          if (precisaReaplicarFiltrosProgOuStatus) {
            // Reaplicar filtros apenas quando dependem de programação/status de tarefa
            _todasOrdens = _aplicarFiltrosLocais(_todasOrdensOriginais);
          }
        });
        if (precisaReaplicarFiltrosProgOuStatus) {
          _aplicarOrdenacaoEPaginacao();
        }
        _atualizarOpcoesFiltros();
      }
    } catch (e) {
      print('⚠️ Erro ao carregar ordens programadas: $e');
      if (mounted) {
        setState(() {
          _ordensProgramadasCarregadas = false;
        });
      }
    }
  }

  bool _isOrdemConcluida(Ordem ordem) {
    final status = ordem.statusSistema?.toUpperCase() ?? '';
    // Regra: concluída se contiver ENCE ou ENTE; aberta caso contrário
    return status.contains('ENCE') || status.contains('ENTE');
  }

  void _atualizarOpcoesFiltros() {
    final statusTarefaSet = <String>{};
    for (final lista in _ordensProgramadasInfo.values) {
      for (final vinculo in lista) {
        final tarefa = vinculo['tarefa'] as Map<String, dynamic>?;
        final status = tarefa?['status'] as String?;
        if (status != null && status.isNotEmpty) {
          statusTarefaSet.add(status);
        }
      }
    }

    List<String> _ordenar(Set<String> set) {
      final list = set.toList();
      list.sort();
      return list;
    }

    setState(() {
      _statusTarefaDisponiveis = _ordenar(statusTarefaSet);
      _locaisDisponiveisFiltro = _ordenar(
        _todasOrdensOriginais
            .map((o) => o.local)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _salasDisponiveis = _ordenar(
        _todasOrdensOriginais
            .map((o) => o.sala)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _tiposDisponiveisFiltro = _ordenar(
        _todasOrdensOriginais
            .map((o) => o.tipo)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _ordensDisponiveis = _ordenar(
        _todasOrdensOriginais.map((o) => o.ordem).toSet(),
      );
      _gpmsDisponiveis = _ordenar(
        _todasOrdensOriginais
            .map((o) => o.gpm)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
    });
  }

  List<Ordem> _aplicarFiltrosLocais(List<Ordem> ordens) {
    return ordens.where((ordem) {
      final concluida = _isOrdemConcluida(ordem);
      if (_filtroTipoOrdem == 'abertas' && concluida) return false;
      if (_filtroTipoOrdem == 'concluidas' && !concluida) return false;

      final programada = _ordensProgramadasIds.contains(ordem.id);
    // Se filtros dependem de programadas/status de tarefa e ainda não carregou, não eliminar resultados
    final aguardandoProgramadas = !_ordensProgramadasCarregadas;
    if (_filtroProgramacao == 'programadas') {
      if (!programada && !aguardandoProgramadas) return false;
    }
    if (_filtroProgramacao == 'nao_programadas') {
      if (programada && !aguardandoProgramadas) return false;
    }

      // Filtro por status da tarefa (das tarefas vinculadas)
      if (_filtroStatusTarefa.isNotEmpty) {
        final vinculos = _ordensProgramadasInfo[ordem.id];
        final statusVinculados = vinculos
                ?.map((v) => (v['tarefa'] as Map<String, dynamic>?)?['status'] as String?)
                .whereType<String>()
                .toSet() ??
            {};
      if (_ordensProgramadasCarregadas) {
        if (statusVinculados.isEmpty || !_filtroStatusTarefa.any(statusVinculados.contains)) {
          return false;
        }
      } else {
        // ainda carregando: não filtrar fora
        }
      }

      if (_filtroLocais.isNotEmpty && !_filtroLocais.contains(ordem.local ?? '')) return false;
      if (_filtroSalas.isNotEmpty && !_filtroSalas.contains(ordem.sala ?? '')) return false;
      if (_filtroTipos.isNotEmpty && !_filtroTipos.contains(ordem.tipo ?? '')) return false;
      if (_filtroOrdens.isNotEmpty && !_filtroOrdens.contains(ordem.ordem)) return false;
      if (_filtroGPMs.isNotEmpty && !_filtroGPMs.contains(ordem.gpm ?? '')) return false;

      return true;
    }).toList();
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
              setState(() {
                _paginaAtual = 0;
              });
              _loadOrdens();
              _loadTodasOrdensParaEstatisticas();
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
      _tiposDisponiveis = valores['tipo'] ?? [];
    });
  }

  Future<void> _loadOrdens() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar todas as ordens (sem paginação no backend) e paginar no cliente
      final ordensBrutas = await _service.getAllOrdens(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        filtroTipo: _filtroTipo,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: null,
        offset: null,
      );

      // Evitar duplicação por número de ordem (mantém primeira ocorrência)
      final ordens = _dedupePorNumero(ordensBrutas);

      final filtradas = _aplicarFiltrosLocais(ordens);

      setState(() {
        _ordensOriginais = ordens;
        _todasOrdensOriginais = ordens;
        _todasOrdens = filtradas;
        _isLoading = false;
      });

      _aplicarOrdenacaoEPaginacao();

      _loadOrdensProgramadas();
      _atualizarOpcoesFiltros();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar ordens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Ordem> _dedupePorNumero(List<Ordem> ordens) {
    final seen = <String>{};
    final result = <Ordem>[];
    for (final o in ordens) {
      if (seen.add(o.ordem)) {
        result.add(o);
      }
    }
    return result;
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
          resultado = await _service.importarOrdensDoCSV(csvContent);
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
                    ? 'Importação concluída: ${resultado['importadas']} ordens importadas, ${resultado['duplicatas']} duplicatas ignoradas'
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
            await _loadOrdens();
            await _loadTodasOrdensParaEstatisticas();
            await _loadOrdensProgramadas();
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

  Future<void> _loadTodasOrdensParaEstatisticas() async {
    // Mantido por compatibilidade; _loadOrdens já carrega todas e calcula estatísticas.
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isCompact = isMobile || isTablet;
    final tipoOrdemSegments = isCompact
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
                  'Ordens',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                // Filtros rápidos (mesma regra da tela de Notas)
                SegmentedButton<String?>(
                  segments: tipoOrdemSegments,
                  selected: {_filtroTipoOrdem},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _filtroTipoOrdem = selection.first;
                      _paginaAtual = 0;
                    });
                    _loadOrdens();
                    _loadTodasOrdensParaEstatisticas();
                  },
                  ),
                const SizedBox(width: 12),
                SegmentedButton<String?>(
                  segments: programacaoSegments,
                  selected: {_filtroProgramacao},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _filtroProgramacao = selection.first;
                      _paginaAtual = 0;
                    });
                    _loadOrdens();
                    _loadTodasOrdensParaEstatisticas();
                  },
                  ),
                const SizedBox(width: 16),
            // Botão de filtros na barra
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
                    setState(() {
                  _filtrosExpandidos = !_filtrosExpandidos;
                    });
                  },
            ),
            const SizedBox(width: 12),
            if (!isCompact)
              Text(
                _filtrosExpandidos ? 'Ocultar' : 'Mostrar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(width: 16),
            const Spacer(),
                // Botões de visualização (desktop/tablet)
                if (!isMobile)
                  Row(
                    children: [
                      _buildViewButton(
                        'Tabela',
                        Icons.table_chart,
                        'tabela',
                        _modoVisualizacao == 'tabela',
                ),
                const SizedBox(width: 8),
                      _buildViewButton(
                        'Cards',
                        Icons.view_module,
                        'cards',
                        _modoVisualizacao == 'cards',
                      ),
                      const SizedBox(width: 8),
                      _buildViewButton(
                        'Calendário',
                        Icons.calendar_today,
                        'calendario',
                        _modoVisualizacao == 'calendario',
                  ),
                    ],
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtroStatusTarefa.clear();
                      _filtroLocais.clear();
                      _filtroSalas.clear();
                      _filtroTipos.clear();
                      _filtroOrdens.clear();
                      _filtroGPMs.clear();
                      _filtroTipoOrdem = 'abertas';
                      _filtroProgramacao = null;
                      _paginaAtual = 0;
                    });
                    _loadOrdens();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),

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
                    width: isMobile ? double.infinity : 180,
                    child: _buildMultiSelectFilterField(
                      'Status (Tarefa)',
                      _filtroStatusTarefa,
                      _statusTarefaDisponiveis,
                      (values) {
                        setState(() => _filtroStatusTarefa = values);
                            _paginaAtual = 0;
                          _loadOrdens();
                          _loadTodasOrdensParaEstatisticas();
                        },
                      searchHint: 'Pesquisar status...',
                    ),
                      ),
                SizedBox(
                    width: isMobile ? double.infinity : 220,
                    child: _buildMultiSelectFilterField(
                      'Local',
                      _filtroLocais,
                      _locaisDisponiveisFiltro,
                      (values) {
                        setState(() => _filtroLocais = values);
                        _paginaAtual = 0;
                      _loadOrdens();
                      _loadTodasOrdensParaEstatisticas();
                    },
                      searchHint: 'Pesquisar local...',
                  ),
                ),
                SizedBox(
                    width: isMobile ? double.infinity : 160,
                    child: _buildMultiSelectFilterField(
                      'Sala',
                      _filtroSalas,
                      _salasDisponiveis,
                      (values) {
                        setState(() => _filtroSalas = values);
                        _paginaAtual = 0;
                      _loadOrdens();
                      _loadTodasOrdensParaEstatisticas();
                    },
                      searchHint: 'Pesquisar sala...',
                  ),
                ),
                SizedBox(
                    width: isMobile ? double.infinity : 160,
                    child: _buildMultiSelectFilterField(
                      'Tipo',
                      _filtroTipos,
                      _tiposDisponiveisFiltro,
                      (values) {
                        setState(() => _filtroTipos = values);
                        _paginaAtual = 0;
                      _loadOrdens();
                      _loadTodasOrdensParaEstatisticas();
                    },
                      searchHint: 'Pesquisar tipo...',
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                    child: _buildMultiSelectFilterField(
                      'Ordem',
                      _filtroOrdens,
                      _ordensDisponiveis,
                      (values) {
                        setState(() => _filtroOrdens = values);
                          _paginaAtual = 0;
                        _loadOrdens();
                        _loadTodasOrdensParaEstatisticas();
                      },
                      searchHint: 'Pesquisar ordem...',
                      ),
                    ),
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                    child: _buildMultiSelectFilterField(
                      'GPM',
                      _filtroGPMs,
                      _gpmsDisponiveis,
                      (values) {
                        setState(() => _filtroGPMs = values);
                          _paginaAtual = 0;
                        _loadOrdens();
                        _loadTodasOrdensParaEstatisticas();
                    },
                      searchHint: 'Pesquisar GPM...',
                      ),
                    ),
                ],
                  ),
                ),
            crossFadeState:
                _filtrosExpandidos ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // Contador de resultados
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Text(
                  'Total: $_totalOrdens ordens (${_ordens.length} nesta página)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Text(
                  'Página ${_paginaAtual + 1} de ${(_totalOrdens / _itensPorPagina).ceil()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Lista de ordems (Cards, Tabela ou Calendário - usando tolerância)
          Expanded(
            child: (() {
              final aguardandoProgramadas = !_ordensProgramadasCarregadas &&
                  ((_filtroProgramacao != null && _filtroProgramacao!.isNotEmpty) ||
                      _filtroStatusTarefa.isNotEmpty);
              final loading = _isLoading || aguardandoProgramadas;
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_ordens.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma ordem encontrada',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }
              return _modoVisualizacao == 'tabela'
                  ? _buildTabelaView()
                  : _modoVisualizacao == 'calendario'
                      ? OrdemCalendarView(
                          ordens: _todasOrdens,
                          onOrdemTap: (ordem) => _mostrarDetalhesOrdem(ordem),
                        )
                      : ListView.builder(
                          itemCount: _ordens.length,
                          itemBuilder: (context, index) {
                            final ordem = _ordens[index];
                            return _buildOrdemCard(ordem);
                          },
                        );
            })(),
          ),

          // Paginação
          if (_modoVisualizacao != 'calendario' && _totalOrdens > _itensPorPagina)
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
                              // Reaplicar paginação local sem refazer fetch
                              final start = _paginaAtual * _itensPorPagina;
                              final end = (start + _itensPorPagina).clamp(0, _todasOrdens.length);
                              _ordens = start < _todasOrdens.length ? _todasOrdens.sublist(start, end) : <Ordem>[];
                            });
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalOrdens / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalOrdens
                        ? () {
                            setState(() {
                              _paginaAtual++;
                              final start = _paginaAtual * _itensPorPagina;
                              final end = (start + _itensPorPagina).clamp(0, _todasOrdens.length);
                              _ordens = start < _todasOrdens.length ? _todasOrdens.sublist(start, end) : <Ordem>[];
                            });
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

  // Criar tarefa a partir de uma ordem
  Future<void> _criarTarefaDaOrdem(Ordem ordem) async {
    try {
      // Calcular datas padrão
      final dataInicio = ordem.inicioBase ?? DateTime.now();
      final dataFim = ordem.fimBase ?? dataInicio.add(const Duration(days: 1));
      
      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          startDate: dataInicio,
          endDate: dataFim,
          ordem: ordem,
        ),
      );
      
      if (taskCriada != null) {
        final taskService = TaskService();
        try {
          final createdTask = await taskService.createTask(taskCriada);
          await _service.vincularOrdemATarefa(createdTask.id, ordem.id);
          await _loadOrdensProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarefa criada e vinculada à ordem ${ordem.ordem} com sucesso!'),
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
                content: Text('Erro ao criar tarefa ou vincular ordem: $e'),
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

  // Vincular ordem a uma tarefa existente
  Future<void> _vincularOrdemATarefaExistente(Ordem ordem) async {
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
          await _service.vincularOrdemATarefa(tarefaSelecionada.id, ordem.id);
          await _loadOrdensProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ordem ${ordem.ordem} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao vincular ordem: $e');
          print('❌ Stack trace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular ordem: ${e.toString()}'),
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
            content: Text('Erro ao vincular ordem: $e'),
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

  // Mostrar todas as vinculações de uma ordem
  void _mostrarTodasVinculacoes(Ordem ordem, List<Map<String, dynamic>> vinculacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarefas vinculadas à ordem ${ordem.ordem}'),
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

  Widget _buildOrdemCard(Ordem ordem) {
    final isProgramada = _ordensProgramadasIds.contains(ordem.id);
    final programadasList = isProgramada ? _ordensProgramadasInfo[ordem.id] : null;
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
              backgroundColor: _getStatusColor(ordem.statusSistema),
              child: Text(
                ordem.tipo ?? '?',
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
                'Ordem: ${ordem.ordem}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ordem.ordem));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ordem copiada!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copiar ordem',
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
            if (ordem.textoBreve != null)
              Text(
                ordem.textoBreve!,
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
                if (ordem.inicioBase != null)
                  Text(
                    'Início: ${_formatDate(ordem.inicioBase!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (ordem.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ordem.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ordem.statusSistema!,
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
                _buildInfoRow('Tipo', ordem.tipo),
                _buildInfoRow('Status Sistema', ordem.statusSistema),
                _buildInfoRow('Status Usuário', ordem.statusUsuario),
                _buildInfoRow('Denominação Local', ordem.denominacaoLocalInstalacao),
                _buildInfoRow('Denominação Objeto', ordem.denominacaoObjeto),
                _buildInfoRow('Texto Breve', ordem.textoBreve),
                _buildInfoRow('Local Instalação', ordem.localInstalacao),
                _buildInfoRow('Código SI', ordem.codigoSI),
                _buildInfoRow('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRow('Início Base', _formatDate(ordem.inicioBase!)),
                if (ordem.fimBase != null)
                  _buildInfoRow('Fim Base', _formatDate(ordem.fimBase!)),
                
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _criarTarefaDaOrdem(ordem),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _vincularOrdemATarefaExistente(ordem),
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

  // Dashboard compacto removido da UI; manter reserva caso necessário no futuro.


  // ignore: unused_element
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

  // ignore: unused_element
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

  int _diasRestantes(Ordem ordem) {
    if (ordem.tolerancia == null) return 999999; // sem prazo vai para o fim
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final prazo = ordem.tolerancia!;
    final prazoSemHora = DateTime(prazo.year, prazo.month, prazo.day);
    return prazoSemHora.difference(hojeSemHora).inDays;
  }

  void _ordenarListaPorPrazo(List<Ordem> lista) {
    lista.sort((a, b) {
      final diasA = _diasRestantes(a);
      final diasB = _diasRestantes(b);
      return _ordenacaoAscendente ? diasA.compareTo(diasB) : diasB.compareTo(diasA);
    });
  }

  void _aplicarOrdenacaoEPaginacao() {
    final ordenadas = List<Ordem>.from(_todasOrdens);
    _ordenarListaPorPrazo(ordenadas);

    final start = _paginaAtual * _itensPorPagina;
    final end = (start + _itensPorPagina).clamp(0, ordenadas.length);
    final pagina = start < ordenadas.length ? ordenadas.sublist(start, end) : <Ordem>[];

    setState(() {
      _todasOrdens = ordenadas;
      _ordens = pagina;
      _totalOrdens = ordenadas.length;
    });
  }

  Widget _buildPrazoBadge(Ordem ordem) {
    if (ordem.tolerancia == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final prazo = ordem.tolerancia!;
    final prazoSemHora = DateTime(prazo.year, prazo.month, prazo.day);

    final diasRestantes = prazoSemHora.difference(hojeSemHora).inDays;

    Color badgeColor;
    Color textColor;

    if (diasRestantes <= 0) {
      badgeColor = Colors.black;
      textColor = Colors.white;
    } else if (diasRestantes <= 30) {
      badgeColor = Colors.red;
      textColor = Colors.white;
    } else if (diasRestantes <= 90) {
      badgeColor = Colors.yellow[700] ?? Colors.amber;
      textColor = Colors.black;
    } else {
      badgeColor = Colors.blue;
      textColor = Colors.white;
    }

    String diasLabel;
    if (diasRestantes < 0) {
      diasLabel = '${diasRestantes} dias';
    } else if (diasRestantes == 0) {
      diasLabel = 'Vence hoje';
    } else if (diasRestantes == 1) {
      diasLabel = '1 dia';
    } else {
      diasLabel = '$diasRestantes dias';
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
            _formatDate(prazoSemHora),
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
              diasLabel,
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

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: [
            const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Tarefa Vinculada', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Sala', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
              label: const Text('Tolerância', style: TextStyle(fontWeight: FontWeight.bold)),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _ordenacaoAscendente = ascending;
                  _paginaAtual = 0;
                });
                _aplicarOrdenacaoEPaginacao();
              },
            ),
            const DataColumn(label: Text('Status Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Local Instalação', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Início Base', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Fim Base', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _ordens.map((ordem) {
            final isProgramada = _ordensProgramadasIds.contains(ordem.id);
            final programadasList = isProgramada ? _ordensProgramadasInfo[ordem.id] : null;
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
                            onTap: () => _criarTarefaDaOrdem(ordem),
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
                            onTap: () => _vincularOrdemATarefaExistente(ordem),
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
                              ? () => _mostrarTodasVinculacoes(ordem, programadasList!)
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
                      Text(
                    ordem.local ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                      ),
                DataCell(
                  SizedBox(
                    width: 89, // mesma largura usada em Notas
                    child: Text(
                      ordem.sala ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _mostrarDetalhesOrdem(ordem),
                        child: Text(
                          ordem.ordem,
                          style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () => _copiarOrdem(ordem.ordem),
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(ordem.tipo ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      ordem.textoBreve ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_buildPrazoBadge(ordem)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ordem.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ordem.statusSistema ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  Text(ordem.statusUsuario ?? '-'),
            ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      ordem.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(ordem.inicioBase != null ? _formatDate(ordem.inicioBase!) : '-'),
                ),
                DataCell(
                  Text(ordem.fimBase != null ? _formatDate(ordem.fimBase!) : '-'),
                ),
                DataCell(
                  Text(ordem.gpm ?? '-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostrarDetalhesOrdem(Ordem ordem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da Ordem: ${ordem.ordem}'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ordem.ordem));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ordem copiada!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copiar ordem',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Ordem', ordem.ordem),
              _buildInfoRow('Tipo', ordem.tipo),
              _buildInfoRow('Status Sistema', ordem.statusSistema),
              _buildInfoRow('Status Usuário', ordem.statusUsuario),
              _buildInfoRow('Texto Breve', ordem.textoBreve),
              _buildInfoRow('Denominação Local', ordem.denominacaoLocalInstalacao),
              _buildInfoRow('Denominação Objeto', ordem.denominacaoObjeto),
              _buildInfoRow('Local Instalação', ordem.localInstalacao),
              _buildInfoRow('Código SI', ordem.codigoSI),
              _buildInfoRow('GPM', ordem.gpm),
              if (ordem.inicioBase != null)
                _buildInfoRow('Início Base', _formatDate(ordem.inicioBase!)),
              if (ordem.fimBase != null)
                _buildInfoRow('Fim Base', _formatDate(ordem.fimBase!)),
              if (ordem.dataImportacao != null)
                _buildInfoRow('Data Importação', _formatDate(ordem.dataImportacao!)),
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

