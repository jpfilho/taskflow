import 'package:flutter/material.dart';
import '../models/local.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class LocalFormDialog extends StatefulWidget {
  final Local? local;

  const LocalFormDialog({
    super.key,
    this.local,
  });

  @override
  State<LocalFormDialog> createState() => _LocalFormDialogState();
}

class _LocalFormDialogState extends State<LocalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _localController;
  late TextEditingController _descricaoController;
  late TextEditingController _localInstalacaoSapController;
  
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  
  bool _isLoading = true;
  
  // Flags de associação
  bool _paraTodaRegional = false;
  bool _paraTodaDivisao = false;
  
  // Seleções específicas
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(
      text: widget.local?.local ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.local?.descricao ?? '',
    );
    _localInstalacaoSapController = TextEditingController(
      text: widget.local?.localInstalacaoSap ?? '',
    );
    
    // Inicializar valores se estiver editando
    if (widget.local != null) {
      _paraTodaRegional = widget.local!.paraTodaRegional;
      _paraTodaDivisao = widget.local!.paraTodaDivisao;
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _localController.dispose();
    _descricaoController.dispose();
    _localInstalacaoSapController.dispose();
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
        if (widget.local != null) {
          if (widget.local!.regionalId != null && widget.local!.regionalId!.isNotEmpty) {
            _selectedRegional = _regionais.firstWhere(
              (r) => r.id == widget.local!.regionalId,
              orElse: () => _regionais.isNotEmpty ? _regionais.first : _regionais.first,
            );
          }
          if (widget.local!.divisaoId != null && widget.local!.divisaoId!.isNotEmpty) {
            _selectedDivisao = _divisoes.firstWhere(
              (d) => d.id == widget.local!.divisaoId,
              orElse: () => _divisoes.isNotEmpty ? _divisoes.first : _divisoes.first,
            );
          }
          if (widget.local!.segmentoId != null && widget.local!.segmentoId!.isNotEmpty) {
            _selectedSegmento = _segmentos.firstWhere(
              (s) => s.id == widget.local!.segmentoId,
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

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Validar que pelo menos uma associação foi selecionada
      if (!_paraTodaRegional && 
          !_paraTodaDivisao && 
          _selectedRegional == null && 
          _selectedDivisao == null && 
          _selectedSegmento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione pelo menos uma associação (Toda Regional, Toda Divisão, ou uma associação específica)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final local = Local(
        id: widget.local?.id ?? '',
        local: _localController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        localInstalacaoSap: _localInstalacaoSapController.text.trim().isEmpty
            ? null
            : _localInstalacaoSapController.text.trim(),
        paraTodaRegional: _paraTodaRegional,
        paraTodaDivisao: _paraTodaDivisao,
        regionalId: _paraTodaRegional ? null : _selectedRegional?.id,
        divisaoId: _paraTodaDivisao ? null : _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        createdAt: widget.local?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.local != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Local' : 'Novo Local'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _localController,
                decoration: const InputDecoration(
                  labelText: 'Local *',
                  border: OutlineInputBorder(),
                  hintText: 'Digite o nome do local',
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
                controller: _localInstalacaoSapController,
                decoration: const InputDecoration(
                  labelText: 'Local da Instalação SAP',
                  border: OutlineInputBorder(),
                  hintText: 'H-S-SAAA',
                  helperText: 'Campo opcional',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              const Text(
                'Associações:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Checkbox para Toda Regional
              CheckboxListTile(
                title: const Text('Para Toda Regional'),
                subtitle: const Text('Aplica-se a todas as regionais'),
                value: _paraTodaRegional,
                onChanged: (value) {
                  setState(() {
                    _paraTodaRegional = value ?? false;
                    if (_paraTodaRegional) {
                      _selectedRegional = null;
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              // Checkbox para Toda Divisão
              CheckboxListTile(
                title: const Text('Para Toda Divisão'),
                subtitle: const Text('Aplica-se a todas as divisões'),
                value: _paraTodaDivisao,
                onChanged: (value) {
                  setState(() {
                    _paraTodaDivisao = value ?? false;
                    if (_paraTodaDivisao) {
                      _selectedDivisao = null;
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              const Text(
                'Associações Específicas:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Dropdown de Regional (sempre disponível)
              _isLoading
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Regional>(
                      value: _selectedRegional,
                      decoration: InputDecoration(
                        labelText: 'Regional Específica',
                        border: const OutlineInputBorder(),
                        hintText: 'Selecione uma regional (opcional)',
                        helperText: _paraTodaRegional 
                            ? 'Nota: "Para Toda Regional" está marcado, mas você pode especificar uma regional específica também'
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<Regional>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._regionais.map((regional) {
                          return DropdownMenuItem<Regional>(
                            value: regional,
                            child: Text('${regional.regional} - ${regional.divisao} - ${regional.empresa}'),
                          );
                        }).toList(),
                      ],
                      onChanged: (Regional? value) {
                        setState(() {
                          _selectedRegional = value;
                        });
                      },
                    ),
              const SizedBox(height: 12),
              // Dropdown de Divisão (sempre disponível)
              _isLoading
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<Divisao>(
                      value: _selectedDivisao,
                      decoration: InputDecoration(
                        labelText: 'Divisão Específica',
                        border: const OutlineInputBorder(),
                        hintText: 'Selecione uma divisão (opcional)',
                        helperText: _paraTodaDivisao 
                            ? 'Nota: "Para Toda Divisão" está marcado, mas você pode especificar uma divisão específica também'
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<Divisao>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._divisoes.map((divisao) {
                          return DropdownMenuItem<Divisao>(
                            value: divisao,
                            child: Text('${divisao.divisao} - ${divisao.regional}'),
                          );
                        }).toList(),
                      ],
                      onChanged: (Divisao? value) {
                        setState(() {
                          _selectedDivisao = value;
                        });
                      },
                    ),
              const SizedBox(height: 12),
              // Dropdown de Segmento
              _isLoading
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<Segmento>(
                      value: _selectedSegmento,
                      decoration: const InputDecoration(
                        labelText: 'Segmento Específico',
                        border: OutlineInputBorder(),
                        hintText: 'Selecione um segmento (opcional)',
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
                        }).toList(),
                      ],
                      onChanged: (Segmento? value) {
                        setState(() {
                          _selectedSegmento = value;
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

