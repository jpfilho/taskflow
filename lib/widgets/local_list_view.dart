import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/local.dart';
import '../services/local_service.dart';
import 'local_form_dialog.dart';

class LocalListView extends StatefulWidget {
  const LocalListView({super.key});

  @override
  State<LocalListView> createState() => _LocalListViewState();
}

class _LocalListViewState extends State<LocalListView> {
  final LocalService _localService = LocalService();
  List<Local> _locais = [];
  List<Local> _filteredLocais = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();

  // Filtros multiescolha por coluna
  Set<String> _selectedRegionais = {};
  Set<String> _selectedDivisoes = {};
  Set<String> _selectedSegmentos = {};

  bool get _hasActiveFilters =>
      _selectedRegionais.isNotEmpty ||
      _selectedDivisoes.isNotEmpty ||
      _selectedSegmentos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedRegionais.clear();
      _selectedDivisoes.clear();
      _selectedSegmentos.clear();
      _searchController.clear();
      _applyFilters();
    });
  }

  List<String> _getUniqueRegionais() {
    return _locais
        .map((l) => l.regional.trim())
        .where((r) => r.isNotEmpty && r != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _locais
        .map((l) => l.divisao.trim())
        .where((d) => d.isNotEmpty && d != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSegmentos() {
    return _locais
        .map((l) => l.segmento.trim())
        .where((s) => s.isNotEmpty && s != '-')
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadLocais();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocais() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locais = await _localService.getAllLocais();
      setState(() {
        _locais = locais;
        _filteredLocais = locais;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar locais: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar locais: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _normalize(String text) {
    var result = text.toLowerCase().trim();
    const withDiacritics = 'áàâãäéèêëíìîïóòôõöúùûüçñýÿ';
    const withoutDiacritics = 'aaaaaeeeeiiiiooooouuuucnyy';
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  bool _matchesLocal(Local l, String rawQuery) {
    final regionalStr = l.regional.trim();
    final divisaoStr = l.divisao.trim();
    final segmentoStr = l.segmento.trim();

    // Filtros multiescolha
    if (_selectedRegionais.isNotEmpty && !_selectedRegionais.contains(regionalStr)) {
      return false;
    }
    if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divisaoStr)) {
      return false;
    }
    if (_selectedSegmentos.isNotEmpty && !_selectedSegmentos.contains(segmentoStr)) {
      return false;
    }

    final query = _normalize(rawQuery);
    if (query.isEmpty) return true;

    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final parts = <String>[
      l.local,
      l.descricao ?? '',
      l.localInstalacaoSap ?? '',
      l.regional,
      l.divisao,
      l.segmento,
      l.associacoesDescricao,
      if (l.paraTodaRegional) 'toda regional',
      if (l.paraTodaDivisao) 'toda divisao toda divisão',
      l.local.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
      if (l.localInstalacaoSap != null)
        l.localInstalacaoSap!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
    ];

    final fullSearchableText = _normalize(parts.join(' '));

    return tokens.every((token) {
      final cleanToken = token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return fullSearchableText.contains(token) ||
          (cleanToken.isNotEmpty && fullSearchableText.contains(cleanToken));
    });
  }

  void _applyFilters() {
    final query = _searchController.text;

    setState(() {
      _filteredLocais = _locais.where((l) => _matchesLocal(l, query)).toList();
    });
  }

  Future<void> _createLocal() async {
    final result = await showDialog<Local>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LocalFormDialog(),
    );

    if (result != null) {
      final created = await _localService.createLocal(result);
      if (created != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar local.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateLocal(Local local) async {
    final duplicated = local.copyWith(
      id: '',
      local: '${local.local} (Cópia)',
    );

    final result = await showDialog<Local>(
      context: context,
      barrierDismissible: true,
      builder: (context) => LocalFormDialog(local: duplicated),
    );

    if (result != null) {
      final created = await _localService.createLocal(result);
      if (created != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar local.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editLocal(Local local) async {
    final result = await showDialog<Local>(
      context: context,
      barrierDismissible: true,
      builder: (context) => LocalFormDialog(local: local),
    );

    if (result != null) {
      final updated = await _localService.updateLocal(local.id, result);
      if (updated != null) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar local.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteLocal(Local local) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir o local "${local.local}"?\n\n'
          'Associações: ${local.associacoesDescricao}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _localService.deleteLocal(local.id);
      if (deleted) {
        await _loadLocais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Local excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir local.'),
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
                title: 'Cadastro de Locais',
                subtitle: 'Locais físicos, subestações e instalações operacionais integradas',
                onBack: () => Navigator.of(context).pop(),
                primaryAction: TFButton(
                  label: 'Novo Local',
                  leadingIcon: TFIcons.add,
                  onPressed: _createLocal,
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
                    tooltip: 'Recarregar locais',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadLocais,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar por local, descrição, SAP ou regional...',
                      prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
                      onChanged: (_) => _applyFilters(),
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
                            _applyFilters();
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
                            _applyFilters();
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
                            _applyFilters();
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
                        message: 'Carregando locais...',
                      )
                    : _filteredLocais.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _locais.isEmpty
                                ? 'Nenhum local cadastrado'
                                : 'Nenhum local encontrado',
                            description: _locais.isEmpty
                                ? 'Cadastre o primeiro local para associar às tarefas operacionais.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _locais.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeiro Local',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createLocal,
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

    return TFDataTable<Local>(
      items: _filteredLocais,
      zebra: true,
      columns: [
        TFDataColumn<Local>.text(
          id: 'local',
          title: 'Local',
          cellBuilder: (context, local) => Text(
            local.local,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Local>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, local) => Text(
            local.descricao != null && local.descricao!.isNotEmpty
                ? local.descricao!
                : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<Local>.text(
          id: 'sap',
          title: 'Instalação SAP',
          width: 140,
          cellBuilder: (context, local) => Text(
            local.localInstalacaoSap != null && local.localInstalacaoSap!.isNotEmpty
                ? local.localInstalacaoSap!
                : '-',
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
        TFDataColumn<Local>(
          id: 'associacoes',
          label: const Text('Associações'),
          cellBuilder: (context, local) => Text(
            local.associacoesDescricao,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        TFDataColumn<Local>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, local) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar local',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editLocal(local),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar local',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateLocal(local),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir local',
                variant: TFIconButtonVariant.danger,
                onPressed: () => _deleteLocal(local),
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
      itemCount: _filteredLocais.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final local = _filteredLocais[index];
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
                      local.local,
                      style: typography.cardTitle.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  if (local.localInstalacaoSap != null && local.localInstalacaoSap!.isNotEmpty)
                    TFStatusBadge(
                      label: local.localInstalacaoSap!,
                      severity: TFStatusSeverity.info,
                      compact: true,
                    ),
                ],
              ),
              if (local.descricao != null && local.descricao!.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  local.descricao!,
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
              SizedBox(height: spacing.xs),
              Text(
                local.associacoesDescricao,
                style: typography.bodySmall.copyWith(
                  color: colors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TFButton(
                    label: 'Editar',
                    leadingIcon: TFIcons.edit,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _editLocal(local),
                  ),
                  SizedBox(width: spacing.xs),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateLocal(local),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteLocal(local),
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
