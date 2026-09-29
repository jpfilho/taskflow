import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import '../../models/projeto_marco.dart';
import '../../models/projeto_risco.dart';
import '../../services/projeto_service.dart';

class MarcosRiscosTab extends StatelessWidget {
  final Projeto projeto;
  final ProjetoService service;

  const MarcosRiscosTab({super.key, required this.projeto, required this.service});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: colors.surface,
            child: TabBar(
              labelColor: colors.primary,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: colors.primary,
              labelStyle: typography.labelMedium.copyWith(fontWeight: FontWeight.bold),
              unselectedLabelStyle: typography.labelMedium,
              tabs: const [
                Tab(text: 'Marcos (Milestones)', icon: Icon(Icons.flag_rounded, size: 18)),
                Tab(text: 'Riscos do Projeto', icon: Icon(TFIcons.warning, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MarcosList(projeto: projeto, service: service),
                _RiscosList(projeto: projeto, service: service),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MarcosList extends StatefulWidget {
  final Projeto projeto;
  final ProjetoService service;

  const _MarcosList({required this.projeto, required this.service});

  @override
  State<_MarcosList> createState() => _MarcosListState();
}

class _MarcosListState extends State<_MarcosList> {
  List<ProjetoMarco> _marcos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      _marcos = await widget.service.getMarcos(widget.projeto.id);
    } catch (e) {
      debugPrint('Erro ao carregar marcos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novo() async {
    final res = await showDialog<ProjetoMarco>(
      context: context,
      builder: (_) => MarcoFormDialog(projetoId: widget.projeto.id),
    );
    if (res != null) {
      await widget.service.createMarco(res);
      _carregar();
    }
  }

  void _editar(ProjetoMarco marco) async {
    final res = await showDialog<ProjetoMarco>(
      context: context,
      builder: (_) => MarcoFormDialog(projetoId: widget.projeto.id, marco: marco),
    );
    if (res != null) {
      await widget.service.updateMarco(res);
      _carregar();
    }
  }

  void _excluir(ProjetoMarco marco) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir Marco',
      message: 'Tem certeza que deseja excluir o marco "${marco.nome}"?',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );
    if (confirm == true) {
      await widget.service.deleteMarco(marco.id);
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Carregando marcos...'));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Marcos Principais',
                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              TFButton(
                label: 'Novo Marco',
                leadingIcon: TFIcons.add,
                onPressed: _novo,
              ),
            ],
          ),
        ),
        Expanded(
          child: _marcos.isEmpty
              ? Center(
                  child: TFEmptyState(
                    title: 'Nenhum marco cadastrado',
                    description: 'Registre entregas críticas e marcos estratégicos para o cronograma.',
                    icon: Icons.flag_rounded,
                    action: TFButton(
                      label: 'Novo Marco',
                      leadingIcon: TFIcons.add,
                      onPressed: _novo,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                  itemCount: _marcos.length,
                  separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                  itemBuilder: (context, index) {
                    final m = _marcos[index];
                    return TFCard(
                      padding: EdgeInsets.all(spacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, color: colors.success, size: 22),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.nome,
                                  style: typography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: spacing.xxs),
                                TFStatusBadge(
                                  label: m.status,
                                  severity: m.status == 'CONCLUIDO' || m.status == 'CONCLUIDA'
                                      ? TFStatusSeverity.success
                                      : TFStatusSeverity.warning,
                                ),
                              ],
                            ),
                          ),
                          TFIconButton(
                            icon: TFIcons.edit,
                            tooltip: 'Editar Marco',
                            onPressed: () => _editar(m),
                          ),
                          TFIconButton(
                            icon: TFIcons.delete,
                            tooltip: 'Excluir Marco',
                            onPressed: () => _excluir(m),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MarcoFormDialog extends StatefulWidget {
  final String projetoId;
  final ProjetoMarco? marco;

  const MarcoFormDialog({super.key, required this.projetoId, this.marco});

  @override
  State<MarcoFormDialog> createState() => _MarcoFormDialogState();
}

class _MarcoFormDialogState extends State<MarcoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  String _status = 'PENDENTE';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.marco?.nome ?? '');
    if (widget.marco != null) {
      _status = widget.marco!.status;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: widget.marco == null ? 'Novo Marco' : 'Editar Marco',
      subtitle: 'Defina o nome e status do ponto de controle.',
      isSaving: _isSaving,
      onSave: () {
        if (_formKey.currentState!.validate()) {
          setState(() => _isSaving = true);
          Navigator.of(context).pop(ProjetoMarco(
            id: widget.marco?.id ?? '',
            projetoId: widget.projetoId,
            nome: _nomeController.text.trim(),
            status: _status,
          ));
        }
      },
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TFTextField(
              controller: _nomeController,
              label: 'Nome do Marco *',
              hint: 'Ex: Energização da Subestação',
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
            ),
            SizedBox(height: spacing.sm),
            TFDropdown<String>(
              label: 'Status',
              value: _status,
              items: const [
                'PENDENTE',
                'EM_ANDAMENTO',
                'CONCLUIDO',
                'CANCELADO',
              ],
              displayText: (e) => e,
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RiscosList extends StatefulWidget {
  final Projeto projeto;
  final ProjetoService service;

  const _RiscosList({required this.projeto, required this.service});

  @override
  State<_RiscosList> createState() => _RiscosListState();
}

class _RiscosListState extends State<_RiscosList> {
  List<ProjetoRisco> _riscos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      _riscos = await widget.service.getRiscos(widget.projeto.id);
    } catch (e) {
      debugPrint('Erro ao carregar riscos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novo() async {
    final res = await showDialog<ProjetoRisco>(
      context: context,
      builder: (_) => RiscoFormDialog(projetoId: widget.projeto.id),
    );
    if (res != null) {
      await widget.service.createRisco(res);
      _carregar();
    }
  }

  void _editar(ProjetoRisco risco) async {
    final res = await showDialog<ProjetoRisco>(
      context: context,
      builder: (_) => RiscoFormDialog(projetoId: widget.projeto.id, risco: risco),
    );
    if (res != null) {
      await widget.service.updateRisco(res);
      _carregar();
    }
  }

  void _excluir(ProjetoRisco risco) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir Risco',
      message: 'Tem certeza que deseja excluir o risco "${risco.titulo}"?',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );
    if (confirm == true) {
      await widget.service.deleteRisco(risco.id);
      _carregar();
    }
  }

  TFStatusSeverity _mapImpacto(String? impacto) {
    switch (impacto?.toUpperCase().trim()) {
      case 'ALTO':
      case 'CRITICO':
      case 'CRÍTICO':
        return TFStatusSeverity.danger;
      case 'MEDIO':
      case 'MÉDIO':
        return TFStatusSeverity.warning;
      case 'BAIXO':
        return TFStatusSeverity.neutral;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Carregando riscos...'));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Matriz de Riscos',
                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              TFButton(
                label: 'Novo Risco',
                leadingIcon: TFIcons.add,
                onPressed: _novo,
              ),
            ],
          ),
        ),
        Expanded(
          child: _riscos.isEmpty
              ? Center(
                  child: TFEmptyState(
                    title: 'Nenhum risco cadastrado',
                    description: 'Identifique riscos operacionais, probabilidade e impacto estimado.',
                    icon: TFIcons.warning,
                    action: TFButton(
                      label: 'Novo Risco',
                      leadingIcon: TFIcons.add,
                      onPressed: _novo,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                  itemCount: _riscos.length,
                  separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                  itemBuilder: (context, index) {
                    final r = _riscos[index];
                    return TFCard(
                      padding: EdgeInsets.all(spacing.sm),
                      child: Row(
                        children: [
                          Icon(TFIcons.warning, color: colors.warning, size: 22),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.titulo,
                                  style: typography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: spacing.xxs),
                                Wrap(
                                  spacing: spacing.xs,
                                  runSpacing: spacing.xxs,
                                  children: [
                                    TFStatusBadge(
                                      label: 'Impacto: ${r.impacto}',
                                      severity: _mapImpacto(r.impacto),
                                    ),
                                    TFStatusBadge(
                                      label: 'Probabilidade: ${r.probabilidade}',
                                      severity: TFStatusSeverity.neutral,
                                    ),
                                    TFStatusBadge(
                                      label: r.status,
                                      severity: TFStatusSeverity.info,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          TFIconButton(
                            icon: TFIcons.edit,
                            tooltip: 'Editar Risco',
                            onPressed: () => _editar(r),
                          ),
                          TFIconButton(
                            icon: TFIcons.delete,
                            tooltip: 'Excluir Risco',
                            onPressed: () => _excluir(r),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class RiscoFormDialog extends StatefulWidget {
  final String projetoId;
  final ProjetoRisco? risco;

  const RiscoFormDialog({super.key, required this.projetoId, this.risco});

  @override
  State<RiscoFormDialog> createState() => _RiscoFormDialogState();
}

class _RiscoFormDialogState extends State<RiscoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  String _probabilidade = 'MEDIA';
  String _impacto = 'MEDIO';
  String _status = 'IDENTIFICADO';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.risco?.titulo ?? '');
    if (widget.risco != null) {
      _probabilidade = widget.risco!.probabilidade ?? 'MEDIA';
      _impacto = widget.risco!.impacto ?? 'MEDIO';
      _status = widget.risco!.status;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: widget.risco == null ? 'Novo Risco' : 'Editar Risco',
      subtitle: 'Registre os parâmetros e impacto do risco operacional.',
      isSaving: _isSaving,
      onSave: () {
        if (_formKey.currentState!.validate()) {
          setState(() => _isSaving = true);
          Navigator.of(context).pop(ProjetoRisco(
            id: widget.risco?.id ?? '',
            projetoId: widget.projetoId,
            titulo: _tituloController.text.trim(),
            probabilidade: _probabilidade,
            impacto: _impacto,
            status: _status,
          ));
        }
      },
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TFTextField(
              controller: _tituloController,
              label: 'Título / Descrição do Risco *',
              hint: 'Ex: Atraso no fornecimento de cabos',
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: TFDropdown<String>(
                    label: 'Probabilidade',
                    value: _probabilidade,
                    items: const [
                      'BAIXA',
                      'MEDIA',
                      'ALTA',
                    ],
                    displayText: (e) => e,
                    onChanged: (v) {
                      if (v != null) setState(() => _probabilidade = v);
                    },
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: TFDropdown<String>(
                    label: 'Impacto',
                    value: _impacto,
                    items: const [
                      'BAIXO',
                      'MEDIO',
                      'ALTO',
                    ],
                    displayText: (e) => e,
                    onChanged: (v) {
                      if (v != null) setState(() => _impacto = v);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            TFDropdown<String>(
              label: 'Status do Risco',
              value: _status,
              items: const [
                'IDENTIFICADO',
                'MITIGADO',
                'OCORRIDO',
                'CANCELADO',
              ],
              displayText: (e) => e,
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
