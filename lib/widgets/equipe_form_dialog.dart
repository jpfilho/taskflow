import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../design_system/taskflow_design_system.dart';
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
import '../services/auth_service_simples.dart';

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
  final AuthServiceSimples _authService = AuthServiceSimples();
  
  List<Executor> _executores = [];
  List<Regional> _regionais = [];
  List<Divisao> _allDivisoes = [];
  List<Divisao> _filteredDivisoes = [];
  List<Segmento> _segmentos = [];
  List<EquipeExecutor> _equipeExecutores = [];
  
  String _tipo = 'FIXA';
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Segmento? _selectedSegmento;
  bool _ativo = true;
  bool _isSaving = false;
  
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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadRegionais(),
      _loadDivisoes(),
      _loadSegmentos(),
    ]);
    await _loadExecutores();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _loadExecutores() async {
    if (mounted) setState(() => _isLoadingExecutores = true);
    try {
      final usuario = _authService.currentUser;
      final executores = await _executorService.getExecutoresPorPerfilUsuario(
        regionalIds: usuario?.regionalIds ?? [],
        divisaoIds: usuario?.divisaoIds ?? [],
        segmentoIds: usuario?.segmentoIds ?? [],
        formRegionalId: _selectedRegional?.id,
        formDivisaoId: _selectedDivisao?.id,
        formSegmentoId: _selectedSegmento?.id,
      );
      if (mounted) {
        setState(() {
          _executores = executores;
          _isLoadingExecutores = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar executores por perfil: $e');
      try {
        final executores = await _executorService.getExecutoresAtivos();
        if (mounted) {
          setState(() {
            _executores = executores;
            _isLoadingExecutores = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() => _isLoadingExecutores = false);
        }
      }
    }
  }

  Future<void> _loadRegionais() async {
    setState(() => _isLoadingRegionais = true);
    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

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
      debugPrint('Erro ao carregar regionais: $e');
      setState(() => _isLoadingRegionais = false);
    }
  }

  Future<void> _loadDivisoes() async {
    setState(() => _isLoadingDivisoes = true);
    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      setState(() {
        _allDivisoes = divisoes;
        _isLoadingDivisoes = false;
        _updateFilteredDivisoes();

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
      debugPrint('Erro ao carregar divisões: $e');
      setState(() => _isLoadingDivisoes = false);
    }
  }

  Future<void> _loadSegmentos() async {
    setState(() => _isLoadingSegmentos = true);
    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;

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
      debugPrint('Erro ao carregar segmentos: $e');
      setState(() => _isLoadingSegmentos = false);
    }
  }

  void _updateFilteredDivisoes() {
    if (_selectedRegional != null) {
      _filteredDivisoes = _allDivisoes
          .where((d) => d.atuaNaRegional(_selectedRegional!.id))
          .toList();
    } else {
      _filteredDivisoes = _allDivisoes;
    }
  }

  void _onRegionalChanged(Regional? regional) {
    setState(() {
      _selectedRegional = regional;
      _selectedDivisao = null;
      _updateFilteredDivisoes();
    });
    _loadExecutores();
  }

  void _onDivisaoChanged(Divisao? divisao) {
    setState(() {
      _selectedDivisao = divisao;
    });
    _loadExecutores();
  }

  void _onSegmentoChanged(Segmento? segmento) {
    setState(() {
      _selectedSegmento = segmento;
    });
    _loadExecutores();
  }

  void _adicionarExecutor(Executor executor, String papel) {
    final index = _equipeExecutores.indexWhere(
      (e) => e.executorId == executor.id,
    );
    
    if (index >= 0) {
      _equipeExecutores[index] = EquipeExecutor(
        executorId: executor.id,
        executorNome: executor.nomeCompleto ?? executor.nome,
        papel: papel,
      );
    } else {
      _equipeExecutores.add(EquipeExecutor(
        executorId: executor.id,
        executorNome: executor.nomeCompleto ?? executor.nome,
        papel: papel,
      ));
    }
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
      setState(() => _isSaving = true);
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

  Widget _buildSearchableDropdown<T extends Object>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?) onChanged,
    bool isRequired = false,
    bool isLoading = false,
    String? hint,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.labelMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: spacing.xxs),
              Text(
                '*',
                style: typography.labelMedium.copyWith(
                  color: colors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.xxs),
        DropdownSearch<T>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Pesquisar $label...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            menuProps: MenuProps(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 280),
          ),
          items: (filter, loadProps) => items,
          selectedItem: value,
          itemAsString: getDisplayText,
          compareFn: (a, b) => a == b,
          onChanged: onChanged,
          enabled: !isLoading,
          filterFn: (item, filter) {
            if (filter.isEmpty) return true;
            return getDisplayText(item).toLowerCase().contains(filter.toLowerCase());
          },
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              isDense: true,
              hintText: isLoading ? 'Carregando...' : (hint ?? 'Selecione $label'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.equipe != null;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFFormDialog(
      title: isEditing ? 'Editar Equipe' : 'Nova Equipe',
      subtitle: 'Atualize os dados e a composição da equipe.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Equipe',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              label: 'Nome da Equipe',
              controller: _nomeController,
              required: true,
              hint: 'Informe o nome da equipe',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              label: 'Descrição',
              controller: _descricaoController,
              hint: 'Descrição operacional da equipe (opcional)',
              maxLines: 2,
            ),
            SizedBox(height: spacing.md),
            TFDropdown<String>(
              label: 'Tipo',
              isRequired: true,
              value: _tipo,
              items: const ['FIXA', 'FLEXIVEL'],
              displayText: (t) => t == 'FIXA' ? 'Fixa' : 'Flexível',
              onChanged: (val) {
                if (val != null) {
                  setState(() => _tipo = val);
                }
              },
            ),
            SizedBox(height: spacing.lg),
            Text(
              'Vínculos Organizacionais (Opcionais)',
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.sm),
            _buildSearchableDropdown<Regional>(
              label: 'Regional',
              value: _selectedRegional,
              items: _regionais,
              getDisplayText: (r) => r.regional,
              isLoading: _isLoadingRegionais,
              hint: 'Selecione uma Regional',
              onChanged: _onRegionalChanged,
            ),
            SizedBox(height: spacing.md),
            _buildSearchableDropdown<Divisao>(
              label: 'Divisão',
              value: _selectedDivisao,
              items: _filteredDivisoes,
              getDisplayText: (d) => d.divisao,
              isLoading: _isLoadingDivisoes,
              hint: 'Selecione uma Divisão',
              onChanged: _onDivisaoChanged,
            ),
            SizedBox(height: spacing.md),
            _buildSearchableDropdown<Segmento>(
              label: 'Segmento',
              value: _selectedSegmento,
              items: _segmentos,
              getDisplayText: (s) => s.segmento,
              isLoading: _isLoadingSegmentos,
              hint: 'Selecione um Segmento',
              onChanged: _onSegmentoChanged,
            ),
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Composição da Equipe (${_equipeExecutores.length})',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: spacing.sm),
                TFButton(
                  label: 'Adicionar Executor',
                  leadingIcon: Icons.group_add_rounded,
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.secondary,
                  onPressed: _showAdicionarExecutoresDialog,
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: _isLoadingExecutores
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  : _equipeExecutores.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: Center(
                            child: Text(
                              'Nenhum executor alocado nesta equipe',
                              style: typography.bodySmall.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _equipeExecutores.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: colors.borderSubtle),
                          itemBuilder: (context, index) {
                            final equipeExecutor = _equipeExecutores[index];
                            final executor = _executores.firstWhere(
                              (e) => e.id == equipeExecutor.executorId,
                              orElse: () => Executor(
                                id: equipeExecutor.executorId,
                                nome: equipeExecutor.executorNome,
                              ),
                            );
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      executor.nomeCompleto ?? executor.nome,
                                      style: typography.bodyMedium.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: spacing.sm),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: DropdownButton<String>(
                                        value: equipeExecutor.papel,
                                        isDense: true,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                                        items: const [
                                          DropdownMenuItem(value: 'FISCAL', child: Text('Fiscal')),
                                          DropdownMenuItem(value: 'TST', child: Text('TST')),
                                          DropdownMenuItem(value: 'ENCARREGADO', child: Text('Encarregado')),
                                          DropdownMenuItem(value: 'EXECUTOR', child: Text('Executor')),
                                        ],
                                        onChanged: (novoPapel) {
                                          if (novoPapel != null) {
                                            _alterarPapel(executor.id, novoPapel);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.danger),
                                    onPressed: () => _removerExecutor(executor.id),
                                    tooltip: 'Remover da equipe',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SizedBox(height: spacing.lg),
            TFSwitch(
              label: 'Ativo',
              description: 'Define se a equipe está ativa para execução e programação de tarefas',
              value: _ativo,
              onChanged: (value) => setState(() => _ativo = value),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdicionarExecutoresDialog() {
    final executoresDisponiveis = _executores.where((executor) {
      return !_equipeExecutores.any((e) => e.executorId == executor.id);
    }).toList();

    if (executoresDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum executor disponível no escopo selecionado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Set<String> selecionadosIds = {};
    String papelPadrao = 'EXECUTOR';
    String? modalSegmentoId = _selectedSegmento?.id;
    String query = '';
    final searchCtrl = TextEditingController();
    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDlgState) {
          final filtrados = executoresDisponiveis.where((e) {
            // Filtro por Segmento selecionado no modal
            if (modalSegmentoId != null && modalSegmentoId!.isNotEmpty) {
              final temSegmentoId = e.segmentoIds.contains(modalSegmentoId);
              final temSegmentoNome = _segmentos.any(
                (s) => s.id == modalSegmentoId && e.segmentos.any((seg) => seg.toLowerCase() == s.segmento.toLowerCase()),
              );
              // Se o executor tem segmentos específicos e não bate com o selecionado, filtra
              if (!temSegmentoId && !temSegmentoNome && e.segmentoIds.isNotEmpty) {
                return false;
              }
            }

            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            final n = (e.nomeCompleto ?? e.nome).toLowerCase();
            final f = (e.funcao ?? '').toLowerCase();
            final m = (e.matricula ?? '').toLowerCase();
            final d = (e.divisao ?? '').toLowerCase();
            final s = e.segmentos.join(' ').toLowerCase();
            return n.contains(q) || f.contains(q) || m.contains(q) || d.contains(q) || s.contains(q);
          }).toList();

          final todosFiltradosSelecionados = filtrados.isNotEmpty &&
              filtrados.every((e) => selecionadosIds.contains(e.id));

          final screenHeight = MediaQuery.of(ctx).size.height;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 680,
                maxHeight: (screenHeight * 0.85).clamp(450.0, 750.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.group_add_rounded, color: Color(0xFF1726C8)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Adicionar Executores',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Campo de Pesquisa
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar por nome, matrícula, função ou segmento...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDlgState(() {
                                    query = '';
                                    searchCtrl.clear();
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      onChanged: (v) => setDlgState(() => query = v),
                    ),
                    const SizedBox(height: 10),

                    // Filtros: Papel + Segmento + Selecionar Todos
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Papel: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButton<String>(
                                value: papelPadrao,
                                isDense: true,
                                underline: const SizedBox(),
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                items: const [
                                  DropdownMenuItem(value: 'EXECUTOR', child: Text('Executor')),
                                  DropdownMenuItem(value: 'ENCARREGADO', child: Text('Encarregado')),
                                  DropdownMenuItem(value: 'TST', child: Text('TST')),
                                  DropdownMenuItem(value: 'FISCAL', child: Text('Fiscal')),
                                ],
                                onChanged: (p) {
                                  if (p != null) setDlgState(() => papelPadrao = p);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_segmentos.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Segmento: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: DropdownButton<String?>(
                                  value: modalSegmentoId,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Todos os Segmentos')),
                                    ..._segmentos.map(
                                      (s) => DropdownMenuItem(value: s.id, child: Text(s.segmento)),
                                    ),
                                  ],
                                  onChanged: (sId) {
                                    setDlgState(() => modalSegmentoId = sId);
                                  },
                                ),
                              ),
                            ],
                          ),
                        TextButton.icon(
                          icon: const Icon(Icons.done_all, size: 16),
                          label: Text(
                            todosFiltradosSelecionados ? 'Desmarcar Todos' : 'Selecionar Todos',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: filtrados.isEmpty
                              ? null
                              : () {
                                  setDlgState(() {
                                    if (todosFiltradosSelecionados) {
                                      for (final e in filtrados) {
                                        selecionadosIds.remove(e.id);
                                      }
                                    } else {
                                      for (final e in filtrados) {
                                        selecionadosIds.add(e.id);
                                      }
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),

                    // Lista de Executores com Checkbox
                    Expanded(
                      child: filtrados.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum executor encontrado',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            )
                          : Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              child: ListView.separated(
                                controller: scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: filtrados.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (c, idx) {
                                  final exec = filtrados[idx];
                                  final isSelected = selecionadosIds.contains(exec.id);
                                  final subtitleParts = <String>[];
                                  if (exec.funcao != null && exec.funcao!.isNotEmpty) {
                                    subtitleParts.add(exec.funcao!);
                                  }
                                  if (exec.matricula != null && exec.matricula!.isNotEmpty) {
                                    subtitleParts.add('Matrícula: ${exec.matricula}');
                                  }
                                  if (exec.divisao != null && exec.divisao!.isNotEmpty) {
                                    subtitleParts.add(exec.divisao!);
                                  }
                                  if (exec.segmentos.isNotEmpty) {
                                    subtitleParts.add('Segmento: ${exec.segmentos.join(", ")}');
                                  }

                                  return CheckboxListTile(
                                    value: isSelected,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      exec.nomeCompleto ?? exec.nome,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: subtitleParts.isNotEmpty
                                        ? Text(
                                            subtitleParts.join(' • '),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                          )
                                        : null,
                                    onChanged: (val) {
                                      setDlgState(() {
                                        if (val == true) {
                                          selecionadosIds.add(exec.id);
                                        } else {
                                          selecionadosIds.remove(exec.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Footer Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selecionadosIds.length} selecionado(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1726C8)),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1726C8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: selecionadosIds.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        for (final id in selecionadosIds) {
                                          final exec = _executores.firstWhere((e) => e.id == id);
                                          _adicionarExecutor(exec, papelPadrao);
                                        }
                                      });
                                      Navigator.of(ctx).pop();
                                    },
                              child: Text('Adicionar (${selecionadosIds.length})'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
