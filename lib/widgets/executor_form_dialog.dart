import 'package:flutter/material.dart';
import '../models/executor.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../models/empresa.dart';
import '../models/funcao.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import '../services/empresa_service.dart';
import '../services/funcao_service.dart';

class ExecutorFormDialog extends StatefulWidget {
  final Executor? executor;

  const ExecutorFormDialog({
    super.key,
    this.executor,
  });

  @override
  State<ExecutorFormDialog> createState() => _ExecutorFormDialogState();
}

class _ExecutorFormDialogState extends State<ExecutorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _nomeCompletoController;
  late TextEditingController _matriculaController;
  late TextEditingController _loginController;
  late TextEditingController _ramalController;
  late TextEditingController _telefoneController;
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  final EmpresaService _empresaService = EmpresaService();
  final FuncaoService _funcaoService = FuncaoService();
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  List<Empresa> _empresas = [];
  List<Funcao> _funcoes = [];
  Divisao? _selectedDivisao;
  Set<String> _selectedSegmentoIds = {}; // Múltiplos segmentos
  Empresa? _selectedEmpresa;
  Funcao? _selectedFuncao;
  bool _ativo = true;
  bool _isLoadingDivisoes = true;
  bool _isLoadingSegmentos = true;
  bool _isLoadingEmpresas = true;
  bool _isLoadingFuncoes = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.executor?.nome ?? '',
    );
    _nomeCompletoController = TextEditingController(
      text: widget.executor?.nomeCompleto ?? '',
    );
    _matriculaController = TextEditingController(
      text: widget.executor?.matricula ?? '',
    );
    _loginController = TextEditingController(
      text: widget.executor?.login ?? '',
    );
    _ramalController = TextEditingController(
      text: widget.executor?.ramal ?? '',
    );
    _telefoneController = TextEditingController(
      text: widget.executor?.telefone ?? '',
    );
    _ativo = widget.executor?.ativo ?? true;
    _loadDivisoes();
    _loadSegmentos();
    _loadEmpresas();
    _loadFuncoes();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeCompletoController.dispose();
    _matriculaController.dispose();
    _loginController.dispose();
    _ramalController.dispose();
    _telefoneController.dispose();
    super.dispose();
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
        if (widget.executor != null && widget.executor!.divisaoId != null) {
          _selectedDivisao = divisoes.firstWhere(
            (d) => d.id == widget.executor!.divisaoId,
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

        // Selecionar os segmentos se estiver editando
        if (widget.executor != null && widget.executor!.segmentoIds.isNotEmpty) {
          _selectedSegmentoIds = widget.executor!.segmentoIds.toSet();
        }
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  Future<void> _loadEmpresas() async {
    setState(() {
      _isLoadingEmpresas = true;
    });

    try {
      final empresas = await _empresaService.getAllEmpresas();
      setState(() {
        _empresas = empresas;
        _isLoadingEmpresas = false;

        // Selecionar a empresa se estiver editando
        if (widget.executor != null && widget.executor!.empresaId != null) {
          _selectedEmpresa = empresas.firstWhere(
            (e) => e.id == widget.executor!.empresaId,
            orElse: () => empresas.isNotEmpty ? empresas.first : empresas.first,
          );
        }
      });
    } catch (e) {
      print('Erro ao carregar empresas: $e');
      setState(() {
        _isLoadingEmpresas = false;
      });
    }
  }

  Future<void> _loadFuncoes() async {
    setState(() {
      _isLoadingFuncoes = true;
    });

    try {
      final funcoes = await _funcaoService.getAllFuncoes();
      setState(() {
        _funcoes = funcoes;
        _isLoadingFuncoes = false;

        // Selecionar a função se estiver editando
        if (widget.executor != null && widget.executor!.funcaoId != null) {
          _selectedFuncao = funcoes.firstWhere(
            (f) => f.id == widget.executor!.funcaoId,
            orElse: () => funcoes.isNotEmpty ? funcoes.first : funcoes.first,
          );
        }
      });
    } catch (e) {
      print('Erro ao carregar funções: $e');
      setState(() {
        _isLoadingFuncoes = false;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final executor = Executor(
        id: widget.executor?.id ?? '',
        nome: _nomeController.text.trim(),
        nomeCompleto: _nomeCompletoController.text.trim().isEmpty
            ? null
            : _nomeCompletoController.text.trim(),
        matricula: _matriculaController.text.trim().isEmpty
            ? null
            : _matriculaController.text.trim(),
        login: _loginController.text.trim().isEmpty
            ? null
            : _loginController.text.trim(),
        ramal: _ramalController.text.trim().isEmpty
            ? null
            : _ramalController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        empresaId: _selectedEmpresa?.id,
        funcaoId: _selectedFuncao?.id,
        divisaoId: _selectedDivisao?.id,
        segmentoIds: _selectedSegmentoIds.toList(),
        segmentos: _segmentos
            .where((s) => _selectedSegmentoIds.contains(s.id))
            .map((s) => s.segmento)
            .toList(),
        ativo: _ativo,
      );

      Navigator.of(context).pop(executor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.executor == null ? 'Novo Executor' : 'Editar Executor'),
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
              // Nome Completo
              TextFormField(
                controller: _nomeCompletoController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Matrícula
              TextFormField(
                controller: _matriculaController,
                decoration: const InputDecoration(
                  labelText: 'Matrícula',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Login
              TextFormField(
                controller: _loginController,
                decoration: const InputDecoration(
                  labelText: 'Login',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Ramal
              TextFormField(
                controller: _ramalController,
                decoration: const InputDecoration(
                  labelText: 'Ramal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Telefone
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Empresa
              _isLoadingEmpresas
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Empresa>(
                      value: _selectedEmpresa,
                      decoration: const InputDecoration(
                        labelText: 'Empresa (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Empresa>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._empresas.map((empresa) {
                          return DropdownMenuItem<Empresa>(
                            value: empresa,
                            child: Text(empresa.empresa),
                          );
                        }),
                      ],
                      onChanged: (empresa) {
                        setState(() {
                          _selectedEmpresa = empresa;
                        });
                      },
                    ),
              const SizedBox(height: 16),
              // Função
              _isLoadingFuncoes
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Funcao>(
                      value: _selectedFuncao,
                      decoration: const InputDecoration(
                        labelText: 'Função (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Funcao>(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._funcoes.map((funcao) {
                          return DropdownMenuItem<Funcao>(
                            value: funcao,
                            child: Text(funcao.funcao),
                          );
                        }),
                      ],
                      onChanged: (funcao) {
                        setState(() {
                          _selectedFuncao = funcao;
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

