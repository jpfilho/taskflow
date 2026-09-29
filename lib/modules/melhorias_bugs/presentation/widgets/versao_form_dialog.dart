import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  DateTime? _dataPrevista;
  DateTime? _dataLancamento;
  bool _isSaving = false;

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

    setState(() => _isSaving = true);

    try {
      final v = (widget.initial ?? Versao(id: '', nome: nome)).copyWith(
        nome: nome,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        dataPrevistaLancamento: _dataPrevista,
        dataLancamento: _dataLancamento,
      );

      await widget.onSave(v);
      if (mounted) {
        Navigator.of(context).pop(v);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar versão: $e')),
        );
      }
    }
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
    final isEdit = widget.initial != null;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFFormDialog(
      title: isEdit ? 'Editar Versão' : 'Nova Versão',
      subtitle: 'Defina os parâmetros do release no roadmap do sistema.',
      maxWidth: 480,
      isSaving: _isSaving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TFTextField(
              controller: _nomeController,
              label: 'Nome da Versão',
              hint: 'Ex: v1.3.0 ou Release Q4',
              required: true,
            ),
            const SizedBox(height: 16),
            TFTextField(
              controller: _descricaoController,
              label: 'Descrição / Escopo',
              hint: 'Descreva os principais objetivos desta versão...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _pickDate(false),
              borderRadius: TFRadius.borderRadiusMd,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data Prevista de Lançamento',
                  border: OutlineInputBorder(
                    borderRadius: TFRadius.borderRadiusMd,
                  ),
                  suffixIcon: Icon(Icons.calendar_today_outlined, color: colors.textSecondary),
                ),
                child: Text(
                  _dataPrevista != null
                      ? DateFormat('dd/MM/yyyy').format(_dataPrevista!)
                      : 'Não definida',
                  style: typography.bodyMedium.copyWith(
                    color: _dataPrevista != null ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _pickDate(true),
              borderRadius: TFRadius.borderRadiusMd,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data Efetiva de Lançamento',
                  border: OutlineInputBorder(
                    borderRadius: TFRadius.borderRadiusMd,
                  ),
                  suffixIcon: Icon(Icons.event_available_outlined, color: colors.textSecondary),
                ),
                child: Text(
                  _dataLancamento != null
                      ? DateFormat('dd/MM/yyyy').format(_dataLancamento!)
                      : 'Não definida',
                  style: typography.bodyMedium.copyWith(
                    color: _dataLancamento != null ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
