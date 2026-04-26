import 'package:flutter/material.dart';
import '../models/feriado.dart';
import '../models/local.dart';
import '../services/feriado_service.dart';
import '../services/local_service.dart';
import 'form_dialog_helpers.dart';

class FeriadoFormDialog extends StatefulWidget {
  final Feriado? feriado;
  final Function()? onSaved;

  const FeriadoFormDialog({
    super.key,
    this.feriado,
    this.onSaved,
  });

  @override
  State<FeriadoFormDialog> createState() => _FeriadoFormDialogState();
}

class _FeriadoFormDialogState extends State<FeriadoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _feriadoService = FeriadoService();
  final _localService = LocalService();

  DateTime? _selectedDate;
  final _descricaoController = TextEditingController();
  String? _selectedTipo;
  final _paisController = TextEditingController(text: 'Brasil');
  final _estadoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _searchController = TextEditingController();

  final List<String> _tipos = ['NACIONAL', 'ESTADUAL', 'MUNICIPAL', 'EVENTO'];

  bool _isLoadingLocais = true;
  List<Local> _locaisPermitidos = [];
  List<Local> _todosLocais = [];
  Set<String> _locaisSelecionados = {};

  @override
  void initState() {
    super.initState();
    if (widget.feriado != null) {
      _selectedDate = widget.feriado!.data;
      _descricaoController.text = widget.feriado!.descricao;
      _selectedTipo = widget.feriado!.tipo;
      _paisController.text = widget.feriado!.pais ?? 'Brasil';
      _estadoController.text = widget.feriado!.estado ?? '';
      _cidadeController.text = widget.feriado!.cidade ?? '';
    } else {
      _selectedDate = DateTime.now();
      _paisController.text = 'Brasil';
    }
    _loadLocais();
  }

  Future<void> _loadLocais() async {
    final locaisPermitidos = await _feriadoService.getLocaisPermitidosParaUsuarioAtual();
    final todosLocais = await _localService.getAllLocais();
    
    setState(() {
      _locaisPermitidos = locaisPermitidos;
      _todosLocais = todosLocais;
      
      if (widget.feriado != null) {
        _locaisSelecionados = widget.feriado!.localIds.toSet();
        // Se for edição de um feriado nacional já existente, garante que ele use a lista completa de locais
        // mas mantém a seleção original do banco.
      } else {
        // Se for novo e nacional, seleciona todos. Se não, seleciona os permitidos.
        if (_selectedTipo == 'NACIONAL') {
          _locaisSelecionados = todosLocais.map((l) => l.id).toSet();
        } else {
          _locaisSelecionados = locaisPermitidos.map((l) => l.id).toSet();
        }
      }
      _isLoadingLocais = false;
    });
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _paisController.dispose();
    _estadoController.dispose();
    _cidadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onTipoChanged(String? tipo) {
    setState(() {
      _selectedTipo = tipo;
      if (tipo == 'NACIONAL') {
        _estadoController.clear();
        _cidadeController.clear();
        // Quando muda para nacional, seleciona todos os locais do banco
        _locaisSelecionados = _todosLocais.map((l) => l.id).toSet();
      } else if (tipo == 'ESTADUAL') {
        _cidadeController.clear();
        // Se mudou de nacional para outro, volta para os permitidos (opcional, mas seguro)
        // _locaisSelecionados = _locaisPermitidos.map((l) => l.id).toSet();
      }
    });
  }

  List<Local> _getFilteredLocais() {
    final query = _searchController.text.toLowerCase().trim();
    final source = _selectedTipo == 'NACIONAL' ? _todosLocais : _locaisPermitidos;
    
    if (query.isEmpty) return source;
    
    return source.where((l) {
      return l.local.toLowerCase().contains(query) ||
             l.regional.toLowerCase().contains(query) ||
             l.divisao.toLowerCase().contains(query) ||
             l.segmento.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma data')),
      );
      return;
    }

    if (_selectedTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione o tipo de feriado')),
      );
      return;
    }

    if (_locaisSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione pelo menos um local aplicável')),
      );
      return;
    }

    if (_selectedTipo == 'NACIONAL' && _paisController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País é obrigatório para feriado nacional')),
      );
      return;
    }

    if (_selectedTipo == 'ESTADUAL' && 
        (_paisController.text.isEmpty || _estadoController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País e Estado são obrigatórios para feriado estadual')),
      );
      return;
    }

    if (_selectedTipo == 'MUNICIPAL' && 
        (_paisController.text.isEmpty || 
         _estadoController.text.isEmpty || 
         _cidadeController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('País, Estado e Cidade são obrigatórios para feriado municipal')),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final feriado = Feriado(
        id: widget.feriado?.id ?? '',
        data: _selectedDate!,
        descricao: _descricaoController.text.trim(),
        tipo: _selectedTipo!,
        pais: _paisController.text.trim().isEmpty ? null : _paisController.text.trim(),
        estado: _estadoController.text.trim().isEmpty ? null : _estadoController.text.trim(),
        cidade: _cidadeController.text.trim().isEmpty ? null : _cidadeController.text.trim(),
        localIds: _locaisSelecionados.toList(),
        createdAt: widget.feriado?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.feriado != null) {
        await _feriadoService.updateFeriado(feriado);
      } else {
        await _feriadoService.createFeriado(feriado);
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onSaved != null) {
          widget.onSaved!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.feriado != null 
                ? 'Feriado atualizado com sucesso' 
                : 'Feriado criado com sucesso'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar feriado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.feriado != null;
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
                    isEditing ? 'Editar Feriado' : 'Novo Feriado',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações do feriado.',
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
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Data *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF3b82f6),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                                    : 'Selecione uma data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Descrição *',
                        controller: _descricaoController,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe a descrição';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelDropdown<String>(
                        label: 'Tipo *',
                        value: _selectedTipo,
                        items: _tipos,
                        isLoading: false,
                        displayText: (tipo) => tipo,
                        onChanged: _onTipoChanged,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor, selecione o tipo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'País *',
                        controller: _paisController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo != null && 
                              (_selectedTipo == 'NACIONAL' || 
                               _selectedTipo == 'ESTADUAL' || 
                               _selectedTipo == 'MUNICIPAL')) {
                            if (value == null || value.trim().isEmpty) {
                              return 'País é obrigatório';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Estado',
                        controller: _estadoController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo == 'ESTADUAL' || _selectedTipo == 'MUNICIPAL') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Estado é obrigatório';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FloatingLabelTextField(
                        label: 'Cidade',
                        controller: _cidadeController,
                        isDark: isDark,
                        validator: (value) {
                          if (_selectedTipo == 'MUNICIPAL') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Cidade é obrigatória';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Locais Aplicáveis *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingLocais)
                        const Center(child: CircularProgressIndicator())
                      else
                        Container(
                          height: 350, // Aumentado para acomodar a busca
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Campo de Busca
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Pesquisar local...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    suffixIcon: _searchController.text.isNotEmpty 
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        ) 
                                      : null,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFf8fafc),
                                  border: Border(
                                    top: BorderSide(
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                                    ),
                                    bottom: BorderSide(
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final filtered = _getFilteredLocais();
                                        final allSelected = filtered.isNotEmpty && 
                                            filtered.every((l) => _locaisSelecionados.contains(l.id));
                                        final someSelected = filtered.any((l) => _locaisSelecionados.contains(l.id)) && !allSelected;
                                        
                                        return Checkbox(
                                          value: allSelected,
                                          tristate: someSelected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                for (var l in filtered) {
                                                  _locaisSelecionados.add(l.id);
                                                }
                                              } else {
                                                for (var l in filtered) {
                                                  _locaisSelecionados.remove(l.id);
                                                }
                                              }
                                            });
                                          },
                                        );
                                      }
                                    ),
                                    const Text('Selecionar Filtrados'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final filtered = _getFilteredLocais();
                                    if (filtered.isEmpty) {
                                      return const Center(
                                        child: Text('Nenhum local encontrado'),
                                      );
                                    }
                                    return ListView.builder(
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final local = filtered[index];
                                        return CheckboxListTile(
                                          title: Text(local.local),
                                          subtitle: Text(
                                            '${local.regional}${local.divisao.isNotEmpty ? ' / ${local.divisao}' : ''}${local.segmento.isNotEmpty ? ' / ${local.segmento}' : ''}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          value: _locaisSelecionados.contains(local.id),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _locaisSelecionados.add(local.id);
                                              } else {
                                                _locaisSelecionados.remove(local.id);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    );
                                  }
                                ),
                              ),
                            ],
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
                      isEditing ? 'Salvar Alterações' : 'Criar Feriado',
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
