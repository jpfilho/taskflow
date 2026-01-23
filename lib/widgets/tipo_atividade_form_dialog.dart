import 'package:flutter/material.dart';
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
  Set<String> _selectedSegmentoIds = {}; // Múltiplos segmentos
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
    
    // Inicializar cor do segmento
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

    // Inicializar cor do texto do segmento
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

        // Selecionar os segmentos se estiver editando
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
    return AlertDialog(
      title: Text(widget.tipoAtividade == null ? 'Novo Tipo de Atividade' : 'Editar Tipo de Atividade'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Código
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: 'Código *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: MANUT, INSTAL, etc.',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Descrição
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Cor (opcional)
              InkWell(
                onTap: _showColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.color_lens),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _corController.text.isEmpty ? 'Não definida' : _corController.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Seletor de cor de fundo do segmento
              InkWell(
                onTap: _showSegmentBackgroundColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor de Fundo do Segmento',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.color_lens),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedSegmentBackgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _corSegmentoController.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Seletor de cor do texto do segmento
              InkWell(
                onTap: _showSegmentTextColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor do Texto do Segmento',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.format_color_text),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedSegmentTextColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _corTextoSegmentoController.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Segmentos (múltipla seleção)
              _isLoadingSegmentos
                  ? const CircularProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Segmentos (opcional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _segmentos.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Nenhum segmento disponível',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _segmentos.map((segmento) {
                                      final isSelected = _selectedSegmentoIds.contains(segmento.id);
                                      return CheckboxListTile(
                                        title: Text(segmento.segmento),
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
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              // Ativo
              SwitchListTile(
                title: const Text('Ativo'),
                value: _ativo,
                onChanged: (value) {
                  setState(() {
                    _ativo = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}


