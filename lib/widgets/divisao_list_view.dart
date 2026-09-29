import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/divisao.dart';
import '../services/divisao_service.dart';
import 'divisao_form_dialog.dart';

class DivisaoListView extends StatefulWidget {
  const DivisaoListView({super.key});

  @override
  State<DivisaoListView> createState() => _DivisaoListViewState();
}

class _DivisaoListViewState extends State<DivisaoListView> {
  final DivisaoService _divisaoService = DivisaoService();
  List<Divisao> _divisoes = [];
  List<Divisao> _filteredDivisoes = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Filtros multiescolha por coluna
  Set<String> _selectedRegionais = {};
  Set<String> _selectedSegmentos = {};

  bool get _hasActiveFilters =>
      _selectedRegionais.isNotEmpty ||
      _selectedSegmentos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedRegionais.clear();
      _selectedSegmentos.clear();
      _searchController.clear();
      _currentPage = 1;
      _filteredDivisoes = _applyFilter(_divisoes);
    });
  }

  List<String> _getUniqueRegionais() {
    final regs = <String>{};
    for (final d in _divisoes) {
      if (d.regional.trim().isNotEmpty) regs.add(d.regional.trim());
      for (final r in d.regionais) {
        if (r.trim().isNotEmpty) regs.add(r.trim());
      }
    }
    return regs.toList()..sort();
  }

  List<String> _getUniqueSegmentos() {
    final segs = <String>{};
    for (final d in _divisoes) {
      for (final s in d.segmentos) {
        if (s.trim().isNotEmpty) segs.add(s.trim());
      }
    }
    return segs.toList()..sort();
  }

  List<Divisao> _applyFilter(List<Divisao> list) {
    final query = _searchController.text.trim().toLowerCase();

    return list.where((d) {
      // Filtro de Regional
      if (_selectedRegionais.isNotEmpty) {
        final matchesReg = _selectedRegionais.contains(d.regional.trim()) ||
            d.regionais.any((r) => _selectedRegionais.contains(r.trim()));
        if (!matchesReg) return false;
      }

      // Filtro de Segmentos
      if (_selectedSegmentos.isNotEmpty) {
        final matchesSeg = d.segmentos.any((s) => _selectedSegmentos.contains(s.trim()));
        if (!matchesSeg) return false;
      }

      // Busca por texto
      if (query.isNotEmpty) {
        final matchDiv = d.divisao.toLowerCase().contains(query);
        final matchReg = d.regional.toLowerCase().contains(query) ||
            d.regionais.any((r) => r.toLowerCase().contains(query));
        final matchSeg = d.segmentos.any((s) => s.toLowerCase().contains(query));
        if (!matchDiv && !matchReg && !matchSeg) return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDivisoes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDivisoes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      setState(() {
        _divisoes = divisoes;
        _filteredDivisoes = _applyFilter(divisoes);
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar divisões: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 1;
      _filteredDivisoes = _applyFilter(_divisoes);
    });
  }

  List<Divisao> get _paginatedDivisoes {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredDivisoes.length > startIndex
        ? _filteredDivisoes.sublist(
            startIndex,
            endIndex > _filteredDivisoes.length ? _filteredDivisoes.length : endIndex,
          )
        : [];
  }

  int get _totalPages => (_filteredDivisoes.length / _itemsPerPage).ceil();

  Future<void> _createDivisao() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DivisaoFormDialog(),
    );

    if (result != null && result['divisao'] != null) {
      try {
        final divisao = result['divisao'] as Divisao;
        final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;

        final created = await _divisaoService.createDivisao(divisao, telegramChatIds: telegramChatIds);
        if (created != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                    ? 'Divisão criada e Chat IDs do Telegram cadastrados com sucesso!'
                    : 'Divisão criada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', '').replaceFirst('PostgrestException: ', ''),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _editDivisao(Divisao divisao) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DivisaoFormDialog(divisao: divisao),
    );

    if (result != null && result['divisao'] != null) {
      try {
        final divisaoResult = result['divisao'] as Divisao;
        final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;

        final updated = await _divisaoService.updateDivisao(divisao.id, divisaoResult, telegramChatIds: telegramChatIds);
        if (updated != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                    ? 'Divisão atualizada e Chat IDs do Telegram cadastrados com sucesso!'
                    : 'Divisão atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', '').replaceFirst('PostgrestException: ', ''),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateDivisao(Divisao divisao) async {
    final duplicated = divisao.copyWith(
      id: '',
      divisao: '${divisao.divisao} (Cópia)',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DivisaoFormDialog(divisao: duplicated),
    );

    if (result != null && result['divisao'] != null) {
      try {
        final divisaoResult = result['divisao'] as Divisao;
        final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;

        final created = await _divisaoService.createDivisao(divisaoResult, telegramChatIds: telegramChatIds);
        if (created != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                    ? 'Divisão duplicada e Chat IDs cadastrados!'
                    : 'Divisão duplicada com sucesso!'),
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

  Future<void> _deleteDivisao(Divisao divisao) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir a divisão "${divisao.divisao}"?\n\n'
          'Regional: ${divisao.regional}\n'
          'Segmentos: ${divisao.segmentos.isEmpty ? "Nenhum" : divisao.segmentos.join(", ")}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _divisaoService.deleteDivisao(divisao.id);
      if (deleted) {
        await _loadDivisoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Divisão excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir divisão.'),
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
                title: 'Cadastro de Divisões',
                subtitle: 'Gerenciamento operacional de divisões, regionais e segmentos',
                onBack: () => Navigator.of(context).pop(),
                primaryAction: TFButton(
                  label: 'Nova Divisão',
                  leadingIcon: TFIcons.add,
                  onPressed: _createDivisao,
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
                    tooltip: 'Recarregar divisões',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadDivisoes,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar por divisão, regional ou segmento...',
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
                            _currentPage = 1;
                            _filteredDivisoes = _applyFilter(_divisoes);
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
                            _filteredDivisoes = _applyFilter(_divisoes);
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
                        message: 'Carregando divisões...',
                      )
                    : _filteredDivisoes.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _divisoes.isEmpty
                                ? 'Nenhuma divisão cadastrada'
                                : 'Nenhuma divisão encontrada',
                            description: _divisoes.isEmpty
                                ? 'Cadastre a primeira divisão operacional para começar.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _divisoes.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeira Divisão',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createDivisao,
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
              if (_totalPages > 1 && !_isLoading && _filteredDivisoes.isNotEmpty)
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

    return TFDataTable<Divisao>(
      items: _paginatedDivisoes,
      zebra: true,
      columns: [
        TFDataColumn<Divisao>.text(
          id: 'divisao',
          title: 'Divisão',
          cellBuilder: (context, divisao) => Text(
            divisao.divisao,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Divisao>(
          id: 'regional',
          label: const Text('Regionais'),
          cellBuilder: (context, divisao) => divisao.regionais.isEmpty
              ? Text(
                  divisao.regional.isEmpty ? '-' : divisao.regional,
                  style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: divisao.regionais
                      .map((reg) => TFStatusBadge(
                            label: reg,
                            severity: TFStatusSeverity.info,
                            compact: true,
                          ))
                      .toList(),
                ),
        ),
        TFDataColumn<Divisao>(
          id: 'segmentos',
          label: const Text('Segmentos'),
          cellBuilder: (context, divisao) => divisao.segmentos.isEmpty
              ? Text('-', style: typography.bodySmall.copyWith(color: colors.textMuted))
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: divisao.segmentos
                      .map((seg) => TFStatusBadge(
                            label: seg,
                            severity: TFStatusSeverity.neutral,
                            compact: true,
                          ))
                      .toList(),
                ),
        ),
        TFDataColumn<Divisao>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, divisao) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar divisão',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editDivisao(divisao),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar divisão',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateDivisao(divisao),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir divisão',
                variant: TFIconButtonVariant.danger,
                onPressed: () => _deleteDivisao(divisao),
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
      itemCount: _paginatedDivisoes.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final divisao = _paginatedDivisoes[index];
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
                      divisao.divisao,
                      style: typography.cardTitle.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  if (divisao.regionais.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: divisao.regionais
                          .map((reg) => TFStatusBadge(
                                label: reg,
                                severity: TFStatusSeverity.info,
                                compact: true,
                              ))
                          .toList(),
                    )
                  else if (divisao.regional.isNotEmpty)
                    TFStatusBadge(
                      label: divisao.regional,
                      severity: TFStatusSeverity.info,
                      compact: true,
                    ),
                ],
              ),
              if (divisao.segmentos.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: divisao.segmentos
                      .map((seg) => TFStatusBadge(
                            label: seg,
                            severity: TFStatusSeverity.neutral,
                            compact: true,
                          ))
                      .toList(),
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
                    onPressed: () => _editDivisao(divisao),
                  ),
                  SizedBox(width: spacing.xs),
                  TFIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Duplicar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => _duplicateDivisao(divisao),
                  ),
                  TFIconButton(
                    icon: TFIcons.delete,
                    tooltip: 'Excluir',
                    variant: TFIconButtonVariant.danger,
                    onPressed: () => _deleteDivisao(divisao),
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
            'Mostrando ${_paginatedDivisoes.length} de ${_filteredDivisoes.length} divisões',
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
