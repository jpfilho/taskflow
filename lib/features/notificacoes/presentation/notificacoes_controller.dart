import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import '../../apoios_operacionais/data/services/apoios_auth_session_service.dart';
import '../../apoios_operacionais/presentation/task_apoio_demo_fixtures.dart';
import '../data/notificacoes_gateway_service.dart';
import '../domain/models/notificacao_interna.dart';

/// Controller reutilizável de Notificações Internas do TaskFlow.
/// - Usa polling controlado autenticado (nunca abre canais Realtime públicos).
/// - Mantém cache offline isolado por `usuarioId` em SQLite (`SqliteApoioPersistence`).
/// - Libera timers e cache no logout/troca de usuário.
class NotificacoesController extends ChangeNotifier {
  final NotificacoesGatewayService _gateway;
  final ApoiosAuthSessionService _sessionService;
  final TaskApoioKeyValuePersistence _persistence;

  Timer? _pollingTimer;
  String? _usuarioAtualId;
  bool _carregando = false;
  bool _temMais = true;
  bool _modoDemonstracao = false;
  bool _apenasNaoLidas = false;
  String? _categoriaFiltro;
  String? _erro;
  int _naoLidas = 0;
  List<NotificacaoInterna> _notificacoes = const [];
  NotificacaoPreferencia _preferencias = const NotificacaoPreferencia();

  static const int _pageSize = 20;

  NotificacoesController({
    NotificacoesGatewayService? gateway,
    ApoiosAuthSessionService? sessionService,
    TaskApoioKeyValuePersistence? persistence,
  })  : _gateway = gateway ?? NotificacoesGatewayService(),
        _sessionService = sessionService ?? ApoiosAuthSessionService(),
        _persistence = persistence ?? SqliteApoioPersistence();

  bool get carregando => _carregando;
  bool get temMais => _temMais;
  bool get isModoDemonstracao => _modoDemonstracao;
  bool get apenasNaoLidas => _apenasNaoLidas;
  String? get categoriaFiltro => _categoriaFiltro;
  String? get erro => _erro;
  int get naoLidas => _naoLidas;
  List<NotificacaoInterna> get notificacoes => _notificacoes;
  NotificacaoPreferencia get preferencias => _preferencias;

  List<NotificacaoInterna> get notificacoesFiltradas {
    final ordenadas = List<NotificacaoInterna>.from(_notificacoes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final solicitacoesVistas = <String>{};

    return ordenadas.where((n) {
      if (n.solicitacaoId != null && n.solicitacaoId!.isNotEmpty) {
        if (!solicitacoesVistas.add(n.solicitacaoId!)) {
          return false;
        }
      }
      if (_apenasNaoLidas && n.lida) return false;
      if (_categoriaFiltro != null &&
          _categoriaFiltro!.isNotEmpty &&
          n.categoria != _categoriaFiltro) {
        return false;
      }
      return true;
    }).toList();
  }

  void iniciarParaUsuario(String usuarioId) {
    if (usuarioId.isEmpty) {
      parar();
      return;
    }
    if (_usuarioAtualId != usuarioId) {
      _usuarioAtualId = usuarioId;
      _notificacoes = const [];
      _naoLidas = 0;
      _modoDemonstracao = false;
      _restaurarCacheLocal(usuarioId);
    }

    _pollingTimer?.cancel();
    if (_sessionService.hasValidToken) {
      atualizarContador();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => atualizarContador(),
      );
    }
  }

