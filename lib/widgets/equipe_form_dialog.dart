import 'package:flutter/material.dart';
import '../models/equipe.dart';
import '../models/executor.dart';
import '../models/equipe_executor.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/executor_service.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';

class EquipeFormDialog extends StatefulWidget {
  final Equipe? equipe;

  const EquipeFormDialog({
    super.key,
    this.equipe,
  });

  @override
  State<EquipeFormDialog> createState() => _EquipeFormDialogState();
}

class _EquipeFormDialogState extends State<EquipeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  final ExecutorService _executorService = ExecutorService();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Executor> _executores = [];
  List<Regional> _regionais = [];
  List<Divisao> _allDivisoes = []; // Lista completa de divisões
  List<Divisao> _filteredDivisoes = []; // Divisões filtradas por regional
  List<Segmento> _segmentos = [];
  List<EquipeExecutor> _equipeExecutores = []; // Lista de executores com seus papéis
  String _tipo = 'FIXA';
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;
  bool _ativo = true;
  bool _isLoadingExecutores = true;
  bool _isLoadingRegionais = true;
  bool _isLoadingDivisoes = true;
  bool _isLoadingSegmentos = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.equipe?.nome ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.equipe?.descricao ?? '',
    );
    _tipo = widget.equipe?.tipo ?? 'FIXA';
    _ativo = widget.equipe?.ativo ?? true;
    _equipeExecutores = widget.equipe?.executores.toList() ?? [];
    _loadExecutores();
    _loadRegionais();
    _loadDivisoes();
    _loadSegmentos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _loadExecutores() async {
    setState(() {
      _isLoadingExecutores = true;
    });

    try {
      final executores = await _executorService.getExecutoresAtivos();
      setState(() {
        _executores = executores;
        _isLoadingExecutores = false;
      });
    } catch (e) {
      print('Erro ao carregar executores: $e');
      setState(() {
        _isLoadingExecutores = false;
      });
    }
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
        if (widget.equipe != null && widget.equipe!.regionalId != null) {
          try {
            _selectedRegional = regionais.firstWhere(
              (r) => r.id == widget.equipe!.regionalId,
            );
          } catch (e) {
            _selectedRegional = null;
          }
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
        _allDivisoes = divisoes;
        _isLoadingDivisoes = false;

        // Filtrar divisões por regional selecionada
        _updateFilteredDivisoes();

        // Selecionar a divisão se estiver editando
        if (widget.equipe != null && widget.equipe!.divisaoId != null) {
          try {
            _selectedDivisao = _filteredDivisoes.firstWhere(
              (d) => d.id == widget.equipe!.divisaoId,
            );
          } catch (e) {
            _selectedDivisao = null;
          }
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
        if (widget.equipe != null && widget.equipe!.segmentoId != null) {
          try {
            _selectedSegmento = segmentos.firstWhere(
              (s) => s.id == widget.equipe!.segmentoId,
            );
          } catch (e) {
            _selectedSegmento = null;
          }
        }
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  void _updateFilteredDivisoes() {
    if (_selectedRegional != null) {
      _filteredDivisoes = _allDivisoes
          .where((d) => d.regionalId == _selectedRegional!.id)
          .toList();
    } else {
      _filteredDivisoes = _allDivisoes;
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      _selectedDivisao = null; // Reset divisão quando regional muda
      _selectedSegmento = null; // Reset segmento quando regional muda
      // Atualizar divisões filtradas
      _updateFilteredDivisoes();
    });
  }

  void _adicionarExecutor(Executor executor, String papel) {
    setState(() {
      // Verificar se o executor já está na lista
      final index = _equipeExecutores.indexWhere(
        (e) => e.executorId == executor.id,
      );
      
      if (index >= 0) {
        // Atualizar papel se já existir
        _equipeExecutores[index] = EquipeExecutor(
          executorId: executor.id,
          executorNome: executor.nome,
          papel: papel,
        );
      } else {
        // Adicionar novo
        _equipeExecutores.add(EquipeExecutor(
          executorId: executor.id,
          executorNome: executor.nome,
          papel: papel,
        ));
      }
    });
  }

  void _removerExecutor(String executorId) {
    setState(() {
      _equipeExecutores.removeWhere((e) => e.executorId == executorId);
    });
  }

  void _alterarPapel(String executorId, String novoPapel) {
    setState(() {
      final index = _equipeExecutores.indexWhere(
        (e) => e.executorId == executorId,
      );
      if (index >= 0) {
        final executor = _equipeExecutores[index];
        _equipeExecutores[index] = EquipeExecutor(
          executorId: executor.executorId,
          executorNome: executor.executorNome,
          papel: novoPapel,
        );
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final equipe = Equipe(
        id: widget.equipe?.id ?? '',
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        tipo: _tipo,
        regionalId: _selectedRegional?.id,
        divisaoId: _selectedDivisao?.id,
        segmentoId: _selectedSegmento?.id,
        ativo: _ativo,
        executores: _equipeExecutores,
      );

      Navigator.of(context).pop(equipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.equipe == null ? 'Nova Equipe' : 'Editar Equipe'),
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
                  labelText: 'Nome da Equipe *',
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
              // Descrição
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Tipo
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'FIXA', child: Text('Fixa')),
                  DropdownMenuItem(value: 'FLEXIVEL', child: Text('Flexível')),
                ],
                onChanged: (value) {
                  setState(() {
                    _tipo = value ?? 'FIXA';
                  });
                },
              ),
              const SizedBox(height: 16),
              // Regional
              _isLoadingRegionais
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Regional>(
                      initialValue: _selectedRegional,
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
                      onChanged: _onRegionalChanged,
                    ),
              const SizedBox(height: 16),
              // Divisão
              _isLoadingDivisoes
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Divisao>(
                      initialValue: _selectedDivisao,
                      decoration: const InputDecoration(
                        labelText: 'Divisão (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Divisao>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._filteredDivisoes.map((divisao) {
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
                      initialValue: _selectedSegmento,
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
              // Executores
              _isLoadingExecutores
                  ? const CircularProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Executores',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Lista de executores adicionados
                        if (_equipeExecutores.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _equipeExecutores.map((equipeExecutor) {
                                  final executor = _executores.firstWhere(
                                    (e) => e.id == equipeExecutor.executorId,
                                    orElse: () => Executor(
                                      id: equipeExecutor.executorId,
                                      nome: equipeExecutor.executorNome,
                                    ),
                                  );
                                  return ListTile(
                                    dense: true,
                                    title: Text(executor.nome),
                                    subtitle: DropdownButton<String>(
                                      value: equipeExecutor.papel,
                                      isExpanded: true,
                                      underline: Container(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'FISCAL',
                                          child: Text('Fiscal'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'TST',
                                          child: Text('TST'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ENCARREGADO',
                                          child: Text('Encarregado'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'EXECUTOR',
                                          child: Text('Executor'),
                                        ),
                                      ],
                                      onChanged: (novoPapel) {
                                        if (novoPapel != null) {
                                          _alterarPapel(executor.id, novoPapel);
                                        }
                                      },
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () => _removerExecutor(executor.id),
                                      color: Colors.red,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Botão para adicionar executor
                        ElevatedButton.icon(
                          onPressed: () => _showAdicionarExecutorDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Executor'),
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

  void _showAdicionarExecutorDialog() {
    // Filtrar executores que já estão na equipe
    final executoresDisponiveis = _executores.where((executor) {
      return !_equipeExecutores.any((e) => e.executorId == executor.id);
    }).toList();

    if (executoresDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os executores já foram adicionados'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Executor'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Executor>(
                decoration: const InputDecoration(
                  labelText: 'Executor *',
                  border: OutlineInputBorder(),
                ),
                items: executoresDisponiveis.map((executor) {
                  return DropdownMenuItem<Executor>(
                    value: executor,
                    child: Text(executor.nomeCompleto ?? executor.nome),
                  );
                }).toList(),
                onChanged: (executor) {
                  if (executor != null) {
                    // Mostrar diálogo para selecionar papel
                    Navigator.of(context).pop();
                    _showSelecionarPapelDialog(executor);
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
        ],
      ),
    );
  }

  void _showSelecionarPapelDialog(Executor executor) {
    String papelSelecionado = 'EXECUTOR';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Papel de ${executor.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Fiscal'),
                value: 'FISCAL',
                groupValue: papelSelecionado,
                onChanged: (value) {
                  setDialogState(() {
                    papelSelecionado = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('TST'),
                value: 'TST',
                groupValue: papelSelecionado,
                onChanged: (value) {
                  setDialogState(() {
                    papelSelecionado = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Encarregado'),
                value: 'ENCARREGADO',
                groupValue: papelSelecionado,
                onChanged: (value) {
                  setDialogState(() {
                    papelSelecionado = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Executor'),
                value: 'EXECUTOR',
                groupValue: papelSelecionado,
                onChanged: (value) {
                  setDialogState(() {
                    papelSelecionado = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _adicionarExecutor(executor, papelSelecionado);
                Navigator.of(context).pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}

