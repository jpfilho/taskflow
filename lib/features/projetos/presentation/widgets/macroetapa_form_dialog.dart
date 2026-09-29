import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto_macroetapa.dart';

class MacroetapaFormDialog extends StatefulWidget {
  final String projetoId;
  final ProjetoMacroetapa? macroetapa;
  final int proximaOrdem;

  const MacroetapaFormDialog({
    super.key,
    required this.projetoId,
    this.macroetapa,
    this.proximaOrdem = 1,
  });

  @override
  State<MacroetapaFormDialog> createState() => _MacroetapaFormDialogState();
}

class _MacroetapaFormDialogState extends State<MacroetapaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _ordemController;
  late TextEditingController _descricaoController;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _status = 'PENDENTE';
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.macroetapa?.nome ?? '');
    _descricaoController = TextEditingController(text: widget.macroetapa?.descricao ?? '');
    _ordemController = TextEditingController(
      text: widget.macroetapa?.ordem.toString() ?? widget.proximaOrdem.toString(),
    );

    _dataInicio = widget.macroetapa?.dataInicioPrevista;
    _dataFim = widget.macroetapa?.dataFimPrevista;

    if (widget.macroetapa != null) {
      _status = widget.macroetapa!.status;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ordemController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final m = ProjetoMacroetapa(
        id: widget.macroetapa?.id ?? '',
        projetoId: widget.projetoId,
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim(),
        ordem: int.tryParse(_ordemController.text) ?? widget.proximaOrdem,
        status: _status,
        dataInicioPrevista: _dataInicio,
        dataFimPrevista: _dataFim,
      );
      Navigator.of(context).pop(m);
    }
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: widget.macroetapa == null ? 'Nova Macroetapa' : 'Editar Macroetapa',
      subtitle: widget.macroetapa == null
          ? 'Defina o bloco macro estrutural do projeto.'
          : 'Atualize os dados da macroetapa.',
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
              label: 'Nome da Macroetapa *',
              hint: 'Ex: Fase de Engenharia e Projetos Executivos',
              validator: (v) => v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _descricaoController,
              label: 'Descrição (opcional)',
              hint: 'Detalhamento do pacote de trabalho...',
              maxLines: 2,
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
