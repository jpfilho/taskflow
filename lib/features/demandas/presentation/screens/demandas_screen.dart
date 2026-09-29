import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/components/tables/tf_data_table.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/demanda_model.dart';
import '../../data/services/demanda_service.dart';
import '../widgets/demanda_card.dart';
import '../widgets/demanda_prazo_helper.dart';
import '../widgets/demanda_status_mapper.dart';
import 'demanda_detail_screen.dart';
import 'demanda_form_screen.dart';

class DemandasScreen extends StatefulWidget {
  const DemandasScreen({super.key});

  @override
  State<DemandasScreen> createState() => _DemandasScreenState();
}

class _DemandasScreenState extends State<DemandasScreen> {
  final DemandaService _demandaService = DemandaService();

  List<Demanda> _todasDemandas = [];
  List<Demanda> _demandasFiltradas = [];
  bool _isLoading = false;
  String _erroMsg = '';
  bool _visualizacaoTabela = true;

  // Controllers para filtros de busca e colunas
  final TextEditingController _filtroGeralController = TextEditingController();
  final TextEditingController _filtroColLocalController = TextEditingController();
  final TextEditingController _filtroColSalaController = TextEditingController();
  final TextEditingController _filtroColOrigemController = TextEditingController();
  final TextEditingController _filtroColDemandaController = TextEditingController();
  final TextEditingController _filtroColResponsavelController = TextEditingController();
  final TextEditingController _filtroColNotaController = TextEditingController();
  final TextEditingController _filtroColOrdemController = TextEditingController();
  final TextEditingController _filtroColSiController = TextEditingController();
  final TextEditingController _filtroColAtController = TextEditingController();

  // Estatísticas / Contadores operacionais
  int _total = 0;
  int _abertas = 0;
  int _emExecucao = 0;
  int _atrasadas = 0;
  int _vencendoHoje = 0;
  int _vencendo7Dias = 0;
  int _aguardando = 0;
  int _concluidas = 0;

  @override
  void initState() {
    super.initState();
    _filtroGeralController.addListener(_aplicarFiltros);
    _filtroColLocalController.addListener(_aplicarFiltros);
    _filtroColSalaController.addListener(_aplicarFiltros);
    _filtroColOrigemController.addListener(_aplicarFiltros);
    _filtroColDemandaController.addListener(_aplicarFiltros);
    _filtroColResponsavelController.addListener(_aplicarFiltros);
    _filtroColNotaController.addListener(_aplicarFiltros);
    _filtroColOrdemController.addListener(_aplicarFiltros);
    _filtroColSiController.addListener(_aplicarFiltros);
    _filtroColAtController.addListener(_aplicarFiltros);
    _carregarDados();
  }

