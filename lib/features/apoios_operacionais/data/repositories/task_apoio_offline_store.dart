import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/local_database_service.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_tipo.dart';
import '../../domain/repositories/task_apoio_repository.dart';

/// Abstração de persistência chave-valor para isolamento por usuário e sobrevivência
/// a fechamento/reinicialização do aplicativo.
abstract class TaskApoioKeyValuePersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class InMemoryApoioPersistence implements TaskApoioKeyValuePersistence {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }
}

class SharedPreferencesApoioPersistence
    implements TaskApoioKeyValuePersistence {
  const SharedPreferencesApoioPersistence();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// Persistência definitiva em SQLite via [LocalDatabaseService], com fallback
/// seguro para [SharedPreferences] caso o banco local não esteja acessível.
class SqliteApoioPersistence implements TaskApoioKeyValuePersistence {
  final LocalDatabaseService _localDb;
  final SharedPreferencesApoioPersistence _fallback;

  SqliteApoioPersistence({
    LocalDatabaseService? localDb,
  })  : _localDb = localDb ?? LocalDatabaseService(),
        _fallback = const SharedPreferencesApoioPersistence();

  @override
  Future<String?> read(String key) async {
    try {
      return await _localDb.getApoiosKv(key);
    } catch (_) {
      return _fallback.read(key);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _localDb.setApoiosKv(key, value);
    } catch (_) {
      await _fallback.write(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _localDb.deleteApoiosKv(key);
    } catch (_) {
      await _fallback.delete(key);
    }
  }
}

/// Item da fila local de sincronização para Apoios Operacionais.
/// Isolado por `usuarioId` e protegido por `idempotencyKey` + `versaoEsperada`.
class TaskApoioOfflineQueueItem {
  final String queueId;
  final String usuarioId;
  final String operacao;
  final String entidadeId;
  final String idempotencyKey;
  final int versaoEsperada;
  final Map<String, dynamic> payload;
  final TaskApoioSyncStatus syncStatus;
  final String? erroMensagem;
  final int tentativas;
  final DateTime criadoEm;

  const TaskApoioOfflineQueueItem({
    required this.queueId,
    required this.usuarioId,
    required this.operacao,
    required this.entidadeId,
    required this.idempotencyKey,
    this.versaoEsperada = 1,
    required this.payload,
    this.syncStatus = TaskApoioSyncStatus.pendenteSync,
    this.erroMensagem,
    this.tentativas = 0,
    required this.criadoEm,
  });

  factory TaskApoioOfflineQueueItem.fromJson(Map<String, dynamic> json) {
    return TaskApoioOfflineQueueItem(
      queueId: json['queue_id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? '',
      operacao: json['operacao']?.toString() ?? '',
      entidadeId: json['entidade_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      versaoEsperada: (json['versao_esperada'] as num?)?.toInt() ?? 1,
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const {},
      ),
      syncStatus: TaskApoioSyncStatus.fromCode(json['sync_status']?.toString()),
      erroMensagem: json['erro_mensagem']?.toString(),
      tentativas: (json['tentativas'] as num?)?.toInt() ?? 0,
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'queue_id': queueId,
        'usuario_id': usuarioId,
        'operacao': operacao,
        'entidade_id': entidadeId,
        'idempotency_key': idempotencyKey,
        'versao_esperada': versaoEsperada,
        'payload': payload,
        'sync_status': syncStatus.code,
        'erro_mensagem': erroMensagem,
        'tentativas': tentativas,
        'criado_em': criadoEm.toUtc().toIso8601String(),
      };

  TaskApoioOfflineQueueItem copyWith({
    TaskApoioSyncStatus? syncStatus,
    String? erroMensagem,
    int? tentativas,
  }) {
    return TaskApoioOfflineQueueItem(
      queueId: queueId,
      usuarioId: usuarioId,
      operacao: operacao,
      entidadeId: entidadeId,
      idempotencyKey: idempotencyKey,
      versaoEsperada: versaoEsperada,
      payload: payload,
      syncStatus: syncStatus ?? this.syncStatus,
      erroMensagem: erroMensagem ?? this.erroMensagem,
      tentativas: tentativas ?? this.tentativas,
      criadoEm: criadoEm,
    );
  }
}

/// Camada offline-first preparada para Apoios Operacionais com persistência
/// isolada por usuário (`apoios_offline_v1_<usuarioId>`):
/// - Troca de usuário ou logout NÃO descarta operações pendentes do usuário anterior;
/// - Dados de um usuário nunca ficam visíveis nem são sincronizados na sessão de outro;
/// - Suporta restauração após reinicialização do app.
class TaskApoioOfflineStore {
  String? _usuarioAtualId;
  bool _isOnline;
  final bool _backendAutenticadoDisponivel;
  final TaskApoioKeyValuePersistence _persistence;

  final List<TaskApoioTipo> _tiposCache = [];
  final Map<String, TaskApoioSolicitacao> _solicitacoesCache = {};
  final List<TaskApoioOfflineQueueItem> _fila = [];
  int _seqQueue = 0;

  static const Set<String> operacoesQueExigemConexao = {
    'ACEITAR_SOLICITACAO',
    'RECUSAR_SOLICITACAO',
    'ENVIAR_CONTRAPROPOSTA',
    'ACEITAR_CONTRAPROPOSTA',
    'RECUSAR_CONTRAPROPOSTA',
  };

  TaskApoioOfflineStore({
    String? usuarioAtualId,
    bool isOnline = false,
    bool backendAutenticadoDisponivel = false,
    TaskApoioKeyValuePersistence? persistence,
  })  : _usuarioAtualId = usuarioAtualId,
        _isOnline = isOnline,
        _backendAutenticadoDisponivel = backendAutenticadoDisponivel,
        _persistence = persistence ?? InMemoryApoioPersistence();

  String? get usuarioAtualId => _usuarioAtualId;
  bool get isOnline => _isOnline;

  String _storageKeyForUser(String uid) => 'apoios_offline_v1_$uid';

  void definirConectividade(bool online) {
    _isOnline = online;
  }

  /// Restaura rascunhos e operações pendentes do usuário atual após reinicialização.
  Future<void> restaurarEstadoUsuarioAtual() async {
    final uid = _usuarioAtualId;
    _solicitacoesCache.clear();
    _fila.clear();
    if (uid == null || uid.isEmpty) return;

    final raw = await _persistence.read(_storageKeyForUser(uid));
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final sols = (decoded['solicitacoes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioSolicitacao.fromJson);
    for (final s in sols) {
      _solicitacoesCache[s.id] = s;
    }

    final fila = (decoded['fila'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioOfflineQueueItem.fromJson)
        .where((q) => q.usuarioId == uid);
    _fila.addAll(fila);
    _seqQueue = (decoded['seq'] as num?)?.toInt() ?? _fila.length;
  }

  Future<void> _persistirEstadoUsuarioAtual() async {
    final uid = _usuarioAtualId;
    if (uid == null || uid.isEmpty) return;

    final payload = jsonEncode({
      'seq': _seqQueue,
      'solicitacoes':
          _solicitacoesCache.values.map((s) => s.toJson()).toList(),
      'fila': _fila.where((q) => q.usuarioId == uid).map((q) => q.toJson()).toList(),
    });
    await _persistence.write(_storageKeyForUser(uid), payload);
  }

  /// Troca de usuário/logout com isolamento seguro:
  /// preserva os dados pendentes da conta anterior em sua chave isolada,
  /// limpa a memória ativa e carrega apenas os dados da nova conta.
  Future<void> trocarUsuario(String? novoUsuarioId) async {
    if (_usuarioAtualId == novoUsuarioId) return;
    await _persistirEstadoUsuarioAtual();
    _solicitacoesCache.clear();
    _fila.clear();
    _usuarioAtualId = novoUsuarioId;
    if (novoUsuarioId != null && novoUsuarioId.isNotEmpty) {
      await restaurarEstadoUsuarioAtual();
    }
  }

  void salvarTiposCache(List<TaskApoioTipo> tipos) {
    _tiposCache
      ..clear()
      ..addAll(tipos);
  }

  List<TaskApoioTipo> listarTiposCache() => List.unmodifiable(_tiposCache);

  List<TaskApoioSolicitacao> listarSolicitacoesLocais() =>
      List.unmodifiable(_solicitacoesCache.values);

  List<TaskApoioOfflineQueueItem> listarFila({String? usuarioId}) {
    final uid = usuarioId ?? _usuarioAtualId;
    if (uid == null) return const [];
    return _fila.where((item) => item.usuarioId == uid).toList();
  }

  /// Prepara uma nova solicitação localmente como `pendenteSync` com persistência
  /// isolada por usuário (sem nunca marcá-la como confirmada pela outra unidade).
  Future<TaskApoioSolicitacao> prepararSolicitacaoOffline(
    TaskApoioSolicitacao solicitacao,
  ) async {
    final uid = _usuarioAtualId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Usuário não definido no contexto local.');
    }

    final key = solicitacao.idempotencyKey ?? 'idem-${solicitacao.id}';
    final jaNaFila = _fila.any(
      (q) => q.usuarioId == uid && q.idempotencyKey == key,
    );
    if (jaNaFila && _solicitacoesCache.containsKey(solicitacao.id)) {
      return _solicitacoesCache[solicitacao.id]!;
    }

    final local = solicitacao.copyWith(
      idempotencyKey: key,
      status: TaskApoioStatus.pendente,
      versao: 1,
      syncStatus: TaskApoioSyncStatus.pendenteSync,
    );
    _solicitacoesCache[local.id] = local;

    _seqQueue++;
    _fila.add(
      TaskApoioOfflineQueueItem(
        queueId: 'q-$_seqQueue',
        usuarioId: uid,
        operacao: 'CRIAR_SOLICITACAO',
        entidadeId: local.id,
        idempotencyKey: key,
        versaoEsperada: 1,
        payload: local.toJson(),
        syncStatus: TaskApoioSyncStatus.pendenteSync,
        criadoEm: DateTime.now().toUtc(),
      ),
    );
    await _persistirEstadoUsuarioAtual();
    return local;
  }

  void validarOperacaoCriticaOffline(String operacao) {
    if (operacoesQueExigemConexao.contains(operacao) && !_isOnline) {
      throw StateError(
        'A operação $operacao exige conexão com o servidor para confirmação oficial.',
      );
    }
  }

  Future<List<TaskApoioOfflineQueueItem>> processarFilaSync(
    ITaskApoioRepository remoteRepository,
  ) async {
    if (!_isOnline) {
      return listarFila();
    }
    if (!_backendAutenticadoDisponivel) {
      throw const TaskApoioAuthRequiredException(
        'Sincronização bloqueada: backend ainda não possui autenticação verificável para Apoios Operacionais.',
      );
    }

    final uid = _usuarioAtualId;
    if (uid == null) return const [];

    for (int i = 0; i < _fila.length; i++) {
      final item = _fila[i];
      if (item.usuarioId != uid) continue;
      if (item.syncStatus == TaskApoioSyncStatus.confirmadoServidor) continue;

      _fila[i] = item.copyWith(syncStatus: TaskApoioSyncStatus.emProcessamento);
      try {
        if (item.operacao == 'CRIAR_SOLICITACAO') {
          final sol = TaskApoioSolicitacao.fromJson(item.payload);
          final criada = await remoteRepository.criarSolicitacao(sol);
          _solicitacoesCache[criada.id] = criada.copyWith(
            syncStatus: TaskApoioSyncStatus.confirmadoServidor,
          );
        }
        _fila[i] = _fila[i].copyWith(
          syncStatus: TaskApoioSyncStatus.confirmadoServidor,
        );
      } on TaskApoioVersionConflictException catch (e) {
        _fila[i] = _fila[i].copyWith(
          syncStatus: TaskApoioSyncStatus.conflitoVersao,
          erroMensagem: e.message,
          tentativas: item.tentativas + 1,
        );
        final cached = _solicitacoesCache[item.entidadeId];
        if (cached != null) {
          _solicitacoesCache[item.entidadeId] = cached.copyWith(
            syncStatus: TaskApoioSyncStatus.conflitoVersao,
            syncErrorMessage: e.message,
          );
        }
      } catch (e) {
        _fila[i] = _fila[i].copyWith(
          syncStatus: TaskApoioSyncStatus.rejeitado,
          erroMensagem: e.toString(),
          tentativas: item.tentativas + 1,
        );
        final cached = _solicitacoesCache[item.entidadeId];
        if (cached != null) {
          _solicitacoesCache[item.entidadeId] = cached.copyWith(
            syncStatus: TaskApoioSyncStatus.rejeitado,
            syncErrorMessage: e.toString(),
          );
        }
      }
    }

    await _persistirEstadoUsuarioAtual();
    return listarFila();
  }
}
