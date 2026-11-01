import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../services/nota_sap_analise_service.dart';
import '../../features/media_albums/data/repositories/supabase_media_repository.dart';
import '../../models/nota_sap.dart';
import 'nota_workspace_contextual_evidence_panel.dart';
import 'nota_workspace_quick_attach_dialog.dart';
import 'nota_anexo_viewer_dialog.dart';

class NotaWorkspaceAnalysisTab extends StatefulWidget {
  final NotaSapAnalise? analiseInicial;
  final String? notaSapId;
  final NotaSAP? nota;
  final NotaSapAnaliseService? service;
  final bool isLoading;
  final bool isSaving;
  final bool isReadOnly;
  final void Function(bool hasChanges)? onDirtyChanged;
  final Future<void> Function(NotaSapAnalise analise)? onSalvar;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;

  const NotaWorkspaceAnalysisTab({
    super.key,
    required this.analiseInicial,
    this.notaSapId,
    this.nota,
    this.service,
    this.isLoading = false,
    this.isSaving = false,
    this.isReadOnly = false,
    this.onDirtyChanged,
    this.onSalvar,
    this.onAbrirNotaHistorica,
  });

  @override
  State<NotaWorkspaceAnalysisTab> createState() =>
      NotaWorkspaceAnalysisTabState();
}

