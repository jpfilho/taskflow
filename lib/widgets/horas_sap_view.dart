import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/hora_sap.dart';
import '../services/hora_sap_service.dart';
import '../design_system/taskflow_design_system.dart';
import 'horas_metas_view.dart';
import 'confirmacao_form_dialog.dart';

class HorasSAPView extends StatefulWidget {
  final String? searchQuery;
  final String? modoVisualizacao; // Controlado pelo Main para integrar com footbar
  final ValueChanged<String>? onModoChange;
  final VoidCallback? onRefresh; // Para acionar reload a partir de filhos (ex: HorasMetasView)

  const HorasSAPView({
    super.key,
    this.searchQuery,
    this.modoVisualizacao,
    this.onModoChange,
    this.onRefresh,
  });

  @override
  State<HorasSAPView> createState() => HorasSAPViewState();
}

class HorasSAPViewState extends State<HorasSAPView> {
  final HoraSAPService _service = HoraSAPService();
  List<HoraSAP> _horas = [];
  bool _isLoading = false;
  int _totalHoras = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  String _searchQuery = '';
  String _modoVisualizacao = 'metas'; // 'tabela' ou 'metas'
  int _metasViewKey = 0; // Key para forçar rebuild do HorasMetasView

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery ?? '';
    _modoVisualizacao = widget.modoVisualizacao ?? _modoVisualizacao;
    _loadHoras();
  }

  @override
  void didUpdateWidget(HorasSAPView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _searchQuery = widget.searchQuery ?? '';
        _paginaAtual = 0;
      });
      _loadHoras();
    }

    if (widget.modoVisualizacao != null &&
        widget.modoVisualizacao != _modoVisualizacao) {
      setState(() {
        _modoVisualizacao = widget.modoVisualizacao!;
      });
    }
  }

  /// Chamado pelo HeaderBar (botão Atualizar) para recarregar dados.
  void refresh() {
    setState(() {
      _paginaAtual = 0;
    });
    _loadHoras();
    widget.onRefresh?.call();
    if (_modoVisualizacao == 'metas') {
      setState(() {
        _metasViewKey = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  Future<void> _loadHoras() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Janela padrão: últimos 3 meses (reduz volume para evitar timeouts)
      final agora = DateTime.now();
      final dataInicioPadrao = DateTime(agora.year, agora.month - 3, 1);
      final dataFimPadrao = agora;
      final inicio = _paginaAtual * _itensPorPagina;

      // Buscar página no backend com paginação (e busca textual se houver)
      final horasPagina = await _service.getAllHoras(
        limit: _itensPorPagina,
        offset: inicio,
        dataLancamentoInicio: _searchQuery.isNotEmpty ? null : dataInicioPadrao,
        dataLancamentoFim: _searchQuery.isNotEmpty ? null : dataFimPadrao,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Contar total no backend (para paginação)
      final total = await _service.contarHoras(
        dataLancamentoInicio: _searchQuery.isNotEmpty ? null : dataInicioPadrao,
        dataLancamentoFim: _searchQuery.isNotEmpty ? null : dataFimPadrao,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _horas = horasPagina;
          _totalHoras = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erro ao carregar horas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar horas (últimos 3 meses): $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '-';
    return time;
  }

  String _formatDouble(double? value) {
    if (value == null) return '-';
    return value.toStringAsFixed(2);
  }

  void _mostrarDetalhesHora(HoraSAP hora) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderSubtle),
        ),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_filled, color: colors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detalhes da Hora: ${hora.ordem ?? 'N/A'}',
                      style: typography.cardTitle.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 24, color: colors.borderSubtle),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoRow('Data Lançamento', _formatDate(hora.dataLancamento)),
                      _buildInfoRow('Início Real', _formatDate(hora.inicioReal)),
                      _buildInfoRow('Data Fim Real', _formatDate(hora.dataFimReal)),
                      _buildInfoRow('Hora Início Real', _formatTime(hora.horaInicioReal)),
                      _buildInfoRow('Tipo Ordem', hora.tipoOrdem),
                      _buildInfoRow('Ordem', hora.ordem),
                      _buildInfoRow('Operação', hora.operacao),
                      _buildInfoRow('Trabalho Real', _formatDouble(hora.trabalhoReal)),
                      _buildInfoRow('Trabalho Planejado', _formatDouble(hora.trabalhoPlanejado)),
                      _buildInfoRow('Trabalho Restante', _formatDouble(hora.trabalhoRestante)),
                      _buildInfoRow('Tipo Atividade Real', hora.tipoAtividadeReal),
                      _buildInfoRow('Número Pessoa', hora.numeroPessoa),
                      _buildInfoRow('Nome Empregado', hora.nomeEmpregado),
                      _buildInfoRow('Status Sistema', hora.statusSistema),
                      _buildInfoRow('Texto Confirmação', hora.textoConfirmacao),
                      _buildInfoRow('Confirmação', hora.confirmacao),
                      _buildInfoRow('STD', hora.std),
                      _buildInfoRow('Finalizado', hora.finalizado),
                      _buildInfoRow('Campo S', hora.campoS),
                      _buildInfoRow('Centro Trabalho Real', hora.centroTrabalhoReal),
                    ],
                  ),
                ),
              ),
              Divider(height: 24, color: colors.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TFButton(
                    label: 'Fechar',
                    variant: TFButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  TFButton(
                    label: 'Usar na Confirmação',
                    variant: TFButtonVariant.primary,
                    leadingIcon: Icons.check,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Abre o formulário já com a ordem preenchida e carrega operações disponíveis
                      await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmacaoFormDialog(initialOrdem: hora.ordem ?? ''),
                      );
                      // Após fechar o formulário, atualiza a listagem
                      refresh();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return const SizedBox.shrink();
    }
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label:',
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Atualizar está no HeaderBar (desktop/tablet). Conteúdo:
          Expanded(
            child: _modoVisualizacao == 'metas'
                ? HorasMetasView(
                    key: ValueKey(_metasViewKey),
                    onRefresh: () {
                      setState(() {
                        _paginaAtual = 0;
                      });
                      _loadHoras();
                      widget.onRefresh?.call();
                    },
                  )
                : _isLoading
                ? const Center(child: TFLoading(message: 'Carregando horas SAP...'))
                : _totalHoras == 0
                ? const Center(
                    child: TFEmptyState(
                      icon: Icons.access_time,
                      title: 'Nenhuma hora encontrada',
                      description: 'Não foram encontrados lançamentos de horas para os filtros selecionados.',
                    ),
                  )
                : _buildTabelaView(),
          ),
          // Paginação (apenas para visualização de tabela)
          if (_modoVisualizacao == 'tabela' && _totalHoras > _itensPorPagina)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final totalPages = (_totalHoras / _itensPorPagina).ceil();

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
            onPressed: _paginaAtual > 0
                ? () {
                    setState(() {
                      _paginaAtual--;
                    });
                    _loadHoras();
                  }
                : null,
            icon: Icon(Icons.chevron_left, color: _paginaAtual > 0 ? colors.textPrimary : colors.textDisabled),
          ),
          const SizedBox(width: 16),
          Text(
            'Página ${_paginaAtual + 1} de $totalPages',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalHoras
                ? () {
                    setState(() {
                      _paginaAtual++;
                    });
                    _loadHoras();
                  }
                : null,
            icon: Icon(Icons.chevron_right, color: (_paginaAtual + 1) * _itensPorPagina < _totalHoras ? colors.textPrimary : colors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _buildTabelaView() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Feedback Visual do Filtro
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _searchQuery.isNotEmpty
                ? colors.primary.withValues(alpha: 0.08)
                : colors.warning.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: _searchQuery.isNotEmpty
                    ? colors.primary.withValues(alpha: 0.2)
                    : colors.warning.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search : Icons.date_range,
                size: 16,
                color: _searchQuery.isNotEmpty ? colors.primary : colors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'Buscando por "$_searchQuery" em todo o histórico'
                      : 'Exibindo padrão: Últimos 3 meses (Use a busca para ver registros antigos)',
                  style: typography.bodySmall.copyWith(
                    color: _searchQuery.isNotEmpty ? colors.primary : colors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isDesktop
              ? SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dataTable = DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          colors.surfaceSecondary,
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              'Ações',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Data Lançamento',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Ordem',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Tipo Ordem',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Operação',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Trabalho Real',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Trabalho Planejado',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Trabalho Restante',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Tipo Atividade',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Nome Empregado',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Número Pessoa',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Centro Trabalho',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status Sistema',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Início Real',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Fim Real',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Hora Início',
                              style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                        ],
                        rows: _horas.map((hora) {
                          return DataRow(
                            cells: [
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    Icons.visibility,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  onPressed: () => _mostrarDetalhesHora(hora),
                                  tooltip: 'Visualizar',
                                ),
                              ),
                              DataCell(Text(_formatDate(hora.dataLancamento), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.ordem ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.tipoOrdem ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.operacao ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatDouble(hora.trabalhoReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatDouble(hora.trabalhoPlanejado), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatDouble(hora.trabalhoRestante), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.tipoAtividadeReal ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.nomeEmpregado ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.numeroPessoa ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.centroTrabalhoReal ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(hora.statusSistema ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatDate(hora.inicioReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatDate(hora.dataFimReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                              DataCell(Text(_formatTime(hora.horaInicioReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            ],
                          );
                        }).toList(),
                      );
                      return Container(
                        width: constraints.maxWidth,
                        alignment: Alignment.topLeft,
                        child: FittedBox(
                          alignment: Alignment.topLeft,
                          fit: BoxFit.scaleDown,
                          child: dataTable,
                        ),
                      );
                    },
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        colors.surfaceSecondary,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Ações',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Data Lançamento',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Ordem',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tipo Ordem',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Operação',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Trabalho Real',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Trabalho Planejado',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Trabalho Restante',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tipo Atividade',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nome Empregado',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Número Pessoa',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Centro Trabalho',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status Sistema',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Início Real',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fim Real',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Hora Início',
                            style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ),
                      ],
                      rows: _horas.map((hora) {
                        return DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  Icons.visibility,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                onPressed: () => _mostrarDetalhesHora(hora),
                                tooltip: 'Visualizar',
                              ),
                            ),
                            DataCell(Text(_formatDate(hora.dataLancamento), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.ordem ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.tipoOrdem ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.operacao ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatDouble(hora.trabalhoReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatDouble(hora.trabalhoPlanejado), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatDouble(hora.trabalhoRestante), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.tipoAtividadeReal ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.nomeEmpregado ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.numeroPessoa ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.centroTrabalhoReal ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(hora.statusSistema ?? '-', style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatDate(hora.inicioReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatDate(hora.dataFimReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                            DataCell(Text(_formatTime(hora.horaInicioReal), style: typography.bodySmall.copyWith(color: colors.textPrimary))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
