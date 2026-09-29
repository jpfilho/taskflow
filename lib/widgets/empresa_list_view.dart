import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/empresa.dart';
import '../services/empresa_service.dart';
import 'empresa_form_dialog.dart';

class EmpresaListView extends StatefulWidget {
  const EmpresaListView({super.key});

  @override
  State<EmpresaListView> createState() => _EmpresaListViewState();
}

class _EmpresaListViewState extends State<EmpresaListView> {
  final EmpresaService _empresaService = EmpresaService();
  List<Empresa> _empresas = [];
  List<Empresa> _filteredEmpresas = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();

  // Filtros multiescolha por coluna
  Set<String> _selectedRegionais = {};
  Set<String> _selectedDivisoes = {};
  Set<String> _selectedTipos = {};

  bool get _hasActiveFilters =>
      _selectedRegionais.isNotEmpty ||
      _selectedDivisoes.isNotEmpty ||
      _selectedTipos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedRegionais.clear();
      _selectedDivisoes.clear();
      _selectedTipos.clear();
      _searchController.clear();
      _filteredEmpresas = _applyFilter(_empresas);
    });
  }

  List<String> _getUniqueRegionais() {
    return _empresas
        .map((e) => e.regional.trim())
        .where((r) => r.isNotEmpty && r != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _empresas
        .map((e) => e.divisao.trim())
        .where((d) => d.isNotEmpty && d != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueTipos() {
    return _empresas
        .map((e) => e.tipo.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<Empresa> _applyFilter(List<Empresa> list) {
    final query = _searchController.text.trim().toLowerCase();

    return list.where((e) {
      final regStr = e.regional.trim();
      final divStr = e.divisao.trim();
      final tipoStr = e.tipo.trim();

      // Filtros multiescolha
      if (_selectedRegionais.isNotEmpty && !_selectedRegionais.contains(regStr)) {
        return false;
      }
      if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divStr)) {
        return false;
      }
      if (_selectedTipos.isNotEmpty && !_selectedTipos.contains(tipoStr)) {
        return false;
      }

      // Busca geral por texto
      if (query.isNotEmpty) {
        final matchEmp = e.empresa.toLowerCase().contains(query);
        final matchReg = regStr.toLowerCase().contains(query);
        final matchDiv = divStr.toLowerCase().contains(query);
        final matchTipo = tipoStr.toLowerCase().contains(query);
        if (!matchEmp && !matchReg && !matchDiv && !matchTipo) return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadEmpresas();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmpresas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final empresas = await _empresaService.getAllEmpresas();
      setState(() {
        _empresas = empresas;
        _filteredEmpresas = _applyFilter(empresas);
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar empresas: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar empresas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filteredEmpresas = _applyFilter(_empresas);
    });
  }

  Future<void> _createEmpresa() async {
    final result = await showDialog<Empresa>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const EmpresaFormDialog(),
    );

    if (result != null) {
      final created = await _empresaService.createEmpresa(result);
      if (created != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar empresa.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateEmpresa(Empresa empresa) async {
    final duplicated = empresa.copyWith(
      id: '',
      empresa: '${empresa.empresa} (Cópia)',
    );

    final result = await showDialog<Empresa>(
      context: context,
      barrierDismissible: true,
      builder: (context) => EmpresaFormDialog(empresa: duplicated),
    );

    if (result != null) {
      final created = await _empresaService.createEmpresa(result);
      if (created != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa duplicada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar empresa.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editEmpresa(Empresa empresa) async {
    final fetchedEmpresa = await _empresaService.getEmpresaById(empresa.id);
    if (fetchedEmpresa == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar empresa para edição.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<Empresa>(
      context: context,
      barrierDismissible: true,
      builder: (context) => EmpresaFormDialog(empresa: fetchedEmpresa),
    );

    if (result != null) {
      final updated = await _empresaService.updateEmpresa(empresa.id, result);
      if (updated != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar empresa.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEmpresa(Empresa empresa) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir a empresa "${empresa.empresa}"?\n\n'
          'Regional: ${empresa.regional}\n'
          'Divisão: ${empresa.divisao}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _empresaService.deleteEmpresa(empresa.id);
      if (deleted) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir empresa.'),
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
                title: 'Cadastro de Empresas',
                subtitle: 'Gerenciamento de empresas prestadoras e parceiras operacionais',
                onBack: () => Navigator.of(context).pop(),
                primaryAction: TFButton(
                  label: 'Nova Empresa',
                  leadingIcon: TFIcons.add,
                  onPressed: _createEmpresa,
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
                    tooltip: 'Recarregar empresas',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadEmpresas,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar empresas por nome, regional ou divisão...',
                      prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
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
                        label: 'Regional',
                        selectedValues: _selectedRegionais,
                        options: _getUniqueRegionais(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedRegionais = values;
                            _filteredEmpresas = _applyFilter(_empresas);
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
                            _filteredEmpresas = _applyFilter(_empresas);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Tipo',
                        selectedValues: _selectedTipos,
                        options: _getUniqueTipos(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedTipos = values;
                            _filteredEmpresas = _applyFilter(_empresas);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.base),
              Expanded(
                child: _isLoading
                    ? const TFLoading(
                        mode: TFLoadingMode.section,
                        message: 'Carregando empresas cadastradas...',
                      )
                    : _filteredEmpresas.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _empresas.isEmpty
                                ? 'Nenhuma empresa cadastrada'
                                : 'Nenhuma empresa encontrada',
                            description: _empresas.isEmpty
                                ? 'Cadastre a primeira empresa para iniciar a alocação de equipes.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _empresas.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeira Empresa',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createEmpresa,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFDataTable<Empresa>(
      items: _filteredEmpresas,
      zebra: true,
      columns: [
        TFDataColumn<Empresa>.text(
          id: 'empresa',
          title: 'Empresa',
          cellBuilder: (context, empresa) => Text(
            empresa.empresa,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Empresa>.text(
          id: 'regional',
          title: 'Regional',
          cellBuilder: (context, empresa) => Text(
            empresa.regional.isNotEmpty ? empresa.regional : '-',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Empresa>.text(
          id: 'divisao',
          title: 'Divisão',
          cellBuilder: (context, empresa) => Text(
            empresa.divisao.isNotEmpty ? empresa.divisao : '-',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Empresa>(
          id: 'tipo',
          label: const Text('Tipo'),
          width: 120,
          cellBuilder: (context, empresa) => TFStatusBadge(
            label: empresa.tipo == 'PROPRIA' ? 'Própria' : 'Terceira',
            severity: empresa.tipo == 'PROPRIA' ? TFStatusSeverity.info : TFStatusSeverity.warning,
            compact: true,
          ),
        ),
        TFDataColumn<Empresa>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, empresa) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar empresa',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editEmpresa(empresa),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar empresa',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateEmpresa(empresa),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir empresa',
                variant: TFIconButtonVariant.danger,
                onPressed: () => _deleteEmpresa(empresa),
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
      itemCount: _filteredEmpresas.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final empresa = _filteredEmpresas[index];
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
                      empresa.empresa,
                      style: typography.cardTitle.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  TFStatusBadge(
                    label: empresa.tipo == 'PROPRIA' ? 'Própria' : 'Terceira',
                    severity: empresa.tipo == 'PROPRIA' ? TFStatusSeverity.info : TFStatusSeverity.warning,
                    compact: true,
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Regional: ${empresa.regional.isNotEmpty ? empresa.regional : "-"}  •  Divisão: ${empresa.divisao.isNotEmpty ? empresa.divisao : "-"}',
                style: typography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TFButton(
                    label: 'Editar',
                    leadingIcon: TFIcons.edit,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _editEmpresa(empresa),
                  ),
                  SizedBox(width: spacing.xs),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateEmpresa(empresa),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteEmpresa(empresa),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
