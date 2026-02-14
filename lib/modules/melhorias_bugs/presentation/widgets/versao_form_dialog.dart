import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/versao.dart';

class VersaoFormDialog extends StatefulWidget {
  final Versao? initial;
  final Future<Versao> Function(Versao) onSave;

  const VersaoFormDialog({
    super.key,
    this.initial,
    required this.onSave,
  });

  @override
  State<VersaoFormDialog> createState() => _VersaoFormDialogState();
}

class _VersaoFormDialogState extends State<VersaoFormDialog> {
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  DateTime? _dataPrevista;
  DateTime? _dataLancamento;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nomeController = TextEditingController(text: i?.nome ?? '');
    _descricaoController = TextEditingController(text: i?.descricao ?? '');
    _dataPrevista = i?.dataPrevistaLancamento;
    _dataLancamento = i?.dataLancamento;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome da versão é obrigatório')),
      );
      return;
    }
    final v = (widget.initial ?? Versao(id: '', nome: nome)).copyWith(
      nome: nome,
      descricao: _descricaoController.text.trim().isEmpty
          ? null
          : _descricaoController.text.trim(),
      dataPrevistaLancamento: _dataPrevista,
      dataLancamento: _dataLancamento,
    );
    await widget.onSave(v);
    if (mounted) Navigator.of(context).pop(v);
  }

  Future<void> _pickDate(bool isLancamento) async {
    final initial = isLancamento ? _dataLancamento : _dataPrevista;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isLancamento) {
          _dataLancamento = picked;
        } else {
          _dataPrevista = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial != null ? 'Editar versão' : 'Nova versão'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome (ex: v1.2.0)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data prevista lançamento'),
              subtitle: Text(
                _dataPrevista != null
                    ? DateFormat('dd/MM/yyyy').format(_dataPrevista!)
                    : 'Não definida',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(false),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data lançamento'),
              subtitle: Text(
                _dataLancamento != null
                    ? DateFormat('dd/MM/yyyy').format(_dataLancamento!)
                    : 'Não definida',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(true),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
