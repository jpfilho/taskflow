import 'package:flutter/material.dart';
import '../../data/models/demanda_model.dart';
import '../../data/services/demanda_service.dart';
import '../widgets/demanda_prazo_helper.dart';
import 'demanda_form_screen.dart';
import 'demanda_detail_screen.dart';

class DemandasScreen extends StatefulWidget {
  const DemandasScreen({super.key});

  @override
  State<DemandasScreen> createState() => _DemandasScreenState();
}

class _DemandasScreenState extends State<DemandasScreen> {
  final DemandaService _demandaService = DemandaService();
  
  List<Demanda> _todasDemandas = [];
  List<Demanda> _demandasFiltradas = [];
  bool _isLoading = false;
  String _erroMsg = '';
  bool _visualizacaoTabela = true; // Visualização padrão em tabela

  // Controllers para filtros de colunas
  final TextEditingController _filtroColLocalController = TextEditingController();
  final TextEditingController _filtroColSalaController = TextEditingController();
  final TextEditingController _filtroColOrigemController = TextEditingController();
  final TextEditingController _filtroColDemandaController = TextEditingController();
  final TextEditingController _filtroColResponsavelController = TextEditingController();
  final TextEditingController _filtroColNotaController = TextEditingController();
  final TextEditingController _filtroColOrdemController = TextEditingController();
  final TextEditingController _filtroColSiController = TextEditingController();
  final TextEditingController _filtroColAtController = TextEditingController();

  // Estatísticas/Contadores
  int _total = 0;
  int _abertas = 0;
  int _emExecucao = 0;
  int _atrasadas = 0;
  int _vencendoHoje = 0;
  int _vencendo7Dias = 0;
  int _aguardando = 0;
  int _concluidas = 0;

  @override
  void initState() {
    super.initState();
    _filtroColLocalController.addListener(_aplicarFiltros);
    _filtroColSalaController.addListener(_aplicarFiltros);
    _filtroColOrigemController.addListener(_aplicarFiltros);
    _filtroColDemandaController.addListener(_aplicarFiltros);
    _filtroColResponsavelController.addListener(_aplicarFiltros);
    _filtroColNotaController.addListener(_aplicarFiltros);
    _filtroColOrdemController.addListener(_aplicarFiltros);
    _filtroColSiController.addListener(_aplicarFiltros);
    _filtroColAtController.addListener(_aplicarFiltros);
    _carregarDados();
  }

