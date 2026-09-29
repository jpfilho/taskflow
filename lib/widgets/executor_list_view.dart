import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/executor.dart';
import '../services/executor_service.dart';
import 'executor_form_dialog.dart';

class ExecutorListView extends StatefulWidget {
  const ExecutorListView({super.key});

  @override
  State<ExecutorListView> createState() => _ExecutorListViewState();
}

class _ExecutorListViewState extends State<ExecutorListView> {
  final ExecutorService _executorService = ExecutorService();
  List<Executor> _executores = [];
  List<Executor> _filteredExecutores = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Filtros multiescolha por coluna
  Set<String> _selectedEmpresas = {};
  Set<String> _selectedFuncoes = {};
  Set<String> _selectedDivisoes = {};
  Set<String> _selectedSegmentos = {};

  bool get _hasActiveFilters =>
      _selectedEmpresas.isNotEmpty ||
      _selectedFuncoes.isNotEmpty ||
      _selectedDivisoes.isNotEmpty ||
      _selectedSegmentos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedEmpresas.clear();
      _selectedFuncoes.clear();
      _selectedDivisoes.clear();
      _selectedSegmentos.clear();
      _searchController.clear();
      _currentPage = 1;
      _filteredExecutores = _applyFilter(_executores);
    });
  }

  List<String> _getUniqueEmpresas() {
    return _executores
        .map((e) => e.empresa?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueFuncoes() {
    return _executores
        .map((e) => e.funcao?.trim() ?? '')
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _executores
        .map((e) => e.divisao?.trim() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSegmentos() {
    final segs = <String>{};
    for (final e in _executores) {
      for (final s in e.segmentos) {
        if (s.trim().isNotEmpty) segs.add(s.trim());
      }
    }
    return segs.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadExecutores();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExecutores() async {
    setState(() => _isLoading = true);

    try {
      final executores = await _executorService.getAllExecutores();
      if (mounted) {
        setState(() {
          _executores = executores;
          _filteredExecutores = _applyFilter(executores);
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar executores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Executor> _applyFilter(List<Executor> list) {
    final query = _searchController.text.toLowerCase().trim();

    return list.where((executor) {
      final empresaStr = executor.empresa?.trim() ?? '';
      final funcaoStr = executor.funcao?.trim() ?? '';
      final divisaoStr = executor.divisao?.trim() ?? '';

      // Filtros multiescolha
      if (_selectedEmpresas.isNotEmpty && !_selectedEmpresas.contains(empresaStr)) {
        return false;
      }
      if (_selectedFuncoes.isNotEmpty && !_selectedFuncoes.contains(funcaoStr)) {
        return false;
      }
      if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divisaoStr)) {
        return false;
      }
      if (_selectedSegmentos.isNotEmpty &&
          !executor.segmentos.any((s) => _selectedSegmentos.contains(s.trim()))) {
        return false;
      }

      // Busca por texto
      if (query.isNotEmpty) {
        final matches = executor.nome.toLowerCase().contains(query) ||
            (executor.nomeCompleto?.toLowerCase().contains(query) ?? false) ||
            (executor.matricula?.toLowerCase().contains(query) ?? false) ||
            (executor.login?.toLowerCase().contains(query) ?? false) ||
            empresaStr.toLowerCase().contains(query) ||
            funcaoStr.toLowerCase().contains(query) ||
            divisaoStr.toLowerCase().contains(query) ||
            executor.segmentos.any((s) => s.toLowerCase().contains(query));
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 1;
      _filteredExecutores = _applyFilter(_executores);
    });
  }

  List<Executor> get _paginatedExecutores {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= _filteredExecutores.length) return [];
    final endIndex = (startIndex + _itemsPerPage < _filteredExecutores.length)
        ? startIndex + _itemsPerPage
        : _filteredExecutores.length;
    return _filteredExecutores.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredExecutores.length / _itemsPerPage).ceil().clamp(1, 9999);

  Future<void> _createExecutor() async {
    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => const ExecutorFormDialog(),
    );

    if (result != null) {
      try {
        await _executorService.createExecutor(result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateExecutor(Executor executor) async {
    final duplicated = executor.copyWith(
      id: '',
      nome: '${executor.nome} (Cópia)',
    );

    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => ExecutorFormDialog(executor: duplicated),
    );

    if (result != null) {
      try {
        await _executorService.createExecutor(result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao duplicar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editExecutor(Executor executor) async {
    final executorAtualizado = await _executorService.getExecutorById(executor.id);
    if (executorAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do executor'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => ExecutorFormDialog(executor: executorAtualizado),
    );

    if (result != null) {
      try {
        await _executorService.updateExecutor(executor.id, result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteExecutor(Executor executor) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir o executor "${executor.nome}"?\n\n'
          'Matrícula: ${executor.matricula ?? "Não informada"}\n'
          'Função: ${executor.funcao ?? "Geral"}',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _executorService.deleteExecutor(executor.id);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TFPageHeader(
                title: 'Executores',
                subtitle: 'Gestão cadastral de técnicos, operadores e lideranças',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Novo Executor',
                  leadingIcon: TFIcons.add,
                  onPressed: _createExecutor,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Atualizar',
                    variant: TFIconButtonVariant.standard,
                    onPressed: _loadExecutores,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar por nome, matrícula, login, função, empresa ou divisão...',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    SizedBox(width: spacing.sm),
                    TFButton(
                      label: 'Limpar Filtros',
                      variant: TFButtonVariant.secondary,
                      leadingIcon: Icons.filter_alt_off,
                      onPressed: _clearAllFilters,
                    ),
                  ],
                ],
              ),
              SizedBox(height: spacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Empresa',
                        selectedValues: _selectedEmpresas,
                        options: _getUniqueEmpresas(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedEmpresas = values;
                            _currentPage = 1;
                            _filteredExecutores = _applyFilter(_executores);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Função',
                        selectedValues: _selectedFuncoes,
                        options: _getUniqueFuncoes(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedFuncoes = values;
                            _currentPage = 1;
                            _filteredExecutores = _applyFilter(_executores);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Divisão',
                        selectedValues: _selectedDivisoes,
                        options: _getUniqueDivisoes(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedDivisoes = values;
                            _currentPage = 1;
                            _filteredExecutores = _applyFilter(_executores);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Segmento',
                        selectedValues: _selectedSegmentos,
                        options: _getUniqueSegmentos(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedSegmentos = values;
                            _currentPage = 1;
                            _filteredExecutores = _applyFilter(_executores);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: TFLoading(
                        mode: TFLoadingMode.section,
                        message: 'Carregando executores...',
                      ),
                    )
                  : _filteredExecutores.isEmpty
                      ? TFEmptyState(
                          icon: TFIcons.search,
                          title: _executores.isEmpty
                              ? 'Nenhum executor cadastrado'
                              : 'Nenhum executor encontrado',
                          description: _executores.isEmpty
                              ? 'Cadastre o primeiro colaborador para atribuição de tarefas e equipes.'
                              : 'Tente refinar sua busca.',
                          action: _executores.isEmpty
                              ? TFButton(
                                  label: 'Cadastrar Primeiro Executor',
                                  leadingIcon: TFIcons.add,
                                  onPressed: _createExecutor,
                                )
                              : TFButton(
                                  label: 'Limpar Busca',
                                  variant: TFButtonVariant.secondary,
                                  onPressed: () => _searchController.clear(),
                                ),
                        )
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          child: Column(
                            children: [
                              Expanded(
                                child: isDesktop
                                    ? _buildTableView()
                                    : _buildCardsView(),
                              ),
                              if (_totalPages > 1) ...[
                                SizedBox(height: spacing.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Página $_currentPage de $_totalPages (${_filteredExecutores.length} executores)',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TFIconButton(
                                          icon: Icons.chevron_left,
                                          tooltip: 'Página anterior',
                                          variant: TFIconButtonVariant.standard,
                                          onPressed: _currentPage > 1
                                              ? () => setState(() => _currentPage--)
                                              : null,
                                        ),
                                        SizedBox(width: spacing.xs),
                                        TFIconButton(
                                          icon: Icons.chevron_right,
                                          tooltip: 'Próxima página',
                                          variant: TFIconButtonVariant.standard,
                                          onPressed: _currentPage < _totalPages
                                              ? () => setState(() => _currentPage++)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: spacing.sm),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCardsView() {
    final items = _paginatedExecutores;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final executor = items[index];
        return TFCard(
          child: Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        executor.nome,
                        style: typography.cardTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TFStatusBadge(
                      label: executor.ativo ? 'Ativo' : 'Inativo',
                      severity: executor.ativo
                          ? TFStatusSeverity.success
                          : TFStatusSeverity.neutral,
                      compact: true,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Função: ${executor.funcao ?? "-"} • Matrícula: ${executor.matricula ?? "-"}',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Divisão: ${executor.divisao ?? "-"} | Empresa: ${executor.empresa ?? "-"}',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (executor.segmentos.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    'Segmentos: ${executor.segmentos.join(", ")}',
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar executor',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateExecutor(executor),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editExecutor(executor),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _deleteExecutor(executor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFDataTable<Executor>(
      items: _paginatedExecutores,
      columns: [
        TFDataColumn<Executor>.text(
          id: 'nome',
          title: 'Nome',
          cellBuilder: (context, executor) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                executor.nome,
                style: typography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (executor.nomeCompleto != null && executor.nomeCompleto!.isNotEmpty)
                Text(
                  executor.nomeCompleto!,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        TFDataColumn<Executor>.text(
          id: 'matricula',
          title: 'Matrícula',
          width: 120,
          cellBuilder: (context, executor) => Text(
            executor.matricula ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        TFDataColumn<Executor>.text(
          id: 'funcao',
          title: 'Função',
          width: 150,
          cellBuilder: (context, executor) => Text(
            executor.funcao ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Executor>.text(
          id: 'divisao',
          title: 'Divisão',
          width: 140,
          cellBuilder: (context, executor) => Text(
            executor.divisao ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Executor>.text(
          id: 'empresa',
          title: 'Empresa',
          width: 140,
          cellBuilder: (context, executor) => Text(
            executor.empresa ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Executor>(
          id: 'status',
          label: const Text('Status'),
          width: 110,
          cellBuilder: (context, executor) => TFStatusBadge(
            label: executor.ativo ? 'Ativo' : 'Inativo',
            severity: executor.ativo
                ? TFStatusSeverity.success
                : TFStatusSeverity.neutral,
            compact: true,
          ),
        ),
        TFDataColumn<Executor>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, executor) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateExecutor(executor),
              ),
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editExecutor(executor),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _deleteExecutor(executor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
