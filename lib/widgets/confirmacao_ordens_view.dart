import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/confirmacao.dart';
import '../models/confirmacao_sap.dart';
import '../services/confirmacao_service.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';
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
    final colors = context.tfColors;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Column(
          children: [
            _buildHeader(isMobile),
            Container(
              color: colors.surface,
              child: TabBar(
                tabs: const [
                  Tab(text: 'Confirmações'),
                  Tab(text: 'SAP (Tabela)'),
                ],
                labelColor: colors.primary,
                unselectedLabelColor: colors.textSecondary,
                indicatorColor: colors.primary,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Confirmações
                  Column(
                    children: [
                      Expanded(
                        child: _isLoading
                            ? const Center(child: TFLoading(message: 'Carregando confirmações...'))
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
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          icon: const Icon(Icons.add),
          label: const Text('Nova Confirmação'),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check, size: 28, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirmação de Ordens (IW41)',
                  style: typography.pageTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: colors.textSecondary),
                onPressed: _loadData,
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: typography.bodyMedium.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por ordem, matrícula ou nome',
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
              fillColor: colors.surfaceSecondary,
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
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

  Widget _buildEmptyState() {
    return const TFEmptyState(
      icon: Icons.inbox,
      title: 'Nenhuma confirmação encontrada',
      description: 'Não há confirmações cadastradas ou correspondentes aos filtros aplicados.',
    );
  }

  Widget _buildMobileList() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _confirmacoes.length,
        itemBuilder: (context, index) {
          final conf = _confirmacoes[index];
          final isConfirmed = conf.confirmacaoFinal == 'S' || conf.confirmacaoFinal == 'SIM';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TFCard(
              onTap: () => _showFormDialog(confirmacao: conf),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ordem: ${conf.ordem ?? "-"}',
                          style: typography.cardTitle.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: colors.textSecondary),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: colors.primary),
                                const SizedBox(width: 8),
                                const Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: colors.danger),
                                const SizedBox(width: 8),
                                Text('Excluir', style: TextStyle(color: colors.danger)),
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
                  Divider(height: 16, color: colors.borderSubtle),
                  _buildInfoRow('Operação', '${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}'),
                  _buildInfoRow('Centro Trabalho', conf.centroDeTrabalho),
                  _buildInfoRow('Nome', conf.nomes),
                  _buildInfoRow('Matrícula', conf.nPessoal),
                  _buildInfoRow('Trabalho Real', '${conf.formatTrabReal()} ${conf.unid ?? ""}'),
                  _buildInfoRow('Início', '${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}'),
                  _buildInfoRow('Fim', '${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}'),
                  _buildInfoRow('Data Lançamento', conf.formatDate(conf.dataLancamento)),
                  _buildInfoRow('Status', conf.status),
                  if (conf.confirmacaoFinal != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TFStatusBadge(
                        label: isConfirmed ? 'CONFIRMADO (${conf.confirmacaoFinal})' : 'NÃO CONFIRMADO (${conf.confirmacaoFinal})',
                        severity: isConfirmed ? TFStatusSeverity.success : TFStatusSeverity.warning,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value == '-') return const SizedBox.shrink();
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      color: colors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(colors.surfaceSecondary),
            columns: [
              DataColumn(
                label: Text(
                  'Ações',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Ordem',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Operação',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Centro Trabalho',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nome',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Matrícula',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Trab. Real',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Início',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Fim',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Data Lanç.',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Confirmação',
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
            rows: _confirmacoes.map((conf) {
              final isConfirmed = conf.confirmacaoFinal == 'S' || conf.confirmacaoFinal == 'SIM';

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 18,
                            color: colors.primary,
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
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: colors.danger,
                                ),
                                onPressed: () => _deleteConfirmacao(conf),
                                tooltip: 'Excluir',
                              ),
                      ],
                    ),
                  ),
                  DataCell(Text(conf.ordem ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(
                    Text('${conf.operacao2 ?? "-"} / ${conf.subOper ?? "-"}', style: typography.bodySmall.copyWith(color: colors.textPrimary)),
                  ),
                  DataCell(Text(conf.centroDeTrabalho ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(Text(conf.nomes ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(Text(conf.nPessoal ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(Text('${conf.formatTrabReal()} ${conf.unid ?? ""}', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(
                    Text(
                      '${conf.formatDate(conf.datInicioExec)} ${conf.formatTime(conf.horaInicio)}',
                      style: typography.bodySmall.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${conf.formatDate(conf.datFimExec)} ${conf.formatTime(conf.horaFim)}',
                      style: typography.bodySmall.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  DataCell(Text(conf.formatDate(conf.dataLancamento), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(Text(conf.status ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                  DataCell(
                    conf.confirmacaoFinal != null
                        ? TFStatusBadge(
                            label: conf.confirmacaoFinal!,
                            severity: isConfirmed ? TFStatusSeverity.success : TFStatusSeverity.warning,
                            compact: true,
                          )
                        : Text('-', style: typography.bodySmall.copyWith(color: colors.textSecondary)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
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
            icon: Icon(Icons.chevron_left, color: _currentPage > 0 ? colors.textPrimary : colors.textDisabled),
          ),
          const SizedBox(width: 16),
          Text(
            'Página ${_currentPage + 1} de $totalPages',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadData();
                  }
                : null,
            icon: Icon(Icons.chevron_right, color: _currentPage < totalPages - 1 ? colors.textPrimary : colors.textDisabled),
          ),
        ],
      ),
    );
  }
}
