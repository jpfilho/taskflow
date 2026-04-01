import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/confirmacao.dart';
import '../models/confirmacao_sap.dart';
import '../services/confirmacao_service.dart';
import '../utils/responsive.dart';
import 'confirmacao_form_dialog.dart';
import 'confirmacao_sap_view.dart';

class ConfirmacaoOrdensView extends StatefulWidget {
  const ConfirmacaoOrdensView({super.key});

  @override
  State<ConfirmacaoOrdensView> createState() => _ConfirmacaoOrdensViewState();
}

class _ConfirmacaoOrdensViewState extends State<ConfirmacaoOrdensView> {
  final ConfirmacaoService _service = ConfirmacaoService();
  List<Confirmacao> _confirmacoes = [];
  bool _isLoading = false;
  final Set<String> _deletingIds = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  // filters removed for this view
  int _totalCount = 0;
  int _currentPage = 0;
  final int _pageSize = 50;
  ConfirmacaoSap? _selectedSapRow;

  // Busca e filtros removidos conforme solicitado

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final result = await _service.listWithCount(
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final confirmacoes = result['items'] as List<Confirmacao>;
      final count = result['total'] as int;

      if (mounted) {
        setState(() {
          _confirmacoes = confirmacoes;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao carregar confirmações: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showFormDialog({
    Confirmacao? confirmacao,
    ConfirmacaoSap? sapData,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ConfirmacaoFormDialog(confirmacao: confirmacao, sapData: sapData),
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
        content: Text(
          'Deseja realmente excluir a confirmação da ordem ${confirmacao.ordem ?? "sem número"}?',
        ),
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
      setState(() => _deletingIds.add(confirmacao.id));
      try {
        await _service.delete(confirmacao.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confirmação excluída com sucesso')),
          );
          await _loadData();
        }
      } catch (e) {
        if (kDebugMode) print('❌ Erro ao excluir confirmação: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir confirmação'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _deletingIds.remove(confirmacao.id));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(isMobile),
            const TabBar(
              tabs: [
                Tab(text: 'Confirmações'),
                Tab(text: 'SAP (Tabela)'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Confirmações
                  Column(
                    children: [
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
                  // Tab 2: SAP (Tabela)
                  ConfirmacaoSapView(
                    onSelect: (row) {
                      _selectedSapRow = row;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(sapData: _selectedSapRow),
          icon: const Icon(Icons.add),
          label: const Text('Nova Confirmação'),
        ),
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por ordem, matrícula ou nome',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
            ),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                _currentPage = 0;
                _loadData();
              });
            },
          ),
        ],
      ),
    );
  }

  // filters removed — not needed on this screen

  // searchable select removed — filters not needed here

  // Removido _buildActiveFiltersChips

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
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
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
                        PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: const [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Excluir',
                                    style: TextStyle(color: Colors.red),
                                  ),
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
                    _buildInfoRow(
                      'Operação',
                      '${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}',
                    ),
                    _buildInfoRow('Centro Trabalho', conf.centroDeTrabalho),
                    _buildInfoRow('Nome', conf.nomes),
                    _buildInfoRow('Matrícula', conf.nPessoal),
                    _buildInfoRow(
                      'Trabalho Real',
                      '${conf.formatTrabReal()} ${conf.unid ?? ""}',
                    ),
                    _buildInfoRow(
                      'Início',
                      '${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}',
                    ),
                    _buildInfoRow(
                      'Fim',
                      '${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}',
                    ),
                    _buildInfoRow(
                      'Data Lançamento',
                      conf.formatDate(conf.dataLancamento),
                    ),
                    _buildInfoRow('Status', conf.status),
                    if (conf.confirmacaoFinal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Tooltip(
                          message:
                              (conf.confirmacaoFinal == 'S' ||
                                  conf.confirmacaoFinal == 'SIM')
                              ? 'Confirmado'
                              : 'Não confirmado',
                          child: Chip(
                            label: Text(conf.confirmacaoFinal!),
                            backgroundColor:
                                (conf.confirmacaoFinal == 'S' ||
                                    conf.confirmacaoFinal == 'SIM')
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          horizontalMargin: 12,
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(
              label: Text(
                'Ações',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Ordem',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Operação',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Centro Trabalho',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Nome',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Matrícula',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Trab. Real',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Início',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text('Fim', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'Data Lanç.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Confirmação',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _confirmacoes.map((conf) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed: () => _showFormDialog(confirmacao: conf),
                        tooltip: 'Editar',
                      ),
                      _deletingIds.contains(conf.id)
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteConfirmacao(conf),
                              tooltip: 'Excluir',
                            ),
                    ],
                  ),
                ),
                DataCell(Text(conf.ordem ?? '-')),
                DataCell(
                  Text('${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}'),
                ),
                DataCell(Text(conf.centroDeTrabalho ?? '-')),
                DataCell(Text(conf.nomes ?? '-')),
                DataCell(Text(conf.nPessoal ?? '-')),
                DataCell(Text('${conf.formatTrabReal()} ${conf.unid ?? ""}')),
                DataCell(
                  Text(
                    '${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}',
                  ),
                ),
                DataCell(
                  Text(
                    '${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}',
                  ),
                ),
                DataCell(Text(conf.formatDate(conf.dataLancamento))),
                DataCell(Text(conf.status ?? '-')),
                DataCell(
                  conf.confirmacaoFinal != null
                      ? Chip(
                          label: Text(
                            conf.confirmacaoFinal!,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor:
                              conf.confirmacaoFinal == 'S' ||
                                  conf.confirmacaoFinal == 'SIM'
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

  // Removido _buildFiltersSheet
}
