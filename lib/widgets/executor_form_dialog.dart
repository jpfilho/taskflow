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
import 'form_dialog_helpers.dart';

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
  Set<String> _selectedSegmentoIds = {};
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
    final isEditing = widget.executor != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Executor' : 'Novo Executor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do executor.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingLabelTextField(
                        label: 'Nome *',
                        controller: _nomeController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nome é obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Nome Completo',
                        controller: _nomeCompletoController,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Matrícula',
                        controller: _matriculaController,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Login',
                        controller: _loginController,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Ramal',
                        controller: _ramalController,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Telefone',
                        controller: _telefoneController,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<Empresa>(
                        label: 'Empresa',
                        value: _selectedEmpresa,
                        items: _empresas,
                        isLoading: _isLoadingEmpresas,
                        displayText: (empresa) => empresa.empresa,
                        onChanged: (value) {
                          setState(() {
                            _selectedEmpresa = value;
                          });
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<Funcao>(
                        label: 'Função',
                        value: _selectedFuncao,
                        items: _funcoes,
                        isLoading: _isLoadingFuncoes,
                        displayText: (funcao) => funcao.funcao,
                        onChanged: (value) {
                          setState(() {
                            _selectedFuncao = value;
                          });
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<Divisao>(
                        label: 'Divisão',
                        value: _selectedDivisao,
                        items: _divisoes,
                        isLoading: _isLoadingDivisoes,
                        displayText: (divisao) => divisao.divisao,
                        onChanged: (value) {
                          setState(() {
                            _selectedDivisao = value;
                          });
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Segmentos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1e293b).withOpacity(0.5) : const Color(0xFFf8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFe2e8f0),
                          ),
                        ),
                        child: _isLoadingSegmentos
                            ? const Center(child: CircularProgressIndicator())
                            : _segmentos.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Nenhum segmento disponível',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _segmentos.map((segmento) {
                                        final isSelected = _selectedSegmentoIds.contains(segmento.id);
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedSegmentoIds.remove(segmento.id);
                                              } else {
                                                _selectedSegmentoIds.add(segmento.id);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    segmento.segmento,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isSelected
                                                          ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                                                          : (isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
                                                    ),
                                                  ),
                                                ),
                                                Checkbox(
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
                                                  activeColor: const Color(0xFF3b82f6),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Ativo',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                            ),
                          ),
                          value: _ativo,
                          activeThumbColor: const Color(0xFF3b82f6),
                          onChanged: (value) {
                            setState(() {
                              _ativo = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer com botões
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar Alterações' : 'Criar Executor',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
