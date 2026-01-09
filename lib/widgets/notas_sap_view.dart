import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../models/nota_sap.dart';
import '../services/nota_sap_service.dart';
import '../utils/responsive.dart';

class NotasSAPView extends StatefulWidget {
  const NotasSAPView({super.key});

  @override
  State<NotasSAPView> createState() => _NotasSAPViewState();
}

class _NotasSAPViewState extends State<NotasSAPView> {
  final NotaSAPService _service = NotaSAPService();
  List<NotaSAP> _notas = [];
  bool _isLoading = false;
  String? _filtroStatus;
  String? _filtroLocal;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  int _totalNotas = 0;
  int _paginaAtual = 0;
  final int _itensPorPagina = 50;
  List<String> _statusDisponiveis = [];
  List<String> _locaisDisponiveis = [];
  bool _visualizacaoTabela = false; // false = cards, true = tabela

  @override
  void initState() {
    super.initState();
    _loadFiltros();
    _loadNotas();
  }

  Future<void> _loadFiltros() async {
    final valores = await _service.getValoresFiltros();
    setState(() {
      _statusDisponiveis = valores['status'] ?? [];
      _locaisDisponiveis = valores['local'] ?? [];
    });
  }

  Future<void> _loadNotas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notas = await _service.getAllNotas(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        limit: _itensPorPagina,
        offset: _paginaAtual * _itensPorPagina,
      );

      final total = await _service.contarNotas(
        filtroStatus: _filtroStatus,
        filtroLocal: _filtroLocal,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
      );

