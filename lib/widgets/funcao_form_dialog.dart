import 'package:flutter/material.dart';
import '../models/funcao.dart';
import 'form_dialog_helpers.dart';

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
    final isEditing = widget.funcao != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Função' : 'Nova Função',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações da função.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingLabelTextField(
                        label: 'Nome da Função *',
                        controller: _funcaoController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição',
                        controller: _descricaoController,
                        isDark: isDark,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Ativo',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                            ),
                          ),
                          value: _ativo,
                          activeColor: const Color(0xFF3b82f6),
                          onChanged: (value) {
                            setState(() {
                              _ativo = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar Alterações' : 'Criar Função',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
