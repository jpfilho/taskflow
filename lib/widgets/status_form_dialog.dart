import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/status.dart';
import 'color_picker_dialog.dart';

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
  bool _isSaving = false;

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
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
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

      setState(() => _isSaving = true);
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
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Status' : 'Novo Status',
      subtitle: 'Atualize as informações do status.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Status',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Código do Status',
              controller: _codigoController,
              required: true,
              hint: 'Ex: ABER, EXEC, CONC',
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
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Status',
              controller: _statusController,
              required: true,
              hint: 'Informe o nome do status',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            _buildColorTile(
              label: 'Cor Principal do Status *',
              color: _selectedColor,
              colorHex: _corController.text,
              onTap: _showColorPicker,
            ),
            SizedBox(height: spacing.sm),
            _buildColorTile(
              label: 'Cor de Fundo do Segmento (Gantt)',
              color: _selectedSegmentBackgroundColor,
              colorHex: _corSegmentoController.text,
              onTap: _showSegmentBackgroundColorPicker,
            ),
            SizedBox(height: spacing.sm),
            _buildColorTile(
              label: 'Cor do Texto do Segmento (Gantt)',
              color: _selectedSegmentTextColor,
              colorHex: _corTextoSegmentoController.text,
              onTap: _showSegmentTextColorPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTile({
    required String label,
    required Color color,
    required String colorHex,
    required VoidCallback onTap,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: colors.borderSubtle),
          color: colors.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                label,
                style: typography.bodyMedium.copyWith(color: colors.textPrimary),
              ),
            ),
            Text(
              colorHex,
              style: typography.bodySmall.copyWith(
                color: colors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: spacing.xs),
            Icon(Icons.colorize_rounded, size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

