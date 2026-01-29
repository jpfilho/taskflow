import 'package:flutter/material.dart';
import '../models/regional.dart';

class RegionalFormDialog extends StatefulWidget {
  final Regional? regional;

  const RegionalFormDialog({
    super.key,
    this.regional,
  });

  @override
  State<RegionalFormDialog> createState() => _RegionalFormDialogState();
}

class _RegionalFormDialogState extends State<RegionalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _regionalController;
  late TextEditingController _divisaoController;
  late TextEditingController _empresaController;

  @override
  void initState() {
    super.initState();
    _regionalController = TextEditingController(
      text: widget.regional?.regional ?? '',
    );
    _divisaoController = TextEditingController(
      text: widget.regional?.divisao ?? '',
    );
    _empresaController = TextEditingController(
      text: widget.regional?.empresa ?? '',
    );
  }

  @override
  void dispose() {
    _regionalController.dispose();
    _divisaoController.dispose();
    _empresaController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final regional = Regional(
        id: widget.regional?.id ?? '',
        regional: _regionalController.text.trim(),
        divisao: _divisaoController.text.trim(),
        empresa: _empresaController.text.trim(),
        createdAt: widget.regional?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(regional);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.regional != null;
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
                    isEditing ? 'Editar Regional' : 'Nova Regional',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações da regional.',
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
                      _FloatingLabelTextField(
                        label: 'Regional *',
                        controller: _regionalController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _FloatingLabelTextField(
                        label: 'Sigla *',
                        controller: _divisaoController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _FloatingLabelTextField(
                        label: 'Empresa *',
                        controller: _empresaController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
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
                      isEditing ? 'Salvar Alterações' : 'Criar Regional',
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

// Widget para campo de texto com label flutuante
class _FloatingLabelTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FloatingLabelTextField({
    required this.label,
    required this.controller,
    required this.isDark,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_FloatingLabelTextField> createState() => _FloatingLabelTextFieldState();
}

class _FloatingLabelTextFieldState extends State<_FloatingLabelTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    final shouldFloat = _isFocused || hasValue;

    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      child: TextFormField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(
          color: widget.isDark ? Colors.white : const Color(0xFF1e293b),
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: shouldFloat
                ? const Color(0xFF3b82f6)
                : (widget.isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
            fontSize: shouldFloat ? 12 : 16,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF3b82f6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelAlignment: FloatingLabelAlignment.start,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: widget.isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                )
              : null,
          filled: true,
          fillColor: widget.prefixIcon != null
              ? (widget.isDark ? const Color(0xFF0f172a).withOpacity(0.3) : const Color(0xFFf8fafc).withOpacity(0.5))
              : Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF3b82f6),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.prefixIcon != null ? 40 : 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
