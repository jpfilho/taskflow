import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/hora_sap.dart';
import '../services/hora_sap_service.dart';
import 'horas_metas_view.dart';

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
  State<HorasSAPView> createState() => _HorasSAPViewState();
}

class _HorasSAPViewState extends State<HorasSAPView> {
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

    if (widget.modoVisualizacao != null && widget.modoVisualizacao != _modoVisualizacao) {
      setState(() {
        _modoVisualizacao = widget.modoVisualizacao!;
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

      // Buscar página no backend com paginação
      final horasPagina = await _service.getAllHoras(
        limit: _itensPorPagina,
        offset: inicio,
        dataLancamentoInicio: dataInicioPadrao,
        dataLancamentoFim: dataFimPadrao,
      );

      // Contar total no backend (para paginação)
      final total = await _service.contarHoras(
        dataLancamentoInicio: dataInicioPadrao,
        dataLancamentoFim: dataFimPadrao,
      );

      // Aplicar busca local (fallback) somente se houver termo
      var horasFiltradas = horasPagina;
      if (_searchQuery.isNotEmpty) {
        final queryLower = _searchQuery.toLowerCase();
        horasFiltradas = horasPagina.where((hora) {
          return (hora.ordem?.toLowerCase().contains(queryLower) ?? false) ||
                 (hora.nomeEmpregado?.toLowerCase().contains(queryLower) ?? false) ||
                 (hora.numeroPessoa?.toLowerCase().contains(queryLower) ?? false) ||
                 (hora.centroTrabalhoReal?.toLowerCase().contains(queryLower) ?? false) ||
                 (hora.tipoAtividadeReal?.toLowerCase().contains(queryLower) ?? false) ||
                 (hora.statusSistema?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _horas = horasFiltradas;
          _totalHoras = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar horas: $e');
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da Hora: ${hora.ordem ?? 'N/A'}'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SingleChildScrollView(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      body: Column(
        children: [
          // Header (desktop/tablet). No mobile o refresh desce para a barra de ações interna.
          if (!isMobile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text(
                    'Horas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botões de visualização (desktop/tablet); no mobile fica no footbar
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'tabela', label: Text('Tabela'), icon: Icon(Icons.table_chart)),
                      ButtonSegment(value: 'metas', label: Text('Metas'), icon: Icon(Icons.track_changes)),
                    ],
                    selected: {_modoVisualizacao},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _modoVisualizacao = newSelection.first;
                      });
                      widget.onModoChange?.call(_modoVisualizacao);
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: () {
                      setState(() {
                        _paginaAtual = 0;
                      });
                      _loadHoras();
                      widget.onRefresh?.call();
                      // Se estiver na visualização de metas, também atualizar
                      if (_modoVisualizacao == 'metas') {
                        // Forçar rebuild do HorasMetasView usando uma key única
                        setState(() {
                          _metasViewKey = DateTime.now().millisecondsSinceEpoch;
                        });
                      }
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          // Conteúdo
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
                    ? const Center(child: CircularProgressIndicator())
                    : _totalHoras == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nenhuma hora encontrada',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _buildTabelaView(),
          ),
          // Paginação (apenas para visualização de tabela)
          if (_modoVisualizacao == 'tabela' && _totalHoras > _itensPorPagina)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
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
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalHoras / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalHoras
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            _loadHoras();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Lançamento', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Operação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trabalho Real', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trabalho Planejado', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Trabalho Restante', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo Atividade', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nome Empregado', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Número Pessoa', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Centro Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Início Real', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Fim Real', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Hora Início', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _horas.map((hora) {
            return DataRow(
              cells: [
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18, color: Colors.purple),
                    onPressed: () => _mostrarDetalhesHora(hora),
                    tooltip: 'Visualizar',
                  ),
                ),
                DataCell(Text(_formatDate(hora.dataLancamento))),
                DataCell(Text(hora.ordem ?? '-')),
                DataCell(Text(hora.tipoOrdem ?? '-')),
                DataCell(Text(hora.operacao ?? '-')),
                DataCell(Text(_formatDouble(hora.trabalhoReal))),
                DataCell(Text(_formatDouble(hora.trabalhoPlanejado))),
                DataCell(Text(_formatDouble(hora.trabalhoRestante))),
                DataCell(Text(hora.tipoAtividadeReal ?? '-')),
                DataCell(Text(hora.nomeEmpregado ?? '-')),
                DataCell(Text(hora.numeroPessoa ?? '-')),
                DataCell(Text(hora.centroTrabalhoReal ?? '-')),
                DataCell(Text(hora.statusSistema ?? '-')),
                DataCell(Text(_formatDate(hora.inicioReal))),
                DataCell(Text(_formatDate(hora.dataFimReal))),
                DataCell(Text(_formatTime(hora.horaInicioReal))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
