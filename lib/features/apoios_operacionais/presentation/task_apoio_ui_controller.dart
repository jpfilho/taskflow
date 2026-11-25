import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../models/task.dart';
import '../../../services/divisao_service.dart';
import '../../../services/regional_service.dart';
import '../../../services/segmento_service.dart';
import '../../../services/task_service.dart';
import '../data/repositories/protected_backend_task_apoio_adapter.dart';
import '../data/repositories/supabase_apoios_gateway_repository.dart';
import '../data/repositories/task_apoio_offline_store.dart';
import '../data/services/apoios_auth_session_service.dart';
import '../domain/models/task_apoio_historico.dart';
import '../domain/models/task_apoio_impacto_alteracao.dart';
import '../domain/models/task_apoio_situacao.dart';
import '../domain/models/task_apoio_solicitacao.dart';
import '../domain/models/task_apoio_tipo.dart';
import '../domain/models/task_apoio_vinculo.dart';
import '../domain/repositories/task_apoio_repository.dart';
import '../services/task_apoio_reprogramacao_watcher.dart';
import '../services/task_apoio_service.dart';
import 'task_apoio_demo_fixtures.dart';
import 'widgets/task_apoio_solicitar_dialog.dart';

enum TaskApoioDisponibilidadeEstado {
  disponivel,
  autenticacaoPendente,
  backendIndisponivel,
  modoDemonstracao,
}

/// Controller de UI desacoplado para Apoios Operacionais.
/// Mantém cache em lote por `taskId`, rascunhos de formulário e estado explícito
/// de disponibilidade/demonstração sem nunca mascarar falhas de backend.
class TaskApoioUiController extends ChangeNotifier {
  ITaskApoioRepository _repository;
  late TaskApoioService _service;
  late TaskApoioReprogramacaoWatcher _watcher;
  final TaskApoioOfflineStore offlineStore;

  TaskApoioDisponibilidadeEstado _disponibilidade;
  bool _carregandoLote = false;
  String? _ultimoErroLote;
  bool _operacaoEmAndamento = false;

  final Map<String, TaskApoioResumo> _resumosCache = {};
  final Map<String, Task> _tasksConhecidas = {};
  final Map<String, String> _nomesUnidades = {};
  List<TaskApoioUnidadeOpcao> _catalogoRegionais = const [];
  List<TaskApoioUnidadeOpcao> _catalogoDivisoes = const [];
  List<TaskApoioUnidadeOpcao> _catalogoSegmentos = const [];
  List<TaskApoioTipo> _tiposAtivos = const [];
  bool _catalogoUnidadesCarregado = false;

  TaskApoioUiController({
    ITaskApoioRepository? repository,
    TaskApoioOfflineStore? offlineStore,
    TaskApoioDisponibilidadeEstado? disponibilidadeInicial,
    ApoiosAuthSessionService? sessionService,
  })  : _repository = repository ??
            ((sessionService ?? ApoiosAuthSessionService()).hasValidToken
                ? SupabaseApoiosGatewayRepository(
                    sessionService: sessionService,
                  )
                : const ProtectedBackendTaskApoioAdapter()),
        offlineStore = offlineStore ??
            TaskApoioOfflineStore(persistence: SqliteApoioPersistence()),
        _disponibilidade = disponibilidadeInicial ??
            ((repository != null &&
                    repository is! ProtectedBackendTaskApoioAdapter)
                ? TaskApoioDisponibilidadeEstado.disponivel
                : ((sessionService ?? ApoiosAuthSessionService()).hasValidToken
                    ? TaskApoioDisponibilidadeEstado.disponivel
                    : TaskApoioDisponibilidadeEstado.autenticacaoPendente)) {
    _service = TaskApoioService(repository: _repository);
    _watcher = TaskApoioReprogramacaoWatcher(
      repository: _repository,
      service: _service,
    );
  }

