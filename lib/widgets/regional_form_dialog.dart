import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/regional.dart';

class RegionalFormDialog extends StatefulWidget {
  final Regional? regional;

  const RegionalFormDialog({
    super.key,
    this.regional,
  });

  @override
  State<RegionalFormDialog> createState() => _RegionalFormDialogState();
}

class _RegionalFormDialogState extends State<RegionalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _regionalController;
  late TextEditingController _divisaoController;
  late TextEditingController _empresaController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _regionalController = TextEditingController(
      text: widget.regional?.regional ?? '',
    );
    _divisaoController = TextEditingController(
      text: widget.regional?.divisao ?? '',
    );
    _empresaController = TextEditingController(
      text: widget.regional?.empresa ?? '',
    );
  }

  @override
  void dispose() {
    _regionalController.dispose();
    _divisaoController.dispose();
    _empresaController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final regional = Regional(
        id: widget.regional?.id ?? '',
        regional: _regionalController.text.trim(),
        divisao: _divisaoController.text.trim(),
        empresa: _empresaController.text.trim(),
        createdAt: widget.regional?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(regional);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.regional != null;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Regional' : 'Nova Regional',
      subtitle: 'Atualize as informações da regional.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Regional',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Regional',
              controller: _regionalController,
              required: true,
              hint: 'Informe o nome da regional',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Sigla',
              controller: _divisaoController,
              required: true,
              hint: 'Informe a sigla / divisão',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Empresa',
              controller: _empresaController,
              required: true,
              hint: 'Informe a empresa responsável',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