      setState(() {
        _notas = notas;
        _totalNotas = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar notas: $e'),
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
    
    // Tentar decodificar como UTF-8 sem allowMalformed primeiro
    try {
      final utf8Result = utf8.decode(bytes);
      print('✅ Arquivo decodificado como UTF-8');
      return utf8Result;
    } catch (e) {
      print('⚠️ Erro ao decodificar UTF-8: $e');
      print('   Tentando com allowMalformed e removendo caracteres de substituição...');
      
      // Se falhar, tentar com allowMalformed e remover caracteres de substituição
      try {
        final utf8Malformed = utf8.decode(bytes, allowMalformed: true);
        // Remover caracteres de substituição () que foram inseridos por bytes malformados
        final cleaned = utf8Malformed.replaceAll('', '');
        
        if (cleaned.length < utf8Malformed.length) {
          print('⚠️ Removidos ${utf8Malformed.length - cleaned.length} caracteres de substituição do arquivo');
        }
        
        print('✅ Arquivo decodificado como UTF-8 (com limpeza)');
        return cleaned;
      } catch (e2) {
        print('❌ Erro ao decodificar UTF-8 com allowMalformed: $e2');
        // Último recurso: Latin-1
        try {
          final latin1Result = latin1.decode(bytes);
          print('⚠️ Fallback: Arquivo decodificado como Latin-1');
          return latin1Result;
        } catch (e3) {
          print('❌ Erro ao decodificar como Latin-1: $e3');
          // Último recurso absoluto: UTF-8 com allowMalformed e remover caracteres de substituição
          return utf8.decode(bytes, allowMalformed: true).replaceAll('', '');
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
          csvContent = _decodeBytes(bytes);
        }

        setState(() {
          _isLoading = true;
        });

        final resultado = await _service.importarNotasDoCSV(csvContent);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resultado['sucesso'] == true
                    ? 'Importação concluída: ${resultado['importadas']} notas importadas, ${resultado['duplicatas']} duplicatas ignoradas'
                    : 'Erro na importação: ${resultado['erro']}',
              ),
              backgroundColor: resultado['sucesso'] == true ? Colors.green : Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        if (resultado['sucesso'] == true) {
          _loadFiltros();
          _loadNotas();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

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
                  'Notas SAP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      _filtroStatus = null;
                      _filtroLocal = null;
                      _dataInicio = null;
                      _dataFim = null;
                      _paginaAtual = 0;
                    });
                    _loadNotas();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),

          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Filtro Status
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    value: _filtroStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status Sistema',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        const Text('Todos'),
                        ..._statusDisponiveis.map((status) => Text(
                              status.length > 25 ? '${status.substring(0, 25)}...' : status,
                              overflow: TextOverflow.ellipsis,
                            )),
                      ];
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._statusDisponiveis.map((status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroStatus = value;
                        _paginaAtual = 0;
                      });
                      _loadNotas();
                    },
                  ),
                ),

                // Filtro Local
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: DropdownButtonFormField<String>(
                    value: _filtroLocal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Local de Instalação',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        const Text('Todos'),
                        ..._locaisDisponiveis.map((local) => Text(
                              local.length > 30 ? '${local.substring(0, 30)}...' : local,
                              overflow: TextOverflow.ellipsis,
                            )),
                      ];
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ..._locaisDisponiveis.map((local) => DropdownMenuItem<String>(
                            value: local,
                            child: Text(local.length > 40 ? '${local.substring(0, 40)}...' : local),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroLocal = value;
                        _paginaAtual = 0;
                      });
                      _loadNotas();
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
                        _loadNotas();
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
                        _loadNotas();
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
                        _filtroStatus = null;
                        _filtroLocal = null;
                        _dataInicio = null;
                        _dataFim = null;
                        _paginaAtual = 0;
                      });
                      _loadNotas();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar'),
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
                  'Total: $_totalNotas notas',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Text(
                  'Página ${_paginaAtual + 1} de ${(_totalNotas / _itensPorPagina).ceil()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Lista de notas (Cards ou Tabela)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notas.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma nota encontrada',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _visualizacaoTabela
                        ? _buildTabelaView()
                        : ListView.builder(
                            itemCount: _notas.length,
                            itemBuilder: (context, index) {
                              final nota = _notas[index];
                              return _buildNotaCard(nota);
                            },
                          ),
          ),

          // Paginação
          if (_totalNotas > _itensPorPagina)
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
                            _loadNotas();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Página ${_paginaAtual + 1} de ${(_totalNotas / _itensPorPagina).ceil()}'),
                  IconButton(
                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _totalNotas
                        ? () {
                            setState(() {
                              _paginaAtual++;
                            });
                            _loadNotas();
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

  Widget _buildNotaCard(NotaSAP nota) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(nota.statusSistema),
          child: Text(
            nota.tipo ?? '?',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          'Nota: ${nota.nota}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nota.descricao != null)
              Text(
                nota.descricao!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (nota.criadoEm != null)
                  Text(
                    'Criado: ${_formatDate(nota.criadoEm!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (nota.statusSistema != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(nota.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      nota.statusSistema!,
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
                _buildInfoRow('Tipo', nota.tipo),
                _buildInfoRow('Prioridade', nota.textPrioridade),
                _buildInfoRow('Ordem', nota.ordem),
                _buildInfoRow('Local', nota.localInstalacao),
                _buildInfoRow('Sala', nota.sala),
                _buildInfoRow('Equipamento', nota.equipamento),
                _buildInfoRow('Status Usuário', nota.statusUsuario),
                _buildInfoRow('Centro', nota.centro),
                _buildInfoRow('Executor', nota.denominacaoExecutor),
                if (nota.inicioDesejado != null)
                  _buildInfoRow('Início Desejado', _formatDate(nota.inicioDesejado!)),
                if (nota.conclusaoDesejada != null)
                  _buildInfoRow('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
                if (nota.dataReferencia != null)
                  _buildInfoRow('Data Referência', _formatDate(nota.dataReferencia!)),
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('MSPR')) return Colors.orange;
    if (status.contains('MSPN')) return Colors.blue;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildTabelaView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Nota', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Criado em', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Prioridade', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Início Desejado', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Conclusão Desejada', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Executor', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _notas.map((nota) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    nota.nota,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _mostrarDetalhesNota(nota),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(nota.tipo ?? '-'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      nota.descricao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(nota.statusSistema),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      nota.statusSistema ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      nota.localInstalacao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(nota.criadoEm != null ? _formatDate(nota.criadoEm!) : '-'),
                ),
                DataCell(Text(nota.textPrioridade ?? '-')),
                DataCell(
                  Text(nota.inicioDesejado != null ? _formatDate(nota.inicioDesejado!) : '-'),
                ),
                DataCell(
                  Text(nota.conclusaoDesejada != null ? _formatDate(nota.conclusaoDesejada!) : '-'),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      nota.denominacaoExecutor ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  void _mostrarDetalhesNota(NotaSAP nota) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalhes da Nota SAP: ${nota.nota}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Tipo', nota.tipo),
              _buildInfoRow('Descrição', nota.descricao),
              _buildInfoRow('Status Sistema', nota.statusSistema),
              _buildInfoRow('Status Usuário', nota.statusUsuario),
              _buildInfoRow('Prioridade', nota.textPrioridade),
              _buildInfoRow('Ordem', nota.ordem),
              _buildInfoRow('Local de Instalação', nota.localInstalacao),
              _buildInfoRow('Sala', nota.sala),
              _buildInfoRow('Equipamento', nota.equipamento),
              _buildInfoRow('Centro', nota.centro),
              _buildInfoRow('Centro Trabalho Responsável', nota.centroTrabalhoResponsavel),
              _buildInfoRow('Executor', nota.denominacaoExecutor),
              _buildInfoRow('GPM', nota.gpm),
              if (nota.criadoEm != null)
                _buildInfoRow('Criado em', _formatDate(nota.criadoEm!)),
              if (nota.inicioDesejado != null)
                _buildInfoRow('Início Desejado', _formatDate(nota.inicioDesejado!)),
              if (nota.conclusaoDesejada != null)
                _buildInfoRow('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
              if (nota.dataReferencia != null)
                _buildInfoRow('Data Referência', _formatDate(nota.dataReferencia!)),
              if (nota.inicioAvaria != null)
                _buildInfoRow('Início Avaria', _formatDate(nota.inicioAvaria!)),
              if (nota.fimAvaria != null)
                _buildInfoRow('Fim Avaria', _formatDate(nota.fimAvaria!)),
              if (nota.encerramento != null)
                _buildInfoRow('Encerramento', _formatDate(nota.encerramento!)),
              if (nota.modificadoEm != null)
                _buildInfoRow('Modificado em', _formatDate(nota.modificadoEm!)),
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

