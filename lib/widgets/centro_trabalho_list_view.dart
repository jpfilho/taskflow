import 'package:flutter/material.dart';
import '../models/centro_trabalho.dart';
import '../services/centro_trabalho_service.dart';
import 'centro_trabalho_form_dialog.dart';
import '../utils/responsive.dart';

class CentroTrabalhoListView extends StatefulWidget {
  const CentroTrabalhoListView({super.key});

  @override
  State<CentroTrabalhoListView> createState() => _CentroTrabalhoListViewState();
}

class _CentroTrabalhoListViewState extends State<CentroTrabalhoListView> {
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();
  List<CentroTrabalho> _centrosTrabalho = [];
  List<CentroTrabalho> _filteredCentrosTrabalho = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadCentrosTrabalho();
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

  Future<void> _loadCentrosTrabalho() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final centrosTrabalho = await _centroTrabalhoService.getAllCentrosTrabalho();
      setState(() {
        _centrosTrabalho = centrosTrabalho;
        _filteredCentrosTrabalho = centrosTrabalho;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar locais: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar locais: $e'),
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
        _filteredCentrosTrabalho = _centrosTrabalho;
      });
    } else {
      _searchCentrosTrabalho(query);
    }
  }

  Future<void> _searchCentrosTrabalho(String query) async {
    try {
      final results = await _centroTrabalhoService.searchCentrosTrabalho(query);
      setState(() {
        _filteredCentrosTrabalho = results;
      });
    } catch (e) {
      print('Erro ao buscar locais: $e');
    }
  }

  Future<void> _createCentroTrabalho() async {
    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => const CentroTrabalhoFormDialog(),
    );

    if (result != null) {
      final created = await _centroTrabalhoService.createCentroTrabalho(result);
      if (created.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Centro de Trabalho criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar centro de trabalho'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateCentroTrabalho(CentroTrabalho centroTrabalho) async {
    // Criar cópia com nome modificado
    final duplicated = centroTrabalho.copyWith(
      id: '',
      centroTrabalho: '${centroTrabalho.centroTrabalho} (Cópia)',
    );

    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => CentroTrabalhoFormDialog(centroTrabalho: duplicated),
    );

    if (result != null) {
      final created = await _centroTrabalhoService.createCentroTrabalho(result);
      if (created.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Centro de Trabalho duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar centro de trabalho'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editCentroTrabalho(CentroTrabalho centroTrabalho) async {
    final result = await showDialog<CentroTrabalho>(
      context: context,
      builder: (context) => CentroTrabalhoFormDialog(centroTrabalho: centroTrabalho),
    );

    if (result != null) {
      final updated = await _centroTrabalhoService.updateCentroTrabalho(result);
      if (updated.id.isNotEmpty) {
        await _loadCentrosTrabalho();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Centro de Trabalho atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar centro de trabalho'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCentroTrabalho(CentroTrabalho centroTrabalho) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir o centro de trabalho:\n\n'
          'Centro de Trabalho: ${centroTrabalho.centroTrabalho}\n'
          'Vínculos: ${_getVinculosDescricao(centroTrabalho)}',
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
      final deleted = await _centroTrabalhoService.deleteCentroTrabalho(centroTrabalho.id);
      if (deleted) {
        await _loadCentrosTrabalho();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Centro de Trabalho excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir centro de trabalho'),
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
        title: const Text('Cadastro de Centros de Trabalho'),
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
            onPressed: _loadCentrosTrabalho,
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
                      hintText: 'Buscar por centroTrabalho ou descrição...',
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
                  onPressed: _createCentroTrabalho,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo CentroTrabalho'),
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
          // Lista ou Tabela de locais
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCentrosTrabalho.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.place,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _centrosTrabalho.isEmpty
                                  ? 'Nenhum centroTrabalho cadastrado'
                                  : 'Nenhum centroTrabalho encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_centrosTrabalho.isEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createCentroTrabalho,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar Primeiro CentroTrabalho'),
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

  String _getVinculosDescricao(CentroTrabalho centroTrabalho) {
    final partes = <String>[];
    if (centroTrabalho.regional != null && centroTrabalho.regional!.isNotEmpty) {
      partes.add('Regional: ${centroTrabalho.regional}');
    }
    if (centroTrabalho.divisao != null && centroTrabalho.divisao!.isNotEmpty) {
      partes.add('Divisão: ${centroTrabalho.divisao}');
    }
    if (centroTrabalho.segmento != null && centroTrabalho.segmento!.isNotEmpty) {
      partes.add('Segmento: ${centroTrabalho.segmento}');
    }
    return partes.isEmpty ? 'Sem vínculos' : partes.join(', ');
  }

  Widget _buildListView() {
    return ListView.builder(
                        itemCount: _filteredCentrosTrabalho.length,
                        itemBuilder: (context, index) {
                          final centroTrabalho = _filteredCentrosTrabalho[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Icon(
                                  Icons.work,
                                  color: Colors.blue[700],
                                ),
                              ),
                              title: Text(
                                centroTrabalho.centroTrabalho,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (centroTrabalho.descricao != null && centroTrabalho.descricao!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        centroTrabalho.descricao!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  if (centroTrabalho.gpm != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.numbers,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'GPM: ${centroTrabalho.gpm}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _getVinculosDescricao(centroTrabalho),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () => _editCentroTrabalho(centroTrabalho),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    color: Colors.orange,
                                    onPressed: () => _duplicateCentroTrabalho(centroTrabalho),
                                    tooltip: 'Duplicar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteCentroTrabalho(centroTrabalho),
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
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Centro de Trabalho', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmento', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredCentrosTrabalho.map((centroTrabalho) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    centroTrabalho.centroTrabalho,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text(
                    centroTrabalho.descricao != null && centroTrabalho.descricao!.isNotEmpty
                        ? centroTrabalho.descricao!
                        : '-',
                  ),
                ),
                DataCell(
                  Text(
                    centroTrabalho.gpm != null ? centroTrabalho.gpm!.toString() : '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(centroTrabalho.regional?.isNotEmpty == true ? centroTrabalho.regional! : '-')),
                DataCell(Text(centroTrabalho.divisao?.isNotEmpty == true ? centroTrabalho.divisao! : '-')),
                DataCell(Text(centroTrabalho.segmento?.isNotEmpty == true ? centroTrabalho.segmento! : '-')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editCentroTrabalho(centroTrabalho),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateCentroTrabalho(centroTrabalho),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteCentroTrabalho(centroTrabalho),
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







