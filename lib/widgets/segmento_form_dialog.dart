import 'package:flutter/material.dart';
import '../models/segmento.dart';
import 'color_picker_dialog.dart';
import 'form_dialog_helpers.dart';

class SegmentoFormDialog extends StatefulWidget {
  final Segmento? segmento;

  const SegmentoFormDialog({
    super.key,
    this.segmento,
  });

  @override
  State<SegmentoFormDialog> createState() => _SegmentoFormDialogState();
}

class _SegmentoFormDialogState extends State<SegmentoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _segmentoController;
  late TextEditingController _descricaoController;
  late TextEditingController _corController;
  late TextEditingController _corTextoController;
  Color _selectedBackgroundColor = Colors.grey;
  Color _selectedTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _segmentoController = TextEditingController(
      text: widget.segmento?.segmento ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.segmento?.descricao ?? '',
    );
    
    // Inicializar cores
    if (widget.segmento != null) {
      if (widget.segmento!.cor != null && widget.segmento!.cor!.isNotEmpty) {
        try {
          _selectedBackgroundColor = widget.segmento!.backgroundColor;
          _corController = TextEditingController(text: widget.segmento!.cor);
        } catch (e) {
          _selectedBackgroundColor = Colors.grey;
          _corController = TextEditingController(text: '#808080');
        }
      } else {
        _corController = TextEditingController(text: '#808080');
      }
      
      if (widget.segmento!.corTexto != null && widget.segmento!.corTexto!.isNotEmpty) {
        try {
          _selectedTextColor = widget.segmento!.textColor;
          _corTextoController = TextEditingController(text: widget.segmento!.corTexto);
        } catch (e) {
          _selectedTextColor = Colors.white;
          _corTextoController = TextEditingController(text: '#FFFFFF');
        }
      } else {
        _corTextoController = TextEditingController(text: '#FFFFFF');
      }
    } else {
      _corController = TextEditingController(text: '#808080');
      _corTextoController = TextEditingController(text: '#FFFFFF');
    }
  }

  @override
  void dispose() {
    _segmentoController.dispose();
    _descricaoController.dispose();
    _corController.dispose();
    _corTextoController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _showBackgroundColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedBackgroundColor,
        title: 'Selecionar Cor de Fundo do Segmento',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedBackgroundColor = color;
        _corController.text = _colorToHex(color);
      });
    }
  }

  Future<void> _showTextColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedTextColor,
        title: 'Selecionar Cor do Texto do Segmento',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedTextColor = color;
        _corTextoController.text = _colorToHex(color);
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final corValue = _corController.text.trim();
      final corTextoValue = _corTextoController.text.trim();
      
      final segmento = Segmento(
        id: widget.segmento?.id ?? '',
        segmento: _segmentoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        cor: corValue.isEmpty ? null : corValue,
        corTexto: corTextoValue.isEmpty ? null : corTextoValue,
        createdAt: widget.segmento?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(segmento);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.segmento != null;
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
                    isEditing ? 'Editar Segmento' : 'Novo Segmento',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do segmento.',
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
                        label: 'Segmento *',
                        controller: _segmentoController,
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
                      ),
                      const SizedBox(height: 24),
                      // Seletor de cor de fundo
                      ColorPickerField(
                        label: 'Cor de Fundo',
                        color: _selectedBackgroundColor,
                        colorHex: _corController.text,
                        isDark: isDark,
                        onTap: _showBackgroundColorPicker,
                        icon: Icons.color_lens,
                      ),
                      const SizedBox(height: 24),
                      // Seletor de cor do texto
                      ColorPickerField(
                        label: 'Cor do Texto',
                        color: _selectedTextColor,
                        colorHex: _corTextoController.text,
                        isDark: isDark,
                        onTap: _showTextColorPicker,
                        icon: Icons.format_color_text,
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
                      isEditing ? 'Salvar Alterações' : 'Criar Segmento',
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

// Widget para campo de texto com label flutuante (mantido para compatibilidade, mas usar FloatingLabelTextField do helper)
class _FloatingLabelTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;

  const _FloatingLabelTextField({
    required this.label,
    required this.controller,
    required this.isDark,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines,
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
        maxLines: widget.maxLines,
        textCapitalization: widget.maxLines != null && widget.maxLines! > 1
            ? TextCapitalization.sentences
            : TextCapitalization.words,
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

// Widget para seletor de cor (mantido para compatibilidade, mas usar ColorPickerField do helper)
class _ColorPickerField extends StatelessWidget {
  final String label;
  final Color color;
  final String colorHex;
  final bool isDark;
  final VoidCallback onTap;
  final IconData icon;

  const _ColorPickerField({
    required this.label,
    required this.color,
    required this.colorHex,
    required this.isDark,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3b82f6),
              ),
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              colorHex,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
            ),
          ],
        ),
      ),
    );
  }
}
