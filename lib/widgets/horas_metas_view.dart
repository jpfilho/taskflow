import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../models/horas_empregado_mes.dart';
import '../models/ordem_programada_empregado_mes.dart';
import '../models/horas_apontadas_ordem_mes.dart';
import '../services/hora_sap_service.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import 'multi_select_filter_dialog.dart';
import 'task_view_dialog.dart';
import 'confirmacao_form_dialog.dart';
import '../models/confirmacao.dart';

// Axia Design System tokens (cores principais)
class DSColors {
  static const Color blue = Color(0xFF0000FF); // Primary Blue
  static const Color blue1 = Color(0xFF1726C8); // Blue 1
  static const Color sky = Color(0xFFA0B4D2);
  static const Color purple = Color(0xFF0A003C);
  static const Color grey1 = Color(0xFF1A1F25);
  static const Color neutral = Color(0xFFE8E5E3);
  static const Color offwhite = Color(0xFFFAF5F0);
  static const Color success = Color(0xFF43B75D);
  static const Color warning = Color(0xFFFFAA00);
  static const Color error = Color(0xFFEE443F);
}

class HorasMetasView extends StatefulWidget {
  final VoidCallback? onRefresh;
  const HorasMetasView({super.key, this.onRefresh});

  @override
  State<HorasMetasView> createState() => _HorasMetasViewState();
}

class _HorasMetasViewState extends State<HorasMetasView> {
  final HoraSAPService _service = HoraSAPService();
  String _horaAgoraStr() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Normaliza a matrícula para comparações/agrupamentos consistentes
  /// Atualmente apenas `trim`, mantendo o formato vindo do backend.
  /// Ajuste aqui se for necessário remover zeros à esquerda ou caracteres.
  String _normMat(String value) {
    return value.trim();
  }

