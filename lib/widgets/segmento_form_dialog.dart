import 'package:flutter/material.dart';
import '../models/segmento.dart';

class SegmentoFormDialog extends StatefulWidget {
  final Segmento? segmento;

  const SegmentoFormDialog({
    super.key,
    this.segmento,
  });

  @override
  State<SegmentoFormDialog> createState() => _SegmentoFormDialogState();
}

class _SegmentoFormDialogState extends State<SegmentoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _segmentoController;
  late TextEditingController _descricaoController;

  @override
  void initState() {
    super.initState();
    _segmentoController = TextEditingController(
      text: widget.segmento?.segmento ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.segmento?.descricao ?? '',
    );
  }

  @override
  void dispose() {
    _segmentoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final segmento = Segmento(
        id: widget.segmento?.id ?? '',
        segmento: _segmentoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        createdAt: widget.segmento?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(segmento);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.segmento != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Segmento' : 'Novo Segmento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _segmentoController,
                decoration: const InputDecoration(
                  labelText: 'Segmento *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome do segmento',
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
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  hintText: 'Digite uma descrição (opcional)',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
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







