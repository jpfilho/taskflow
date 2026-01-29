import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/status.dart';
import 'color_picker_dialog.dart';
import 'form_dialog_helpers.dart';

class StatusFormDialog extends StatefulWidget {
  final Status? status;

  const StatusFormDialog({
    super.key,
    this.status,
  });

  @override
  State<StatusFormDialog> createState() => _StatusFormDialogState();
}

class _StatusFormDialogState extends State<StatusFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoController;
  late TextEditingController _statusController;
  late TextEditingController _corController;
  late TextEditingController _corSegmentoController;
  late TextEditingController _corTextoSegmentoController;
  Color _selectedColor = const Color(0xFF2196F3);
  Color _selectedSegmentBackgroundColor = Colors.grey;
  Color _selectedSegmentTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController(
      text: widget.status?.codigo ?? '',
    );
    _statusController = TextEditingController(
      text: widget.status?.status ?? '',
    );
    
    if (widget.status != null && widget.status!.cor.isNotEmpty) {
      try {
        final corValue = widget.status!.cor;
        _selectedColor = widget.status!.color;
        _corController = TextEditingController(text: corValue);
      } catch (e) {
        _selectedColor = const Color(0xFF2196F3);
        _corController = TextEditingController(text: '#2196F3');
      }
    } else {
      _corController = TextEditingController(text: '#2196F3');
    }

    if (widget.status != null && widget.status!.corSegmento != null && widget.status!.corSegmento!.isNotEmpty) {
      try {
        _selectedSegmentBackgroundColor = widget.status!.segmentBackgroundColor;
        _corSegmentoController = TextEditingController(text: widget.status!.corSegmento);
      } catch (e) {
        _selectedSegmentBackgroundColor = Colors.grey;
        _corSegmentoController = TextEditingController(text: '#808080');
      }
    } else {
      _corSegmentoController = TextEditingController(text: '#808080');
    }

    if (widget.status != null && widget.status!.corTextoSegmento != null && widget.status!.corTextoSegmento!.isNotEmpty) {
      try {
        _selectedSegmentTextColor = widget.status!.segmentTextColor;
        _corTextoSegmentoController = TextEditingController(text: widget.status!.corTextoSegmento);
      } catch (e) {
        _selectedSegmentTextColor = Colors.white;
        _corTextoSegmentoController = TextEditingController(text: '#FFFFFF');
      }
    } else {
      _corTextoSegmentoController = TextEditingController(text: '#FFFFFF');
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _statusController.dispose();
    _corController.dispose();
    _corSegmentoController.dispose();
    _corTextoSegmentoController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _showColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedColor,
        title: 'Selecionar Cor do Status',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedColor = color;
        _corController.text = _colorToHex(color);
      });
    }
  }

  Future<void> _showSegmentBackgroundColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedSegmentBackgroundColor,
        title: 'Selecionar Cor de Fundo do Segmento',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedSegmentBackgroundColor = color;
        _corSegmentoController.text = _colorToHex(color);
      });
    }
  }

  Future<void> _showSegmentTextColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedSegmentTextColor,
        title: 'Selecionar Cor do Texto do Segmento',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedSegmentTextColor = color;
        _corTextoSegmentoController.text = _colorToHex(color);
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final corValue = _corController.text.trim();
      if (corValue.isEmpty || !corValue.startsWith('#')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma cor válida'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final corSegmentoValue = _corSegmentoController.text.trim();
      final corTextoSegmentoValue = _corTextoSegmentoController.text.trim();

      final status = Status(
        id: widget.status?.id ?? '',
        codigo: _codigoController.text.trim().toUpperCase(),
        status: _statusController.text.trim(),
        cor: corValue,
        corSegmento: corSegmentoValue.isEmpty ? null : corSegmentoValue,
        corTextoSegmento: corTextoSegmentoValue.isEmpty ? null : corTextoSegmentoValue,
        createdAt: widget.status?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.status != null;
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
                    isEditing ? 'Editar Status' : 'Novo Status',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do status.',
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
                        label: 'Código do Status *',
                        controller: _codigoController,
                        isDark: isDark,
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          if (value.trim().length > 4) {
                            return 'Máximo 4 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Status *',
                        controller: _statusController,
                        isDark: isDark,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor *',
                        color: _selectedColor,
                        colorHex: _corController.text,
                        isDark: isDark,
                        onTap: _showColorPicker,
                        icon: Icons.color_lens,
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor de Fundo do Segmento',
                        color: _selectedSegmentBackgroundColor,
                        colorHex: _corSegmentoController.text,
                        isDark: isDark,
                        onTap: _showSegmentBackgroundColorPicker,
                        icon: Icons.color_lens,
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor do Texto do Segmento',
                        color: _selectedSegmentTextColor,
                        colorHex: _corTextoSegmentoController.text,
                        isDark: isDark,
                        onTap: _showSegmentTextColorPicker,
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
                      isEditing ? 'Salvar Alterações' : 'Criar Status',
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