  /// Formata número com separador de milhar (ponto), ex.: 3120 -> "3.120"
  static String _fmtMilhar(num value, [int decimals = 0]) {
    final str = value.toStringAsFixed(decimals);
    if (decimals > 0) {
      final parts = str.split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      return '$intPart,$parts[1]';
    }
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  List<HorasEmpregadoMes> _dados = [];
  List<HorasEmpregadoMes> _dadosFiltrados = [];
  bool _isLoading = false;
  int _anoSelecionado = DateTime.now().year;
  Set<int> _mesesSelecionados = {DateTime.now().month};

  // ... (inside initState or wherever appropriate, though initialization is done at declaration)

  Widget _buildMesesFilter() {
    final meses = [
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
    final options = List.generate(12, (i) => '${i + 1} - ${meses[i]}');
    final selectedValues = _mesesSelecionados
        .map((m) => '$m - ${meses[m - 1]}')
        .toSet();

    return GestureDetector(
      onTap: () async {
        final newSelection = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => MultiSelectFilterDialog(
            title: 'Selecionar Meses',
            options: options,
            selectedValues: selectedValues,
            onSelectionChanged: (values) {
              setState(() {
                _mesesSelecionados = values
                    .map((v) => int.parse(v.split(' - ')[0]))
                    .toSet();
              });
              _carregarDados();
            },
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 40,
        ), // Match year dropdown height
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50], // Match other inputs
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[700]!,
          ), // Standard InputBorder default color
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _mesesSelecionados.isEmpty
                    ? 'Nenhum'
                    : _mesesSelecionados.length == 12
                    ? 'Todos'
                    : _mesesSelecionados.length > 2
                    ? '${_mesesSelecionados.length} meses'
                    : _mesesSelecionados
                          .map((m) => meses[m - 1].substring(0, 3))
                          .join(', '),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Set<String> _filtroEmpregados = {}; // Multi-seleção para empregados
  List<String> _empregadosDisponiveis = []; // Lista de empregados disponíveis
  Map<String, double>?
  _horasPorDiaChart; // Horas alocadas por dia (data_lancamento) para o gráfico

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar ano inteiro para o gráfico acumulado mês a mês; filtro por mês é aplicado na exibição
      final dados = await _service.getHorasPorEmpregadoMes(
        ano: _anoSelecionado,
        mes: null,
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
        if (_mesesSelecionados.isEmpty && mounted) {
          setState(() => _horasPorDiaChart = null);
        } else {
          _carregarGraficoMetas();
        }
      }
    } catch (e) {
      print('❌ Erro ao carregar dados de metas: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  /// Dados dos meses selecionados (para cards, tabela e gráfico diário).
  List<HorasEmpregadoMes> get _dadosDoMesSelecionado {
    if (_mesesSelecionados.isEmpty) return [];
    return _dadosFiltrados
        .where(
          (d) => d.ano == _anoSelecionado && _mesesSelecionados.contains(d.mes),
        )
        .toList();
  }

  /// Dias úteis no mês (segunda a sexta).
  static int _diasUteisNoMes(int ano, int mes) {
    final lastDay = DateTime(ano, mes + 1, 0).day;
    int count = 0;
    for (int d = 1; d <= lastDay; d++) {
      final dt = DateTime(ano, mes, d);
      if (dt.weekday >= DateTime.monday && dt.weekday <= DateTime.friday) {
        count++;
      }
    }
    return count;
  }

  /// Dias úteis do dia 1 até [dia] (inclusive) no mês.
  static int _diasUteisAteDia(int ano, int mes, int dia) {
    int count = 0;
    for (int d = 1; d <= dia; d++) {
      final dt = DateTime(ano, mes, d);
      if (dt.weekday >= DateTime.monday && dt.weekday <= DateTime.friday) {
        count++;
      }
    }
    return count;
  }

  /// Dados para a tabela de metas: meses selecionados + linhas para quem não alocou nada ainda.
  List<HorasEmpregadoMes> get _dadosTabelaMetas {
    final doMes = _dadosDoMesSelecionado;
    if (_mesesSelecionados.isEmpty) return doMes;
    // Criar linhas para cada mês selecionado para quem não tem apontamento
    final matriculasPorMes = <int, Set<String>>{};
    for (var m in _mesesSelecionados) {
      matriculasPorMes[m] = <String>{};
    }
    for (var d in doMes) {
      matriculasPorMes[d.mes]?.add(_normMat(d.matricula));
    }

    final mapaEmpregado = <String, String>{};
    for (var d in _dadosFiltrados) {
      mapaEmpregado[_normMat(d.matricula)] = d.nomeEmpregado;
    }

    final resultado = List<HorasEmpregadoMes>.from(doMes);
    for (var mes in _mesesSelecionados) {
      final metaMensal = (_diasUteisNoMes(_anoSelecionado, mes) * 8.0).clamp(
        8.0,
        250.0,
      );
      for (var entry in mapaEmpregado.entries) {
        if (matriculasPorMes[mes]?.contains(entry.key) == true) continue;
        resultado.add(
          HorasEmpregadoMes(
            numeroPessoa: entry.key,
            nomeEmpregado: entry.value,
            matricula: entry.key,
            ano: _anoSelecionado,
            mes: mes,
            horasApontadas: 0,
            horasFaltantes: metaMensal,
            semApontamento: true,
            metaMensal: metaMensal,
          ),
        );
      }
    }
    resultado.sort((a, b) {
      final nome = a.nomeEmpregado.compareTo(b.nomeEmpregado);
      if (nome != 0) return nome;
      return a.mes.compareTo(b.mes);
    });
    return resultado;
  }

  String _formatMesesLabel(Set<int> meses) {
    if (meses.isEmpty) return '—';
    final ordered = meses.toList()..sort();
    final abbr = ordered.map((m) => _getNomeMes(m).substring(0, 3)).toList();
    if (abbr.length <= 3) return abbr.join(', ');
    return '${abbr.first}–${abbr.last}';
  }

  /// Gera dados para um conjunto arbitrário de meses do ano selecionado, incluindo linhas
  /// sintéticas para colaboradores que não possuem apontamentos nesses meses.
  List<HorasEmpregadoMes> _dadosParaMeses(Set<int> meses) {
    if (meses.isEmpty) return [];
    final doMes = _dadosFiltrados
        .where((d) => d.ano == _anoSelecionado && meses.contains(d.mes))
        .toList();

    // Mapa de matrículas presentes por mês
    final matriculasPorMes = <int, Set<String>>{
      for (var m in meses) m: <String>{},
    };
    for (var d in doMes) {
      matriculasPorMes[d.mes]!.add(_normMat(d.matricula));
    }

    // Todos os colaboradores visíveis pelo filtro atual
    final mapaEmpregado = <String, String>{};
    for (var d in _dadosFiltrados) {
      mapaEmpregado[_normMat(d.matricula)] = d.nomeEmpregado;
    }

    final resultado = List<HorasEmpregadoMes>.from(doMes);
    for (var mes in meses) {
      final metaMensal = (_diasUteisNoMes(_anoSelecionado, mes) * 8.0).clamp(
        8.0,
        250.0,
      );
      for (var entry in mapaEmpregado.entries) {
        if (matriculasPorMes[mes]!.contains(entry.key)) continue;
        resultado.add(
          HorasEmpregadoMes(
            numeroPessoa: entry.key,
            nomeEmpregado: entry.value,
            matricula: entry.key,
            ano: _anoSelecionado,
            mes: mes,
            horasApontadas: 0,
            horasFaltantes: metaMensal,
            semApontamento: true,
            metaMensal: metaMensal,
          ),
        );
      }
    }
    resultado.sort((a, b) {
      final nome = a.nomeEmpregado.compareTo(b.nomeEmpregado);
      if (nome != 0) return nome;
      return a.mes.compareTo(b.mes);
    });
    return resultado;
  }

  /// Calcula estatísticas agregadas para um conjunto arbitrário de meses.
  Map<String, dynamic> _calcularEstatisticasParaMeses(Set<int> meses) {
    final dadosMes = _dadosParaMeses(meses);
    if (dadosMes.isEmpty) {
      return {
        'totalColaboradores': 0,
        'horasTotais': 0.0,
        'metaTotalMes': 0.0,
        'percentualAlocado': 0.0,
        'metasAtingidas': 0,
        'metasPendentes': 0,
        'percentualAtingido': 0.0,
        'horasInvestimento': 0.0,
        'horasCusteio': 0.0,
        'progInvestimento': 0.0,
        'progCusteio': 0.0,
        'percentualInvestimento': 0.0,
        'horasAteHoje': 0.0,
        'metaAteHoje': 0.0,
        'percentualFeitoAteHoje': 0.0,
        'percentualDeveriaAteHoje': 0.0,
      };
    }

    final colaboradoresUnicos = <String>{};
    double horasTotais = 0;
    double metaTotalMes = 0;
    double horasInvestimento = 0;
    double horasCusteio = 0;
    double progInvestimento = 0;
    double progCusteio = 0;
    int metasAtingidas = 0;
    int total = 0;

    for (var dado in dadosMes) {
      colaboradoresUnicos.add(dado.matricula);
      horasTotais += dado.horasApontadas;
      metaTotalMes += dado.metaMensal;
      horasInvestimento += dado.horasInvestimento;
      horasCusteio += dado.horasCusteio;
      progInvestimento += dado.horasProgramadasInvestimento;
      progCusteio += dado.horasProgramadasCusteio;
      total++;
      if (dado.horasApontadas >= dado.metaMensal) metasAtingidas++;
    }

    final totalCustInvest = horasInvestimento + horasCusteio;
    final percentualInvestimento = totalCustInvest > 0
        ? (horasInvestimento / totalCustInvest * 100)
        : 0.0;
    final percentualAlocado = metaTotalMes > 0
        ? (horasTotais / metaTotalMes * 100)
        : 0.0;

    // Até hoje (para os meses informados)
    double horasAteHoje = 0.0;
    double metaAteHoje = 0.0;
    double percentualFeitoAteHoje = 0.0;
    double percentualDeveriaAteHoje = 0.0;
    if (meses.isNotEmpty) {
      final ano = _anoSelecionado;
      final agora = DateTime.now();
      for (var mes in meses) {
        final diasUteisMes = _diasUteisNoMes(ano, mes);
        double metaDesteMesTodosColaboradores = 0.0;
        double horasRealizadasDesteMesTodos = 0.0;
        for (var d in dadosMes.where((d) => d.mes == mes)) {
          metaDesteMesTodosColaboradores += d.metaMensal;
          horasRealizadasDesteMesTodos += d.horasApontadas;
        }
        final isPassado =
            ano < agora.year || (ano == agora.year && mes < agora.month);
        final isFuturo =
            ano > agora.year || (ano == agora.year && mes > agora.month);
        final isAtual = (ano == agora.year && mes == agora.month);
        if (isPassado) {
          horasAteHoje += horasRealizadasDesteMesTodos;
          metaAteHoje += metaDesteMesTodosColaboradores;
        } else if (isAtual) {
          final diaHoje = agora.day;
          horasAteHoje += horasRealizadasDesteMesTodos;
          final diasUteisAteHoje = _diasUteisAteDia(ano, mes, diaHoje);
          if (diasUteisMes > 0) {
            metaAteHoje +=
                (diasUteisAteHoje / diasUteisMes) *
                metaDesteMesTodosColaboradores;
          }
        } else if (isFuturo) {
          // nada
        }
      }
      if (metaAteHoje > 0) {
        percentualFeitoAteHoje = (horasAteHoje / metaAteHoje) * 100;
        percentualDeveriaAteHoje = (metaAteHoje / metaTotalMes) * 100;
      }
    }

    return {
      'totalColaboradores': colaboradoresUnicos.length,
      'horasTotais': horasTotais,
      'metaTotalMes': metaTotalMes,
      'percentualAlocado': percentualAlocado,
      'metasAtingidas': metasAtingidas,
      'metasPendentes': total - metasAtingidas,
      'percentualAtingido': total > 0 ? (metasAtingidas / total * 100) : 0.0,
      'horasInvestimento': horasInvestimento,
      'horasCusteio': horasCusteio,
      'progInvestimento': progInvestimento,
      'progCusteio': progCusteio,
      'percentualInvestimento': percentualInvestimento,
      'horasAteHoje': horasAteHoje,
      'metaAteHoje': metaAteHoje,
      'percentualFeitoAteHoje': percentualFeitoAteHoje,
      'percentualDeveriaAteHoje': percentualDeveriaAteHoje,
    };
  }

  Future<void> _carregarGraficoMetas() async {
    if (_mesesSelecionados.isEmpty) {
      if (mounted) setState(() => _horasPorDiaChart = null);
      return;
    }

    final matriculas = _dadosDoMesSelecionado
        .map((d) => d.matricula)
        .toSet()
        .toList();
    if (matriculas.isEmpty) {
      if (mounted) setState(() => _horasPorDiaChart = null);
      return;
    }

    // Carregar dados para todos os meses selecionados e agregar
    final Map<String, double> porDiaAgregado = {};

    for (var mes in _mesesSelecionados) {
      final porDiaMes = await _service.getHorasAlocadasPorDiaNoMes(
        _anoSelecionado,
        mes,
        matriculas,
      );

      // Agregar os dados por dia
      porDiaMes.forEach((data, horas) {
        porDiaAgregado[data] = (porDiaAgregado[data] ?? 0.0) + horas;
      });
    }

    if (mounted) setState(() => _horasPorDiaChart = porDiaAgregado);
  }

  /// Abre o dialog com ordens programadas e horas apontadas por ordem (e ordens não programadas).
  Future<void> _mostrarOrdensEmpregadoMes(HorasEmpregadoMes dado) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    List<OrdemProgramadaEmpregadoMes> ordensProgramadas = [];
    List<HorasApontadasOrdemMes> horasPorOrdem = [];
    try {
      ordensProgramadas = await _service.getOrdensProgramadasPorEmpregadoMes(
        ano: dado.ano,
        mes: dado.mes,
        matriculas: [dado.matricula],
      );
      horasPorOrdem = await _service.getHorasApontadasPorEmpregadoOrdemMes(
        ano: dado.ano,
        mes: dado.mes,
        matriculas: [dado.matricula],
      );
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
    if (!mounted) return;

    final setOrdensProgramadas = ordensProgramadas.map((o) => o.ordem).toSet();
    final mapHorasPorOrdem = <String, double>{};
    for (var h in horasPorOrdem) {
      mapHorasPorOrdem[h.ordem] =
          (mapHorasPorOrdem[h.ordem] ?? 0) + h.horasApontadas;
    }
    final ordensNaoProgramadas =
        mapHorasPorOrdem.keys
            .where((ordem) => !setOrdensProgramadas.contains(ordem))
            .toList()
          ..sort();
    Map<String, Map<String, String?>> mapDetalhesNaoProgramadas = {};
    if (ordensNaoProgramadas.isNotEmpty) {
      mapDetalhesNaoProgramadas = await _service.getDetalhesOrdensByNumeros(
        ordensNaoProgramadas,
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        final selecionadas = <String>{};
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isMobile = Responsive.isMobile(context);
        final isTablet = Responsive.isTablet(context);
        // Largura maior e responsiva: mobile quase tela cheia, tablet 92%, desktop até 1400px
        final dialogWidth = isMobile
            ? (screenWidth * 0.96).clamp(320.0, screenWidth)
            : isTablet
            ? (screenWidth * 0.92).clamp(500.0, screenWidth)
            : (screenWidth * 0.85).clamp(800.0, 1400.0);
        final maxContentHeight = (screenHeight * 0.75).clamp(400.0, 800.0);
        final colSel = isMobile ? 36.0 : 40.0;
        final colTipo = isMobile ? 44.0 : 52.0;
        final colOrdem = isMobile ? 82.0 : 100.0;
        final colSala = isMobile ? 44.0 : 52.0;
        final colLocal = isMobile ? 60.0 : 90.0;
        final colTarefa = isMobile ? 100.0 : 140.0;
        final colStatus = isMobile ? 44.0 : 52.0;
        const colHoras = 48.0;
        final colTextoBreve = isMobile
            ? (dialogWidth -
                      colTipo -
                      colOrdem -
                      colSala -
                      colLocal -
                      colTarefa -
                      colStatus -
                      colHoras -
                      48)
                  .clamp(100.0, 280.0)
            : (isTablet ? 200.0 : 280.0);
        return Dialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 24 : 48,
          ),
          child: SizedBox(
            width: dialogWidth,
            height: maxContentHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ordens — ${dado.nomeEmpregado}',
                          style: TextStyle(fontSize: isMobile ? 16 : 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getNomeMes(dado.mes)}/${dado.ano}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ordens programadas (atribuídas nas tarefas)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (ordensProgramadas.isEmpty)
                          Text(
                            'Nenhuma ordem programada.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        else
                          StatefulBuilder(
                            builder: (context, setStateDialog) =>
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Table(
                                    columnWidths: {
                                      0: FixedColumnWidth(colSel),
                                      1: FixedColumnWidth(colTipo),
                                      2: FixedColumnWidth(colOrdem),
                                      3: FixedColumnWidth(colSala),
                                      4: FixedColumnWidth(
                                        colTextoBreve > 0 ? colTextoBreve : 180,
                                      ),
                                      5: FixedColumnWidth(colLocal),
                                      6: FixedColumnWidth(colTarefa),
                                      7: FixedColumnWidth(colStatus),
                                      8: FixedColumnWidth(colHoras),
                                    },
                                    border: TableBorder.all(
                                      color: Colors.grey.shade300,
                                      width: 0.5,
                                    ),
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                        ),
                                        children: [
                                          _tableCell('Sel.', isHeader: true),
                                          _tableCell('Tipo', isHeader: true),
                                          _tableCell('Ordem', isHeader: true),
                                          _tableCell('Sala', isHeader: true),
                                          _tableCell(
                                            'Texto breve',
                                            isHeader: true,
                                          ),
                                          _tableCell('Local', isHeader: true),
                                          _tableCell('Tarefa', isHeader: true),
                                          _tableCell('Status', isHeader: true),
                                          _tableCell('Horas', isHeader: true),
                                        ],
                                      ),
                                      ...ordensProgramadas.map((dados) {
                                        final horas =
                                            mapHorasPorOrdem[dados.ordem] ??
                                            0.0;
                                        final status = (dados.taskStatus ?? '')
                                            .toUpperCase()
                                            .trim();
                                        final statusBg =
                                            _corFundoStatusPorStatus(
                                              status,
                                              horas,
                                            );
                                        final concSemAlocacao =
                                            status.contains('CONC') &&
                                            horas == 0;
                                        return TableRow(
                                          decoration: concSemAlocacao
                                              ? BoxDecoration(
                                                  color: Colors.red.shade50,
                                                )
                                              : null,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 6,
                                                  ),
                                              child: Checkbox(
                                                value: selecionadas.contains(
                                                  dados.ordem,
                                                ),
                                                onChanged: (v) {
                                                  setStateDialog(() {
                                                    if (v == true) {
                                                      selecionadas.add(
                                                        dados.ordem,
                                                      );
                                                    } else {
                                                      selecionadas.remove(
                                                        dados.ordem,
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            _tableCell(dados.tipo ?? '-'),
                                            _tableCell(dados.ordem),
                                            _tableCell(dados.sala ?? '-'),
                                            _tableCell(dados.textoBreve ?? '-'),
                                            _tableCell(
                                              dados.localDetalhe ?? '-',
                                            ),
                                            _tableCellTarefaLink(
                                              tarefa: dados.taskTarefa ?? '-',
                                              taskId: dados.taskId,
                                              onTap:
                                                  dados.taskId != null &&
                                                      dados.taskId!.isNotEmpty
                                                  ? () => _navegarParaTarefa(
                                                      context,
                                                      dados.taskId!,
                                                    )
                                                  : null,
                                            ),
                                            _tableCell(
                                              dados.taskStatus ?? '-',
                                              backgroundColor: statusBg,
                                            ),
                                            _tableCell(
                                              horas.toStringAsFixed(1),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ordens não programadas (apontou mas não estava na tarefa)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (ordensNaoProgramadas.isEmpty)
                          Text(
                            'Nenhuma.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Table(
                              columnWidths: {
                                0: FixedColumnWidth(colTipo),
                                1: FixedColumnWidth(colOrdem),
                                2: FixedColumnWidth(colSala),
                                3: FixedColumnWidth(colLocal),
                                4: FixedColumnWidth(
                                  colTextoBreve > 0 ? colTextoBreve : 200,
                                ),
                                5: FixedColumnWidth(colHoras),
                              },
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                                width: 0.5,
                              ),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                  ),
                                  children: [
                                    _tableCell('Tipo', isHeader: true),
                                    _tableCell('Ordem', isHeader: true),
                                    _tableCell('Sala', isHeader: true),
                                    _tableCell('Local', isHeader: true),
                                    _tableCell('Texto breve', isHeader: true),
                                    _tableCell('Horas', isHeader: true),
                                  ],
                                ),
                                ...ordensNaoProgramadas.map((ordem) {
                                  final horas = mapHorasPorOrdem[ordem] ?? 0.0;
                                  final det = mapDetalhesNaoProgramadas[ordem];
                                  return TableRow(
                                    children: [
                                      _tableCell(
                                        det?['tipo'] ?? '-',
                                        isOrange: true,
                                      ),
                                      _tableCell(ordem, isOrange: true),
                                      _tableCell(
                                        det?['sala'] ?? '-',
                                        isOrange: true,
                                      ),
                                      _tableCell(
                                        det?['local'] ?? '-',
                                        isOrange: true,
                                      ),
                                      _tableCell(
                                        det?['texto_breve'] ?? '-',
                                        isOrange: true,
                                      ),
                                      _tableCell(
                                        horas.toStringAsFixed(1),
                                        isOrange: true,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Adicionar Confirmação para ordens selecionadas
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (selecionadas.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecione uma ordem programada para confirmar',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          final ordem = selecionadas.first;
                          final conf = Confirmacao(
                            id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                            ordem: ordem,
                            nPessoal: dado.matricula,
                            nomes: dado.nomeEmpregado,
                            dataLancamento: DateTime.now(),
                            unid: 'H',
                          );
                          await showDialog(
                            context: context,
                            builder: (_) =>
                                ConfirmacaoFormDialog(confirmacao: conf),
                          );
                        },
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('Adicionar Confirmação'),
                      ),
                      const SizedBox(width: 8),
                      // Botão para abrir o Design System (HTML bundle em assets/ds)
                      TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.base.resolve(
                            'assets/ds/design-system.html',
                          );
                          await launchUrl(uri, webOnlyWindowName: '_blank');
                        },
                        icon: const Icon(Icons.style, size: 18),
                        label: const Text('Design System'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Cor de fundo da célula Status conforme cadastro: CONC+h>0 verde, PROG azul, ANDA laranja.
  Color? _corFundoStatusPorStatus(String status, double horas) {
    if (status.contains('CONC')) {
      return horas > 0 ? Colors.green.shade50 : null;
    }
    if (status.contains('PROG')) return Colors.blue.shade50;
    if (status.contains('ANDA')) return Colors.orange.shade50;
    return null;
  }

  Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isGreen = false,
    bool isOrange = false,
    Color? backgroundColor,
  }) {
    Color? textColor;
    if (isHeader) {
      textColor = Colors.grey[800];
    } else if (isGreen)
      textColor = Colors.green[700];
    else if (isOrange)
      textColor = Colors.orange[800];
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: textColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: isHeader ? 1 : 2,
      ),
    );
    if (backgroundColor != null) {
      return Container(color: backgroundColor, child: content);
    }
    return content;
  }

  Widget _tableCellTarefaLink({
    required String tarefa,
    required String? taskId,
    VoidCallback? onTap,
  }) {
    final isLink = onTap != null && (taskId ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: isLink
          ? InkWell(
              onTap: onTap,
              child: Text(
                tarefa,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.blue[700],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            )
          : Text(
              tarefa,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
    );
  }

  Future<void> _navegarParaTarefa(BuildContext context, String taskId) async {
    try {
      final taskService = TaskService();
      final task = await taskService.getTaskById(taskId);
      if (task != null && context.mounted) {
        Navigator.of(context).pop(); // fecha o diálogo de Ordens
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => TaskViewDialog(task: task),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarefa não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Color _getCorStatus(
    double horasApontadas,
    double metaMensal,
    bool semApontamento,
  ) {
    if (semApontamento) return DSColors.error;
    if (horasApontadas >= metaMensal) return DSColors.success;
    if (horasApontadas >= metaMensal * 0.75) return DSColors.warning;
    return DSColors.error;
  }

  Color _getCorBackgroundStatus(
    double horasApontadas,
    double metaMensal,
    bool semApontamento,
  ) {
    if (semApontamento) return DSColors.error.withValues(alpha: 0.08);
    if (horasApontadas >= metaMensal) {
      return DSColors.success.withValues(alpha: 0.08);
    }
    if (horasApontadas >= metaMensal * 0.75) {
      return DSColors.warning.withValues(alpha: 0.08);
    }
    return DSColors.error.withValues(alpha: 0.08);
  }

  // Calcular estatísticas gerais (mês selecionado + quem não alocou horas)
  Map<String, dynamic> _calcularEstatisticas() {
    final dadosMes = _dadosTabelaMetas;
    if (dadosMes.isEmpty) {
      return {
        'totalColaboradores': 0,
        'horasTotais': 0.0,
        'metaTotalMes': 0.0,
        'percentualAlocado': 0.0,
        'metasAtingidas': 0,
        'metasPendentes': 0,
        'percentualAtingido': 0.0,
        'horasInvestimento': 0.0,
        'horasCusteio': 0.0,
        'progInvestimento': 0.0,
        'progCusteio': 0.0,
        'percentualInvestimento': 0.0,
        'horasAteHoje': 0.0,
        'metaAteHoje': 0.0,
        'percentualFeitoAteHoje': 0.0,
        'percentualDeveriaAteHoje': 0.0,
      };
    }

    final colaboradoresUnicos = <String>{};
    double horasTotais = 0;
    double metaTotalMes = 0;
    double horasInvestimento = 0;
    double horasCusteio = 0;
    double progInvestimento = 0;
    double progCusteio = 0;
    int metasAtingidas = 0;
    int total = 0;

    for (var dado in dadosMes) {
      colaboradoresUnicos.add(dado.matricula);
      horasTotais += dado.horasApontadas;
      metaTotalMes += dado.metaMensal;
      horasInvestimento += dado.horasInvestimento;
      horasCusteio += dado.horasCusteio;
      progInvestimento += dado.horasProgramadasInvestimento;
      progCusteio += dado.horasProgramadasCusteio;
      total++;
      if (dado.horasApontadas >= dado.metaMensal) {
        metasAtingidas++;
      }
    }

    final totalCustInvest = horasInvestimento + horasCusteio;
    final percentualInvestimento = totalCustInvest > 0
        ? (horasInvestimento / totalCustInvest * 100)
        : 0.0;
    final percentualAlocado = metaTotalMes > 0
        ? (horasTotais / metaTotalMes * 100)
        : 0.0;

    // Até hoje (considerando todos os meses selecionados):
    // Se hoje estiver dentro de um dos meses selecionados, consideramos até hoje.
    // Se um mês selecionado já passou, consideramos ele inteiro.
    // Se um mês selecionado é futuro, consideramos 0.
    double horasAteHoje = 0.0;
    double metaAteHoje = 0.0;
    double percentualFeitoAteHoje = 0.0;
    double percentualDeveriaAteHoje = 0.0;

    if (_mesesSelecionados.isNotEmpty) {
      final ano = _anoSelecionado;
      final agora = DateTime.now();

      // Para o cálculo "Até Hoje", precisamos somar o realizado e a meta proporcional de cada mês selecionado
      for (var mes in _mesesSelecionados) {
        final lastDay = DateTime(ano, mes + 1, 0).day;
        final diasUteisMes = _diasUteisNoMes(ano, mes);
        final metaMesTotal = (diasUteisMes * 8.0).clamp(
          8.0,
          250.0,
        ); // estimativa, ou pegar da soma dos colaboradores?
        // A _dadosTabelaMetas já tem a meta individual. Podemos somar a meta de todos colaboradores neste mês?
        // Mas "metaAteHoje" é geralmente comparativo global.
        // Vamos usar a soma das metas dos colaboradores neste mês como base.
        double metaDesteMesTodosColaboradores = 0.0;
        double horasRealizadasDesteMesTodos = 0.0;

        final doMes = dadosMes.where((d) => d.mes == mes);
        for (var d in doMes) {
          metaDesteMesTodosColaboradores += d.metaMensal;
          horasRealizadasDesteMesTodos += d.horasApontadas;
        }

        // Se ano/mes for passado
        bool isPassado =
            ano < agora.year || (ano == agora.year && mes < agora.month);
        bool isFuturo =
            ano > agora.year || (ano == agora.year && mes > agora.month);
        bool isAtual = (ano == agora.year && mes == agora.month);

        if (isPassado) {
          // Considera tudo
          horasAteHoje += horasRealizadasDesteMesTodos;
          metaAteHoje += metaDesteMesTodosColaboradores;
        } else if (isFuturo) {
          // Considera nada para "até hoje" (meta acumulada não inclui futuro)
          // Mas horas realizadas futuras contam? Geralmente não tem.
          // Manter 0.
        } else if (isAtual) {
          // Mês atual: proporcional
          final diaHoje = agora.day;
          // Horas realizadas até hoje no mês atual:
          // Precisamos do _horasPorDiaChart. Mas ele só é carregado se tiver 1 mês selecionado.
          // Se tiver múltiplos meses e um deles é o atual, o _horasPorDiaChart pode estar null.
          // Fallback: usar horas totais do mês se não tiver chart? Não, "até hoje" implica parcial.
          // Se não temos detalhe dia-a-dia, assumimos que tudo apontado no mês é "até hoje"? Pode ser, já que não se aponta futuro.
          horasAteHoje += horasRealizadasDesteMesTodos;

          // Meta proporcional
          final diasUteisAteHoje = _diasUteisAteDia(ano, mes, diaHoje);
          if (diasUteisMes > 0) {
            metaAteHoje +=
                (diasUteisAteHoje / diasUteisMes) *
                metaDesteMesTodosColaboradores;
          }
        }
      }

      if (metaAteHoje > 0) {
        percentualFeitoAteHoje = (horasAteHoje / metaAteHoje) * 100;
        // Percentual deveria: se selecionou meses passados + atual, quanto do total "deveria" ter feito?
        // É complexo com múltiplos meses. simplificação:
        // Comparar metaAteHoje com metaTotalMes (que é a soma de todos os meses selecionados)
        percentualDeveriaAteHoje = (metaAteHoje / metaTotalMes) * 100;
      }
    }

    return {
      'totalColaboradores': colaboradoresUnicos.length,
      'horasTotais': horasTotais,
      'metaTotalMes': metaTotalMes,
      'percentualAlocado': percentualAlocado,
      'metasAtingidas': metasAtingidas,
      'metasPendentes': total - metasAtingidas,
      'percentualAtingido': total > 0 ? (metasAtingidas / total * 100) : 0.0,
      'horasInvestimento': horasInvestimento,
      'horasCusteio': horasCusteio,
      'progInvestimento': progInvestimento,
      'progCusteio': progCusteio,
      'percentualInvestimento': percentualInvestimento,
      'horasAteHoje': horasAteHoje,
      'metaAteHoje': metaAteHoje,
      'percentualFeitoAteHoje': percentualFeitoAteHoje,
      'percentualDeveriaAteHoje': percentualDeveriaAteHoje,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final now = DateTime.now();
    final Set<int> monthsAno = _anoSelecionado == now.year
        ? {for (var m = 1; m <= now.month; m++) m}
        : {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    final statsMes = _calcularEstatisticasParaMeses(_mesesSelecionados);
    final statsAno = _calcularEstatisticasParaMeses(monthsAno);
    final String scopeLabelAno = _anoSelecionado.toString();
    final String scopeLabelMeses = _formatMesesLabel(_mesesSelecionados);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          primary: true,
          child: Column(
            children: [
              // Barra: Ano, Mês, Empregados | Cards (mesma largura/altura)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildFilterDropdown(
                                label: 'ANO',
                                width: 82,
                                child: _buildAnoDropdown(),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterDropdown(
                                label: 'MÊS',
                                width: 130,
                                child: _buildMesesFilter(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildFilterDropdown(
                            label: 'EMPREGADOS',
                            width: double.infinity,
                            child: _buildEmpregadosDropdown(),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 160,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card combinado (Ano)
                              SizedBox(
                                width: 780,
                                child: _buildResumoInvestCombinadoCard(
                                  metaTotal:
                                      (statsAno['metaTotalMes'] as num? ?? 0)
                                          .toDouble(),
                                  horasAlocadas:
                                      (statsAno['horasTotais'] as num? ?? 0)
                                          .toDouble(),
                                  horasInvestimento:
                                      (statsAno['horasInvestimento'] as num? ??
                                              0)
                                          .toDouble(),
                                  horasCusteio:
                                      (statsAno['horasCusteio'] as num? ?? 0)
                                          .toDouble(),
                                  scopeLabel: scopeLabelAno,
                                  compact: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Filtros (ANO, MÊS, EMPREGADOS)
                              SizedBox(
                                width: 92 + 16 + 130,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        _buildFilterDropdown(
                                          label: 'ANO',
                                          width: 92,
                                          child: _buildAnoDropdown(),
                                        ),
                                        const SizedBox(width: 16),
                                        _buildFilterDropdown(
                                          label: 'MÊS',
                                          width: 130,
                                          child: _buildMesesFilter(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildFilterDropdown(
                                      label: 'EMPREGADOS',
                                      width: double.infinity,
                                      child: _buildEmpregadosDropdown(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Card combinado (Meses Selecionados)
                              SizedBox(
                                width: 780,
                                child: _buildResumoInvestCombinadoCard(
                                  metaTotal:
                                      (statsMes['metaTotalMes'] as num? ?? 0)
                                          .toDouble(),
                                  horasAlocadas:
                                      (statsMes['horasTotais'] as num? ?? 0)
                                          .toDouble(),
                                  horasInvestimento:
                                      (statsMes['horasInvestimento'] as num? ??
                                              0)
                                          .toDouble(),
                                  horasCusteio:
                                      (statsMes['horasCusteio'] as num? ?? 0)
                                          .toDouble(),
                                  scopeLabel: scopeLabelMeses,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    // No mobile: cards em coluna acima do gráfico
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildResumoInvestCombinadoCard(
                            metaTotal: (statsMes['metaTotalMes'] as num? ?? 0)
                                .toDouble(),
                            horasAlocadas:
                                (statsMes['horasTotais'] as num? ?? 0)
                                    .toDouble(),
                            horasInvestimento:
                                (statsMes['horasInvestimento'] as num? ?? 0)
                                    .toDouble(),
                            horasCusteio:
                                (statsMes['horasCusteio'] as num? ?? 0)
                                    .toDouble(),
                            scopeLabel: scopeLabelMeses,
                            compact: false,
                            stacked: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            title: 'Colaboradores',
                            value: statsMes['totalColaboradores'].toString(),
                            subtitle: null,
                            icon: Icons.people,
                            iconColor: Colors.blue[600]!,
                            backgroundColor: Colors.blue[50]!,
                          ),
                          const SizedBox(height: 12),
                          _buildVelocimetroAteHojeCard(
                            horasAteHoje: (statsMes['horasAteHoje'] as num)
                                .toDouble(),
                            metaAteHoje: (statsMes['metaAteHoje'] as num)
                                .toDouble(),
                            percentualFeitoAteHoje:
                                (statsMes['percentualFeitoAteHoje'] as num)
                                    .toDouble(),
                            percentualDeveriaAteHoje:
                                (statsMes['percentualDeveriaAteHoje'] as num)
                                    .toDouble(),
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            title: 'Horas Alocadas',
                            value: (statsMes['horasTotais'] as num)
                                .toStringAsFixed(0)
                                .replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]}.',
                                ),
                            subtitle: null,
                            icon: Icons.access_time,
                            iconColor: Colors.green[700]!,
                            backgroundColor: Colors.green[50]!,
                          ),
                          // Cards antigos (Meta Mensal, Status Metas, Custeio/Invest.) removidos
                        ],
                      ),
                    if (_mesesSelecionados.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: isMobile ? 320.0 : 380.0,
                        child: DefaultTabController(
                          length: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TabBar(
                                labelColor: Theme.of(context).primaryColor,
                                unselectedLabelColor: Colors.grey[600],
                                tabs: const [
                                  Tab(text: 'Horas acumuladas no mês'),
                                  Tab(text: 'Horas Extras'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: _buildGraficoAcumuladoMes(
                                            isMobile,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: _buildGraficoAnoCombinado(
                                            isMobile,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildGraficoHoraExtra(isMobile),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    : _dadosTabelaMetas.isEmpty
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
        ),
      ),
    );
  }

  Widget _buildTabelaCompacta(bool isMobile) {
    // Dados do mês + quem não alocou nada ainda
    final dadosTabela = _dadosTabelaMetas;
    final Map<String, List<HorasEmpregadoMes>> dadosPorEmpregado = {};
    for (var dado in dadosTabela) {
      final key = '${dado.nomeEmpregado}_${dado.matricula}';
      dadosPorEmpregado.putIfAbsent(key, () => []);
      dadosPorEmpregado[key]!.add(dado);
    }

    // Se houver mais de um mês selecionado, agregamos por colaborador
    final bool agregado = _mesesSelecionados.length > 1;
    List<HorasEmpregadoMes> fonteLinhas;
    if (agregado) {
      fonteLinhas = dadosPorEmpregado.values.map((lista) {
        lista.sort((a, b) {
          final anoCompare = a.ano.compareTo(b.ano);
          if (anoCompare != 0) return anoCompare;
          return a.mes.compareTo(b.mes);
        });
        final first = lista.first;
        double somaApontadas = 0;
        double somaMeta = 0;
        double somaExtras = 0;
        double somaProg = 0;
        double somaProgInv = 0;
        double somaProgCus = 0;
        double somaInv = 0;
        double somaCus = 0;
        double somaHexInv = 0;
        double somaHexCus = 0;
        double somaHex50Inv = 0;
        double somaHex50Cus = 0;
        double somaHex100Inv = 0;
        double somaHex100Cus = 0;
        for (var d in lista) {
          somaApontadas += d.horasApontadas;
          somaMeta += d.metaMensal;
          somaExtras += d.horasExtras;
          somaProg += d.horasProgramadas;
          somaProgInv += d.horasProgramadasInvestimento;
          somaProgCus += d.horasProgramadasCusteio;
          somaInv += d.horasInvestimento;
          somaCus += d.horasCusteio;
          somaHexInv += d.horasExtrasInvestimento;
          somaHexCus += d.horasExtrasCusteio;
          somaHex50Inv += d.horasExtras50Investimento;
          somaHex50Cus += d.horasExtras50Custeio;
          somaHex100Inv += d.horasExtras100Investimento;
          somaHex100Cus += d.horasExtras100Custeio;
        }
        return HorasEmpregadoMes(
          numeroPessoa: first.numeroPessoa,
          nomeEmpregado: first.nomeEmpregado,
          matricula: first.matricula,
          ano: _anoSelecionado,
          mes: 0, // indica "selecionados"
          horasApontadas: somaApontadas,
          horasFaltantes: (somaMeta - somaApontadas).clamp(
            0.0,
            double.infinity,
          ),
          semApontamento: somaApontadas == 0,
          horasExtras: somaExtras,
          metaMensal: somaMeta,
          horasProgramadas: somaProg,
          horasProgramadasInvestimento: somaProgInv,
          horasProgramadasCusteio: somaProgCus,
          horasInvestimento: somaInv,
          horasCusteio: somaCus,
          horasExtrasInvestimento: somaHexInv,
          horasExtrasCusteio: somaHexCus,
          horasExtras50Investimento: somaHex50Inv,
          horasExtras50Custeio: somaHex50Cus,
          horasExtras100Investimento: somaHex100Inv,
          horasExtras100Custeio: somaHex100Cus,
        );
      }).toList()..sort((a, b) => a.nomeEmpregado.compareTo(b.nomeEmpregado));
    } else {
      fonteLinhas = dadosPorEmpregado.values.expand((lista) {
        // Ordenar por mês
        lista.sort((a, b) {
          final anoCompare = a.ano.compareTo(b.ano);
          if (anoCompare != 0) return anoCompare;
          return a.mes.compareTo(b.mes);
        });
        return lista;
      }).toList();
    }

    return SingleChildScrollView(
      primary: false,
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        primary: false,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 72,
          headingRowColor: WidgetStateProperty.all(DSColors.blue1),
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
                'Gráficos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'C/I',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Programado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Alocado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'HCOOM',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'HHE050',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'HHE100',
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
            DataColumn(
              label: Text(
                'Ordens',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
          ],
          rows: fonteLinhas.map((dado) {
            final corStatus = _getCorStatus(
              dado.horasApontadas,
              dado.metaMensal,
              dado.semApontamento,
            );
            final corBackground = _getCorBackgroundStatus(
              dado.horasApontadas,
              dado.metaMensal,
              dado.semApontamento,
            );
            final statusText = dado.semApontamento
                ? (dado.horasApontadas == 0
                      ? 'Não alocou nada ainda'
                      : 'Sem Apontamento')
                : dado.horasApontadas >= dado.metaMensal
                ? 'Meta Atingida'
                : dado.horasApontadas >= dado.metaMensal * 0.75
                ? 'Em Risco'
                : 'Abaixo da Meta';

            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
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
                        color: DSColors.grey1.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          dado.nomeEmpregado,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dado.semApontamento
                                ? Colors.red[900]
                                : Colors.black87,
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
                      color: DSColors.grey1.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DSColors.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dado.mes == 0
                          ? 'Selecionados/$_anoSelecionado'
                          : '${_getNomeMes(dado.mes)}/${dado.ano}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: DSColors.blue1,
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
                        // Topo: horas programadas / meta do mês
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dado.horasProgramadas.toStringAsFixed(0),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: DSColors.blue1,
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${dado.metaMensal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: DSColors.grey1.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Programado',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: DSColors.grey1.withValues(alpha: 0.6),
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
                                  color: DSColors.neutral,
                                ),
                              ),
                              // Barra de horas programadas (azul) - proporcional às horas programadas
                              if (dado.horasProgramadas > 0)
                                Positioned(
                                  left: 0,
                                  child: SizedBox(
                                    width:
                                        ((dado.horasProgramadas /
                                                dado.metaMensal)
                                            .clamp(0.0, 1.0) *
                                        (isMobile ? 140 : 180)),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(3),
                                        bottomLeft: const Radius.circular(3),
                                        topRight:
                                            dado.horasProgramadas >=
                                                dado.metaMensal
                                            ? Radius.zero
                                            : const Radius.circular(3),
                                        bottomRight:
                                            dado.horasProgramadas >=
                                                dado.metaMensal
                                            ? Radius.zero
                                            : const Radius.circular(3),
                                      ),
                                      child: Container(color: DSColors.blue1),
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
                                  color: DSColors.neutral,
                                ),
                              ),
                              // Barra de horas normais (até a meta)
                              if (dado.horasApontadas > 0)
                                Positioned(
                                  left: 0,
                                  child: SizedBox(
                                    width:
                                        (dado.horasApontadas / dado.metaMensal)
                                            .clamp(0.0, 1.0) *
                                        (isMobile ? 140 : 180),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(3),
                                        bottomLeft: const Radius.circular(3),
                                        topRight:
                                            dado.horasApontadas >=
                                                dado.metaMensal
                                            ? Radius.zero
                                            : const Radius.circular(3),
                                        bottomRight:
                                            dado.horasApontadas >=
                                                dado.metaMensal
                                            ? Radius.zero
                                            : const Radius.circular(3),
                                      ),
                                      child: Container(color: corStatus),
                                    ),
                                  ),
                                ),
                              // Barra de horas extras (HHE) em laranja, continuando após as horas normais
                              if (dado.horasExtras > 0)
                                Positioned(
                                  left:
                                      (dado.horasApontadas / dado.metaMensal)
                                          .clamp(0.0, 1.0) *
                                      (isMobile ? 140 : 180),
                                  child: SizedBox(
                                    width:
                                        (dado.horasExtras / dado.metaMensal)
                                            .clamp(0.0, 1.0) *
                                        (isMobile ? 140 : 180),
                                    height: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topRight: const Radius.circular(3),
                                        bottomRight: const Radius.circular(3),
                                        topLeft:
                                            dado.horasApontadas >=
                                                dado.metaMensal
                                            ? const Radius.circular(3)
                                            : Radius.zero,
                                        bottomLeft:
                                            dado.horasApontadas >=
                                                dado.metaMensal
                                            ? const Radius.circular(3)
                                            : Radius.zero,
                                      ),
                                      child: Container(color: DSColors.warning),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Base: horas alocadas (apontadas) do mês
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dado.horasApontadas.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: corStatus,
                                fontSize: isMobile ? 12 : 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${dado.metaMensal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: DSColors.grey1.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Alocado',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: DSColors.grey1.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        // Observação: removido bloco de informações textuais abaixo dos gráficos
                      ],
                    ),
                  ),
                ),
                // Coluna C/I (Custeio / Investimento)
                DataCell(
                  SizedBox(
                    width: isMobile ? 70 : 90,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Custeio',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 10 : 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Investimento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 10 : 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna Programado (duas linhas: Custeio e Investimento)
                DataCell(
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dado.horasProgramadasCusteio.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dado.horasProgramadasInvestimento.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna Alocado (duas linhas: Custeio e Investimento)
                DataCell(
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dado.horasCusteio.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dado.horasInvestimento.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna HCOOM (horas comuns = sem HHE)
                DataCell(
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ((dado.horasCusteio - dado.horasExtrasCusteio).clamp(
                            0.0,
                            double.infinity,
                          )).toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ((dado.horasInvestimento -
                                      dado.horasExtrasInvestimento)
                                  .clamp(0.0, double.infinity))
                              .toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna HHE050
                DataCell(
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dado.horasExtras50Custeio.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dado.horasExtras50Investimento.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna HHE100
                DataCell(
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dado.horasExtras100Custeio.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dado.horasExtras100Investimento.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                            fontSize: isMobile ? 11 : 12,
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
                        dado.horasFaltantes > 0
                            ? Icons.trending_down
                            : Icons.check_circle,
                        size: 16,
                        color: dado.horasFaltantes > 0
                            ? DSColors.warning
                            : DSColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dado.horasFaltantes.toStringAsFixed(2),
                        style: TextStyle(
                          color: dado.horasFaltantes > 0
                              ? DSColors.warning
                              : DSColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: corStatus.withValues(alpha: 0.15),
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
                DataCell(
                  TextButton.icon(
                    onPressed: () => _mostrarOrdensEmpregadoMes(dado),
                    icon: const Icon(
                      Icons.assignment,
                      size: 16,
                      color: DSColors.blue1,
                    ),
                    label: Text(
                      'Ver',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: DSColors.blue1,
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

  Widget _buildGraficoAcumuladoMes(bool isMobile) {
    final ano = _anoSelecionado;
    if (_mesesSelecionados.isEmpty) return const SizedBox.shrink();

    // Para múltiplos meses, vamos concatenar os dias de cada mês no eixo X
    final numEmpregados = _dadosTabelaMetas
        .map((d) => d.matricula)
        .toSet()
        .length;
    final porDia = _horasPorDiaChart ?? {};

    final doMes = _dadosDoMesSelecionado;
    final totalAlocadoMes = doMes.fold<double>(
      0,
      (s, d) => s + d.horasApontadas,
    );
    final totalCusteioMes = doMes.fold<double>(0, (s, d) => s + d.horasCusteio);
    final totalInvestimentoMes = doMes.fold<double>(
      0,
      (s, d) => s + d.horasInvestimento,
    );

    final hoje = DateTime.now();

    double acumPossivel = 0;
    double acumAlocado = 0;
    final spotsPossivel = <FlSpot>[];
    final spotsAlocado = <FlSpot>[];
    final spotsCusteio = <FlSpot>[];
    final spotsInvestimento = <FlSpot>[];

    // Labels para o eixo X (dia/mês)
    final Map<int, String> xLabels = {};
    int xPosition = 0;

    // Ordenar meses para exibição sequencial
    final mesesOrdenados = _mesesSelecionados.toList()..sort();

    for (var mes in mesesOrdenados) {
      final lastDay = DateTime(ano, mes + 1, 0).day;
      final mesmoMesAno = hoje.year == ano && hoje.month == mes;
      final diaHoje = hoje.day;

      for (int d = 1; d <= lastDay; d++) {
        final dt = DateTime(ano, mes, d);
        final isDiaUtil =
            dt.weekday >= DateTime.monday && dt.weekday <= DateTime.friday;
        if (isDiaUtil) acumPossivel += 8.0 * numEmpregados;

        final chave =
            '${ano.toString()}-${mes.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

        // Só acumular até hoje se for o mês atual
        if (!mesmoMesAno || d <= diaHoje) {
          acumAlocado += porDia[chave] ?? 0;
        }

        spotsPossivel.add(FlSpot(xPosition.toDouble(), acumPossivel));

        // Horas alocadas, custeio e investimento: linha só até hoje
        if (!mesmoMesAno || d <= diaHoje) {
          spotsAlocado.add(FlSpot(xPosition.toDouble(), acumAlocado));
          final ratio = totalAlocadoMes > 0
              ? (acumAlocado / totalAlocadoMes).clamp(0.0, 1.0)
              : 0.0;
          spotsCusteio.add(
            FlSpot(xPosition.toDouble(), totalCusteioMes * ratio),
          );
          spotsInvestimento.add(
            FlSpot(xPosition.toDouble(), totalInvestimentoMes * ratio),
          );
        }

        // Adicionar label a cada 5 dias ou no primeiro/último dia do mês
        if (d == 1 || d == lastDay || d % 5 == 0) {
          xLabels[xPosition] = '$d/${_getNomeMes(mes).substring(0, 3)}';
        }

        xPosition++;
      }
    }

    final maxY = [
      ...spotsPossivel.map((e) => e.y),
      ...spotsAlocado.map((e) => e.y),
      ...spotsCusteio.map((e) => e.y),
      ...spotsInvestimento.map((e) => e.y),
    ].fold<double>(0, (p, c) => c > p ? c : p);

    // Evitar clamp(lower, upper) com lower > upper (ex.: maxY == 0)
    final maxYScale = maxY <= 0 ? 1.0 : (maxY + 1);
    final intervalY = maxY <= 0 ? 1.0 : (maxY / 4).clamp(1.0, maxY);

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: spotsPossivel,
        isCurved: false,
        color: Colors.indigo,
        barWidth: 3,
        dotData: FlDotData(show: true),
      ),
      LineChartBarData(
        spots: spotsAlocado,
        isCurved: false,
        color: Colors.teal,
        barWidth: 3,
        dotData: FlDotData(show: true),
      ),
      LineChartBarData(
        spots: spotsCusteio,
        isCurved: false,
        color: Colors.orange[800],
        barWidth: 2,
        dotData: FlDotData(show: true),
      ),
      LineChartBarData(
        spots: spotsInvestimento,
        isCurved: false,
        color: Colors.purple.shade600,
        barWidth: 2,
        dotData: FlDotData(show: true),
      ),
    ];
    const indiceBarraHoje =
        4; // 0=possível, 1=alocado, 2=custeio, 3=investimento, 4=hoje

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            'Horas acumuladas no mês',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (xPosition - 1).toDouble(),
                    minY: 0,
                    maxY: maxYScale,
                    lineBarsData: lineBars,
                    showingTooltipIndicators: () {
                      final list = <ShowingTooltipIndicators>[];
                      if (spotsPossivel.isNotEmpty && spotsAlocado.isNotEmpty) {
                        list.add(
                          ShowingTooltipIndicators([
                            LineBarSpot(lineBars[0], 0, spotsPossivel.last),
                            LineBarSpot(lineBars[1], 1, spotsAlocado.last),
                            LineBarSpot(lineBars[2], 2, spotsCusteio.last),
                            LineBarSpot(lineBars[3], 3, spotsInvestimento.last),
                          ]),
                        );
                      }
                      return list;
                    }(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: intervalY,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _fmtMilhar(value),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 20,
                          getTitlesWidget: (value, meta) {
                            final xPos = value.toInt();
                            if (xLabels.containsKey(xPos)) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  xLabels[xPos]!,
                                  style: const TextStyle(fontSize: 8),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: 1,
                      horizontalInterval: intervalY,
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) =>
                            touchedSpots.map((s) {
                              if (s.barIndex == indiceBarraHoje) {
                                return LineTooltipItem(
                                  'Hoje',
                                  TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              final color = s.barIndex == 0
                                  ? Colors.indigo
                                  : s.barIndex == 1
                                  ? Colors.teal
                                  : s.barIndex == 2
                                  ? Colors.orange[800]
                                  : Colors.purple.shade600;
                              final label = s.barIndex == 0
                                  ? 'Possível'
                                  : s.barIndex == 1
                                  ? 'Alocado'
                                  : s.barIndex == 2
                                  ? 'Custeio'
                                  : 'Invest.';
                              return LineTooltipItem(
                                '$label: ${_fmtMilhar(s.y)} h',
                                TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
                // Rótulos nos últimos pontos (sempre visíveis)
                if (spotsPossivel.isNotEmpty &&
                    spotsAlocado.isNotEmpty &&
                    maxYScale > 0)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      if (w < 50 || h < 50) return const SizedBox.shrink();
                      const plotLeft = 40.0;
                      const plotBottom = 20.0;
                      final plotW = w - plotLeft;
                      final plotH = h - plotBottom;
                      if (plotW <= 0 || plotH <= 0) {
                        return const SizedBox.shrink();
                      }

                      final maxX = (xPosition - 1).toDouble();
                      final spotP = spotsPossivel.last;
                      final spotA = spotsAlocado.last;
                      final spotC = spotsCusteio.isNotEmpty
                          ? spotsCusteio.last
                          : null;
                      final spotI = spotsInvestimento.isNotEmpty
                          ? spotsInvestimento.last
                          : null;

                      final xUltimo =
                          plotLeft + (maxX > 0 ? (spotA.x / maxX) * plotW : 0);
                      double topFor(double y) =>
                          plotH - (y / maxYScale) * plotH;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Label Possível
                          Positioned(
                            left: xUltimo - 30,
                            top: topFor(spotP.y) - 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_fmtMilhar(spotP.y)} h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Label Alocado
                          Positioned(
                            left: xUltimo + 4,
                            top: topFor(spotA.y) - 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_fmtMilhar(spotA.y)} h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Label Custeio
                          if (spotC != null)
                            Positioned(
                              left: xUltimo - 30,
                              top: topFor(spotC.y) + 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[800]!.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_fmtMilhar(spotC.y)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          // Label Investimento
                          if (spotI != null)
                            Positioned(
                              left: xUltimo + 4,
                              top: topFor(spotI.y) + 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade600.withOpacity(
                                    0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_fmtMilhar(spotI.y)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.indigo,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  const Text('Possível', style: TextStyle(fontSize: 9)),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.teal,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  const Text('Alocado', style: TextStyle(fontSize: 9)),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.orange[800],
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  const Text('Custeio', style: TextStyle(fontSize: 9)),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.purple.shade600,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  const Text('Investimento', style: TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Gráfico acumulado mês a mês (mantido como referência; uso atual: _buildGraficoAnoCombinado).
  // ignore: unused_element
  Widget _buildGraficoAcumuladoAno(bool isMobile) {
    final ano = _anoSelecionado;
    final agora = DateTime.now();
    final int maxMes = (agora.year == ano) ? agora.month : 12;
    if (maxMes < 1) {
      return const SizedBox.shrink();
    }

    final horasPossivelPorMes = <int, double>{};
    final horasAlocadoPorMes = <int, double>{};
    for (int m = 1; m <= maxMes; m++) {
      horasPossivelPorMes[m] = 0.0;
      horasAlocadoPorMes[m] = 0.0;
    }
    for (var d in _dadosFiltrados) {
      if (d.ano != ano || d.mes < 1 || d.mes > maxMes) continue;
      horasPossivelPorMes[d.mes] =
          (horasPossivelPorMes[d.mes] ?? 0) + d.metaMensal;
      horasAlocadoPorMes[d.mes] =
          (horasAlocadoPorMes[d.mes] ?? 0) + d.horasApontadas;
    }
    // Incluir na meta quem não alocou nada no mês: para cada mês, somar meta dos que não têm linha
    final todasMatriculas = _dadosFiltrados
        .map((d) => d.matricula)
        .toSet()
        .toList();
    for (int m = 1; m <= maxMes; m++) {
      final matriculasNoMes = _dadosFiltrados
          .where((d) => d.ano == ano && d.mes == m)
          .map((d) => d.matricula)
          .toSet();
      final metaMes = (_diasUteisNoMes(ano, m) * 8.0).clamp(8.0, 250.0);
      for (var mat in todasMatriculas) {
        if (!matriculasNoMes.contains(mat)) {
          horasPossivelPorMes[m] = (horasPossivelPorMes[m] ?? 0) + metaMes;
        }
      }
    }

    double acumP = 0;
    double acumA = 0;
    final spotsPossivel = <FlSpot>[];
    final spotsAlocado = <FlSpot>[];
    for (int m = 1; m <= maxMes; m++) {
      acumP += horasPossivelPorMes[m] ?? 0;
      acumA += horasAlocadoPorMes[m] ?? 0;
      spotsPossivel.add(FlSpot(m.toDouble(), acumP));
      spotsAlocado.add(FlSpot(m.toDouble(), acumA));
    }

    final maxY = [
      ...spotsPossivel.map((e) => e.y),
      ...spotsAlocado.map((e) => e.y),
    ].fold<double>(0, (p, c) => c > p ? c : p);
    final maxYScale = maxY <= 0 ? 1.0 : (maxY * 1.05);
    final intervalY = maxY <= 0 ? 1.0 : (maxY / 4).clamp(1.0, maxY);

    const mesLabels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            'Acumulado no ano',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                const plotLeft = 32.0;
                const plotBottom = 14.0;
                final plotW = w - plotLeft;
                final plotH = h - plotBottom;
                if (plotW <= 0 || plotH <= 0) {
                  return LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: maxMes.toDouble(),
                      minY: 0,
                      maxY: maxYScale,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spotsPossivel,
                          isCurved: false,
                          color: Colors.indigo,
                          barWidth: 2,
                          dotData: FlDotData(show: true),
                        ),
                        LineChartBarData(
                          spots: spotsAlocado,
                          isCurved: false,
                          color: Colors.teal,
                          barWidth: 2,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LineChart(
                      LineChartData(
                        minX: 1,
                        maxX: maxMes.toDouble(),
                        minY: 0,
                        maxY: maxYScale,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spotsPossivel,
                            isCurved: false,
                            color: Colors.indigo,
                            barWidth: 2,
                            dotData: FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: spotsAlocado,
                            isCurved: false,
                            color: Colors.teal,
                            barWidth: 2,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: intervalY,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 14,
                              getTitlesWidget: (value, meta) {
                                final m = value.toInt();
                                if (m < 1 || m > maxMes) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    mesLabels[m - 1],
                                    style: const TextStyle(fontSize: 8),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          verticalInterval: 1,
                          horizontalInterval: intervalY,
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) => touchedSpots.map((
                              s,
                            ) {
                              final isPossivel = s.barIndex == 0;
                              final idx = (s.x.toInt() - 1).clamp(0, 11);
                              return LineTooltipItem(
                                '${mesLabels[idx]}: ${s.y.toStringAsFixed(0)} h',
                                TextStyle(
                                  color: isPossivel
                                      ? Colors.indigo
                                      : Colors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    // Rótulos de valor para cada mês (Possíveis acima do ponto, Alocadas abaixo)
                    ...List.generate(maxMes, (i) {
                      final m = i + 1;
                      if (spotsPossivel.length < m || spotsAlocado.length < m) {
                        return const SizedBox.shrink();
                      }
                      final spotP = spotsPossivel[i];
                      final spotA = spotsAlocado[i];
                      final xNorm = maxMes > 1 ? (m - 1) / (maxMes - 1) : 0.5;
                      final xPixel = plotLeft + xNorm * plotW;
                      final yP = plotH - (spotP.y / maxYScale) * plotH;
                      final yA = plotH - (spotA.y / maxYScale) * plotH;
                      return Stack(
                        clipBehavior: Clip.none,
                        key: ValueKey('ano_$m'),
                        children: [
                          Positioned(
                            left: xPixel - 18,
                            top: yP - 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${spotP.y.toStringAsFixed(0)} h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: xPixel - 18,
                            top: yA + 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${spotA.y.toStringAsFixed(0)} h',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.indigo,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Possíveis',
                    style: TextStyle(fontSize: isMobile ? 10 : 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.teal,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Alocadas',
                    style: TextStyle(fontSize: isMobile ? 10 : 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Um único gráfico: linhas = acumulado no ano (Possíveis e Alocadas), barras = mês a mês (Possíveis e Alocadas). Eixo esq. = acumulado, eixo dir. = mês a mês.
  Widget _buildGraficoAnoCombinado(bool isMobile) {
    final ano = _anoSelecionado;
    final agora = DateTime.now();
    final int maxMes = (agora.year == ano) ? agora.month : 12;
    if (maxMes < 1) return const SizedBox.shrink();

    final horasPossivelPorMes = <int, double>{};
    final horasAlocadoPorMes = <int, double>{};
    for (int m = 1; m <= maxMes; m++) {
      horasPossivelPorMes[m] = 0.0;
      horasAlocadoPorMes[m] = 0.0;
    }
    for (var d in _dadosFiltrados) {
      if (d.ano != ano || d.mes < 1 || d.mes > maxMes) continue;
      horasPossivelPorMes[d.mes] =
          (horasPossivelPorMes[d.mes] ?? 0) + d.metaMensal;
      horasAlocadoPorMes[d.mes] =
          (horasAlocadoPorMes[d.mes] ?? 0) + d.horasApontadas;
    }
    final todasMatriculas = _dadosFiltrados
        .map((d) => d.matricula)
        .toSet()
        .toList();
    for (int m = 1; m <= maxMes; m++) {
      final matriculasNoMes = _dadosFiltrados
          .where((d) => d.ano == ano && d.mes == m)
          .map((d) => d.matricula)
          .toSet();
      final metaMes = (_diasUteisNoMes(ano, m) * 8.0).clamp(8.0, 250.0);
      for (var mat in todasMatriculas) {
        if (!matriculasNoMes.contains(mat)) {
          horasPossivelPorMes[m] = (horasPossivelPorMes[m] ?? 0) + metaMes;
        }
      }
    }

    double acumP = 0;
    double acumA = 0;
    final spotsPossivel = <FlSpot>[];
    final spotsAlocado = <FlSpot>[];
    for (int i = 0; i < maxMes; i++) {
      final m = i + 1;
      acumP += horasPossivelPorMes[m] ?? 0;
      acumA += horasAlocadoPorMes[m] ?? 0;
      spotsPossivel.add(FlSpot(i.toDouble(), acumP));
      spotsAlocado.add(FlSpot(i.toDouble(), acumA));
    }

    final maxAccum = [
      ...spotsPossivel.map((e) => e.y),
      ...spotsAlocado.map((e) => e.y),
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final maxMonth = [
      for (int m = 1; m <= maxMes; m++) ...[
        horasPossivelPorMes[m] ?? 0,
        horasAlocadoPorMes[m] ?? 0,
      ],
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final scaleAccum = maxAccum <= 0 ? 1.0 : maxAccum;
    final scaleMonth = maxMonth <= 0 ? 1.0 : maxMonth;

    const mesLabels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    // Eixo X 0-based (0, 1, ... maxMes-1) para alinhar linhas e barras na mesma posição
    final spotsPossivelNorm = spotsPossivel
        .map(
          (s) => FlSpot(
            s.x,
            scaleAccum <= 0 ? 0 : (s.y / scaleAccum).clamp(0.0, 1.0),
          ),
        )
        .toList();
    final spotsAlocadoNorm = spotsAlocado
        .map(
          (s) => FlSpot(
            s.x,
            scaleAccum <= 0 ? 0 : (s.y / scaleAccum).clamp(0.0, 1.0),
          ),
        )
        .toList();
    final lineMaxX = maxMes > 1 ? (maxMes - 1).toDouble() : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            'Acumulado no ano + Mês a mês',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const plotLeft = 40.0;
                const plotBottom = 18.0;
                final plotW = constraints.maxWidth - plotLeft - 40;
                final plotH = constraints.maxHeight - plotBottom;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 1.0,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.grey[800]!,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final m = group.x.toInt() + 1;
                              final valor = rodIndex == 0
                                  ? (horasPossivelPorMes[m] ?? 0)
                                  : (horasAlocadoPorMes[m] ?? 0);
                              final label = rodIndex == 0
                                  ? 'Possíveis (mês)'
                                  : 'Alocadas (mês)';
                              return BarTooltipItem(
                                '$label: ${valor.toStringAsFixed(0)} h',
                                TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 9 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: isMobile ? 32 : 40,
                              interval: 0.25,
                              getTitlesWidget: (value, meta) {
                                final real = (value * scaleAccum).round();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Text(
                                    real.toString(),
                                    style: TextStyle(
                                      fontSize: isMobile ? 8 : 9,
                                      color: Colors.indigo[700],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: isMobile ? 32 : 40,
                              interval: 0.25,
                              getTitlesWidget: (value, meta) {
                                final real = (value * scaleMonth).round();
                                return Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    real.toString(),
                                    style: TextStyle(
                                      fontSize: isMobile ? 8 : 9,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 18,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= maxMes) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    mesLabels[idx],
                                    style: const TextStyle(fontSize: 8),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 0.25,
                          getDrawingHorizontalLine: (value) =>
                              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(maxMes, (i) {
                          final m = i + 1;
                          final yPossivel = scaleMonth <= 0
                              ? 0.0
                              : ((horasPossivelPorMes[m] ?? 0) / scaleMonth)
                                    .clamp(0.0, 1.0);
                          final yAlocado = scaleMonth <= 0
                              ? 0.0
                              : ((horasAlocadoPorMes[m] ?? 0) / scaleMonth)
                                    .clamp(0.0, 1.0);
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: yPossivel,
                                color: Colors.indigo.withOpacity(0.7),
                                width: isMobile ? 8 : 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                              BarChartRodData(
                                toY: yAlocado,
                                color: Colors.teal.withOpacity(0.7),
                                width: isMobile ? 8 : 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: lineMaxX,
                        minY: 0,
                        maxY: 1.0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spotsPossivelNorm,
                            isCurved: false,
                            color: Colors.indigo,
                            barWidth: 2,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: spotsAlocadoNorm,
                            isCurved: false,
                            color: Colors.teal,
                            barWidth: 2,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) => touchedSpots.map((
                              s,
                            ) {
                              final isPossivel = s.barIndex == 0;
                              final idx = s.x
                                  .toInt()
                                  .clamp(0, spotsPossivel.length - 1)
                                  .clamp(0, 11);
                              final valor = isPossivel
                                  ? spotsPossivel[idx].y
                                  : spotsAlocado[idx].y;
                              return LineTooltipItem(
                                '${mesLabels[idx]} (acum.): ${valor.toStringAsFixed(0)} h',
                                TextStyle(
                                  color: isPossivel
                                      ? Colors.indigo
                                      : Colors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (plotW > 0 && plotH > 0)
                      ...List.generate(maxMes, (i) {
                        final m = i + 1;
                        final xNorm = maxMes > 1 ? (m - 1) / (maxMes - 1) : 0.5;
                        final xPixel = plotLeft + xNorm * plotW;
                        final spotP = spotsPossivel[i];
                        final spotA = spotsAlocado[i];
                        final yP = plotH - (spotsPossivelNorm[i].y * plotH);
                        final yA = plotH - (spotsAlocadoNorm[i].y * plotH);
                        final yBarP =
                            plotH -
                            (scaleMonth <= 0
                                    ? 0.0
                                    : ((horasPossivelPorMes[m] ?? 0) /
                                              scaleMonth)
                                          .clamp(0.0, 1.0)) *
                                plotH;
                        final yBarA =
                            plotH -
                            (scaleMonth <= 0
                                    ? 0.0
                                    : ((horasAlocadoPorMes[m] ?? 0) /
                                              scaleMonth)
                                          .clamp(0.0, 1.0)) *
                                plotH;
                        return Stack(
                          key: ValueKey('rotulo_ano_$m'),
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: xPixel - 18,
                              top: yP - 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${spotP.y.toStringAsFixed(0)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: xPixel - 18,
                              top: yA + 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${spotA.y.toStringAsFixed(0)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Rótulo barra Possíveis: logo acima do topo da barra, alinhado à primeira barra
                            Positioned(
                              left: xPixel - 24,
                              top: yBarP - 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${(horasPossivelPorMes[m] ?? 0).toStringAsFixed(0)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Rótulo barra Alocadas: logo acima do topo da barra, alinhado à segunda barra
                            Positioned(
                              left: xPixel - 8,
                              top: yBarA - 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${(horasAlocadoPorMes[m] ?? 0).toStringAsFixed(0)} h',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.indigo,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Possíveis',
                    style: TextStyle(fontSize: isMobile ? 8 : 9),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: Colors.teal,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Alocadas',
                    style: TextStyle(fontSize: isMobile ? 8 : 9),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                '— linha = acumulado  ·  barra = mês',
                style: TextStyle(
                  fontSize: isMobile ? 7 : 8,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Gráfico Hora Extra: horas extras (HHE) divididas em Custeio e Investimento.
  /// Gráfico Hora Extra: horas extras (HHE) divididas em Custeio e Investimento.
  Widget _buildGraficoHoraExtra(bool isMobile) {
    final ano = _anoSelecionado;
    final agora = DateTime.now();
    final int maxMes = (agora.year == ano) ? agora.month : 12;
    if (maxMes < 1) return const SizedBox.shrink();

    final horasExtrasCusteioPorMes = <int, double>{};
    final horasExtrasInvestimentoPorMes = <int, double>{};

    for (int m = 1; m <= maxMes; m++) {
      horasExtrasCusteioPorMes[m] = 0.0;
      horasExtrasInvestimentoPorMes[m] = 0.0;
    }
    for (var d in _dadosFiltrados) {
      if (d.ano != ano || d.mes < 1 || d.mes > maxMes) continue;
      horasExtrasCusteioPorMes[d.mes] =
          (horasExtrasCusteioPorMes[d.mes] ?? 0) + d.horasExtrasCusteio;
      horasExtrasInvestimentoPorMes[d.mes] =
          (horasExtrasInvestimentoPorMes[d.mes] ?? 0) +
          d.horasExtrasInvestimento;
    }

    // Calcular max Y considerando o empilhamento (Custeio + Investimento)
    final maxY = [
      for (int m = 1; m <= maxMes; m++)
        (horasExtrasCusteioPorMes[m] ?? 0) +
            (horasExtrasInvestimentoPorMes[m] ?? 0),
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final maxYScale = maxY <= 0 ? 1.0 : (maxY * 1.1);

    const mesLabels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Horas Extras (Custeio vs Investimento)',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: isMobile ? 1.5 : 2.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxYScale,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey[800]!,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = group.x.toInt() + 1;
                      final hCust = horasExtrasCusteioPorMes[m] ?? 0;
                      final hInv = horasExtrasInvestimentoPorMes[m] ?? 0;
                      return BarTooltipItem(
                        '${mesLabels[m - 1]}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: 'Custeio: ${_fmtMilhar(hCust)} h\n',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: 'Invest.: ${_fmtMilhar(hInv)} h\n',
                            style: TextStyle(
                              color: Colors.purple[300],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: 'Total: ${_fmtMilhar(hCust + hInv)} h',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < maxMes) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              mesLabels[index],
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toStringAsFixed(0),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxYScale / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[300],
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(maxMes, (index) {
                  final m = index + 1;
                  final hCust = horasExtrasCusteioPorMes[m] ?? 0;
                  final hInv = horasExtrasInvestimentoPorMes[m] ?? 0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: hCust + hInv,
                        rodStackItems: [
                          BarChartRodStackItem(0, hCust, Colors.orange[800]!),
                          BarChartRodStackItem(
                            hCust,
                            hCust + hInv,
                            Colors.purple[300]!,
                          ),
                        ],
                        width: isMobile ? 16 : 24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.orange[800]!, 'HE Custeio'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.purple[300]!, 'HE Investimento'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
          margin: const EdgeInsets.only(right: 4),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  /// Gráfico de barras mês a mês (mantido como referência; uso atual: _buildGraficoAnoCombinado).
  // ignore: unused_element
  Widget _buildGraficoBarrasMesAMes(bool isMobile) {
    final ano = _anoSelecionado;
    final agora = DateTime.now();
    final int maxMes = (agora.year == ano) ? agora.month : 12;
    if (maxMes < 1) return const SizedBox.shrink();

    final horasPossivelPorMes = <int, double>{};
    final horasAlocadoPorMes = <int, double>{};
    for (int m = 1; m <= maxMes; m++) {
      horasPossivelPorMes[m] = 0.0;
      horasAlocadoPorMes[m] = 0.0;
    }
    for (var d in _dadosFiltrados) {
      if (d.ano != ano || d.mes < 1 || d.mes > maxMes) continue;
      horasPossivelPorMes[d.mes] =
          (horasPossivelPorMes[d.mes] ?? 0) + d.metaMensal;
      horasAlocadoPorMes[d.mes] =
          (horasAlocadoPorMes[d.mes] ?? 0) + d.horasApontadas;
    }
    final todasMatriculas = _dadosFiltrados
        .map((d) => d.matricula)
        .toSet()
        .toList();
    for (int m = 1; m <= maxMes; m++) {
      final matriculasNoMes = _dadosFiltrados
          .where((d) => d.ano == ano && d.mes == m)
          .map((d) => d.matricula)
          .toSet();
      final metaMes = (_diasUteisNoMes(ano, m) * 8.0).clamp(8.0, 250.0);
      for (var mat in todasMatriculas) {
        if (!matriculasNoMes.contains(mat)) {
          horasPossivelPorMes[m] = (horasPossivelPorMes[m] ?? 0) + metaMes;
        }
      }
    }

    final maxPossivel = [
      for (int m = 1; m <= maxMes; m++) horasPossivelPorMes[m] ?? 0,
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final maxAlocado = [
      for (int m = 1; m <= maxMes; m++) horasAlocadoPorMes[m] ?? 0,
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final scalePossivel = maxPossivel <= 0 ? 1.0 : maxPossivel;
    final scaleAlocado = maxAlocado <= 0 ? 1.0 : maxAlocado;

    const mesLabels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mês a mês (não acumulado)',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey[800]!,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = group.x.toInt() + 1;
                      final valor = rodIndex == 0
                          ? (horasPossivelPorMes[m] ?? 0)
                          : (horasAlocadoPorMes[m] ?? 0);
                      final label = rodIndex == 0 ? 'Possíveis' : 'Alocadas';
                      return BarTooltipItem(
                        '$label: ${valor.toStringAsFixed(0)} h',
                        TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 36 : 44,
                      interval: 0.25,
                      getTitlesWidget: (value, meta) {
                        final real = (value * scalePossivel).round();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            real.toString(),
                            style: TextStyle(
                              fontSize: isMobile ? 9 : 10,
                              color: Colors.indigo[700],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 36 : 44,
                      interval: 0.25,
                      getTitlesWidget: (value, meta) {
                        final real = (value * scaleAlocado).round();
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            real.toString(),
                            style: TextStyle(
                              fontSize: isMobile ? 9 : 10,
                              color: Colors.teal[700],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final m = value.toInt();
                        if (m < 0 || m >= maxMes) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            mesLabels[m],
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(maxMes, (i) {
                  final m = i + 1;
                  final yPossivel = scalePossivel <= 0
                      ? 0.0
                      : ((horasPossivelPorMes[m] ?? 0) / scalePossivel).clamp(
                          0.0,
                          1.0,
                        );
                  final yAlocado = scaleAlocado <= 0
                      ? 0.0
                      : ((horasAlocadoPorMes[m] ?? 0) / scaleAlocado).clamp(
                          0.0,
                          1.0,
                        );
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: yPossivel,
                        color: Colors.indigo,
                        width: isMobile ? 10 : 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: yAlocado,
                        color: Colors.teal,
                        width: isMobile ? 10 : 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: [0, 1],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.indigo,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Possíveis (eixo esq.)',
                    style: TextStyle(fontSize: isMobile ? 9 : 10),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.teal,
                    margin: const EdgeInsets.only(right: 2),
                  ),
                  Text(
                    'Alocadas (eixo dir.)',
                    style: TextStyle(fontSize: isMobile ? 9 : 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required double width,
    required Widget child,
  }) {
    final column = Column(
      crossAxisAlignment: width == double.infinity
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
    if (width == double.infinity) return column;
    return SizedBox(width: width, child: column);
  }

  Widget _buildAnoDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _anoSelecionado,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      items: List.generate(5, (i) {
        final ano = DateTime.now().year - 2 + i;
        return DropdownMenuItem(
          value: ano,
          child: Text(ano.toString(), style: const TextStyle(fontSize: 13)),
        );
      }),
      onChanged: (v) {
        if (v != null) {
          setState(() => _anoSelecionado = v);
          _carregarDados();
        }
      },
    );
  }

  Widget _buildEmpregadosDropdown() {
    return GestureDetector(
      onTap: () async {
        final selecionados = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => MultiSelectFilterDialog(
            title: 'Selecionar Empregados',
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
        if (selecionados != null) {
          setState(() {
            _filtroEmpregados = selecionados;
            _aplicarFiltros();
          });
          _carregarGraficoMetas();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _filtroEmpregados.isEmpty
                    ? 'Todos os Colaboradores'
                    : '${_filtroEmpregados.length} selecionado(s)',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // Widget para Card de Estatística (referência: título uppercase cinza, valor em destaque, ícone em quadrado)
  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    bool compact = false,
  }) {
    final padding = compact ? 8.0 : 16.0;
    final valueSize = compact ? 18.0 : 26.0;
    final iconSize = compact ? 16.0 : 22.0;
    final iconPadding = compact ? 6.0 : 10.0;
    return Container(
      padding: EdgeInsets.all(padding),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 6 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null &&
                        subtitle.trim().isNotEmpty &&
                        !compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (subtitle != null &&
                        subtitle.trim().isNotEmpty &&
                        compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(compact ? 6 : 10),
                ),
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card Resumo de Alocação (como a referência nas imagens)
  Widget _buildResumoAlocacaoCard({
    required double metaTotal,
    required double horasAlocadas,
    required double horasInvestimento,
    required double horasCusteio,
    String? scopeLabel,
    bool compact = false,
  }) {
    final padding = compact ? 6.0 : 16.0;
    final headerSize = compact ? 10.0 : 12.0;
    final subSize = compact ? 9.0 : 11.0;
    final valueSize = compact ? 16.0 : 26.0;
    final labelSize = compact ? 9.0 : 12.0;
    final barHeight = compact ? 6.0 : 10.0;

    final total = metaTotal.clamp(0.0, double.infinity);
    final aloc = horasAlocadas.clamp(0.0, double.infinity);
    final gap = (total - aloc).clamp(0.0, double.infinity);
    final pct = total > 0 ? (aloc / total * 100) : 0.0;

    String fmt(num v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    String horaAgora() {
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    String fmt1(num v) => v
        .toStringAsFixed(1)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    Widget metric(String title, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: labelSize, color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: color ?? Colors.black87,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  'h',
                  style: TextStyle(
                    fontSize: labelSize,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RESUMO DE ALOCAÇÃO',
                        style: TextStyle(
                          fontSize: headerSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Colors.grey[600],
                        ),
                      ),
                      if ((scopeLabel ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          scopeLabel!,
                          style: TextStyle(
                            fontSize: headerSize - 1,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dados atualizados hoje às ${_horaAgoraStr()}',
                    style: TextStyle(
                      fontSize: subSize,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[100]!),
                ),
                padding: EdgeInsets.all(compact ? 4 : 6),
                child: Icon(
                  Icons.access_time,
                  size: compact ? 16 : 18,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              metric('Horas Meta', fmt(total)),
              metric('Horas Alocadas', fmt(aloc)),
              metric('Horas Pendentes', fmt(gap), color: Colors.red[700]),
            ],
          ),
          SizedBox(height: compact ? 6 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso da Meta',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: barHeight,
              child: Stack(
                children: [
                  Container(color: Colors.grey[200]),
                  FractionallySizedBox(
                    widthFactor: (total <= 0)
                        ? 0
                        : (aloc / total).clamp(0.0, 1.0),
                    child: Container(color: Colors.green[600]!),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 6),
          // Donut movido para card próprio (sem legendas aqui)
        ],
      ),
    );
  }

  // Card Meta Mensal com donut de horas programadas Custeio x Investimento
  Widget _buildMetaMensalDonutCard({
    required double metaTotal,
    required double progCusteio,
    required double progInvestimento,
    bool compact = false,
  }) {
    final padding = compact ? 8.0 : 16.0;
    final valueSize = compact ? 18.0 : 26.0;
    final donutSize = compact ? 52.0 : 76.0;
    final strokeWidth = compact ? 5.0 : 8.0;
    final legendSize = compact ? 9.0 : 11.0;
    final totalProg = (progCusteio + progInvestimento).clamp(
      0.0,
      double.infinity,
    );
    final percentualInvestProg = totalProg > 0
        ? (progInvestimento / totalProg * 100)
        : 0.0;

    String fmt(num v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    return Container(
      padding: EdgeInsets.all(padding),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'META MENSAL',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 6 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: donutSize,
                height: donutSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: donutSize,
                      height: donutSize,
                      child: CircularProgressIndicator(
                        value: (percentualInvestProg / 100).clamp(0.0, 1.0),
                        strokeWidth: strokeWidth,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple[600]!,
                        ),
                      ),
                    ),
                    Text(
                      '${percentualInvestProg.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: compact ? 11.0 : 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmt(metaTotal),
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      'Prog.: ${fmt(totalProg)} h',
                      style: TextStyle(
                        fontSize: legendSize,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.purple[600],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Inv. (${fmt(progInvestimento)} h)',
                style: TextStyle(fontSize: legendSize, color: Colors.grey[800]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.orange[800],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cust. (${fmt(progCusteio)} h)',
                  style: TextStyle(
                    fontSize: legendSize,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card INVESTIMENTO: mini donut + legendas (Inv./Cust.)
  Widget _buildInvestimentoDonutCard({
    required double horasInvestimento,
    required double horasCusteio,
    bool compact = false,
  }) {
    final padding = compact ? 8.0 : 14.0;
    final titleSize = compact ? 11.0 : 12.0;
    final labelSize = compact ? 10.0 : 11.0;
    final donutSize = compact ? 36.0 : 44.0;
    final stroke = compact ? 6.0 : 7.0;

    final total = (horasInvestimento + horasCusteio).clamp(
      0.0,
      double.infinity,
    );
    final pctInv = total > 0 ? (horasInvestimento / total) : 0.0;

    String fmt1(num v) => v
        .toStringAsFixed(1)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'INVESTIMENTO',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: donutSize,
                height: donutSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pctInv.clamp(0.0, 1.0),
                      strokeWidth: stroke,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.purple.shade700,
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                    Text(
                      '${(pctInv * 100).round()}%',
                      style: TextStyle(
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade700,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Investimento (${fmt1(horasInvestimento)} h)',
                        style: TextStyle(
                          fontSize: labelSize,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange[800],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Custeio (${fmt1(horasCusteio)} h)',
                        style: TextStyle(
                          fontSize: labelSize,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card combinado: Resumo de Alocação (esq.) + Investimento (dir.)
  Widget _buildResumoInvestCombinadoCard({
    required double metaTotal,
    required double horasAlocadas,
    required double horasInvestimento,
    required double horasCusteio,
    String? scopeLabel,
    bool compact = true,
    bool stacked = false,
  }) {
    final padding = compact ? 8.0 : 16.0;
    final headerSize = compact ? 10.0 : 12.0;
    final subSize = compact ? 9.0 : 11.0;
    final valueSize = compact ? 16.0 : 26.0;
    final labelSize = compact ? 9.0 : 12.0;
    final barHeight = compact ? 6.0 : 10.0;

    final total = metaTotal.clamp(0.0, double.infinity);
    final aloc = horasAlocadas.clamp(0.0, double.infinity);
    final gap = (total - aloc).clamp(0.0, double.infinity);
    final pct = total > 0 ? (aloc / total * 100) : 0.0;
    final totalIC = (horasInvestimento + horasCusteio).clamp(
      0.0,
      double.infinity,
    );
    final pctInv = totalIC > 0 ? (horasInvestimento / totalIC) : 0.0;

    String fmt0(num v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    String fmt1(num v) => v
        .toStringAsFixed(1)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    Widget metric(String title, String value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: labelSize, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: color ?? Colors.black87,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                'h',
                style: TextStyle(fontSize: labelSize, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );

    final resumoLeft = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RESUMO DE ALOCAÇÃO',
                style: TextStyle(
                  fontSize: headerSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.grey[600],
                ),
              ),
              if ((scopeLabel ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  scopeLabel!,
                  style: TextStyle(
                    fontSize: headerSize - 1,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Dados atualizados hoje às ${_horaAgoraStr()}',
            style: TextStyle(fontSize: subSize, color: Colors.grey[500]),
          ),
          SizedBox(height: compact ? 8 : 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              metric('Horas Meta', fmt0(total)),
              metric('Horas Alocadas', fmt0(aloc)),
              metric(
                'Horas Pendentes (Gap)',
                fmt0(gap),
                color: Colors.red[700],
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESSO DA META',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: barHeight,
              child: Stack(
                children: [
                  Container(color: Colors.grey[200]),
                  FractionallySizedBox(
                    widthFactor: (total <= 0)
                        ? 0
                        : (aloc / total).clamp(0.0, 1.0),
                    child: Container(color: Colors.green[600]!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final bool isDesktopCompact = compact && !stacked;
    final double donutSz = isDesktopCompact ? 52.0 : (compact ? 36.0 : 44.0);
    final double donutStroke = isDesktopCompact ? 8.0 : (compact ? 6.0 : 7.0);

    final investRight = SizedBox(
      width: isDesktopCompact ? 260 : (compact ? 240 : 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 Investimento (topo)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.purple.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Investimento (${fmt1(horasInvestimento)} h)',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          /// 🔹 Donut centralizado e responsivo
          stacked
              ? SizedBox(
                  height: 180,
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final minSide = math.min(c.maxWidth, c.maxHeight);
                        final donutSize = (minSide * 0.95).clamp(96.0, 180.0);
                        final stroke = (donutSize * 0.14).clamp(10.0, 18.0);
                        final fontSize = (donutSize * 0.34).clamp(18.0, 34.0);
                        return SizedBox(
                          width: donutSize,
                          height: donutSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: donutSize,
                                height: donutSize,
                                child: CircularProgressIndicator(
                                  value: pctInv.clamp(0.0, 1.0),
                                  strokeWidth: stroke,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.purple.shade700,
                                  ),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ),
                              Text(
                                '${(pctInv * 100).round()}%',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade900,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                )
              : Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final minSide = math.min(c.maxWidth, c.maxHeight);
                        final donutSize = (minSide * 0.95).clamp(96.0, 180.0);
                        final stroke = (donutSize * 0.14).clamp(10.0, 18.0);
                        final fontSize = (donutSize * 0.34).clamp(18.0, 34.0);
                        return SizedBox(
                          width: donutSize,
                          height: donutSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: donutSize,
                                height: donutSize,
                                child: CircularProgressIndicator(
                                  value: pctInv.clamp(0.0, 1.0),
                                  strokeWidth: stroke,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.purple.shade700,
                                  ),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ),
                              Text(
                                '${(pctInv * 100).round()}%',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade900,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

          /// 🔹 Pequeno espaço inferior
          const SizedBox(height: 6),

          /// 🔹 Custeio (bottom)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Custeio (${fmt1(horasCusteio)} h)',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [resumoLeft, const SizedBox(height: 12), investRight],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                resumoLeft,
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 4 : 6,
                    horizontal: 12,
                  ),
                  child: Container(width: 1, color: Colors.grey[200]),
                ),
                investRight,
              ],
            ),
    );
  }

  /// Card velocímetro: % feito até hoje vs % que deveria ter feito (mês selecionado).
  Widget _buildVelocimetroAteHojeCard({
    required double horasAteHoje,
    required double metaAteHoje,
    required double percentualFeitoAteHoje,
    required double percentualDeveriaAteHoje,
    bool compact = false,
  }) {
    final size = compact ? 52.0 : 80.0;
    final strokeWidth = compact ? 5.0 : 8.0;
    final fontSize = compact ? 11.0 : 16.0;
    final padding = compact ? 8.0 : 16.0;
    final textSize = compact ? 9.0 : 11.0;
    final gaugeValue = (percentualFeitoAteHoje / 100).clamp(0.0, 1.0);
    final color = percentualFeitoAteHoje >= 100
        ? Colors.green[600]!
        : percentualFeitoAteHoje >= 80
        ? Colors.orange[600]!
        : Colors.red[600]!;
    return Container(
      padding: EdgeInsets.all(padding),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'ATÉ HOJE',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: gaugeValue,
                        strokeWidth: strokeWidth,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percentualFeitoAteHoje.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (!compact)
                          Text(
                            'feito',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Feito: ${horasAteHoje.toStringAsFixed(0)} h',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(
                            color: Colors.orange[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Deveria: ${metaAteHoje.toStringAsFixed(0)} h',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
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

  // Widget para Card de Metas com gráfico circular
  Widget _buildMetasCard({
    required int metasAtingidas,
    required int metasPendentes,
    required double percentual,
    bool compact = false,
  }) {
    final size = compact ? 52.0 : 80.0;
    final strokeWidth = compact ? 5.0 : 8.0;
    final fontSize = compact ? 12.0 : 18.0;
    final padding = compact ? 8.0 : 16.0;
    final textSize = compact ? 9.0 : 11.0;
    return Container(
      padding: EdgeInsets.all(padding),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'STATUS METAS',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: percentual / 100,
                        strokeWidth: strokeWidth,
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
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Atingido ($metasAtingidas)',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pendente ($metasPendentes)',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
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

  // Card Custeio x Investimento: quantidade de horas e percentual de Investimento no círculo
  Widget _buildCusteioInvestimentoCard({
    required double horasInvestimento,
    required double horasCusteio,
    required double percentualInvestimento,
    bool compact = false,
  }) {
    final size = compact ? 52.0 : 80.0;
    final strokeWidth = compact ? 5.0 : 8.0;
    final fontSize = compact ? 12.0 : 18.0;
    final padding = compact ? 8.0 : 16.0;
    final textSize = compact ? 9.0 : 11.0;
    return Container(
      padding: EdgeInsets.all(padding),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            'INVESTIMENTO',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: (percentualInvestimento / 100).clamp(0.0, 1.0),
                        strokeWidth: strokeWidth,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple[600]!,
                        ),
                      ),
                    ),
                    Text(
                      '${percentualInvestimento.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 8 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(
                            color: Colors.purple[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Inv. (${horasInvestimento.toStringAsFixed(1)} h)',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Row(
                      children: [
                        Container(
                          width: compact ? 8 : 12,
                          height: compact ? 8 : 12,
                          decoration: BoxDecoration(
                            color: Colors.teal[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cust. (${horasCusteio.toStringAsFixed(1)} h)',
                            style: TextStyle(fontSize: textSize),
                            overflow: TextOverflow.ellipsis,
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
