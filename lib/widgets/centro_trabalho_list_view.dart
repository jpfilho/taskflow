import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/centro_trabalho.dart';
import '../services/centro_trabalho_service.dart';
import 'centro_trabalho_form_dialog.dart';

class CentroTrabalhoListView extends StatefulWidget {
  const CentroTrabalhoListView({super.key});

  @override
  State<CentroTrabalhoListView> createState() => _CentroTrabalhoListViewState();
}

class _CentroTrabalhoListViewState extends State<CentroTrabalhoListView> {
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();
  List<CentroTrabalho> _centrosTrabalho = [];
  List<CentroTrabalho> _filteredCentrosTrabalho = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

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
      _filteredCentrosTrabalho = _applyFilter(_centrosTrabalho);
    });
  }

  List<String> _getUniqueRegionais() {
    return _centrosTrabalho
        .map((c) => c.regional?.trim() ?? '')
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _centrosTrabalho
        .map((c) => c.divisao?.trim() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSegmentos() {
    return _centrosTrabalho
        .map((c) => c.segmento?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<CentroTrabalho> _applyFilter(List<CentroTrabalho> list) {
    final query = _searchController.text.trim().toLowerCase();

    return list.where((c) {
      final regStr = c.regional?.trim() ?? '';
      final divStr = c.divisao?.trim() ?? '';
      final segStr = c.segmento?.trim() ?? '';

      // Filtros multiescolha
      if (_selectedRegionais.isNotEmpty && !_selectedRegionais.contains(regStr)) {
        return false;
      }
      if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divStr)) {
        return false;
      }
      if (_selectedSegmentos.isNotEmpty && !_selectedSegmentos.contains(segStr)) {
        return false;
      }

      // Busca geral por texto
      if (query.isNotEmpty) {
        final matchCt = c.centroTrabalho.toLowerCase().contains(query);
        final matchDesc = c.descricao?.toLowerCase().contains(query) ?? false;
        final matchGpm = c.gpm?.toString().toLowerCase().contains(query) ?? false;
        final matchReg = regStr.toLowerCase().contains(query);
        final matchDiv = divStr.toLowerCase().contains(query);
        final matchSeg = segStr.toLowerCase().contains(query);
        if (!matchCt && !matchDesc && !matchGpm && !matchReg && !matchDiv && !matchSeg) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCentrosTrabalho();
    _searchController.addListener(_onSearchChanged);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && TFBreakpoints.isDesktop(context)) {
        setState(() {
          _isTableView = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCentrosTrabalho() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final centrosTrabalho = await _centroTrabalhoService.getAllCentrosTrabalho();
      setState(() {
        _centrosTrabalho = centrosTrabalho;
        _filteredCentrosTrabalho = _applyFilter(centrosTrabalho);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar centros de trabalho: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final colors = context.tfColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar locais: $e'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCentrosTrabalho = _applyFilter(_centrosTrabalho);
    });
  }

  Future<void> _createCentroTrabalho() async {
    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => const CentroTrabalhoFormDialog(),
    );

    if (result != null) {
      final created = await _centroTrabalhoService.createCentroTrabalho(result);
      if (created.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Centro de Trabalho criado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao criar centro de trabalho'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateCentroTrabalho(CentroTrabalho centroTrabalho) async {
    final duplicated = centroTrabalho.copyWith(
      id: '',
      centroTrabalho: '${centroTrabalho.centroTrabalho} (Cópia)',
    );

    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => CentroTrabalhoFormDialog(centroTrabalho: duplicated),
    );

    if (result != null) {
      final created = await _centroTrabalhoService.createCentroTrabalho(result);
      if (created.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Centro de Trabalho duplicado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao duplicar centro de trabalho'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _editCentroTrabalho(CentroTrabalho centroTrabalho) async {
    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => CentroTrabalhoFormDialog(centroTrabalho: centroTrabalho),
    );

    if (result != null) {
      final updated = await _centroTrabalhoService.updateCentroTrabalho(result);
      if (updated.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Centro de Trabalho atualizado com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao atualizar centro de trabalho'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCentroTrabalho(CentroTrabalho centroTrabalho) async {
    final confirm = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir o centro de trabalho "${centroTrabalho.centroTrabalho}"?\n\n'
          'Vínculos: ${_getVinculosDescricao(centroTrabalho)}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirm == true) {
      final deleted = await _centroTrabalhoService.deleteCentroTrabalho(centroTrabalho.id);
      if (deleted) {
        await _loadCentrosTrabalho();
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Centro de Trabalho excluído com sucesso!'),
              backgroundColor: colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final colors = context.tfColors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro ao excluir centro de trabalho'),
              backgroundColor: colors.danger,
            ),
          );
        }
      }
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
                title: 'Cadastro de Centros de Trabalho',
                subtitle: 'Gestão de bases operacionais, regionais e divisões vinculadas',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Novo Centro de Trabalho',
                  leadingIcon: TFIcons.add,
                  variant: TFButtonVariant.primary,
                  onPressed: _createCentroTrabalho,
                ),
                secondaryActions: [
                  TFButton(
                    label: 'Atualizar',
                    leadingIcon: TFIcons.refresh,
                    variant: TFButtonVariant.secondary,
                    onPressed: _loadCentrosTrabalho,
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
                      hint: 'Buscar por centro de trabalho ou descrição...',
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
                        label: 'Regional',
                        selectedValues: _selectedRegionais,
                        options: _getUniqueRegionais(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedRegionais = values;
                            _filteredCentrosTrabalho = _applyFilter(_centrosTrabalho);
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
                            _filteredCentrosTrabalho = _applyFilter(_centrosTrabalho);
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
                            _filteredCentrosTrabalho = _applyFilter(_centrosTrabalho);
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
                          message: 'Carregando centros de trabalho...',
                        ),
                      )
                    : _filteredCentrosTrabalho.isEmpty
                        ? Center(
                            child: TFEmptyState(
                              icon: Icons.place_outlined,
                              title: _centrosTrabalho.isEmpty
                                  ? 'Nenhum centro de trabalho cadastrado'
                                  : 'Nenhum centro de trabalho encontrado',
                              description: _centrosTrabalho.isEmpty
                                  ? 'Comece cadastrando a primeira base operacional da empresa.'
                                  : 'Nenhum registro corresponde aos filtros pesquisados.',
                              action: _centrosTrabalho.isEmpty
                                  ? TFButton(
                                      label: 'Cadastrar Primeiro Centro',
                                      leadingIcon: TFIcons.add,
                                      variant: TFButtonVariant.primary,
                                      onPressed: _createCentroTrabalho,
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

  String _getVinculosDescricao(CentroTrabalho centroTrabalho) {
    final partes = <String>[];
    if (centroTrabalho.regional != null && centroTrabalho.regional!.isNotEmpty) {
      partes.add('Regional: ${centroTrabalho.regional}');
    }
    if (centroTrabalho.divisao != null && centroTrabalho.divisao!.isNotEmpty) {
      partes.add('Divisão: ${centroTrabalho.divisao}');
    }
    if (centroTrabalho.segmento != null && centroTrabalho.segmento!.isNotEmpty) {
      partes.add('Segmento: ${centroTrabalho.segmento}');
    }
    return partes.isEmpty ? 'Nenhum' : partes.join(', ');
  }

  Widget _buildListView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return ListView.builder(
      itemCount: _filteredCentrosTrabalho.length,
      itemBuilder: (context, index) {
        final centro = _filteredCentrosTrabalho[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: TFCard(
            variant: TFCardVariant.defaultCard,
            padding: EdgeInsets.symmetric(horizontal: spacing.base, vertical: spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centro.centroTrabalho,
                        style: typography.cardTitle.copyWith(color: colors.textPrimary),
                      ),
                      if (centro.descricao != null && centro.descricao!.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          centro.descricao!,
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                      SizedBox(height: spacing.xs),
                      Wrap(
                        spacing: spacing.sm,
                        runSpacing: spacing.xxs,
                        children: [
                          if (centro.gpm != null)
                            _buildInfoChip(Icons.numbers_rounded, 'GPM ${centro.gpm}'),
                          if (centro.regional != null && centro.regional!.isNotEmpty)
                            _buildInfoChip(Icons.business_outlined, centro.regional!),
                          if (centro.divisao != null && centro.divisao!.isNotEmpty)
                            _buildInfoChip(Icons.domain_outlined, centro.divisao!),
                          if (centro.segmento != null && centro.segmento!.isNotEmpty)
                            _buildInfoChip(Icons.apartment_outlined, centro.segmento!),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar "${centro.centroTrabalho}"',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editCentroTrabalho(centro),
                    ),
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar "${centro.centroTrabalho}"',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateCentroTrabalho(centro),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir "${centro.centroTrabalho}"',
                      variant: TFIconButtonVariant.danger,
                      onPressed: () => _deleteCentroTrabalho(centro),
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

  Widget _buildInfoChip(IconData icon, String label) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: TFRadius.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textSecondary),
          SizedBox(width: spacing.xxs),
          Text(
            label,
            style: typography.micro.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFDataTable<CentroTrabalho>(
      items: _filteredCentrosTrabalho,
      zebra: true,
      columns: [
        TFDataColumn<CentroTrabalho>.text(
          id: 'centroTrabalho',
          title: 'Centro de Trabalho',
          cellBuilder: (context, centro) => Text(
            centro.centroTrabalho,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<CentroTrabalho>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, centro) => Text(
            centro.descricao != null && centro.descricao!.isNotEmpty
                ? centro.descricao!
                : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<CentroTrabalho>.text(
          id: 'gpm',
          title: 'GPM',
          width: 90,
          numeric: true,
          cellBuilder: (context, centro) => Text(
            centro.gpm != null ? centro.gpm.toString() : '-',
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<CentroTrabalho>.text(
          id: 'regional',
          title: 'Regional',
          width: 130,
          cellBuilder: (context, centro) => Text(
            centro.regional != null && centro.regional!.isNotEmpty ? centro.regional! : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<CentroTrabalho>.text(
          id: 'divisao',
          title: 'Divisão',
          width: 140,
          cellBuilder: (context, centro) => Text(
            centro.divisao != null && centro.divisao!.isNotEmpty ? centro.divisao! : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<CentroTrabalho>.text(
          id: 'segmento',
          title: 'Segmento',
          width: 150,
          cellBuilder: (context, centro) => Text(
            centro.segmento != null && centro.segmento!.isNotEmpty ? centro.segmento! : '-',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
        TFDataColumn<CentroTrabalho>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, centro) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar "${centro.centroTrabalho}"',
                variant: TFIconButtonVariant.standard,
                iconSize: 18,
                onPressed: () => _editCentroTrabalho(centro),
              ),
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar "${centro.centroTrabalho}"',
                variant: TFIconButtonVariant.subtle,
                iconSize: 18,
                onPressed: () => _duplicateCentroTrabalho(centro),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir "${centro.centroTrabalho}"',
                variant: TFIconButtonVariant.danger,
                iconSize: 18,
                onPressed: () => _deleteCentroTrabalho(centro),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
