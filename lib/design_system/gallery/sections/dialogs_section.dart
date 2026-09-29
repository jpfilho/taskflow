import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../components/dialogs/tf_modal_dialog.dart';
import '../../components/dialogs/tf_form_dialog.dart';
import '../../components/inputs/tf_text_field.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class DialogsSection extends StatelessWidget {
  const DialogsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFModalDialog — Modais & Diálogos',
      description: 'Estrutura modal padronizada com cabeçalho semântico, área de rolagem isolada e barra de ações padronizada.',
      children: [
        GalleryPreviewCard(
          title: 'Gatilhos Interativos de Diálogos',
          description: 'Clique para abrir os diferentes tamanhos e severidades em tela cheia',
          child: Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: [
              TFButton(
                label: 'Abrir Modal Pequeno (Confirmação)',
                variant: TFButtonVariant.secondary,
                leadingIcon: TFIcons.info,
                onPressed: () {
                  TFModalDialog.show(
                    context: context,
                    title: 'Confirmar Ação',
                    subtitle: 'Esta operação alterará o status da tarefa.',
                    size: TFDialogSize.small,
                    content: const Text(
                      'Deseja realmente marcar esta tarefa operacional como Concluída?',
                    ),
                    primaryAction: TFButton(
                      label: 'Confirmar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    secondaryAction: TFButton(
                      label: 'Cancelar',
                      variant: TFButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  );
                },
              ),
              TFButton(
                label: 'Abrir Modal Médio (Formulário)',
                variant: TFButtonVariant.primary,
                leadingIcon: TFIcons.edit,
                onPressed: () {
                  TFModalDialog.show(
                    context: context,
                    title: 'Cadastro de Função',
                    subtitle: 'Preencha os dados do cargo para sincronização com o SAP RH.',
                    size: TFDialogSize.medium,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TFTextField(
                          label: 'Nome da Função',
                          hint: 'Ex: Eletricista de Linha Viva',
                          required: true,
                        ),
                        SizedBox(height: spacing.md),
                        const TFTextField(
                          label: 'Descrição das Atividades',
                          hint: 'Atribuições e qualificações técnicas...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                    primaryAction: TFButton(
                      label: 'Salvar Função',
                      leadingIcon: TFIcons.save,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    secondaryAction: TFButton(
                      label: 'Cancelar',
                      variant: TFButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  );
                },
              ),
              TFButton(
                label: 'Diálogo de Exclusão (Perigo)',
                variant: TFButtonVariant.danger,
                leadingIcon: TFIcons.delete,
                onPressed: () async {
                  await TFModalDialog.confirm(
                    context: context,
                    title: 'Excluir Função',
                    message: 'Deseja realmente excluir a função "Eletricista de Subestação"? Esta ação não pode ser desfeita.',
                    confirmLabel: 'Excluir Definitivamente',
                    isDestructive: true,
                  );
                },
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Anatomia Estrutural do TFModalDialog',
          description: 'Visualização da composição de cabeçalho, corpo e rodapé de ações',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: TFModalDialog(
              title: 'Anatomia do Componente',
              subtitle: 'Subtítulo descritivo opcional com escala micro/bodySmall',
              icon: TFIcons.info,
              severity: TFDialogSeverity.info,
              size: TFDialogSize.medium,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O corpo do modal consome automaticamente o fundo semântico surface e texto textPrimary.'),
                  SizedBox(height: spacing.sm),
                  const Text('Possui rolagem interna inteligente e margens responsivas que respeitam safe-area e breakpoints móveis.'),
                ],
              ),
              primaryAction: TFButton(
                label: 'Ação Primária',
                onPressed: () {},
              ),
              secondaryAction: TFButton(
                label: 'Secundária',
                variant: TFButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
          ),
        ),
        GalleryPreviewCard(
          title: 'TFFormDialog — Padrão de Formulários Modais',
          description: 'Diálogos de cadastro e edição padronizados com validação, estado de salvamento e footer rígido.',
          child: Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: [
              TFButton(
                label: 'Abrir Formulário (Criação)',
                variant: TFButtonVariant.primary,
                leadingIcon: TFIcons.add,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TFFormDialog(
                      title: 'Nova Regional',
                      subtitle: 'Preencha os dados da regional operacional',
                      onSave: () async {
                        await Future.delayed(const Duration(milliseconds: 600));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      onCancel: () => Navigator.of(ctx).pop(),
                      child: Column(
                        children: [
                          const TFTextField(
                            label: 'Código',
                            hint: 'Ex: REG-01',
                            required: true,
                          ),
                          SizedBox(height: spacing.md),
                          const TFTextField(
                            label: 'Nome da Regional',
                            hint: 'Ex: Metropolitana Sul',
                            required: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              TFButton(
                label: 'Abrir Formulário (Edição com Salvamento)',
                variant: TFButtonVariant.secondary,
                leadingIcon: TFIcons.edit,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TFFormDialog(
                      title: 'Editar Regional',
                      subtitle: 'Edição de cadastro existente #REG-01',
                      saveLabel: 'Atualizar Dados',
                      onCancel: () => Navigator.of(ctx).pop(),
                      onSave: () async {
                        await Future.delayed(const Duration(seconds: 1));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Column(
                        children: [
                          const TFTextField(
                            label: 'Código',
                            hint: 'REG-01',
                            required: true,
                          ),
                          SizedBox(height: spacing.md),
                          const TFTextField(
                            label: 'Nome da Regional',
                            hint: 'Metropolitana Sul',
                            required: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

