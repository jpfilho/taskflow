import 'package:flutter/material.dart';
import '../models/empresa.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';

class EmpresaFormDialog extends StatefulWidget {
  final Empresa? empresa;

  const EmpresaFormDialog({
    super.key,
    this.empresa,
  });

  @override
  State<EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<EmpresaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _empresaController;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  String _selectedTipo = 'PROPRIA';
  bool _isLoadingRegionais = true;
  bool _isLoadingDivisoes = true;

  @override
  void initState() {
    super.initState();
    _empresaController = TextEditingController(
      text: widget.empresa?.empresa ?? '',
    );
    _selectedTipo = widget.empresa?.tipo ?? 'PROPRIA';
    _loadRegionais();
  }

  @override
  void dispose() {
    _empresaController.dispose();
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
        if (widget.empresa != null && widget.empresa!.regionalId.isNotEmpty) {
          _selectedRegional = regionais.firstWhere(
            (r) => r.id == widget.empresa!.regionalId,
            orElse: () => regionais.isNotEmpty ? regionais.first : regionais.first,
          );
          // Carregar divisões da regional selecionada
          _loadDivisoes();
        } else if (regionais.isNotEmpty) {
          _selectedRegional = regionais.first;
          _loadDivisoes();
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
    if (_selectedRegional == null) return;

    setState(() {
      _isLoadingDivisoes = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      // Filtrar divisões da regional selecionada
      final divisoesFiltradas = divisoes
          .where((d) => d.regionalId == _selectedRegional!.id)
          .toList();

      setState(() {
        _divisoes = divisoesFiltradas;
        _isLoadingDivisoes = false;

        // Selecionar a divisão se estiver editando
        if (widget.empresa != null && widget.empresa!.divisaoId.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.firstWhere(
            (d) => d.id == widget.empresa!.divisaoId,
            orElse: () => divisoesFiltradas.isNotEmpty
                ? divisoesFiltradas.first
                : divisoesFiltradas.first,
          );
        } else if (divisoesFiltradas.isNotEmpty) {
          _selectedDivisao = divisoesFiltradas.first;
        } else {
          _selectedDivisao = null;
        }
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoadingDivisoes = false;
      });
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      _selectedDivisao = null; // Reset divisão quando mudar regional
    });
    _loadDivisoes();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma regional.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedDivisao == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma divisão.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final empresa = Empresa(
        id: widget.empresa?.id ?? '',
        empresa: _empresaController.text.trim(),
        regionalId: _selectedRegional!.id,
        divisaoId: _selectedDivisao!.id,
        tipo: _selectedTipo,
      );

      Navigator.of(context).pop(empresa);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.empresa == null ? 'Nova Empresa' : 'Editar Empresa'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _empresaController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Empresa',
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
                // Dropdown de Regional
                _isLoadingRegionais
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<Regional>(
                        value: _selectedRegional,
                        decoration: const InputDecoration(
                          labelText: 'Regional',
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
                            return 'Selecione uma regional';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                // Dropdown de Divisão
                _isLoadingDivisoes
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<Divisao>(
                        value: _selectedDivisao,
                        decoration: const InputDecoration(
                          labelText: 'Divisão',
                          border: OutlineInputBorder(),
                        ),
                        items: _divisoes.map((divisao) {
                          return DropdownMenuItem<Divisao>(
                            value: divisao,
                            child: Text(divisao.divisao),
                          );
                        }).toList(),
                        onChanged: (divisao) {
                          setState(() {
                            _selectedDivisao = divisao;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Selecione uma divisão';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                // Dropdown de Tipo
                DropdownButtonFormField<String>(
                  value: _selectedTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'PROPRIA',
                      child: Text('Própria'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'TERCEIRA',
                      child: Text('Terceira'),
                    ),
                  ],
                  onChanged: (tipo) {
                    setState(() {
                      _selectedTipo = tipo!;
                    });
                  },
                ),
              ],
            ),
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







