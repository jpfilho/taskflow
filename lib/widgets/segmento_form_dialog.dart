import 'package:flutter/material.dart';
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

    return AlertDialog(
      title: Text(isEditing ? 'Editar Segmento' : 'Novo Segmento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _segmentoController,
                decoration: const InputDecoration(
                  labelText: 'Segmento *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome do segmento',
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
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  hintText: 'Digite uma descrição (opcional)',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Seletor de cor de fundo
              InkWell(
                onTap: _showBackgroundColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor de Fundo',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.color_lens),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedBackgroundColor,
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
              // Seletor de cor do texto
              InkWell(
                onTap: _showTextColorPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Cor do Texto',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.format_color_text),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedTextColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _corTextoController.text,
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







