import 'package:flutter/material.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';
import 'segmento_form_dialog.dart';
import '../utils/responsive.dart';

class SegmentoListView extends StatefulWidget {
  const SegmentoListView({super.key});

  @override
  State<SegmentoListView> createState() => _SegmentoListViewState();
}

class _SegmentoListViewState extends State<SegmentoListView> {
  final SegmentoService _segmentoService = SegmentoService();
  List<Segmento> _segmentos = [];
  List<Segmento> _filteredSegmentos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadSegmentos();
    _searchController.addListener(_onSearchChanged);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Responsive.isDesktop(context)) {
        setState(() {
          _isTableView = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      setState(() {
        _segmentos = segmentos;
        _filteredSegmentos = segmentos;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar segmentos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredSegmentos = _segmentos;
      });
    } else {
      _searchSegmentos(query);
    }
  }

  Future<void> _searchSegmentos(String query) async {
    try {
      final results = await _segmentoService.searchSegmentos(query);
      setState(() {
        _filteredSegmentos = results;
      });
    } catch (e) {
      print('Erro ao buscar segmentos: $e');
    }
  }

  Future<void> _createSegmento() async {
    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => const SegmentoFormDialog(),
    );

    if (result != null) {
      final created = await _segmentoService.createSegmento(result);
      if (created != null) {
        await _loadSegmentos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Segmento criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar segmento'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateSegmento(Segmento segmento) async {
    // Criar cópia com nome modificado
    final duplicated = segmento.copyWith(
      id: '',
      segmento: '${segmento.segmento} (Cópia)',
    );

    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => SegmentoFormDialog(segmento: duplicated),
    );

    if (result != null) {
      final created = await _segmentoService.createSegmento(result);
      if (created != null) {
        await _loadSegmentos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Segmento duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar segmento'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editSegmento(Segmento segmento) async {
    final result = await showDialog<Segmento>(
      context: context,
      builder: (context) => SegmentoFormDialog(segmento: segmento),
    );

    if (result != null) {
      final updated = await _segmentoService.updateSegmento(segmento.id, result);
      if (updated != null) {
        await _loadSegmentos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Segmento atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar segmento'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSegmento(Segmento segmento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir o segmento:\n\n'
          'Segmento: ${segmento.segmento}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _segmentoService.deleteSegmento(segmento.id);
      if (deleted) {
        await _loadSegmentos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Segmento excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir segmento'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Segmentos'),
        actions: [
          // Toggle de visualização
          IconButton(
            icon: Icon(_isTableView ? Icons.view_list : Icons.table_chart),
            onPressed: () {
              setState(() {
                _isTableView = !_isTableView;
              });
            },
            tooltip: _isTableView ? 'Visualização em Lista' : 'Visualização em Tabela',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSegmentos,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca e botão criar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por segmento ou descrição...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createSegmento,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Segmento'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista ou Tabela de segmentos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSegmentos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _segmentos.isEmpty
                                  ? 'Nenhum segmento cadastrado'
                                  : 'Nenhum segmento encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_segmentos.isEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createSegmento,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar Primeiro Segmento'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _isTableView
                        ? _buildTableView()
                        : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
                        itemCount: _filteredSegmentos.length,
                        itemBuilder: (context, index) {
                          final segmento = _filteredSegmentos[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: segmento.backgroundColor,
                                child: Icon(
                                  Icons.category,
                                  color: segmento.textColor,
                                ),
                              ),
                              title: Text(
                                segmento.segmento,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: segmento.textColor,
                                ),
                              ),
                              subtitle: segmento.descricao != null &&
                                      segmento.descricao!.isNotEmpty
                                  ? Text(segmento.descricao!)
                                  : const Text(
                                      'Sem descrição',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () => _editSegmento(segmento),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    color: Colors.orange,
                                    onPressed: () => _duplicateSegmento(segmento),
                                    tooltip: 'Duplicar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteSegmento(segmento),
                                    tooltip: 'Excluir',
                                  ),
                                ],
                              ),
                            ),
                          );
        },
      );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Segmento', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Cor de Fundo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Cor do Texto', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredSegmentos.map((segmento) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    segmento.segmento,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text(
                    segmento.descricao != null && segmento.descricao!.isNotEmpty
                        ? segmento.descricao!
                        : 'Sem descrição',
                    style: TextStyle(
                      fontStyle: segmento.descricao != null && segmento.descricao!.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: segmento.descricao != null && segmento.descricao!.isNotEmpty
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: segmento.backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        segmento.cor ?? '#808080',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: segmento.textColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        segmento.corTexto ?? '#FFFFFF',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editSegmento(segmento),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateSegmento(segmento),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteSegmento(segmento),
                        tooltip: 'Excluir',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}







