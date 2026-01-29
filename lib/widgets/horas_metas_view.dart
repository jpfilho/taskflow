import 'package:flutter/material.dart';
import '../models/horas_empregado_mes.dart';
import '../services/hora_sap_service.dart';
import 'multi_select_filter_dialog.dart';

class HorasMetasView extends StatefulWidget {
  const HorasMetasView({super.key});

  @override
  State<HorasMetasView> createState() => _HorasMetasViewState();
}

class _HorasMetasViewState extends State<HorasMetasView> {
  final HoraSAPService _service = HoraSAPService();
  List<HorasEmpregadoMes> _dados = [];
  List<HorasEmpregadoMes> _dadosFiltrados = [];
  bool _isLoading = false;
  int _anoSelecionado = DateTime.now().year;
  int? _mesSelecionado = DateTime.now().month;
  Set<String> _filtroEmpregados = {}; // Multi-seleção para empregados
  List<String> _empregadosDisponiveis = []; // Lista de empregados disponíveis

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dados = await _service.getHorasPorEmpregadoMes(
        ano: _anoSelecionado,
        mes: _mesSelecionado,
      );

      if (mounted) {
        setState(() {
          _dados = dados;
          _atualizarEmpregadosDisponiveis();
          // Se houver apenas um empregado disponível, selecioná-lo automaticamente
          if (_filtroEmpregados.isEmpty && _empregadosDisponiveis.length == 1) {
            _filtroEmpregados = {_empregadosDisponiveis.first};
          }
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar dados de metas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _atualizarEmpregadosDisponiveis() {
    final empregadosSet = <String>{};
    for (var dado in _dados) {
      empregadosSet.add('${dado.nomeEmpregado} (${dado.matricula})');
    }
    _empregadosDisponiveis = empregadosSet.toList()..sort();
  }

  void _aplicarFiltros() {
    if (_filtroEmpregados.isEmpty) {
      _dadosFiltrados = _dados;
    } else {
      _dadosFiltrados = _dados.where((dado) {
        final nomeCompleto = '${dado.nomeEmpregado} (${dado.matricula})';
        return _filtroEmpregados.contains(nomeCompleto);
      }).toList();
    }
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return meses[mes - 1];
  }

  Color _getCorStatus(double horasApontadas, double metaMensal, bool semApontamento) {
    if (semApontamento) return Colors.red[600]!;
    if (horasApontadas >= metaMensal) return Colors.green[600]!;
    if (horasApontadas >= metaMensal * 0.75) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  Color _getCorBackgroundStatus(double horasApontadas, double metaMensal, bool semApontamento) {
    if (semApontamento) return Colors.red[50]!;
    if (horasApontadas >= metaMensal) return Colors.green[50]!;
    if (horasApontadas >= metaMensal * 0.75) return Colors.orange[50]!;
    return Colors.red[50]!;
  }

  // Calcular estatísticas gerais
  Map<String, dynamic> _calcularEstatisticas() {
    if (_dadosFiltrados.isEmpty) {
      return {
        'totalColaboradores': 0,
        'horasTotais': 0.0,
        'metasAtingidas': 0,
        'metasPendentes': 0,
        'percentualAtingido': 0.0,
      };
    }

    final colaboradoresUnicos = <String>{};
    double horasTotais = 0;
    int metasAtingidas = 0;
    int total = 0;

    for (var dado in _dadosFiltrados) {
      colaboradoresUnicos.add(dado.matricula);
      horasTotais += dado.horasApontadas;
      total++;
      if (dado.horasApontadas >= dado.metaMensal) {
        metasAtingidas++;
      }
    }

    return {
      'totalColaboradores': colaboradoresUnicos.length,
      'horasTotais': horasTotais,
      'metasAtingidas': metasAtingidas,
      'metasPendentes': total - metasAtingidas,
      'percentualAtingido': total > 0 ? (metasAtingidas / total * 100) : 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final stats = _calcularEstatisticas();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Dashboard Cards no topo
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Título
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dashboard de Horas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.table_chart, color: Colors.blue),
                          onPressed: () {},
                          tooltip: 'Tabela',
                        ),
                        IconButton(
                          icon: const Icon(Icons.show_chart),
                          onPressed: () {},
                          tooltip: 'Metas',
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _carregarDados,
                          tooltip: 'Atualizar',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 3 Cards de estatísticas
                Row(
                  children: [
                    // Card 1: Total de Colaboradores
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total de Colaboradores',
                        value: stats['totalColaboradores'].toString(),
                        subtitle: '+3 desde mês',
                        icon: Icons.people,
                        iconColor: Colors.blue[600]!,
                        backgroundColor: Colors.blue[50]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Card 2: Horas Totais Registradas
                    Expanded(
                      child: _buildStatCard(
                        title: 'Horas Totais Registradas',
                        value: stats['horasTotais'].toStringAsFixed(0),
                        subtitle: 'Metas atingida/colaborador',
                        icon: Icons.access_time,
                        iconColor: Colors.orange[600]!,
                        backgroundColor: Colors.orange[50]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Card 3: Status das Metas (com gráfico)
                    Expanded(
                      child: _buildMetasCard(
                        metasAtingidas: stats['metasAtingidas'],
                        metasPendentes: stats['metasPendentes'],
                        percentual: stats['percentualAtingido'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filtros (estilo Notas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Filtro Ano
                SizedBox(
                  width: isMobile ? 70 : 80,
                  child: DropdownButtonFormField<int>(
                    value: _anoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Ano',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    items: List.generate(5, (index) {
                      final ano = DateTime.now().year - 2 + index;
                      return DropdownMenuItem(
                        value: ano,
                        child: Text(ano.toString(), style: const TextStyle(fontSize: 13)),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _anoSelecionado = value;
                        });
                        _carregarDados();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                // Filtro Mês
                SizedBox(
                  width: isMobile ? 100 : 120,
                  child: DropdownButtonFormField<int?>(
                    value: _mesSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Mês',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos', style: TextStyle(fontSize: 13)),
                      ),
                      ...List.generate(12, (index) {
                        final mes = index + 1;
                        return DropdownMenuItem<int?>(
                          value: mes,
                          child: Text(_getNomeMes(mes), style: const TextStyle(fontSize: 13)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _mesSelecionado = value;
                      });
                      _carregarDados();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                // Filtro Empregado (mesmo estilo de Ano e Mês)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => MultiSelectFilterDialog(
                          title: 'Empregado',
                          options: _empregadosDisponiveis,
                          selectedValues: _filtroEmpregados,
                          onSelectionChanged: (values) {
                            setState(() {
                              _filtroEmpregados = values;
                              _aplicarFiltros();
                            });
                          },
                          searchHint: 'Pesquisar empregado...',
                        ),
                      );
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Empregado',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      child: Text(
                        _filtroEmpregados.isEmpty
                            ? 'Todos'
                            : _filtroEmpregados.length == 1
                                ? _filtroEmpregados.first
                                : '${_filtroEmpregados.length} selecionados',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dadosFiltrados.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum dado encontrado',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : _buildTabelaCompacta(isMobile),
          ),
        ],
      ),
    );
  }


  Widget _buildTabelaCompacta(bool isMobile) {
    // Agrupar dados por empregado (usar dados filtrados)
    final Map<String, List<HorasEmpregadoMes>> dadosPorEmpregado = {};
    for (var dado in _dadosFiltrados) {
      final key = '${dado.nomeEmpregado}_${dado.matricula}';
      dadosPorEmpregado.putIfAbsent(key, () => []);
      dadosPorEmpregado[key]!.add(dado);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 72,
          headingRowColor: MaterialStateProperty.all(Colors.blue[600]),
          columns: [
            DataColumn(
              label: Text(
                'Empregado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Matrícula',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Mês',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Horas Apontadas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Horas Faltantes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
          ],
          rows: dadosPorEmpregado.values.expand((lista) {
            // Ordenar por mês
            lista.sort((a, b) {
              final anoCompare = a.ano.compareTo(b.ano);
              if (anoCompare != 0) return anoCompare;
              return a.mes.compareTo(b.mes);
            });
            return lista;
          }).map((dado) {
            final corStatus = _getCorStatus(dado.horasApontadas, dado.metaMensal, dado.semApontamento);
            final corBackground = _getCorBackgroundStatus(dado.horasApontadas, dado.metaMensal, dado.semApontamento);
            final statusText = dado.semApontamento
                ? 'Sem Apontamento'
                : dado.horasApontadas >= dado.metaMensal
                    ? 'Meta Atingida'
                    : dado.horasApontadas >= dado.metaMensal * 0.75
                        ? 'Em Risco'
                        : 'Abaixo da Meta';

            return DataRow(
              color: MaterialStateProperty.resolveWith((states) {
                if (dado.semApontamento) {
                  return corBackground;
                }
                return null;
              }),
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          dado.nomeEmpregado,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dado.semApontamento ? Colors.red[900] : Colors.black87,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    dado.matricula,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_getNomeMes(dado.mes)}/${dado.ano}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: isMobile ? 140 : 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Total de horas apontadas
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dado.horasApontadas.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: corStatus,
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${dado.metaMensal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Barra de horas programadas (azul) - primeira barra
                        SizedBox(
                          height: 5,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Fundo cinza
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Container(
                                  width: double.infinity,
                                  height: 5,
                                  color: Colors.grey[200],
                                ),
                              ),
                              // Barra de horas programadas (azul) - proporcional às horas programadas
                              if (dado.horasProgramadas > 0)
                                Positioned(
                                  left: 0,
                                  child: SizedBox(
                                    width: ((dado.horasProgramadas / dado.metaMensal).clamp(0.0, 1.0) * (isMobile ? 140 : 180)),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(3),
                                        bottomLeft: const Radius.circular(3),
                                        topRight: dado.horasProgramadas >= dado.metaMensal ? Radius.zero : const Radius.circular(3),
                                        bottomRight: dado.horasProgramadas >= dado.metaMensal ? Radius.zero : const Radius.circular(3),
                                      ),
                                      child: Container(
                                        color: Colors.blue[400],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Barra de horas apontadas (verde/vermelha/laranja) - segunda barra
                        SizedBox(
                          height: 5,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Fundo cinza
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Container(
                                  width: double.infinity,
                                  height: 5,
                                  color: Colors.grey[200],
                                ),
                              ),
                              // Barra de horas normais (até a meta)
                              if (dado.horasApontadas > 0)
                                Positioned(
                                  left: 0,
                                  child: SizedBox(
                                    width: (dado.horasApontadas / dado.metaMensal).clamp(0.0, 1.0) * (isMobile ? 140 : 180),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(3),
                                        bottomLeft: const Radius.circular(3),
                                        topRight: dado.horasApontadas >= dado.metaMensal ? Radius.zero : const Radius.circular(3),
                                        bottomRight: dado.horasApontadas >= dado.metaMensal ? Radius.zero : const Radius.circular(3),
                                      ),
                                      child: Container(
                                        color: corStatus,
                                      ),
                                    ),
                                  ),
                                ),
                              // Barra de horas extras (HHE) em laranja, continuando após as horas normais
                              if (dado.horasExtras > 0)
                                Positioned(
                                  left: (dado.horasApontadas / dado.metaMensal).clamp(0.0, 1.0) * (isMobile ? 140 : 180),
                                  child: SizedBox(
                                    width: (dado.horasExtras / dado.metaMensal).clamp(0.0, 1.0) * (isMobile ? 140 : 180),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topRight: const Radius.circular(3),
                                        bottomRight: const Radius.circular(3),
                                        topLeft: dado.horasApontadas >= dado.metaMensal ? const Radius.circular(3) : Radius.zero,
                                        bottomLeft: dado.horasApontadas >= dado.metaMensal ? const Radius.circular(3) : Radius.zero,
                                      ),
                                      child: Container(
                                        color: Colors.orange[600],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Informações de horas programadas e extras em linha única compacta
                        if (dado.horasProgramadas > 0 || dado.horasExtras > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                if (dado.horasProgramadas > 0)
                                  Text(
                                    'Prog: ${dado.horasProgramadas.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 9 : 10,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (dado.horasExtras > 0)
                                  Text(
                                    'HHE: ${dado.horasExtras.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 9 : 10,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dado.horasFaltantes > 0 ? Icons.trending_down : Icons.check_circle,
                        size: 16,
                        color: dado.horasFaltantes > 0 ? Colors.orange[700] : Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dado.horasFaltantes.toStringAsFixed(2),
                        style: TextStyle(
                          color: dado.horasFaltantes > 0 ? Colors.orange[700] : Colors.green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: corStatus.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: corStatus, width: 1.5),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: corStatus,
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // Widget para Card de Estatística
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para Card de Metas com gráfico circular
  Widget _buildMetasCard({
    required int metasAtingidas,
    required int metasPendentes,
    required double percentual,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status das Metas',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Gráfico circular
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: percentual / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentual >= 80
                              ? Colors.green[600]!
                              : percentual >= 50
                                  ? Colors.orange[600]!
                                  : Colors.red[600]!,
                        ),
                      ),
                    ),
                    Text(
                      '${percentual.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legenda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Atingido ($metasAtingidas)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pendente ($metasPendentes)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
