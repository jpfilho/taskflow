import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/dialogs/tf_form_dialog.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';

class ProjetoFormDialog extends StatefulWidget {
  final Projeto? projeto;

  const ProjetoFormDialog({super.key, this.projeto});

  @override
  State<ProjetoFormDialog> createState() => _ProjetoFormDialogState();
}

class _ProjetoFormDialogState extends State<ProjetoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _codigoController;
  late TextEditingController _descricaoController;
  late TextEditingController _orcamentoController;

  String _status = 'EM PLANEJAMENTO';
  String _prioridade = 'MEDIA';
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.projeto?.nome ?? '');
    _codigoController = TextEditingController(text: widget.projeto?.codigo ?? '');
    _descricaoController = TextEditingController(text: widget.projeto?.descricao ?? '');
    _orcamentoController = TextEditingController(
      text: widget.projeto?.orcamentoPrevisto?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );

    if (widget.projeto != null) {
      _status = widget.projeto!.status;
      _prioridade = widget.projeto!.prioridade;
      _dataInicio = widget.projeto!.dataInicioPrevista;
      _dataFim = widget.projeto!.dataFimPrevista;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _codigoController.dispose();
    _descricaoController.dispose();
    _orcamentoController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final novoProjeto = Projeto(
        id: widget.projeto?.id ?? '',
        nome: _nomeController.text.trim(),
        codigo: _codigoController.text.trim().isEmpty ? null : _codigoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
        status: _status,
        prioridade: _prioridade,
        orcamentoPrevisto: double.tryParse(_orcamentoController.text.replaceAll(',', '.')),
        progresso: widget.projeto?.progresso ?? 0.0,
        dataInicioPrevista: _dataInicio,
        dataFimPrevista: _dataFim,
      );
      Navigator.of(context).pop(novoProjeto);
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
      title: widget.projeto == null ? 'Novo Projeto' : 'Editar Projeto',
      subtitle: widget.projeto == null
          ? 'Cadastre as informações básicas e planejamento do projeto.'
          : 'Atualize os dados e parâmetros do projeto.',
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
              label: 'Nome do Projeto *',
              hint: 'Ex: Expansão Linha de Transmissão Norte',
              validator: (v) => v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _codigoController,
              label: 'Código / Sigla (Opcional)',
              hint: 'Ex: PRJ-LT-2026',
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _descricaoController,
              label: 'Descrição',
              hint: 'Objetivo, escopo e premissas gerais...',
              maxLines: 3,
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
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: TFDropdown<String>(
                    label: 'Status',
                    value: _status,
                    items: const [
                      'EM PLANEJAMENTO',
                      'ATIVO',
                      'PAUSADO',
                      'CONCLUIDO',
                      'CANCELADO',
                    ],
                    displayText: (e) => e,
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: TFDropdown<String>(
                    label: 'Prioridade',
                    value: _prioridade,
                    items: const [
                      'BAIXA',
                      'MEDIA',
                      'ALTA',
                      'URGENTE',
                    ],
                    displayText: (e) => e,
                    onChanged: (v) {
                      if (v != null) setState(() => _prioridade = v);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            TFTextField(
              controller: _orcamentoController,
              label: 'Orçamento Previsto (R\$)',
              hint: '0,00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
    );
  }
}
