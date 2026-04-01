import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
import '../services/local_service.dart';
import '../features/media_albums/data/models/room.dart';
import '../features/media_albums/data/repositories/supabase_media_repository.dart';
import '../features/media_albums/presentation/pages/gallery_page.dart';

/// Info de álbum (imagens) para uma ordem: contagem e filtros para abrir a galeria.
class _AlbumInfo {
  final int count;
  final String? localId;
  final String? roomId;
  _AlbumInfo({required this.count, this.localId, this.roomId});
}

class OrdemView extends StatefulWidget {
  final String? searchQuery;
  
  const OrdemView({super.key, this.searchQuery});

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
  bool _ordenacaoAscendente = true; // Direção da ordenação (asc/desc)
  String? _sortColumn; // Coluna de ordenação atual (null = padrão Tolerância)
  bool _filtrosExpandidos = false;
  Set<String> _ordensProgramadasIds = {}; // IDs das ordens vinculadas a tarefas
  bool _ordensProgramadasCarregadas = false; // Controle de carregamento (evitar limpar tabela enquanto carrega)
  Map<String, List<Map<String, dynamic>>> _ordensProgramadasInfo = {}; // Lista de vinculações por ordem
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  final Set<String> _ordensVinculando = {}; // IDs das ordens que estão sendo vinculadas
  Set<String> _ordensSelecionadas = {}; // IDs das ordens selecionadas para vinculação múltipla
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
  String _searchQuery = ''; // Termo de busca do HeaderBar
  StreamSubscription<String>? _statusChangeSubscription;
  bool _canEditTasks = false; // Permissão para criar/editar tarefas
  bool _canEditTasksChecked = false; // Indica se a permissão já foi verificada
  bool _isCheckingTaskPermission = false; // Evita múltiplas verificações simultâneas
  final AuthServiceSimples _authService = AuthServiceSimples();
  final ExecutorService _executorService = ExecutorService();
  /// Contagem de imagens por ordem (local+sala) para coluna Álbum
  Map<String, _AlbumInfo> _albumInfoByOrdemId = {};
  final SupabaseMediaRepository _mediaRepo = SupabaseMediaRepository();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery ?? '';
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

