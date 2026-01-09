import 'package:flutter/material.dart';
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

    return AlertDialog(
      title: Text(isEditing ? 'Editar Regional' : 'Nova Regional'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _regionalController,
                decoration: const InputDecoration(
                  labelText: 'Regional *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome da regional',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _divisaoController,
                decoration: const InputDecoration(
                  labelText: 'Sigla *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite a sigla',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _empresaController,
                decoration: const InputDecoration(
                  labelText: 'Empresa *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome da empresa',
                ),
                textCapitalization: TextCapitalization.words,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}


