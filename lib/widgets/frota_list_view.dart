import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/frota.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../services/frota_service.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import 'frota_form_dialog.dart';

class FrotaListView extends StatefulWidget {
  const FrotaListView({super.key});

  @override
  State<FrotaListView> createState() => _FrotaListViewState();
}

class _FrotaListViewState extends State<FrotaListView> {
  final FrotaService _frotaService = FrotaService();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  List<Frota> _frotas = [];
  List<Frota> _filteredFrotas = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];

  // Filtros multiescolha por coluna
  Set<String> _selectedTipos = {};
  Set<String> _selectedMarcas = {};
  Set<String> _selectedPropriedades = {};
  Set<String> _selectedRegionais = {};
  Set<String> _selectedDivisoes = {};
  Set<String> _selectedSegmentos = {};

  bool get _hasActiveFilters =>
      _selectedTipos.isNotEmpty ||
      _selectedMarcas.isNotEmpty ||
      _selectedPropriedades.isNotEmpty ||
      _selectedRegionais.isNotEmpty ||
      _selectedDivisoes.isNotEmpty ||
      _selectedSegmentos.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedTipos.clear();
      _selectedMarcas.clear();
      _selectedPropriedades.clear();
      _selectedRegionais.clear();
      _selectedDivisoes.clear();
      _selectedSegmentos.clear();
      _searchController.clear();
      _currentPage = 1;
      _filteredFrotas = _applyFilter(_frotas);
    });
  }

  List<String> _getUniquePropriedades() {
    return _frotas
        .where((f) => f.ativo)
        .map((f) => Frota.getPropriedadeLabel(f.propriedade))
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueTipos() {
    return _frotas
        .where((f) => f.ativo)
        .map((f) => _getTipoVeiculoLabel(f.tipoVeiculo))
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueMarcas() {
    return _frotas
        .where((f) => f.ativo && f.marca != null && f.marca!.trim().isNotEmpty)
        .map((f) => f.marca!.trim())
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueRegionais() {
    return _frotas
        .where((f) => f.ativo)
        .map((f) => _getRegionalNome(f.regionalId))
        .where((r) => r.isNotEmpty && r != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueDivisoes() {
    return _frotas
        .where((f) => f.ativo)
        .map((f) => _getDivisaoNome(f.divisaoId))
        .where((d) => d.isNotEmpty && d != '-')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSegmentos() {
    return _frotas
        .where((f) => f.ativo)
        .map((f) => _getSegmentoNome(f.segmentoId))
        .where((s) => s.isNotEmpty && s != '-')
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadFrotas();
    _loadDependencies();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFrotas() async {
    setState(() => _isLoading = true);

    try {
      final frotas = await _frotaService.getAllFrotas();
      if (mounted) {
        setState(() {
          _frotas = frotas;
          _filteredFrotas = _applyFilter(frotas);
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar frota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDependencies() async {
    try {
      final results = await Future.wait([
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
      ]);
      if (mounted) {
        setState(() {
          _regionais = results[0] as List<Regional>;
          _divisoes = results[1] as List<Divisao>;
          _segmentos = results[2] as List<Segmento>;
        });
      }
    } catch (_) {}
  }

  List<Frota> _applyFilter(List<Frota> list) {
    final query = _searchController.text.toLowerCase().trim();
    final ativos = list.where((f) => f.ativo).toList();

    return ativos.where((frota) {
      final regionalNome = _getRegionalNome(frota.regionalId);
      final divisaoNome = _getDivisaoNome(frota.divisaoId);
      final segmentoNome = _getSegmentoNome(frota.segmentoId);
      final tipoLabel = _getTipoVeiculoLabel(frota.tipoVeiculo);
      final marcaStr = frota.marca?.trim() ?? '';
      final propLabel = Frota.getPropriedadeLabel(frota.propriedade);

      // Filtros multiescolha
      if (_selectedTipos.isNotEmpty && !_selectedTipos.contains(tipoLabel)) {
        return false;
      }
      if (_selectedMarcas.isNotEmpty && !_selectedMarcas.contains(marcaStr)) {
        return false;
      }
      if (_selectedPropriedades.isNotEmpty && !_selectedPropriedades.contains(propLabel)) {
        return false;
      }
      if (_selectedRegionais.isNotEmpty && !_selectedRegionais.contains(regionalNome)) {
        return false;
      }
      if (_selectedDivisoes.isNotEmpty && !_selectedDivisoes.contains(divisaoNome)) {
        return false;
      }
      if (_selectedSegmentos.isNotEmpty && !_selectedSegmentos.contains(segmentoNome)) {
        return false;
      }

      // Busca geral por texto
      if (query.isNotEmpty) {
        final matchesQuery = frota.nome.toLowerCase().contains(query) ||
            marcaStr.toLowerCase().contains(query) ||
            frota.placa.toLowerCase().contains(query) ||
            tipoLabel.toLowerCase().contains(query) ||
            propLabel.toLowerCase().contains(query) ||
            regionalNome.toLowerCase().contains(query) ||
            divisaoNome.toLowerCase().contains(query) ||
            segmentoNome.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      return true;
    }).toList();
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 1;
      _filteredFrotas = _applyFilter(_frotas);
    });
  }

  String _getRegionalNome(String? id) {
    if (id == null) return '-';
    return _regionais.cast<Regional?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    )?.regional ?? '-';
  }

  String _getDivisaoNome(String? id) {
    if (id == null) return '-';
    return _divisoes.cast<Divisao?>().firstWhere(
      (d) => d?.id == id,
      orElse: () => null,
    )?.divisao ?? '-';
  }

  String _getSegmentoNome(String? id) {
    if (id == null) return '-';
    return _segmentos.cast<Segmento?>().firstWhere(
      (s) => s?.id == id,
      orElse: () => null,
    )?.segmento ?? '-';
  }

  String _getTipoVeiculoLabel(String tipo) {
    switch (tipo) {
      case 'CARRO_LEVE':
        return 'Carro Leve';
      case 'MUNCK':
        return 'Munck';
      case 'TRATOR':
        return 'Trator';
      case 'CAMINHAO':
        return 'Caminhão';
      case 'PICKUP':
        return 'Pickup';
      case 'VAN':
        return 'Van';
      case 'MOTO':
        return 'Moto';
      case 'ONIBUS':
        return 'Ônibus';
      case 'OUTRO':
        return 'Outro';
      default:
        return tipo;
    }
  }

  List<Frota> get _paginatedFrotas {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= _filteredFrotas.length) return [];
    final endIndex = (startIndex + _itemsPerPage < _filteredFrotas.length)
        ? startIndex + _itemsPerPage
        : _filteredFrotas.length;
    return _filteredFrotas.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredFrotas.length / _itemsPerPage).ceil().clamp(1, 9999);

  Future<void> _createFrota() async {
    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => const FrotaFormDialog(),
    );

    if (result != null) {
      try {
        await _frotaService.createFrota(result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateFrota(Frota frota) async {
    final duplicated = frota.copyWith(
      id: '',
      nome: '${frota.nome} (Cópia)',
      placa: '${frota.placa}-CP',
    );

    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => FrotaFormDialog(frota: duplicated),
    );

    if (result != null) {
      try {
        await _frotaService.createFrota(result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota duplicada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao duplicar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editFrota(Frota frota) async {
    final result = await showDialog<Frota>(
      context: context,
      builder: (context) => FrotaFormDialog(frota: frota),
    );

    if (result != null) {
      try {
        await _frotaService.updateFrota(frota.id, result);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar frota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFrota(Frota frota) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir a frota "${frota.nome}"?\n\n'
          'Placa: ${frota.placa}\n'
          'Tipo: ${_getTipoVeiculoLabel(frota.tipoVeiculo)}',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _frotaService.deleteFrota(frota.id);
        await _loadFrotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Frota excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir frota: $e'),
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
                title: 'Frota',
                subtitle: 'Cadastro e gestão patrimonial de veículos e equipamentos',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Nova Frota',
                  leadingIcon: TFIcons.add,
                  onPressed: _createFrota,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Atualizar',
                    variant: TFIconButtonVariant.standard,
                    onPressed: _loadFrotas,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TFTextField(
                      controller: _searchController,
                      hint: 'Buscar por nome, marca, placa, tipo ou regional...',
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
                        label: 'Tipo de Veículo',
                        selectedValues: _selectedTipos,
                        options: _getUniqueTipos(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedTipos = values;
                            _currentPage = 1;
                            _filteredFrotas = _applyFilter(_frotas);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Marca / Modelo',
                        selectedValues: _selectedMarcas,
                        options: _getUniqueMarcas(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedMarcas = values;
                            _currentPage = 1;
                            _filteredFrotas = _applyFilter(_frotas);
                          });
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    SizedBox(
                      width: 170,
                      child: TFMultiSelectFilterField(
                        label: 'Propriedade',
                        selectedValues: _selectedPropriedades,
                        options: _getUniquePropriedades(),
                        isCompact: true,
                        onChanged: (values) {
                          setState(() {
                            _selectedPropriedades = values;
                            _currentPage = 1;
                            _filteredFrotas = _applyFilter(_frotas);
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
                            _currentPage = 1;
                            _filteredFrotas = _applyFilter(_frotas);
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
                            _filteredFrotas = _applyFilter(_frotas);
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
                            _filteredFrotas = _applyFilter(_frotas);
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
                          message: 'Carregando frota...',
                        ),
                      )
                    : _filteredFrotas.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _frotas.isEmpty
                                ? 'Nenhum veículo cadastrado na frota'
                                : 'Nenhum veículo encontrado',
                            description: _frotas.isEmpty
                                ? 'Cadastre o primeiro veículo ou equipamento da operação.'
                                : 'Tente refinar sua busca.',
                            action: _frotas.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeiro Veículo',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createFrota,
                                  )
                                : TFButton(
                                    label: 'Limpar Busca',
                                    variant: TFButtonVariant.secondary,
                                    onPressed: () => _searchController.clear(),
                                  ),
                          )
                        : Column(
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
                                      'Página $_currentPage de $_totalPages (${_filteredFrotas.length} veículos)',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsView() {
    final items = _paginatedFrotas;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final frota = items[index];
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
                        frota.nome,
                        style: typography.cardTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (frota.emManutencao)
                          Padding(
                            padding: EdgeInsets.only(right: spacing.xs),
                            child: const TFStatusBadge(
                              label: 'Manutenção',
                              severity: TFStatusSeverity.warning,
                              compact: true,
                            ),
                          ),
                        TFStatusBadge(
                          label: frota.ativo ? 'Ativo' : 'Inativo',
                          severity: frota.ativo
                              ? TFStatusSeverity.success
                              : TFStatusSeverity.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Placa: ${frota.placa} • Tipo: ${_getTipoVeiculoLabel(frota.tipoVeiculo)}',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (frota.marca != null && frota.marca!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    'Marca/Modelo: ${frota.marca!}',
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: spacing.xs),
                Text(
                  'Propriedade: ${Frota.getPropriedadeLabel(frota.propriedade)} | Regional: ${_getRegionalNome(frota.regionalId)} | Divisão: ${_getDivisaoNome(frota.divisaoId)} | Segmento: ${_getSegmentoNome(frota.segmentoId)}',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TFIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Duplicar veículo',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _duplicateFrota(frota),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editFrota(frota),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _deleteFrota(frota),
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

    return TFDataTable<Frota>(
      items: _paginatedFrotas,
      columns: [
        TFDataColumn<Frota>.text(
          id: 'nome',
          title: 'Nome / Identificação',
          cellBuilder: (context, frota) => Text(
            frota.nome,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Frota>.text(
          id: 'placa',
          title: 'Placa',
          width: 120,
          cellBuilder: (context, frota) => Text(
            frota.placa,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        TFDataColumn<Frota>.text(
          id: 'tipo',
          title: 'Tipo',
          width: 130,
          cellBuilder: (context, frota) => Text(
            _getTipoVeiculoLabel(frota.tipoVeiculo),
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Frota>.text(
          id: 'marca',
          title: 'Marca/Modelo',
          width: 140,
          cellBuilder: (context, frota) => Text(
            frota.marca ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Frota>.text(
          id: 'propriedade',
          title: 'Propriedade',
          width: 120,
          cellBuilder: (context, frota) => Text(
            Frota.getPropriedadeLabel(frota.propriedade),
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Frota>.text(
          id: 'regional',
          title: 'Regional',
          width: 130,
          cellBuilder: (context, frota) => Text(
            _getRegionalNome(frota.regionalId),
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Frota>(
          id: 'status',
          label: const Text('Status'),
          width: 180,
          cellBuilder: (context, frota) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (frota.emManutencao)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: TFStatusBadge(
                    label: 'Manutenção',
                    severity: TFStatusSeverity.warning,
                    compact: true,
                  ),
                ),
              TFStatusBadge(
                label: frota.ativo ? 'Ativo' : 'Inativo',
                severity: frota.ativo
                    ? TFStatusSeverity.success
                    : TFStatusSeverity.neutral,
                compact: true,
              ),
            ],
          ),
        ),
        TFDataColumn<Frota>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 160,
          alignment: Alignment.centerRight,
          cellBuilder: (context, frota) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicar',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _duplicateFrota(frota),
              ),
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editFrota(frota),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _deleteFrota(frota),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
