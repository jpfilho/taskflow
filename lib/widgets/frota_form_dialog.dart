import 'package:flutter/material.dart';
import '../models/frota.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class FrotaFormDialog extends StatefulWidget {
  final Frota? frota;

  const FrotaFormDialog({
    super.key,
    this.frota,
  });

  @override
  State<FrotaFormDialog> createState() => _FrotaFormDialogState();
}

class _FrotaFormDialogState extends State<FrotaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _marcaController;
  late TextEditingController _placaController;
  late TextEditingController _observacoesController;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;
  String _tipoVeiculo = 'CARRO_LEVE';
  bool _emManutencao = false;
  bool _ativo = true;
  bool _isLoadingRegionais = true;
  bool _isLoadingDivisoes = true;
  bool _isLoadingSegmentos = true;

  // Tipos de veículos disponíveis
  final List<Map<String, String>> _tiposVeiculos = [
    {'value': 'CARRO_LEVE', 'label': 'Carro Leve'},
    {'value': 'MUNCK', 'label': 'Munck'},
    {'value': 'TRATOR', 'label': 'Trator'},
    {'value': 'CAMINHAO', 'label': 'Caminhão'},
    {'value': 'PICKUP', 'label': 'Pickup'},
    {'value': 'VAN', 'label': 'Van'},
    {'value': 'MOTO', 'label': 'Moto'},
    {'value': 'ONIBUS', 'label': 'Ônibus'},
    {'value': 'OUTRO', 'label': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.frota?.nome ?? '',
    );
    _marcaController = TextEditingController(
      text: widget.frota?.marca ?? '',
    );
    _placaController = TextEditingController(
      text: widget.frota?.placa ?? '',
    );
    _observacoesController = TextEditingController(
      text: widget.frota?.observacoes ?? '',
    );
    _tipoVeiculo = widget.frota?.tipoVeiculo ?? 'CARRO_LEVE';
    _emManutencao = widget.frota?.emManutencao ?? false;
    _ativo = widget.frota?.ativo ?? true;
    _loadRegionais();
    _loadDivisoes();
    _loadSegmentos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _marcaController.dispose();
    _placaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoadingRegionais = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

        // Selecionar a regional se estiver editando
        if (widget.frota != null && widget.frota!.regionalId != null) {
          _selectedRegional = regionais.firstWhere(
            (r) => r.id == widget.frota!.regionalId,
            orElse: () => regionais.isNotEmpty ? regionais.first : regionais.first,
          );
        }
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoadingRegionais = false;
      });
    }
  }

  Future<void> _loadDivisoes() async {
    setState(() {
      _isLoadingDivisoes = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      setState(() {
        _divisoes = divisoes;
        _isLoadingDivisoes = false;

        // Selecionar a divisão se estiver editando
        if (widget.frota != null && widget.frota!.divisaoId != null) {
          _selectedDivisao = divisoes.firstWhere(
            (d) => d.id == widget.frota!.divisaoId,
            orElse: () => divisoes.isNotEmpty ? divisoes.first : divisoes.first,
          );
        }
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoadingDivisoes = false;
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

        // Selecionar o segmento se estiver editando
        if (widget.frota != null && widget.frota!.segmentoId != null) {
          _selectedSegmento = segmentos.firstWhere(
            (s) => s.id == widget.frota!.segmentoId,
            orElse: () => segmentos.isNotEmpty ? segmentos.first : segmentos.first,
          );
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
      final frota = Frota(
        id: widget.frota?.id ?? '',
        nome: _nomeController.text.trim(),
        marca: _marcaController.text.trim().isEmpty
            ? null
            : _marcaController.text.trim(),
        tipoVeiculo: _tipoVeiculo,
        placa: _placaController.text.trim().toUpperCase(),
        regionalId: _selectedRegional?.id,
        divisaoId: _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        emManutencao: _emManutencao,
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
        ativo: _ativo,
      );

      Navigator.of(context).pop(frota);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.frota == null ? 'Nova Frota' : 'Editar Frota'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nome
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Marca
              TextFormField(
                controller: _marcaController,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Tipo de Veículo
              DropdownButtonFormField<String>(
                value: _tipoVeiculo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Veículo *',
                  border: OutlineInputBorder(),
                ),
                items: _tiposVeiculos.map((tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo['value'],
                    child: Text(tipo['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoVeiculo = value ?? 'CARRO_LEVE';
                  });
                },
              ),
              const SizedBox(height: 16),
              // Placa
              TextFormField(
                controller: _placaController,
                decoration: const InputDecoration(
                  labelText: 'Placa *',
                  border: OutlineInputBorder(),
                  hintText: 'ABC-1234',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Placa é obrigatória';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Regional
              _isLoadingRegionais
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Regional>(
                      value: _selectedRegional,
                      decoration: const InputDecoration(
                        labelText: 'Regional (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Regional>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._regionais.map((regional) {
                          return DropdownMenuItem<Regional>(
                            value: regional,
                            child: Text(regional.regional),
                          );
                        }),
                      ],
                      onChanged: (regional) {
                        setState(() {
                          _selectedRegional = regional;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              // Divisão
              _isLoadingDivisoes
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Divisao>(
                      value: _selectedDivisao,
                      decoration: const InputDecoration(
                        labelText: 'Divisão (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Divisao>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._divisoes.map((divisao) {
                          return DropdownMenuItem<Divisao>(
                            value: divisao,
                            child: Text(divisao.divisao),
                          );
                        }),
                      ],
                      onChanged: (divisao) {
                        setState(() {
                          _selectedDivisao = divisao;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              // Segmento
              _isLoadingSegmentos
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Segmento>(
                      value: _selectedSegmento,
                      decoration: const InputDecoration(
                        labelText: 'Segmento (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Segmento>(
                          value: null,
                          child: Text('Nenhum'),
                        ),
                        ..._segmentos.map((segmento) {
                          return DropdownMenuItem<Segmento>(
                            value: segmento,
                            child: Text(segmento.segmento),
                          );
                        }),
                      ],
                      onChanged: (segmento) {
                        setState(() {
                          _selectedSegmento = segmento;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              // Em Manutenção
              CheckboxListTile(
                title: const Text('Em Manutenção'),
                value: _emManutencao,
                onChanged: (value) {
                  setState(() {
                    _emManutencao = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 8),
              // Observações
              TextFormField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Ativo
              CheckboxListTile(
                title: const Text('Ativo'),
                value: _ativo,
                onChanged: (value) {
                  setState(() {
                    _ativo = value ?? true;
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
