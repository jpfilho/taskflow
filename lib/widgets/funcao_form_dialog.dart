import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/funcao.dart';

class FuncaoFormDialog extends StatefulWidget {
  final Funcao? funcao;

  const FuncaoFormDialog({
    super.key,
    this.funcao,
  });

  @override
  State<FuncaoFormDialog> createState() => _FuncaoFormDialogState();
}

class _FuncaoFormDialogState extends State<FuncaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _funcaoController;
  late TextEditingController _descricaoController;
  bool _ativo = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _funcaoController = TextEditingController(
      text: widget.funcao?.funcao ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.funcao?.descricao ?? '',
    );
    _ativo = widget.funcao?.ativo ?? true;
  }

  @override
  void dispose() {
    _funcaoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final funcao = Funcao(
        id: widget.funcao?.id ?? '',
        funcao: _funcaoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        ativo: _ativo,
      );

      Navigator.of(context).pop(funcao);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.funcao != null;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Função' : 'Nova Função',
      subtitle: 'Atualize as informações da função.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Função',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Nome da Função',
              controller: _funcaoController,
              required: true,
              hint: 'Informe o nome da função',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Descrição',
              controller: _descricaoController,
              hint: 'Descrição das atribuições da função (opcional)',
              maxLines: 3,
            ),
            SizedBox(height: spacing.md),
            TFSwitch(
              label: 'Ativo',
              description: 'Define se esta função está disponível para novos cadastros e alocações',
              value: _ativo,
              onChanged: (value) => setState(() => _ativo = value),
            ),
          ],
        ),
      ),
    );
  }
}

