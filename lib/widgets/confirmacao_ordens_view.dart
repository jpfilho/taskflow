import 'package:flutter/material.dart';
import '../models/confirmacao.dart';
import '../services/confirmacao_service.dart';
import '../utils/responsive.dart';
import 'confirmacao_form_dialog.dart';

class ConfirmacaoOrdensView extends StatefulWidget {
  const ConfirmacaoOrdensView({super.key});

  @override
  State<ConfirmacaoOrdensView> createState() => _ConfirmacaoOrdensViewState();
}

class _ConfirmacaoOrdensViewState extends State<ConfirmacaoOrdensView> {
  final ConfirmacaoService _service = ConfirmacaoService();
  List<Confirmacao> _confirmacoes = [];
  bool _isLoading = false;
  int _totalCount = 0;
  int _currentPage = 0;
  final int _pageSize = 50;
  
  // Busca e filtros
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _filters = {};
  
  // Opções para filtros
  List<String> _centrosTrabalho = [];
  List<String> _tiposAtividade = [];
  List<String> _confirmacoesFinais = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final confirmacoes = await _service.list(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        filters: _filters.isEmpty ? null : _filters,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final count = await _service.count(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        filters: _filters.isEmpty ? null : _filters,
      );

      if (mounted) {
        setState(() {
          _confirmacoes = confirmacoes;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar confirmações: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final centros = await _service.getDistinctValues('centro_de_trab');
      final tipos = await _service.getDistinctValues('tipo_atividade');
      final confirmacoes = await _service.getDistinctValues('confirmacao_final');

      if (mounted) {
        setState(() {
          _centrosTrabalho = centros;
          _tiposAtividade = tipos;
          _confirmacoesFinais = confirmacoes;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar opções de filtros: $e');
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
    });
    _loadData();
  }

  void _onFilterChanged(Map<String, dynamic> newFilters) {
    setState(() {
      _filters = newFilters;
      _currentPage = 0;
    });
    _loadData();
  }

  void _clearFilters() {
    setState(() {
      _filters = {};
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 0;
    });
    _loadData();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFiltersSheet(),
    );
  }

  Future<void> _showFormDialog({Confirmacao? confirmacao}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmacaoFormDialog(confirmacao: confirmacao),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteConfirmacao(Confirmacao confirmacao) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir a confirmação da ordem ${confirmacao.ordem ?? "sem número"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.delete(confirmacao.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confirmação excluída com sucesso')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(isMobile),
          if (_filters.isNotEmpty || _searchQuery.isNotEmpty) _buildActiveFiltersChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _totalCount == 0
                    ? _buildEmptyState()
                    : isMobile
                        ? _buildMobileList()
                        : _buildDesktopTable(),
          ),
          if (_totalCount > _pageSize) _buildPagination(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Confirmação'),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, size: 28, color: Colors.blue),
              const SizedBox(width: 12),
              const Text(
                'Confirmação de Ordens',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ordem, matrícula ou nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: _onSearch,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showFilters,
                icon: Icon(
                  Icons.filter_list,
                  color: _filters.isNotEmpty ? Colors.blue : null,
                ),
                label: Text(
                  'Filtros${_filters.isNotEmpty ? " (${_filters.length})" : ""}',
                  style: TextStyle(
                    color: _filters.isNotEmpty ? Colors.blue : null,
                    fontWeight: _filters.isNotEmpty ? FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final chips = <Widget>[];
    
    if (_searchQuery.isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Busca: "$_searchQuery"'),
          onDeleted: () {
            _searchController.clear();
            _onSearch('');
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }

    _filters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        String label = '';
        if (key == 'centro_de_trab') label = 'Centro: $value';
        else if (key == 'tipo_atividade') label = 'Tipo: $value';
        else if (key == 'confirmacao_final') label = 'Confirmação: $value';
        else if (key == 'data_lancamento_inicio') {
          final date = value as DateTime;
          label = 'De: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        } else if (key == 'data_lancamento_fim') {
          final date = value as DateTime;
          label = 'Até: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        }

        if (label.isNotEmpty) {
          chips.add(
            Chip(
              label: Text(label),
              onDeleted: () {
                final newFilters = Map<String, dynamic>.from(_filters);
                newFilters.remove(key);
                _onFilterChanged(newFilters);
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          );
        }
      }
    });

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhuma confirmação encontrada',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          if (_filters.isNotEmpty || _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Limpar filtros'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _confirmacoes.length,
      itemBuilder: (context, index) {
        final conf = _confirmacoes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showFormDialog(confirmacao: conf),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ordem: ${conf.ordem ?? "-"}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Excluir', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showFormDialog(confirmacao: conf);
                          } else if (value == 'delete') {
                            _deleteConfirmacao(conf);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildInfoRow('Operação', '${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}'),
                  _buildInfoRow('Centro Trabalho', conf.centroDeTrabalho),
                  _buildInfoRow('Nome', conf.nomes),
                  _buildInfoRow('Matrícula', conf.nPessoal),
                  _buildInfoRow('Trabalho Real', '${conf.formatTrabReal()} ${conf.unid ?? ""}'),
                  _buildInfoRow('Início', '${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}'),
                  _buildInfoRow('Fim', '${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}'),
                  _buildInfoRow('Data Lançamento', conf.formatDate(conf.dataLancamento)),
                  if (conf.confirmacaoFinal != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        label: Text(conf.confirmacaoFinal!),
                        backgroundColor: conf.confirmacaoFinal == 'S' || conf.confirmacaoFinal == 'SIM'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Operação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Centro Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Matrícula', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trab. Real', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Início', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Fim', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Lanç.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Confirmação', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _confirmacoes.map((conf) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                        onPressed: () => _showFormDialog(confirmacao: conf),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => _deleteConfirmacao(conf),
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                ),
                DataCell(Text(conf.ordem ?? '-')),
                DataCell(Text('${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}')),
                DataCell(Text(conf.centroDeTrabalho ?? '-')),
                DataCell(Text(conf.nomes ?? '-')),
                DataCell(Text(conf.nPessoal ?? '-')),
                DataCell(Text('${conf.formatTrabReal()} ${conf.unid ?? ""}')),
                DataCell(Text('${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}')),
                DataCell(Text('${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}')),
                DataCell(Text(conf.formatDate(conf.dataLancamento))),
                DataCell(
                  conf.confirmacaoFinal != null
                      ? Chip(
                          label: Text(conf.confirmacaoFinal!, style: const TextStyle(fontSize: 11)),
                          backgroundColor: conf.confirmacaoFinal == 'S' || conf.confirmacaoFinal == 'SIM'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                        )
                      : const Text('-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadData();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          Text('Página ${_currentPage + 1} de $totalPages'),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadData();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSheet() {
    final tempFilters = Map<String, dynamic>.from(_filters);
    
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Centro de Trabalho
              DropdownButtonFormField<String>(
                initialValue: tempFilters['centro_de_trab'],
                decoration: const InputDecoration(
                  labelText: 'Centro de Trabalho',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._centrosTrabalho.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (value) {
                  setModalState(() {
                    if (value == null) {
                      tempFilters.remove('centro_de_trab');
                    } else {
                      tempFilters['centro_de_trab'] = value;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Tipo de Atividade
              DropdownButtonFormField<String>(
                initialValue: tempFilters['tipo_atividade'],
                decoration: const InputDecoration(
                  labelText: 'Tipo de Atividade',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._tiposAtividade.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (value) {
                  setModalState(() {
                    if (value == null) {
                      tempFilters.remove('tipo_atividade');
                    } else {
                      tempFilters['tipo_atividade'] = value;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Confirmação Final
              DropdownButtonFormField<String>(
                initialValue: tempFilters['confirmacao_final'],
                decoration: const InputDecoration(
                  labelText: 'Confirmação Final',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._confirmacoesFinais.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (value) {
                  setModalState(() {
                    if (value == null) {
                      tempFilters.remove('confirmacao_final');
                    } else {
                      tempFilters['confirmacao_final'] = value;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() => tempFilters.clear());
                      },
                      child: const Text('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _onFilterChanged(tempFilters);
                        Navigator.pop(context);
                      },
                      child: const Text('Aplicar'),
                    ),
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
