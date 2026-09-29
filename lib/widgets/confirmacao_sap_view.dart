import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/confirmacao_sap.dart';
import '../services/confirmacao_sap_service.dart';
import '../design_system/taskflow_design_system.dart';
import 'package:intl/intl.dart';
import 'multi_select_filter_dialog.dart';

class ConfirmacaoSapView extends StatefulWidget {
  final Function(ConfirmacaoSap?)? onSelect;
  const ConfirmacaoSapView({super.key, this.onSelect});

  @override
  State<ConfirmacaoSapView> createState() => _ConfirmacaoSapViewState();
}

class _ConfirmacaoSapViewState extends State<ConfirmacaoSapView> {
  final ConfirmacaoSapService _service = ConfirmacaoSapService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ConfirmacaoSap> _confirmacoes = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalCount = 0;
  final int _pageSize = 50;
  String? _selectedId;
  
  // Filtros (Multi-select)
  final Map<String, Set<String>> _filters = {
    'tipo': {},
    'ordem': {},
    'operacao': {},
    'status_usuario': {},
    'centro_trabalho': {},
  };

  List<String> _tipos = [];
  List<String> _ordens = [];
  List<String> _operacoes = [];
  List<String> _statusUsuarios = [];
  List<String> _centrosTrabalho = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        _service.getDistinctValues('tipo'),
        _service.getDistinctValues('ordem'),
        _service.getDistinctValues('operacao'),
        _service.getDistinctValues('status_usuario'),
        _service.getDistinctValues('centro_trabalho'),
      ]);

      if (mounted) {
        setState(() {
          _tipos = results[0];
          _ordens = results[1];
          _operacoes = results[2];
          _statusUsuarios = results[3];
          _centrosTrabalho = results[4];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erro ao carregar opções de filtro SAP: $e');
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await _service.list(
        search: _searchController.text,
        filters: _filters,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final count = await _service.count(
        search: _searchController.text,
        filters: _filters,
      );

      if (mounted) {
        setState(() {
          _confirmacoes = results;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [SAP DEBUG] Erro ao carregar dados SAP: $e');
        debugPrint(stack.toString());
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados SAP: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildFilterBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar por confirmação, ordem, tipo, texto, operador...',
                      hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
                      prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: colors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                _currentPage = 0;
                                _loadData();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.borderFocus, width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Repaint to show/hide clear icon
                      _currentPage = 0;
                      _loadData();
                    },
                    onSubmitted: (_) {
                      _currentPage = 0;
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh, color: colors.textSecondary),
                  onPressed: () {
                    _currentPage = 0;
                    _loadData();
                  },
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: TFLoading(message: 'Carregando dados SAP...'))
                : _confirmacoes.isEmpty
                    ? const Center(
                        child: TFEmptyState(
                          icon: Icons.table_rows_outlined,
                          title: 'Nenhum dado SAP encontrado',
                          description: 'Não foram encontrados registros para os filtros selecionados.',
                        ),
                      )
                    : Container(
                        color: colors.surface,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              horizontalMargin: 12,
                              columnSpacing: 24,
                              headingRowColor: WidgetStateProperty.all(colors.surfaceSecondary),
                              columns: [
                                DataColumn(label: Text('Confirmação', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Tipo', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Ordem', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Operação', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Texto Breve', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Texto Breve Op.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Status Usuário', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Status Sistema', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Restri. Iníc.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Hora In.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Fim Restri.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Hora F.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Centro Trab.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Criado Por', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Trab. Real', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                                DataColumn(label: Text('Data Conf.', style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
                              ],
                              rows: _confirmacoes.map((item) {
                                final isSelected = _selectedId == item.confirmacao;
                                return DataRow(
                                  selected: isSelected,
                                  onSelectChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedId = item.confirmacao;
                                        widget.onSelect?.call(item);
                                      } else {
                                        _selectedId = null;
                                        widget.onSelect?.call(null);
                                      }
                                    });
                                  },
                                  cells: [
                                    DataCell(Text(item.confirmacao, style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.tipo ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.ordem ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.operacao ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.textoBreve ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.textoBreveOperacao ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.statusUsuario ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.statusSistema ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.restricaoInicio != null 
                                        ? DateFormat('dd/MM/yyyy').format(item.restricaoInicio!) 
                                        : '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.resHorIn ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.fimRestricao != null 
                                        ? DateFormat('dd/MM/yyyy').format(item.fimRestricao!) 
                                        : '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.resHoraF ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.centroTrabalho ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.criadoPor ?? '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.trabalhoReal?.toStringAsFixed(2) ?? '0.00', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                    DataCell(Text(item.dataConfirmacao != null 
                                        ? DateFormat('dd/MM/yyyy').format(item.dataConfirmacao!) 
                                        : '', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: _currentPage > 0 ? colors.textPrimary : colors.textDisabled),
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadData();
                  }
                : null,
          ),
          Text(
            'Página ${_currentPage + 1} de $totalPages ($_totalCount itens)',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: _currentPage < totalPages - 1 ? colors.textPrimary : colors.textDisabled),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadData();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildMultiSelectFilter('Tipo', 'tipo', _tipos),
          const SizedBox(width: 8),
          _buildMultiSelectFilter('Ordem', 'ordem', _ordens),
          const SizedBox(width: 8),
          _buildMultiSelectFilter('Operação', 'operacao', _operacoes),
          const SizedBox(width: 8),
          _buildMultiSelectFilter('Status Usuário', 'status_usuario', _statusUsuarios),
          const SizedBox(width: 8),
          _buildMultiSelectFilter('Centro Trabalho', 'centro_trabalho', _centrosTrabalho),
        ],
      ),
    );
  }

  Widget _buildMultiSelectFilter(String label, String key, List<String> options) {
    final selectedCount = _filters[key]?.length ?? 0;
    final isSelected = selectedCount > 0;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return GestureDetector(
      onTap: () async {
        final result = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => MultiSelectFilterDialog(
            title: 'Filtrar $label',
            options: options,
            selectedValues: _filters[key] ?? {},
            onSelectionChanged: (values) {},
          ),
        );

        if (result != null) {
          setState(() {
            _filters[key] = result;
            _currentPage = 0;
          });
          _loadData();
        }
      },
      child: Container(
        width: 155,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
          border: Border.all(color: isSelected ? colors.primary : colors.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.labelSmall.copyWith(
                fontSize: 10,
                color: isSelected ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCount == 0
                        ? 'Todos'
                        : selectedCount == 1
                            ? _filters[key]!.first
                            : '$selectedCount selecionados',
                    style: typography.bodySmall.copyWith(
                      fontSize: 13,
                      color: isSelected ? colors.primary : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