  /// Sincroniza automaticamente o repositório do controller com o estado atual
  /// da sessão autenticada do gateway, sem sobrescrever o modo demo explícito
  /// a menos que `forcar = true`.
  Future<void> sincronizarSessaoAutenticada({
    ApoiosAuthSessionService? sessionService,
    bool forcar = false,
  }) async {
    if (!forcar && isModoDemonstracao) return;
    final auth = sessionService ?? ApoiosAuthSessionService();
    if (auth.hasValidToken) {
      _repository = SupabaseApoiosGatewayRepository(sessionService: auth);
      _service = TaskApoioService(repository: _repository);
      _watcher = TaskApoioReprogramacaoWatcher(
        repository: _repository,
        service: _service,
      );
      _disponibilidade = TaskApoioDisponibilidadeEstado.disponivel;
      _resumosCache.clear();
      _ultimoErroLote = null;
      notifyListeners();
    } else if (!isModoDemonstracao) {
      _repository = const ProtectedBackendTaskApoioAdapter();
      _service = TaskApoioService(repository: _repository);
      _watcher = TaskApoioReprogramacaoWatcher(
        repository: _repository,
        service: _service,
      );
      _disponibilidade = TaskApoioDisponibilidadeEstado.autenticacaoPendente;
      _resumosCache.clear();
      notifyListeners();
    }
  }

  TaskApoioService get service => _service;
  TaskApoioReprogramacaoWatcher get watcher => _watcher;
  TaskApoioDisponibilidadeEstado get disponibilidade => _disponibilidade;
  bool get isModoDemonstracao =>
      _disponibilidade == TaskApoioDisponibilidadeEstado.modoDemonstracao;
  bool get isBackendProtegido =>
      _disponibilidade == TaskApoioDisponibilidadeEstado.autenticacaoPendente ||
      _disponibilidade == TaskApoioDisponibilidadeEstado.backendIndisponivel;
  bool get carregandoLote => _carregandoLote;
  String? get ultimoErroLote => _ultimoErroLote;
  bool get operacaoEmAndamento => _operacaoEmAndamento;
  List<TaskApoioTipo> get tiposAtivos => _tiposAtivos;
  Map<String, String> get nomesUnidades => Map.unmodifiable(_nomesUnidades);
  List<TaskApoioUnidadeOpcao> get regionaisCatalogo => _catalogoRegionais;
  List<TaskApoioUnidadeOpcao> get divisoesCatalogo => _catalogoDivisoes;
  List<TaskApoioUnidadeOpcao> get segmentosCatalogo => _catalogoSegmentos;
  Map<String, Task> get tasksConhecidas => Map.unmodifiable(_tasksConhecidas);

  final Map<String, Task> _tasksSomenteLeitura = {};

  /// Busca uma atividade relacionada a uma solicitação/vínculo de apoio
  /// (inclusive de outra Regional/Divisão/Segmento) para visualização somente leitura.
  Future<Task?> buscarTaskRelacionadaPorId(String taskId) async {
    if (taskId.isEmpty) return null;
    final local = _tasksConhecidas[taskId] ?? _tasksSomenteLeitura[taskId];
    if (local != null) return local;

    Task? encontrada;
    final repo = _repository;
    if (repo is SupabaseApoiosGatewayRepository) {
      try {
        encontrada = await repo.buscarTaskRelacionadaPorId(taskId);
      } catch (_) {}
    }
    encontrada ??= await TaskService().getTaskById(taskId);
    if (encontrada != null) {
      _tasksSomenteLeitura[taskId] = encontrada;
    }
    return encontrada;
  }

  TaskApoioResumo? resumoParaTask(String taskId) => _resumosCache[taskId];

  void registrarTasksConhecidas(Iterable<Task> tasks) {
    for (final t in tasks) {
      _tasksConhecidas[t.id] = t;
    }
  }

  void registrarNomesUnidades(Map<String, String> mapa) {
    if (mapa.isEmpty) return;
    _nomesUnidades.addAll(mapa);
    notifyListeners();
  }

