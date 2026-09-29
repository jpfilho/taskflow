import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/tipo_atividade.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';
import 'color_picker_dialog.dart';

class TipoAtividadeFormDialog extends StatefulWidget {
  final TipoAtividade? tipoAtividade;

  const TipoAtividadeFormDialog({
    super.key,
    this.tipoAtividade,
  });

  @override
  State<TipoAtividadeFormDialog> createState() => _TipoAtividadeFormDialogState();
}

class _TipoAtividadeFormDialogState extends State<TipoAtividadeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoController;
  late TextEditingController _descricaoController;
  late TextEditingController _corController;
  late TextEditingController _corSegmentoController;
  late TextEditingController _corTextoSegmentoController;
  final SegmentoService _segmentoService = SegmentoService();
  List<Segmento> _segmentos = [];
  Set<String> _selectedSegmentoIds = {};
  bool _ativo = true;
  bool _isLoadingSegmentos = true;
  bool _isSaving = false;
  Color _selectedColor = Colors.blue;
  Color _selectedSegmentBackgroundColor = Colors.grey;
  Color _selectedSegmentTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController(
      text: widget.tipoAtividade?.codigo ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.tipoAtividade?.descricao ?? '',
    );
    final corHex = widget.tipoAtividade?.cor;
    _corController = TextEditingController(text: corHex ?? '');
    if (corHex != null && corHex.isNotEmpty) {
      _selectedColor = _hexToColor(corHex) ?? Colors.blue;
    }
    
    if (widget.tipoAtividade != null && widget.tipoAtividade!.corSegmento != null && widget.tipoAtividade!.corSegmento!.isNotEmpty) {
      try {
        _selectedSegmentBackgroundColor = widget.tipoAtividade!.segmentBackgroundColor;
        _corSegmentoController = TextEditingController(text: widget.tipoAtividade!.corSegmento);
      } catch (e) {
        _selectedSegmentBackgroundColor = Colors.grey;
        _corSegmentoController = TextEditingController(text: '#808080');
      }
    } else {
      _corSegmentoController = TextEditingController(text: '#808080');
    }

    if (widget.tipoAtividade != null && widget.tipoAtividade!.corTextoSegmento != null && widget.tipoAtividade!.corTextoSegmento!.isNotEmpty) {
      try {
        _selectedSegmentTextColor = widget.tipoAtividade!.segmentTextColor;
        _corTextoSegmentoController = TextEditingController(text: widget.tipoAtividade!.corTextoSegmento);
      } catch (e) {
        _selectedSegmentTextColor = Colors.white;
        _corTextoSegmentoController = TextEditingController(text: '#FFFFFF');
      }
    } else {
      _corTextoSegmentoController = TextEditingController(text: '#FFFFFF');
    }
    
    _ativo = widget.tipoAtividade?.ativo ?? true;
    _loadSegmentos();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _descricaoController.dispose();
    _corController.dispose();
    _corSegmentoController.dispose();
    _corTextoSegmentoController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  Future<void> _showColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _selectedColor,
        title: 'Selecionar Cor do Tipo de Atividade',
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

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoadingSegmentos = true;
    });

    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;

        if (widget.tipoAtividade != null && widget.tipoAtividade!.segmentoIds.isNotEmpty) {
          _selectedSegmentoIds = widget.tipoAtividade!.segmentoIds.toSet();
        }
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final corHex = _corController.text.trim();
      final corSegmentoValue = _corSegmentoController.text.trim();
      final corTextoSegmentoValue = _corTextoSegmentoController.text.trim();
      
      final tipoAtividade = TipoAtividade(
        id: widget.tipoAtividade?.id ?? '',
        codigo: _codigoController.text.trim().toUpperCase(),
        descricao: _descricaoController.text.trim(),
        ativo: _ativo,
        cor: corHex.isNotEmpty ? corHex : null,
        corSegmento: corSegmentoValue.isNotEmpty ? corSegmentoValue : null,
        corTextoSegmento: corTextoSegmentoValue.isNotEmpty ? corTextoSegmentoValue : null,
        segmentoIds: _selectedSegmentoIds.toList(),
        segmentos: _segmentos
            .where((s) => _selectedSegmentoIds.contains(s.id))
            .map((s) => s.segmento)
            .toList(),
      );

      Navigator.of(context).pop(tipoAtividade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tipoAtividade != null;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFFormDialog(
      title: isEditing ? 'Editar Tipo de Atividade' : 'Novo Tipo de Atividade',
      subtitle: 'Atualize as informações do tipo de atividade.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Tipo de Atividade',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Código',
              controller: _codigoController,
              required: true,
              hint: 'Ex: MANUT, OPER',
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
              required: true,
              hint: 'Descrição detalhada do tipo de atividade',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            _buildColorTile(
              label: 'Cor de Destaque',
              color: _selectedColor,
              colorHex: _corController.text.isEmpty ? 'Padrão' : _corController.text,
              onTap: _showColorPicker,
            ),
            SizedBox(height: spacing.sm),
            _buildColorTile(
              label: 'Fundo do Segmento (Gantt)',
              color: _selectedSegmentBackgroundColor,
              colorHex: _corSegmentoController.text,
              onTap: _showSegmentBackgroundColorPicker,
            ),
            SizedBox(height: spacing.sm),
            _buildColorTile(
              label: 'Texto do Segmento (Gantt)',
              color: _selectedSegmentTextColor,
              colorHex: _corTextoSegmentoController.text,
              onTap: _showSegmentTextColorPicker,
            ),
            SizedBox(height: spacing.md),
            Text(
              'Segmentos Aplicáveis',
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: _isLoadingSegmentos
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  : _segmentos.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing.sm),
                          child: Text(
                            'Nenhum segmento cadastrado',
                            style: typography.bodySmall.copyWith(color: colors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _segmentos.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: colors.borderSubtle),
                          itemBuilder: (context, index) {
                            final segmento = _segmentos[index];
                            final isSelected = _selectedSegmentoIds.contains(segmento.id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSegmentoIds.remove(segmento.id);
                                  } else {
                                    _selectedSegmentoIds.add(segmento.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.sm,
                                  vertical: spacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        segmento.segmento,
                                        style: typography.bodyMedium.copyWith(
                                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(TFRadius.r4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSegmentoIds.add(segmento.id);
                                          } else {
                                            _selectedSegmentoIds.remove(segmento.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SizedBox(height: spacing.md),
            TFSwitch(
              label: 'Ativo',
              description: 'Define se este tipo de atividade pode ser selecionado em ordens operacionais',
              value: _ativo,
              onChanged: (val) => setState(() => _ativo = val),
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
