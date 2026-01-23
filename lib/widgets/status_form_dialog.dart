import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController(
      text: widget.status?.codigo ?? '',
    );
    _statusController = TextEditingController(
      text: widget.status?.status ?? '',
    );
    
    // Inicializar cor
    if (widget.status != null && widget.status!.cor.isNotEmpty) {
      try {
        final corValue = widget.status!.cor;
        print('🎨 Inicializando cor do status: $corValue');
        _selectedColor = widget.status!.color;
        _corController = TextEditingController(text: corValue);
        print('✅ Cor inicializada: ${_corController.text}, Color: ${_selectedColor.value.toRadixString(16)}');
      } catch (e) {
        print('❌ Erro ao inicializar cor: $e');
        _selectedColor = const Color(0xFF2196F3);
        _corController = TextEditingController(text: '#2196F3');
      }
    } else {
      _corController = TextEditingController(text: '#2196F3');
    }

    // Inicializar cor do segmento
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

    // Inicializar cor do texto do segmento
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

      print('💾 Salvando status com cor: $corValue, corSegmento: $corSegmentoValue, corTextoSegmento: $corTextoSegmentoValue');
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

    return AlertDialog(
      title: Text(isEditing ? 'Editar Status' : 'Novo Status'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: 'Código do Status *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: ANDA, CONC, PROG',
                  helperText: 'Máximo 4 caracteres',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(4),
                ],
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome do status',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Seletor de cor
              InkWell(
                onTap: _showColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor *',
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
                          _corController.text,
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
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

