import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/backlog_macro_models.dart';
import '../../models/nota_sap_grupo.dart';
import '../../services/nota_sap_backlog_service.dart';
import '../../services/nota_sap_service.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../nota_analise_workspace.dart';
import '../task_form_dialog.dart';

/// Tela Gerencial de Planejamento Macro de Notas SAP agrupadas.
class PlanejamentoMacroView extends StatefulWidget {
  final NotaSapBacklogService? backlogService;
  final NotaSapService? notaSapService;
  final TaskService? taskService;

  const PlanejamentoMacroView({
    super.key,
    this.backlogService,
    this.notaSapService,
    this.taskService,
  });

  @override
  State<PlanejamentoMacroView> createState() => _PlanejamentoMacroViewState();
}

class _PlanejamentoMacroViewState extends State<PlanejamentoMacroView>
    with AutomaticKeepAliveClientMixin {
  late final NotaSapBacklogService _backlogService;
  NotaSapService? _notaSapService;
  NotaSapService get _resolvedNotaSapService => _notaSapService ??= widget.notaSapService ?? NotaSapService();
  TaskService? _taskService;
  TaskService get _resolvedTaskService => _taskService ??= widget.taskService ?? TaskService();

  bool _carregando = true;
  String? _erro;
  BacklogMacroResult? _resultado;

  // Filtros ativos
  BacklogFiltro _filtro = const BacklogFiltro();
  final TextEditingController _buscaController = TextEditingController();

  // Mês selecionado no carrossel de navegação (null = "Todos", -1 = "Sem previsão", -2 = "Atrasados")
  int? _mesFiltroNav;
  int? _anoFiltroNav;
  String _abaNavegacaoAtiva = 'todos'; // 'todos', 'atrasados', 'mes_ano', 'sem_previsao'

  @override
  void initState() {
    super.initState();
    _backlogService = widget.backlogService ?? NotaSapBacklogService();
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

    _carregarDados(forcar: false);
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

    return ListView(
      key: const Key('planejamento_macro_scroll'),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      children: [
        // Grid de KPIs Globais
        _buildKpisGlobais(context, ext, isDesktop),
        const SizedBox(height: 24),

        // Listagem de Meses e Grupos
        ..._buildListaMeses(context, ext, isDesktop),
      ],
    );
  }

  // ===========================================================================
  // 4. KPIS GLOBAIS
  // ===========================================================================
  Widget _buildKpisGlobais(BuildContext context, TaskFlowThemeExtension? ext, bool isDesktop) {
    final g = _resultado!.global;

    final cards = [
      _buildKpiCard(
        label: 'Grupos Ativos',
        valor: g.gruposAtivos.toString(),
        icon: Icons.folder_outlined,
        cor: ext?.colors.primary ?? Theme.of(context).primaryColor,
      ),
      _buildKpiCard(
        label: 'Com Previsão',
        valor: g.gruposComPrevisao.toString(),
        icon: Icons.event_available_outlined,
        cor: ext?.colors.success ?? Colors.green.shade700,
      ),
      _buildKpiCard(
        label: 'Sem Previsão',
        valor: g.gruposSemPrevisao.toString(),
        icon: Icons.event_busy_outlined,
        cor: ext?.colors.warning ?? Colors.amber.shade800,
      ),
      _buildKpiCard(
        label: 'Previsão Ultrapassada',
        valor: g.gruposUltrapassados.toString(),
        icon: Icons.warning_amber_rounded,
        cor: g.gruposUltrapassados > 0 ? (ext?.colors.danger ?? Colors.red.shade700) : Colors.grey,
      ),
      _buildKpiCard(
        label: 'Notas Pendentes',
        valor: g.notasPendentes.toString(),
        subtitulo: '${g.notasProgramadas} programadas (${g.percentualProgramado.toStringAsFixed(0)}%)',
        icon: Icons.pending_actions_outlined,
        cor: ext?.colors.info ?? Colors.blue.shade700,
      ),
    ];

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
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<TaskFlowThemeExtension>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext?.colors.surface ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext?.colors.borderSubtle ?? Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ext?.colors.textSecondary ?? Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              subtitulo,
              style: TextStyle(
                fontSize: 11,
                color: ext?.colors.textSecondary ?? Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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
                  child: Text(
                    resumo.labelMesAno,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: headerCor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Resumo de contagem e horas
                Text(
                  '${resumo.totalGrupos} grupos  •  ${resumo.totalNotas} Notas (${resumo.notasProgramadas} prog. / ${resumo.notasPendentes} pend.)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ext?.colors.textSecondary ?? Colors.grey.shade700,
                  ),
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
                          'Progresso: ${resumo.percentualProgramado.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${resumo.notasProgramadas} de ${resumo.totalNotas} Notas',
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
      title: Row(
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
          if (isDesktop && (grupo.localInstalacao != null || grupo.equipamento != null)) ...[
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
              const SizedBox(width: 8),
              // Programar Pendentes (só se houver pendentes)
              if (grupo.notasPendentes > 0)
                ElevatedButton.icon(
                  onPressed: () => _programarNotasPendentes(context, grupo),
                  icon: const Icon(Icons.playlist_add, size: 16),
                  label: Text('Programar Pendentes (${grupo.notasPendentes})', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext?.colors.primary ?? Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ),

        // Lista drill-down de Notas do Grupo
        Column(
          children: [
            for (int i = 0; i < grupo.notas.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _buildItemNotaDrillDown(context, ext, grupo.notas[i]),
            ],
          ],
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
        label = 'Programação concluída';
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
  // 7. DRILL-DOWN DE NOTA INDIVIDUAL
  // ===========================================================================
  Widget _buildItemNotaDrillDown(
    BuildContext context,
    TaskFlowThemeExtension? ext,
    BacklogNotaItem nota,
  ) {
    final isProgramada = nota.isProgramada;
    final progCor = isProgramada
        ? (ext?.colors.success ?? Colors.green.shade700)
        : (ext?.colors.warning ?? Colors.amber.shade800);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status da Programação
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
          // Dados da Nota
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nota.nota,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
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
                    const Spacer(),
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
                const SizedBox(height: 2),
                Text(
                  nota.descricao,
                  style: TextStyle(fontSize: 12, color: ext?.colors.textPrimary ?? Colors.black87),
                ),
                const SizedBox(height: 4),
                // Localização e Status SAP
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
                    if (nota.statusSistema != null)
                      Text(
                        'SAP: ${nota.statusSistema}',
                        style: TextStyle(fontSize: 11, color: ext?.colors.textSecondary ?? Colors.grey.shade500),
                      ),
                  ],
                ),

                // Exibição de Tasks válidas e canceladas
                if (nota.tasks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: nota.tasks.map((t) {
                      final isCanc = t.isCancelada;
                      final tCor = isCanc ? Colors.grey : (ext?.colors.primary ?? Colors.blue.shade700);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tCor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: tCor.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Task #${t.id.length >= 6 ? t.id.substring(0, 6) : t.id} [${t.status}]${t.tarefa != null ? ' - ${t.tarefa}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: tCor,
                            decoration: isCanc ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
}
