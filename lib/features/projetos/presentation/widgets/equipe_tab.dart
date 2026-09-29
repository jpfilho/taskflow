import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import '../../models/projeto_membro.dart';
import '../../services/projeto_service.dart';

class EquipeTab extends StatefulWidget {
  final Projeto projeto;
  final ProjetoService service;

  const EquipeTab({super.key, required this.projeto, required this.service});

  @override
  State<EquipeTab> createState() => _EquipeTabState();
}

class _EquipeTabState extends State<EquipeTab> {
  List<ProjetoMembro> _membros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      _membros = await widget.service.getMembros(widget.projeto.id);
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novoMembro() async {
    final p = await showDialog<ProjetoMembro>(
      context: context,
      builder: (_) => MembroFormDialog(projetoId: widget.projeto.id),
    );
    if (p != null) {
      await widget.service.addMembro(p);
      _carregar();
    }
  }

  void _editarMembro(ProjetoMembro membro) async {
    final p = await showDialog<ProjetoMembro>(
      context: context,
      builder: (_) => MembroFormDialog(projetoId: widget.projeto.id, membro: membro),
    );
    if (p != null) {
      if (membro.id.isNotEmpty) {
        await widget.service.removeMembro(membro.id);
      }
      await widget.service.addMembro(p);
      _carregar();
    }
  }

  void _removerMembro(ProjetoMembro membro) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Remover Membro',
      message: 'Tem certeza que deseja remover ${membro.usuarioId} da equipe deste projeto?',
      confirmLabel: 'Remover',
      isDestructive: true,
    );
    if (confirm == true) {
      await widget.service.removeMembro(membro.id);
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Carregando membros da equipe...'));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Equipe do Projeto',
                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              TFButton(
                label: 'Adicionar Membro',
                leadingIcon: TFIcons.add,
                onPressed: _novoMembro,
              ),
            ],
          ),
        ),
        Expanded(
          child: _membros.isEmpty
              ? Center(
                  child: TFEmptyState(
                    title: 'Nenhum membro adicionado',
                    description: 'Adicione colaboradores e defina papéis para a equipe do projeto.',
                    icon: TFIcons.team,
                    action: TFButton(
                      label: 'Adicionar Membro',
                      leadingIcon: TFIcons.add,
                      onPressed: _novoMembro,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                  itemCount: _membros.length,
                  separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                  itemBuilder: (context, index) {
                    final membro = _membros[index];
                    return TFCard(
                      padding: EdgeInsets.all(spacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(TFIcons.team, size: 20, color: colors.primary),
                          ),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  membro.usuarioId,
                                  style: typography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: spacing.xxs),
                                Text(
                                  'Papel: ${membro.papel}',
                                  style: typography.caption.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TFIconButton(
                            icon: TFIcons.edit,
                            tooltip: 'Editar Membro',
                            onPressed: () => _editarMembro(membro),
                          ),
                          TFIconButton(
                            icon: TFIcons.delete,
                            tooltip: 'Remover Membro',
                            onPressed: () => _removerMembro(membro),
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

class MembroFormDialog extends StatefulWidget {
  final String projetoId;
  final ProjetoMembro? membro;

  const MembroFormDialog({super.key, required this.projetoId, this.membro});

  @override
  State<MembroFormDialog> createState() => _MembroFormDialogState();
}

class _MembroFormDialogState extends State<MembroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usuarioIdController;
  late TextEditingController _papelController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usuarioIdController = TextEditingController(text: widget.membro?.usuarioId ?? '');
    _papelController = TextEditingController(text: widget.membro?.papel ?? '');
  }

  @override
  void dispose() {
    _usuarioIdController.dispose();
    _papelController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final m = ProjetoMembro(
        id: widget.membro?.id ?? '',
        projetoId: widget.projetoId,
        usuarioId: _usuarioIdController.text.trim(),
        papel: _papelController.text.trim(),
        podeVisualizar: widget.membro?.podeVisualizar ?? true,
        podeEditar: widget.membro?.podeEditar ?? false,
        podePlanejar: widget.membro?.podePlanejar ?? false,
        podeAprovar: widget.membro?.podeAprovar ?? false,
        podeEncerrar: widget.membro?.podeEncerrar ?? false,
      );
      Navigator.of(context).pop(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: widget.membro == null ? 'Adicionar Membro' : 'Editar Membro',
      subtitle: widget.membro == null
          ? 'Vincule um profissional e seu papel na equipe.'
          : 'Atualize os dados do membro na equipe.',
      isSaving: _isSaving,
      onSave: _salvar,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TFTextField(
              controller: _usuarioIdController,
              label: 'Identificação / Nome do Usuário *',
              hint: 'Ex: Carlos Silva ou user_id',
              validator: (v) => v == null || v.trim().isEmpty ? 'Identificação é obrigatória' : null,
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _papelController,
              label: 'Papel no Projeto *',
              hint: 'Ex: Engenheiro Responsável, Supervisor de Linha',
              validator: (v) => v == null || v.trim().isEmpty ? 'Papel é obrigatório' : null,
            ),
          ],
        ),
      ),
    );
  }
}
