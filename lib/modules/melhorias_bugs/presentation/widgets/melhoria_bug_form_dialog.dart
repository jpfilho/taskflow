import 'package:flutter/material.dart';
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
  late TextEditingController _tituloController;
  late TextEditingController _descricaoController;
  late String _tipo;
  late String _status;
  String? _versaoId;
  String? _prioridade;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _tituloController = TextEditingController(text: i?.titulo ?? '');
    _descricaoController = TextEditingController(text: i?.descricao ?? '');
    _tipo = i?.tipo ?? kTipoMelhoria;
    _status = i?.status ?? 'BACKLOG';
    _versaoId = i?.versaoId;
    _prioridade = i?.prioridade;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título é obrigatório')),
      );
      return;
    }
    final mb = (widget.initial ?? MelhoriaBug(id: '', tipo: _tipo, titulo: titulo, status: 'BACKLOG'))
        .copyWith(
      titulo: titulo,
      descricao: _descricaoController.text.trim().isEmpty
          ? null
          : _descricaoController.text.trim(),
      tipo: _tipo,
      status: _status,
      versaoId: _versaoId?.isEmpty ?? true ? null : _versaoId,
      prioridade: _prioridade,
    );
    await widget.onSave(mb);
    if (mounted) Navigator.of(context).pop(mb);
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _prioridadeLabel(String codigo) {
    const labels = {'BAIXA': 'Baixa', 'MEDIA': 'Média', 'ALTA': 'Alta', 'CRITICA': 'Crítica'};
    return labels[codigo] ?? codigo;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Editar item' : 'Nova melhoria/bug',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preencha os detalhes da sua solicitação.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _tituloController,
                      decoration: _inputDecoration('Título'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descricaoController,
                      decoration: _inputDecoration(
                        'Descrição (opcional)',
                        hint: 'Descreva os detalhes desta tarefa...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tipo,
                      decoration: _inputDecoration('Tipo'),
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(value: kTipoBug, child: Text('Bug')),
                        DropdownMenuItem(value: kTipoMelhoria, child: Text('Melhoria')),
                      ],
                      onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: _inputDecoration('Status'),
                        borderRadius: BorderRadius.circular(12),
                        items: kMelhoriasBugsStatusCodes
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(melhoriaBugStatusLabel(c)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v ?? _status),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _prioridade,
                      decoration: _inputDecoration('Prioridade'),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('— Nenhuma —')),
                        ...kMelhoriasBugsPrioridades.map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(_prioridadeLabel(p)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _prioridade = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
