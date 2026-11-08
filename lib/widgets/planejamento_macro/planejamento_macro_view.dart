import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/backlog_macro_models.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_grupo.dart';
import '../../services/carteira_service.dart';
import '../../services/nota_sap_backlog_service.dart';
import '../../services/nota_sap_service.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../models/capacidade_operacional_models.dart';
import '../../services/auth_service_simples.dart';
import '../../services/capacidade_service.dart';
import 'capacidade_balanceamento_panel.dart';
import '../nota_analise_workspace.dart';
import '../task_form_dialog.dart';
import '../previsao_dialog.dart';

/// Tela Gerencial de Planejamento Macro de Notas SAP agrupadas.
class PlanejamentoMacroView extends StatefulWidget {
  final NotaSapBacklogService? backlogService;
  final NotaSapService? notaSapService;
  final TaskService? taskService;
  final CarteiraService? carteiraService;
  final CapacidadeService? capacidadeService;
  final Function(String filtroTipo, {String? valor})? onDrillDown;

  const PlanejamentoMacroView({
    super.key,
    this.backlogService,
    this.notaSapService,
    this.taskService,
    this.carteiraService,
    this.capacidadeService,
    this.onDrillDown,
  });

  @override
  State<PlanejamentoMacroView> createState() => _PlanejamentoMacroViewState();
}