class NotaWorkspaceAnalysisTabState extends State<NotaWorkspaceAnalysisTab>
    with AutomaticKeepAliveClientMixin<NotaWorkspaceAnalysisTab> {
  late TextEditingController _diagnosticoController;
  late TextEditingController _escopoController;
  late TextEditingController _observacoesController;
  late TextEditingController _estimativaHorasController;
  late TextEditingController _quantidadeTecnicosController;
  late TextEditingController _ferramentasController;
  late TextEditingController _requisitosSegurancaController;
  late TextEditingController _valorPvController;

  late NotaAnaliseStatus _status;
  late bool _necessitaDesligamento;

  bool _isDirty = false;

  bool get isDirty => _isDirty;

  late final NotaSapAnaliseService _analiseService;
  List<NotaSapAnaliseEvidencia> _evidencias = [];
  bool _isLoadingEvidencias = false;

  // Estado da Experiência Integrada (Fase 4C)
  NotaTipoVinculoEvidencia _secaoAtiva = NotaTipoVinculoEvidencia.diagnostico;
  NotaSapAnaliseEvidencia? _evidenciaSelecionada;

  String? get _effectiveNotaSapId =>
      widget.analiseInicial?.notaSapId ?? widget.notaSapId;

  @override
  void initState() {
    super.initState();
    _analiseService = widget.service ?? NotaSapAnaliseService();
    _initValues(widget.analiseInicial);
    _carregarEvidencias();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceAnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analiseInicial != widget.analiseInicial && !_isDirty) {
      _initValues(widget.analiseInicial);
      _carregarEvidencias();
    }
  }

  Future<void> _carregarEvidencias() async {
    final nid = _effectiveNotaSapId;
    if (nid == null || nid.trim().isEmpty) return;

    setState(() => _isLoadingEvidencias = true);
    try {
      final list = await _analiseService.listarEvidenciasDaNota(nid);
      if (mounted) {
        setState(() {
          _evidencias = list;
          _isLoadingEvidencias = false;

          // Sincroniza a evidência selecionada com a nova lista
          if (_evidenciaSelecionada != null) {
            final idx = _evidencias.indexWhere((e) => e.id == _evidenciaSelecionada!.id);
            if (idx != -1) {
              _evidenciaSelecionada = _evidencias[idx];
            } else {
              _evidenciaSelecionada = _evidencias.isNotEmpty ? _evidencias.first : null;
            }
          } else if (_evidencias.isNotEmpty) {
            final daSecao = _evidencias.where((e) => e.tipoVinculo == _secaoAtiva).toList();
            _evidenciaSelecionada = daSecao.isNotEmpty ? daSecao.first : _evidencias.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvidencias = false);
      }
    }
  }

  /// Abre o Quick Attach de forma ágil para vincular evidência à seção informada
  void _abrirQuickAttach(NotaTipoVinculoEvidencia secao) {
    final nid = _effectiveNotaSapId;
    if (nid == null) return;

    final notaObj = widget.nota ??
        NotaSAP(
          id: nid,
          nota: widget.analiseInicial?.numeroNota ?? '',
        );

    NotaWorkspaceQuickAttachDialog.abrir(
      context,
      notaSapId: nid,
      nota: notaObj,
      secaoInicial: secao,
      service: _analiseService,
      onVinculoConcluido: _carregarEvidencias,
    );
  }

  void _selecionarEvidencia(NotaSapAnaliseEvidencia? ev) {
    setState(() {
      _evidenciaSelecionada = ev;
      if (ev != null) {
        _secaoAtiva = ev.tipoVinculo;
      }
    });
  }

  void _initValues(NotaSapAnalise? a) {
    _status = a?.statusAnalise ?? NotaAnaliseStatus.naoIniciada;
    _diagnosticoController =
        TextEditingController(text: a?.diagnosticoPrevio ?? '');
    _escopoController = TextEditingController(text: a?.escopoDetalhado ?? '');
    _observacoesController =
        TextEditingController(text: a?.observacoesPlanejamento ?? '');
    _estimativaHorasController = TextEditingController(
        text: (a?.estimativaHoras != null && a!.estimativaHoras! > 0)
            ? a.estimativaHoras!.toStringAsFixed(1)
            : '');
    _quantidadeTecnicosController = TextEditingController(
        text: (a?.quantidadeTecnicos != null && a!.quantidadeTecnicos! > 0)
            ? a.quantidadeTecnicos!.toString()
            : '');
    _ferramentasController =
        TextEditingController(text: a?.ferramentasEspeciais ?? '');
    _requisitosSegurancaController =
        TextEditingController(text: a?.requisitosSeguranca ?? '');
    _valorPvController = TextEditingController(
        text: (a?.valorPv != null && a!.valorPv! > 0)
            ? a.valorPv!.toStringAsFixed(2)
            : '');

    _necessitaDesligamento = a?.necessitaDesligamento ?? false;

    _diagnosticoController.addListener(_markDirty);
    _escopoController.addListener(_markDirty);
    _observacoesController.addListener(_markDirty);
    _estimativaHorasController.addListener(_markDirty);
    _quantidadeTecnicosController.addListener(_markDirty);
    _ferramentasController.addListener(_markDirty);
    _requisitosSegurancaController.addListener(_markDirty);
    _valorPvController.addListener(_markDirty);

    _isDirty = false;
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
      widget.onDirtyChanged?.call(true);
    }
  }

  void markClean() {
    if (_isDirty) {
      setState(() => _isDirty = false);
      widget.onDirtyChanged?.call(false);
    }
  }

  NotaSapAnalise buildAnalisePayload({
    required String notaSapId,
    required String numeroNota,
    String? analistaId,
    String? analistaNome,
  }) {
    final horas = double.tryParse(
            _estimativaHorasController.text.replaceAll(',', '.')) ??
        0.0;
    final tecnicos =
        int.tryParse(_quantidadeTecnicosController.text.trim()) ?? 0;

    var statusFinal = _status;
    if (statusFinal == NotaAnaliseStatus.naoIniciada) {
      statusFinal = NotaAnaliseStatus.emAnalise;
    }

    double? valorPv;
    if (_necessitaDesligamento && _valorPvController.text.trim().isNotEmpty) {
      final limpo = _valorPvController.text.trim().replaceAll('R\$', '').trim();
      if (limpo.contains(',') && limpo.contains('.')) {
        valorPv = double.tryParse(limpo.replaceAll('.', '').replaceAll(',', '.'));
      } else if (limpo.contains(',')) {
        valorPv = double.tryParse(limpo.replaceAll(',', '.'));
      } else {
        valorPv = double.tryParse(limpo);
      }
    }

    return NotaSapAnalise(
      id: widget.analiseInicial?.id,
      notaSapId: notaSapId,
      numeroNota: numeroNota,
      statusAnalise: statusFinal,
      diagnosticoPrevio: _diagnosticoController.text.trim().isEmpty
          ? null
          : _diagnosticoController.text.trim(),
      escopoDetalhado: _escopoController.text.trim().isEmpty
          ? null
          : _escopoController.text.trim(),
      observacoesPlanejamento: _observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim(),
      necessitaDesligamento: _necessitaDesligamento,
      necessitaBloqueio: false,
      valorPv: valorPv,
      estimativaHoras: horas,
      quantidadeTecnicos: tecnicos,
      ferramentasEspeciais: _ferramentasController.text.trim().isEmpty
          ? null
          : _ferramentasController.text.trim(),
      requisitosSeguranca: _requisitosSegurancaController.text.trim().isEmpty
          ? null
          : _requisitosSegurancaController.text.trim(),
      analistaId: analistaId ?? widget.analiseInicial?.analistaId,
      analistaNome: analistaNome ?? widget.analiseInicial?.analistaNome,
      createdAt: widget.analiseInicial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _diagnosticoController.dispose();
    _escopoController.dispose();
    _observacoesController.dispose();
    _estimativaHorasController.dispose();
    _quantidadeTecnicosController.dispose();
    _ferramentasController.dispose();
    _requisitosSegurancaController.dispose();
    _valorPvController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: spacing.md),
            Text('Carregando análise técnica...',
                style: typography.bodyMedium
                    .copyWith(color: colors.textSecondary)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSplit = constraints.maxWidth >= 1200;
        final isTablet =
            constraints.maxWidth >= 800 && constraints.maxWidth < 1200;

        if (isDesktopSplit) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lado Esquerdo: Formulário de Análise (60%)
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.md),
                  child: _buildFormularioConteudo(
                    context,
                    colors,
                    typography,
                    spacing,
                    true,
                    isDesktopSplit: true,
                  ),
                ),
              ),
              // Divisor vertical sutil
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colors.borderSubtle,
              ),
              // Lado Direito: Painel Contextual de Evidências (40%)
              Expanded(
                flex: 4,
                child: NotaWorkspaceContextualEvidencePanel(
                  notaSapId: _effectiveNotaSapId ?? '',
                  nota: widget.nota,
                  evidencias: _evidencias,
                  selectedEvidence: _evidenciaSelecionada,
                  activeSection: _secaoAtiva,
                  service: _analiseService,
                  isReadOnly: widget.isReadOnly,
                  onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                  onSelectEvidence: (ev) {
                    setState(() {
                      _evidenciaSelecionada = ev;
                      if (ev != null) _secaoAtiva = ev.tipoVinculo;
                    });
                  },
                  onRefreshEvidencias: _carregarEvidencias,
                  onVincularNovaEvidencia: (secao) => _abrirQuickAttach(secao),
                ),
              ),
            ],
          );
        }

        // Mobile ou Tablet (coluna única)
        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isTablet) ...[
                _buildTabletEvidenceHeader(
                    context, colors, typography, spacing),
                SizedBox(height: spacing.md),
              ],
              _buildFormularioConteudo(
                context,
                colors,
                typography,
                spacing,
                constraints.maxWidth >= 800,
                isDesktopSplit: false,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletEvidenceHeader(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_library_outlined, size: 20, color: colors.primary),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              'Evidências Contextuais (${_evidencias.length} vinculadas)',
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
            label: const Text('Inspecionar Evidências'),
            onPressed: () => _abrirDrawerEvidenciasTablet(context),
          ),
        ],
      ),
    );
  }

  void _abrirDrawerEvidenciasTablet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Painel Contextual de Evidências'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              body: NotaWorkspaceContextualEvidencePanel(
                notaSapId: _effectiveNotaSapId ?? '',
                nota: widget.nota,
                evidencias: _evidencias,
                selectedEvidence: _evidenciaSelecionada,
                activeSection: _secaoAtiva,
                service: _analiseService,
                isReadOnly: widget.isReadOnly,
                onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                onSelectEvidence: (ev) {
                  setState(() {
                    _evidenciaSelecionada = ev;
                    if (ev != null) _secaoAtiva = ev.tipoVinculo;
                  });
                },
                onRefreshEvidencias: _carregarEvidencias,
                onVincularNovaEvidencia: (secao) => _abrirQuickAttach(secao),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormularioConteudo(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
    bool isWide, {
    required bool isDesktopSplit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de status da análise e metadados
        _buildStatusBanner(context, colors, typography, spacing),

        SizedBox(height: spacing.md),

        // Checklist Informativo de Suficiência Técnica (Fase 4 - Não bloqueante)
        _buildChecklistInformativoEvidencias(colors, typography, spacing),

        SizedBox(height: spacing.md),

        // Seção: Diagnóstico e Escopo
        _buildCard(
          context,
          title: 'Diagnóstico e Escopo Técnico',
          icon: Icons.psychology_outlined,
          children: [
            Text(
              'Diagnóstico Prévio',
              style: typography.labelMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            TextFormField(
              controller: _diagnosticoController,
              maxLines: 3,
              style:
                  typography.bodyMedium.copyWith(color: colors.textPrimary),
              onTap: () {
                if (_secaoAtiva != NotaTipoVinculoEvidencia.diagnostico) {
                  setState(() =>
                      _secaoAtiva = NotaTipoVinculoEvidencia.diagnostico);
                }
              },
              decoration: InputDecoration(
                hintText:
                    'Descreva o diagnóstico prévio ou causas aparentes do defeito...',
                hintStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                filled: true,
                fillColor: colors.surfaceSecondary,
              ),
            ),
            // Evidências de Diagnóstico
            _buildFaixaEvidenciasSecao(
              NotaTipoVinculoEvidencia.diagnostico,
              colors,
              typography,
              spacing,
              isDesktopSplit: isDesktopSplit,
            ),

            SizedBox(height: spacing.md),
            Text(
              'Escopo Detalhado dos Serviços',
              style: typography.labelMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            TextFormField(
              controller: _escopoController,
              maxLines: 4,
              style:
                  typography.bodyMedium.copyWith(color: colors.textPrimary),
              onTap: () {
                if (_secaoAtiva != NotaTipoVinculoEvidencia.escopo) {
                  setState(() =>
                      _secaoAtiva = NotaTipoVinculoEvidencia.escopo);
                }
              },
              decoration: InputDecoration(
                hintText:
                    'Detalhamento das atividades, passo a passo técnico da intervenção...',
                hintStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                filled: true,
                fillColor: colors.surfaceSecondary,
              ),
            ),
            // Evidências de Escopo
            _buildFaixaEvidenciasSecao(
              NotaTipoVinculoEvidencia.escopo,
              colors,
              typography,
              spacing,
              isDesktopSplit: isDesktopSplit,
            ),

            SizedBox(height: spacing.md),
            Text(
              'Observações para o Planejador / Programador (Acesso & Logística)',
              style: typography.labelMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            TextFormField(
              controller: _observacoesController,
              maxLines: 2,
              style:
                  typography.bodyMedium.copyWith(color: colors.textPrimary),
              onTap: () {
                if (_secaoAtiva != NotaTipoVinculoEvidencia.acesso) {
                  setState(() =>
                      _secaoAtiva = NotaTipoVinculoEvidencia.acesso);
                }
              },
              decoration: InputDecoration(
                hintText:
                    'Orientações logísticas, melhores horários, janelas de operação...',
                hintStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                filled: true,
                fillColor: colors.surfaceSecondary,
              ),
            ),
            // Evidências de Acesso e Logística
            _buildFaixaEvidenciasSecao(
              NotaTipoVinculoEvidencia.acesso,
              colors,
              typography,
              spacing,
              isDesktopSplit: isDesktopSplit,
            ),
          ],
        ),

        SizedBox(height: spacing.md),

        // Seção: Requisitos Operacionais e Segurança (em 2 colunas se wide)
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCard(
                  context,
                  title: 'Desligamento e Segurança',
                  icon: Icons.power_off_outlined,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Necessita Desligamento?',
                        style: typography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Intervenção exige desenergização do ativo ou linha',
                        style: typography.caption
                            .copyWith(color: colors.textSecondary),
                      ),
                      value: _necessitaDesligamento,
                      activeThumbColor: Colors.red.shade700,
                      onChanged: (val) {
                        setState(() => _necessitaDesligamento = val);
                        _markDirty();
                      },
                    ),
                    if (_necessitaDesligamento) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        'Valor da Parcela Variável (PV)',
                        style: typography.labelMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      TextFormField(
                        controller: _valorPvController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: typography.bodyMedium
                            .copyWith(color: colors.textPrimary),
                        onTap: () {
                          if (_secaoAtiva !=
                              NotaTipoVinculoEvidencia.desligamento) {
                            setState(() => _secaoAtiva =
                                NotaTipoVinculoEvidencia.desligamento);
                          }
                        },
                        decoration: InputDecoration(
                          prefixText: 'R\$ ',
                          prefixStyle: typography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: '0,00',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          helperText:
                              'Impacto financeiro estimado de indisponibilidade da FT',
                          helperStyle: typography.caption
                              .copyWith(color: colors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(TFRadius.r8),
                            borderSide:
                                BorderSide(color: colors.borderSubtle),
                          ),
                          filled: true,
                          fillColor: colors.surfaceSecondary,
                        ),
                      ),
                    ],
                    Divider(color: colors.borderSubtle),
                    Text(
                      'Requisitos Especiais de Segurança',
                      style: typography.labelMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _requisitosSegurancaController,
                      maxLines: 3,
                      style: typography.bodyMedium
                          .copyWith(color: colors.textPrimary),
                      onTap: () {
                        if (_secaoAtiva !=
                            NotaTipoVinculoEvidencia.seguranca) {
                          setState(() => _secaoAtiva =
                              NotaTipoVinculoEvidencia.seguranca);
                        }
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Ex: APR específica, teste de ausência de tensão, aterramento...',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          borderSide: BorderSide(color: colors.borderSubtle),
                        ),
                        filled: true,
                        fillColor: colors.surfaceSecondary,
                      ),
                    ),
                    // Evidências de Segurança
                    _buildFaixaEvidenciasSecao(
                      NotaTipoVinculoEvidencia.seguranca,
                      colors,
                      typography,
                      spacing,
                      isDesktopSplit: isDesktopSplit,
                    ),
                    // Evidências de Desligamento
                    _buildFaixaEvidenciasSecao(
                      NotaTipoVinculoEvidencia.desligamento,
                      colors,
                      typography,
                      spacing,
                      isDesktopSplit: isDesktopSplit,
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _buildCard(
                  context,
                  title: 'Estimativas e Recursos',
                  icon: Icons.timer_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimativa (Horas)',
                                style: typography.labelMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              TextFormField(
                                controller: _estimativaHorasController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: typography.bodyMedium
                                    .copyWith(color: colors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 3.5',
                                  suffixText: 'h',
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                    borderSide: BorderSide(
                                        color: colors.borderSubtle),
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qtd. Técnicos',
                                style: typography.labelMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              TextFormField(
                                controller: _quantidadeTecnicosController,
                                keyboardType: TextInputType.number,
                                style: typography.bodyMedium
                                    .copyWith(color: colors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 2',
                                  suffixText: 'tec.',
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(TFRadius.r8),
                                    borderSide: BorderSide(
                                        color: colors.borderSubtle),
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Ferramentas e Equipamentos Especiais',
                      style: typography.labelMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    TextFormField(
                      controller: _ferramentasController,
                      maxLines: 4,
                      style: typography.bodyMedium
                          .copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText:
                            'Ex: Caminhão cesto, torquímetro calibrado, alicate prensa terminal...',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          borderSide: BorderSide(color: colors.borderSubtle),
                        ),
                        filled: true,
                        fillColor: colors.surfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildCard(
            context,
            title: 'Desligamento e Segurança',
            icon: Icons.power_off_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Necessita Desligamento?',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Intervenção exige desenergização do ativo ou linha',
                  style:
                      typography.caption.copyWith(color: colors.textSecondary),
                ),
                value: _necessitaDesligamento,
                activeThumbColor: Colors.red.shade700,
                onChanged: (val) {
                  setState(() => _necessitaDesligamento = val);
                  _markDirty();
                },
              ),
              if (_necessitaDesligamento) ...[
                SizedBox(height: spacing.xs),
                Text(
                  'Valor da Parcela Variável (PV)',
                  style: typography.labelMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing.xs),
                TextFormField(
                  controller: _valorPvController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: typography.bodyMedium
                      .copyWith(color: colors.textPrimary),
                  onTap: () {
                    if (_secaoAtiva !=
                        NotaTipoVinculoEvidencia.desligamento) {
                      setState(() => _secaoAtiva =
                          NotaTipoVinculoEvidencia.desligamento);
                    }
                  },
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    prefixStyle: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    hintText: '0,00',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    helperText:
                        'Impacto financeiro estimado de indisponibilidade da FT',
                    helperStyle: typography.caption
                        .copyWith(color: colors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      borderSide:
                          BorderSide(color: colors.borderSubtle),
                    ),
                    filled: true,
                    fillColor: colors.surfaceSecondary,
                  ),
                ),
              ],
              Divider(color: colors.borderSubtle),
              Text(
                'Requisitos Especiais de Segurança',
                style: typography.labelMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.xs),
              TextFormField(
                controller: _requisitosSegurancaController,
                maxLines: 3,
                style: typography.bodyMedium
                    .copyWith(color: colors.textPrimary),
                onTap: () {
                  if (_secaoAtiva !=
                      NotaTipoVinculoEvidencia.seguranca) {
                    setState(() => _secaoAtiva =
                        NotaTipoVinculoEvidencia.seguranca);
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Ex: APR específica, teste de ausência de tensão, aterramento...',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  filled: true,
                  fillColor: colors.surfaceSecondary,
                ),
              ),
              // Evidências de Segurança
              _buildFaixaEvidenciasSecao(
                NotaTipoVinculoEvidencia.seguranca,
                colors,
                typography,
                spacing,
                isDesktopSplit: isDesktopSplit,
              ),
              // Evidências de Desligamento
              _buildFaixaEvidenciasSecao(
                NotaTipoVinculoEvidencia.desligamento,
                colors,
                typography,
                spacing,
                isDesktopSplit: isDesktopSplit,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _buildCard(
            context,
            title: 'Estimativas e Recursos',
            icon: Icons.timer_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimativa (Horas)',
                          style: typography.labelMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        TextFormField(
                          controller: _estimativaHorasController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: typography.bodyMedium
                              .copyWith(color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Ex: 3.5',
                            suffixText: 'h',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(TFRadius.r8),
                              borderSide:
                                  BorderSide(color: colors.borderSubtle),
                            ),
                            filled: true,
                            fillColor: colors.surfaceSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qtd. Técnicos',
                          style: typography.labelMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        TextFormField(
                          controller: _quantidadeTecnicosController,
                          keyboardType: TextInputType.number,
                          style: typography.bodyMedium
                              .copyWith(color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Ex: 2',
                            suffixText: 'tec.',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(TFRadius.r8),
                              borderSide:
                                  BorderSide(color: colors.borderSubtle),
                            ),
                            filled: true,
                            fillColor: colors.surfaceSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              Text(
                'Ferramentas e Equipamentos Especiais',
                style: typography.labelMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.xs),
              TextFormField(
                controller: _ferramentasController,
                maxLines: 3,
                style: typography.bodyMedium
                    .copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      'Ex: Caminhão cesto, torquímetro calibrado, alicate prensa terminal...',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  filled: true,
                  fillColor: colors.surfaceSecondary,
                ),
              ),
            ],
          ),
        ],

        SizedBox(height: spacing.md),

        // Seção: Outras Evidências Técnicas (tipo: outro)
        _buildCard(
          context,
          title: 'Outras Evidências Técnicas (Complementares)',
          icon: Icons.folder_special_outlined,
          children: [
            Text(
              'Evidências complementares vinculadas à Nota SAP que apoiam o parecer técnico geral.',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            _buildFaixaEvidenciasSecao(
              NotaTipoVinculoEvidencia.outro,
              colors,
              typography,
              spacing,
              isDesktopSplit: isDesktopSplit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: spacing.sm,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Status da Análise:',
                      style: typography.labelMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<NotaAnaliseStatus>(
                        value: _status,
                        isDense: true,
                        borderRadius: BorderRadius.circular(TFRadius.r8),
                        items: NotaAnaliseStatus.values.map((s) {
                          return DropdownMenuItem<NotaAnaliseStatus>(
                            value: s,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(s),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: spacing.xs),
                                Text(
                                  s.label,
                                  style: typography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (novo) {
                          if (novo != null && novo != _status) {
                            setState(() => _status = novo);
                            _markDirty();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.analiseInicial != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    'Analista: ${widget.analiseInicial?.analistaNome ?? 'Não informado'} • Atualizado em: ${_formatDate(widget.analiseInicial?.updatedAt)}',
                    style: typography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ] else ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    'Nenhuma análise salva para esta Nota. Preencha os campos e salve quando desejar.',
                    style: typography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (_isDirty)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 16, color: Colors.amber.shade800),
                  SizedBox(width: spacing.xs),
                  Text(
                    'Alterações não salvas',
                    style: typography.caption.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(NotaAnaliseStatus s) {
    switch (s) {
      case NotaAnaliseStatus.naoIniciada:
        return Colors.grey.shade500;
      case NotaAnaliseStatus.emAnalise:
        return Colors.blue.shade600;
      case NotaAnaliseStatus.concluida:
        return Colors.green.shade600;
      case NotaAnaliseStatus.aguardandoInformacao:
        return Colors.orange.shade700;
      case NotaAnaliseStatus.cancelada:
        return Colors.red.shade600;
    }
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.primary),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: typography.sectionTitle.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: spacing.lg, color: colors.borderSubtle),
            ...children,
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EVIDÊNCIAS TÉCNICAS INTEGRADAS À ANÁLISE (FASE 4)
  // ---------------------------------------------------------------------------

  /// Constrói uma faixa compacta de evidências vinculadas a uma seção da análise
  Widget _buildFaixaEvidenciasSecao(
    NotaTipoVinculoEvidencia tipo,
    dynamic colors,
    dynamic typography,
    dynamic spacing, {
    bool isDesktopSplit = false,
  }) {
    final evidenciasDestaSecao =
        _evidencias.where((e) => e.tipoVinculo == tipo).toList();
    final isSecaoEmFoco = _secaoAtiva == tipo;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: () => setState(() => _secaoAtiva = tipo),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attachment,
                        size: 14,
                        color: isSecaoEmFoco ? colors.primary : Colors.purple.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Evidências associadas (${evidenciasDestaSecao.length})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSecaoEmFoco
                              ? colors.primary
                              : Colors.purple.shade800,
                        ),
                      ),
                      if (isSecaoEmFoco) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: colors.primary.withAlpha(80), width: 0.6),
                          ),
                          child: Text(
                            'Em Foco',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (evidenciasDestaSecao.isEmpty && !isSecaoEmFoco) ...[
                Text(
                  '• Nenhuma evidência vinculada',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (!widget.isReadOnly)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _secaoAtiva = tipo);
                    _abrirQuickAttach(tipo);
                  },
                  icon: const Icon(Icons.add_link, size: 14),
                  label: const Text('Vincular Evidência',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (evidenciasDestaSecao.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: evidenciasDestaSecao.map((ev) {
                return _buildCardCompactoEvidencia(
                  ev,
                  colors,
                  typography,
                  isDesktopSplit: isDesktopSplit,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Card compacto da evidência vinculada à seção técnica (suporta Anexo da Nota, Álbum e Anexo Histórico)
  Widget _buildCardCompactoEvidencia(
    NotaSapAnaliseEvidencia ev,
    dynamic colors,
    dynamic typography, {
    bool isDesktopSplit = false,
  }) {
    final isAlbum = ev.isFotoAlbum;
    final isHist = ev.isAnexoHistorico;
    final anexo = ev.anexo;
    final nome = ev.tituloExibicao;
    final versaoStr = ev.rotuloVersao;
    final hasNovaVersao = ev.hasVersaoMaisRecente;
    final isSelected = isDesktopSplit && _evidenciaSelecionada?.id == ev.id;

    final dataFormatada = ev.dataRegistro != null
        ? DateFormat('dd/MM/yyyy').format(ev.dataRegistro!)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isDesktopSplit) {
            _selecionarEvidencia(ev);
          } else {
            _abrirViewerEvidencia(ev);
          }
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withAlpha(15) : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : hasNovaVersao
                      ? Colors.amber.shade600
                      : isHist
                          ? Colors.amber.shade400
                          : isAlbum
                              ? Colors.blue.shade300
                              : Colors.purple.shade200,
              width: isSelected ? 2.0 : (hasNovaVersao ? 1.4 : 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? colors.primary.withAlpha(25)
                    : Colors.black.withAlpha(8),
                blurRadius: isSelected ? 6 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Linha Superior: Proveniência + Versão/Data + Menu
              Row(
                children: [
                  Icon(
                    isHist
                        ? Icons.history_edu
                        : (isAlbum
                            ? Icons.photo_library_outlined
                            : (anexo?.tipoArquivo == NotaAnexoTipo.imagem
                                ? Icons.image_outlined
                                : Icons.description_outlined)),
                    size: 15,
                    color: isHist
                        ? Colors.amber.shade800
                        : (isAlbum ? Colors.blue.shade700 : colors.primary),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isHist
                          ? Colors.amber.shade50
                          : (isAlbum ? Colors.blue.shade50 : Colors.purple.shade50),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isHist
                            ? Colors.amber.shade300
                            : (isAlbum
                                ? Colors.blue.shade200
                                : Colors.purple.shade200),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      isHist
                          ? '🏛️ Nota ${ev.numeroNotaHistorica ?? "Histórica"}'
                          : (isAlbum ? '📷 Álbum' : '📎 Anexo'),
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        color: isHist
                            ? Colors.amber.shade900
                            : (isAlbum ? Colors.blue.shade900 : Colors.purple.shade900),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isAlbum) ...[
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: ev.isComAnotacao
                            ? Colors.teal.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: ev.isComAnotacao
                              ? Colors.teal.shade400
                              : Colors.grey.shade300,
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        versaoStr,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: ev.isComAnotacao
                              ? Colors.teal.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ] else if (dataFormatada != null) ...[
                    Text(
                      dataFormatada,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 16, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'abrir') {
                        _abrirViewerEvidencia(ev);
                      } else if (val == 'desvincular') {
                        _desvincularEvidencia(ev);
                      } else if (val == 'usar_mais_recente') {
                        _atualizarParaVersaoMaisRecente(ev);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'abrir',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 14),
                            SizedBox(width: 6),
                            Text('Abrir Evidência',
                                style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      if (hasNovaVersao)
                        PopupMenuItem(
                          value: 'usar_mais_recente',
                          child: Row(
                            children: [
                              Icon(Icons.upgrade,
                                  size: 14, color: Colors.amber.shade900),
                              SizedBox(width: 6),
                              Text('Usar v${ev.versaoMaisRecenteAnexo}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber.shade900)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'desvincular',
                        child: Row(
                          children: [
                            Icon(Icons.link_off, size: 14, color: Colors.red),
                            SizedBox(width: 6),
                            Text('Desvincular desta seção',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Título da Evidência
              Tooltip(
                message: nome,
                child: Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Observação Contextual da Evidência
              if (ev.observacao != null && ev.observacao!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  ev.observacao!.trim(),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Alerta Não Bloqueante de Nova Versão Disponível (Apenas Anexo)
              if (hasNovaVersao) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 12, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Versão v${ev.versaoMaisRecenteAnexo} disponível',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _atualizarParaVersaoMaisRecente(ev),
                        child: Text(
                          'Usar v${ev.versaoMaisRecenteAnexo}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Botão Rápido para Visualizar na versão exata
              InkWell(
                onTap: () {
                  if (isDesktopSplit) {
                    _selecionarEvidencia(ev);
                  } else {
                    _abrirViewerEvidencia(ev);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isDesktopSplit ? 'Visualizar no painel' : 'Inspecionar',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isAlbum ? Colors.blue.shade800 : colors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 9,
                      color: isAlbum ? Colors.blue.shade800 : colors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Abre o visualizador correto para a fonte da evidência
  Future<void> _abrirViewerEvidencia(NotaSapAnaliseEvidencia ev) async {
    if (ev.isFotoAlbum) {
      await _abrirViewerFotoAlbum(ev);
    } else {
      final anexo = ev.anexo;
      if (anexo == null) return;

      await NotaAnexoViewerDialog.abrir(
        context: context,
        anexos: [anexo],
        indiceInicial: 0,
        contextoFiltro: ev.isAnexoHistorico
            ? 'Evidência Histórica - ${ev.tipoVinculo.labelCurto}'
            : 'Evidência - ${ev.tipoVinculo.labelCurto}',
        service: _analiseService,
        isHistoricoReadOnly: ev.isAnexoHistorico,
        notaHistoricaNumero: ev.numeroNotaHistorica,
        notaAtual: widget.nota,
      );
    }
  }

  /// Visualizador dedicado para fotografia histórica do módulo de álbuns
  Future<void> _abrirViewerFotoAlbum(NotaSapAnaliseEvidencia ev) async {
    final img = ev.mediaImage;
    if (img == null) return;

    final repo = SupabaseMediaRepository();
    final url = repo.getPublicUrl(img.filePath);
    final dataStr = ev.dataRegistro != null
        ? DateFormat('dd/MM/yyyy').format(ev.dataRegistro!)
        : 'Data não informada';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.photo_library, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Álbum de Campo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${ev.tituloExibicao} • $dataStr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        );
                      },
                      errorBuilder: (c, e, s) => const Center(
                        child: Text(
                          'Erro ao carregar imagem do álbum',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (ev.observacao != null && ev.observacao!.trim().isNotEmpty)
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  child: Text(
                    'Observação da Análise: ${ev.observacao!.trim()}',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Atualiza explicitamente a versão do vínculo para a mais recente
  Future<void> _atualizarParaVersaoMaisRecente(NotaSapAnaliseEvidencia ev) async {
    if (ev.id == null || ev.anexoId == null || ev.versaoMaisRecenteAnexo == null) return;
    try {
      await _analiseService.atualizarVersaoVinculada(
        evidenciaId: ev.id!,
        anexoId: ev.anexoId!,
        novaVersao: ev.versaoMaisRecenteAnexo!,
      );
      _carregarEvidencias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Evidência atualizada para v${ev.versaoMaisRecenteAnexo} com sucesso!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar versão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Desvincula evidência desta seção técnica
  Future<void> _desvincularEvidencia(NotaSapAnaliseEvidencia ev) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Evidência'),
        content: Text(
          'Deseja remover o vínculo desta evidência com a seção ${ev.tipoVinculo.labelCurto}?\nO arquivo original permanecerá intacto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      try {
        await _analiseService.desvincularEvidencia(
          notaSapId: ev.notaSapId,
          tipoFonte: ev.tipoFonte,
          anexoId: ev.anexoId,
          mediaImageId: ev.mediaImageId,
          tipoVinculo: ev.tipoVinculo,
        );
        _carregarEvidencias();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evidência desvinculada com sucesso'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao desvincular evidência: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Painel de checklist informativo de evidências associadas
  Widget _buildChecklistInformativoEvidencias(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    int totalDiagnostico =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.diagnostico).length;
    int totalEscopo =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.escopo).length;
    int totalMateriais =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.materiais).length;
    int totalSeguranca =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.seguranca).length;
    int totalDesligamento =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.desligamento).length;
    int totalAcesso =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.acesso).length;
    int totalOutro =
        _evidencias.where((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.outro).length;

    final itens = [
      ('Diagnóstico', totalDiagnostico),
      ('Escopo', totalEscopo),
      ('Materiais', totalMateriais),
      ('Segurança', totalSeguranca),
      ('Desligamento', totalDesligamento),
      ('Acesso', totalAcesso),
      if (totalOutro > 0) ('Outras', totalOutro),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Suficiência Técnica — Evidências Associadas',
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (_isLoadingEvidencias) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Informativo (Não bloqueante)',
                style: TextStyle(fontSize: 10, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: itens.map((item) {
              final temEvidencia = item.$2 > 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: temEvidencia ? Colors.purple.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: temEvidencia ? Colors.purple.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: temEvidencia ? Colors.purple.shade900 : colors.textSecondary,
                        fontWeight: temEvidencia ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.$2}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: temEvidencia ? Colors.purple.shade900 : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