  /// Carrega os nomes reais de Regionais, Divisões e Segmentos para eliminar UUIDs na UI.
  Future<void> carregarCatalogoUnidades({bool forcar = false}) async {
    if (_catalogoUnidadesCarregado && !forcar) return;
    if (isModoDemonstracao) {
      _catalogoUnidadesCarregado = true;
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        RegionalService().getAllRegionais(),
        DivisaoService().getAllDivisoes(),
        SegmentoService().getAllSegmentos(),
      ]);
      final regs = <TaskApoioUnidadeOpcao>[];
      for (final r in results[0] as List) {
        if (r.id != null && r.regional != null) {
          _nomesUnidades[r.id as String] = r.regional as String;
          regs.add(
            TaskApoioUnidadeOpcao(
              id: r.id as String,
              nome: r.regional as String,
            ),
          );
        }
      }
      final divs = <TaskApoioUnidadeOpcao>[];
      for (final d in results[1] as List) {
        if (d.id != null && d.divisao != null) {
          _nomesUnidades[d.id as String] = d.divisao as String;
          final regIds = (d.regionalIds as List?)?.cast<String>() ?? const <String>[];
          divs.add(
            TaskApoioUnidadeOpcao(
              id: d.id as String,
              nome: d.divisao as String,
              parentId: d.regionalId as String?,
              parentIds: regIds,
            ),
          );
        }
      }
      final segs = <TaskApoioUnidadeOpcao>[];
      for (final s in results[2] as List) {
        if (s.id != null && s.segmento != null) {
          _nomesUnidades[s.id as String] = s.segmento as String;
          segs.add(
            TaskApoioUnidadeOpcao(
              id: s.id as String,
              nome: s.segmento as String,
            ),
          );
        }
      }
      _catalogoRegionais = regs;
      _catalogoDivisoes = divs;
      _catalogoSegmentos = segs;
      _catalogoUnidadesCarregado = true;
      notifyListeners();
    } catch (_) {
      // Fallback seguro offline/testes sem plugin Supabase ativo
    }
  }

  /// Ativa o modo de demonstração controlada exclusivamente em ambiente DEV.
  Future<void> ativarModoDemonstracaoDev() async {
    if (!TaskApoioDemoFixtures.isDevDemoAllowed) {
      throw StateError(
        'Modo de demonstração bloqueado fora do ambiente DEV.',
      );
    }
    final demo = await TaskApoioDemoFixtures.criarCenariosObrigatorios();
    _repository = demo.repository;
    _service = TaskApoioService(repository: _repository);
    _watcher = TaskApoioReprogramacaoWatcher(
      repository: _repository,
      service: _service,
    );
    _tasksConhecidas.addAll(demo.tasksPorId);
    _nomesUnidades
      ..clear()
      ..addAll(demo.nomesUnidades);
    _disponibilidade = TaskApoioDisponibilidadeEstado.modoDemonstracao;
    _tiposAtivos = await _service.listarTiposAtivos();
    _ultimoErroLote = null;
    _resumosCache.clear();
    notifyListeners();
  }

  /// Carrega resumos em lote para a `TaskTable` sem consultas N+1 e sem quebrar
  /// a tabela quando o backend estiver protegido/indisponível.
  Future<void> carregarResumosEmLote(
    List<String> taskIds, {
    bool forcar = false,
  }) async {
    if (taskIds.isEmpty) return;

    final pendentes = forcar
        ? taskIds.toSet().toList()
        : taskIds.where((id) => !_resumosCache.containsKey(id)).toList();
    if (pendentes.isEmpty) return;

    _carregandoLote = true;
    _ultimoErroLote = null;
    notifyListeners();

    try {
      final resumos = await _service.buscarResumosEmLote(pendentes);
      _resumosCache.addAll(resumos);
    } on TaskApoioAuthRequiredException catch (e) {
      _disponibilidade = TaskApoioDisponibilidadeEstado.autenticacaoPendente;
      _ultimoErroLote = e.message;
    } catch (e) {
      _ultimoErroLote = e.toString();
    } finally {
      _carregandoLote = false;
      notifyListeners();
    }
  }

  void invalidarCacheTask(String taskId) {
    _resumosCache.remove(taskId);
    notifyListeners();
  }

  Future<List<TaskApoioTipo>> carregarTiposAtivos() async {
    try {
      final remotos = await _service.listarTiposAtivos();
      final ativos = remotos.where((t) => t.ativo).toList();
      if (ativos.isNotEmpty) {
        _tiposAtivos = ativos;
        offlineStore.salvarTiposCache(_tiposAtivos);
        return _tiposAtivos;
      }
    } catch (_) {}

    final cache = offlineStore
        .listarTiposCache()
        .where((t) => t.ativo)
        .toList();
    _tiposAtivos = cache;
    return _tiposAtivos;
  }

  Future<TaskApoioImpactoAlteracao?> verificarImpactoReprogramacao({
    required Task antes,
    required Task depois,
  }) async {
    if (isBackendProtegido) return null;
    return _watcher.avaliarImpactoAlteracao(
      taskAntes: antes,
      taskDepois: depois,
      tasksPorId: _tasksConhecidas,
    );
  }

  Future<T> executarAcaoProtegida<T>(Future<T> Function() acao) async {
    if (_operacaoEmAndamento) {
      throw StateError('Já existe uma operação de apoio em processamento.');
    }
    _operacaoEmAndamento = true;
    notifyListeners();
    try {
      return await acao();
    } finally {
      _operacaoEmAndamento = false;
      notifyListeners();
    }
  }

  Future<List<TaskApoioHistorico>> buscarHistoricoSolicitacao(
    String solicitacaoId,
  ) =>
      _service.buscarHistorico(solicitacaoId: solicitacaoId);

  Future<TaskApoioSituacao> avaliarSituacao(
    TaskApoioSolicitacao solicitacao,
  ) async {
    TaskApoioTipo? tipo;
    for (final t in _tiposAtivos) {
      if (t.id == solicitacao.tipoApoioId) {
        tipo = t;
        break;
      }
    }
    return _service.avaliarSituacaoSolicitacao(
      solicitacao: solicitacao,
      tipoApoio: tipo,
      tasksPorId: _tasksConhecidas,
    );
  }

  Future<(List<TaskApoioSolicitacao>, List<TaskApoioVinculo>)>
      carregarDetalhesParaTask(String taskId) async {
    final sols = await _service.buscarSolicitacoesPorAtividade(taskId);
    final vincs = await _service.consultarRelacionamentoBidirecional(taskId);
    return (sols, vincs);
  }

  /// Cria uma nova atividade de apoio diretamente pela Central e a vincula
  /// definitivamente à solicitação informada.
  Future<Task> criarAtividadeDeApoioEVincular({
    required TaskApoioSolicitacao solicitacao,
    required String titulo,
    String? descricao,
    required DateTime inicio,
    required DateTime fim,
    required String atorUsuarioId,
    String? atorNome,
  }) async {
    return executarAcaoProtegida(() async {
      final repo = _repository;
      final now = DateTime.now();
      if (repo is SupabaseApoiosGatewayRepository) {
        final data = await repo.criarAtividadeDeApoio(
          solicitacaoId: solicitacao.id,
          tarefa: titulo,
          observacoes: descricao,
          dataInicio: inicio,
          dataFim: fim,
          regionalId: solicitacao.regionalDestinoId,
          divisaoId: solicitacao.divisaoDestinoId,
          segmentoId: solicitacao.segmentoDestinoId,
        );
        final taskMap = Map<String, dynamic>.from(data['task'] as Map);
        final created = Task(
          id: taskMap['id']?.toString() ?? 'apoio-${now.microsecondsSinceEpoch}',
          tarefa: taskMap['tarefa']?.toString() ?? titulo,
          observacoes: taskMap['observacoes']?.toString() ?? descricao,
          dataInicio: DateTime.tryParse(taskMap['data_inicio']?.toString() ?? '') ?? inicio,
          dataFim: DateTime.tryParse(taskMap['data_fim']?.toString() ?? '') ?? fim,
          regionalId: taskMap['regional_id']?.toString() ?? solicitacao.regionalDestinoId,
          divisaoId: taskMap['divisao_id']?.toString() ?? solicitacao.divisaoDestinoId,
          segmentoId: taskMap['segmento_id']?.toString() ?? solicitacao.segmentoDestinoId,
          regional: _nomesUnidades[solicitacao.regionalDestinoId] ??
              solicitacao.regionalDestinoId,
          divisao: _nomesUnidades[solicitacao.divisaoDestinoId] ??
              solicitacao.divisaoDestinoId,
          status: taskMap['status']?.toString() ?? 'Programada',
          tipo: taskMap['tipo']?.toString() ?? 'Apoio Operacional',
          coordenador: taskMap['coordenador']?.toString() ?? atorNome ?? '',
          dataCriacao: now,
          dataAtualizacao: now,
        );
        _tasksConhecidas[created.id] = created;
        if (solicitacao.taskSolicitanteId != null) {
          invalidarCacheTask(solicitacao.taskSolicitanteId!);
        }
        return created;
      }

      // Modo demonstração / repositório em memória
      final created = Task(
        id: 'apoio-task-${now.microsecondsSinceEpoch}',
        tarefa: titulo,
        observacoes: descricao ?? '',
        dataInicio: inicio,
        dataFim: fim,
        regionalId: solicitacao.regionalDestinoId,
        divisaoId: solicitacao.divisaoDestinoId,
        segmentoId: solicitacao.segmentoDestinoId,
        regional: _nomesUnidades[solicitacao.regionalDestinoId] ??
            solicitacao.regionalDestinoId,
        divisao: _nomesUnidades[solicitacao.divisaoDestinoId] ??
            solicitacao.divisaoDestinoId,
        status: 'Programada',
        tipo: 'Apoio Operacional',
        coordenador: atorNome ?? '',
        dataCriacao: now,
        dataAtualizacao: now,
      );
      _tasksConhecidas[created.id] = created;
      final taskPrincipal = solicitacao.taskSolicitanteId != null
          ? _tasksConhecidas[solicitacao.taskSolicitanteId!]
          : null;
      if (taskPrincipal != null) {
        await _service.vincularAtividadeExistente(
          id: const Uuid().v4(),
          solicitacaoId: solicitacao.id,
          taskPrincipal: taskPrincipal,
          taskApoio: created,
          tipoApoioId: solicitacao.tipoApoioId,
          autorizadoDireto: false,
          createdBy: atorUsuarioId,
          atorNome: atorNome,
        );
      }
      if (solicitacao.taskSolicitanteId != null) {
        invalidarCacheTask(solicitacao.taskSolicitanteId!);
      }
      return created;
    });
  }

  /// Carrega em lote todas as solicitações e situações para o Gantt Integrado
  /// e Painel Gerencial, sem consultas N+1.
  Future<(List<TaskApoioSolicitacao>, Map<String, TaskApoioSituacao>)>
      carregarDadosGanttIntegrado({List<String> taskIds = const []}) async {
    if (isBackendProtegido) {
      return (const <TaskApoioSolicitacao>[], const <String, TaskApoioSituacao>{});
    }
    final repo = _repository;
    List<TaskApoioSolicitacao> sols;
    if (repo is SupabaseApoiosGatewayRepository) {
      final raw = await repo.buscarGanttIntegrado(taskIds: taskIds);
      final list = (raw['solicitacoes'] as List?) ?? const [];
      sols = list
          .whereType<Map<String, dynamic>>()
          .map(TaskApoioSolicitacao.fromJson)
          .toList();
      final tasksRaw = (raw['tasksVinculadas'] as List?) ?? const [];
      for (final t in tasksRaw.whereType<Map<String, dynamic>>()) {
        final task = Task(
          id: t['id']?.toString() ?? '',
          tarefa: t['tarefa']?.toString() ?? '',
          dataInicio:
              DateTime.tryParse(t['data_inicio']?.toString() ?? '') ?? DateTime.now(),
          dataFim:
              DateTime.tryParse(t['data_fim']?.toString() ?? '') ?? DateTime.now(),
          status: t['status']?.toString() ?? '',
          regional: t['regional']?.toString() ?? '',
          divisao: t['divisao']?.toString() ?? '',
          regionalId: t['regional_id']?.toString(),
          divisaoId: t['divisao_id']?.toString(),
          segmentoId: t['segmento_id']?.toString(),
          frota: t['frota']?.toString() ?? '',
          executor: t['executor']?.toString() ?? '',
          equipeId: t['equipe_id']?.toString(),
          tipo: 'Apoio',
          coordenador: '',
        );
        if (task.id.isNotEmpty) _tasksConhecidas[task.id] = task;
      }
    } else {
      sols = await _service.buscarSolicitacoes();
      if (taskIds.isNotEmpty) {
        final set = taskIds.toSet();
        sols = sols.where((s) => set.contains(s.taskSolicitanteId)).toList();
      }
    }

    final situacoes = <String, TaskApoioSituacao>{};
    for (final s in sols) {
      situacoes[s.id] = await avaliarSituacao(s);
    }
    return (sols, situacoes);
  }

  static final Expando<List<TaskApoioSolicitacao>> _rascunhosPorNovaTask =
      Expando<List<TaskApoioSolicitacao>>('apoios_rascunhos_nova_task');

  /// Associa rascunhos de apoio a uma nova [Task] recém-montada pelo formulário
  /// para que sejam persistidos imediatamente após o `id` real ser gerado.
  static void anexarRascunhosANovaTask(
    Task task,
    List<TaskApoioSolicitacao> rascunhos,
  ) {
    if (rascunhos.isEmpty) return;
    _rascunhosPorNovaTask[task] = List<TaskApoioSolicitacao>.from(rascunhos);
  }

  /// Lê e limpa os rascunhos de apoio associados a uma nova [Task].
  static List<TaskApoioSolicitacao> consumirRascunhosDeNovaTask(Task task) {
    final lista = _rascunhosPorNovaTask[task];
    _rascunhosPorNovaTask[task] = null;
    return lista ?? const [];
  }

  /// Persiste uma lista de rascunhos de solicitação vinculando-os ao `taskId` real.
  /// Retorna uma lista de mensagens de erro (vazia se todos forem salvos).
  static Future<List<String>> persistirRascunhosParaTask({
    required String taskId,
    required String taskTitulo,
    required List<TaskApoioSolicitacao> rascunhos,
    TaskApoioUiController? controller,
  }) async {
    if (rascunhos.isEmpty) return const [];

    TaskApoioService? service;
    if (controller != null && !controller.isBackendProtegido) {
      service = controller.service;
    } else if (ApoiosAuthSessionService().hasValidToken) {
      service = TaskApoioService(repository: SupabaseApoiosGatewayRepository());
    }

    if (service == null) {
      return const [
        'Sessão de Apoios Operacionais não autenticada. Faça login novamente para salvar solicitações de apoio.',
      ];
    }

    final erros = <String>[];
    for (final rascunho in rascunhos) {
      try {
        final normalizada = rascunho.copyWith(
          taskSolicitanteId: taskId,
          taskSolicitanteTituloSnapshot:
              rascunho.taskSolicitanteTituloSnapshot.trim().isEmpty
                  ? taskTitulo
                  : rascunho.taskSolicitanteTituloSnapshot,
        );
        await service.criarSolicitacao(normalizada);
      } catch (e) {
        erros.add(e.toString());
      }
    }
    if (erros.isEmpty && controller != null) {
      controller.invalidarCacheTask(taskId);
    }
    return erros;
  }
}