class _PlanejamentoMacroViewState extends State<PlanejamentoMacroView>
    with AutomaticKeepAliveClientMixin {
  late final NotaSapBacklogService _backlogService;
  late final CarteiraService _carteiraService;
  late final CapacidadeService _capacidadeService;
  NotaSapService? _notaSapService;
  NotaSapService get _resolvedNotaSapService => _notaSapService ??= widget.notaSapService ?? NotaSapService();
  TaskService? _taskService;
  TaskService get _resolvedTaskService => _taskService ??= widget.taskService ?? TaskService();

  bool _carregando = true;
  String? _erro;
  BacklogMacroResult? _resultado;
  CarteiraResult? _carteiraResult;

  // Capacidade Operacional e Balanceamento Mensal
  ConfiguracaoCapacidade _configCapacidade = const ConfiguracaoCapacidade();
  final Map<String, BalanceamentoCapacidadeMes> _balancosCapacidade = {};
  final Map<String, List<CapacidadeExecutorMes>> _executoresPorMes = {};
  final Set<String> _mesesComCapacidadeExpandida = {};
  final Set<String> _carregandoCapacidadeMeses = {};
  final Set<String> _falhasCapacidadeMeses = {};
  bool _secaoCapacidadeAberta = false;

  // Filtros ativos
  BacklogFiltro _filtro = const BacklogFiltro();
  final TextEditingController _buscaController = TextEditingController();

  // Mês selecionado no carrossel de navegação (null = "Todos", -1 = "Sem previsão", -2 = "Atrasados")
  int? _mesFiltroNav;
  int? _anoFiltroNav;
  String _abaNavegacaoAtiva = 'todos'; // 'todos', 'atrasados', 'mes_ano', 'sem_previsao'

  // Filtro rápido ativado ao clicar nos cards gerenciais (ex: 'programadas', 'nao_programadas', 'vencidas_risco', 'sem_estimativa', 'regular', etc.)
  String? _filtroCardAtivo;

  void _alternarFiltroCard(String? filtro) {
    setState(() {
      if (_filtroCardAtivo == filtro || filtro == null) {
        _filtroCardAtivo = null;
      } else {
        _filtroCardAtivo = filtro;
      }
    });
  }

  String _descreverFiltro(String filtro) {
    switch (filtro) {
      case 'programadas':
        return 'Programadas';
      case 'nao_programadas':
        return 'Ainda Não Programadas';
      case 'vencidas_risco':
        return 'Vencidas / Em Risco';
      case 'sem_estimativa':
        return 'Sem Estimativa';
      case 'regular':
        return 'Situação Regular';
      case 'vencidas':
        return 'Vencidas';
      case 'urgentes':
        return 'Prazo Urgente';
      case 'sem_programacao':
        return 'Sem Programação';
      case 'com_previsao':
        return 'Com Previsão';
      default:
        return filtro;
    }
  }

  bool _notaAtendeFiltroCard(BacklogNotaItem n, {int? mes, int? ano}) {
    if (_filtroCardAtivo == null) return true;
    switch (_filtroCardAtivo) {
      case 'programadas':
        return n.isProgramada;
      case 'nao_programadas':
        return !n.isProgramada;
      case 'vencidas_risco':
        final isVenc = n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
        final isUrg = n.prioridade != null &&
            (n.prioridade!.toLowerCase().contains('urg') || n.prioridade!.toLowerCase().contains('alt'));
        final div = n.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
        final isApos = div == DivergenciaPrevisaoTask.aposPrevisao;
        return isVenc || isUrg || isApos;
      case 'sem_estimativa':
        return n.estimativaHoras == null || n.estimativaHoras! <= 0;
      case 'regular':
        final isVenc = n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
        final isUrg = n.prioridade != null &&
            (n.prioridade!.toLowerCase().contains('urg') || n.prioridade!.toLowerCase().contains('alt'));
        final div = n.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
        final isApos = div == DivergenciaPrevisaoTask.aposPrevisao;
        return n.isProgramada && !isVenc && !isUrg && !isApos;
      case 'com_previsao':
        return n.mesPrevisto != null && n.anoPrevisto != null;
      case 'vencidas':
        return n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
      case 'urgentes':
        if (n.dataFimDesejada == null) return false;
        final diff = n.dataFimDesejada!.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 15;
      case 'sem_programacao':
        return !n.isProgramada;
      default:
        return true;
    }
  }

  /// Ordenação visual das demandas por necessidade de ação gerencial (Regra 11)
  int _grauNecessidadeAcao(BacklogNotaItem nota, int? mesRef, int? anoRef) {
    final isVencida = nota.dataFimDesejada != null && nota.dataFimDesejada!.isBefore(DateTime.now());
    final task = nota.taskProgramacaoAtual;
    final isConcluida = task != null && task.status.toUpperCase() == 'CONC';
    final isProgramada = nota.isProgramada;
    final mes = nota.mesPrevisto ?? mesRef;
    final ano = nota.anoPrevisto ?? anoRef;
    final div = nota.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
    final semEstimativa = nota.estimativaHoras == null || nota.estimativaHoras! <= 0;

    if (isVencida) return 1; // 1. Vencida / risco crítico
    if (!isProgramada && mes != null) return 2; // 2. Prevista e não programada
    if (isProgramada &&
        (div == DivergenciaPrevisaoTask.aposPrevisao ||
            div == DivergenciaPrevisaoTask.antecipada ||
            div == DivergenciaPrevisaoTask.programadaSemPrevisaoMacro)) {
      return 3; // 3. Programada fora da previsão
    }
    if (semEstimativa && !isConcluida) return 4; // 4. Sem estimativa
    if (isProgramada && div == DivergenciaPrevisaoTask.conformePrevisao && !isConcluida) return 5; // 5. Conforme previsão
    if (isConcluida) return 6; // 6. Concluída
    return 7;
  }

  String _formatarNomeMesCompleto(int mes, int ano) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final nomeMes = (mes >= 1 && mes <= 12) ? meses[mes - 1] : 'Mês $mes';
    return '$nomeMes de $ano';
  }

  @override
  void initState() {
    super.initState();
    _backlogService = widget.backlogService ?? NotaSapBacklogService();
    _carteiraService = widget.carteiraService ?? CarteiraService();
    _capacidadeService = widget.capacidadeService ?? CapacidadeService();
    if (widget.notaSapService != null) {
      _notaSapService = widget.notaSapService;
    }
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados({bool forcar = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (widget.backlogService != null && widget.carteiraService == null) {
        final res = await _backlogService.buscarBacklogMacro(
          filtro: _filtro,
          forcarAtualizacao: forcar,
        );
        if (mounted) {
          setState(() {
            _resultado = res;
            _carregando = false;
          });
        }
      } else {
        // Fluxo unificado da Carteira Gerencial (100% dados reais do banco)
        final res = await _carteiraService.carregarCarteira(
          filtro: _filtro,
          forcarAtualizacao: forcar,
        );
        if (mounted) {
          setState(() {
            _carteiraResult = res;
            _resultado = res.backlogMacro;
            _carregando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar o Planejamento Macro.\n${e.toString()}';
          _carregando = false;
        });
      }
    }
  }

  void _aplicarFiltroNav(String aba, {int? mes, int? ano}) {
    setState(() {
      _abaNavegacaoAtiva = aba;
      _mesFiltroNav = mes;
      _anoFiltroNav = ano;
      _filtroCardAtivo = null;

      if (aba == 'todos') {
        _filtro = _filtro.copyWith(
          clearAnoMes: true,
          apenasUltrapassados: false,
          apenasSemPrevisao: false,
        );
      } else if (aba == 'atrasados') {
        _filtro = _filtro.copyWith(
          clearAnoMes: true,
          apenasUltrapassados: true,
          apenasSemPrevisao: false,
        );
      } else if (aba == 'sem_previsao') {
        _filtro = _filtro.copyWith(
          clearAnoMes: true,
          apenasUltrapassados: false,
          apenasSemPrevisao: true,
        );
      } else if (aba == 'mes_ano') {
        _filtro = _filtro.copyWith(
          ano: ano,
          mes: mes,
          apenasUltrapassados: false,
          apenasSemPrevisao: false,
        );
      }
    });

    if (aba == 'mes_ano' && mes != null && ano != null) {
      if (widget.carteiraService != null || widget.backlogService == null) {
        _mesesComCapacidadeExpandida.add('${ano}_$mes');
        _carregarCapacidadeParaMes(ano, mes);
      }
    }

    _carregarDados(forcar: false);
  }

  Future<void> _carregarCapacidadeParaMes(int ano, int mes, {bool forcar = false}) async {
    if (widget.backlogService != null && widget.carteiraService == null) {
      return;
    }
    final chave = '${ano}_$mes';
    if (!forcar && _balancosCapacidade.containsKey(chave)) return;
    if (_carregandoCapacidadeMeses.contains(chave)) return;

    _carregandoCapacidadeMeses.add(chave);
    _falhasCapacidadeMeses.remove(chave);

    try {
      final cal = _capacidadeService.calcularCalendarioMes(ano: ano, mes: mes);
      final results = await Future.wait([
        _capacidadeService.executorService.getAllExecutores(),
        _capacidadeService.equipeService.getAllEquipes(),
        _capacidadeService.taskService.getTasksForRange(
          startDate: DateTime(ano, mes, 1),
          endDate: DateTime(ano, mes + 1, 0),
          aplicarPerfil: true,
        ),
      ]);
      final todosExec = results[0] as dynamic;
      var todasEq = results[1] as dynamic;
      final tarefas = results[2] as dynamic;

      final usuario = AuthServiceSimples().currentUser;
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        todasEq = (todasEq as List).where((eq) {
          final regOk = usuario.regionalIds.isEmpty ||
              (eq.regionalId != null && usuario.regionalIds.contains(eq.regionalId));
          final divOk = usuario.divisaoIds.isEmpty ||
              (eq.divisaoId != null && usuario.divisaoIds.contains(eq.divisaoId));
          final segOk = usuario.segmentoIds.isEmpty ||
              (eq.segmentoId != null && usuario.segmentoIds.contains(eq.segmentoId));
          return regOk && divOk && segOk;
        }).toList();
      }

      var caps = _capacidadeService.calcularCapacidadeExecutoresMes(
        ano: ano,
        mes: mes,
        executores: todosExec,
        equipes: List.from(todasEq),
        tarefasDoPeriodo: tarefas,
        calendario: cal,
        config: _configCapacidade,
      );

      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        caps = caps.where((c) {
          final regOk = usuario.regionalIds.isEmpty ||
              (c.regionalId != null && usuario.regionalIds.contains(c.regionalId));
          final divOk = usuario.divisaoIds.isEmpty ||
              (c.divisaoId != null && usuario.divisaoIds.contains(c.divisaoId));
          final segOk = usuario.segmentoIds.isEmpty ||
              (c.segmentoId != null && usuario.segmentoIds.contains(c.segmentoId)) ||
              c.segmentoIds.any((s) => usuario.segmentoIds.contains(s));
          return regOk && divOk && segOk;
        }).toList();
      }
      if (_filtro.regionalId != null && _filtro.regionalId!.isNotEmpty) {
        caps = caps.where((c) => c.regionalId == _filtro.regionalId).toList();
      }
      if (_filtro.divisaoId != null && _filtro.divisaoId!.isNotEmpty) {
        caps = caps.where((c) => c.divisaoId == _filtro.divisaoId).toList();
      }

      final notasDoMes = <BacklogNotaItem>[];
      if (_carteiraResult != null) {
        for (final g in _carteiraResult!.backlogMacro.todosGrupos) {
          if (g.anoProgramacaoPrevisto == ano && g.mesProgramacaoPrevisto == mes) {
            notasDoMes.addAll(g.notas);
          }
        }
      }

      final dem = _capacidadeService.consolidarDemandaCarteiraMes(
        ano: ano,
        mes: mes,
        notasPrevistasNoMes: notasDoMes,
        config: _configCapacidade,
      );

      final bal = _capacidadeService.calcularBalanceamentoMensal(
        ano: ano,
        mes: mes,
        capacidadesExecutores: caps,
        demanda: dem,
        calendario: cal,
        config: _configCapacidade,
      );

      if (mounted) {
        setState(() {
          _balancosCapacidade[chave] = bal;
          _executoresPorMes[chave] = caps;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _falhasCapacidadeMeses.add(chave);
          _mesesComCapacidadeExpandida.remove(chave);
        });
      }
    } finally {
      _carregandoCapacidadeMeses.remove(chave);
    }
  }

  void _exibirDialogConfigCapacidade() {
    double jornada = _configCapacidade.jornadaDiariaHoras;
    double eficiencia = _configCapacidade.fatorEficiencia;
    bool semEquipe = _configCapacidade.incluirExecutoresSemEquipe;
    double limiteConfiabilidade = _configCapacidade.limiteConfiabilidadeMinimo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.tune, color: Colors.blue),
                SizedBox(width: 8),
                Text('Parâmetros de Capacidade', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jornada Diária Padrão: ${jornada.toStringAsFixed(1)} horas',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Slider(
                    value: jornada,
                    min: 6.0,
                    max: 10.0,
                    divisions: 8,
                    label: '${jornada.toStringAsFixed(1)}h',
                    onChanged: (v) => setDlgState(() => jornada = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Fator de Eficiência: ${(eficiencia * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Slider(
                    value: eficiencia,
                    min: 0.60,
                    max: 1.00,
                    divisions: 8,
                    label: '${(eficiencia * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => setDlgState(() => eficiencia = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Limite Mínimo de Confiabilidade: ${(limiteConfiabilidade * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Slider(
                    value: limiteConfiabilidade,
                    min: 0.50,
                    max: 0.95,
                    divisions: 9,
                    label: '${(limiteConfiabilidade * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => setDlgState(() => limiteConfiabilidade = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir Executores Sem Equipe Vinculada', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Quadro geral da unidade (simulação de técnicos avulsos)', style: TextStyle(fontSize: 11)),
                    value: semEquipe,
                    onChanged: (v) => setDlgState(() => semEquipe = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _configCapacidade = _configCapacidade.copyWith(
                      jornadaDiariaHoras: jornada,
                      fatorEficiencia: eficiencia,
                      incluirExecutoresSemEquipe: semEquipe,
                      limiteConfiabilidadeMinimo: limiteConfiabilidade,
                    );
                    _balancosCapacidade.clear();
                    _executoresPorMes.clear();
                  });
                  Navigator.of(ctx).pop();
                  if (_mesFiltroNav != null && _anoFiltroNav != null) {
                    _carregarCapacidadeParaMes(_anoFiltroNav!, _mesFiltroNav!, forcar: true);
                  }
                },
                child: const Text('Salvar Parâmetros'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final ext = theme.extension<TaskFlowThemeExtension>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: ext?.colors.background ?? theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Cabeçalho Oficial
          _buildHeader(context, ext, isDesktop),

          // 2. Barra de Navegação Temporal / Meses
          if (!_carregando && _resultado != null)
            _buildNavegacaoTemporal(context, ext),

          // 3. Conteúdo Principal (KPIs + Lista de Meses e Grupos)
          Expanded(
            child: _buildCorpo(context, ext, isDesktop),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. CABEÇALHO
  // ===========================================================================
  Widget _buildHeader(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: ext?.colors.borderSubtle ?? Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (ext?.colors.primary ?? Theme.of(context).primaryColor).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: ext?.colors.primary ?? Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Planejamento Macro',
                  style: (ext?.typography.pageTitle ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Grupos de Notas SAP organizados por previsão de programação mensal.',
                  style: (ext?.typography.bodySmall ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
                    color: ext?.colors.textSecondary ?? Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Campo de busca rápida
          if (isDesktop)
            SizedBox(
              width: 240,
              height: 38,
              child: TextField(
                controller: _buscaController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar grupo ou nota...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _buscaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _buscaController.clear();
                            _filtro = _filtro.copyWith(buscaTexto: '');
                            _carregarDados();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
                  ),
                ),
                onSubmitted: (val) {
                  _filtro = _filtro.copyWith(buscaTexto: val);
                  _carregarDados();
                },
              ),
            ),
          const SizedBox(width: 8),
          // Botão Parâmetros de Capacidade
          IconButton(
            tooltip: 'Parâmetros de Capacidade & Balanceamento',
            icon: const Icon(Icons.tune_outlined, size: 20),
            onPressed: _exibirDialogConfigCapacidade,
          ),
          const SizedBox(width: 4),
          // Botão Atualizar
          IconButton(
            tooltip: 'Atualizar dados (ignora cache)',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _carregarDados(forcar: true),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. NAVEGAÇÃO TEMPORAL
  // ===========================================================================
  Widget _buildNavegacaoTemporal(BuildContext context, TaskFlowThemeExtension? ext) {
    if (_resultado == null) return const SizedBox.shrink();

    final listaTabs = <Widget>[
      _buildTabItem(
        label: 'Todos',
        count: _resultado!.global.gruposAtivos,
        ativo: _abaNavegacaoAtiva == 'todos',
        onTap: () => _aplicarFiltroNav('todos'),
      ),
    ];

    if (_resultado!.global.gruposUltrapassados > 0) {
      listaTabs.add(
        _buildTabItem(
          label: 'Atrasados',
          count: _resultado!.global.gruposUltrapassados,
          ativo: _abaNavegacaoAtiva == 'atrasados',
          isAtrasado: true,
          onTap: () => _aplicarFiltroNav('atrasados'),
        ),
      );
    }

    for (final m in _resultado!.meses) {
      final isAtivo = _abaNavegacaoAtiva == 'mes_ano' && _mesFiltroNav == m.mes && _anoFiltroNav == m.ano;
      listaTabs.add(
        _buildTabItem(
          label: m.labelCompacto,
          count: m.totalGrupos,
          ativo: isAtivo,
          onTap: () => _aplicarFiltroNav('mes_ano', mes: m.mes, ano: m.ano),
        ),
      );
    }

    if (_resultado!.semPrevisao != null && _resultado!.semPrevisao!.totalGrupos > 0) {
      listaTabs.add(
        _buildTabItem(
          label: 'Sem previsão',
          count: _resultado!.semPrevisao!.totalGrupos,
          ativo: _abaNavegacaoAtiva == 'sem_previsao',
          onTap: () => _aplicarFiltroNav('sem_previsao'),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: ext?.colors.borderSubtle ?? Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: listaTabs,
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required int count,
    required bool ativo,
    bool isAtrasado = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<TaskFlowThemeExtension>();

    final primaryColor = isAtrasado
        ? (ext?.colors.danger ?? Colors.red.shade700)
        : (ext?.colors.primary ?? theme.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: ativo ? primaryColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ativo ? primaryColor : (ext?.colors.borderSubtle ?? Colors.grey.shade300),
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
                  color: ativo ? primaryColor : (ext?.colors.textPrimary ?? Colors.black87),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ativo ? primaryColor : (ext?.colors.surfaceSecondary ?? Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ativo ? Colors.white : (ext?.colors.textSecondary ?? Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. CORPO (KPIS + CONTEÚDO)
  // ===========================================================================
  Widget _buildCorpo(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando Planejamento Macro de Notas...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: ext?.colors.danger ?? Colors.red),
              const SizedBox(height: 16),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _carregarDados(forcar: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultado == null || _resultado!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: ext?.colors.textSecondary ?? Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum grupo ativo encontrado para os filtros selecionados.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _filtro = const BacklogFiltro();
                  _buscaController.clear();
                  _abaNavegacaoAtiva = 'todos';
                });
                _carregarDados();
              },
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      );
    }

    if (_abaNavegacaoAtiva == 'sem_previsao') {
      return _buildVisaoSemPrevisao(context, ext, isDesktop);
    } else if (_abaNavegacaoAtiva == 'mes_ano' && _mesFiltroNav != null && _anoFiltroNav != null) {
      return _buildVisaoMesEspecifico(context, ext, isDesktop, _anoFiltroNav!, _mesFiltroNav!);
    } else {
      return _buildVisaoConsolidada(context, ext, isDesktop);
    }
  }

  // ===========================================================================
  // 3A. VISÃO CONSOLIDADA ("TODOS" OU "ATRASADOS")
  // ===========================================================================
  Widget _buildVisaoConsolidada(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    return ListView(
      key: const Key('planejamento_macro_scroll'),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      children: [
        // Grid de KPIs Globais da Carteira
        _buildKpisGlobais(context, ext, isDesktop),
        if (_filtroCardAtivo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtro ativo: ${_descreverFiltro(_filtroCardAtivo!)} (exibindo apenas demandas correspondentes)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _alternarFiltroCard(null),
                    mouseCursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Limpar filtro',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 14, color: Colors.blue.shade800),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Listagem de Meses e Grupos
        ..._buildListaMeses(context, ext, isDesktop),
      ],
    );
  }

  // ===========================================================================
  // 3B. VISÃO DO MÊS ESPECÍFICO (FOCO EM DECISÃO GERENCIAL)
  // ===========================================================================
  Widget _buildVisaoMesEspecifico(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    bool isDesktop,
    int ano,
    int mes,
  ) {
    // 1. Extrai o resumo do mês específico
    BacklogMensalResumo? resumoMes;
    if (_resultado != null) {
      for (final m in _resultado!.meses) {
        if (m.mes == mes && m.ano == ano) {
          resumoMes = m;
          break;
        }
      }
    }
    resumoMes ??= BacklogMensalResumo(mes: mes, ano: ano, grupos: const []);

    // 2. Coleta todas as notas previstas deste mês
    final todasNotasDoMes = <BacklogNotaItem>[];
    for (final g in resumoMes.grupos) {
      todasNotasDoMes.addAll(g.notas);
    }

    // 3. Aplicação de filtro rápido por card gerencial (se houver seleção ativa)
    List<BacklogNotaItem> notasFiltradas = todasNotasDoMes;
    if (_filtroCardAtivo != null) {
      switch (_filtroCardAtivo) {
        case 'programadas':
          notasFiltradas = todasNotasDoMes.where((n) => n.isProgramada).toList();
          break;
        case 'nao_programadas':
          notasFiltradas = todasNotasDoMes.where((n) => !n.isProgramada).toList();
          break;
        case 'vencidas_risco':
          notasFiltradas = todasNotasDoMes.where((n) {
            final isVenc = n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
            final isUrg = n.prioridade != null &&
                (n.prioridade!.toLowerCase().contains('urg') || n.prioridade!.toLowerCase().contains('alt'));
            final div = n.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
            final isApos = div == DivergenciaPrevisaoTask.aposPrevisao;
            return isVenc || isUrg || isApos;
          }).toList();
          break;
        case 'sem_estimativa':
          notasFiltradas = todasNotasDoMes.where((n) => n.estimativaHoras == null || n.estimativaHoras! <= 0).toList();
          break;
        case 'regular':
          notasFiltradas = todasNotasDoMes.where((n) {
            final isVenc = n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
            final isUrg = n.prioridade != null &&
                (n.prioridade!.toLowerCase().contains('urg') || n.prioridade!.toLowerCase().contains('alt'));
            final div = n.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
            final isApos = div == DivergenciaPrevisaoTask.aposPrevisao;
            return n.isProgramada && !isVenc && !isUrg && !isApos;
          }).toList();
          break;
      }
    }

    // 4. Ordenação visual por necessidade de ação gerencial (Regra 11)
    final notasOrdenadas = List<BacklogNotaItem>.from(notasFiltradas)
      ..sort((a, b) => _grauNecessidadeAcao(a, mes, ano).compareTo(_grauNecessidadeAcao(b, mes, ano)));

    // 5. Indicadores de 1º Nível (Decisão Gerencial - Regras 1, 3 e 7)
    final totalDemandas = todasNotasDoMes.length;
    final totalProgramadas = todasNotasDoMes.where((n) => n.isProgramada).length;
    final totalNaoProgramadas = totalDemandas - totalProgramadas;
    final totalVencidasOuRisco = todasNotasDoMes.where((n) {
      final isVenc = n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now());
      final isUrg = n.prioridade != null &&
          (n.prioridade!.toLowerCase().contains('urg') || n.prioridade!.toLowerCase().contains('alt'));
      final div = n.classificarDivergencia(mesPrevisao: mes, anoPrevisao: ano);
      final isApos = div == DivergenciaPrevisaoTask.aposPrevisao;
      return isVenc || isUrg || isApos;
    }).length;
    final totalSemEstimativa = todasNotasDoMes.where((n) => n.estimativaHoras == null || n.estimativaHoras! <= 0).length;

    // 6. Balanço de Capacidade do Mês
    final chaveCap = '${ano}_$mes';
    final bal = _balancosCapacidade[chaveCap];
    if (bal == null && !_carregandoCapacidadeMeses.contains(chaveCap)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _carregarCapacidadeParaMes(ano, mes);
      });
    }

    final nomeMesFormatado = _formatarNomeMesCompleto(mes, ano);

    return ListView(
      key: const Key('planejamento_macro_scroll'),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      children: [
        // Cabeçalho do Mês
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ext?.colors.surface ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: ext?.colors.primary ?? Theme.of(context).primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      nomeMesFormatado.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: ext?.colors.textPrimary ?? Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                            ? (ext?.colors.success ?? Colors.green.shade700).withValues(alpha: 0.12)
                            : (ext?.colors.primary ?? Colors.blue).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                              ? (ext?.colors.success ?? Colors.green.shade700)
                              : (ext?.colors.primary ?? Colors.blue),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        totalProgramadas == totalDemandas && totalDemandas > 0
                            ? 'Todas as demandas estão programadas'
                            : 'Cobertura de Programação: $totalProgramadas de $totalDemandas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                              ? (ext?.colors.success ?? Colors.green.shade700)
                              : (ext?.colors.primary ?? Colors.blue.shade800),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: ext?.colors.primary ?? Theme.of(context).primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nomeMesFormatado.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: ext?.colors.textPrimary ?? Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                            ? (ext?.colors.success ?? Colors.green.shade700).withValues(alpha: 0.12)
                            : (ext?.colors.primary ?? Colors.blue).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                              ? (ext?.colors.success ?? Colors.green.shade700)
                              : (ext?.colors.primary ?? Colors.blue),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        totalProgramadas == totalDemandas && totalDemandas > 0
                            ? 'Todas as demandas estão programadas'
                            : 'Cobertura de Programação: $totalProgramadas de $totalDemandas',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: (totalProgramadas == totalDemandas && totalDemandas > 0)
                              ? (ext?.colors.success ?? Colors.green.shade700)
                              : (ext?.colors.primary ?? Colors.blue.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),

              // Grid de Primeiro Nível (Decisão Gerencial - Regra 7)
              _buildGridKpisPrimeiroNivel(
                context: context,
                ext: ext,
                isDesktop: isDesktop,
                totalDemandas: totalDemandas,
                totalProgramadas: totalProgramadas,
                totalNaoProgramadas: totalNaoProgramadas,
                totalVencidasOuRisco: totalVencidasOuRisco,
                totalSemEstimativa: totalSemEstimativa,
                filtroCardAtivo: _filtroCardAtivo,
                onSelecionarFiltro: _alternarFiltroCard,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Mensagem Gerencial Automática (Regra 4)
        _buildMensagemGerencialAutomatica(
          context: context,
          ext: ext,
          nomeMes: nomeMesFormatado,
          totalDemandas: totalDemandas,
          totalProgramadas: totalProgramadas,
          totalNaoProgramadas: totalNaoProgramadas,
          totalEmRisco: totalVencidasOuRisco,
          totalSemEstimativa: totalSemEstimativa,
          bal: bal,
        ),
        const SizedBox(height: 14),

        // Barra de Subresumo de Ação (Regra 10)
        _buildBarraSubresumoAcao(
          context: context,
          ext: ext,
          precisaAcao: totalNaoProgramadas,
          emRisco: totalVencidasOuRisco,
          regular: (totalProgramadas - totalVencidasOuRisco).clamp(0, totalProgramadas),
          filtroCardAtivo: _filtroCardAtivo,
          onSelecionarFiltro: _alternarFiltroCard,
        ),
        const SizedBox(height: 16),

        // Bloco Recolhível de Capacidade e Carga (Regras 29 a 33 e 35)
        _buildBlocoCapacidadeRecolhivel(
          context: context,
          ext: ext,
          bal: bal,
          isDesktop: isDesktop,
          chaveCap: chaveCap,
          ano: ano,
          mes: mes,
          semEstimativa: totalSemEstimativa,
          totalDemandas: totalDemandas,
        ),
        const SizedBox(height: 16),

        // Seção Demandas do Mês (Regra 9 e 11)
        _buildSecaoDemandasDoMes(
          context: context,
          ext: ext,
          isDesktop: isDesktop,
          notas: notasOrdenadas,
          mes: mes,
          ano: ano,
          gruposDoMes: resumoMes.grupos,
          filtroAtivo: _filtroCardAtivo,
          totalDemandasMes: totalDemandas,
          onLimparFiltro: () => _alternarFiltroCard(null),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3C. VISÃO "SEM PREVISÃO" (SEM BLOCOS DE MESES NEM CAPACIDADE MENSAL)
  // ===========================================================================
  Widget _buildVisaoSemPrevisao(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    bool isDesktop,
  ) {
    final notasSemPrevisao = <BacklogNotaItem>[];
    if (_resultado?.semPrevisao != null) {
      for (final g in _resultado!.semPrevisao!.grupos) {
        notasSemPrevisao.addAll(g.notas);
      }
    }
    if (_resultado?.todosGrupos != null) {
      for (final g in _resultado!.todosGrupos) {
        if (g.mesProgramacaoPrevisto == null || g.anoProgramacaoPrevisto == null) {
          for (final n in g.notas) {
            if (!notasSemPrevisao.any((existente) => existente.id == n.id)) {
              notasSemPrevisao.add(n);
            }
          }
        }
      }
    }

    // Ordenação: Vencidas -> Sem programação -> Programadas sem previsão
    notasSemPrevisao.sort((a, b) {
      final aVenc = a.dataFimDesejada != null && a.dataFimDesejada!.isBefore(DateTime.now());
      final bVenc = b.dataFimDesejada != null && b.dataFimDesejada!.isBefore(DateTime.now());
      if (aVenc && !bVenc) return -1;
      if (!aVenc && bVenc) return 1;

      if (!a.isProgramada && b.isProgramada) return -1;
      if (a.isProgramada && !b.isProgramada) return 1;
      return a.nota.compareTo(b.nota);
    });

    final totalSemPrevisao = notasSemPrevisao.length;
    final vencidas = notasSemPrevisao.where((n) => n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now())).length;
    final prazoUrgente = notasSemPrevisao.where((n) {
      if (n.dataFimDesejada == null) return false;
      final diff = n.dataFimDesejada!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 15;
    }).length;
    final programadasSemPrevisao = notasSemPrevisao.where((n) => n.isProgramada).length;
    final semProgramacao = totalSemPrevisao - programadasSemPrevisao;

    // Filtragem rápida por card ativo na visão Sem Previsão
    List<BacklogNotaItem> notasFiltradas = notasSemPrevisao;
    if (_filtroCardAtivo != null) {
      switch (_filtroCardAtivo) {
        case 'vencidas':
          notasFiltradas = notasSemPrevisao.where((n) => n.dataFimDesejada != null && n.dataFimDesejada!.isBefore(DateTime.now())).toList();
          break;
        case 'urgentes':
          notasFiltradas = notasSemPrevisao.where((n) {
            if (n.dataFimDesejada == null) return false;
            final diff = n.dataFimDesejada!.difference(DateTime.now()).inDays;
            return diff >= 0 && diff <= 15;
          }).toList();
          break;
        case 'programadas':
          notasFiltradas = notasSemPrevisao.where((n) => n.isProgramada).toList();
          break;
        case 'sem_programacao':
          notasFiltradas = notasSemPrevisao.where((n) => !n.isProgramada).toList();
          break;
      }
    }

    return ListView(
      key: const Key('planejamento_macro_scroll'),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      children: [
        // Cabeçalho Sem Previsão (Regra 19)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ext?.colors.surface ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.amber.shade900, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SEM PREVISÃO',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        Text(
                          'Demandas que ainda não possuem horizonte gerencial de atendimento.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (_resultado?.semPrevisao != null && _resultado!.semPrevisao!.grupos.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        final gAvulso = _resultado!.semPrevisao!.grupos.firstWhere(
                          (g) => g.id.startsWith('avulsas_'),
                          orElse: () => _resultado!.semPrevisao!.grupos.first,
                        );
                        _definirPrevisaoLote(context, gAvulso);
                      },
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Definir Previsão em Lote'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ext?.colors.primary ?? Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // KPIs Específicos de Sem Previsão (Regra 20) com suporte a clique e filtragem
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCardKpiDecisao(
                    label: 'Total Sem Previsão',
                    valor: totalSemPrevisao.toString(),
                    subtitulo: 'Aguardando horizonte',
                    icon: Icons.inventory_2_outlined,
                    cor: Colors.amber.shade900,
                    selecionado: _filtroCardAtivo == null,
                    onTap: () => _alternarFiltroCard(null),
                  ),
                  _buildCardKpiDecisao(
                    label: 'Vencidas',
                    valor: vencidas.toString(),
                    subtitulo: 'Prazo limite expirado',
                    icon: Icons.error_outline,
                    cor: vencidas > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                    destaque: vencidas > 0,
                    selecionado: _filtroCardAtivo == 'vencidas',
                    onTap: () => _alternarFiltroCard('vencidas'),
                  ),
                  _buildCardKpiDecisao(
                    label: 'Prazo Urgente',
                    valor: prazoUrgente.toString(),
                    subtitulo: 'Vence em até 15 dias',
                    icon: Icons.warning_amber_rounded,
                    cor: prazoUrgente > 0 ? Colors.orange.shade800 : Colors.grey.shade600,
                    destaque: prazoUrgente > 0,
                    selecionado: _filtroCardAtivo == 'urgentes',
                    onTap: () => _alternarFiltroCard('urgentes'),
                  ),
                  _buildCardKpiDecisao(
                    label: 'Já Programadas',
                    valor: programadasSemPrevisao.toString(),
                    subtitulo: 'Programada sem previsão macro',
                    icon: Icons.bolt,
                    cor: Colors.blue.shade800,
                    selecionado: _filtroCardAtivo == 'programadas',
                    onTap: () => _alternarFiltroCard('programadas'),
                  ),
                  _buildCardKpiDecisao(
                    label: 'Sem Programação',
                    valor: semProgramacao.toString(),
                    subtitulo: 'Sem previsão e sem task',
                    icon: Icons.pending_actions,
                    cor: semProgramacao > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                    destaque: semProgramacao > 0,
                    selecionado: _filtroCardAtivo == 'sem_programacao',
                    onTap: () => _alternarFiltroCard('sem_programacao'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Demandas Sem Previsão (Regra 22: Sem blocos de meses!)
        Container(
          decoration: BoxDecoration(
            color: ext?.colors.surface ?? Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Demandas Aguardando Previsão (${notasFiltradas.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_filtroCardAtivo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt, size: 14, color: Colors.blue.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Filtro ativo: ${_descreverFiltro(_filtroCardAtivo!)} (${notasFiltradas.length} de $totalSemPrevisao demandas)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _alternarFiltroCard(null),
                            mouseCursor: SystemMouseCursors.click,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Limpar filtro',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.close, size: 14, color: Colors.blue.shade800),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 1),
              if (notasFiltradas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list_off, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          _filtroCardAtivo != null
                              ? 'Nenhuma demanda encontrada para o filtro "${_descreverFiltro(_filtroCardAtivo!)}".'
                              : 'Nenhuma demanda sem previsão encontrada.',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        if (_filtroCardAtivo != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _alternarFiltroCard(null),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Mostrar todas as demandas sem previsão'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notasFiltradas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final nota = notasFiltradas[index];
                    return _buildItemNotaCompacto(ctx, ext, nota, null, null);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // COMPONENTES DE APOIO AO NOVO FLUXO GERENCIAL
  // ===========================================================================

  Widget _buildGridKpisPrimeiroNivel({
    required BuildContext context,
    required TaskFlowThemeExtension? ext,
    required bool isDesktop,
    required int totalDemandas,
    required int totalProgramadas,
    required int totalNaoProgramadas,
    required int totalVencidasOuRisco,
    required int totalSemEstimativa,
    String? filtroCardAtivo,
    ValueChanged<String?>? onSelecionarFiltro,
  }) {
    final cards = [
      _buildCardKpiDecisao(
        label: 'Demandas Previstas',
        valor: totalDemandas.toString(),
        subtitulo: 'Total do mês',
        icon: Icons.assignment_outlined,
        cor: ext?.colors.primary ?? Theme.of(context).primaryColor,
        selecionado: filtroCardAtivo == null,
        onTap: () => onSelecionarFiltro?.call(null),
      ),
      _buildCardKpiDecisao(
        label: 'Programadas',
        valor: totalProgramadas.toString(),
        subtitulo: totalDemandas > 0
            ? '${((totalProgramadas / totalDemandas) * 100).toStringAsFixed(0)}% da carteira'
            : '0%',
        icon: Icons.task_alt,
        cor: ext?.colors.success ?? Colors.green.shade700,
        selecionado: filtroCardAtivo == 'programadas',
        onTap: () => onSelecionarFiltro?.call('programadas'),
      ),
      _buildCardKpiDecisao(
        label: 'Ainda Não Programadas',
        valor: totalNaoProgramadas.toString(),
        subtitulo: totalNaoProgramadas > 0 ? 'Requer programação' : 'Nenhuma pendente',
        icon: Icons.pending_actions,
        cor: totalNaoProgramadas > 0 ? (ext?.colors.danger ?? Colors.red.shade700) : Colors.grey.shade600,
        destaque: totalNaoProgramadas > 0,
        selecionado: filtroCardAtivo == 'nao_programadas',
        onTap: () => onSelecionarFiltro?.call('nao_programadas'),
      ),
      _buildCardKpiDecisao(
        label: 'Vencidas / Em Risco',
        valor: totalVencidasOuRisco.toString(),
        subtitulo: totalVencidasOuRisco > 0 ? 'Atraso ou prazo crítico' : 'Sem risco de prazo',
        icon: Icons.warning_amber_rounded,
        cor: totalVencidasOuRisco > 0 ? Colors.orange.shade900 : Colors.grey.shade600,
        destaque: totalVencidasOuRisco > 0,
        selecionado: filtroCardAtivo == 'vencidas_risco',
        onTap: () => onSelecionarFiltro?.call('vencidas_risco'),
      ),
      _buildCardKpiDecisao(
        label: 'Sem Estimativa',
        valor: totalSemEstimativa.toString(),
        subtitulo: totalSemEstimativa > 0 ? 'Não dimensionadas' : '100% dimensionadas',
        icon: Icons.hourglass_empty,
        cor: totalSemEstimativa > 0 ? Colors.amber.shade900 : Colors.grey.shade600,
        selecionado: filtroCardAtivo == 'sem_estimativa',
        onTap: () => onSelecionarFiltro?.call('sem_estimativa'),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c,
                  ),
                ))
            .toList(),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards
            .map((c) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: c,
                ))
            .toList(),
      );
    }
  }

  Widget _buildCardKpiDecisao({
    required String label,
    required String valor,
    required String subtitulo,
    required IconData icon,
    required Color cor,
    bool destaque = false,
    bool selecionado = false,
    VoidCallback? onTap,
  }) {
    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selecionado
            ? cor.withValues(alpha: 0.12)
            : (destaque ? cor.withValues(alpha: 0.06) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selecionado
              ? cor
              : (destaque ? cor.withValues(alpha: 0.4) : Colors.grey.shade300),
          width: selecionado ? 2.0 : (destaque ? 1.5 : 1.0),
        ),
        boxShadow: selecionado
            ? [
                BoxShadow(
                  color: cor.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
                          color: selecionado ? cor : Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selecionado) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 12, color: cor),
                    ],
                  ],
                ),
              ),
              Icon(icon, size: 16, color: cor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor),
          ),
          const SizedBox(height: 2),
          Text(
            selecionado ? 'Filtro aplicado (clique p/ alternar)' : subtitulo,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
              color: selecionado ? cor : Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          mouseCursor: SystemMouseCursors.click,
          child: container,
        ),
      );
    }

    return container;
  }

  Widget _buildMensagemGerencialAutomatica({
    required BuildContext context,
    required TaskFlowThemeExtension? ext,
    required String nomeMes,
    required int totalDemandas,
    required int totalProgramadas,
    required int totalNaoProgramadas,
    required int totalEmRisco,
    required int totalSemEstimativa,
    required BalanceamentoCapacidadeMes? bal,
  }) {
    final hasAlerta = totalNaoProgramadas > 0 || totalEmRisco > 0 || (bal != null && !bal.isSaldoConfiavel);
    final corTema = hasAlerta ? Colors.amber.shade900 : Colors.green.shade800;
    final corFundo = hasAlerta ? Colors.amber.shade50 : Colors.green.shade50;
    final corBorda = hasAlerta ? Colors.amber.shade300 : Colors.green.shade300;

    final buffer = StringBuffer();
    buffer.writeln('$totalProgramadas das $totalDemandas demandas previstas para $nomeMes já estão programadas.');

    if (totalNaoProgramadas > 0) {
      buffer.writeln('$totalNaoProgramadas demanda${totalNaoProgramadas > 1 ? 's' : ''} ainda precisa${totalNaoProgramadas > 1 ? 'm' : ''} ser programada${totalNaoProgramadas > 1 ? 's' : ''}.');
    }

    if (totalEmRisco > 0) {
      buffer.writeln('$totalEmRisco demanda${totalEmRisco > 1 ? 's' : ''} apresenta${totalEmRisco > 1 ? 'm' : ''} risco de prazo ou atraso.');
    }

    if (bal != null) {
      if (!bal.isSaldoConfiavel || totalSemEstimativa == totalDemandas) {
        buffer.writeln(
          'A capacidade disponível aparenta ser suficiente, mas não é possível confirmar folga porque '
          '${totalSemEstimativa == totalDemandas ? 'todas as' : '$totalSemEstimativa das'} $totalDemandas demandas '
          'não possuem estimativa técnica de horas.',
        );
      } else if (bal.saldoHorasCalculado < 0) {
        buffer.writeln(
          'Atenção: A demanda estimada excede a capacidade disponível no mês em '
          '${bal.saldoHorasCalculado.abs().toStringAsFixed(0)} horas.',
        );
      } else {
        buffer.writeln(
          'A capacidade disponível é suficiente para absorver a carteira prevista com saldo calculado de '
          '+${bal.saldoHorasCalculado.toStringAsFixed(0)} h.',
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: corBorda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasAlerta ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: corTema,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAlerta ? 'ATENÇÃO GERENCIAL' : 'SITUAÇÃO REGULAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: corTema,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  buffer.toString().trim(),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: hasAlerta ? Colors.brown.shade900 : Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraSubresumoAcao({
    required BuildContext context,
    required TaskFlowThemeExtension? ext,
    required int precisaAcao,
    required int emRisco,
    required int regular,
    String? filtroCardAtivo,
    ValueChanged<String?>? onSelecionarFiltro,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Situação Operacional:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ext?.colors.textSecondary ?? Colors.grey.shade700),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelecionarFiltro?.call('nao_programadas'),
              borderRadius: BorderRadius.circular(6),
              mouseCursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: filtroCardAtivo == 'nao_programadas' ? Colors.red.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: filtroCardAtivo == 'nao_programadas' ? Border.all(color: Colors.red, width: 1.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 10, color: Colors.red),
                    const SizedBox(width: 5),
                    Text(
                      'Precisa de ação: $precisaAcao',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelecionarFiltro?.call('vencidas_risco'),
              borderRadius: BorderRadius.circular(6),
              mouseCursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: filtroCardAtivo == 'vencidas_risco' ? Colors.orange.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: filtroCardAtivo == 'vencidas_risco' ? Border.all(color: Colors.orange.shade800, width: 1.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: Colors.orange.shade800),
                    const SizedBox(width: 5),
                    Text(
                      'Em risco: $emRisco',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelecionarFiltro?.call('regular'),
              borderRadius: BorderRadius.circular(6),
              mouseCursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: filtroCardAtivo == 'regular' ? Colors.green.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: filtroCardAtivo == 'regular' ? Border.all(color: Colors.green.shade700, width: 1.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: Colors.green.shade700),
                    const SizedBox(width: 5),
                    Text(
                      'Regular: $regular',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoCapacidadeRecolhivel({
    required BuildContext context,
    required TaskFlowThemeExtension? ext,
    required BalanceamentoCapacidadeMes? bal,
    required bool isDesktop,
    required String chaveCap,
    required int ano,
    required int mes,
    required int semEstimativa,
    required int totalDemandas,
  }) {
    if (bal == null) {
      return Container(
        decoration: BoxDecoration(
          color: ext?.colors.surface ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.speed, size: 20, color: ext?.colors.primary ?? Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capacidade e Carga Operacional',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _carregandoCapacidadeMeses.contains(chaveCap)
                        ? 'Calculando capacidade e balanceamento do mês...'
                        : 'Balanceamento operacional sob demanda para o período selecionado.',
                    style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (!_carregandoCapacidadeMeses.contains(chaveCap))
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Carregar', style: TextStyle(fontSize: 11)),
                onPressed: () => _carregarCapacidadeParaMes(ano, mes, forcar: true),
              ),
          ],
        ),
      );
    }

    final isNaoConfiavel = !bal.isSaldoConfiavel || bal.nivelConfiabilidade == NivelConfiabilidadeCapacidade.baixa;
    final horasDisp = bal.horasAjustadas.toStringAsFixed(0);
    final horasComp = bal.horasComprometidasProgramadas.toStringAsFixed(0);
    final horasDemanda = bal.demanda.horasEstimadasConfirmadas.toStringAsFixed(0);
    final saldo = bal.saldoHorasCalculado.toStringAsFixed(0);
    final saldoPositivo = bal.saldoHorasCalculado >= 0;

    return Container(
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
      ),
      child: ExpansionTile(
        key: Key('capacidade_recolhivel_${ano}_$mes'),
        initiallyExpanded: _secaoCapacidadeAberta,
        onExpansionChanged: (val) {
          setState(() {
            _secaoCapacidadeAberta = val;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Icon(Icons.speed, size: 20, color: isNaoConfiavel ? Colors.amber.shade900 : (ext?.colors.primary ?? Colors.blue)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Capacidade e Carga Operacional',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNaoConfiavel ? Colors.amber.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isNaoConfiavel ? Colors.amber.shade400 : Colors.green.shade400, width: 0.6),
                        ),
                        child: Text(
                          isNaoConfiavel ? '⚠ BAIXA CONFIABILIDADE' : 'CONFIABILIDADE ALTA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isNaoConfiavel ? Colors.amber.shade900 : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNaoConfiavel
                        ? '$horasDisp h aparentemente disponíveis • $horasComp h comprometidas • $semEstimativa de $totalDemandas demandas sem estimativa'
                        : '$horasDisp h disponíveis • $horasComp h comprometidas • Demanda: $horasDemanda h (Saldo: ${saldoPositivo ? '+' : ''}$saldo h)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isNaoConfiavel ? Colors.brown.shade800 : (ext?.colors.textSecondary ?? Colors.grey.shade600),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CapacidadeBalanceamentoPanel(
              balanceamento: bal,
              capacidadesExecutores: _executoresPorMes[chaveCap] ?? const [],
              notasDoMes: _carteiraResult?.backlogMacro.todosGrupos
                  .where((g) => g.anoProgramacaoPrevisto == ano && g.mesProgramacaoPrevisto == mes)
                  .expand((g) => g.notas)
                  .toList() ?? const [],
              configuracao: _configCapacidade,
              onDrillDown: widget.onDrillDown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoDemandasDoMes({
    required BuildContext context,
    required TaskFlowThemeExtension? ext,
    required bool isDesktop,
    required List<BacklogNotaItem> notas,
    required int mes,
    required int ano,
    required List<BacklogGrupoItem> gruposDoMes,
    String? filtroAtivo,
    int? totalDemandasMes,
    VoidCallback? onLimparFiltro,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_list_bulleted, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Demandas do Mês (${notas.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '• Ordenadas por necessidade de ação gerencial',
                  style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                ),
                if (gruposDoMes.any((g) => g.notasPendentes > 0))
                  ElevatedButton.icon(
                    onPressed: () {
                      final grupoComPendentes = gruposDoMes.firstWhere((g) => g.notasPendentes > 0);
                      _programarNotasPendentes(context, grupoComPendentes);
                    },
                    icon: const Icon(Icons.playlist_add, size: 14),
                    label: const Text('Programar Pendentes', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext?.colors.primary ?? Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          if (filtroAtivo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, size: 14, color: Colors.blue.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Filtro ativo: ${_descreverFiltro(filtroAtivo)} (${notas.length} de ${totalDemandasMes ?? notas.length} demandas)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLimparFiltro,
                        mouseCursor: SystemMouseCursors.click,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Limpar filtro',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.close, size: 14, color: Colors.blue.shade800),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),

          if (notas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list_off, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      filtroAtivo != null
                          ? 'Nenhuma demanda encontrada para o filtro "${_descreverFiltro(filtroAtivo)}".'
                          : 'Nenhuma demanda prevista para este mês.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    if (filtroAtivo != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onLimparFiltro,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Mostrar todas as demandas do mês'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final nota = notas[index];
                return _buildItemNotaCompacto(ctx, ext, nota, mes, ano);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildItemNotaCompacto(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    BacklogNotaItem nota,
    int? mesContexto,
    int? anoContexto,
  ) {
    final taskAtual = nota.taskProgramacaoAtual;
    final isProgramada = nota.isProgramada;
    final mesPrevisto = nota.mesPrevisto ?? mesContexto;
    final anoPrevisto = nota.anoPrevisto ?? anoContexto;
    final divergencia = nota.classificarDivergencia(mesPrevisao: mesPrevisto, anoPrevisao: anoPrevisto);
    final isConcluida = taskAtual != null && taskAtual.status.toUpperCase() == 'CONC';
    final isVencida = nota.dataFimDesejada != null && nota.dataFimDesejada!.isBefore(DateTime.now());

    final Color corSituacao;
    final IconData iconeSituacao;
    final String situacaoTexto;

    if (isConcluida) {
      corSituacao = Colors.grey.shade600;
      iconeSituacao = Icons.check_circle;
      situacaoTexto = 'Execução concluída';
    } else if (isVencida) {
      corSituacao = Colors.red.shade700;
      iconeSituacao = Icons.error;
      situacaoTexto = 'Vencida';
    } else if (!isProgramada) {
      corSituacao = Colors.red.shade700;
      iconeSituacao = Icons.fiber_manual_record;
      situacaoTexto = 'Requer programação';
    } else if (divergencia == DivergenciaPrevisaoTask.aposPrevisao) {
      corSituacao = Colors.orange.shade800;
      iconeSituacao = Icons.warning_amber_rounded;
      situacaoTexto = 'Programada após previsão';
    } else if (divergencia == DivergenciaPrevisaoTask.antecipada) {
      corSituacao = Colors.blue.shade700;
      iconeSituacao = Icons.bolt;
      situacaoTexto = 'Programada antecipadamente';
    } else if (divergencia == DivergenciaPrevisaoTask.programadaSemPrevisaoMacro) {
      corSituacao = Colors.blue.shade800;
      iconeSituacao = Icons.info_outline;
      situacaoTexto = 'Programada sem previsão macro';
    } else {
      corSituacao = Colors.green.shade700;
      iconeSituacao = Icons.check_circle_outline;
      situacaoTexto = 'Programada conforme previsão';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isVencida || (!isProgramada && !isConcluida)
              ? corSituacao.withValues(alpha: 0.35)
              : (ext?.colors.borderSubtle ?? Colors.grey.shade200),
          width: (!isProgramada && !isConcluida) || isVencida ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Linha Principal: Ícone Situação + Nota + Descrição + Estimativa
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconeSituacao, size: 16, color: corSituacao),
              const SizedBox(width: 8),
              Text(
                'Nota SAP: ${nota.nota}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nota.descricao,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ext?.colors.textPrimary ?? Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (nota.estimativaHoras != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ext?.colors.surfaceSecondary ?? Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${nota.estimativaHoras!.toStringAsFixed(1)} h',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Text(
                  'Sem estimativa',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Linha Operacional: SAP [MSPR] (e USR) | TASK [PROG]
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NOTA: ${nota.statusSistema?.trim().isNotEmpty == true ? nota.statusSistema!.trim() : 'N/D'}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              if (nota.statusUsuario?.trim().isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueGrey.shade400, width: 0.5),
                  ),
                  child: Text(
                    'USR: ${nota.statusUsuario!.trim()}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade900),
                  ),
                ),

              if (taskAtual != null && taskAtual.isValida)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: taskAtual.status.toUpperCase() == 'CONC'
                        ? Colors.green.shade800
                        : (taskAtual.status.toUpperCase() == 'ANDA' ? Colors.purple.shade800 : Colors.blue.shade800),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TASK: ${taskAtual.status}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else if (taskAtual != null && taskAtual.isCancelada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TASK: CANCELADA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200, width: 0.5),
                  ),
                  child: Text(
                    'TASK: NÃO PROGRAMADA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                  ),
                ),

              if (nota.localInstalacao != null)
                Text(
                  'Local: ${nota.localInstalacao}',
                  style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Linha Planejamento: Prazo | Previsão -> Programação | Situação
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Prazo Limite da Demanda
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVencida ? Icons.alarm_off : Icons.flag_outlined,
                    size: 13,
                    color: isVencida ? Colors.red.shade700 : Colors.blueGrey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Prazo: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: isVencida ? Colors.red.shade800 : Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    nota.dataFimDesejada != null
                        ? _formatarDataBR(nota.dataFimDesejada)
                        : 'Não informado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isVencida ? Colors.red.shade800 : (ext?.colors.textPrimary ?? Colors.black87),
                    ),
                  ),
                  if (isVencida) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.red.shade300, width: 0.5),
                      ),
                      child: Text(
                        'Vencido',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 13, color: Colors.blueGrey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Prev. ${_formatarMesAno(mesPrevisto, anoPrevisto)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  if (taskAtual != null && taskAtual.dataInicio != null)
                    Text(
                      'Prog. ${_formatarDataBR(taskAtual.dataInicio)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corSituacao),
                    )
                  else
                    Text(
                      'Sem data programada',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: corSituacao.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  situacaoTexto,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: corSituacao),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Ações
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isProgramada && taskAtual != null)
                OutlinedButton.icon(
                  onPressed: () => _abrirTarefaDeepLink(taskAtual.id),
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: const Text('Abrir Tarefa', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ext?.colors.primary ?? Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _programarNota(context, nota),
                  icon: const Icon(Icons.add_task, size: 13),
                  label: const Text('Programar', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext?.colors.primary ?? Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

              if (nota.tasks.length > 1)
                OutlinedButton.icon(
                  onPressed: () => _exibirModalMultiplasTasks(context, nota),
                  icon: const Icon(Icons.format_list_bulleted, size: 13),
                  label: Text('${nota.tasks.length} Tarefas Vinculadas', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

              OutlinedButton.icon(
                onPressed: () => _abrirDetalheNota(context, notaId: nota.id, numeroNota: nota.nota),
                icon: const Icon(Icons.visibility_outlined, size: 13),
                label: const Text('Abrir Nota', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ext?.colors.textSecondary ?? Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              Tooltip(
                message: 'Definir / Editar Previsão Macro',
                child: IconButton(
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  color: ext?.colors.textSecondary ?? Colors.grey.shade600,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _definirPrevisaoIndividual(context, nota),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Busca resiliente da NotaSAP completa, aceitando ID (UUID) e/ou Número SAP como fallback.
  Future<NotaSAP?> _obterNotaSAPCompleta({String? id, String? numero}) async {
    NotaSAP? notaCompleta;

    // 1. Tentar por ID (UUID)
    if (id != null && id.trim().isNotEmpty) {
      try {
        notaCompleta = await _resolvedNotaSapService.getNotaById(id.trim());
      } catch (_) {}
    }

    // 2. Se não encontrou, tentar por número oficial da Nota SAP
    if (notaCompleta == null && numero != null && numero.trim().isNotEmpty) {
      try {
        notaCompleta = await _resolvedNotaSapService.getNotaPorNumero(numero.trim());
      } catch (_) {}
    }

    // 3. Fallback: Se o ID fornecido na verdade for o número da nota
    if (notaCompleta == null && id != null && id.trim().isNotEmpty) {
      try {
        notaCompleta = await _resolvedNotaSapService.getNotaPorNumero(id.trim());
      } catch (_) {}
    }

    return notaCompleta;
  }

  Future<void> _abrirDetalheNota(BuildContext ctx, {String? notaId, String? numeroNota}) async {
    final notaCompleta = await _obterNotaSAPCompleta(id: notaId, numero: numeroNota);
    if (!mounted || notaCompleta == null) {
      if (mounted) {
        final idOuNumero = (numeroNota?.isNotEmpty == true ? numeroNota : notaId) ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nota $idOuNumero não encontrada no momento.')),
        );
      }
      return;
    }

    await NotaAnaliseWorkspace.abrir(
      context,
      nota: notaCompleta,
      initialTab: 0,
    );

    _carregarDados(forcar: true);
  }

  Future<void> _programarNota(BuildContext ctx, BacklogNotaItem nota) async {
    final notaCompleta = await _obterNotaSAPCompleta(id: nota.id, numero: nota.nota);
    if (!mounted || notaCompleta == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível carregar os dados da Nota ${nota.nota} para programar.')),
        );
      }
      return;
    }

    final agora = DateTime.now();
    final taskCriada = await showDialog<Task>(
      context: context,
      builder: (dCtx) => TaskFormDialog(
        startDate: agora,
        endDate: agora.add(const Duration(hours: 4)),
        notaSAP: notaCompleta,
      ),
    );

    if (taskCriada != null) {
      try {
        final createResult = await _resolvedTaskService.createTaskWithResult(taskCriada);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Atividade "${createResult.task.tarefa}" programada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar atividade: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    _carregarDados(forcar: true);
  }


  // ===========================================================================
  // 4. KPIS GLOBAIS
  // ===========================================================================
  Widget _buildKpisGlobais(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    final cards = <Widget>[];

    if (_carteiraResult != null) {
      final ind = _carteiraResult!.indicadores;
      final riscoPrazoTotal = ind.totalVencidas + ind.totalViolacaoPrevista;

      cards.addAll([
        _buildKpiCard(
          label: 'Carteira Pendente',
          valor: ind.totalNotasPendentes.toString(),
          subtitulo: '${ind.totalNotasAgrupadas} em grupos • ${ind.totalNotasAvulsas} avulsas',
          icon: Icons.inventory_2_outlined,
          cor: ext?.colors.primary ?? Theme.of(context).primaryColor,
          tooltip: 'Total de notas abertas na carteira. Clique para ver todas.',
          selecionado: _filtroCardAtivo == null,
          onTap: () => _alternarFiltroCard(null),
        ),
        _buildKpiCard(
          label: 'Cobertura Previsibilidade',
          valor: '${ind.taxaCoberturaPrevisibilidade.toStringAsFixed(1)}%',
          subtitulo: '${ind.totalComPrevisao} de ${ind.totalNotasPendentes} com previsão',
          icon: Icons.track_changes_outlined,
          cor: ind.taxaCoberturaPrevisibilidade >= 80
              ? (ext?.colors.success ?? Colors.green.shade700)
              : (ext?.colors.warning ?? Colors.amber.shade800),
          tooltip: 'Percentual de notas com previsão macro definida.',
          selecionado: _filtroCardAtivo == 'com_previsao',
          onTap: () => _alternarFiltroCard('com_previsao'),
        ),
        _buildKpiCard(
          label: 'Sem Previsão',
          valor: ind.totalSemPrevisao.toString(),
          subtitulo: ind.totalSemPrevisaoPrazoProximo > 0
              ? '${ind.totalSemPrevisaoPrazoProximo} com prazo urgente'
              : 'Sem horizonte de atendimento',
          icon: Icons.event_busy_outlined,
          cor: ind.totalSemPrevisao > 0 ? (ext?.colors.warning ?? Colors.amber.shade800) : Colors.grey,
          tooltip: 'Notas pendentes sem mês previsto. Clique para abrir visão Sem Previsão.',
          onTap: () => _aplicarFiltroNav('sem_previsao'),
        ),
        _buildKpiCard(
          label: 'Vencidas & Risco',
          valor: riscoPrazoTotal.toString(),
          subtitulo: '${ind.totalVencidas} vencidas • ${ind.totalViolacaoPrevista} violação prev.',
          icon: Icons.warning_amber_rounded,
          cor: riscoPrazoTotal > 0 ? (ext?.colors.danger ?? Colors.red.shade700) : Colors.grey,
          tooltip: 'Notas vencidas ou com previsão posterior ao prazo. Clique para filtrar.',
          selecionado: _filtroCardAtivo == 'vencidas_risco',
          onTap: () => _alternarFiltroCard('vencidas_risco'),
        ),
        _buildKpiCard(
          label: 'Programadas',
          valor: ind.totalProgramadas.toString(),
          subtitulo: '${ind.taxaProgramacao.toStringAsFixed(0)}% da carteira pendente',
          icon: Icons.task_alt_outlined,
          cor: ext?.colors.info ?? Colors.blue.shade700,
          tooltip: 'Notas vinculadas a tarefas operacionais válidas. Clique para filtrar.',
          selecionado: _filtroCardAtivo == 'programadas',
          onTap: () => _alternarFiltroCard('programadas'),
        ),
      ]);
    } else {
      // Fallback para grupos puros (retrocompatibilidade)
      final g = _resultado!.global;
      cards.addAll([
        _buildKpiCard(
          label: 'Grupos Ativos',
          valor: g.gruposAtivos.toString(),
          icon: Icons.folder_outlined,
          cor: ext?.colors.primary ?? Theme.of(context).primaryColor,
          selecionado: _filtroCardAtivo == null,
          onTap: () => _alternarFiltroCard(null),
        ),
        _buildKpiCard(
          label: 'Com Previsão',
          valor: g.gruposComPrevisao.toString(),
          icon: Icons.event_available_outlined,
          cor: ext?.colors.success ?? Colors.green.shade700,
          selecionado: _filtroCardAtivo == 'com_previsao',
          onTap: () => _alternarFiltroCard('com_previsao'),
        ),
        _buildKpiCard(
          label: 'Sem Previsão',
          valor: g.gruposSemPrevisao.toString(),
          icon: Icons.event_busy_outlined,
          cor: ext?.colors.warning ?? Colors.amber.shade800,
          onTap: () => _aplicarFiltroNav('sem_previsao'),
        ),
        _buildKpiCard(
          label: 'Previsão Ultrapassada',
          valor: g.gruposUltrapassados.toString(),
          icon: Icons.warning_amber_rounded,
          cor: g.gruposUltrapassados > 0 ? (ext?.colors.danger ?? Colors.red.shade700) : Colors.grey,
          selecionado: _filtroCardAtivo == 'vencidas_risco',
          onTap: () => _alternarFiltroCard('vencidas_risco'),
        ),
        _buildKpiCard(
          label: 'Notas Pendentes',
          valor: g.notasPendentes.toString(),
          subtitulo: '${g.notasProgramadas} programadas (${g.percentualProgramado.toStringAsFixed(0)}%)',
          icon: Icons.pending_actions_outlined,
          cor: ext?.colors.info ?? Colors.blue.shade700,
          selecionado: _filtroCardAtivo == 'programadas',
          onTap: () => _alternarFiltroCard('programadas'),
        ),
      ]);
    }

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 40) / 2, child: c)).toList(),
      );
    }
  }

  Widget _buildKpiCard({
    required String label,
    required String valor,
    String? subtitulo,
    required IconData icon,
    required Color cor,
    VoidCallback? onTap,
    String? tooltip,
    bool selecionado = false,
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<TaskFlowThemeExtension>();

    final cardContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selecionado
            ? cor.withValues(alpha: 0.12)
            : (ext?.colors.surface ?? Theme.of(context).cardColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selecionado
              ? cor
              : (ext?.colors.borderSubtle ?? Colors.grey.shade300),
          width: selecionado ? 2.0 : 1.0,
        ),
        boxShadow: selecionado
            ? [
                BoxShadow(
                  color: cor.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
                          color: selecionado ? cor : (ext?.colors.textSecondary ?? Colors.grey.shade600),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selecionado) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 12, color: cor),
                    ],
                  ],
                ),
              ),
              Icon(icon, size: 18, color: cor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              selecionado ? 'Filtro aplicado (clique p/ alternar)' : subtitulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                color: selecionado ? cor : (ext?.colors.textSecondary ?? Colors.grey.shade600),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return tooltip != null ? Tooltip(message: tooltip, child: cardContent) : cardContent;
    }

    return Tooltip(
      message: tooltip ?? (selecionado ? 'Clique para remover o filtro' : 'Clique para filtrar'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        mouseCursor: SystemMouseCursors.click,
        child: cardContent,
      ),
    );
  }

  // ===========================================================================
  // 5. LISTA DE MESES
  // ===========================================================================
  List<Widget> _buildListaMeses(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    final List<Widget> widgets = [];

    // Meses com previsão
    for (final resumoMes in _resultado!.meses) {
      widgets.add(_buildCardMes(context, ext, resumoMes, isDesktop));
      widgets.add(const SizedBox(height: 20));
    }

    // Bloco Sem Previsão
    if (_resultado!.semPrevisao != null && _resultado!.semPrevisao!.totalGrupos > 0) {
      widgets.add(_buildCardMes(context, ext, _resultado!.semPrevisao!, isDesktop));
      widgets.add(const SizedBox(height: 20));
    }

    return widgets;
  }

  Widget _buildCardMes(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    BacklogMensalResumo resumo,
    bool isDesktop,
  ) {
    final isAtrasado = resumo.isUltrapassado();
    final headerCor = isAtrasado
        ? (ext?.colors.danger ?? Colors.red.shade700)
        : (ext?.colors.primary ?? Theme.of(context).primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAtrasado
              ? (ext?.colors.danger ?? Colors.red.shade400).withOpacity(0.5)
              : (ext?.colors.borderSubtle ?? Colors.grey.shade300),
          width: isAtrasado ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Mês
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isAtrasado ? headerCor.withOpacity(0.06) : (ext?.colors.surfaceSecondary ?? Colors.grey.shade100),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAtrasado ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
                  size: 20,
                  color: headerCor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resumo.labelMesAno,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: headerCor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isDesktop) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${resumo.totalGrupos} gr. • ${resumo.totalNotas} Notas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ext?.colors.textSecondary ?? Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  Text(
                    '${resumo.totalGrupos} grupos  •  ${resumo.totalNotas} Notas (${resumo.notasProgramadas} prog. / ${resumo.notasPendentes} pend.)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ext?.colors.textSecondary ?? Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (resumo.temPrevisao)
                  IconButton(
                    tooltip: _mesesComCapacidadeExpandida.contains('${resumo.ano}_${resumo.mes}')
                        ? 'Ocultar Capacidade Operacional'
                        : 'Ver Capacidade Operacional & Balanceamento',
                    icon: Icon(
                      _mesesComCapacidadeExpandida.contains('${resumo.ano}_${resumo.mes}')
                          ? Icons.speed
                          : Icons.speed_outlined,
                      size: 20,
                      color: _mesesComCapacidadeExpandida.contains('${resumo.ano}_${resumo.mes}')
                          ? (ext?.colors.primary ?? Theme.of(context).primaryColor)
                          : Colors.grey.shade600,
                    ),
                    onPressed: () {
                      final chave = '${resumo.ano}_${resumo.mes}';
                      setState(() {
                        if (_mesesComCapacidadeExpandida.contains(chave)) {
                          _mesesComCapacidadeExpandida.remove(chave);
                        } else {
                          _mesesComCapacidadeExpandida.add(chave);
                          _carregarCapacidadeParaMes(resumo.ano!, resumo.mes!);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),

          // Barra de estatísticas do Mês (Progresso e Horas)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final widgetProgresso = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'Cobertura de Programação: ${resumo.percentualProgramado.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${resumo.notasProgramadas} de ${resumo.totalNotas} demandas programadas',
                          style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: resumo.totalNotas == 0 ? 0 : resumo.notasProgramadas / resumo.totalNotas,
                        backgroundColor: ext?.colors.surfaceSecondary ?? Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          resumo.percentualProgramado == 100
                              ? (ext?.colors.success ?? Colors.green)
                              : (ext?.colors.primary ?? Theme.of(context).primaryColor),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );

                final widgetEstimativas = Column(
                  crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soma das estimativas individuais: ${resumo.somaEstimativasTotal.toStringAsFixed(1)} h (Pendentes: ${resumo.somaEstimativasPendentes.toStringAsFixed(1)} h)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${resumo.notasComEstimativa} de ${resumo.totalNotas} Notas com estimativa (${resumo.notasSemEstimativa} sem estimativa)',
                      style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 4, child: widgetProgresso),
                      const SizedBox(width: 24),
                      Expanded(flex: 5, child: widgetEstimativas),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widgetProgresso,
                      const SizedBox(height: 12),
                      widgetEstimativas,
                    ],
                  );
                }
              },
            ),
          ),
          const Divider(height: 1),

          // Painel de Capacidade do Mês Expandido
          if (resumo.temPrevisao && _mesesComCapacidadeExpandida.contains('${resumo.ano}_${resumo.mes}')) ...[
            Builder(
              builder: (ctx) {
                final chave = '${resumo.ano}_${resumo.mes}';
                final bal = _balancosCapacidade[chave];
                if (bal == null) {
                  if (_carregandoCapacidadeMeses.contains(chave)) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  if (_falhasCapacidadeMeses.contains(chave)) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('Não foi possível carregar o balanço de capacidade deste mês.')),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return CapacidadeBalanceamentoPanel(
                  balanceamento: bal,
                  capacidadesExecutores: _executoresPorMes[chave] ?? const [],
                  notasDoMes: resumo.grupos.expand((g) => g.notas).toList(),
                  gruposDoMes: resumo.grupos,
                  configuracao: _configCapacidade,
                  onDrillDown: widget.onDrillDown,
                );
              },
            ),
            const Divider(height: 1),
          ],

          // Grupos do mês
          Column(
            children: [
              for (int i = 0; i < resumo.grupos.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
                _buildCardGrupo(context, ext, resumo.grupos[i], isDesktop),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. CARD DO GRUPO COM DRILL-DOWN E AÇÕES
  // ===========================================================================
  Widget _buildCardGrupo(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    BacklogGrupoItem grupo,
    bool isDesktop,
  ) {
    return ExpansionTile(
      key: Key('grupo_${grupo.id}'),
      shape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: isDesktop
          ? Row(
              children: [
                _buildBadgeStatusProgramacao(ext, grupo.statusProgramacao),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grupo.nome,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (grupo.motivo != null && grupo.motivo!.isNotEmpty)
                        Text(
                          grupo.motivo!,
                          style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Local e Equipamento
                if (grupo.localInstalacao != null || grupo.equipamento != null) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (grupo.localInstalacao != null)
                        Text(
                          grupo.localInstalacao!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      if (grupo.equipamento != null)
                        Text(
                          grupo.equipamento!,
                          style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                        ),
                    ],
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBadgeStatusProgramacao(ext, grupo.statusProgramacao),
                const SizedBox(height: 6),
                Text(
                  grupo.nome,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (grupo.motivo != null && grupo.motivo!.isNotEmpty)
                  Text(
                    grupo.motivo!,
                    style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              '${grupo.totalNotas} Notas (${grupo.notasProgramadas} prog. / ${grupo.notasPendentes} pend.)',
              style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade700),
            ),
            Text(
              'Estimativa total: ${grupo.somaEstimativaTotal.toStringAsFixed(1)} h (Pendente: ${grupo.somaEstimativaPendente.toStringAsFixed(1)} h)',
              style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade700),
            ),
            Text(
              '[${grupo.notasComEstimativa}/${grupo.totalNotas} est.]',
              style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade500),
            ),
          ],
        ),
      ),
      children: [
        // Ações rápidas do grupo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          color: (ext?.colors.surfaceSecondary ?? Colors.grey.shade50),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (grupo.id.startsWith('avulsas_')) ...[
                // Atribuir Previsão em Lote para notas avulsas
                ElevatedButton.icon(
                  onPressed: () => _definirPrevisaoLote(context, grupo),
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Definir Previsão em Lote', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext?.colors.primary ?? Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else ...[
                // Histórico Lazy
                TextButton.icon(
                  onPressed: () => _abrirHistoricoGrupo(context, grupo),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Histórico', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                // Ver no Workspace
                TextButton.icon(
                  onPressed: () => _abrirWorkspaceDoGrupo(context, grupo),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ver Grupo', style: TextStyle(fontSize: 12)),
                ),
              ],
              if (grupo.notasPendentes > 0) ...[
                const SizedBox(width: 8),
                // Programar Pendentes (só se houver pendentes)
                ElevatedButton.icon(
                  onPressed: () => _programarNotasPendentes(context, grupo),
                  icon: const Icon(Icons.playlist_add, size: 16),
                  label: Text('Programar Pendentes (${grupo.notasPendentes})', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: grupo.id.startsWith('avulsas_')
                        ? (ext?.colors.surfaceSecondary ?? Colors.grey.shade200)
                        : (ext?.colors.primary ?? Theme.of(context).primaryColor),
                    foregroundColor: grupo.id.startsWith('avulsas_')
                        ? (ext?.colors.textPrimary ?? Colors.black87)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Lista drill-down de Notas do Grupo
        Builder(
          builder: (ctx) {
            final notasExibidas = _filtroCardAtivo == null
                ? grupo.notas
                : grupo.notas.where((n) => _notaAtendeFiltroCard(n, mes: grupo.mesProgramacaoPrevisto, ano: grupo.anoProgramacaoPrevisto)).toList();

            if (notasExibidas.isEmpty && _filtroCardAtivo != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text(
                  'Nenhuma demanda deste grupo atende ao filtro "${_descreverFiltro(_filtroCardAtivo!)}".',
                  style: TextStyle(fontSize: 12, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                ),
              );
            }

            return Column(
              children: [
                for (int i = 0; i < notasExibidas.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildItemNotaDrillDown(context, ext, notasExibidas[i], grupo: grupo),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBadgeStatusProgramacao(TaskFlowThemeExtension? ext, StatusProgramacaoGrupo status) {
    Color cor;
    String label;

    switch (status) {
      case StatusProgramacaoGrupo.total:
        cor = ext?.colors.success ?? Colors.green.shade700;
        label = 'Todas as demandas estão programadas';
        break;
      case StatusProgramacaoGrupo.parcial:
        cor = ext?.colors.warning ?? Colors.amber.shade800;
        label = 'Parcialmente programado';
        break;
      case StatusProgramacaoGrupo.naoProgramado:
        cor = ext?.colors.textSecondary ?? Colors.grey.shade600;
        label = 'Ainda não programado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
      ),
    );
  }

  // ===========================================================================
  // 7. DRILL-DOWN DE NOTA INDIVIDUAL COM RASTREABILIDADE NOTA ↔ TASK
  // ===========================================================================

  String _formatarDataBR(DateTime? data) {
    if (data == null) return '-';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _formatarMesAno(int? mes, int? ano) {
    if (mes == null || ano == null) return 'Sem previsão';
    const nomes = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final nomeMes = (mes >= 1 && mes <= 12) ? nomes[mes] : mes.toString();
    return '$nomeMes/$ano';
  }

  Future<void> _abrirTarefaDeepLink(String taskId) async {
    try {
      final taskService = _resolvedTaskService;
      final task = await taskService.getTaskById(taskId);
      if (!mounted) return;
      if (task == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarefa #$taskId não encontrada.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          task: task,
          startDate: task.dataInicio,
          endDate: task.dataFim,
        ),
      );

      if (result != null && mounted) {
        await _carregarDados(forcar: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exibirModalMultiplasTasks(BuildContext context, BacklogNotaItem nota) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tarefas Vinculadas — Nota SAP ${nota.nota}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 14,
                columns: const [
                  DataColumn(label: Text('Task')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Início')),
                  DataColumn(label: Text('Fim')),
                  DataColumn(label: Text('Ação')),
                ],
                rows: nota.tasks.map((t) {
                  final isCanc = t.isCancelada;
                  final statusCor = isCanc
                      ? Colors.grey
                      : (t.status.toUpperCase() == 'CONC'
                          ? Colors.green.shade700
                          : (t.status.toUpperCase() == 'ANDA'
                              ? Colors.purple.shade700
                              : Colors.blue.shade700));

                  return DataRow(
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            '#${t.id.length >= 6 ? t.id.substring(0, 6) : t.id}\n${t.tarefa ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              decoration: isCanc ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusCor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusCor.withOpacity(0.4)),
                          ),
                          child: Text(
                            t.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusCor,
                              decoration: isCanc ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(
                        _formatarDataBR(t.dataInicio),
                        style: const TextStyle(fontSize: 11),
                      )),
                      DataCell(Text(
                        _formatarDataBR(t.dataFim),
                        style: const TextStyle(fontSize: 11),
                      )),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          tooltip: 'Abrir Tarefa',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _abrirTarefaDeepLink(t.id);
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemNotaDrillDown(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    BacklogNotaItem nota, {
    BacklogGrupoItem? grupo,
  }) {
    final isProgramada = nota.isProgramada;
    final progCor = isProgramada
        ? (ext?.colors.success ?? Colors.green.shade700)
        : (ext?.colors.warning ?? Colors.amber.shade800);

    final mesPrevisaoEfetivo = nota.mesPrevisto ?? grupo?.mesProgramacaoPrevisto;
    final anoPrevisaoEfetivo = nota.anoPrevisto ?? grupo?.anoProgramacaoPrevisto;
    final divergencia = nota.classificarDivergencia(
      mesPrevisao: mesPrevisaoEfetivo,
      anoPrevisao: anoPrevisaoEfetivo,
    );
    final taskAtual = nota.taskProgramacaoAtual;
    final isVencida = nota.dataFimDesejada != null && nota.dataFimDesejada!.isBefore(DateTime.now());

    // Definição da cor da divergência
    final Color divergenciaCor;
    switch (divergencia) {
      case DivergenciaPrevisaoTask.conformePrevisao:
        divergenciaCor = ext?.colors.success ?? const Color(0xFF2E7D32);
        break;
      case DivergenciaPrevisaoTask.aposPrevisao:
        divergenciaCor = ext?.colors.danger ?? const Color(0xFFC62828);
        break;
      case DivergenciaPrevisaoTask.antecipada:
        divergenciaCor = ext?.colors.primary ?? const Color(0xFF1565C0);
        break;
      case DivergenciaPrevisaoTask.programadaSemPrevisaoMacro:
        divergenciaCor = ext?.colors.warning ?? const Color(0xFFEF6C00);
        break;
      case DivergenciaPrevisaoTask.previstaNaoProgramada:
      case DivergenciaPrevisaoTask.semPrevisao:
        divergenciaCor = ext?.colors.textSecondary ?? const Color(0xFF757575);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone de Status da Programação
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: progCor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProgramada ? Icons.check : Icons.access_time,
              size: 14,
              color: progCor,
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo e Detalhes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cabeçalho: Número da Nota, Badges de Status (Nota vs Task), Prioridade e Estimativa
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tooltip(
                      message: 'Clique para abrir análise completa da Nota',
                      child: InkWell(
                        onTap: () => _abrirDetalheNota(context, notaId: nota.id, numeroNota: nota.nota),
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nota SAP: ${nota.nota}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ext?.colors.primary ?? Colors.blue.shade800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new,
                              size: 12,
                              color: ext?.colors.primary ?? Colors.blue.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // STATUS DA NOTA (status_sistema oficial e status_usuario se houver)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NOTA: ${nota.statusSistema?.trim().isNotEmpty == true ? nota.statusSistema!.trim() : 'N/D'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (nota.statusUsuario?.trim().isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blueGrey.shade400, width: 0.5),
                        ),
                        child: Text(
                          'USR: ${nota.statusUsuario!.trim()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ),

                    // STATUS DA TASK (separado)
                    if (taskAtual != null && taskAtual.isValida)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: taskAtual.status.toUpperCase() == 'CONC'
                              ? Colors.green.shade800
                              : (taskAtual.status.toUpperCase() == 'ANDA'
                                  ? Colors.purple.shade800
                                  : Colors.blue.shade800),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TASK: ${taskAtual.status}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (taskAtual != null && taskAtual.isCancelada)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TASK: CANCELADA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade400, width: 0.5),
                        ),
                        child: Text(
                          'TASK: NÃO PROGRAMADA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),

                    if (nota.prioridade != null && nota.prioridade!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (ext?.colors.danger ?? Colors.red).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nota.prioridade!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ext?.colors.danger ?? Colors.red.shade700,
                          ),
                        ),
                      ),

                    // Botão de Previsão Individual
                    Tooltip(
                      message: 'Definir / Editar Previsão',
                      child: InkWell(
                        onTap: () => _definirPrevisaoIndividual(context, nota),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (ext?.colors.primary ?? Colors.blue).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: (ext?.colors.primary ?? Colors.blue).withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month, size: 12, color: ext?.colors.primary ?? Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Previsão',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ext?.colors.primary ?? Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Estimativa de Horas
                    Text(
                      nota.estimativaHoras != null
                          ? '${nota.estimativaHoras!.toStringAsFixed(1)} h'
                          : 'Sem análise',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: nota.estimativaHoras != null
                            ? (ext?.colors.textPrimary ?? Colors.black87)
                            : (ext?.colors.textSecondary ?? Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // 2. Descrição da Nota
                Text(
                  nota.descricao,
                  style: TextStyle(fontSize: 12, color: ext?.colors.textPrimary ?? Colors.black87),
                ),
                const SizedBox(height: 4),

                // 3. Localização (Local, Equip, CT)
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (nota.localInstalacao != null)
                      Text(
                        'Local: ${nota.localInstalacao}',
                        style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                      ),
                    if (nota.equipamento != null)
                      Text(
                        'Equip: ${nota.equipamento}',
                        style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                      ),
                    if (nota.centroTrabalhoResponsavel != null)
                      Text(
                        'CT: ${nota.centroTrabalhoResponsavel}',
                        style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // 4. Painel de Rastreabilidade Operacional: Previsão x Programação Real
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha de Previsão e Programação
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Prazo Limite da Demanda
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                isVencida ? Icons.alarm_off : Icons.flag_outlined,
                                size: 13,
                                color: isVencida ? Colors.red.shade700 : Colors.blueGrey.shade600,
                              ),
                              Text(
                                'Prazo: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isVencida ? Colors.red.shade800 : Colors.blueGrey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                nota.dataFimDesejada != null
                                    ? _formatarDataBR(nota.dataFimDesejada)
                                    : 'Não informado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isVencida ? Colors.red.shade800 : null,
                                ),
                              ),
                              if (isVencida)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.red.shade300, width: 0.5),
                                  ),
                                  child: Text(
                                    'Vencido',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(Icons.event, size: 13, color: Colors.blueGrey.shade600),
                              Text(
                                'Previsão: ',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _formatarMesAno(mesPrevisaoEfetivo, anoPrevisaoEfetivo),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                isProgramada ? Icons.check_circle_outline : Icons.pending_outlined,
                                size: 13,
                                color: progCor,
                              ),
                              if (taskAtual != null && taskAtual.status.toUpperCase() == 'CONC') ...[
                                Text(
                                  'Execução: ',
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Concluída em ${_formatarDataBR(taskAtual.dataFim ?? taskAtual.dataInicio)}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ] else if (taskAtual != null && taskAtual.isValida && taskAtual.dataInicio != null) ...[
                                Text(
                                  'Programação: ',
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _formatarDataBR(taskAtual.dataInicio),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ] else if (taskAtual != null && taskAtual.isCancelada) ...[
                                Text(
                                  'Histórico: ${nota.tasks.length} task(s) cancelada(s)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Não programada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Linha de Divergência Temporal e Detalhes da Task
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Rótulo da Divergência Temporal
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: divergenciaCor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: divergenciaCor.withOpacity(0.35)),
                            ),
                            child: Text(
                              divergencia.rotulo,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: divergenciaCor,
                              ),
                            ),
                          ),

                          // Identificação da Task e Ação de Deep-link
                          if (taskAtual != null) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width < 360 ? 120 : 190,
                              ),
                              child: Text(
                                'Task #${taskAtual.id.length >= 6 ? taskAtual.id.substring(0, 6) : taskAtual.id}${taskAtual.tarefa != null ? ' — ${taskAtual.tarefa}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: taskAtual.isCancelada ? Colors.grey : Colors.blueGrey.shade900,
                                  fontWeight: FontWeight.w500,
                                  decoration: taskAtual.isCancelada ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () => _abrirTarefaDeepLink(taskAtual.id),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (ext?.colors.primary ?? Colors.blue).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: (ext?.colors.primary ?? Colors.blue).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_new, size: 11, color: ext?.colors.primary ?? Colors.blue.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Abrir Tarefa',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: ext?.colors.primary ?? Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Ação de Abrir Nota
                          InkWell(
                            onTap: () => _abrirDetalheNota(context, notaId: nota.id, numeroNota: nota.nota),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blueGrey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_outlined, size: 11, color: Colors.blueGrey.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Abrir Nota',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Botão para Múltiplas Tasks se houver
                          if (nota.tasks.length > 1)
                            InkWell(
                              onTap: () => _exibirModalMultiplasTasks(context, nota),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.list_alt, size: 11, color: Colors.amber.shade900),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${nota.tasks.length} Tarefas Vinculadas',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 8. AÇÕES: VER GRUPO, PROGRAMAR PENDENTES, HISTÓRICO LAZY
  // ===========================================================================

  /// Abre o Workspace da Nota no grupo diretamente na aba Vínculo & Previsão.
  Future<void> _abrirWorkspaceDoGrupo(BuildContext ctx, BacklogGrupoItem grupo) async {
    if (grupo.notas.isEmpty) return;

    final primeiraNota = grupo.notas.first;
    // Buscar NotaSAP completa
    final notaCompleta = await _resolvedNotaSapService.getNotaById(primeiraNota.id);
    if (!mounted || notaCompleta == null) return;

    await NotaAnaliseWorkspace.abrir(
      context,
      nota: notaCompleta,
      initialTab: 6, // Aba 6 = Vínculo & Previsão (NotaWorkspaceGruposTab)
    );

    // Atualizar após retorno
    _carregarDados(forcar: true);
  }

  /// Dispara o TaskFormDialog com a primeira Nota pendente como origem e o painel de grupo carregado.
  Future<void> _programarNotasPendentes(BuildContext ctx, BacklogGrupoItem grupo) async {
    final notaPendente = grupo.primeiraNotaPendente;
    if (notaPendente == null) return;

    final notaCompleta = await _resolvedNotaSapService.getNotaById(notaPendente.id);
    if (!mounted || notaCompleta == null) return;

    final agora = DateTime.now();
    final taskCriada = await showDialog<Task>(
      context: context,
      builder: (dCtx) => TaskFormDialog(
        startDate: agora,
        endDate: agora.add(const Duration(hours: 4)),
        notaSAP: notaCompleta, // Pré-preenche apenas a nota origem
      ),
    );

    if (taskCriada != null) {
      try {
        final createResult = await _resolvedTaskService.createTaskWithResult(taskCriada);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                createResult.vinculacaoCompleta
                    ? 'Atividade "${createResult.task.tarefa}" programada e vinculada com sucesso!'
                    : 'Atividade criada, mas algumas notas pendentes não puderam ser vinculadas.',
              ),
              backgroundColor: createResult.vinculacaoCompleta ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar atividade: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // Recarregar os dados do backlog após eventual criação de tarefa
    _carregarDados(forcar: true);
  }

  /// Abre diálogo modal com histórico de previsões carregado de forma LAZY.
  Future<void> _abrirHistoricoGrupo(BuildContext context, BacklogGrupoItem grupo) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<NotaSapGrupoPrevisaoHist>>(
          future: _backlogService.buscarHistoricoGrupo(grupo.id),
          builder: (context, snapshot) {
            final ext = Theme.of(context).extension<TaskFlowThemeExtension>();

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Histórico de Previsões — ${grupo.nome}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : snapshot.hasError
                        ? Text('Erro ao carregar histórico: ${snapshot.error}')
                        : (snapshot.data == null || snapshot.data!.isEmpty)
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Nenhuma alteração de previsão registrada para este grupo.'),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final h = snapshot.data![idx];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    leading: const Icon(Icons.arrow_forward_rounded, size: 16),
                                    title: Text(
                                      h.transicaoTexto,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (h.motivo != null && h.motivo!.isNotEmpty)
                                          Text(
                                            'Motivo: ${h.motivo}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        Text(
                                          'Por: ${h.alteradoPorNome ?? "Usuário"} em ${h.alteradoEm != null ? "${h.alteradoEm!.day}/${h.alteradoEm!.month}/${h.alteradoEm!.year}" : ""}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ext?.colors.textSecondary ?? Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Abre o modal de previsão individual para uma nota no drill-down
  Future<void> _definirPrevisaoIndividual(BuildContext ctx, BacklogNotaItem nota) async {
    final alterado = await PrevisaoDialog.showIndividual(
      context,
      notaSapId: nota.id,
      numeroNota: nota.nota,
    );

    if (!mounted || alterado != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Previsão da nota ${nota.nota} atualizada com sucesso!'),
        backgroundColor: Colors.green.shade700,
      ),
    );

    _carregarDados(forcar: true);
  }

  /// Abre o modal de previsão em lote para as notas de um grupo avulso
  Future<void> _definirPrevisaoLote(BuildContext ctx, BacklogGrupoItem grupo) async {
    if (grupo.notas.isEmpty) return;

    final Map<String, String> numeroPorNotaId = {
      for (final n in grupo.notas) n.id: n.nota,
    };
    final Map<String, DateTime?> vencimentoPorNotaId = {
      for (final n in grupo.notas) n.id: null,
    };

    final loteId = await PrevisaoDialog.showLote(
      context,
      notaSapIds: grupo.notas.map((n) => n.id).toList(),
      numeroPorNotaId: numeroPorNotaId,
      vencimentoPorNotaId: vencimentoPorNotaId,
    );

    if (!mounted || loteId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Previsão em lote atribuída a ${grupo.notas.length} notas!'),
        backgroundColor: Colors.green.shade700,
        action: SnackBarAction(
          label: 'DESFAZER',
          textColor: Colors.amberAccent,
          onPressed: () async {
            final ok = await _carteiraService.desfazerAlteracaoLote(loteId: loteId);
            if (mounted) {
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alteração em lote desfeita com sucesso!')),
                );
                _carregarDados(forcar: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Não foi possível desfazer a alteração em lote.')),
                );
              }
            }
          },
        ),
        duration: const Duration(seconds: 8),
      ),
    );

    _carregarDados(forcar: true);
  }
}
