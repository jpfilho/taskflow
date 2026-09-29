import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto_atividade.dart';

class ProjetoAtividadeFormDialog extends StatefulWidget {
  final String projetoId;
  final String macroetapaId;
  final String etapaId;
  final ProjetoAtividade? atividade;
  final int proximaOrdem;

  const ProjetoAtividadeFormDialog({
    super.key,
    required this.projetoId,
    required this.macroetapaId,
    required this.etapaId,
    this.atividade,
    this.proximaOrdem = 1,
  });

  @override
  State<ProjetoAtividadeFormDialog> createState() => _ProjetoAtividadeFormDialogState();
}

class _ProjetoAtividadeFormDialogState extends State<ProjetoAtividadeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _ordemController;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _status = 'PENDENTE';
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.atividade?.nome ?? '');
    _descricaoController = TextEditingController(text: widget.atividade?.descricao ?? '');
    _ordemController = TextEditingController(
      text: widget.atividade?.ordem.toString() ?? widget.proximaOrdem.toString(),
    );
    _dataInicio = widget.atividade?.dataInicioPrevista;
    _dataFim = widget.atividade?.dataFimPrevista;

    if (widget.atividade != null) {
      _status = widget.atividade!.status;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    final dataAtual = isInicio ? _dataInicio : _dataFim;
    final picked = await showDatePicker(
      context: context,
      initialDate: dataAtual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
    }
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final a = ProjetoAtividade(
        id: widget.atividade?.id ?? '',
        projetoId: widget.projetoId,
        macroetapaId: widget.macroetapaId,
        etapaId: widget.etapaId,
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
        ordem: int.tryParse(_ordemController.text) ?? widget.proximaOrdem,
        dataInicioPrevista: _dataInicio,
        dataFimPrevista: _dataFim,
        status: _status,
      );
      Navigator.of(context).pop(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: widget.atividade == null ? 'Nova Atividade' : 'Editar Atividade',
      subtitle: widget.atividade == null
          ? 'Cadastre uma tarefa operacional dentro da etapa.'
          : 'Atualize os dados e prazos da atividade.',
      isSaving: _isSaving,
      onSave: _salvar,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TFTextField(
              controller: _nomeController,
              label: 'Nome da Atividade *',
              hint: 'Ex: Concretagem da base da torre',
              validator: (v) => v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: TFTextField(
                    controller: _ordemController,
                    label: 'Ordem',
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: TFDropdown<String>(
                    label: 'Status',
                    value: _status,
                    items: const [
                      'PENDENTE',
                      'EM_ANDAMENTO',
                      'CONCLUIDA',
                      'CANCELADA',
                    ],
                    displayText: (e) => e,
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _descricaoController,
              label: 'Descrição (opcional)',
              hint: 'Instruções e escopo da atividade...',
              maxLines: 2,
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(context, true),
                    child: IgnorePointer(
                      child: TFTextField(
                        controller: TextEditingController(
                          text: _dataInicio != null ? _dateFormat.format(_dataInicio!) : '',
                        ),
                        label: 'Início Previsto',
                        hint: 'DD/MM/AAAA',
                        suffixIcon: const Icon(TFIcons.calendar, size: 18),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(context, false),
                    child: IgnorePointer(
                      child: TFTextField(
                        controller: TextEditingController(
                          text: _dataFim != null ? _dateFormat.format(_dataFim!) : '',
                        ),
                        label: 'Fim Previsto',
                        hint: 'DD/MM/AAAA',
                        suffixIcon: const Icon(TFIcons.calendar, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
