import 'package:flutter/material.dart';
import '../models/tipo_atividade.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';
import 'color_picker_dialog.dart';
import 'form_dialog_helpers.dart';

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
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
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
                    isEditing ? 'Editar Tipo de Atividade' : 'Novo Tipo de Atividade',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do tipo de atividade.',
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
                        label: 'Código *',
                        controller: _codigoController,
                        isDark: isDark,
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição *',
                        controller: _descricaoController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ColorPickerField(
                        label: 'Cor',
                        color: _selectedColor,
                        colorHex: _corController.text.isEmpty ? 'Não definida' : _corController.text,
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
                      const SizedBox(height: 24),
                      Text(
                        'Segmentos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1e293b).withOpacity(0.5) : const Color(0xFFf8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFe2e8f0),
                          ),
                        ),
                        child: _isLoadingSegmentos
                            ? const Center(child: CircularProgressIndicator())
                            : _segmentos.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Nenhum segmento disponível',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _segmentos.map((segmento) {
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
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    segmento.segmento,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isSelected
                                                          ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                                                          : (isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
                                                    ),
                                                  ),
                                                ),
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value == true) {
                                                        _selectedSegmentoIds.add(segmento.id);
                                                      } else {
                                                        _selectedSegmentoIds.remove(segmento.id);
                                                      }
                                                    });
                                                  },
                                                  activeColor: const Color(0xFF3b82f6),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
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
                      isEditing ? 'Salvar Alterações' : 'Criar Tipo de Atividade',
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
