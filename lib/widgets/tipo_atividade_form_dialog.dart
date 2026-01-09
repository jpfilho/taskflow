import 'package:flutter/material.dart';
import '../models/tipo_atividade.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';

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
  final SegmentoService _segmentoService = SegmentoService();
  List<Segmento> _segmentos = [];
  Set<String> _selectedSegmentoIds = {}; // Múltiplos segmentos
  bool _ativo = true;
  bool _isLoadingSegmentos = true;
  Color _selectedColor = Colors.blue;
  
  // Cores pré-definidas
  static const List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

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
    _ativo = widget.tipoAtividade?.ativo ?? true;
    _loadSegmentos();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _descricaoController.dispose();
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
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedColor = tempColor;
                    _corController.text = tempCorController.text;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
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
      final tipoAtividade = TipoAtividade(
        id: widget.tipoAtividade?.id ?? '',
        codigo: _codigoController.text.trim().toUpperCase(),
        descricao: _descricaoController.text.trim(),
        ativo: _ativo,
        cor: corHex.isNotEmpty ? corHex : null,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cor (opcional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showColorPicker,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: 2),
                          ),
                          child: _corController.text.isEmpty
                              ? const Icon(Icons.color_lens, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _corController,
                          decoration: InputDecoration(
                            labelText: 'Código hexadecimal',
                            hintText: '#FF5733',
                            border: const OutlineInputBorder(),
                            prefixIcon: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            final color = _hexToColor(value);
                            if (color != null) {
                              setState(() {
                                _selectedColor = color;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _corController.clear();
                            _selectedColor = Colors.blue;
                          });
                        },
                        tooltip: 'Limpar cor',
                      ),
                    ],
                  ),
                ],
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