  @override
  void dispose() {
    _filtroGeralController.dispose();
    _filtroColLocalController.dispose();
    _filtroColSalaController.dispose();
    _filtroColOrigemController.dispose();
    _filtroColDemandaController.dispose();
    _filtroColResponsavelController.dispose();
    _filtroColNotaController.dispose();
    _filtroColOrdemController.dispose();
    _filtroColSiController.dispose();
    _filtroColAtController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
      _erroMsg = '';
    });

    try {
      final lista = await _demandaService.listarDemandas(limit: 1000);
      if (mounted) {
        setState(() {
          _todasDemandas = lista;
          _calcularEstatisticas();
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroMsg = 'Erro ao carregar demandas: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _calcularEstatisticas() {
    _total = _todasDemandas.length;
    _abertas = 0;
    _emExecucao = 0;
    _atrasadas = 0;
    _vencendoHoje = 0;
    _vencendo7Dias = 0;
    _aguardando = 0;
    _concluidas = 0;

    for (final d in _todasDemandas) {
      if (d.status == 'Aberta' || d.status == 'Em análise' || d.status == 'Programada') {
        _abertas++;
      } else if (d.status == 'Em execução') {
        _emExecucao++;
      } else if (d.status == 'Aguardando terceiros' || d.status == 'Aguardando material') {
        _aguardando++;
      } else if (d.status == 'Concluída') {
        _concluidas++;
      }

      final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
      if (situacao == SituacaoPrazo.atrasada) {
        _atrasadas++;
      } else if (situacao == SituacaoPrazo.venceHoje) {
        _vencendoHoje++;
      } else if (situacao == SituacaoPrazo.venceEmAte7Dias) {
        _vencendo7Dias++;
      }
    }
  }

  void _limparFiltros() {
    setState(() {
      _filtroGeralController.clear();
      _filtroColLocalController.clear();
      _filtroColSalaController.clear();
      _filtroColOrigemController.clear();
      _filtroColDemandaController.clear();
      _filtroColResponsavelController.clear();
      _filtroColNotaController.clear();
      _filtroColOrdemController.clear();
      _filtroColSiController.clear();
      _filtroColAtController.clear();
      _aplicarFiltros();
    });
  }

  bool get _possuiFiltrosAtivos {
    return _filtroGeralController.text.isNotEmpty ||
        _filtroColLocalController.text.isNotEmpty ||
        _filtroColSalaController.text.isNotEmpty ||
        _filtroColOrigemController.text.isNotEmpty ||
        _filtroColDemandaController.text.isNotEmpty ||
        _filtroColResponsavelController.text.isNotEmpty ||
        _filtroColNotaController.text.isNotEmpty ||
        _filtroColOrdemController.text.isNotEmpty ||
        _filtroColSiController.text.isNotEmpty ||
        _filtroColAtController.text.isNotEmpty;
  }

  void _aplicarFiltros() {
    setState(() {
      final buscaGeral = _filtroGeralController.text.trim().toLowerCase();

      _demandasFiltradas = _todasDemandas.where((d) {
        // Busca geral unificada
        if (buscaGeral.isNotEmpty) {
          final matchGeral = d.demanda.toLowerCase().contains(buscaGeral) ||
              d.local.toLowerCase().contains(buscaGeral) ||
              (d.sala ?? '').toLowerCase().contains(buscaGeral) ||
              d.responsavel.toLowerCase().contains(buscaGeral) ||
              (d.nota ?? '').toLowerCase().contains(buscaGeral) ||
              (d.ordem ?? '').toLowerCase().contains(buscaGeral) ||
              (d.si ?? '').toLowerCase().contains(buscaGeral) ||
              (d.at ?? '').toLowerCase().contains(buscaGeral);
          if (!matchGeral) return false;
        }

        // Filtros específicos por coluna
        if (_filtroColLocalController.text.isNotEmpty) {
          if (!d.local.toLowerCase().contains(_filtroColLocalController.text.toLowerCase())) return false;
        }
        if (_filtroColSalaController.text.isNotEmpty) {
          if (!(d.sala ?? '').toLowerCase().contains(_filtroColSalaController.text.toLowerCase())) return false;
        }
        if (_filtroColOrigemController.text.isNotEmpty) {
          if (!d.origem.toLowerCase().contains(_filtroColOrigemController.text.toLowerCase())) return false;
        }
        if (_filtroColDemandaController.text.isNotEmpty) {
          if (!d.demanda.toLowerCase().contains(_filtroColDemandaController.text.toLowerCase())) return false;
        }
        if (_filtroColResponsavelController.text.isNotEmpty) {
          if (!d.responsavel.toLowerCase().contains(_filtroColResponsavelController.text.toLowerCase())) return false;
        }
        if (_filtroColNotaController.text.isNotEmpty) {
          if (!(d.nota ?? '').toLowerCase().contains(_filtroColNotaController.text.toLowerCase())) return false;
        }
        if (_filtroColOrdemController.text.isNotEmpty) {
          if (!(d.ordem ?? '').toLowerCase().contains(_filtroColOrdemController.text.toLowerCase())) return false;
        }
        if (_filtroColSiController.text.isNotEmpty) {
          if (!(d.si ?? '').toLowerCase().contains(_filtroColSiController.text.toLowerCase())) return false;
        }
        if (_filtroColAtController.text.isNotEmpty) {
          if (!(d.at ?? '').toLowerCase().contains(_filtroColAtController.text.toLowerCase())) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _abrirNovaDemanda() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DemandaFormScreen()),
    );
    if (result == true) {
      _carregarDados();
    }
  }

  Future<void> _abrirDetalhe(Demanda d) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DemandaDetailScreen(demandaId: d.id),
      ),
    );
    if (result == true) {
      _carregarDados();
    }
  }

  Future<void> _abrirEdicao(Demanda d) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DemandaFormScreen(demandaExistente: d),
      ),
    );
    if (result == true) {
      _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final isDesktop = TFBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Page Header oficial TFDS
            TFPageHeader(
              title: 'Demandas Operacionais',
              subtitle: 'Acompanhe, priorize e gerencie as demandas e evidências da unidade.',
              primaryAction: TFButton(
                label: 'Nova Demanda',
                leadingIcon: TFIcons.add,
                onPressed: _abrirNovaDemanda,
              ),
              secondaryActions: [
                TFIconButton(
                  icon: _visualizacaoTabela ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                  tooltip: _visualizacaoTabela ? 'Ver em Cards' : 'Ver em Tabela',
                  onPressed: () {
                    setState(() {
                      _visualizacaoTabela = !_visualizacaoTabela;
                    });
                  },
                ),
                if (_possuiFiltrosAtivos)
                  TFIconButton(
                    icon: TFIcons.clear,
                    tooltip: 'Limpar Filtros',
                    onPressed: _limparFiltros,
                  ),
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar Lista',
                  onPressed: _carregarDados,
                ),
              ],
            ),

            // 2. Painel de KPIs Operacionais
            _buildKpiBar(context),

            // 3. Barra de Busca Geral
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
              child: TFTextField(
                controller: _filtroGeralController,
                hint: 'Pesquisar por demanda, local, responsável, nota, ordem...',
                prefixIcon: const Icon(TFIcons.search, size: 18),
                suffixIcon: _filtroGeralController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(TFIcons.clear, size: 16),
                        onPressed: () {
                          _filtroGeralController.clear();
                        },
                      )
                    : null,
              ),
            ),

            // 4. Conteúdo Principal (Loading / Erro / Empty / Tabela / Cards)
            Expanded(
              child: _isLoading
                  ? const Center(child: TFLoading(message: 'Carregando demandas...'))
                  : _erroMsg.isNotEmpty
                      ? Center(
                          child: TFEmptyState(
                            title: 'Erro ao carregar',
                            description: _erroMsg,
                            icon: TFIcons.warning,
                            action: TFButton(
                              label: 'Tentar Novamente',
                              leadingIcon: TFIcons.refresh,
                              onPressed: _carregarDados,
                            ),
                          ),
                        )
                      : _demandasFiltradas.isEmpty
                          ? Center(
                              child: TFEmptyState(
                                title: _possuiFiltrosAtivos
                                    ? 'Nenhuma demanda encontrada'
                                    : 'Nenhuma demanda cadastrada',
                                description: _possuiFiltrosAtivos
                                    ? 'Não há demandas compatíveis com os filtros aplicados.'
                                    : 'Clique no botão "Nova Demanda" para registrar a primeira atividade.',
                                icon: TFIcons.task,
                                action: TFButton(
                                  label: _possuiFiltrosAtivos ? 'Limpar Filtros' : 'Nova Demanda',
                                  leadingIcon: _possuiFiltrosAtivos ? TFIcons.clear : TFIcons.add,
                                  onPressed: _possuiFiltrosAtivos ? _limparFiltros : _abrirNovaDemanda,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _carregarDados,
                              child: Padding(
                                padding: EdgeInsets.all(spacing.md),
                                child: _visualizacaoTabela && isDesktop
                                    ? _buildTableView(context)
                                    : _buildCardsView(context),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBar(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    Widget kpiItem(String label, int count, Color color) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: spacing.xs),
            Text(
              '$label: ',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
            Text(
              '$count',
              style: typography.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
      child: TFCard(
        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              kpiItem('Total', _total, colors.info),
              kpiItem('Abertas', _abertas, colors.info),
              kpiItem('Em Execução', _emExecucao, colors.warning),
              kpiItem('Aguardando', _aguardando, colors.warning),
              kpiItem('Atrasadas', _atrasadas, colors.danger),
              kpiItem('Vence Hoje', _vencendoHoje, colors.warning),
              kpiItem('Em 7 Dias', _vencendo7Dias, colors.info),
              kpiItem('Concluídas', _concluidas, colors.success),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableView(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final columns = [
      TFDataColumn<Demanda>(
        id: 'status',
        label: const Text('Status'),
        width: 130,
        cellBuilder: (context, d) {
          return TFStatusBadge(
            label: d.status,
            severity: DemandaStatusMapper.mapSeverity(d.status),
            compact: true,
          );
        },
      ),
      TFDataColumn<Demanda>(
        id: 'prazo',
        label: const Text('Prazo'),
        width: 160,
        cellBuilder: (context, d) {
          final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
          final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, d.prazo);
          final severity = DemandaPrazoHelper.obterSeverity(situacao);
          return TFStatusBadge(
            label: textoPrazo,
            severity: severity,
            compact: true,
          );
        },
      ),
      TFDataColumn<Demanda>.text(
        id: 'local',
        title: 'Local',
        width: 140,
        cellBuilder: (context, d) => Text(d.local, style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'sala',
        title: 'Sala',
        width: 100,
        cellBuilder: (context, d) => Text(d.sala ?? '-', style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'origem',
        title: 'Origem',
        width: 110,
        cellBuilder: (context, d) => Text(d.origem, style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>(
        id: 'demanda',
        label: const Text('Demanda'),
        width: 260,
        cellBuilder: (context, d) => Text(
          d.demanda,
          style: typography.bodySmall.copyWith(fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TFDataColumn<Demanda>.text(
        id: 'responsavel',
        title: 'Responsável',
        width: 140,
        cellBuilder: (context, d) => Text(d.responsavel, style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'prioridade',
        title: 'Prioridade',
        width: 100,
        cellBuilder: (context, d) => Text(
          d.prioridade,
          style: typography.bodySmall.copyWith(
            color: d.prioridade == 'Crítica' ? colors.danger : null,
            fontWeight: d.prioridade == 'Crítica' ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      TFDataColumn<Demanda>.text(
        id: 'nota',
        title: 'Nota SAP',
        width: 100,
        cellBuilder: (context, d) => Text(d.nota ?? '-', style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'ordem',
        title: 'Ordem SAP',
        width: 100,
        cellBuilder: (context, d) => Text(d.ordem ?? '-', style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'si',
        title: 'SI',
        width: 110,
        cellBuilder: (context, d) => Text(d.si ?? '-', style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>.text(
        id: 'at',
        title: 'AT',
        width: 80,
        cellBuilder: (context, d) => Text(d.at ?? '-', style: typography.bodySmall),
      ),
      TFDataColumn<Demanda>(
        id: 'acoes',
        label: const Text('Ações'),
        width: 130,
        cellBuilder: (context, d) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'Visualizar Demanda',
                onPressed: () => _abrirDetalhe(d),
              ),
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar Demanda',
                onPressed: () => _abrirEdicao(d),
              ),
            ],
          );
        },
      ),
    ];

    return TFDataTable<Demanda>(
      columns: columns,
      items: _demandasFiltradas,
      zebra: true,
      onRowTap: _abrirDetalhe,
    );
  }

  Widget _buildCardsView(BuildContext context) {
    final spacing = context.tfSpacing;
    final isDesktop = TFBreakpoints.isDesktop(context);
    final isTablet = TFBreakpoints.isTablet(context);
    final crossAxisCount = isDesktop ? 3 : isTablet ? 2 : 1;

    if (crossAxisCount == 1) {
      return ListView.separated(
        itemCount: _demandasFiltradas.length,
        separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
        itemBuilder: (context, index) {
          final d = _demandasFiltradas[index];
          return DemandaCard(
            demanda: d,
            onTap: () => _abrirDetalhe(d),
          );
        },
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing.md,
        mainAxisSpacing: spacing.md,
        mainAxisExtent: 170,
      ),
      itemCount: _demandasFiltradas.length,
      itemBuilder: (context, index) {
        final d = _demandasFiltradas[index];
        return DemandaCard(
          demanda: d,
          onTap: () => _abrirDetalhe(d),
        );
      },
    );
  }
}
