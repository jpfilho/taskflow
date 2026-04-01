import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/regra_prazo_nota.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';

class RegraPrazoNotaFormDialog extends StatefulWidget {
  final RegraPrazoNota? regra;

  const RegraPrazoNotaFormDialog({
    super.key,
    this.regra,
  });

  @override
  State<RegraPrazoNotaFormDialog> createState() => _RegraPrazoNotaFormDialogState();
}

class _RegraPrazoNotaFormDialogState extends State<RegraPrazoNotaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _diasPrazoController;
  late TextEditingController _descricaoController;
  String? _selectedPrioridade;
  String? _selectedDataReferencia;
  Set<String> _selectedSegmentoIds = {}; // Set de IDs de segmentos selecionados. Se vazio = todos os segmentos
  bool _ativo = true;
  List<Segmento> _segmentos = [];
  bool _isLoadingSegmentos = true;
  final SegmentoService _segmentoService = SegmentoService();

  // Opções de prioridade
  final List<String> _prioridades = [
    'Alta',
    'Baixa',
    'Emergência',
    'Média',
    'Monitoramento',
    'Por Oportunidade',
    'Urgência',
  ];

  // Opções de data de referência
  final List<Map<String, String>> _dataReferencias = [
    {'value': 'criacao', 'label': 'Data de Criação'},
    {'value': 'inicio_desejado', 'label': 'Início da Avaria'},
  ];

  @override
  void initState() {
    super.initState();
    _diasPrazoController = TextEditingController(
      text: widget.regra?.diasPrazo.toString() ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.regra?.descricao ?? '',
    );
    _selectedPrioridade = widget.regra?.prioridade;
    _selectedDataReferencia = widget.regra?.dataReferencia;
    _selectedSegmentoIds = widget.regra?.segmentoIds.toSet() ?? {}; // Set de IDs selecionados
    _ativo = widget.regra?.ativo ?? true;
    _loadSegmentos();
  }

  Future<void> _loadSegmentos() async {
    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  @override
  void dispose() {
    _diasPrazoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedPrioridade == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma prioridade'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDataReferencia == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione a data de referência'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final regra = RegraPrazoNota(
        id: widget.regra?.id ?? '',
        prioridade: _selectedPrioridade!,
        diasPrazo: int.parse(_diasPrazoController.text.trim()),
        dataReferencia: _selectedDataReferencia!,
        segmentoIds: _selectedSegmentoIds.toList(), // Lista de IDs selecionados. Se vazia = todos os segmentos
        ativo: _ativo,
        descricao: _descricaoController.text.trim().isEmpty 
            ? null 
            : _descricaoController.text.trim(),
        createdAt: widget.regra?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(regra);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.regra != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Regra de Prazo' : 'Nova Regra de Prazo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPrioridade,
                decoration: const InputDecoration(
                  labelText: 'Prioridade *',
                  border: OutlineInputBorder(),
                ),
                items: _prioridades.map((prioridade) {
                  return DropdownMenuItem(
                    value: prioridade,
                    child: Text(prioridade),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPrioridade = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione uma prioridade';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diasPrazoController,
                decoration: const InputDecoration(
                  labelText: 'Dias de Prazo *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 5, 10, 30',
                  helperText: 'Quantidade de dias para conclusão',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a quantidade de dias';
                  }
                  final dias = int.tryParse(value);
                  if (dias == null || dias <= 0) {
                    return 'Dias deve ser um número maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedDataReferencia,
                decoration: InputDecoration(
                  labelText: 'Data de Referência *',
                  border: const OutlineInputBorder(),
                  helperText: _selectedDataReferencia == 'inicio_desejado'
                      ? 'Usa o campo "Início da Avaria" da nota SAP para calcular o prazo'
                      : _selectedDataReferencia == 'criacao'
                          ? 'Usa a data de criação da nota SAP para calcular o prazo'
                          : 'Selecione a data base para cálculo do prazo',
                ),
                items: _dataReferencias.map((item) {
                  return DropdownMenuItem(
                    value: item['value'],
                    child: Text(item['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDataReferencia = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione a data de referência';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _isLoadingSegmentos
                  ? const CircularProgressIndicator()
                  : ExpansionTile(
                      title: const Text('Segmentos'),
                      subtitle: Text(
                        _selectedSegmentoIds.isEmpty
                            ? 'Todos os segmentos'
                            : '${_selectedSegmentoIds.length} segmento(s) selecionado(s)',
                      ),
                      initiallyExpanded: false,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                title: const Text('Todos os Segmentos'),
                                value: _selectedSegmentoIds.isEmpty,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedSegmentoIds.clear();
                                    }
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                              const Divider(),
                              ..._segmentos.map((segmento) {
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
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  hintText: 'Descrição opcional da regra',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Regra Ativa'),
                subtitle: const Text('Se desativada, a regra não será aplicada'),
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
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
