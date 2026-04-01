import 'package:flutter/material.dart';
import '../models/centro_trabalho.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class CentroTrabalhoFormDialog extends StatefulWidget {
  final CentroTrabalho? centroTrabalho;

  const CentroTrabalhoFormDialog({
    super.key,
    this.centroTrabalho,
  });

  @override
  State<CentroTrabalhoFormDialog> createState() => _CentroTrabalhoFormDialogState();
}

class _CentroTrabalhoFormDialogState extends State<CentroTrabalhoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _centroTrabalhoController;
  late TextEditingController _descricaoController;
  late TextEditingController _gpmController;
  
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  
  bool _isLoading = true;
  bool _ativo = true;
  
  // Seleções obrigatórias
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;

  @override
  void initState() {
    super.initState();
    _centroTrabalhoController = TextEditingController(
      text: widget.centroTrabalho?.centroTrabalho ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.centroTrabalho?.descricao ?? '',
    );
    _gpmController = TextEditingController(
      text: widget.centroTrabalho?.gpm?.toString() ?? '',
    );
    
    // Inicializar valores se estiver editando
    if (widget.centroTrabalho != null) {
      _ativo = widget.centroTrabalho!.ativo;
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _centroTrabalhoController.dispose();
    _descricaoController.dispose();
    _gpmController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);

      setState(() {
        _regionais = futures[0] as List<Regional>;
        _divisoes = futures[1] as List<Divisao>;
        _segmentos = futures[2] as List<Segmento>;
        _isLoading = false;

        // Selecionar valores se estiver editando
        if (widget.centroTrabalho != null) {
          if (widget.centroTrabalho!.regionalId.isNotEmpty) {
            _selectedRegional = _regionais.firstWhere(
              (r) => r.id == widget.centroTrabalho!.regionalId,
              orElse: () => _regionais.isNotEmpty ? _regionais.first : _regionais.first,
            );
          }
          if (widget.centroTrabalho!.divisaoId.isNotEmpty) {
            _selectedDivisao = _divisoes.firstWhere(
              (d) => d.id == widget.centroTrabalho!.divisaoId,
              orElse: () => _divisoes.isNotEmpty ? _divisoes.first : _divisoes.first,
            );
          }
          if (widget.centroTrabalho!.segmentoId.isNotEmpty) {
            _selectedSegmento = _segmentos.firstWhere(
              (s) => s.id == widget.centroTrabalho!.segmentoId,
              orElse: () => _segmentos.isNotEmpty ? _segmentos.first : _segmentos.first,
            );
          }
        }
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      // Limpar divisão e segmento quando mudar a regional
      _selectedDivisao = null;
      _selectedSegmento = null;
    });
  }

  void _onDivisaoChanged(Divisao? divisao) {
    setState(() {
      _selectedDivisao = divisao;
      // Limpar segmento quando mudar a divisão
      _selectedSegmento = null;
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Validar que todos os vínculos foram selecionados (obrigatórios)
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma Regional'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDivisao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma Divisão'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedSegmento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um Segmento'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final centroTrabalho = CentroTrabalho(
        id: widget.centroTrabalho?.id ?? '',
        centroTrabalho: _centroTrabalhoController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        regionalId: _selectedRegional!.id,
        divisaoId: _selectedDivisao!.id,
        segmentoId: _selectedSegmento!.id,
        gpm: _gpmController.text.trim().isEmpty
            ? null
            : int.tryParse(_gpmController.text.trim()),
        ativo: _ativo,
        createdAt: widget.centroTrabalho?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(centroTrabalho);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.centroTrabalho != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Centro de Trabalho' : 'Novo Centro de Trabalho'),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _centroTrabalhoController,
                      decoration: const InputDecoration(
                        labelText: 'Centro de Trabalho *',
                        border: OutlineInputBorder(),
                        hintText: 'Digite o nome do centro de trabalho',
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
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gpmController,
                      decoration: const InputDecoration(
                        labelText: 'GPM',
                        border: OutlineInputBorder(),
                        hintText: 'Digite o GPM (numérico)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final gpm = int.tryParse(value.trim());
                          if (gpm == null) {
                            return 'Digite um número válido';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Vínculos (obrigatórios):',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Regional
                    DropdownButtonFormField<Regional>(
                      initialValue: _selectedRegional,
                      decoration: const InputDecoration(
                        labelText: 'Regional *',
                        border: OutlineInputBorder(),
                      ),
                      items: _regionais.map((regional) {
                        return DropdownMenuItem<Regional>(
                          value: regional,
                          child: Text(regional.regional),
                        );
                      }).toList(),
                      onChanged: _onRegionalChanged,
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione uma Regional';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Divisão
                    DropdownButtonFormField<Divisao>(
                      initialValue: _selectedDivisao,
                      decoration: const InputDecoration(
                        labelText: 'Divisão *',
                        border: OutlineInputBorder(),
                      ),
                      items: _divisoes
                          .where((d) => _selectedRegional == null || d.regionalId == _selectedRegional!.id)
                          .map((divisao) {
                        return DropdownMenuItem<Divisao>(
                          value: divisao,
                          child: Text(divisao.divisao),
                        );
                      }).toList(),
                      onChanged: _onDivisaoChanged,
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione uma Divisão';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Segmento
                    DropdownButtonFormField<Segmento>(
                      initialValue: _selectedSegmento,
                      decoration: const InputDecoration(
                        labelText: 'Segmento *',
                        border: OutlineInputBorder(),
                      ),
                      items: _segmentos
                          .where((s) => _selectedDivisao == null || _selectedDivisao!.segmentoIds.contains(s.id))
                          .map((segmento) {
                        return DropdownMenuItem<Segmento>(
                          value: segmento,
                          child: Text(segmento.segmento),
                        );
                      }).toList(),
                      onChanged: (segmento) {
                        setState(() {
                          _selectedSegmento = segmento;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione um Segmento';
                        }
                        return null;
                      },
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
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
