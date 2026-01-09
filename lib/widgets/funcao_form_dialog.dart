import 'package:flutter/material.dart';
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
    return AlertDialog(
      title: Text(widget.funcao == null ? 'Nova Função' : 'Editar Função'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _funcaoController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Função',
                    border: OutlineInputBorder(),
                  ),
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
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Ativo'),
                  value: _ativo,
                  onChanged: (value) {
                    setState(() {
                      _ativo = value;
                    });
                  },
                ),
              ],
            ),
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
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}







