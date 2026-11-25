import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../../../services/segmento_service.dart';
import '../../../../services/task_service.dart';
import '../../../../widgets/task_form_dialog.dart';
import '../../../../widgets/task_view_dialog.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../task_apoio_demo_fixtures.dart';
import '../task_apoio_status_mapper.dart';
import '../task_apoio_ui_controller.dart';
import '../utils/task_apoio_formatters.dart';
import '../widgets/task_apoio_detail_panel.dart';
import '../widgets/task_apoio_mensagens_dialog.dart';
import '../widgets/task_apoio_negociacao_helper.dart';
import '../widgets/task_apoio_solicitar_dialog.dart';
import '../widgets/task_apoio_vincular_dialog.dart';
import 'apoios_gerencial_dashboard_view.dart';

enum CentralApoiosOrdenacao {
  dataNecessaria('Período necessário'),
  prioridade('Prioridade'),
  riscoSituacao('Risco / Situação');

  final String label;
  const CentralApoiosOrdenacao(this.label);
}

/// Central de Apoios Operacionais — Visão corporativa com Tabela Operacional (`TFDataTable`),
/// Painel Lateral de Detalhamento sob demanda, 6 Indicadores Gerenciais consistentes,
/// Barra de Filtros compacta + Filtros Avançados e compartilhamento do período global.
class CentralApoiosView extends StatefulWidget {
  final TaskApoioUiController controller;
  final String usuarioAtualId;
  final String? usuarioAtualNome;
  final String? regionalAtualId;
  final String? divisaoAtualId;
  final List<String> regionalIdsPermitidas;
  final List<String> divisaoIdsPermitidas;
  final List<String> segmentoIdsPermitidos;
  final DateTime? periodoInicio;
  final DateTime? periodoFim;
  final List<Task> atividadesDisponiveis;
  final List<TaskApoioUnidadeOpcao> regionais;
  final List<TaskApoioUnidadeOpcao> divisoes;
  final List<TaskApoioUnidadeOpcao> segmentos;
  final void Function(Map<String, dynamic> rascunhoAtividade)?
      onCriarAtividadeApoio;
  final void Function(Task task)? onAbrirAtividade;
  final VoidCallback? onAtualizarNotificacoes;
  final int initialTabIndex;
  final String? solicitacaoInicialId;
  final bool podeEditar;
  final bool isRoot;

  const CentralApoiosView({
    super.key,
    required this.controller,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
    this.regionalAtualId,
    this.divisaoAtualId,
    this.regionalIdsPermitidas = const [],
    this.divisaoIdsPermitidas = const [],
    this.segmentoIdsPermitidos = const [],
    this.periodoInicio,
    this.periodoFim,
    this.atividadesDisponiveis = const [],
    this.regionais = const [],
    this.divisoes = const [],
    this.segmentos = const [],
    this.onCriarAtividadeApoio,
    this.onAbrirAtividade,
    this.onAtualizarNotificacoes,
    this.initialTabIndex = 0,
    this.solicitacaoInicialId,
    this.podeEditar = true,
    this.isRoot = false,
  });

  @override
  State<CentralApoiosView> createState() => _CentralApoiosViewState();
}

