import 'package:flutter/material.dart';
import '../../data/models/status_album.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../widgets/color_picker_dialog.dart';

/// Diálogo modal TFDS para criação e edição de Status de Álbum.
class StatusAlbumFormDialog extends StatefulWidget {
  final StatusAlbum? statusAlbum;

  const StatusAlbumFormDialog({
    super.key,
    this.statusAlbum,
  });

  @override
  State<StatusAlbumFormDialog> createState() => _StatusAlbumFormDialogState();
}

class _StatusAlbumFormDialogState extends State<StatusAlbumFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _corFundoController;
  late TextEditingController _corTextoController;
  late TextEditingController _ordemController;
  bool _ativo = true;
  Color _selectedBackgroundColor = TFPrimitiveColors.blue600;
  Color _selectedTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.statusAlbum?.nome ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.statusAlbum?.descricao ?? '',
    );
    final corFundoHex = widget.statusAlbum?.corFundo;
    _corFundoController = TextEditingController(text: corFundoHex ?? '');
    if (corFundoHex != null && corFundoHex.isNotEmpty) {
      _selectedBackgroundColor = _hexToColor(corFundoHex) ?? TFPrimitiveColors.blue600;
    }

    final corTextoHex = widget.statusAlbum?.corTexto;
    _corTextoController = TextEditingController(text: corTextoHex ?? '');
    if (corTextoHex != null && corTextoHex.isNotEmpty) {
      _selectedTextColor = _hexToColor(corTextoHex) ?? Colors.white;
    } else {
      _corTextoController.text = '#FFFFFF';
    }

    _ordemController = TextEditingController(
      text: widget.statusAlbum?.ordem.toString() ?? '0',
    );
    _ativo = widget.statusAlbum?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _corFundoController.dispose();
    _corTextoController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  Future<void> _showBackgroundColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedBackgroundColor,
        title: 'Selecionar Cor de Fundo',
      ),
    );

    if (color != null) {
      setState(() {
        _selectedBackgroundColor = color;
        _corFundoController.text = _colorToHex(color);
      });
    }
  }

  Future<void> _showTextColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedTextColor,
        title: 'Selecionar Cor do Texto',
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
      final corFundoHex = _corFundoController.text.trim();
      final corTextoHex = _corTextoController.text.trim();
      final ordem = int.tryParse(_ordemController.text.trim()) ?? 0;

      final statusAlbum = StatusAlbum(
        id: widget.statusAlbum?.id ?? '',
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        corFundo: corFundoHex.isNotEmpty ? corFundoHex : null,
        corTexto: corTextoHex.isNotEmpty ? corTextoHex : null,
        ativo: _ativo,
        ordem: ordem,
      );

      Navigator.of(context).pop(statusAlbum);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.statusAlbum != null;
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: isEditing ? 'Editar Status de Álbum' : 'Novo Status de Álbum',
      subtitle: 'Configure o status e suas cores de exibição.',
      onCancel: () => Navigator.of(context).pop(),
      onSave: _save,
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Status',
      maxWidth: 520,
      formKey: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TFTextField(
            label: 'Nome *',
            controller: _nomeController,
            hint: 'Ex: Aprovado, Pendente, etc.',
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
            hint: 'Descrição opcional do status',
            maxLines: 3,
          ),
          SizedBox(height: spacing.md),
          // Seletor de Cor de Fundo
          _buildColorPickerRow(
            label: 'Cor de Fundo',
            color: _selectedBackgroundColor,
            hexValue: _corFundoController.text.isEmpty ? 'Não definida' : _corFundoController.text,
            onTap: _showBackgroundColorPicker,
            colors: colors,
            typography: typography,
            spacing: spacing,
          ),
          SizedBox(height: spacing.md),
          // Seletor de Cor do Texto
          _buildColorPickerRow(
            label: 'Cor do Texto',
            color: _selectedTextColor,
            hexValue: _corTextoController.text,
            onTap: _showTextColorPicker,
            colors: colors,
            typography: typography,
            spacing: spacing,
          ),
          SizedBox(height: spacing.md),
          TFTextField(
            label: 'Ordem',
            controller: _ordemController,
            keyboardType: TextInputType.number,
            hint: '0',
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final ordem = int.tryParse(value.trim());
                if (ordem == null || ordem < 0) {
                  return 'Ordem deve ser um número positivo';
                }
              }
              return null;
            },
          ),
          SizedBox(height: spacing.md),
          // Switch de Ativo
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary.withValues(alpha: 0.3),
              borderRadius: TFRadius.borderRadiusMd,
              border: Border.all(color: colors.borderDefault),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Ativo',
                        style: typography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Status inativos não aparecem na seleção',
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.sm),
                Switch.adaptive(
                  value: _ativo,
                  activeTrackColor: colors.primary,
                  onChanged: (value) {
                    setState(() {
                      _ativo = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerRow({
    required String label,
    required Color color,
    required String hexValue,
    required VoidCallback onTap,
    required dynamic colors,
    required dynamic typography,
    required dynamic spacing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: TFRadius.borderRadiusMd,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TFRadius.borderRadiusMd,
          border: Border.all(color: colors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: TFRadius.borderRadiusSm,
                border: Border.all(color: colors.borderDefault),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: typography.labelMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    hexValue,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              TFIcons.edit,
              size: 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
