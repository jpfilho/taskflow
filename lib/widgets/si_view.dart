import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../models/si.dart';
import '../services/si_service.dart';
import '../utils/responsive.dart';
import 'task_form_dialog.dart';
import 'task_selection_dialog.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../services/status_service.dart';
import 'task_view_dialog.dart';
import 'multi_select_filter_dialog.dart';

class SIView extends StatefulWidget {
  const SIView({super.key});

  @override
  State<SIView> createState() => _SIViewState();
}

class _SIViewState extends State<SIView> {
  final SIService _service = SIService();
  final StatusService _statusService = StatusService();
  List<SI> _sis = [];
  List<SI> _todasSIs = []; // Todas as SIs para calcular estatísticas
  Set<String> _sisProgramadasIds = {}; // IDs das SIs vinculadas a tarefas
  Map<String, List<Map<String, dynamic>>> _sisProgramadasInfo = {}; // Lista de vinculações por SI
  Map<String, Status> _statusMap = {}; // Mapa de status (codigo -> Status)
  bool _isLoading = false;
  Set<String> _filtroStatus = {};
  Set<String> _filtroLocal = {};
  Set<String> _filtroStatusUsuario = {};
  DateTime? _dataInicio;
  DateTime? _dataFim;
  int _totalSIs = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  List<String> _statusDisponiveis = [];
  List<String> _locaisDisponiveis = [];
  List<String> _statusUsuarioDisponiveis = [];
  bool _visualizacaoTabela = false; // false = cards, true = tabela
  StreamSubscription<String>? _statusChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadFiltros();
    _loadSIs();
    _loadTodasSIsParaEstatisticas();
    _loadSIsProgramadas();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _visualizacaoTabela = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final statuses = await _statusService.getAllStatus();
      final statusMap = <String, Status>{};
      for (final status in statuses) {
        statusMap[status.codigo] = status;
      }
      if (mounted) {
        setState(() {
          _statusMap = statusMap;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar status: $e');
    }
  }

  Future<void> _loadSIsProgramadas() async {
    try {
      final programadas = await _service.getSIsProgramadas();
      final ids = <String>{};
      final info = <String, List<Map<String, dynamic>>>{};
      
      for (final item in programadas) {
        final si = item['si'] as SI;
        final siId = si.id;
        ids.add(siId);
        
        // Adicionar à lista de vinculações desta SI
        if (!info.containsKey(siId)) {
          info[siId] = [];
        }
        info[siId]!.add(item);
      }
      
      // Ordenar cada lista por data de vinculação (mais recente primeiro)
      for (final siId in info.keys) {
        info[siId]!.sort((a, b) {
          final dataA = a['vinculado_em'] as DateTime?;
          final dataB = b['vinculado_em'] as DateTime?;
          if (dataA == null && dataB == null) return 0;
          if (dataA == null) return 1;
          if (dataB == null) return -1;
          return dataB.compareTo(dataA); // Mais recente primeiro
        });
      }
      
      if (mounted) {
        setState(() {
          _sisProgramadasIds = ids;
          _sisProgramadasInfo = info;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar SIs programadas: $e');
    }
  }

  Color _getTaskStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      return statusObj.color;
    }
    
    // Fallback para cores padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return Colors.orange;
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      case 'RPAR':
        return Colors.teal;
      case 'CANC':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  Future<void> _loadFiltros() async {
    final valores = await _service.getValoresFiltros();
    setState(() {
      _statusDisponiveis = valores['status'] ?? [];
      _locaisDisponiveis = valores['local'] ?? [];
      _statusUsuarioDisponiveis = valores['statusUsuario'] ?? [];
    });
  }

  Future<void> _loadSIs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sis = await _service.getAllSIs(
        filtroStatus: _filtroStatus.isEmpty ? null : _filtroStatus.toList(),
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: _itensPorPagina,
        offset: _paginaAtual * _itensPorPagina,
      );

      final total = await _service.contarSIs(
        filtroStatus: _filtroStatus.isEmpty ? null : _filtroStatus.toList(),
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
      );

      setState(() {
        _sis = sis;
        _totalSIs = total;
        _isLoading = false;
      });
      // Recarregar SIs programadas quando carregar SIs
      _loadSIsProgramadas();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao carregar SIs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
    }
  }

  // Função auxiliar para decodificar bytes como UTF-8
  // O arquivo está em UTF-8, mas pode ter alguns bytes malformados
  String _decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    
    // Detectar encoding: verificar se há caracteres típicos de Latin-1
    // que não são válidos em UTF-8
    bool pareceLatin1 = false;
    for (int i = 0; i < bytes.length && i < 1000; i++) {
      if (bytes[i] > 127 && bytes[i] < 160) {
        pareceLatin1 = true;
        break;
      }
    }
    
    // Se parece Latin-1, tentar primeiro como Latin-1
    if (pareceLatin1) {
      try {
        final latin1Result = latin1.decode(bytes);
        print('✅ Arquivo decodificado como Latin-1 (ISO-8859-1)');
        return latin1Result;
      } catch (e) {
        print('⚠️ Erro ao decodificar como Latin-1: $e');
      }
    }
    
    // Tentar decodificar como UTF-8 sem allowMalformed primeiro
    try {
      final utf8Result = utf8.decode(bytes);
      // Verificar se não há caracteres de substituição (indicando encoding errado)
      if (!utf8Result.contains('')) {
        print('✅ Arquivo decodificado como UTF-8');
        return utf8Result;
      } else {
        print('⚠️ UTF-8 contém caracteres de substituição, tentando Latin-1...');
        throw FormatException('UTF-8 contém caracteres de substituição');
      }
    } catch (e) {
      print('⚠️ Erro ao decodificar UTF-8: $e');
      print('   Tentando como Latin-1...');
      
      // Tentar Latin-1
      try {
        final latin1Result = latin1.decode(bytes);
        print('✅ Arquivo decodificado como Latin-1 (ISO-8859-1)');
        return latin1Result;
      } catch (e2) {
        print('❌ Erro ao decodificar como Latin-1: $e2');
        // Último recurso: UTF-8 com allowMalformed e remover caracteres de substituição
        try {
          final utf8Malformed = utf8.decode(bytes, allowMalformed: true);
          final cleaned = utf8Malformed.replaceAll('', '');
          print('⚠️ Fallback: Arquivo decodificado como UTF-8 (com limpeza)');
          return cleaned;
        } catch (e3) {
          print('❌ Erro crítico ao decodificar arquivo: $e3');
          // Último recurso absoluto: tentar Latin-1 mesmo com erro
          try {
            return latin1.decode(bytes);
          } catch (e4) {
            // Se tudo falhar, retornar string vazia ou tentar UTF-8 com allowMalformed
            return utf8.decode(bytes, allowMalformed: true).replaceAll('', '');
          }
        }
      }
    }
  }

