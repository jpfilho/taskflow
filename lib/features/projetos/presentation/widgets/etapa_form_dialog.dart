import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto_etapa.dart';

class EtapaFormDialog extends StatefulWidget {
  final String projetoId;
  final String macroetapaId;
  final ProjetoEtapa? etapa;
  final int proximaOrdem;

  const EtapaFormDialog({
    super.key,
    required this.projetoId,
    required this.macroetapaId,
    this.etapa,
    this.proximaOrdem = 1,
  });

  @override
  State<EtapaFormDialog> createState() => _EtapaFormDialogState();
}

class _EtapaFormDialogState extends State<EtapaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _ordemController;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _status = 'PENDENTE';
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.etapa?.nome ?? '');
    _ordemController = TextEditingController(
      text: widget.etapa?.ordem.toString() ?? widget.proximaOrdem.toString(),
    );

    _dataInicio = widget.etapa?.dataInicioPrevista;
    _dataFim = widget.etapa?.dataFimPrevista;

    if (widget.etapa != null) {
      _status = widget.etapa!.status;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final e = ProjetoEtapa(
        id: widget.etapa?.id ?? '',
        projetoId: widget.projetoId,
        macroetapaId: widget.macroetapaId,
        nome: _nomeController.text.trim(),
        ordem: int.tryParse(_ordemController.text) ?? widget.proximaOrdem,
        status: _status,
        dataInicioPrevista: _dataInicio,
        dataFimPrevista: _dataFim,
      );
      Navigator.of(context).pop(e);
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
      title: widget.etapa == null ? 'Nova Etapa' : 'Editar Etapa',
      subtitle: widget.etapa == null
          ? 'Cadastre uma subetapa de entrega.'
          : 'Atualize as informações da etapa.',
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
              label: 'Nome da Etapa *',
              hint: 'Ex: Fundação e Obras Civis',
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