  @override
  void didUpdateWidget(OrdemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _searchQuery = widget.searchQuery ?? '';
        _paginaAtual = 0;
      });
      // Reaplicar filtros com o novo searchQuery
      _todasOrdens = _aplicarFiltrosLocais(_todasOrdensOriginais);
      _aplicarOrdenacaoEPaginacao();
      _loadTodasOrdensParaEstatisticas();
    }
  }

  int _totalFiltrosAtivos() {
    return _filtroStatusTarefa.length +
        _filtroLocais.length +
        _filtroSalas.length +
        _filtroTipos.length +
        _filtroOrdens.length +
        _filtroGPMs.length;
  }

  Widget _buildViewButton(String label, IconData icon, String value, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _modoVisualizacao = value;
          _paginaAtual = 0;
        });
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

  Future<void> _copiarOrdem(String ordemNumero) async {
    try {
      // Verificar se está em web e clipboard está disponível
      if (kIsWeb) {
        // Em web, pode precisar de permissão ou contexto seguro
        // Tentar copiar mesmo assim
        await Clipboard.setData(ClipboardData(text: ordemNumero));
      } else {
        await Clipboard.setData(ClipboardData(text: ordemNumero));
      }
      
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
          content: Text('Não foi possível copiar a ordem: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
      // Não zerar _ordensProgramadasCarregadas aqui para evitar flicker:
      // a lista não deve ser substituída por loading ao apenas atualizar programadas.

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

  /// Carrega contagem de imagens (álbum) por ordem (local + sala) para exibir na coluna Álbum.
  Future<void> _loadAlbumInfoForOrdens() async {
    if (_todasOrdens.isEmpty) {
      setState(() => _albumInfoByOrdemId = {});
      return;
    }
    try {
      final locais = await LocalService().getAllLocais();
      String localDisplayLower(String s) => (s.trim().toLowerCase());
      const sep = '\u0001';
      final uniqueKeys = <String>{};
      for (final o in _todasOrdens) {
        final localD = _localParaExibicao(o);
        final sala = o.sala?.trim() ?? '';
        uniqueKeys.add('$localD$sep$sala');
      }
      final cache = <String, _AlbumInfo>{};
      for (final key in uniqueKeys) {
        final idx = key.indexOf(sep);
        final localDisplay = idx >= 0 ? key.substring(0, idx) : key;
        final sala = idx >= 0 && idx < key.length - 1 ? key.substring(idx + 1) : '';
        String? localId;
        String? roomId;
        final match = locais.where((l) =>
            localDisplayLower(l.local) == localDisplayLower(localDisplay)).toList();
        if (match.isNotEmpty) {
          final local = match.first;
          localId = local.id;
          final sap = local.localInstalacaoSap?.trim() ?? '';
          if (sala.isNotEmpty && sap.isNotEmpty) {
            roomId = Room.generateDeterministicUuid('room:$sala:$sap');
          }
        }
        final count = await _mediaRepo.countImagesByLocalAndRoom(localId, roomId);
        cache[key] = _AlbumInfo(count: count, localId: localId, roomId: roomId);
      }
      final newMap = <String, _AlbumInfo>{};
      for (final o in _todasOrdens) {
        final localD = _localParaExibicao(o);
        final sala = o.sala?.trim() ?? '';
        final k = '$localD$sep$sala';
        newMap[o.id] = cache[k] ?? _AlbumInfo(count: 0);
      }
      if (mounted) setState(() => _albumInfoByOrdemId = newMap);
    } catch (e) {
      if (kDebugMode) print('⚠️ _loadAlbumInfoForOrdens: $e');
      if (mounted) setState(() => _albumInfoByOrdemId = {});
    }
  }

  static List<String> _ordenarOpcoes(Set<String> set) {
    final list = set.toList();
    list.sort();
    return list;
  }

  /// Atualiza as opções de cada filtro com base na lista ATUALMENTE FILTRADA (_todasOrdens),
  /// para que os demais filtros só mostrem valores que existem na junção dos filtros já aplicados.
  void _atualizarOpcoesFiltros() {
    if (!mounted) return;
    // Usar a lista já filtrada (_todasOrdens), não a original, para que opções reflitam combinações possíveis
    final base = _todasOrdens;

    final statusTarefaSet = <String>{};
    for (final ordem in base) {
      final lista = _ordensProgramadasInfo[ordem.id];
      if (lista == null) continue;
      for (final vinculo in lista) {
        final tarefa = vinculo['tarefa'] as Map<String, dynamic>?;
        final status = tarefa?['status'] as String?;
        if (status != null && status.isNotEmpty) {
          statusTarefaSet.add(status);
        }
      }
    }

    setState(() {
      _statusTarefaDisponiveis = _ordenarOpcoes(statusTarefaSet);
      _locaisDisponiveisFiltro = _ordenarOpcoes(
        base
            .map((o) => o.local)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _salasDisponiveis = _ordenarOpcoes(
        base
            .map((o) => o.sala)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _tiposDisponiveisFiltro = _ordenarOpcoes(
        base
            .map((o) => o.tipo)
            .where((v) => (v ?? '').isNotEmpty)
            .cast<String>()
            .toSet(),
      );
      _ordensDisponiveis = _ordenarOpcoes(base.map((o) => o.ordem).toSet());
      _gpmsDisponiveis = _ordenarOpcoes(
        base
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

      // Filtro de pesquisa (searchQuery do HeaderBar)
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        final matchesSearch = 
            ordem.ordem.toLowerCase().contains(lowerQuery) ||
            (ordem.textoBreve?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.local?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.localInstalacao?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.denominacaoLocalInstalacao?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.denominacaoObjeto?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.codigoSI?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.sala?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.tipo?.toLowerCase().contains(lowerQuery) ?? false) ||
            (ordem.gpm?.toLowerCase().contains(lowerQuery) ?? false);
        
        if (!matchesSearch) return false;
      }

      return true;
    }).toList();
  }

  /// Reaplica filtros localmente sem nova requisição à API (evita loading/flicker).
  /// Filtra a lista COMPLETA (_todasOrdensOriginais) e depois pagina, para não filtrar só a primeira página.
  /// Atualiza as opções dos demais filtros para refletir apenas valores que existem na lista filtrada.
  void _reaplicarFiltrosLocais() {
    if (!mounted) return;
    final filtradas = _aplicarFiltrosLocais(_todasOrdensOriginais);
    final ordenadas = List<Ordem>.from(filtradas);
    _ordenarListaPorColuna(ordenadas);
    final start = 0;
    final end = (_itensPorPagina).clamp(0, ordenadas.length);
    final pagina = start < ordenadas.length ? ordenadas.sublist(start, end) : <Ordem>[];
    setState(() {
      _paginaAtual = 0;
      _todasOrdens = ordenadas;
      _ordens = pagina;
      _totalOrdens = ordenadas.length;
    });
    _atualizarOpcoesFiltros();
    _loadAlbumInfoForOrdens();
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
              _reaplicarFiltrosLocais();
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
        // Opções dos filtros no mesmo frame para não ter tela com ordens e opções vazias
        _locaisDisponiveisFiltro = _ordenarOpcoes(
          ordens.map((o) => o.local).where((v) => (v ?? '').isNotEmpty).cast<String>().toSet(),
        );
        _salasDisponiveis = _ordenarOpcoes(
          ordens.map((o) => o.sala).where((v) => (v ?? '').isNotEmpty).cast<String>().toSet(),
        );
        _tiposDisponiveisFiltro = _ordenarOpcoes(
          ordens.map((o) => o.tipo).where((v) => (v ?? '').isNotEmpty).cast<String>().toSet(),
        );
        _ordensDisponiveis = _ordenarOpcoes(ordens.map((o) => o.ordem).toSet());
        _gpmsDisponiveis = _ordenarOpcoes(
          ordens.map((o) => o.gpm).where((v) => (v ?? '').isNotEmpty).cast<String>().toSet(),
        );
        // _statusTarefaDisponiveis continua do _ordensProgramadasInfo (atualizado em _loadOrdensProgramadas)
      });

      _aplicarOrdenacaoEPaginacao();

      _loadOrdensProgramadas();
      if (mounted) _atualizarOpcoesFiltros();
      if (mounted) _loadAlbumInfoForOrdens();
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
                  onSelectionChanged: (Set<String?> newSelection) {
                    setState(() {
                      _filtroTipoOrdem = newSelection.first;
                    });
                    _reaplicarFiltrosLocais();
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
                const SizedBox(width: 16),
                SegmentedButton<String?>(
                  segments: programacaoSegments,
                  selected: {_filtroProgramacao},
                  onSelectionChanged: (Set<String?> newSelection) {
                    setState(() {
                      _filtroProgramacao = newSelection.first;
                    });
                    _reaplicarFiltrosLocais();
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
            const SizedBox(width: 8),
            if (!isCompact)
              Text(
                _filtrosExpandidos ? 'Ocultar' : 'Mostrar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(width: 16),
            if (_ordensSelecionadas.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      '${_ordensSelecionadas.length} selecionada${_ordensSelecionadas.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _ordensSelecionadas.clear();
                        });
                      },
                      child: Icon(Icons.close, size: 16, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            const Spacer(),
                // Opções de visualização
                if (isCompact)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _modoVisualizacao = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'tabela', child: Row(children: [Icon(Icons.table_chart, size: 18), SizedBox(width: 8), Text('Tabela')])),
                      const PopupMenuItem(value: 'cards', child: Row(children: [Icon(Icons.view_module, size: 18), SizedBox(width: 8), Text('Cards')])),
                      const PopupMenuItem(value: 'calendario', child: Row(children: [Icon(Icons.calendar_today, size: 18), SizedBox(width: 8), Text('Calendário')])),
                    ],
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.view_agenda),
                      label: Text(
                        _modoVisualizacao == 'tabela' ? 'Tabela' : _modoVisualizacao == 'cards' ? 'Cards' : 'Calendário',
                      ),
                      onPressed: null,
                    ),
                  )
                else
                  Row(
                    children: [
                      // Container para os botões de visualização (estilo SegmentedButton)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewButton(
                              'Tabela',
                              Icons.table_chart,
                              'tabela',
                              _modoVisualizacao == 'tabela',
                            ),
                            _buildViewButton(
                              'Cards',
                              Icons.view_module,
                              'cards',
                              _modoVisualizacao == 'cards',
                            ),
                            _buildViewButton(
                              'Calendário',
                              Icons.calendar_today,
                              'calendario',
                              _modoVisualizacao == 'calendario',
                            ),
                          ],
                        ),
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
                    _loadTodasOrdensParaEstatisticas();
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
              // Apenas loading de ordens da API mostra spinner; atualização de programadas não.
              final loading = _isLoading;
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
      if (!await _ensureCanEditTasks()) return;
      
      // Verificar se há ordens selecionadas
      final ordensParaVincular = _ordensSelecionadas.isNotEmpty 
          ? _ordens.where((o) => _ordensSelecionadas.contains(o.id)).toList()
          : [ordem];
      
      // Se há múltiplas ordens selecionadas, usar a primeira para pré-preencher o formulário
      final ordemPrincipal = ordensParaVincular.first;
      
      // Calcular datas padrão baseado na primeira ordem
      final dataInicio = ordemPrincipal.inicioBase ?? DateTime.now();
      final dataFim = ordemPrincipal.fimBase ?? dataInicio.add(const Duration(days: 1));
      
      // Mostrar formulário de criação de tarefa pré-preenchido com dados da ordem principal
      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          startDate: dataInicio,
          endDate: dataFim,
          ordem: ordemPrincipal,
        ),
      );
      
      if (taskCriada != null) {
        // Mostrar diálogo de progresso se houver múltiplas ordens
        final progressDialogContext = context;
        StateSetter? setDialogState;
        int ordensProcessadas = 0;
        String statusAtual = 'Criando tarefa...';
        
        if (ordensParaVincular.length > 1) {
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
                          'Criando tarefa e vinculando ${ordensParaVincular.length} ordens...',
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
                          value: ordensParaVincular.isNotEmpty 
                              ? ordensProcessadas / (ordensParaVincular.length + 1) // +1 para a criação da tarefa
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
        
        final taskService = TaskService();
        try {
          // Atualizar progresso: criando tarefa
          if (ordensParaVincular.length > 1 && setDialogState != null) {
            statusAtual = 'Criando tarefa...';
            setDialogState!(() {});
          }
          
          final createdTask = await taskService.createTask(taskCriada);
          ordensProcessadas++;
          
          // Atualizar progresso: tarefa criada, iniciando vinculação
          if (ordensParaVincular.length > 1 && setDialogState != null) {
            statusAtual = 'Vinculando ordens...';
            setDialogState!(() {});
          }
          
          // Vincular todas as ordens selecionadas (ou apenas a ordem clicada)
          int vinculadasComSucesso = 0;
          int vinculadasComErro = 0;
          
          for (final ordemParaVincular in ordensParaVincular) {
            try {
              await _service.vincularOrdemATarefa(createdTask.id, ordemParaVincular.id);
              vinculadasComSucesso++;
              ordensProcessadas++;
              
              // Atualizar progresso no diálogo
              if (ordensParaVincular.length > 1 && setDialogState != null) {
                statusAtual = 'Vinculando ordens... ($ordensProcessadas/${ordensParaVincular.length + 1})';
                setDialogState!(() {});
              }
            } catch (e) {
              print('❌ Erro ao vincular ordem ${ordemParaVincular.ordem}: $e');
              vinculadasComErro++;
              ordensProcessadas++;
              
              // Atualizar progresso mesmo em caso de erro
              if (ordensParaVincular.length > 1 && setDialogState != null) {
                statusAtual = 'Vinculando ordens... ($ordensProcessadas/${ordensParaVincular.length + 1})';
                setDialogState!(() {});
              }
            }
          }
          
          // Fechar diálogo de progresso se foi aberto
          if (ordensParaVincular.length > 1 && mounted) {
            Navigator.of(progressDialogContext, rootNavigator: true).pop();
          }
          
          // Recarregar ordens programadas para atualizar a visualização
          await _loadOrdensProgramadas();
          
          // Limpar seleção
          if (mounted) {
            setState(() {
              _ordensSelecionadas.clear();
            });
          }
          
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            if (vinculadasComErro == 0) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    vinculadasComSucesso == 1
                        ? 'Tarefa criada e vinculada à ordem ${ordemPrincipal.ordem} com sucesso!'
                        : 'Tarefa criada e $vinculadasComSucesso ordens vinculadas com sucesso!',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Tarefa criada. $vinculadasComSucesso ordem(s) vinculada(s) com sucesso. $vinculadasComErro erro(s).',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          // Fechar diálogo de progresso se foi aberto
          if (ordensParaVincular.length > 1 && mounted) {
            Navigator.of(progressDialogContext, rootNavigator: true).pop();
          }
          
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

  // Vincular ordens selecionadas (ou apenas a ordem clicada)
  Future<void> _vincularOrdensSelecionadas(Ordem ordem) async {
    // Se há ordens selecionadas, vincular todas elas
    if (_ordensSelecionadas.isNotEmpty) {
      await _vincularMultiplasOrdens(_ordensSelecionadas.toList());
    } else {
      // Se não há seleção, vincular apenas a ordem clicada
      await _vincularOrdemATarefaExistente(ordem);
    }
  }

  // Vincular múltiplas ordens a uma tarefa
  Future<void> _vincularMultiplasOrdens(List<String> ordemIds) async {
    if (!mounted || ordemIds.isEmpty) {
      return;
    }

    // Verificar se alguma ordem já está sendo vinculada
    final ordensEmProcessamento = ordemIds.where((id) => _ordensVinculando.contains(id)).toList();
    if (ordensEmProcessamento.isNotEmpty) {
      return;
    }

    // Marcar todas como processando
    setState(() {
      for (final id in ordemIds) {
        _ordensVinculando.add(id);
      }
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Buscar as ordens selecionadas
      final ordensSelecionadas = _ordens.where((o) => ordemIds.contains(o.id)).toList();
      if (ordensSelecionadas.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Nenhuma ordem selecionada encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Usar o local da primeira ordem para filtrar tarefas (ou todas se não houver local)
      final localComum = ordensSelecionadas.first.local;
      
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

      // Filtrar tarefas já vinculadas a qualquer uma das ordens selecionadas
      final tarefasVinculadasSet = <String>{};
      for (final ordem in ordensSelecionadas) {
        final tarefasVinculadas = await _service.getTarefasPorOrdem(ordem.id);
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
                    : 'Todas as tarefas já estão vinculadas às ordens selecionadas',
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
          for (final id in ordemIds) {
            _ordensVinculando.remove(id);
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
          title: 'Vincular ${ordemIds.length} Ordem${ordemIds.length > 1 ? 's' : ''} a Tarefa',
        ),
      );

      if (tarefaSelecionada != null && mounted) {
        // Mostrar diálogo de progresso com StatefulBuilder para atualização dinâmica
        int ordensProcessadas = 0;
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
                        'Vinculando ${ordensSelecionadas.length} ordem${ordensSelecionadas.length > 1 ? 's' : ''}...',
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
                        value: ordensSelecionadas.isNotEmpty ? ordensProcessadas / ordensSelecionadas.length : 0.0,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$ordensProcessadas de ${ordensSelecionadas.length} vinculada${ordensSelecionadas.length > 1 ? 's' : ''}',
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

        // Vincular todas as ordens selecionadas
        int vinculadasComSucesso = 0;
        int vinculadasComErro = 0;

        for (int i = 0; i < ordensSelecionadas.length; i++) {
          final ordem = ordensSelecionadas[i];
          try {
            await _service.vincularOrdemATarefa(tarefaSelecionada.id, ordem.id);
            vinculadasComSucesso++;
            ordensProcessadas++;
            
            // Atualizar progresso no diálogo
            if (mounted && setDialogState != null) {
              setDialogState!(() {});
            }
          } catch (e) {
            print('❌ Erro ao vincular ordem ${ordem.ordem}: $e');
            vinculadasComErro++;
            ordensProcessadas++;
            
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

        // Recarregar ordens programadas
        await _loadOrdensProgramadas();

        // Limpar seleção
        setState(() {
          _ordensSelecionadas.clear();
        });

        if (mounted) {
          if (vinculadasComErro == 0) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  vinculadasComSucesso == 1
                      ? 'Ordem vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'
                      : '$vinculadasComSucesso ordens vinculadas à tarefa "${tarefaSelecionada.tarefa}" com sucesso!',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  '$vinculadasComSucesso ordem(s) vinculada(s) com sucesso. $vinculadasComErro erro(s).',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Erro ao vincular múltiplas ordens: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular ordens: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Remover do conjunto de processamento
      if (mounted) {
        setState(() {
          for (final id in ordemIds) {
            _ordensVinculando.remove(id);
          }
        });
      }
    }
  }

  // Vincular ordem a uma tarefa existente
  Future<void> _vincularOrdemATarefaExistente(Ordem ordem) async {
    if (!mounted || _ordensVinculando.contains(ordem.id)) {
      return;
    }
    
    // Marcar como processando
    setState(() {
      _ordensVinculando.add(ordem.id);
    });
    
    // Capturar o contexto antes de operações assíncronas
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Executar operações em paralelo para ser mais rápido
      final taskService = TaskService();
      final results = await Future.wait([
        taskService.getAllTasks(),
        _service.getTarefasPorOrdem(ordem.id),
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
      
      // Filtrar tarefas do mesmo local da ordem (se a ordem tiver local)
      if (ordem.local != null && ordem.local!.isNotEmpty) {
        tarefasDisponiveis = tarefasDisponiveis
            .where((t) => t.locais.contains(ordem.local))
            .toList();
      }
      
      if (tarefasDisponiveis.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                ordem.local != null && ordem.local!.isNotEmpty
                    ? 'Não há tarefas disponíveis do mesmo local (${ordem.local}) para vincular'
                    : 'Todas as tarefas já estão vinculadas a esta ordem',
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
          _ordensVinculando.remove(ordem.id);
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
          title: 'Vincular Ordem a Tarefa',
        ),
      );
      
      if (tarefaSelecionada != null && mounted) {
        try {
          await _service.vincularOrdemATarefa(tarefaSelecionada.id, ordem.id);
          await _loadOrdensProgramadas();
          
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Ordem ${ordem.ordem} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular ordem: $e'),
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
      // Remover do conjunto de processamento
      if (mounted) {
        setState(() {
          _ordensVinculando.remove(ordem.id);
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
              onPressed: () => _copiarOrdem(ordem.ordem),
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
                      onPressed: _ordensVinculando.contains(ordem.id) 
                          ? null 
                          : () => _vincularOrdemATarefaExistente(ordem),
                      icon: _ordensVinculando.contains(ordem.id)
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
      initialValue: value,
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

  /// Local para exibição: VIEW (local) → denominação → local_instalacao, para funcionar com tabela ou VIEW.
  String _localParaExibicao(Ordem ordem) {
    final v = ordem.local?.trim();
    if (v != null && v.isNotEmpty) return v;
    final d = ordem.denominacaoLocalInstalacao?.trim();
    if (d != null && d.isNotEmpty) return d;
    final i = ordem.localInstalacao?.trim();
    if (i != null && i.isNotEmpty) return i;
    return '-';
  }

  Widget _buildAlbumCell(Ordem ordem) {
    final info = _albumInfoByOrdemId[ordem.id];
    if (info == null || info.count <= 0) {
      return Text('-', style: TextStyle(fontSize: _kTableDataFontSize, color: Colors.grey));
    }
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaAlbumsGalleryPage(
              initialLocalId: info.localId,
              initialRoomId: info.roomId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              '${info.count}',
              style: TextStyle(
                fontSize: _kTableDataFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
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

  int _diasRestantes(Ordem ordem) {
    if (ordem.tolerancia == null) return 999999; // sem prazo vai para o fim
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final prazo = ordem.tolerancia!;
    final prazoSemHora = DateTime(prazo.year, prazo.month, prazo.day);
    return prazoSemHora.difference(hojeSemHora).inDays;
  }

  /// Chave de ordenação para uma ordem na coluna [columnKey].
  String _sortKey(Ordem o, String columnKey) {
    switch (columnKey) {
      case 'Status': {
        final list = _ordensProgramadasInfo[o.id];
        if (list == null || list.isEmpty) return '';
        final tarefa = list.first['tarefa'];
        final status = tarefa is Map<String, dynamic> ? tarefa['status'] as String? : null;
        return (status ?? '').toLowerCase();
      }
      case 'Tarefa Vinculada': {
        final list = _ordensProgramadasInfo[o.id];
        if (list == null || list.isEmpty) return '';
        final tarefa = list.first['tarefa'];
        final titulo = tarefa is Map<String, dynamic> ? tarefa['titulo'] as String? : null;
        return (titulo ?? '').toLowerCase();
      }
      case 'Local':
        return _localParaExibicao(o).toLowerCase();
      case 'Sala':
        return (o.sala ?? '').trim().toLowerCase();
      case 'Álbum':
        final info = _albumInfoByOrdemId[o.id];
        return (info?.count ?? 0).toString().padLeft(8, '0');
      case 'Ordem':
        return (o.ordem).toLowerCase();
      case 'Tipo':
        return (o.tipo ?? '').toLowerCase();
      case 'Texto Breve':
        return (o.textoBreve ?? '').toLowerCase();
      case 'Tolerância':
        return _diasRestantes(o).toString().padLeft(8, '0');
      case 'Status Sistema':
        return (o.statusSistema ?? '').toLowerCase();
      case 'Status Usuário':
        return (o.statusUsuario ?? '').toLowerCase();
      case 'Local Instalação':
        final loc = o.denominacaoLocalInstalacao ?? o.localInstalacao ?? '';
        return loc.trim().toLowerCase();
      case 'Início Base':
        if (o.inicioBase == null) return '';
        return o.inicioBase!.toIso8601String();
      case 'Fim Base':
        if (o.fimBase == null) return '';
        return o.fimBase!.toIso8601String();
      case 'GPM':
        return (o.gpm ?? '').toLowerCase();
      default:
        return _diasRestantes(o).toString().padLeft(8, '0');
    }
  }

  void _ordenarListaPorColuna(List<Ordem> lista) {
    final col = _sortColumn ?? 'Tolerância';
    final asc = _ordenacaoAscendente;
    lista.sort((a, b) {
      final va = _sortKey(a, col);
      final vb = _sortKey(b, col);
      final cmp = va.compareTo(vb);
      return asc ? cmp : -cmp;
    });
  }

  void _aplicarOrdenacaoEPaginacao() {
    final ordenadas = List<Ordem>.from(_todasOrdens);
    _ordenarListaPorColuna(ordenadas);

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
      diasLabel = '$diasRestantes dias';
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

  // Tabela: fonte cabeçalho/dados e larguras (ajuste aqui para reduzir/aumentar)
  static const double _kTableHeaderFontSize = 11;
  static const double _kTableDataFontSize = 10;
  static const double _wTarefaVinculada = 200;
  static const double _wLocal = 72;
  static const double _wSala = 72;
  static const double _wTextoBreve = 250;
  static const double _wLocalInstalacao = 170;

  DataColumn _sortableColumn(String title, String columnKey, TextStyle headerStyle) {
    final isActive = _sortColumn == columnKey || (_sortColumn == null && columnKey == 'Tolerância');
    return DataColumn(
      tooltip: 'Clique para ordenar por $title',
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: headerStyle),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (_ordenacaoAscendente ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
          ),
        ],
      ),
      onSort: (columnIndex, ascending) {
        setState(() {
          _sortColumn = columnKey;
          _ordenacaoAscendente = ascending;
          _paginaAtual = 0;
        });
        _aplicarOrdenacaoEPaginacao();
      },
    );
  }

  Widget _buildTabelaView() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: _kTableHeaderFontSize);
    const dataStyle = TextStyle(fontSize: _kTableDataFontSize);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: [
            DataColumn(
              label: Checkbox(
                value: _ordensSelecionadas.length == _ordens.length && _ordens.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _ordensSelecionadas = _ordens.map((o) => o.id).toSet();
                    } else {
                      _ordensSelecionadas.clear();
                    }
                  });
                },
              ),
            ),
            DataColumn(label: Text('Ações', style: headerStyle)),
            _sortableColumn('Status', 'Status', headerStyle),
            _sortableColumn('Tarefa Vinculada', 'Tarefa Vinculada', headerStyle),
            _sortableColumn('Local', 'Local', headerStyle),
            _sortableColumn('Sala', 'Sala', headerStyle),
            _sortableColumn('Álbum', 'Álbum', headerStyle),
            _sortableColumn('Ordem', 'Ordem', headerStyle),
            _sortableColumn('Tipo', 'Tipo', headerStyle),
            _sortableColumn('Texto Breve', 'Texto Breve', headerStyle),
            _sortableColumn('Tolerância', 'Tolerância', headerStyle),
            _sortableColumn('Status Sistema', 'Status Sistema', headerStyle),
            _sortableColumn('Status Usuário', 'Status Usuário', headerStyle),
            _sortableColumn('Local Instalação', 'Local Instalação', headerStyle),
            _sortableColumn('Início Base', 'Início Base', headerStyle),
            _sortableColumn('Fim Base', 'Fim Base', headerStyle),
            _sortableColumn('GPM', 'GPM', headerStyle),
          ],
          rows: _ordens.map((ordem) {
            final isProgramada = _ordensProgramadasIds.contains(ordem.id);
            final programadasList = isProgramada ? _ordensProgramadasInfo[ordem.id] : null;
            final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
            final totalVinculacoes = programadasList?.length ?? 0;
            
            final isSelected = _ordensSelecionadas.contains(ordem.id);
            return DataRow(
              selected: isSelected,
              color: isProgramada && statusColor != null
                  ? WidgetStateProperty.all(statusColor.withOpacity(0.1))
                  : null,
              cells: [
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _ordensSelecionadas.add(ordem.id);
                        } else {
                          _ordensSelecionadas.remove(ordem.id);
                        }
                      });
                    },
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Criar Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _canEditTasks ? () => _criarTarefaDaOrdem(ordem) : null,
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
                            onTap: _ordensVinculando.contains(ordem.id)
                                ? null
                                : () => _vincularOrdensSelecionadas(ordem),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _ordensVinculando.contains(ordem.id)
                                    ? Colors.grey[200]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _ordensVinculando.contains(ordem.id)
                                      ? Colors.grey[300]!
                                      : Colors.blue[300]!,
                                ),
                              ),
                              child: _ordensVinculando.contains(ordem.id)
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
                            width: _wTarefaVinculada,
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
                      : Text('-', style: dataStyle.copyWith(color: Colors.grey)),
                ),
                DataCell(
                  SizedBox(
                    width: _wLocal,
                    child: Text(
                      _localParaExibicao(ordem),
                      style: dataStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: _wSala,
                    child: Text(
                      ordem.sala ?? '-',
                      style: dataStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_buildAlbumCell(ordem)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _mostrarDetalhesOrdem(ordem),
                        child: Text(
                          ordem.ordem,
                          style: dataStyle.copyWith(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
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
                    child: Text(ordem.tipo ?? '-', style: dataStyle),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: _wTextoBreve,
                    child: Text(
                      ordem.textoBreve ?? '-',
                      style: dataStyle,
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
                      style: TextStyle(color: Colors.white, fontSize: _kTableDataFontSize),
                    ),
                  ),
                ),
                DataCell(
                  Text(ordem.statusUsuario ?? '-', style: dataStyle),
                ),
                DataCell(
                  SizedBox(
                    width: _wLocalInstalacao,
                    child: Text(
                      ordem.localInstalacao ?? '-',
                      style: dataStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(ordem.inicioBase != null ? _formatDate(ordem.inicioBase!) : '-', style: dataStyle),
                ),
                DataCell(
                  Text(ordem.fimBase != null ? _formatDate(ordem.fimBase!) : '-', style: dataStyle),
                ),
                DataCell(
                  Text(ordem.gpm ?? '-', style: dataStyle),
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
              onPressed: () => _copiarOrdem(ordem.ordem),
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

