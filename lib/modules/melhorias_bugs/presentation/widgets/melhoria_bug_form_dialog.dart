import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../models/versao.dart';

class MelhoriaBugFormDialog extends StatefulWidget {
  final MelhoriaBug? initial;
  final List<Versao> versoes;
  final Future<MelhoriaBug> Function(MelhoriaBug) onSave;

  const MelhoriaBugFormDialog({
    super.key,
    this.initial,
    required this.versoes,
    required this.onSave,
  });

  @override
  State<MelhoriaBugFormDialog> createState() => _MelhoriaBugFormDialogState();
}

class _MelhoriaBugFormDialogState extends State<MelhoriaBugFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _descricaoController;
  late TextEditingController _feedbackController;
  late String _tipo;
  late String _status;
  String? _versaoId;
  String? _prioridade;
  DateTime? _prazo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _tituloController = TextEditingController(text: i?.titulo ?? '');
    _descricaoController = TextEditingController(text: i?.descricao ?? '');
    _feedbackController = TextEditingController(text: i?.feedback ?? '');
    _tipo = i?.tipo ?? kTipoMelhoria;
    _status = i?.status ?? 'BACKLOG';
    _versaoId = i?.versaoId;
    _prioridade = i?.prioridade;
    _prazo = i?.prazo;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  String _prioridadeLabel(String? codigo) {
    if (codigo == null) return '— Nenhuma —';
    const labels = {
      'BAIXA': 'Baixa',
      'MEDIA': 'Média',
      'ALTA': 'Alta',
      'CRITICA': 'Crítica',
    };
    return labels[codigo] ?? codigo;
  }

  List<String> _getAvailableStatusOptions() {
    final current = widget.initial?.status ?? _status;
    final transitions = kMelhoriasBugsTransicoes[current] ?? [];
    final allowed = <String>{current, ...transitions};
    return allowed.toList();
  }

  Future<void> _submit() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título é obrigatório')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final mb = (widget.initial ??
              MelhoriaBug(id: '', tipo: _tipo, titulo: titulo, status: 'BACKLOG'))
          .copyWith(
        titulo: titulo,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        feedback: _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
        tipo: _tipo,
        status: _status,
        versaoId: _versaoId?.isEmpty ?? true ? null : _versaoId,
        prioridade: _prioridade,
        prazo: _prazo,
      );

      await widget.onSave(mb);
      if (mounted) {
        Navigator.of(context).pop(mb);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final availableStatuses = _getAvailableStatusOptions();

    return TFFormDialog(
      title: isEdit ? 'Editar Item' : 'Novo Item',
      subtitle: 'Preencha os detalhes da solicitação de melhoria ou bug.',
      maxWidth: 520,
      isSaving: _isSaving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TFTextField(
              controller: _tituloController,
              label: 'Título',
              hint: 'Ex: Erro ao calcular horas no SAP',
              required: true,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TFTextField(
              controller: _descricaoController,
              label: 'Descrição',
              hint: 'Descreva detalhadamente o comportamento ou a melhoria desejada...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TFDropdown<String>(
              label: 'Tipo',
              value: _tipo,
              items: const [kTipoBug, kTipoMelhoria],
              displayText: (t) => t == kTipoBug ? 'Bug' : 'Melhoria',
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            if (isEdit) ...[
              const SizedBox(height: 16),
              TFDropdown<String>(
                label: 'Status',
                value: availableStatuses.contains(_status)
                    ? _status
                    : availableStatuses.first,
                items: availableStatuses,
                displayText: (s) => melhoriaBugStatusLabel(s),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
            ],
            const SizedBox(height: 16),
            TFDropdown<String?>(
              label: 'Prioridade',
              value: _prioridade,
              items: [null, ...kMelhoriasBugsPrioridades],
              displayText: (p) => _prioridadeLabel(p),
              onChanged: (v) => setState(() => _prioridade = v),
            ),
            const SizedBox(height: 16),
            // Prazo para Resolver
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prazo para Resolver',
                  style: context.tfTypography.labelMedium.copyWith(
                    color: context.tfColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _prazo ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _prazo = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: context.tfColors.surface,
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      border: Border.all(color: context.tfColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: _prazo != null ? context.tfColors.primary : context.tfColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _prazo != null
                                ? DateFormat('dd/MM/yyyy').format(_prazo!)
                                : 'Definir prazo de resolução...',
                            style: context.tfTypography.bodyMedium.copyWith(
                              color: _prazo != null
                                  ? context.tfColors.textPrimary
                                  : context.tfColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_prazo != null)
                          InkWell(
                            onTap: () => setState(() => _prazo = null),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: context.tfColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.versoes.isNotEmpty) ...[
              const SizedBox(height: 16),
              TFDropdown<String?>(
                label: 'Versão do Roadmap',
                value: _versaoId,
                items: [null, ...widget.versoes.map((v) => v.id)],
                displayText: (id) {
                  if (id == null) return '— Nenhuma —';
                  final match = widget.versoes.where((v) => v.id == id);
                  return match.isNotEmpty ? match.first.nome : id;
                },
                onChanged: (v) => setState(() => _versaoId = v),
              ),
            ],
            const SizedBox(height: 16),
            TFTextField(
              controller: _feedbackController,
              label: 'Feedback ao Solicitante',
              hint: 'Escreva uma resposta, esclarecimento ou justificativa para o usuário...',
              maxLines: 3,
            ),
            if (isEdit && widget.initial?.createdBy != null && widget.initial!.createdBy!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.tfColors.surfaceSecondary,
                  borderRadius: TFRadius.borderRadiusSm,
                  border: Border.all(color: context.tfColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: context.tfColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reportado por: ${widget.initial!.createdBy!}',
                        style: context.tfTypography.bodySmall.copyWith(
                          color: context.tfColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
