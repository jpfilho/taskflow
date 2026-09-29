import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/regra_prazo_nota.dart';
import '../models/segmento.dart';
import '../services/regra_prazo_nota_service.dart';
import '../services/segmento_service.dart';
import 'regra_prazo_nota_form_dialog.dart';

class RegraPrazoNotaListView extends StatefulWidget {
  const RegraPrazoNotaListView({super.key});

  @override
  State<RegraPrazoNotaListView> createState() => _RegraPrazoNotaListViewState();
}

class _RegraPrazoNotaListViewState extends State<RegraPrazoNotaListView> {
  final RegraPrazoNotaService _service = RegraPrazoNotaService();
  final SegmentoService _segmentoService = SegmentoService();
  List<RegraPrazoNota> _regrasList = [];
  List<RegraPrazoNota> _filteredRegrasList = [];
  Map<String, Segmento> _segmentosMap = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadRegras();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegras() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.getAllRegras(),
        _segmentoService.getAllSegmentos(),
      ]);

      final regrasList = results[0] as List<RegraPrazoNota>;
      final segmentosList = results[1] as List<Segmento>;

      final segmentosMap = <String, Segmento>{};
      for (var segmento in segmentosList) {
        segmentosMap[segmento.id] = segmento;
      }

      if (mounted) {
        setState(() {
          _regrasList = regrasList;
          _filteredRegrasList = regrasList;
          _segmentosMap = segmentosMap;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar regras de prazo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getSegmentosNomes(List<String> segmentoIds) {
    if (segmentoIds.isEmpty) return 'Todos os Segmentos';
    return segmentoIds
        .map((id) => _segmentosMap[id]?.segmento ?? 'Não identificado')
        .join(', ');
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _currentPage = 1;
      if (query.isEmpty) {
        _filteredRegrasList = _regrasList;
      } else {
        _filteredRegrasList = _regrasList.where((regra) {
          final segmentosNomes = _getSegmentosNomes(regra.segmentoIds).toLowerCase();
          return regra.prioridade.toLowerCase().contains(query) ||
              regra.dataReferenciaLabel.toLowerCase().contains(query) ||
              segmentosNomes.contains(query) ||
              (regra.descricao?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  List<RegraPrazoNota> get _paginatedRegras {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= _filteredRegrasList.length) return [];
    final endIndex = (startIndex + _itemsPerPage < _filteredRegrasList.length)
        ? startIndex + _itemsPerPage
        : _filteredRegrasList.length;
    return _filteredRegrasList.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredRegrasList.length / _itemsPerPage).ceil().clamp(1, 9999);

  Future<void> _createRegra() async {
    final result = await showDialog<RegraPrazoNota>(
      context: context,
      builder: (context) => const RegraPrazoNotaFormDialog(),
    );

    if (result != null) {
      try {
        final created = await _service.createRegra(result);
        if (created != null) {
          await _loadRegras();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regra de prazo criada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar regra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editRegra(RegraPrazoNota regra) async {
    final result = await showDialog<RegraPrazoNota>(
      context: context,
      builder: (context) => RegraPrazoNotaFormDialog(regra: regra),
    );

    if (result != null) {
      try {
        final updated = await _service.updateRegra(regra.id, result);
        if (updated != null) {
          await _loadRegras();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regra de prazo atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar regra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRegra(RegraPrazoNota regra) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar Exclusão',
      message: 'Deseja realmente excluir a regra de prazo?\n\n'
          'Prioridade: ${regra.prioridade}\n'
          'Dias de Prazo: ${regra.diasPrazo} dias\n'
          'Data Base: ${regra.dataReferenciaLabel}',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        final deleted = await _service.deleteRegra(regra.id);
        if (deleted) {
          await _loadRegras();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regra de prazo excluída com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao excluir regra de prazo'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir regra: $e'),
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
                title: 'Regras de Prazo para Notas',
                subtitle: 'Parametrização administrativa dos prazos de atendimento por prioridade',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Nova Regra',
                  leadingIcon: TFIcons.add,
                  onPressed: _createRegra,
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Atualizar',
                    variant: TFIconButtonVariant.standard,
                    onPressed: _loadRegras,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              TFTextField(
                controller: _searchController,
                hint: 'Buscar por prioridade, data base, segmento ou descrição...',
                prefixIcon: const Icon(Icons.search),
              ),
              SizedBox(height: spacing.md),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: TFLoading(
                          mode: TFLoadingMode.section,
                          message: 'Carregando regras de prazo...',
                        ),
                      )
                    : _filteredRegrasList.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _regrasList.isEmpty
                                ? 'Nenhuma regra de prazo cadastrada'
                                : 'Nenhuma regra encontrada',
                            description: _regrasList.isEmpty
                                ? 'Cadastre a primeira regra para automação dos prazos de notas.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _regrasList.isEmpty
                                ? TFButton(
                                    label: 'Criar Primeira Regra',
                                    leadingIcon: TFIcons.add,
                                    onPressed: _createRegra,
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
                                      'Página $_currentPage de $_totalPages (${_filteredRegrasList.length} itens)',
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
    final items = _paginatedRegras;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final regra = items[index];
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
                        regra.prioridade,
                        style: typography.cardTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TFStatusBadge(
                      label: regra.ativo ? 'Ativa' : 'Inativa',
                      severity: regra.ativo
                          ? TFStatusSeverity.success
                          : TFStatusSeverity.neutral,
                      compact: true,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Prazo: ${regra.diasPrazo} dias • Base: ${regra.dataReferenciaLabel}',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Segmentos: ${_getSegmentosNomes(regra.segmentoIds)}',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (regra.descricao != null && regra.descricao!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    regra.descricao!,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                SizedBox(height: spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _editRegra(regra),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _deleteRegra(regra),
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

    return TFDataTable<RegraPrazoNota>(
      items: _paginatedRegras,
      columns: [
        TFDataColumn<RegraPrazoNota>.text(
          id: 'prioridade',
          title: 'Prioridade',
          width: 140,
          cellBuilder: (context, regra) => Text(
            regra.prioridade,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<RegraPrazoNota>.text(
          id: 'prazo',
          title: 'Prazo',
          width: 110,
          cellBuilder: (context, regra) => Text(
            '${regra.diasPrazo} dias',
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        TFDataColumn<RegraPrazoNota>.text(
          id: 'referencia',
          title: 'Data de Referência',
          width: 180,
          cellBuilder: (context, regra) => Text(
            regra.dataReferenciaLabel,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        TFDataColumn<RegraPrazoNota>.text(
          id: 'segmentos',
          title: 'Segmentos',
          cellBuilder: (context, regra) => Text(
            _getSegmentosNomes(regra.segmentoIds),
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TFDataColumn<RegraPrazoNota>(
          id: 'status',
          label: const Text('Status'),
          width: 110,
          cellBuilder: (context, regra) => TFStatusBadge(
            label: regra.ativo ? 'Ativa' : 'Inativa',
            severity: regra.ativo
                ? TFStatusSeverity.success
                : TFStatusSeverity.neutral,
            compact: true,
          ),
        ),
        TFDataColumn<RegraPrazoNota>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, regra) => Text(
            regra.descricao ?? '-',
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TFDataColumn<RegraPrazoNota>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 130,
          alignment: Alignment.centerRight,
          cellBuilder: (context, regra) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _editRegra(regra),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _deleteRegra(regra),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
