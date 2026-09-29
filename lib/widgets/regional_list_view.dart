import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/regional.dart';
import '../services/regional_service.dart';
import 'regional_form_dialog.dart';

class RegionalListView extends StatefulWidget {
  const RegionalListView({super.key});

  @override
  State<RegionalListView> createState() => _RegionalListViewState();
}

class _RegionalListViewState extends State<RegionalListView> {
  final RegionalService _regionalService = RegionalService();
  List<Regional> _regionais = [];
  List<Regional> _filteredRegionais = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadRegionais();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _filteredRegionais = regionais;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar regionais: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredRegionais = _regionais;
        _currentPage = 1;
      });
    } else {
      _searchRegionais(query);
    }
  }

  Future<void> _searchRegionais(String query) async {
    try {
      final results = await _regionalService.searchRegionais(query);
      setState(() {
        _filteredRegionais = results;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao buscar regionais: $e');
    }
  }

  List<Regional> get _paginatedRegionais {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredRegionais.length > startIndex
        ? _filteredRegionais.sublist(
            startIndex,
            endIndex > _filteredRegionais.length ? _filteredRegionais.length : endIndex,
          )
        : [];
  }

  int get _totalPages => (_filteredRegionais.length / _itemsPerPage).ceil();

  Future<void> _createRegional() async {
    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const RegionalFormDialog(),
    );

    if (result != null) {
      try {
        final created = await _regionalService.createRegional(result);
        if (created != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional criada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _editRegional(Regional regional) async {
    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RegionalFormDialog(regional: regional),
    );

    if (result != null) {
      try {
        final updated = await _regionalService.updateRegional(regional.id, result);
        if (updated != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateRegional(Regional regional) async {
    final duplicated = regional.copyWith(
      id: '',
      regional: '${regional.regional} (Cópia)',
    );

    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RegionalFormDialog(regional: duplicated),
    );

    if (result != null) {
      try {
        final created = await _regionalService.createRegional(result);
        if (created != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional duplicada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRegional(Regional regional) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir a regional "${regional.regional}"?\n\n'
          'Sigla: ${regional.divisao}\n'
          'Empresa: ${regional.empresa}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _regionalService.deleteRegional(regional.id);
      if (deleted) {
        await _loadRegionais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Regional excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir regional.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = TFBreakpoints.isMobile(context);
    final spacing = context.tfSpacing;
    final colors = context.tfColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? spacing.sm : spacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TFPageHeader(
                title: 'Cadastro de Regionais',
                subtitle: 'Gerenciamento operacional de regionais e divisões',
                onBack: () => Navigator.of(context).pop(),
                primaryAction: TFButton(
                  label: 'Nova Regional',
                  leadingIcon: TFIcons.add,
                  onPressed: _createRegional,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: _isTableView ? Icons.view_list_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Visualizar em Lista' : 'Visualizar em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () {
                      setState(() {
                        _isTableView = !_isTableView;
                      });
                    },
                  ),
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Recarregar regionais',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadRegionais,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(bottom: spacing.base),
                child: TFTextField(
                  controller: _searchController,
                  hint: 'Buscar por regional, sigla ou empresa...',
                  prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(TFIcons.close, size: 16, color: colors.textMuted),
                          onPressed: () => _searchController.clear(),
                          tooltip: 'Limpar busca',
                        )
                      : null,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const TFLoading(
                        mode: TFLoadingMode.section,
                        message: 'Carregando regionais...',
                      )
                    : _filteredRegionais.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _regionais.isEmpty
                                ? 'Nenhuma regional cadastrada'
                                : 'Nenhuma regional encontrada',
                            description: _regionais.isEmpty
                                ? 'Cadastre a primeira regional operacional para começar.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _regionais.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeira Regional',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createRegional,
                                  )
                                : TFButton(
                                    label: 'Limpar Busca',
                                    variant: TFButtonVariant.secondary,
                                    onPressed: () => _searchController.clear(),
                                  ),
                          )
                        : (isMobile || !_isTableView)
                            ? _buildMobileList()
                            : _buildDesktopTable(),
              ),
              if (_totalPages > 1 && !_isLoading && _filteredRegionais.isNotEmpty)
                _buildPagination(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFDataTable<Regional>(
      items: _paginatedRegionais,
      zebra: true,
      columns: [
        TFDataColumn<Regional>.text(
          id: 'regional',
          title: 'Regional',
          cellBuilder: (context, regional) => Text(
            regional.regional,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Regional>.text(
          id: 'sigla',
          title: 'Sigla',
          cellBuilder: (context, regional) => Text(
            regional.divisao.isNotEmpty ? regional.divisao : '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Regional>.text(
          id: 'empresa',
          title: 'Empresa',
          cellBuilder: (context, regional) => Text(
            regional.empresa.isNotEmpty ? regional.empresa : '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Regional>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, regional) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar regional',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editRegional(regional),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar regional',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateRegional(regional),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir regional',
                variant: TFIconButtonVariant.danger,
                onPressed: () => _deleteRegional(regional),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList() {
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: _paginatedRegionais.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final regional = _paginatedRegionais[index];
        return TFCard(
          variant: TFCardVariant.defaultCard,
          padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      regional.regional,
                      style: typography.cardTitle.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  if (regional.divisao.isNotEmpty)
                    TFStatusBadge(
                      label: regional.divisao,
                      severity: TFStatusSeverity.neutral,
                      compact: true,
                    ),
                ],
              ),
              if (regional.empresa.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  'Empresa: ${regional.empresa}',
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TFButton(
                    label: 'Editar',
                    leadingIcon: TFIcons.edit,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _editRegional(regional),
                  ),
                  SizedBox(width: spacing.xs),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateRegional(regional),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteRegional(regional),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    final spacing = context.tfSpacing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.tfColors.surface,
        border: Border(
          top: BorderSide(color: context.tfColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${_paginatedRegionais.length} de ${_filteredRegionais.length} regionais',
            style: context.tfTypography.bodySmall.copyWith(
              color: context.tfColors.textSecondary,
            ),
          ),
          Row(
            children: [
              TFButton(
                label: 'Anterior',
                variant: TFButtonVariant.ghost,
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              SizedBox(width: spacing.xs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.tfColors.primary,
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                ),
                child: Text(
                  '$_currentPage',
                  style: context.tfTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: spacing.xs),
              TFButton(
                label: 'Próximo',
                variant: TFButtonVariant.ghost,
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
