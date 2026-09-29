import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/equipe.dart';
import '../services/auth_service_simples.dart';
import '../services/equipe_service.dart';
import '../services/performance_monitor.dart';
import 'equipe_form_dialog.dart';

class EquipeListView extends StatefulWidget {
  const EquipeListView({super.key});

  @override
  State<EquipeListView> createState() => _EquipeListViewState();
}

class _EquipeListViewState extends State<EquipeListView> {
  final EquipeService _equipeService = EquipeService();
  List<Equipe> _equipes = [];
  List<Equipe> _filteredEquipes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = true;
  Timer? _searchDebounce;

  // Filtros multiescolha por coluna
  Set<String> _selectedTipos = {};
  Set<String> _selectedRegionais = {};
  Set<String> _selectedDivisoes = {};
  Set<String> _selectedSegmentos = {};

  bool get _hasActiveFilters =>
      _selectedTipos.isNotEmpty ||
      _selectedRegionais.isNotEmpty ||
      _selectedDivisoes.isNotEmpty ||
      _selectedSegmentos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedTipos.clear();
      _selectedRegionais.clear();
      _selectedDivisoes.clear();
      _selectedSegmentos.clear();
      _searchController.clear();
      _filteredEquipes = _applyFilter(_equipes);
    });
  }

  List<String> _getUniqueTipos() {
    return _equipes
        .map((e) => _getTipoLabel(e.tipo))
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueRegionais() {
    return _equipes
        .map((e) => e.regional?.trim() ?? '')
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _equipes
        .map((e) => e.divisao?.trim() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSegmentos() {
    return _equipes
        .map((e) => e.segmento?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<Equipe> _applyFilter(List<Equipe> list) {
    final query = _searchController.text.trim().toLowerCase();

    return list.where((e) {
      final tipoLabel = _getTipoLabel(e.tipo);
      final regionalStr = e.regional?.trim() ?? '';
      final divisaoStr = e.divisao?.trim() ?? '';
      final segmentoStr = e.segmento?.trim() ?? '';

      // Filtros multiescolha
      if (_selectedTipos.isNotEmpty && !_selectedTipos.contains(tipoLabel)) {
        return false;
      }
      if (_selectedRegionais.isNotEmpty && !_selectedRegionais.contains(regionalStr)) {
        return false;
      }
      if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divisaoStr)) {
        return false;
      }
      if (_selectedSegmentos.isNotEmpty && !_selectedSegmentos.contains(segmentoStr)) {
        return false;
      }

      // Busca geral por texto
      if (query.isNotEmpty) {
        final matchNome = e.nome.toLowerCase().contains(query);
        final matchDesc = e.descricao?.toLowerCase().contains(query) ?? false;
        final matchExec = e.executores.any((ex) => ex.executorNome.toLowerCase().contains(query));
        final matchReg = regionalStr.toLowerCase().contains(query);
        final matchDiv = divisaoStr.toLowerCase().contains(query);
        final matchSeg = segmentoStr.toLowerCase().contains(query);
        if (!matchNome && !matchDesc && !matchExec && !matchReg && !matchDiv && !matchSeg) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadEquipes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipes() async {
    PerformanceMonitor.start('EquipeListView._loadEquipes');
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthServiceSimples().currentUser;
      final List<Equipe> equipes;

      if (currentUser != null &&
          !currentUser.isRoot &&
          (currentUser.regionalIds.isNotEmpty ||
              currentUser.divisaoIds.isNotEmpty ||
              currentUser.segmentoIds.isNotEmpty)) {
        equipes = await _equipeService.getEquipesPorPerfilUsuario(
          regionalIds: currentUser.regionalIds,
          divisaoIds: currentUser.divisaoIds,
          segmentoIds: currentUser.segmentoIds,
          includeInativas: true,
        );
      } else {
        equipes = await _equipeService.getAllEquipes();
      }

      if (mounted) {
        setState(() {
          _equipes = equipes;
          _filteredEquipes = _applyFilter(equipes);
          _isLoading = false;
        });
      }
      PerformanceMonitor.stop('EquipeListView._loadEquipes');
    } catch (e) {
      PerformanceMonitor.stop('EquipeListView._loadEquipes');
      debugPrint('Erro ao carregar equipes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar equipes: $e'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filteredEquipes = _applyFilter(_equipes);
        });
      }
    });
  }


  Future<void> _createEquipe() async {
    final result = await showDialog<Equipe>(
      context: context,
      builder: (context) => const EquipeFormDialog(),
    );

    if (result != null) {
      final created = await _equipeService.createEquipe(result);
      if (created != null) {
        await _loadEquipes();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Equipe criada com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao criar equipe.'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateEquipe(Equipe equipe) async {
    final equipeAtualizada = await _equipeService.getEquipeById(equipe.id);
    if (equipeAtualizada == null) {
      if (mounted) {
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao carregar dados da equipe'),
            backgroundColor: colors.danger,
          ),
        );
      }
      return;
    }

    final duplicated = equipeAtualizada.copyWith(
      id: '',
      nome: '${equipeAtualizada.nome} (Cópia)',
      executores: [],
    );

    if (!mounted) return;
    final result = await showDialog<Equipe>(
      context: context,
      builder: (context) => EquipeFormDialog(equipe: duplicated),
    );

    if (result != null) {
      final created = await _equipeService.createEquipe(result);
      if (created != null) {
        await _loadEquipes();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Equipe duplicada com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao duplicar equipe'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _editEquipe(Equipe equipe) async {
    final equipeAtualizada = await _equipeService.getEquipeById(equipe.id);
    if (equipeAtualizada == null) {
      if (mounted) {
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao carregar dados da equipe'),
            backgroundColor: colors.danger,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final result = await showDialog<Equipe>(
      context: context,
      builder: (context) => EquipeFormDialog(equipe: equipeAtualizada),
    );

    if (result != null) {
      final updated = await _equipeService.updateEquipe(equipe.id, result);
      if (updated != null) {
        await _loadEquipes();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Equipe atualizada com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao atualizar equipe.'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEquipe(Equipe equipe) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir a equipe "${equipe.nome}"?\nEsta ação não poderá ser desfeita.',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _equipeService.deleteEquipe(equipe.id);
      if (deleted) {
        await _loadEquipes();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Equipe excluída com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir equipe.'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  String _getTipoLabel(String tipo) {
    return tipo == 'FIXA' ? 'Fixa' : 'Flexível';
  }

  String _getPapelLabel(String papel) {
    switch (papel) {
      case 'FISCAL':
        return 'Fiscal';
      case 'TST':
        return 'TST';
      case 'ENCARREGADO':
        return 'Encarregado';
      case 'EXECUTOR':
        return 'Executor';
      default:
        return papel;
    }
  }

  IconData _getPapelIcon(String papel) {
    switch (papel) {
      case 'FISCAL':
        return Icons.gavel_rounded;
      case 'TST':
        return Icons.health_and_safety_rounded;
      case 'ENCARREGADO':
        return Icons.badge_rounded;
      case 'EXECUTOR':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final isDesktop = TFBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Page Header oficial TFDS
              TFPageHeader(
                title: 'Cadastro de Equipes',
                subtitle: 'Gestão de equipes fixas e flexíveis, executores e lideranças',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Nova Equipe',
                  leadingIcon: TFIcons.add,
                  variant: TFButtonVariant.primary,
                  onPressed: _createEquipe,
                ),
                secondaryActions: [
                  TFButton(
                    label: 'Atualizar',
                    leadingIcon: TFIcons.refresh,
                    variant: TFButtonVariant.secondary,
                    onPressed: _loadEquipes,
                  ),
                ],
              ),

              SizedBox(height: spacing.md),

              // 2. Barra de Busca e Alternância
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Pesquisar equipes por nome, executor ou descrição...',
                      prefixIcon: const Icon(TFIcons.search),
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
                  SizedBox(width: spacing.sm),
                  TFIconButton(
                    icon: _isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Visualizar em Cards' : 'Visualizar em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () {
                      setState(() {
                        _isTableView = !_isTableView;
                      });
                    },
                  ),
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
                        label: 'Tipo de Equipe',
                        selectedValues: _selectedTipos,
                        options: _getUniqueTipos(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedTipos = values;
                            _filteredEquipes = _applyFilter(_equipes);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Regional',
                        selectedValues: _selectedRegionais,
                        options: _getUniqueRegionais(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedRegionais = values;
                            _filteredEquipes = _applyFilter(_equipes);
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
                            _filteredEquipes = _applyFilter(_equipes);
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
                            _filteredEquipes = _applyFilter(_equipes);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing.md),

              // 3. Conteúdo Principal
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: TFLoading(
                          mode: TFLoadingMode.section,
                          message: 'Carregando equipes...',
                        ),
                      )
                    : _filteredEquipes.isEmpty
                        ? Center(
                            child: TFEmptyState(
                              icon: Icons.groups_outlined,
                              title: _equipes.isEmpty
                                  ? 'Nenhuma equipe cadastrada'
                                  : 'Nenhuma equipe encontrada',
                              description: _equipes.isEmpty
                                  ? 'Comece cadastrando a primeira equipe de campo da empresa.'
                                  : 'Não existem equipes compatíveis com os filtros atuais.',
                              action: _equipes.isEmpty
                                  ? TFButton(
                                      label: 'Cadastrar Primeira Equipe',
                                      leadingIcon: TFIcons.add,
                                      variant: TFButtonVariant.primary,
                                      onPressed: _createEquipe,
                                    )
                                  : TFButton(
                                      label: 'Limpar Busca',
                                      leadingIcon: TFIcons.clear,
                                      variant: TFButtonVariant.secondary,
                                      onPressed: () => _searchController.clear(),
                                    ),
                            ),
                          )
                        : _isTableView || isDesktop
                            ? _buildTableView()
                            : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFDataTable<Equipe>(
      items: _filteredEquipes,
      zebra: true,
      columns: [
        TFDataColumn<Equipe>.text(
          id: 'nome',
          title: 'Equipe',
          cellBuilder: (context, equipe) => Text(
            equipe.nome,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<Equipe>.text(
          id: 'tipo',
          title: 'Tipo',
          width: 100,
          cellBuilder: (context, equipe) => Text(
            _getTipoLabel(equipe.tipo),
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Equipe>.text(
          id: 'regional',
          title: 'Regional',
          width: 120,
          cellBuilder: (context, equipe) => Text(
            equipe.regional ?? '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Equipe>.text(
          id: 'divisao',
          title: 'Divisão',
          width: 120,
          cellBuilder: (context, equipe) => Text(
            equipe.divisao ?? '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Equipe>.text(
          id: 'segmento',
          title: 'Segmento',
          width: 120,
          cellBuilder: (context, equipe) => Text(
            equipe.segmento ?? '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Equipe>.text(
          id: 'executores',
          title: 'Executores',
          width: 110,
          cellBuilder: (context, equipe) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: colors.textSecondary),
              SizedBox(width: spacing.xxs),
              Text(
                '${equipe.executores.length}',
                style: typography.bodySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TFDataColumn<Equipe>(
          id: 'status',
          label: const Text('Status'),
          width: 110,
          cellBuilder: (context, equipe) => TFStatusBadge(
            label: equipe.ativo ? 'Ativa' : 'Inativa',
            severity: equipe.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
            compact: true,
          ),
        ),
        TFDataColumn<Equipe>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, equipe) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar "${equipe.nome}"',
                variant: TFIconButtonVariant.standard,
                iconSize: 18,
                onPressed: () => _editEquipe(equipe),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar "${equipe.nome}"',
                variant: TFIconButtonVariant.subtle,
                iconSize: 18,
                onPressed: () => _duplicateEquipe(equipe),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir "${equipe.nome}"',
                variant: TFIconButtonVariant.danger,
                iconSize: 18,
                onPressed: () => _deleteEquipe(equipe),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return ListView.builder(
      itemCount: _filteredEquipes.length,
      itemBuilder: (context, index) {
        final equipe = _filteredEquipes[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: TFCard(
            variant: TFCardVariant.defaultCard,
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.xs),
              leading: TFStatusBadge(
                label: equipe.ativo ? 'Ativa' : 'Inativa',
                severity: equipe.ativo ? TFStatusSeverity.success : TFStatusSeverity.neutral,
                compact: true,
              ),
              title: Text(
                equipe.nome,
                style: typography.cardTitle.copyWith(color: colors.textPrimary),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: spacing.xxs),
                  Text(
                    'Tipo: ${_getTipoLabel(equipe.tipo)} • Executores: ${equipe.executores.length}',
                    style: typography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  if (equipe.regional != null || equipe.divisao != null || equipe.segmento != null) ...[
                    SizedBox(height: spacing.xxs),
                    Text(
                      [
                        if (equipe.regional != null) 'Regional: ${equipe.regional}',
                        if (equipe.divisao != null) 'Divisão: ${equipe.divisao}',
                        if (equipe.segmento != null) 'Segmento: ${equipe.segmento}',
                      ].join(' • '),
                      style: typography.micro.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TFIconButton(
                    icon: TFIcons.edit,
                    tooltip: 'Editar "${equipe.nome}"',
                    variant: TFIconButtonVariant.standard,
                    onPressed: () => _editEquipe(equipe),
                  ),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar "${equipe.nome}"',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateEquipe(equipe),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir "${equipe.nome}"',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteEquipe(equipe),
                  ),
                ],
              ),
              children: [
                if (equipe.executores.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(spacing.base),
                    child: Text(
                      'Nenhum executor vinculado a esta equipe',
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  )
                else
                  ...equipe.executores.map((equipeExecutor) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getPapelIcon(equipeExecutor.papel),
                        size: 18,
                        color: colors.primary,
                      ),
                      title: Text(
                        equipeExecutor.executorNome,
                        style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: TFRadius.borderRadiusSm,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Text(
                          _getPapelLabel(equipeExecutor.papel),
                          style: typography.micro.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
