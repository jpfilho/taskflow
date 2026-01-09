import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/status.dart';

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
  Color _selectedColor = const Color(0xFF2196F3);

  // Cores pré-definidas para escolha rápida
  final List<Color> _predefinedColors = [
    const Color(0xFF2196F3), // Azul
    const Color(0xFF4CAF50), // Verde
    const Color(0xFFFF9800), // Laranja
    const Color(0xFFF44336), // Vermelho
    const Color(0xFF9C27B0), // Roxo
    const Color(0xFF00BCD4), // Ciano
    const Color(0xFFFFEB3B), // Amarelo
    const Color(0xFF795548), // Marrom
    const Color(0xFF607D8B), // Azul acinzentado
    const Color(0xFFE91E63), // Rosa
    const Color(0xFF3F51B5), // Índigo
    const Color(0xFF009688), // Verde-água
  ];

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
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _statusController.dispose();
    _corController.dispose();
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

  void _showColorPicker() {
    Color tempColor = _selectedColor;
    final tempCorController = TextEditingController(text: _corController.text);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Selecionar Cor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cores pré-definidas
                  const Text(
                    'Cores Pré-definidas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _predefinedColors.map((color) {
                      final isSelected = color.value == tempColor.value;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            tempColor = color;
                            tempCorController.text = _colorToHex(color);
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Campo para inserir cor hexadecimal manualmente
                  const Text(
                    'Ou digite o código hexadecimal:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tempCorController,
                    decoration: InputDecoration(
                      hintText: '#FF5733',
                      prefixIcon: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tempColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      final color = _hexToColor(value);
                      if (color != null) {
                        setDialogState(() {
                          tempColor = color;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedColor = tempColor;
                    _corController.text = tempCorController.text;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
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

      print('💾 Salvando status com cor: $corValue');
      final status = Status(
        id: widget.status?.id ?? '',
        codigo: _codigoController.text.trim().toUpperCase(),
        status: _statusController.text.trim(),
        cor: corValue,
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