  @override
  void dispose() {
    _filtroColLocalController.dispose();
    _filtroColSalaController.dispose();
    _filtroColOrigemController.dispose();
    _filtroColDemandaController.dispose();
    _filtroColResponsavelController.dispose();
    _filtroColNotaController.dispose();
    _filtroColOrdemController.dispose();
    _filtroColSiController.dispose();
    _filtroColAtController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
      _erroMsg = '';
    });

    try {
      // Carregar todas para calcular estatísticas completas offline/online
      final lista = await _demandaService.listarDemandas(limit: 1000);
      setState(() {
        _todasDemandas = lista;
        _calcularEstatisticas();
        _extrairValoresFiltros();
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _erroMsg = 'Erro ao carregar demandas: $e';
        _isLoading = false;
      });
    }
  }

  void _calcularEstatisticas() {
    _total = _todasDemandas.length;
    _abertas = 0;
    _emExecucao = 0;
    _atrasadas = 0;
    _vencendoHoje = 0;
    _vencendo7Dias = 0;
    _aguardando = 0;
    _concluidas = 0;

    for (final d in _todasDemandas) {
      if (d.status == 'Aberta' || d.status == 'Em análise' || d.status == 'Programada') {
        _abertas++;
      } else if (d.status == 'Em execução') {
        _emExecucao++;
      } else if (d.status == 'Aguardando terceiros' || d.status == 'Aguardando material') {
        _aguardando++;
      } else if (d.status == 'Concluída') {
        _concluidas++;
      }

      final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
      if (situacao == SituacaoPrazo.atrasada) {
        _atrasadas++;
      } else if (situacao == SituacaoPrazo.venceHoje) {
        _vencendoHoje++;
      } else if (situacao == SituacaoPrazo.venceEmAte7Dias) {
        _vencendo7Dias++;
      }
    }
  }

  void _extrairValoresFiltros() {
    // Mantido por compatibilidade
  }

  void _aplicarFiltros() {
    setState(() {
      _demandasFiltradas = _todasDemandas.where((d) {
        if (_filtroColLocalController.text.isNotEmpty) {
          if (!d.local.toLowerCase().contains(_filtroColLocalController.text.toLowerCase())) return false;
        }
        if (_filtroColSalaController.text.isNotEmpty) {
          if (!(d.sala ?? '').toLowerCase().contains(_filtroColSalaController.text.toLowerCase())) return false;
        }
        if (_filtroColOrigemController.text.isNotEmpty) {
          if (!d.origem.toLowerCase().contains(_filtroColOrigemController.text.toLowerCase())) return false;
        }
        if (_filtroColDemandaController.text.isNotEmpty) {
          if (!d.demanda.toLowerCase().contains(_filtroColDemandaController.text.toLowerCase())) return false;
        }
        if (_filtroColResponsavelController.text.isNotEmpty) {
          if (!d.responsavel.toLowerCase().contains(_filtroColResponsavelController.text.toLowerCase())) return false;
        }
        if (_filtroColNotaController.text.isNotEmpty) {
          if (!(d.nota ?? '').toLowerCase().contains(_filtroColNotaController.text.toLowerCase())) return false;
        }
        if (_filtroColOrdemController.text.isNotEmpty) {
          if (!(d.ordem ?? '').toLowerCase().contains(_filtroColOrdemController.text.toLowerCase())) return false;
        }
        if (_filtroColSiController.text.isNotEmpty) {
          if (!(d.si ?? '').toLowerCase().contains(_filtroColSiController.text.toLowerCase())) return false;
        }
        if (_filtroColAtController.text.isNotEmpty) {
          if (!(d.at ?? '').toLowerCase().contains(_filtroColAtController.text.toLowerCase())) return false;
        }
        return true;
      }).toList();
    });
  }

  Color _obterCorStatus(String status) {
    switch (status) {
      case 'Aberta':
        return Colors.blue;
      case 'Em análise':
        return Colors.purple;
      case 'Programada':
        return Colors.cyan;
      case 'Em execução':
        return Colors.orange;
      case 'Aguardando terceiros':
      case 'Aguardando material':
        return Colors.amber;
      case 'Concluída':
        return Colors.green;
      case 'Cancelada':
      case 'Suspensa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandas Operacionais', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: _visualizacaoTabela ? 'Ver em Cards' : 'Ver em Tabela',
            icon: Icon(_visualizacaoTabela ? Icons.grid_view : Icons.view_list),
            onPressed: () {
              setState(() {
                _visualizacaoTabela = !_visualizacaoTabela;
              });
            },
          ),
          IconButton(
            tooltip: 'Limpar Filtros',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () {
              setState(() {
                _filtroColLocalController.clear();
                _filtroColSalaController.clear();
                _filtroColOrigemController.clear();
                _filtroColDemandaController.clear();
                _filtroColResponsavelController.clear();
                _filtroColNotaController.clear();
                _filtroColOrdemController.clear();
                _filtroColSiController.clear();
                _filtroColAtController.clear();
                _aplicarFiltros();
              });
            },
          ),
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nova Demanda'),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DemandaFormScreen()),
                );
                if (result == true) {
                  _carregarDados();
                }
              },
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erroMsg.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_erroMsg, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _carregarDados, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: Column(
                    children: [
                      // 3. Grid/Lista de Demandas
                      Expanded(
                        child: _demandasFiltradas.isEmpty
                            ? const Center(child: Text('Nenhuma demanda encontrada.'))
                            : Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _visualizacaoTabela
                                    ? _buildTableView(context)
                                    : GridView.builder(
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: isDesktop ? 3 : 1,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          mainAxisExtent: 220,
                                        ),
                                  itemCount: _demandasFiltradas.length,
                                  itemBuilder: (context, index) {
                                    final d = _demandasFiltradas[index];
                                    final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
                                    final corPrazo = DemandaPrazoHelper.obterCorSituacao(situacao);
                                    final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, d.prazo);

                                    return Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: situacao == SituacaoPrazo.atrasada ? Colors.red.shade300 : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => DemandaDetailScreen(demandaId: d.id),
                                            ),
                                          );
                                          if (result == true) {
                                            _carregarDados();
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _obterCorStatus(d.status).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      d.status,
                                                      style: TextStyle(
                                                        color: _obterCorStatus(d.status),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: corPrazo.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      textoPrazo,
                                                      style: TextStyle(
                                                        color: corPrazo,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Expanded(
                                                child: Text(
                                                  d.demanda,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Divider(height: 16),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      "${d.local} ${d.sala != null && d.sala!.isNotEmpty ? '• ${d.sala}' : ''}",
                                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.person, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        d.responsavel,
                                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.priority_high, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        d.prioridade,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: d.prioridade == 'Crítica' ? Colors.red : Colors.black87,
                                                          fontWeight: d.prioridade == 'Crítica' ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }


  Widget _buildTableView(BuildContext context) {
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            headingRowHeight: 80,
            columns: [
              const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Prazo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: _buildSearchableHeader('Local', _filtroColLocalController)),
              DataColumn(label: _buildSearchableHeader('Sala', _filtroColSalaController)),
              DataColumn(label: _buildSearchableHeader('Origem', _filtroColOrigemController)),
              DataColumn(label: _buildSearchableHeader('Demanda', _filtroColDemandaController)),
              DataColumn(label: _buildSearchableHeader('Responsável', _filtroColResponsavelController)),
              const DataColumn(label: Text('Prioridade', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: _buildSearchableHeader('Nota SAP', _filtroColNotaController)),
              DataColumn(label: _buildSearchableHeader('Ordem SAP', _filtroColOrdemController)),
              DataColumn(label: _buildSearchableHeader('SI', _filtroColSiController)),
              DataColumn(label: _buildSearchableHeader('AT', _filtroColAtController)),
              const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _demandasFiltradas.map((d) {
              final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
              final corPrazo = DemandaPrazoHelper.obterCorSituacao(situacao);
              final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, d.prazo);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _obterCorStatus(d.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        d.status,
                        style: TextStyle(
                          color: _obterCorStatus(d.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      textoPrazo,
                      style: TextStyle(color: corPrazo, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text(d.local)),
                  DataCell(Text(d.sala ?? '-')),
                  DataCell(Text(d.origem)),
                  DataCell(
                    SizedBox(
                      width: 250,
                      child: Text(
                        d.demanda,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(d.responsavel)),
                  DataCell(Text(d.prioridade)),
                  DataCell(Text(d.nota ?? '-')),
                  DataCell(Text(d.ordem ?? '-')),
                  DataCell(Text(d.si ?? '-')),
                  DataCell(Text(d.at ?? '-')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.blue),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DemandaDetailScreen(demandaId: d.id),
                              ),
                            );
                            if (result == true) {
                              _carregarDados();
                            }
                          },
                          tooltip: 'Visualizar',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DemandaFormScreen(demandaExistente: d),
                              ),
                            );
                            if (result == true) {
                              _carregarDados();
                            }
                          },
                          tooltip: 'Editar',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchableHeader(String label, TextEditingController controller) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filtrar...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