class _CentralApoiosViewState extends State<CentralApoiosView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _buscaCtrl = TextEditingController();

  bool _carregando = false;
  String? _erro;
  List<TaskApoioSolicitacao> _todasSolicitacoes = const [];
  final Map<String, TaskApoioSituacao> _situacoes = {};

  // Layout e seleção
  bool _indicadoresExpandidos = true;
  String? _solicitacaoSelecionadaId;
  double _larguraPainelLateral = 410;
  int _paginaAtual = 0;
  static const int _itensPorPagina = 20;

  // Filtros contextuais + avançados
  String? _filtroSolicitanteDivId;
  String? _filtroPrestadoraDivId;
  String? _filtroTipoId;
  TaskApoioSituacaoOperacional? _filtroSituacao;
  TaskApoioCriticidade? _filtroCriticidade;
  TaskApoioPrioridade? _filtroPrioridade;
  String? _filtroKpiAtivo;
  bool _incluirPendenciasAnteriores = false;
  bool _somenteComPendencia = false;
  CentralApoiosOrdenacao _ordenacao = CentralApoiosOrdenacao.dataNecessaria;
  final bool _ordemAscendente = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _paginaAtual = 0);
      }
    });
    widget.controller.registrarTasksConhecidas(widget.atividadesDisponiveis);
    _registrarOpcoesCatalogo();
    _carregar();
  }

  void _registrarOpcoesCatalogo() {
    final mapa = <String, String>{};
    for (final r in widget.regionais) {
      mapa[r.id] = r.nome;
    }
    for (final d in widget.divisoes) {
      mapa[d.id] = d.nome;
    }
    for (final s in widget.segmentos) {
      mapa[s.id] = s.nome;
    }
    if (mapa.isNotEmpty) {
      widget.controller.registrarNomesUnidades(mapa);
    }
  }

  @override
  void didUpdateWidget(covariant CentralApoiosView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atividadesDisponiveis != widget.atividadesDisponiveis) {
      widget.controller.registrarTasksConhecidas(widget.atividadesDisponiveis);
    }
    if (oldWidget.controller.disponibilidade !=
        widget.controller.disponibilidade) {
      _carregar();
    }
    if (oldWidget.periodoInicio != widget.periodoInicio ||
        oldWidget.periodoFim != widget.periodoFim) {
      setState(() => _paginaAtual = 0);
    }
    if (widget.solicitacaoInicialId != null &&
        widget.solicitacaoInicialId != oldWidget.solicitacaoInicialId) {
      _selecionarSolicitacaoInicial(widget.solicitacaoInicialId!);
    }
  }

  void _selecionarSolicitacaoInicial(String solicitacaoId) {
    if (solicitacaoId.isEmpty) return;
    final sol = _todasSolicitacoes.where((s) => s.id == solicitacaoId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _solicitacaoSelecionadaId = solicitacaoId;
      if (sol != null) {
        if (_ehRecebidaPeloUsuario(sol)) {
          _tabController.animateTo(0);
        } else if (_ehEnviadaPeloUsuario(sol)) {
          _tabController.animateTo(1);
        } else {
          _tabController.animateTo(2);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (widget.controller.isBackendProtegido) {
      setState(() {
        _todasSolicitacoes = const [];
        _situacoes.clear();
        _erro = null;
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.controller.carregarCatalogoUnidades(),
        widget.controller.carregarTiposAtivos(),
        widget.controller.service.buscarSolicitacoes(),
      ]);
      final lista = results[2] as List<TaskApoioSolicitacao>;

      final situacoesList = await Future.wait(
        lista.map((sol) => widget.controller.avaliarSituacao(sol)),
      );
      final mapaSit = <String, TaskApoioSituacao>{
        for (var i = 0; i < lista.length; i++) lista[i].id: situacoesList[i],
      };

      if (!mounted) return;
      setState(() {
        _todasSolicitacoes = lista;
        _situacoes
          ..clear()
          ..addAll(mapaSit);
      });
      if (widget.solicitacaoInicialId != null &&
          widget.solicitacaoInicialId!.isNotEmpty) {
        _selecionarSolicitacaoInicial(widget.solicitacaoInicialId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Conjuntos organizacionais do usuário logado
  Set<String> get _regsUsuario => {
        ...widget.regionalIdsPermitidas.where((e) => e.isNotEmpty),
        if (widget.regionalAtualId != null && widget.regionalAtualId!.isNotEmpty)
          widget.regionalAtualId!,
      };

  Set<String> get _divsUsuario => {
        ...widget.divisaoIdsPermitidas.where((e) => e.isNotEmpty),
        if (widget.divisaoAtualId != null && widget.divisaoAtualId!.isNotEmpty)
          widget.divisaoAtualId!,
      };

  Set<String> get _segsUsuario =>
      widget.segmentoIdsPermitidos.where((e) => e.isNotEmpty).toSet();

  bool _ehRecebidaPeloUsuario(TaskApoioSolicitacao s) {
    if (widget.isRoot) return true;
    if (_divsUsuario.isEmpty || widget.controller.isModoDemonstracao) {
      return _divsUsuario.isEmpty ? true : _divsUsuario.contains(s.divisaoDestinoId);
    }
    if (_regsUsuario.isNotEmpty && !_regsUsuario.contains(s.regionalDestinoId)) {
      return false;
    }
    if (!_divsUsuario.contains(s.divisaoDestinoId)) return false;
    if (s.segmentoDestinoId == null ||
        s.segmentoDestinoId!.isEmpty ||
        !_segsUsuario.contains(s.segmentoDestinoId)) {
      return false;
    }
    return true;
  }

  bool _ehEnviadaPeloUsuario(TaskApoioSolicitacao s) {
    if (_divsUsuario.isEmpty || widget.controller.isModoDemonstracao) {
      return _divsUsuario.isEmpty
          ? true
          : _divsUsuario.contains(s.divisaoSolicitanteId);
    }
    if (s.solicitanteUsuarioId == widget.usuarioAtualId) return true;
    if (_regsUsuario.isNotEmpty &&
        !_regsUsuario.contains(s.regionalSolicitanteId)) {
      return false;
    }
    if (!_divsUsuario.contains(s.divisaoSolicitanteId)) return false;
    if (_segsUsuario.isNotEmpty &&
        s.segmentoSolicitanteId != null &&
        !_segsUsuario.contains(s.segmentoSolicitanteId)) {
      return false;
    }
    return true;
  }

  /// Verifica interseção do período necessário do apoio com o período global do cabeçalho.
  bool _intersectaPeriodoGlobal(TaskApoioSolicitacao s) {
    final pIni = widget.periodoInicio;
    final pFim = widget.periodoFim;
    if (pIni == null || pFim == null) return true;

    final iniFiltro = DateTime(pIni.year, pIni.month, pIni.day);
    final fimFiltro = DateTime(pFim.year, pFim.month, pFim.day, 23, 59, 59);
    final solIni = TaskApoioFormatters.inicioVigente(s);
    final solFim = TaskApoioFormatters.fimVigente(s);

    final intersecta = !solFim.isBefore(iniFiltro) && !solIni.isAfter(fimFiltro);
    if (intersecta) return true;

    if (_incluirPendenciasAnteriores && solFim.isBefore(iniFiltro)) {
      return _ehPendenteDeResolucao(s);
    }
    return false;
  }

  bool _ehPendenteDeResolucao(TaskApoioSolicitacao s) {
    if (s.status == TaskApoioStatus.cancelada ||
        s.status == TaskApoioStatus.recusada) {
      return false;
    }
    final sit = _situacoes[s.id];
    if (sit?.situacaoOperacional == TaskApoioSituacaoOperacional.concluida) {
      return false;
    }
    return s.status == TaskApoioStatus.pendente ||
        s.status == TaskApoioStatus.emAnalise ||
        s.status == TaskApoioStatus.contraproposta ||
        sit?.situacaoOperacional ==
            TaskApoioSituacaoOperacional.aceitaSemProgramacao ||
        sit?.situacaoOperacional ==
            TaskApoioSituacaoOperacional.parcialmenteProgramada ||
        sit?.situacaoOperacional ==
            TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
        sit?.situacaoOperacional ==
            TaskApoioSituacaoOperacional.programadaComRecursosPendentes;
  }

  /// Base consistente para KPIs e abas: escopo do usuário + período global (sem canceladas inativas por padrão).
  List<TaskApoioSolicitacao> get _universoEscopoEPeriodo {
    return _todasSolicitacoes.where((s) {
      if (!s.ativo) return false;
      if (!_intersectaPeriodoGlobal(s)) return false;
      if (widget.controller.isModoDemonstracao || _divsUsuario.isEmpty) {
        return true;
      }
      return _ehRecebidaPeloUsuario(s) || _ehEnviadaPeloUsuario(s);
    }).toList();
  }

  bool _ehProgramada(TaskApoioSolicitacao s) {
    final sit = _situacoes[s.id];
    return s.status == TaskApoioStatus.aceita &&
        (sit?.qtdVinculosAtivos ?? 0) > 0;
  }

  bool _ehEssencialEmRisco(TaskApoioSolicitacao s) {
    if (s.criticidade != TaskApoioCriticidade.essencial) return false;
    final op = _situacoes[s.id]?.situacaoOperacional;
    return op == TaskApoioSituacaoOperacional.aceitaSemProgramacao ||
        op == TaskApoioSituacaoOperacional.parcialmenteProgramada ||
        op == TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
        op == TaskApoioSituacaoOperacional.programadaComRecursosPendentes;
  }

  List<TaskApoioSolicitacao> _listaPorAba(int tabIndex) {
    final universo = _universoEscopoEPeriodo;
    switch (tabIndex) {
      case 0: // Recebidas
        return universo.where(_ehRecebidaPeloUsuario).toList();
      case 1: // Enviadas
        return universo.where(_ehEnviadaPeloUsuario).toList();
      case 2: // Programados
        return universo.where(_ehProgramada).toList();
      case 3: // Pendências e riscos
      default:
        return universo.where(_ehPendenteDeResolucao).toList();
    }
  }

  List<TaskApoioSolicitacao> _aplicarFiltrosEOrdenacao(
    List<TaskApoioSolicitacao> base,
  ) {
    final termo = _buscaCtrl.text.trim().toLowerCase();
    final nomes = widget.controller.nomesUnidades;

    final filtrada = base.where((s) {
      if (termo.isNotEmpty) {
        final solNome = TaskApoioFormatters.formatarUnidade(
          regionalId: s.regionalSolicitanteId,
          divisaoId: s.divisaoSolicitanteId,
          segmentoId: s.segmentoSolicitanteId,
          nomesUnidades: nomes,
        ).toLowerCase();
        final destNome = TaskApoioFormatters.formatarUnidade(
          regionalId: s.regionalDestinoId,
          divisaoId: s.divisaoDestinoId,
          segmentoId: s.segmentoDestinoId,
          nomesUnidades: nomes,
        ).toLowerCase();

        final bate = s.descricao.toLowerCase().contains(termo) ||
            s.taskSolicitanteTituloSnapshot.toLowerCase().contains(termo) ||
            solNome.contains(termo) ||
            destNome.contains(termo) ||
            (s.locaisAtendimento?.toLowerCase().contains(termo) ?? false);
        if (!bate) return false;
      }

      if (_filtroSolicitanteDivId != null &&
          s.divisaoSolicitanteId != _filtroSolicitanteDivId) {
        return false;
      }
      if (_filtroPrestadoraDivId != null &&
          s.divisaoDestinoId != _filtroPrestadoraDivId) {
        return false;
      }
      if (_filtroTipoId != null && s.tipoApoioId != _filtroTipoId) {
        return false;
      }
      if (_filtroCriticidade != null && s.criticidade != _filtroCriticidade) {
        return false;
      }
      if (_filtroPrioridade != null && s.prioridade != _filtroPrioridade) {
        return false;
      }
      final sit = _situacoes[s.id];
      if (_filtroSituacao != null &&
          sit?.situacaoOperacional != _filtroSituacao) {
        return false;
      }
      if (_somenteComPendencia && !_ehPendenteDeResolucao(s)) {
        return false;
      }

      if (_filtroKpiAtivo != null) {
        switch (_filtroKpiAtivo) {
          case 'recebidas':
            if (!_ehRecebidaPeloUsuario(s)) return false;
          case 'enviadas':
            if (!_ehEnviadaPeloUsuario(s)) return false;
          case 'aguardando':
            if (s.status != TaskApoioStatus.pendente &&
                s.status != TaskApoioStatus.emAnalise &&
                s.status != TaskApoioStatus.contraproposta) {
              return false;
            }
          case 'aceitos_sem_prog':
            if (sit?.situacaoOperacional !=
                TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
              return false;
            }
          case 'programadas':
            if (!_ehProgramada(s)) return false;
          case 'risco':
            if (!_ehEssencialEmRisco(s)) return false;
        }
      }
      return true;
    }).toList();

    filtrada.sort((a, b) {
      int cmp;
      switch (_ordenacao) {
        case CentralApoiosOrdenacao.dataNecessaria:
          cmp = TaskApoioFormatters.inicioVigente(a)
              .compareTo(TaskApoioFormatters.inicioVigente(b));
        case CentralApoiosOrdenacao.prioridade:
          cmp = a.prioridade.index.compareTo(b.prioridade.index);
        case CentralApoiosOrdenacao.riscoSituacao:
          cmp = _pesoRisco(_situacoes[b.id]?.situacaoOperacional)
              .compareTo(_pesoRisco(_situacoes[a.id]?.situacaoOperacional));
      }
      return _ordemAscendente ? cmp : -cmp;
    });

    return filtrada;
  }

  int _pesoRisco(TaskApoioSituacaoOperacional? op) {
    switch (op) {
      case TaskApoioSituacaoOperacional.programadaComIncompatibilidade:
        return 5;
      case TaskApoioSituacaoOperacional.programadaComRecursosPendentes:
        return 4;
      case TaskApoioSituacaoOperacional.parcialmenteProgramada:
        return 3;
      case TaskApoioSituacaoOperacional.aceitaSemProgramacao:
        return 2;
      case TaskApoioSituacaoOperacional.aguardandoAnalise:
      case TaskApoioSituacaoOperacional.emNegociacao:
        return 1;
      default:
        return 0;
    }
  }

  int get _qtdFiltrosAtivos {
    var count = 0;
    if (_buscaCtrl.text.trim().isNotEmpty) count++;
    if (_filtroSolicitanteDivId != null) count++;
    if (_filtroPrestadoraDivId != null) count++;
    if (_filtroTipoId != null) count++;
    if (_filtroSituacao != null) count++;
    if (_filtroCriticidade != null) count++;
    if (_filtroPrioridade != null) count++;
    if (_filtroKpiAtivo != null) count++;
    if (_incluirPendenciasAnteriores) count++;
    if (_somenteComPendencia) count++;
    return count;
  }

  void _limparFiltros() {
    setState(() {
      _buscaCtrl.clear();
      _filtroSolicitanteDivId = null;
      _filtroPrestadoraDivId = null;
      _filtroTipoId = null;
      _filtroSituacao = null;
      _filtroCriticidade = null;
      _filtroPrioridade = null;
      _filtroKpiAtivo = null;
      _incluirPendenciasAnteriores = false;
      _somenteComPendencia = false;
      _paginaAtual = 0;
    });
  }

  // ===========================================================================
  // AÇÕES CONTEXTUAIS POR PAPEL E ESTADO (máx 1 principal + menu secundário)
  // ===========================================================================
  (TaskApoioAcaoUi?, List<TaskApoioAcaoUi>) _construirAcoesContextuais(
    TaskApoioSolicitacao sol,
  ) {
    if (!widget.podeEditar) {
      return (
        TaskApoioAcaoUi(
          label: 'Consultar',
          icon: Icons.visibility_outlined,
          onPressed: () => _abrirDetalhes(sol),
        ),
        const <TaskApoioAcaoUi>[],
      );
    }
    final sit = _situacoes[sol.id];
    final ehPrestadora = widget.controller.isModoDemonstracao ||
        _ehRecebidaPeloUsuario(sol);
    final ehSolicitante = widget.controller.isModoDemonstracao ||
        _ehEnviadaPeloUsuario(sol);

    TaskApoioAcaoUi? principal;
    final secundarias = <TaskApoioAcaoUi>[];

    // Ação principal estritamente coerente com papel + estado
    if (sol.status == TaskApoioStatus.pendente ||
        sol.status == TaskApoioStatus.emAnalise) {
      if (ehPrestadora) {
        principal = TaskApoioAcaoUi(
          label: sol.status == TaskApoioStatus.pendente
              ? 'Analisar'
              : 'Aceitar / Decidir',
          icon: Icons.fact_check_outlined,
          onPressed: () => _executarDecisaoRapida(sol),
        );
      } else {
        principal = TaskApoioAcaoUi(
          label: 'Consultar',
          icon: Icons.visibility_outlined,
          onPressed: () => _abrirDetalhes(sol),
        );
      }
    } else if (sol.status == TaskApoioStatus.contraproposta) {
      if (ehSolicitante) {
        principal = TaskApoioAcaoUi(
          label: 'Responder contraproposta',
          icon: Icons.swap_horiz,
          onPressed: () => _executarNegociacao(
            sol,
            TaskApoioAcao.aceitarContraproposta,
          ),
        );
      } else {
        principal = TaskApoioAcaoUi(
          label: 'Consultar',
          icon: Icons.visibility_outlined,
          onPressed: () => _abrirDetalhes(sol),
        );
      }
    } else if (sol.status == TaskApoioStatus.aceita) {
      if (ehPrestadora &&
          sit?.situacaoOperacional ==
              TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
        principal = TaskApoioAcaoUi(
          label: 'Programar apoio',
          icon: Icons.add_task_outlined,
          onPressed: () => _abrirCriarAtividadeApoio(sol),
        );
      } else {
        principal = TaskApoioAcaoUi(
          label: 'Consultar',
          icon: Icons.visibility_outlined,
          onPressed: () => _abrirDetalhes(sol),
        );
      }
    } else {
      principal = TaskApoioAcaoUi(
        label: 'Consultar',
        icon: Icons.visibility_outlined,
        onPressed: () => _abrirDetalhes(sol),
      );
    }

    // Ações secundárias no menu ⋮
    if (ehPrestadora &&
        (sol.status == TaskApoioStatus.pendente ||
            sol.status == TaskApoioStatus.emAnalise)) {
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Criar tarefa de apoio',
          icon: Icons.add_task_outlined,
          onPressed: () => _abrirCriarAtividadeApoio(sol),
        ),
      );
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Vincular tarefa existente',
          icon: Icons.link,
          onPressed: () => _abrirVincularExistente(sol),
        ),
      );
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Contrapropor período',
          icon: Icons.edit_calendar_outlined,
          onPressed: () => _executarNegociacao(
            sol,
            TaskApoioAcao.enviarContraproposta,
          ),
        ),
      );
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Recusar solicitação',
          icon: Icons.block_outlined,
          isDestructive: true,
          onPressed: () => _executarNegociacao(sol, TaskApoioAcao.recusar),
        ),
      );
    }

    if (ehPrestadora && sol.status == TaskApoioStatus.aceita) {
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Vincular tarefa existente',
          icon: Icons.link,
          onPressed: () => _abrirVincularExistente(sol),
        ),
      );
      if (sit?.situacaoOperacional !=
          TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
        secundarias.add(
          TaskApoioAcaoUi(
            label: 'Criar tarefa de apoio',
            icon: Icons.add_circle_outline,
            onPressed: () => _abrirCriarAtividadeApoio(sol),
          ),
        );
      }
    }

    if (ehSolicitante && sol.status == TaskApoioStatus.aceita) {
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Solicitar reconfirmação',
          icon: Icons.update,
          onPressed: () => _executarNegociacao(
            sol,
            TaskApoioAcao.solicitarReconfirmacao,
          ),
        ),
      );
    }

    secundarias.add(
      TaskApoioAcaoUi(
        label: 'Esclarecimentos',
        icon: Icons.forum_outlined,
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (_) => TaskApoioMensagensDialog(
              solicitacaoId: sol.id,
              tituloSolicitacao: sol.descricao,
              usuarioAtualId: widget.usuarioAtualId,
              usuarioAtualNome: widget.usuarioAtualNome ?? 'Usuário',
              modoDemonstracao: widget.controller.isModoDemonstracao,
            ),
          );
        },
      ),
    );

    final taskRel = sol.taskSolicitanteId != null
        ? widget.controller.tasksConhecidas[sol.taskSolicitanteId!]
        : null;
    if (sol.taskSolicitanteId != null && sol.taskSolicitanteId!.isNotEmpty) {
      secundarias.add(
        TaskApoioAcaoUi(
          label: taskRel != null
              ? 'Abrir atividade relacionada'
              : 'Visualizar atividade relacionada',
          icon: taskRel != null
              ? Icons.open_in_new
              : Icons.visibility_outlined,
          onPressed: () async {
            if (taskRel != null && widget.onAbrirAtividade != null) {
              widget.onAbrirAtividade!(taskRel);
              return;
            }
            final task = taskRel ??
                await widget.controller
                    .buscarTaskRelacionadaPorId(sol.taskSolicitanteId!);
            if (!mounted) return;
            if (task == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Não foi possível carregar os dados desta atividade.',
                  ),
                ),
              );
              return;
            }
            await showDialog(
              context: context,
              builder: (_) => TaskViewDialog(
                task: task,
                apoioController: widget.controller,
                onEdit: null,
              ),
            );
          },
        ),
      );
    }

    if ((ehSolicitante || ehPrestadora) &&
        sol.status != TaskApoioStatus.cancelada &&
        sol.status != TaskApoioStatus.recusada) {
      secundarias.add(
        TaskApoioAcaoUi(
          label: 'Cancelar solicitação',
          icon: Icons.cancel_outlined,
          isDestructive: true,
          onPressed: () => _executarNegociacao(sol, TaskApoioAcao.cancelar),
        ),
      );
    }

    return (principal, secundarias);
  }

  Future<void> _executarDecisaoRapida(TaskApoioSolicitacao sol) async {
    final acao = sol.status == TaskApoioStatus.pendente
        ? TaskApoioAcao.encaminharAnalise
        : TaskApoioAcao.aceitar;
    await _executarNegociacao(sol, acao);
  }

  Future<void> _executarNegociacao(
    TaskApoioSolicitacao sol,
    TaskApoioAcao acao,
  ) async {
    final ok = await TaskApoioNegociacaoHelper.executarAcao(
      context: context,
      controller: widget.controller,
      solicitacao: sol,
      acao: acao,
      usuarioAtualId: widget.usuarioAtualId,
      usuarioAtualNome: widget.usuarioAtualNome,
    );
    if (ok) {
      await _carregar();
      widget.onAtualizarNotificacoes?.call();
    }
  }

  void _abrirDetalhes(TaskApoioSolicitacao sol) {
    final isMobile = MediaQuery.of(context).size.width < 1024;
    if (!isMobile) {
      setState(() => _solicitacaoSelecionadaId = sol.id);
      return;
    }
    final (principal, secundarias) = _construirAcoesContextuais(sol);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: TaskApoioDetailPanel(
          controller: widget.controller,
          solicitacao: sol,
          situacao: _situacoes[sol.id],
          usuarioAtualId: widget.usuarioAtualId,
          usuarioAtualNome: widget.usuarioAtualNome,
          acaoPrincipal: principal,
          acoesSecundarias: secundarias,
          onFechar: () => Navigator.of(ctx).pop(),
          onAbrirAtividade: widget.onAbrirAtividade,
        ),
      ),
    );
  }

  // ===========================================================================
  // DIÁLOGOS DE NOVA SOLICITAÇÃO / CRIAÇÃO / VINCULAÇÃO
  // ===========================================================================
  Future<void> _abrirNovaSolicitacao() async {
    if (widget.controller.isBackendProtegido) return;
    await Future.wait([
      widget.controller.carregarTiposAtivos(),
      widget.controller.carregarCatalogoUnidades(),
    ]);
    if (!mounted) return;

    final tipos = widget.controller.tiposAtivos;
    final regionais = widget.regionais.isNotEmpty
        ? widget.regionais
        : widget.controller.regionaisCatalogo;
    final divisoes = widget.divisoes.isNotEmpty
        ? widget.divisoes
        : widget.controller.divisoesCatalogo;
    final segmentos = widget.segmentos.isNotEmpty
        ? widget.segmentos
        : widget.controller.segmentosCatalogo;

    final regSolicitante = widget.regionalAtualId ??
        (_regsUsuario.isNotEmpty
            ? _regsUsuario.first
            : (regionais.isNotEmpty ? regionais.first.id : ''));
    final divSolicitante = widget.divisaoAtualId ??
        (_divsUsuario.isNotEmpty
            ? _divsUsuario.first
            : (divisoes.isNotEmpty ? divisoes.first.id : ''));
    final segSolicitante = _segsUsuario.isNotEmpty ? _segsUsuario.first : null;

    final sol = await showDialog<TaskApoioSolicitacao>(
      context: context,
      builder: (_) => TaskApoioSolicitarDialog(
        taskSolicitanteTitulo: 'Nova solicitação via Central de Apoios',
        regionalSolicitanteId: regSolicitante,
        divisaoSolicitanteId: divSolicitante,
        segmentoSolicitanteId: segSolicitante,
        usuarioSolicitanteId: widget.usuarioAtualId,
        dataInicioSugerida:
            widget.periodoInicio ?? DateTime.now().add(const Duration(days: 1)),
        dataFimSugerida:
            widget.periodoFim ?? DateTime.now().add(const Duration(days: 2)),
        tiposApoio: tipos,
        regionais: regionais,
        divisoes: divisoes,
        segmentos: segmentos,
        onCarregarSegmentosPorDivisao: widget.controller.isModoDemonstracao
            ? null
            : (divId) async {
                final segs = await SegmentoService().getSegmentosPorDivisao(divId);
                return segs
                    .map(
                      (s) => TaskApoioUnidadeOpcao(
                        id: s.id,
                        nome: s.segmento,
                        parentId: divId,
                      ),
                    )
                    .toList();
              },
      ),
    );
    if (sol == null || !mounted) return;
    try {
      await widget.controller.service.criarSolicitacao(sol);
      await _carregar();
      widget.onAtualizarNotificacoes?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de apoio salva com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar solicitação de apoio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirVincularExistente(TaskApoioSolicitacao sol) async {
    final tasksLista = widget.controller.tasksConhecidas.values.toList();
    final res = await showDialog<TaskApoioVincularResultado>(
      context: context,
      builder: (_) => TaskApoioVincularDialog(
        taskPrincipalId: sol.taskSolicitanteId ?? sol.id,
        divisaoPrincipalId: sol.divisaoSolicitanteId,
        onBuscarAtividades: ({
          String? termo,
          String? regional,
          String? divisao,
          String? status,
          int limit = 20,
          int offset = 0,
        }) async {
          final q = (termo ?? '').trim().toLowerCase();
          return tasksLista.where((t) {
            if (t.id == sol.taskSolicitanteId) return false;
            if (q.isEmpty) return true;
            return t.tarefa.toLowerCase().contains(q) ||
                t.divisao.toLowerCase().contains(q);
          }).toList();
        },
      ),
    );
    if (res == null || !mounted) return;
    try {
      final solAceita = await _garantirAceiteAntesDeVincular(sol);
      final taskPrincipalId = solAceita.taskSolicitanteId;
      if (taskPrincipalId != null && taskPrincipalId.isNotEmpty) {
        final taskPrinc =
            widget.controller.tasksConhecidas[taskPrincipalId] ??
            Task(
              id: taskPrincipalId,
              tarefa: solAceita.taskSolicitanteTituloSnapshot,
              dataInicio: TaskApoioFormatters.inicioVigente(solAceita),
              dataFim: TaskApoioFormatters.fimVigente(solAceita),
              status: 'PROG',
              tipo: 'Manutenção',
              coordenador: '',
              regional: '',
              divisao: '',
            );
        await widget.controller.service.vincularAtividadeExistente(
          id: const Uuid().v4(),
          solicitacaoId: solAceita.id,
          taskPrincipal: taskPrinc,
          taskApoio: res.taskSelecionada,
          tipoApoioId: solAceita.tipoApoioId,
          autorizadoDireto: res.autorizadoDireto,
          observacao: res.observacao,
          createdBy: widget.usuarioAtualId,
          atorNome: widget.usuarioAtualNome,
        );
      }
      await _carregar();
      widget.onAtualizarNotificacoes?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              taskPrincipalId != null && taskPrincipalId.isNotEmpty
                  ? 'Tarefa vinculada ao apoio com sucesso.'
                  : 'Solicitação aceita. Não foi possível criar vínculo porque a solicitação não possui tarefa principal.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<TaskApoioSolicitacao> _garantirAceiteAntesDeVincular(
    TaskApoioSolicitacao sol,
  ) async {
    var atual = sol;
    if (atual.status == TaskApoioStatus.pendente) {
      atual = await widget.controller.service.encaminharParaAnalise(
        solicitacaoId: atual.id,
        versaoEsperada: atual.versao,
        responsavelId: widget.usuarioAtualId,
        responsavelNome: widget.usuarioAtualNome,
      );
    }
    if (atual.status == TaskApoioStatus.emAnalise) {
      atual = await widget.controller.service.aceitar(
        solicitacaoId: atual.id,
        versaoEsperada: atual.versao,
        atorUsuarioId: widget.usuarioAtualId,
        atorNome: widget.usuarioAtualNome,
        observacoes: 'Aceite automático ao programar/vincular tarefa de apoio.',
      );
    }
    return atual;
  }

  Future<void> _abrirCriarAtividadeApoio(TaskApoioSolicitacao sol) async {
    if (widget.onCriarAtividadeApoio != null &&
        widget.controller.isModoDemonstracao) {
      widget.onCriarAtividadeApoio!({'solicitacao_id': sol.id});
      return;
    }

    final inicio = TaskApoioFormatters.inicioVigente(sol);
    final fim = TaskApoioFormatters.fimVigente(sol);

    if (!widget.controller.isModoDemonstracao) {
      final novaTask = await showDialog<Task>(
        context: context,
        builder: (_) => TaskFormDialog(
          startDate: inicio,
          endDate: fim,
          apoioSolicitacao: sol,
        ),
      );
      if (novaTask == null || !mounted) return;
      try {
        final created = await TaskService().createTask(novaTask);
        final solAceita = await _garantirAceiteAntesDeVincular(sol);
        final taskPrincipalId = solAceita.taskSolicitanteId;
        if (taskPrincipalId != null && taskPrincipalId.isNotEmpty) {
          final taskPrinc =
              widget.controller.tasksConhecidas[taskPrincipalId] ??
              Task(
                id: taskPrincipalId,
                tarefa: solAceita.taskSolicitanteTituloSnapshot,
                dataInicio: inicio,
                dataFim: fim,
                status: 'PROG',
                tipo: 'Manutenção',
                coordenador: '',
                regional: '',
                divisao: '',
              );
          await widget.controller.service.vincularAtividadeExistente(
            id: const Uuid().v4(),
            solicitacaoId: solAceita.id,
            taskPrincipal: taskPrinc,
            taskApoio: created,
            tipoApoioId: solAceita.tipoApoioId,
            autorizadoDireto: true,
            observacao: 'Tarefa de apoio criada diretamente pela Central.',
            createdBy: widget.usuarioAtualId,
            atorNome: widget.usuarioAtualNome,
          );
        }
        await _carregar();
        widget.onAtualizarNotificacoes?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                taskPrincipalId != null && taskPrincipalId.isNotEmpty
                    ? 'Tarefa de apoio criada e vinculada com sucesso.'
                    : 'Tarefa de apoio criada e solicitação aceita com sucesso.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar e vincular tarefa de apoio: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    final tituloCtrl = TextEditingController(
      text: 'Apoio: ${sol.descricao}',
    );
    final obsCtrl = TextEditingController(
      text: 'Atendimento à atividade: ${sol.taskSolicitanteTituloSnapshot}',
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar atividade de apoio'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Solicitação: ${sol.descricao}',
                style: ctx.tfTypography.bodySmall.copyWith(
                  color: ctx.tfColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título da atividade de apoio *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Período: ${TaskApoioFormatters.formatarPeriodoHumano(inicio, fim)}',
                style: ctx.tfTypography.labelSmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Criar e vincular'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    try {
      await widget.controller.criarAtividadeDeApoioEVincular(
        solicitacao: sol,
        titulo: tituloCtrl.text.trim().isEmpty
            ? 'Apoio: ${sol.descricao}'
            : tituloCtrl.text.trim(),
        descricao: obsCtrl.text.trim(),
        inicio: inicio,
        fim: fim,
        atorUsuarioId: widget.usuarioAtualId,
        atorNome: widget.usuarioAtualNome,
      );
      await _carregar();
      widget.onAtualizarNotificacoes?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar atividade de apoio: $e')),
        );
      }
    }
  }

  Future<void> _abrirFiltrosAvancados() async {
    final tipos = widget.controller.tiposAtivos;
    var critTmp = _filtroCriticidade;
    var prioTmp = _filtroPrioridade;
    var tipoTmp = _filtroTipoId;
    var sitTmp = _filtroSituacao;
    var pendTmp = _somenteComPendencia;
    var antTmp = _incluirPendenciasAnteriores;

    final aplicar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: const Text('Filtros avançados'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: tipoTmp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de apoio',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...tipos.map(
                        (t) => DropdownMenuItem(value: t.id, child: Text(t.nome)),
                      ),
                    ],
                    onChanged: (v) => setStateDlg(() => tipoTmp = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskApoioSituacaoOperacional?>(
                    initialValue: sitTmp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Situação operacional',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...TaskApoioSituacaoOperacional.values.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                      ),
                    ],
                    onChanged: (v) => setStateDlg(() => sitTmp = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskApoioCriticidade?>(
                    initialValue: critTmp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Criticidade',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...TaskApoioCriticidade.values.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      ),
                    ],
                    onChanged: (v) => setStateDlg(() => critTmp = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskApoioPrioridade?>(
                    initialValue: prioTmp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Prioridade',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...TaskApoioPrioridade.values.map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                      ),
                    ],
                    onChanged: (v) => setStateDlg(() => prioTmp = v),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pendTmp,
                    title: const Text('Somente com pendência operacional'),
                    onChanged: (v) => setStateDlg(() => pendTmp = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: antTmp,
                    title: const Text('Incluir pendências anteriores'),
                    subtitle: const Text(
                      'Exibe apoios pendentes de períodos anteriores ao selecionado.',
                    ),
                    onChanged: (v) => setStateDlg(() => antTmp = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );

    if (aplicar == true && mounted) {
      setState(() {
        _filtroTipoId = tipoTmp;
        _filtroSituacao = sitTmp;
        _filtroCriticidade = critTmp;
        _filtroPrioridade = prioTmp;
        _somenteComPendencia = pendTmp;
        _incluirPendenciasAnteriores = antTmp;
        _paginaAtual = 0;
      });
    }
  }

  // ===========================================================================
  // BUILD PRINCIPAL
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isMobile = width < 600;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final universo = _universoEscopoEPeriodo;
        final tabIndex = _tabController.index;

        final recebidasList = universo.where(_ehRecebidaPeloUsuario).toList();
        final enviadasList = universo.where(_ehEnviadaPeloUsuario).toList();
        final programadasList = universo.where(_ehProgramada).toList();
        final pendenciasList = universo.where(_ehPendenteDeResolucao).toList();
        final aguardandoCount = universo
            .where(
              (s) =>
                  s.status == TaskApoioStatus.pendente ||
                  s.status == TaskApoioStatus.emAnalise ||
                  s.status == TaskApoioStatus.contraproposta,
            )
            .length;
        final aceitasSemProgCount = universo
            .where(
              (s) =>
                  _situacoes[s.id]?.situacaoOperacional ==
                  TaskApoioSituacaoOperacional.aceitaSemProgramacao,
            )
            .length;
        final riscoCount = universo.where(_ehEssencialEmRisco).length;

        final listaAba = _listaPorAba(tabIndex);
        final listaFiltrada = _aplicarFiltrosEOrdenacao(listaAba);

        final totalPaginas =
            (listaFiltrada.length / _itensPorPagina).ceil().clamp(1, 9999);
        final paginaSegura = _paginaAtual.clamp(0, totalPaginas - 1);
        final inicioIdx = paginaSegura * _itensPorPagina;
        final fimIdx =
            (inicioIdx + _itensPorPagina).clamp(0, listaFiltrada.length);
        final itensPagina = listaFiltrada.sublist(inicioIdx, fimIdx);

        final selecionada = _solicitacaoSelecionadaId == null
            ? null
            : universo
                .where((s) => s.id == _solicitacaoSelecionadaId)
                .firstOrNull;

        final nomes = widget.controller.nomesUnidades;
        final unidadeContexto = TaskApoioFormatters.formatarUnidade(
          regionalId: widget.regionalAtualId,
          divisaoId: widget.divisaoAtualId,
          nomesUnidades: nomes,
        );
        final periodoTexto =
            widget.periodoInicio != null && widget.periodoFim != null
                ? TaskApoioFormatters.formatarPeriodoHumano(
                    widget.periodoInicio!,
                    widget.periodoFim!,
                  )
                : 'Todos os períodos';

        return Container(
          color: colors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho corporativo compacto
              _buildCabecalho(
                context,
                isMobile: isMobile,
                unidadeContexto: unidadeContexto,
                periodoTexto: periodoTexto,
              ),

              if (widget.controller.isBackendProtegido)
                _buildBannerProtegido(context)
              else if (widget.controller.isModoDemonstracao)
                _buildBannerDemo(context),

              // 2. Indicadores Gerenciais (6 KPIs recolhíveis e consistentes)
              if (!widget.controller.isBackendProtegido)
                _buildIndicadoresSection(
                  context,
                  isMobile: isMobile,
                  recebidas: recebidasList.length,
                  enviadas: enviadasList.length,
                  aguardando: aguardandoCount,
                  aceitasSemProg: aceitasSemProgCount,
                  programadas: programadasList.length,
                  risco: riscoCount,
                ),

              // 3. Navegação por Abas
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(color: colors.borderSubtle),
                    bottom: BorderSide(color: colors.borderSubtle),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: typo.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(text: 'Recebidas (${recebidasList.length})'),
                    Tab(text: 'Enviadas (${enviadasList.length})'),
                    Tab(text: 'Programados (${programadasList.length})'),
                    Tab(text: 'Pendências e riscos (${pendenciasList.length})'),
                    const Tab(text: 'Gestão & Reunião'),
                  ],
                ),
              ),

              // 4. Barra de Filtros Compacta (oculta na aba Gestão & Reunião)
              if (tabIndex != 4 && !widget.controller.isBackendProtegido)
                _buildBarraFiltros(context, isMobile: isMobile),

              // 5. Área de Trabalho Principal
              Expanded(
                child: _carregando
                    ? const Center(
                        child: TFLoading(message: 'Carregando apoios operacionais...'),
                      )
                    : _erro != null
                        ? Center(
                            child: TFEmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: 'Não foi possível carregar os apoios',
                              description: _erro!,
                              action: TFButton(
                                label: 'Tentar novamente',
                                variant: TFButtonVariant.secondary,
                                onPressed: _carregar,
                              ),
                            ),
                          )
                        : tabIndex == 4
                            ? ApoiosGerencialDashboardView(
                                controller: widget.controller,
                                solicitacoes: universo,
                                situacoes: _situacoes,
                                usuarioAtualId: widget.usuarioAtualId,
                                usuarioAtualNome: widget.usuarioAtualNome,
                                divisaoAtualId: widget.divisaoAtualId,
                                onSelecionarIndicador: (cat) {
                                  _tabController.animateTo(3);
                                  setState(() {
                                    _filtroKpiAtivo = cat == 'emRisco'
                                        ? 'risco'
                                        : (cat == 'aceitosSemProg'
                                            ? 'aceitos_sem_prog'
                                            : null);
                                  });
                                },
                                onAbrirAtividade: widget.onAbrirAtividade,
                              )
                            : isDesktop
                                ? _buildDesktopWorkspace(
                                    context,
                                    itensPagina: itensPagina,
                                    totalItens: listaFiltrada.length,
                                    paginaAtual: paginaSegura,
                                    totalPaginas: totalPaginas,
                                    selecionada: selecionada,
                                  )
                                : _buildMobileList(
                                    context,
                                    itensPagina: itensPagina,
                                    totalItens: listaFiltrada.length,
                                    paginaAtual: paginaSegura,
                                    totalPaginas: totalPaginas,
                                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCabecalho(
    BuildContext context, {
    required bool isMobile,
    required String unidadeContexto,
    required String periodoTexto,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;

    return Container(
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 12,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Central de Apoios Operacionais',
                style: typo.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Unidade: $unidadeContexto • Período: $periodoTexto',
                style: typo.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TFButton(
                label: 'Atualizar',
                leadingIcon: Icons.refresh,
                variant: TFButtonVariant.secondary,
                size: TFButtonSize.small,
                onPressed: _carregando ? null : _carregar,
              ),
              if (widget.podeEditar)
                TFButton(
                  label: 'Nova solicitação',
                  leadingIcon: Icons.add,
                  variant: TFButtonVariant.primary,
                  size: TFButtonSize.small,
                  onPressed: widget.controller.isBackendProtegido
                      ? null
                      : _abrirNovaSolicitacao,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerProtegido(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: colors.warning, size: 20),
          Text(
            'Apoios Operacionais protegidos — autentique-se para consultar e gerenciar solicitações reais.',
            style: typo.bodySmall.copyWith(color: colors.textPrimary),
          ),
          if (TaskApoioDemoFixtures.isDevDemoAllowed)
            TFButton(
              label: 'Ativar Modo Demonstração (DEV)',
              variant: TFButtonVariant.secondary,
              size: TFButtonSize.small,
              onPressed: () async {
                await widget.controller.ativarModoDemonstracaoDev();
                await _carregar();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBannerDemo(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Container(
      color: colors.info.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: colors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODO DEMONSTRAÇÃO (DEV) — Dados simulados para homologação visual.',
              style: typo.labelSmall.copyWith(
                color: colors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicadoresSection(
    BuildContext context, {
    required bool isMobile,
    required int recebidas,
    required int enviadas,
    required int aguardando,
    required int aceitasSemProg,
    required int programadas,
    required int risco,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;

    final kpis = [
      (
        'recebidas',
        'Recebidas',
        recebidas,
        colors.primary,
        0,
      ),
      (
        'enviadas',
        'Enviadas',
        enviadas,
        colors.textPrimary,
        1,
      ),
      (
        'aguardando',
        'Aguardando resposta',
        aguardando,
        aguardando > 0 ? colors.warning : colors.textPrimary,
        3,
      ),
      (
        'aceitos_sem_prog',
        'Aceitas s/ programação',
        aceitasSemProg,
        aceitasSemProg > 0 ? colors.warning : colors.textPrimary,
        3,
      ),
      (
        'programadas',
        'Programadas',
        programadas,
        colors.success,
        2,
      ),
      (
        'risco',
        'Essenciais em risco',
        risco,
        risco > 0 ? colors.danger : colors.textPrimary,
        3,
      ),
    ];

    return Container(
      color: colors.surface,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        0,
        isMobile ? 12 : 20,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => setState(
                  () => _indicadoresExpandidos = !_indicadoresExpandidos,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _indicadoresExpandidos
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _indicadoresExpandidos
                          ? 'Indicadores do período'
                          : 'Mostrar indicadores do período',
                      style: typo.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_indicadoresExpandidos)
                Text(
                  _incluirPendenciasAnteriores
                      ? 'Inclui pendências de períodos anteriores'
                      : 'Mesmo escopo e período das abas',
                  style: typo.labelSmall.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
          if (_indicadoresExpandidos) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 1100
                    ? 6
                    : (constraints.maxWidth >= 600 ? 3 : 2);
                const spacing = 8.0;
                final cardWidth =
                    (constraints.maxWidth - (spacing * (cols - 1))) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: kpis.map((k) {
                    final ativo = _filtroKpiAtivo == k.$1;
                    return SizedBox(
                      width: cardWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _filtroKpiAtivo = ativo ? null : k.$1;
                            _paginaAtual = 0;
                          });
                          if (!ativo) {
                            _tabController.animateTo(k.$5);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ativo
                                ? colors.primary.withValues(alpha: 0.08)
                                : colors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ativo
                                  ? colors.primary
                                  : colors.borderSubtle,
                              width: ativo ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${k.$3}',
                                style: typo.sectionTitle.copyWith(
                                  fontSize: 22,
                                  color: k.$4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                k.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typo.labelSmall.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarraFiltros(BuildContext context, {required bool isMobile}) {
    final colors = context.tfColors;
    final filtrosAtivos = _qtdFiltrosAtivos;

    return Container(
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 8,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 250,
            height: 38,
            child: TextField(
              controller: _buscaCtrl,
              onChanged: (_) => setState(() => _paginaAtual = 0),
              decoration: InputDecoration(
                hintText: 'Buscar necessidade, atividade ou unidade...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          FilterChip(
            label: const Text('Incluir pendências anteriores'),
            selected: _incluirPendenciasAnteriores,
            onSelected: (v) => setState(() {
              _incluirPendenciasAnteriores = v;
              _paginaAtual = 0;
            }),
          ),
          TFButton(
            label: filtrosAtivos > 0
                ? 'Filtros ($filtrosAtivos)'
                : 'Filtros avançados',
            leadingIcon: Icons.tune,
            variant: TFButtonVariant.secondary,
            size: TFButtonSize.small,
            onPressed: _abrirFiltrosAvancados,
          ),
          if (filtrosAtivos > 0)
            TextButton.icon(
              onPressed: _limparFiltros,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Limpar'),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkspace(
    BuildContext context, {
    required List<TaskApoioSolicitacao> itensPagina,
    required int totalItens,
    required int paginaAtual,
    required int totalPaginas,
    required TaskApoioSolicitacao? selecionada,
  }) {
    final colors = context.tfColors;
    final painelAberto = selecionada != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildTabelaOperacional(
                    context,
                    itens: itensPagina,
                    painelAberto: painelAberto,
                    selecionadaId: selecionada?.id,
                  ),
                ),
              ),
              _buildPaginacao(
                context,
                totalItens: totalItens,
                paginaAtual: paginaAtual,
                totalPaginas: totalPaginas,
              ),
            ],
          ),
        ),
        if (painelAberto) ...[
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _larguraPainelLateral =
                      (_larguraPainelLateral - details.delta.dx)
                          .clamp(340.0, 560.0);
                });
              },
              child: Container(
                width: 6,
                color: colors.borderSubtle.withValues(alpha: 0.4),
              ),
            ),
          ),
          SizedBox(
            width: _larguraPainelLateral,
            child: Builder(
              builder: (_) {
                final (principal, secundarias) =
                    _construirAcoesContextuais(selecionada);
                return TaskApoioDetailPanel(
                  controller: widget.controller,
                  solicitacao: selecionada,
                  situacao: _situacoes[selecionada.id],
                  usuarioAtualId: widget.usuarioAtualId,
                  usuarioAtualNome: widget.usuarioAtualNome,
                  acaoPrincipal: principal,
                  acoesSecundarias: secundarias,
                  onFechar: () =>
                      setState(() => _solicitacaoSelecionadaId = null),
                  onAbrirAtividade: widget.onAbrirAtividade,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabelaOperacional(
    BuildContext context, {
    required List<TaskApoioSolicitacao> itens,
    required bool painelAberto,
    required String? selecionadaId,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final nomes = widget.controller.nomesUnidades;
    final tiposMap = {
      for (final t in widget.controller.tiposAtivos) t.id: t.nome,
    };

    if (itens.isEmpty) {
      return TFEmptyState(
        icon: Icons.handshake_outlined,
        title: 'Nenhuma solicitação encontrada',
        description: _qtdFiltrosAtivos > 0
            ? 'Nenhuma solicitação corresponde aos filtros e período selecionados.'
            : 'Nenhuma solicitação registrada para esta visão no período selecionado.',
        action: _qtdFiltrosAtivos > 0
            ? TFButton(
                label: 'Limpar filtros',
                variant: TFButtonVariant.secondary,
                onPressed: _limparFiltros,
              )
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final modoCompleto =
            !painelAberto && constraints.maxWidth >= 1340;
        final larguraUtil = (constraints.maxWidth - 32).clamp(640.0, 2400.0);

        // Distribui a largura excedente entre as colunas para evitar espaço vazio
        // à direita e truncamento prematuro de textos e badges.
        final double wSolicitacao;
        final double wAtividade;
        final double wSolicitante;
        final double wPrestadora;
        final double wPeriodo;
        final double wCriticidade;
        final double wSituacao;
        final double wAcoes;

        if (modoCompleto) {
          const baseCompleto = 230 + 200 + 165 + 175 + 130 + 110 + 215 + 160;
          final extra = (larguraUtil - baseCompleto).clamp(0.0, 900.0);
          wSolicitacao = 230 + extra * 0.25;
          wAtividade = 200 + extra * 0.25;
          wSolicitante = 165 + extra * 0.14;
          wPrestadora = 175 + extra * 0.14;
          wPeriodo = 130 + extra * 0.07;
          wCriticidade = 110;
          wSituacao = 215 + extra * 0.15;
          wAcoes = 160;
        } else {
          final baseSol = painelAberto ? 200.0 : 220.0;
          final basePres = painelAberto ? 185.0 : 230.0;
          const basePer = 145.0;
          const baseSit = 235.0;
          const baseAcoes = 155.0;
          final baseCompacto =
              baseSol + basePres + basePer + baseSit + baseAcoes;
          final extra = (larguraUtil - baseCompacto).clamp(0.0, 900.0);
          wSolicitacao = baseSol + extra * 0.28;
          wAtividade = 0;
          wSolicitante = 0;
          wPrestadora = basePres + extra * 0.30;
          wPeriodo = basePer + extra * 0.14;
          wCriticidade = 0;
          wSituacao = baseSit + extra * 0.28;
          wAcoes = baseAcoes;
        }

        String resolverLocal(TaskApoioSolicitacao s) {
          final formatado = TaskApoioFormatters.formatarLocaisAtendimento(
            s.locaisAtendimento,
          );
          if (formatado.isNotEmpty) return formatado;
          if (s.taskSolicitanteId != null) {
            final t = widget.controller.tasksConhecidas[s.taskSolicitanteId!];
            if (t != null && t.locais.isNotEmpty) {
              return t.locais.where((l) => l.trim().isNotEmpty).join(', ');
            }
          }
          return '';
        }

        final colunas = <TFDataColumn<TaskApoioSolicitacao>>[
          TFDataColumn.text(
            id: 'solicitacao',
            title: 'Solicitação',
            width: wSolicitacao,
            cellBuilder: (ctx, s) {
              final tipoNome = tiposMap[s.tipoApoioId] ?? 'Apoio operacional';
              final localTxt = resolverLocal(s);
              final subtitulo = (!modoCompleto && localTxt.isNotEmpty)
                  ? '$tipoNome • Local: $localTxt'
                  : tipoNome;
              return Tooltip(
                message: [
                  s.descricao,
                  if (s.taskSolicitanteTituloSnapshot.isNotEmpty)
                    'Atividade: ${s.taskSolicitanteTituloSnapshot}',
                  if (localTxt.isNotEmpty) 'Local: $localTxt',
                ].join('\n'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.descricao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: s.id == selecionadaId
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (modoCompleto)
            TFDataColumn.text(
              id: 'atividade',
              title: 'Atividade relacionada',
              width: wAtividade,
              cellBuilder: (ctx, s) {
                final titulo = s.taskSolicitanteTituloSnapshot.isNotEmpty
                    ? s.taskSolicitanteTituloSnapshot
                    : 'Não vinculada';
                final localTxt = resolverLocal(s);
                return Tooltip(
                  message: localTxt.isNotEmpty
                      ? '$titulo\nLocal: $localTxt'
                      : titulo,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodySmall.copyWith(color: colors.textPrimary),
                      ),
                      if (localTxt.isNotEmpty)
                        Text(
                          'Local: $localTxt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.labelSmall.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (modoCompleto)
            TFDataColumn.text(
              id: 'solicitante',
              title: 'Solicitante',
              width: wSolicitante,
              cellBuilder: (ctx, s) {
                final txt = TaskApoioFormatters.formatarUnidade(
                  regionalId: s.regionalSolicitanteId,
                  divisaoId: s.divisaoSolicitanteId,
                  segmentoId: s.segmentoSolicitanteId,
                  nomesUnidades: nomes,
                  omitirRegional: widget.regionalAtualId != null &&
                      s.regionalSolicitanteId == widget.regionalAtualId,
                );
                return Tooltip(
                  message: txt,
                  child: Text(
                    txt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                );
              },
            ),
          TFDataColumn.text(
            id: 'prestadora',
            title: modoCompleto ? 'Prestadora' : 'Unidades',
            width: wPrestadora,
            cellBuilder: (ctx, s) {
              final dest = TaskApoioFormatters.formatarUnidade(
                regionalId: s.regionalDestinoId,
                divisaoId: s.divisaoDestinoId,
                segmentoId: s.segmentoDestinoId,
                nomesUnidades: nomes,
                omitirRegional: widget.regionalAtualId != null &&
                    s.regionalDestinoId == widget.regionalAtualId,
              );
              if (modoCompleto) {
                return Tooltip(
                  message: dest,
                  child: Text(
                    dest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.bodySmall.copyWith(color: colors.textPrimary),
                  ),
                );
              }
              final orig = TaskApoioFormatters.formatarUnidade(
                regionalId: s.regionalSolicitanteId,
                divisaoId: s.divisaoSolicitanteId,
                segmentoId: s.segmentoSolicitanteId,
                nomesUnidades: nomes,
                omitirRegional: widget.regionalAtualId != null &&
                    s.regionalSolicitanteId == widget.regionalAtualId,
              );
              return Tooltip(
                message: 'De: $orig\nPara: $dest',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'De: $orig',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Para: $dest',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              );
            },
          ),
          TFDataColumn.text(
            id: 'periodo',
            title: 'Período necessário',
            width: wPeriodo,
            cellBuilder: (ctx, s) {
              final periodoTxt = TaskApoioFormatters.formatarPeriodoHumano(
                TaskApoioFormatters.inicioVigente(s),
                TaskApoioFormatters.fimVigente(s),
              );
              if (modoCompleto) {
                return Text(
                  periodoTxt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodySmall.copyWith(color: colors.textPrimary),
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    periodoTxt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.bodySmall.copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    s.criticidade.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.labelSmall.copyWith(
                      color: s.criticidade == TaskApoioCriticidade.essencial
                          ? colors.warning
                          : colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
          if (modoCompleto)
            TFDataColumn.text(
              id: 'criticidade',
              title: 'Criticidade',
              width: wCriticidade,
              cellBuilder: (ctx, s) => Text(
                s.criticidade.label,
                style: typo.labelSmall.copyWith(
                  color: s.criticidade == TaskApoioCriticidade.essencial
                      ? colors.warning
                      : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TFDataColumn.text(
            id: 'situacao',
            title: 'Situação',
            width: wSituacao,
            cellBuilder: (ctx, s) {
              final sit = _situacoes[s.id];
              final info = sit != null
                  ? TaskApoioStatusMapper.paraSituacaoOperacional(
                      sit.situacaoOperacional,
                    )
                  : TaskApoioStatusMapper.paraStatusNegociacao(s.status);
              return Tooltip(
                message: info.label,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TFStatusBadge(
                    label: info.label,
                    severity: info.severity,
                    icon: info.icon,
                    compact: true,
                  ),
                ),
              );
            },
          ),
          TFDataColumn.text(
            id: 'acoes',
            title: 'Ações',
            width: wAcoes,
            cellBuilder: (ctx, s) {
              final (principal, secundarias) = _construirAcoesContextuais(s);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (principal != null)
                    Flexible(
                      child: TextButton(
                        onPressed: principal.onPressed,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(
                          principal.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (secundarias.isNotEmpty)
                    PopupMenuButton<int>(
                      tooltip: 'Mais ações',
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (idx) => secundarias[idx].onPressed(),
                      itemBuilder: (_) => [
                        for (var i = 0; i < secundarias.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                Icon(
                                  secundarias[i].icon,
                                  size: 16,
                                  color: secundarias[i].isDestructive
                                      ? colors.danger
                                      : colors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  secundarias[i].label,
                                  style: TextStyle(
                                    color: secundarias[i].isDestructive
                                        ? colors.danger
                                        : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ];

        return TFDataTable<TaskApoioSolicitacao>(
          columns: colunas,
          items: itens,
          zebra: true,
          densityMode: TFDensityMode.compact,
          onRowTap: (s) => setState(() => _solicitacaoSelecionadaId = s.id),
        );
      },
    );
  }

  Widget _buildMobileList(
    BuildContext context, {
    required List<TaskApoioSolicitacao> itensPagina,
    required int totalItens,
    required int paginaAtual,
    required int totalPaginas,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final nomes = widget.controller.nomesUnidades;

    if (itensPagina.isEmpty) {
      return TFEmptyState(
        icon: Icons.handshake_outlined,
        title: 'Nenhuma solicitação encontrada',
        description: 'Ajuste o período ou filtros para visualizar registros.',
        action: _qtdFiltrosAtivos > 0
            ? TFButton(
                label: 'Limpar filtros',
                variant: TFButtonVariant.secondary,
                onPressed: _limparFiltros,
              )
            : null,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: itensPagina.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final s = itensPagina[i];
              final sit = _situacoes[s.id];
              final info = sit != null
                  ? TaskApoioStatusMapper.paraSituacaoOperacional(
                      sit.situacaoOperacional,
                    )
                  : TaskApoioStatusMapper.paraStatusNegociacao(s.status);
              final (principal, secundarias) = _construirAcoesContextuais(s);
              final orig = TaskApoioFormatters.formatarUnidade(
                divisaoId: s.divisaoSolicitanteId,
                nomesUnidades: nomes,
              );
              final dest = TaskApoioFormatters.formatarUnidade(
                divisaoId: s.divisaoDestinoId,
                segmentoId: s.segmentoDestinoId,
                nomesUnidades: nomes,
              );

              return TFCard(
                onTap: () => _abrirDetalhes(s),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            s.descricao,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typo.cardTitle.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: TFStatusBadge(
                              label: info.label,
                              severity: info.severity,
                              compact: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$orig -> $dest',
                      style: typo.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Período: ${TaskApoioFormatters.formatarPeriodoHumano(TaskApoioFormatters.inicioVigente(s), TaskApoioFormatters.fimVigente(s))} • ${s.criticidade.label}',
                      style: typo.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (principal != null)
                          TFButton(
                            label: principal.label,
                            leadingIcon: principal.icon,
                            variant: TFButtonVariant.secondary,
                            size: TFButtonSize.small,
                            onPressed: principal.onPressed,
                          ),
                        const Spacer(),
                        if (secundarias.isNotEmpty)
                          PopupMenuButton<int>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (idx) => secundarias[idx].onPressed(),
                            itemBuilder: (_) => [
                              for (var j = 0; j < secundarias.length; j++)
                                PopupMenuItem<int>(
                                  value: j,
                                  child: Text(secundarias[j].label),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildPaginacao(
          context,
          totalItens: totalItens,
          paginaAtual: paginaAtual,
          totalPaginas: totalPaginas,
        ),
      ],
    );
  }

  Widget _buildPaginacao(
    BuildContext context, {
    required int totalItens,
    required int paginaAtual,
    required int totalPaginas,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalItens registro(s) • Pág. ${paginaAtual + 1}/$totalPaginas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.labelSmall.copyWith(color: colors.textSecondary),
            ),
          ),
          if (MediaQuery.of(context).size.width >= 520) ...[
            const SizedBox(width: 8),
            DropdownButton<CentralApoiosOrdenacao>(
              value: _ordenacao,
              underline: const SizedBox.shrink(),
              style: typo.labelSmall.copyWith(color: colors.textPrimary),
              items: CentralApoiosOrdenacao.values
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text('Ordenar: ${o.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _ordenacao = v);
              },
            ),
          ],
          const SizedBox(width: 4),
          TFIconButton(
            icon: Icons.chevron_left,
            tooltip: 'Página anterior',
            onPressed: paginaAtual > 0
                ? () => setState(() => _paginaAtual = paginaAtual - 1)
                : null,
          ),
          TFIconButton(
            icon: Icons.chevron_right,
            tooltip: 'Próxima página',
            onPressed: paginaAtual + 1 < totalPaginas
                ? () => setState(() => _paginaAtual = paginaAtual + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