  Future<void> _importarCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        String csvContent;

        try {
          // Web: usar bytes (path não está disponível)
          if (kIsWeb) {
            if (file.bytes == null || file.bytes!.isEmpty) {
              throw Exception('Arquivo vazio ou não foi possível ler');
            }
            csvContent = _decodeBytes(file.bytes!);
          } else {
            // Mobile/Desktop: usar path
            if (file.path == null) {
              throw Exception('Caminho do arquivo não disponível');
            }
            final fileObj = File(file.path!);
            // Ler como bytes primeiro para poder tentar diferentes encodings
            final bytes = await fileObj.readAsBytes();
            if (bytes.isEmpty) {
              throw Exception('Arquivo vazio');
            }
            csvContent = _decodeBytes(bytes);
          }

          if (csvContent.isEmpty) {
            throw Exception('Conteúdo do arquivo está vazio após decodificação');
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao ler arquivo: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }

        Map<String, dynamic> resultado;
        try {
          resultado = await _service.importarSIsDoCSV(csvContent);
        } catch (e) {
          print('❌ Erro crítico na importação: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao processar CSV: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resultado['sucesso'] == true
                    ? 'Importação concluída: ${resultado['importadas']} SIs importados, ${resultado['duplicatas']} duplicatas ignoradas'
                    : 'Erro na importação: ${resultado['erro'] ?? 'Erro desconhecido'}',
              ),
              backgroundColor: resultado['sucesso'] == true ? Colors.green : Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        if (resultado['sucesso'] == true && mounted) {
          try {
            await _loadFiltros();
            await _loadSIs();
            await _loadTodasSIsParaEstatisticas();
            await _loadSIsProgramadas();
          } catch (e) {
            print('⚠️ Erro ao recarregar dados após importação: $e');
            // Não mostrar erro ao usuário, pois a importação foi bem-sucedida
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro crítico em _importarCSV: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadTodasSIsParaEstatisticas() async {
    try {
      // Carregar todas as SIs sem paginação para calcular estatísticas, usando os mesmos filtros
      final todasSIs = await _service.getAllSIs(
        filtroStatus: _filtroStatus.isEmpty ? null : _filtroStatus.toList(),
        filtroLocal: _filtroLocal.isEmpty ? null : _filtroLocal.toList(),
        filtroStatusUsuario: _filtroStatusUsuario.isEmpty ? null : _filtroStatusUsuario.toList(),
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: null, // Sem limite
        offset: null,
      );

      if (mounted) {
        setState(() {
          _todasSIs = todasSIs;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar todas as SIs para estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    // Calcular estatísticas para os dashboards usando as SIs filtradas
    final totalSIs = _todasSIs.length;
    // Contar apenas as SIs programadas que estão na lista filtrada
    final sisProgramadas = _todasSIs.where((si) => _sisProgramadasIds.contains(si.id)).length;
    final sisNaoProgramadas = totalSIs > 0 ? totalSIs - sisProgramadas : 0;
    
    // Contar por status sistema
    final sisPorStatus = <String, int>{};
    for (final si in _todasSIs) {
      final status = si.statusSistema ?? 'Sem Status';
      sisPorStatus[status] = (sisPorStatus[status] ?? 0) + 1;
    }
    
    final statusMaisComum = sisPorStatus.entries.isNotEmpty
        ? sisPorStatus.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '-';

    return Scaffold(
      body: Column(
        children: [
          // Header com botões
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
                  'SIs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                // Dashboards compactos
                if (!isMobile) ...[
                  _buildDashboardCardCompacto(
                    'Total',
                    totalSIs.toString(),
                    Icons.description,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildDashboardCardCompacto(
                    'Programadas',
                    sisProgramadas.toString(),
                    Icons.task_alt,
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildDashboardCardCompacto(
                    'Não Programadas',
                    sisNaoProgramadas.toString(),
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildDashboardCardCompacto(
                    'Status Mais Comum',
                    statusMaisComum.length > 15 ? '${statusMaisComum.substring(0, 15)}...' : statusMaisComum,
                    Icons.label,
                    Colors.purple,
                  ),
                ],
                const Spacer(),
                // Botão de alternar visualização
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visualizacaoTabela = !_visualizacaoTabela;
                    });
                  },
                  icon: Icon(_visualizacaoTabela ? Icons.view_module : Icons.table_chart),
                  tooltip: _visualizacaoTabela ? 'Visualização em Cards' : 'Visualização em Tabela',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _importarCSV,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtroStatus = {};
                      _filtroLocal = {};
                      _filtroStatusUsuario = {};
                      _dataInicio = null;
                      _dataFim = null;
                      _paginaAtual = 0;
                    });
                    _loadSIs();
                    _loadTodasSIsParaEstatisticas();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),

          // Filtros
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: isMobile
                ? ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 20),
                        const SizedBox(width: 8),
                        const Text('Filtros', style: TextStyle(fontSize: 16)),
                        if (_filtroStatus.isNotEmpty || _filtroLocal.isNotEmpty || _filtroStatusUsuario.isNotEmpty || _dataInicio != null || _dataFim != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              [
                                if (_filtroStatus.isNotEmpty) '1',
                                if (_filtroLocal.isNotEmpty) '1',
                                if (_filtroStatusUsuario.isNotEmpty) '1',
                                if (_dataInicio != null) '1',
                                if (_dataFim != null) '1',
                              ].length.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.all(8),
                    children: [
                      _buildMultiSelectFilterField(
                        'Status Sistema',
                        _filtroStatus,
                        _statusDisponiveis,
                        (newValues) {
                          setState(() {
                            _filtroStatus = newValues;
                            _paginaAtual = 0;
                          });
                          _loadSIs();
                          _loadTodasSIsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectFilterField(
                        'Local de Instalação',
                        _filtroLocal,
                        _locaisDisponiveis,
                        (newValues) {
                          setState(() {
                            _filtroLocal = newValues;
                            _paginaAtual = 0;
                          });
                          _loadSIs();
                          _loadTodasSIsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectFilterField(
                        'Status Usuário',
                        _filtroStatusUsuario,
                        _statusUsuarioDisponiveis,
                        (newValues) {
                          setState(() {
                            _filtroStatusUsuario = newValues;
                            _paginaAtual = 0;
                          });
                          _loadSIs();
                          _loadTodasSIsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildDateFilterField(
                        'Data Início',
                        _dataInicio,
                        (date) {
                          setState(() {
                            _dataInicio = date;
                            _paginaAtual = 0;
                          });
                          _loadSIs();
                          _loadTodasSIsParaEstatisticas();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildDateFilterField(
                        'Data Fim',
                        _dataFim,
                        (date) {
                          setState(() {
                            _dataFim = date;
                            _paginaAtual = 0;
                          });
                          _loadSIs();
                          _loadTodasSIsParaEstatisticas();
                        },
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: _buildMultiSelectFilterField(
                    'Status Sistema',
                    _filtroStatus,
                    _statusDisponiveis,
                    (newValues) {
                      setState(() {
                        _filtroStatus = newValues;
                        _paginaAtual = 0;
                      });
                      _loadSIs();
                      _loadTodasSIsParaEstatisticas();
                    },
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: _buildMultiSelectFilterField(
                    'Local de Instalação',
                    _filtroLocal,
                    _locaisDisponiveis,
                    (newValues) {
                      setState(() {
                        _filtroLocal = newValues;
                        _paginaAtual = 0;
                      });
                      _loadSIs();
                      _loadTodasSIsParaEstatisticas();
                    },
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: _buildMultiSelectFilterField(
                    'Status Usuário',
                    _filtroStatusUsuario,
                    _statusUsuarioDisponiveis,
                    (newValues) {
                      setState(() {
                        _filtroStatusUsuario = newValues;
                        _paginaAtual = 0;
                      });
                      _loadSIs();
                      _loadTodasSIsParaEstatisticas();
                    },
                  ),
                ),

                // Filtro Data Início
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dataInicio ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dataInicio = date;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Início',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dataInicio != null
                            ? '${_dataInicio!.day}/${_dataInicio!.month}/${_dataInicio!.year}'
                            : 'Selecione',
                      ),
                    ),
                  ),
                ),

                // Filtro Data Fim
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dataFim ?? DateTime.now(),
                        firstDate: _dataInicio ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dataFim = date;
                          _paginaAtual = 0;
                        });
                        _loadSIs();
                        _loadTodasSIsParaEstatisticas();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Fim',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dataFim != null
                            ? '${_dataFim!.day}/${_dataFim!.month}/${_dataFim!.year}'
                            : 'Selecione',
                      ),
                    ),
                  ),
                ),

                // Botão Limpar Filtros
                if (!isMobile)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtroStatus = {};
                        _filtroLocal = {};
                        _filtroStatusUsuario = {};
                        _dataInicio = null;
                        _dataFim = null;
                        _paginaAtual = 0;
                      });
                      _loadSIs();
                      _loadTodasSIsParaEstatisticas();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar Filtros'),
                  ),
                    ],
                  ),
          ),

          // Contador de resultados
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Text(
                  'Total: $_totalSIs SIs (${_sis.length} nesta página)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Text(
                  'Página ${_paginaAtual + 1} de ${(_totalSIs / _itensPorPagina).ceil()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Lista de ats (Cards ou Tabela)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sis.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma SI encontrada',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _visualizacaoTabela
                        ? _buildTabelaView()
                        : ListView.builder(
                            itemCount: _sis.length,
                            itemBuilder: (context, index) {
                              final si = _sis[index];
                              return _buildSICard(si);
                            },
                          ),
          ),

          // Paginação
          if (_totalSIs > _itensPorPagina)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ],
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
                            _loadSIs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalSIs / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalSIs
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            _loadSIs();
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

  // Criar tarefa a partir de uma at
  Future<void> _criarTarefaDaSI(SI si) async {
    try {
      // Calcular datas padrão
      final dataInicio = si.dataInicio ?? DateTime.now();
      final dataFim = si.dataFim ?? dataInicio.add(const Duration(days: 1));
      
      final taskCriada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskFormDialog(
          startDate: dataInicio,
          endDate: dataFim,
        ),
      );
      
      if (taskCriada != null) {
        final taskService = TaskService();
        try {
          final createdTask = await taskService.createTask(taskCriada);
          await _service.vincularSITarefa(createdTask.id, si.id);
          await _loadSIsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarefa criada e vinculada à SI ${si.solicitacao} com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          print('⚠️ Erro ao criar/vincular tarefa: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao criar tarefa ou vincular at: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar tarefa: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Vincular SI a uma tarefa existente
  Future<void> _vincularSITarefaExistente(SI si) async {
    try {
      final taskService = TaskService();
      final todasTarefas = await taskService.getAllTasks();
      
      if (todasTarefas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não há tarefas disponíveis para vincular'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final tarefaSelecionada = await showDialog<Task>(
        context: context,
        builder: (context) => TaskSelectionDialog(
          tasks: todasTarefas,
        ),
      );
      
      if (tarefaSelecionada != null) {
        try {
          await _service.vincularSITarefa(tarefaSelecionada.id, si.id);
          await _loadSIsProgramadas();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('SI ${si.solicitacao} vinculada à tarefa "${tarefaSelecionada.tarefa}" com sucesso!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao vincular at: $e');
          print('❌ Stack trace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular at: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular at: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Navegar para tarefa vinculada
  Future<void> _navegarParaTarefa(String? taskId) async {
    if (taskId == null) return;
    
    try {
      final taskService = TaskService();
      final task = await taskService.getTaskById(taskId);
      
      if (task != null && mounted) {
        await showDialog(
          context: context,
          builder: (context) => TaskViewDialog(task: task),
        );
      }
    } catch (e) {
      print('⚠️ Erro ao carregar tarefa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar todas as vinculações de uma SI
  void _mostrarTodasVinculacoes(SI si, List<Map<String, dynamic>> vinculacoes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tarefas vinculadas à SI ${si.solicitacao}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vinculacoes.length,
            itemBuilder: (context, index) {
              final vinculacao = vinculacoes[index];
              final tarefa = vinculacao['tarefa'] as Map<String, dynamic>?;
              final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
              
              if (tarefa == null) return const SizedBox.shrink();
              
              final status = tarefa['status'] as String?;
              final statusColor = status != null ? _getTaskStatusColor(status) : Colors.grey;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(Icons.task, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    tarefa['tarefa']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      if (vinculadoEm != null)
                        Text(
                          'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _navegarParaTarefa(tarefa['id'] as String?);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarParaAreaTransferencia(String texto, String mensagemSucesso) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemSucesso), duration: const Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível copiar: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  Widget _buildSICard(SI si) {
    final isProgramada = _sisProgramadasIds.contains(si.id);
    final programadasList = isProgramada ? _sisProgramadasInfo[si.id] : null;
    final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
    final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
    final tarefaStatus = tarefa?['status'] as String?;
    final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: isProgramada && statusColor != null 
          ? statusColor.withOpacity(0.1) 
          : null,
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(si.statusSistema),
              child: Text(
                si.statusUsuario ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (isProgramada && statusColor != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'SI: ${si.solicitacao}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
            if (isProgramada && tarefaStatus != null && statusColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      tarefaStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (si.textoBreve != null)
              Text(
                si.textoBreve!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (isProgramada && tarefa != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _navegarParaTarefa(tarefa['id'] as String?),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor != null 
                        ? statusColor.withOpacity(0.15)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor ?? Colors.blue[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: statusColor ?? Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tarefa['tarefa']?.toString() ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: statusColor ?? Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (si.dataInicio != null)
                  Text(
                    'Início: ${_formatDate(si.dataInicio!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (si.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(si.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      si.statusSistema!,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Status Sistema', si.statusSistema),
                _buildInfoRow('Status Usuário', si.statusUsuario),
                _buildInfoRow('Tipo', si.tipo),
                _buildInfoRow('Texto Breve', si.textoBreve),
                _buildInfoRow('Local Instalação', si.localInstalacao),
                _buildInfoRow('Cen', si.cen),
                _buildInfoRow('CntrTrab', si.cntrTrab),
                if (si.dataInicio != null)
                  _buildInfoRow('Data Início', _formatDate(si.dataInicio!)),
                if (si.dataFim != null)
                  _buildInfoRow('Data Fim', _formatDate(si.dataFim!)),
                
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _criarTarefaDaSI(si),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _vincularSITarefaExistente(si),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Vincular a Tarefa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                
                // Mostrar tarefas vinculadas se houver
                if (isProgramada && programadasList != null && programadasList.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Tarefas Vinculadas (${programadasList.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...programadasList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final vinculacao = entry.value;
                    final tarefaVinculada = vinculacao['tarefa'] as Map<String, dynamic>?;
                    final statusTarefa = tarefaVinculada?['status'] as String?;
                    final statusColorTarefa = statusTarefa != null ? _getTaskStatusColor(statusTarefa) : null;
                    final vinculadoEm = vinculacao['vinculado_em'] as DateTime?;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: index < programadasList.length - 1 ? 16 : 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColorTarefa?.withOpacity(0.1) ?? Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColorTarefa ?? Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _navegarParaTarefa(tarefaVinculada?['id'] as String?),
                                  child: Text(
                                    tarefaVinculada?['tarefa']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: statusColorTarefa ?? Colors.blue[700],
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              if (statusTarefa != null && statusColorTarefa != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColorTarefa,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusTarefa,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                          if (vinculadoEm != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Vinculado em: ${vinculadoEm.day}/${vinculadoEm.month}/${vinculadoEm.year}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
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

  Widget _buildDashboardCardCompacto(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 20 ? 12 : 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMultiSelectFilterField(
    String label,
    Set<String> selectedValues,
    List<String> options,
    Function(Set<String>) onChanged, {
    String? searchHint,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MultiSelectFilterDialog(
            title: label,
            options: options,
            selectedValues: selectedValues,
            onSelectionChanged: (newValues) {
              onChanged(newValues);
            },
            searchHint: searchHint,
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          selectedValues.isEmpty
              ? 'Todos'
              : selectedValues.length == 1
                  ? selectedValues.first
                  : '${selectedValues.length} selecionado(s)',
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.grey[600] : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterField(String label, DateTime? value, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          onChanged(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: const Icon(Icons.calendar_today),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          value != null
              ? '${value.day}/${value.month}/${value.year}'
              : 'Selecione',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('ABER')) return Colors.orange;
    if (status.contains('CAPC')) return Colors.blue;
    if (status.contains('DMNV')) return Colors.red;
    if (status.contains('ERRD')) return Colors.red;
    if (status.contains('SCDM')) return Colors.green;
    return Colors.grey;
  }

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Solicitação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status Usuário', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local Instalação', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tarefa Vinculada', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Início', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data Fim', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Cen', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _sis.map((si) {
            final isProgramada = _sisProgramadasIds.contains(si.id);
            final programadasList = isProgramada ? _sisProgramadasInfo[si.id] : null;
            final programadaInfo = programadasList?.isNotEmpty == true ? programadasList!.first : null;
            final tarefa = programadaInfo?['tarefa'] as Map<String, dynamic>?;
            final tarefaStatus = tarefa?['status'] as String?;
            final statusColor = tarefaStatus != null ? _getTaskStatusColor(tarefaStatus) : null;
            final totalVinculacoes = programadasList?.length ?? 0;
            
            return DataRow(
              color: isProgramada && statusColor != null
                  ? MaterialStateProperty.all(statusColor.withOpacity(0.1))
                  : null,
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Criar Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _criarTarefaDaSI(si),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: const Icon(Icons.add_task, size: 20, color: Colors.green),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Vincular a Tarefa',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _vincularSITarefaExistente(si),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[300]!),
                              ),
                              child: const Icon(Icons.link, size: 20, color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  isProgramada && tarefaStatus != null && statusColor != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.task, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                tarefaStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (totalVinculacoes > 1) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${totalVinculacoes - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.grey[600], size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Não Programada',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
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
                      Text(
                        si.solicitacao,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                  onTap: () => _mostrarDetalhesSI(si),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(si.tipo ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      si.textoBreve ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(si.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      si.statusSistema ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  Text(si.statusUsuario ?? '-'),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      si.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  isProgramada && tarefa != null
                      ? InkWell(
                          onTap: totalVinculacoes > 1
                              ? () => _mostrarTodasVinculacoes(si, programadasList!)
                              : () => _navegarParaTarefa(tarefa['id'] as String?),
                          child: SizedBox(
                            width: 200,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    tarefa['tarefa']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: totalVinculacoes > 1 ? Colors.orange : Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (totalVinculacoes > 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$totalVinculacoes',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : const Text('-', style: TextStyle(color: Colors.grey)),
                ),
                DataCell(
                  Text(si.dataInicio != null ? _formatDate(si.dataInicio!) : '-'),
                ),
                DataCell(
                  Text(si.dataFim != null ? _formatDate(si.dataFim!) : '-'),
                ),
                DataCell(
                  Text(si.cen ?? '-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostrarDetalhesSI(SI si) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Detalhes da SI: ${si.solicitacao}'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Solicitação', si.solicitacao),
              _buildInfoRow('Tipo', si.tipo),
              _buildInfoRow('Status Sistema', si.statusSistema),
              _buildInfoRow('Status Usuário', si.statusUsuario),
              _buildInfoRow('Texto Breve', si.textoBreve),
              _buildInfoRow('Local Instalação', si.localInstalacao),
              _buildInfoRow('Criado Por', si.criadoPor),
              _buildInfoRow('Cen', si.cen),
              _buildInfoRow('CntrTrab', si.cntrTrab),
              if (si.dataInicio != null)
                _buildInfoRow('Data Início', _formatDate(si.dataInicio!)),
              if (si.dataFim != null)
                _buildInfoRow('Data Fim', _formatDate(si.dataFim!)),
              if (si.dataImportacao != null)
                _buildInfoRow('Data Importação', _formatDate(si.dataImportacao!)),
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



}

