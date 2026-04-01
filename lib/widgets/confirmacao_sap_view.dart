import 'package:flutter/material.dart';
import '../models/confirmacao_sap.dart';
import '../services/confirmacao_sap_service.dart';
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
  List<String> _centros = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
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
          _centros = results[4];
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar opções de filtro SAP: $e');
    }
  }

  Future<void> _loadData() async {
    print('🔍 [SAP DEBUG] Iniciando carregamento de dados (página: $_currentPage)...');
    setState(() => _isLoading = true);
    try {
      final results = await _service.list(
        search: _searchController.text,
        filters: _filters,
        page: _currentPage,
        pageSize: _pageSize,
      );
      print('🔍 [SAP DEBUG] Listagem concluída: ${results.length} itens.');

      final count = await _service.count(
        search: _searchController.text,
        filters: _filters,
      );
      print('🔍 [SAP DEBUG] Contagem concluída: $count itens.');

      if (mounted) {
        setState(() {
          _confirmacoes = results;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print('❌ [SAP DEBUG] Erro ao carregar dados SAP: $e');
      print(stack);
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
    return Column(
      children: [
        _buildFilterBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por confirmação, ordem, tipo, texto, operador...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _currentPage = 0;
                              _loadData();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
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
                icon: const Icon(Icons.refresh),
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
              ? const Center(child: CircularProgressIndicator())
              : _confirmacoes.isEmpty
                  ? Center(child: Text('Nenhum dado encontrado para os filtros selecionados (Contagem: $_totalCount)'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          horizontalMargin: 12,
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                          columns: const [
                            DataColumn(label: Text('Confirmação')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Ordem')),
                            DataColumn(label: Text('Operação')),
                            DataColumn(label: Text('Texto Breve')),
                            DataColumn(label: Text('Texto Breve Op.')),
                            DataColumn(label: Text('Status Usuário')),
                            DataColumn(label: Text('Status Sistema')),
                            DataColumn(label: Text('Restri. Iníc.')),
                            DataColumn(label: Text('Hora In.')),
                            DataColumn(label: Text('Fim Restri.')),
                            DataColumn(label: Text('Hora F.')),
                            DataColumn(label: Text('Centro Trab.')),
                            DataColumn(label: Text('Criado Por')),
                            DataColumn(label: Text('Trab. Real')),
                            DataColumn(label: Text('Data Conf.')),
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
                              DataCell(Text(item.confirmacao)),
                              DataCell(Text(item.tipo ?? '')),
                              DataCell(Text(item.ordem ?? '')),
                              DataCell(Text(item.operacao ?? '')),
                              DataCell(Text(item.textoBreve ?? '')),
                              DataCell(Text(item.textoBreveOperacao ?? '')),
                              DataCell(Text(item.statusUsuario ?? '')),
                              DataCell(Text(item.statusSistema ?? '')),
                              DataCell(Text(item.restricaoInicio != null 
                                  ? DateFormat('dd/MM/yyyy').format(item.restricaoInicio!) 
                                  : '')),
                              DataCell(Text(item.resHorIn ?? '')),
                              DataCell(Text(item.fimRestricao != null 
                                  ? DateFormat('dd/MM/yyyy').format(item.fimRestricao!) 
                                  : '')),
                              DataCell(Text(item.resHoraF ?? '')),
                              DataCell(Text(item.centroTrabalho ?? '')),
                              DataCell(Text(item.criadoPor ?? '')),
                              DataCell(Text(item.trabalhoReal?.toStringAsFixed(2) ?? '0.00')),
                              DataCell(Text(item.dataConfirmacao != null 
                                  ? DateFormat('dd/MM/yyyy').format(item.dataConfirmacao!) 
                                  : '')),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadData();
                  }
                : null,
          ),
          Text('Página ${_currentPage + 1} de $totalPages ($_totalCount itens)'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
          _buildMultiSelectFilter('Centro Trabalho', 'centro_trabalho', _centros),
        ],
      ),
    );
  }

  Widget _buildMultiSelectFilter(String label, String key, List<String> options) {
    final selectedCount = _filters[key]?.length ?? 0;
    final isSelected = selectedCount > 0;

    return GestureDetector(
      onTap: () async {
        final result = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => MultiSelectFilterDialog(
            title: 'Filtrar $label',
            options: options,
            selectedValues: _filters[key] ?? {},
            onSelectionChanged: (values) {
              // Já tratado pelo result do showDialog no nosso caso para recarregar
            },
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
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.grey,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.blue.shade800 : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
