import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/feriado.dart';
import '../services/feriado_service.dart';
import 'feriado_form_dialog.dart';

class FeriadoListView extends StatefulWidget {
  const FeriadoListView({super.key});

  @override
  State<FeriadoListView> createState() => _FeriadoListViewState();
}

class _FeriadoListViewState extends State<FeriadoListView> {
  final FeriadoService _feriadoService = FeriadoService();
  List<Feriado> _feriados = [];
  List<Feriado> _filteredFeriados = [];
  bool _isLoading = true;
  bool _isTableView = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadFeriados();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeriados() async {
    setState(() => _isLoading = true);
    try {
      final feriados = await _feriadoService.getAllFeriados();
      setState(() {
        _feriados = feriados;
        _filteredFeriados = feriados;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      debugPrint('Erro ao carregar feriados: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar feriados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFeriados = _feriados;
      } else {
        _filteredFeriados = _feriados.where((f) {
          return f.descricao.toLowerCase().contains(query) ||
              f.tipo.toLowerCase().contains(query) ||
              (f.pais?.toLowerCase().contains(query) ?? false) ||
              (f.estado?.toLowerCase().contains(query) ?? false) ||
              (f.cidade?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      _currentPage = 1;
    });
  }

  List<Feriado> get _paginatedFeriados {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredFeriados.length);
    if (startIndex >= _filteredFeriados.length) return [];
    return _filteredFeriados.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredFeriados.length / _itemsPerPage).ceil().clamp(1, 9999);

  Future<void> _showFeriadoForm([Feriado? feriado]) async {
    await showDialog(
      context: context,
      builder: (context) => FeriadoFormDialog(
        feriado: feriado,
        onSaved: _loadFeriados,
      ),
    );
  }

  Future<void> _deleteFeriado(Feriado feriado) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Deseja realmente excluir o feriado "${feriado.descricao}"?\n\n'
          'Data: ${_formatDate(feriado.data)}\n'
          'Tipo: ${feriado.tipo}',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _feriadoService.deleteFeriado(feriado.id);
        await _loadFeriados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Feriado excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir feriado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatLocation(Feriado f) {
    final parts = <String>[];
    if (f.pais != null && f.pais!.isNotEmpty) parts.add(f.pais!);
    if (f.estado != null && f.estado!.isNotEmpty) parts.add(f.estado!);
    if (f.cidade != null && f.cidade!.isNotEmpty) parts.add(f.cidade!);
    return parts.isEmpty ? 'Nacional' : parts.join(' / ');
  }

  TFStatusSeverity _getSeverityForTipo(String tipo) {
    switch (tipo) {
      case 'NACIONAL':
        return TFStatusSeverity.info;
      case 'ESTADUAL':
        return TFStatusSeverity.warning;
      case 'MUNICIPAL':
        return TFStatusSeverity.success;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? spacing.sm : spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TFPageHeader(
                title: 'Cadastro de Feriados',
                subtitle: 'Gerencie o calendário de feriados nacionais, estaduais e municipais',
                onBack: () => Navigator.of(context).maybePop(),
                primaryAction: TFButton(
                  label: 'Novo Feriado',
                  leadingIcon: TFIcons.add,
                  size: isMobile ? TFButtonSize.small : TFButtonSize.medium,
                  onPressed: () => _showFeriadoForm(),
                ),
                secondaryActions: [
                  TFIconButton(
                    icon: _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                    tooltip: _isTableView ? 'Visualização em Cards' : 'Visualização em Tabela',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => setState(() => _isTableView = !_isTableView),
                  ),
                  TFIconButton(
                    icon: TFIcons.refresh,
                    tooltip: 'Recarregar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: _loadFeriados,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(bottom: spacing.base),
                child: TFTextField(
                  controller: _searchController,
                  hint: 'Buscar por descrição, tipo, estado ou cidade...',
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
                        message: 'Carregando feriados...',
                      )
                    : _filteredFeriados.isEmpty
                        ? TFEmptyState(
                            icon: TFIcons.search,
                            title: _feriados.isEmpty
                                ? 'Nenhum feriado cadastrado'
                                : 'Nenhum feriado encontrado',
                            description: _feriados.isEmpty
                                ? 'Cadastre o primeiro feriado para configurar os calendários.'
                                : 'Tente buscar por outro termo ou limpe o campo de busca.',
                            action: _feriados.isEmpty
                                ? TFButton(
                                    label: 'Cadastrar Primeiro Feriado',
                                    leadingIcon: TFIcons.add,
                                    onPressed: () => _showFeriadoForm(),
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
              if (_totalPages > 1 && !_isLoading && _filteredFeriados.isNotEmpty)
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

    return TFDataTable<Feriado>(
      items: _paginatedFeriados,
      zebra: true,
      columns: [
        TFDataColumn<Feriado>.text(
          id: 'data',
          title: 'Data',
          width: 130,
          cellBuilder: (context, feriado) => Text(
            _formatDate(feriado.data),
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TFDataColumn<Feriado>.text(
          id: 'descricao',
          title: 'Descrição',
          cellBuilder: (context, feriado) => Text(
            feriado.descricao,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TFDataColumn<Feriado>(
          id: 'tipo',
          label: const Text('Tipo'),
          width: 140,
          cellBuilder: (context, feriado) => TFStatusBadge(
            label: feriado.tipo,
            severity: _getSeverityForTipo(feriado.tipo),
            compact: true,
          ),
        ),
        TFDataColumn<Feriado>.text(
          id: 'localidade',
          title: 'Abrangência / Local',
          cellBuilder: (context, feriado) => Text(
            _formatLocation(feriado),
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TFDataColumn<Feriado>(
          id: 'acoes',
          label: const Text('Ações'),
          width: 130,
          alignment: Alignment.centerRight,
          cellBuilder: (context, feriado) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar feriado',
                variant: TFIconButtonVariant.standard,
                onPressed: () => _showFeriadoForm(feriado),
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir feriado',
                variant: TFIconButtonVariant.subtle,
                onPressed: () => _deleteFeriado(feriado),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList() {
    final items = _paginatedFeriados;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final feriado = items[index];
        return TFCard(
          child: Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(feriado.data),
                      style: typography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TFStatusBadge(
                      label: feriado.tipo,
                      severity: _getSeverityForTipo(feriado.tipo),
                      compact: true,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  feriado.descricao,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  _formatLocation(feriado),
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: spacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TFIconButton(
                      icon: TFIcons.edit,
                      tooltip: 'Editar',
                      variant: TFIconButtonVariant.standard,
                      onPressed: () => _showFeriadoForm(feriado),
                    ),
                    SizedBox(width: spacing.xs),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir',
                      variant: TFIconButtonVariant.subtle,
                      onPressed: () => _deleteFeriado(feriado),
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

  Widget _buildPagination() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Padding(
      padding: EdgeInsets.only(top: spacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Página $_currentPage de $_totalPages (${_filteredFeriados.length} itens)',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          Row(
            children: [
              TFIconButton(
                icon: TFIcons.chevronLeft,
                tooltip: 'Página anterior',
                variant: TFIconButtonVariant.subtle,
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              SizedBox(width: spacing.xs),
              TFIconButton(
                icon: TFIcons.chevronRight,
                tooltip: 'Próxima página',
                variant: TFIconButtonVariant.subtle,
                onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