  void parar() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _usuarioAtualId = null;
    _notificacoes = const [];
    _naoLidas = 0;
    _modoDemonstracao = false;
    _erro = null;
    notifyListeners();
  }

  Future<void> _restaurarCacheLocal(String usuarioId) async {
    try {
      final raw = await _persistence.read('notif_cache_v1_$usuarioId');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(NotificacaoInterna.fromJson)
          .toList();
      if (_usuarioAtualId == usuarioId && _notificacoes.isEmpty) {
        _notificacoes = list;
        _naoLidas = list.where((n) => !n.lida).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _salvarCacheLocal() async {
    final uid = _usuarioAtualId;
    if (uid == null || uid.isEmpty || _modoDemonstracao) return;
    try {
      final encoded = jsonEncode(
        _notificacoes.take(60).map((n) => n.toJson()).toList(),
      );
      await _persistence.write('notif_cache_v1_$uid', encoded);
    } catch (_) {}
  }

  void ativarModoDemonstracaoDev() {
    if (!TaskApoioDemoFixtures.isDevDemoAllowed) return;
    _modoDemonstracao = true;
    final now = DateTime.now();
    _notificacoes = [
      NotificacaoInterna(
        id: 'demo-notif-1',
        categoria: 'SOLICITACAO',
        eventoTipo: 'SOLICITACAO_CRIADA',
        severidade: 'ATENCAO',
        titulo: 'NOVA SOLICITAÇÃO DE APOIO',
        mensagem:
            '[DEMONSTRAÇÃO] Divisão Eletromecânica solicitou Caminhão Munck com operador (23 a 25/11).',
        entidadeTipo: 'SOLICITACAO',
        entidadeId: 'demo-sol-1',
        solicitacaoId: 'demo-sol-1',
        unidadeOrigemNome: 'Divisão Eletromecânica (Demo)',
        unidadeDestinoNome: 'Divisão de Frota (Demo)',
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      NotificacaoInterna(
        id: 'demo-notif-2',
        categoria: 'NEGOCIACAO',
        eventoTipo: 'CONTRAPROPOSTA_ENVIADA',
        severidade: 'ATENCAO',
        titulo: 'CONTRAPROPOSTA DE APOIO',
        mensagem:
            '[DEMONSTRAÇÃO] Divisão de Frota propôs período alternativo (24 a 26/11) para Trator de faixa.',
        entidadeTipo: 'SOLICITACAO',
        entidadeId: 'demo-sol-2',
        solicitacaoId: 'demo-sol-2',
        unidadeOrigemNome: 'Divisão de Frota (Demo)',
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      NotificacaoInterna(
        id: 'demo-notif-3',
        categoria: 'ALTERACAO',
        eventoTipo: 'ATIVIDADE_REPROGRAMADA',
        severidade: 'RISCO',
        titulo: 'ATENÇÃO — APOIO OPERACIONAL EM RISCO',
        mensagem:
            '[DEMONSTRAÇÃO] A atividade de manutenção foi reprogramada para 30/11. O apoio permanece em 23 a 25/11.',
        entidadeTipo: 'SOLICITACAO',
        entidadeId: 'demo-sol-3',
        solicitacaoId: 'demo-sol-3',
        unidadeOrigemNome: 'Manutenção SE Centro (Demo)',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      NotificacaoInterna(
        id: 'demo-notif-4',
        categoria: 'PROGRAMACAO',
        eventoTipo: 'ATIVIDADE_APOIO_CRIADA',
        severidade: 'INFO',
        titulo: 'APOIO PROGRAMADO',
        mensagem:
            '[DEMONSTRAÇÃO] Caminhão Munck programado e vinculado com 100% de cobertura.',
        entidadeTipo: 'SOLICITACAO',
        entidadeId: 'demo-sol-4',
        solicitacaoId: 'demo-sol-4',
        unidadeOrigemNome: 'Divisão de Frota (Demo)',
        lida: true,
        lidaEm: now.subtract(const Duration(minutes: 40)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
    _naoLidas = _notificacoes.where((n) => !n.lida).length;
    _temMais = false;
    _erro = null;
    notifyListeners();
  }

  Future<void> atualizarContador() async {
    if (_modoDemonstracao || !_sessionService.hasValidToken) return;
    try {
      final count = await _gateway.buscarContadorNaoLidas();
      if (count != _naoLidas) {
        _naoLidas = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> carregarNotificacoes({bool reset = true}) async {
    if (_modoDemonstracao) return;
    if (!_sessionService.hasValidToken) {
      _erro = 'Autenticação real pendente. Exibindo histórico em cache local.';
      notifyListeners();
      return;
    }

    _carregando = true;
    _erro = null;
    if (reset) _temMais = true;
    notifyListeners();

    try {
      final offset = reset ? 0 : _notificacoes.length;
      final novas = await _gateway.listarNotificacoes(
        apenasNaoLidas: _apenasNaoLidas,
        categoria: _categoriaFiltro,
        limit: _pageSize,
        offset: offset,
      );
      if (reset) {
        _notificacoes = novas;
      } else {
        final ids = _notificacoes.map((e) => e.id).toSet();
        _notificacoes = [
          ..._notificacoes,
          ...novas.where((n) => !ids.contains(n.id)),
        ];
      }
      _temMais = novas.length >= _pageSize;
      await _salvarCacheLocal();
      await atualizarContador();
    } catch (e) {
      _erro = e.toString();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void definirFiltros({bool? apenasNaoLidas, String? categoria, bool limparCategoria = false}) {
    bool mudou = false;
    if (apenasNaoLidas != null && apenasNaoLidas != _apenasNaoLidas) {
      _apenasNaoLidas = apenasNaoLidas;
      mudou = true;
    }
    if (limparCategoria && _categoriaFiltro != null) {
      _categoriaFiltro = null;
      mudou = true;
    } else if (categoria != null && categoria != _categoriaFiltro) {
      _categoriaFiltro = categoria;
      mudou = true;
    }
    if (mudou) {
      notifyListeners();
      if (!_modoDemonstracao && _sessionService.hasValidToken) {
        carregarNotificacoes(reset: true);
      }
    }
  }

  Future<void> marcarComoLida(String notificacaoId) async {
    final idx = _notificacoes.indexWhere((n) => n.id == notificacaoId);
    final solId = idx >= 0 ? _notificacoes[idx].solicitacaoId : null;
    final idsParaMarcar = <String>{notificacaoId};
    if (solId != null && solId.isNotEmpty) {
      for (final n in _notificacoes) {
        if (n.solicitacaoId == solId && !n.lida) {
          idsParaMarcar.add(n.id);
        }
      }
    }

    if (idx >= 0) {
      final now = DateTime.now();
      int removidas = 0;
      _notificacoes = _notificacoes.map((n) {
        if (idsParaMarcar.contains(n.id) && !n.lida) {
          removidas++;
          return n.copyWith(lida: true, lidaEm: now);
        }
        return n;
      }).toList();
      if (removidas > 0) {
        _naoLidas = (_naoLidas - 1).clamp(0, 999999);
        notifyListeners();
      }
    }
    if (!_modoDemonstracao && _sessionService.hasValidToken) {
      for (final id in idsParaMarcar) {
        try {
          await _gateway.marcarComoLida(id);
        } catch (_) {}
      }
      await _salvarCacheLocal();
    }
  }

  Future<void> marcarTodasComoLidas() async {
    final now = DateTime.now();
    _notificacoes = _notificacoes
        .map((n) => n.lida ? n : n.copyWith(lida: true, lidaEm: now))
        .toList();
    _naoLidas = 0;
    notifyListeners();

    if (!_modoDemonstracao && _sessionService.hasValidToken) {
      try {
        await _gateway.marcarTodasComoLidas();
        await _salvarCacheLocal();
      } catch (_) {}
    }
  }

  Future<void> carregarPreferencias() async {
    if (_modoDemonstracao || !_sessionService.hasValidToken) return;
    try {
      _preferencias = await _gateway.buscarPreferencias();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> salvarPreferencias(NotificacaoPreferencia pref) async {
    _preferencias = pref;
    notifyListeners();
    if (!_modoDemonstracao && _sessionService.hasValidToken) {
      _preferencias = await _gateway.salvarPreferencias(pref);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

