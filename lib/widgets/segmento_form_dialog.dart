import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/segmento.dart';
import 'color_picker_dialog.dart';

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
  bool _isSaving = false;

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
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
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
      setState(() => _isSaving = true);
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
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Segmento' : 'Novo Segmento',
      subtitle: 'Atualize as informações visuais e cadastrais do segmento.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Segmento',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Segmento',
              controller: _segmentoController,
              required: true,
              hint: 'Informe o nome do segmento',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Descrição',
              controller: _descricaoController,
              hint: 'Descrição detalhada do segmento (opcional)',
              maxLines: 3,
            ),
            SizedBox(height: spacing.md),
            _buildColorTile(
              label: 'Cor de Fundo do Segmento',
              color: _selectedBackgroundColor,
              colorHex: _corController.text,
              onTap: _showBackgroundColorPicker,
            ),
            SizedBox(height: spacing.sm),
            _buildColorTile(
              label: 'Cor do Texto do Segmento',
              color: _selectedTextColor,
              colorHex: _corTextoController.text,
              onTap: _showTextColorPicker,
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

