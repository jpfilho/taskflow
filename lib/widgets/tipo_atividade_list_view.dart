import 'package:flutter/material.dart';
import '../models/tipo_atividade.dart';
import '../services/tipo_atividade_service.dart';
import 'tipo_atividade_form_dialog.dart';
import '../utils/responsive.dart';

class TipoAtividadeListView extends StatefulWidget {
  const TipoAtividadeListView({super.key});

  @override
  State<TipoAtividadeListView> createState() => _TipoAtividadeListViewState();
}

class _TipoAtividadeListViewState extends State<TipoAtividadeListView> {
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  List<TipoAtividade> _tiposAtividade = [];
  List<TipoAtividade> _filteredTiposAtividade = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadTiposAtividade();
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

  Future<void> _loadTiposAtividade() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tipos = await _tipoAtividadeService.getAllTiposAtividade();
      setState(() {
        _tiposAtividade = tipos;
        _filteredTiposAtividade = tipos;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar tipos de atividade: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tipos de atividade: $e'),
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
        _filteredTiposAtividade = _tiposAtividade;
      });
    } else {
      _searchTiposAtividade(query);
    }
  }

  Future<void> _searchTiposAtividade(String query) async {
    try {
      final results = await _tipoAtividadeService.searchTiposAtividade(query);
      setState(() {
        _filteredTiposAtividade = results;
      });
    } catch (e) {
      print('Erro ao buscar tipos de atividade: $e');
    }
  }

  Future<void> _createTipoAtividade() async {
    final result = await showDialog<TipoAtividade>(
      context: context,
      builder: (context) => const TipoAtividadeFormDialog(),
    );

    if (result != null) {
      final created = await _tipoAtividadeService.createTipoAtividade(result);
      if (created != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateTipoAtividade(TipoAtividade tipoAtividade) async {
    // Buscar tipo atualizado do banco para garantir dados completos
    final tipoAtualizado = await _tipoAtividadeService.getTipoAtividadeById(tipoAtividade.id);
    if (tipoAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do tipo de atividade'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Criar cópia com código e descrição modificados
    final duplicated = tipoAtualizado.copyWith(
      id: '',
      codigo: '${tipoAtualizado.codigo}CP', // Adicionar sufixo ao código
      descricao: '${tipoAtualizado.descricao} (Cópia)',
    );

    final result = await showDialog<TipoAtividade>(
      context: context,
      builder: (context) => TipoAtividadeFormDialog(tipoAtividade: duplicated),
    );

    if (result != null) {
      final created = await _tipoAtividadeService.createTipoAtividade(result);
      if (created != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar tipo de atividade'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editTipoAtividade(TipoAtividade tipoAtividade) async {
    // Buscar tipo atualizado do banco para garantir dados completos
    final tipoAtualizado = await _tipoAtividadeService.getTipoAtividadeById(tipoAtividade.id);
    if (tipoAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do tipo de atividade'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<TipoAtividade>(
      context: context,
      builder: (context) => TipoAtividadeFormDialog(tipoAtividade: tipoAtualizado),
    );

    if (result != null) {
      final updated = await _tipoAtividadeService.updateTipoAtividade(tipoAtividade.id, result);
      if (updated != null) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar tipo de atividade.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTipoAtividade(TipoAtividade tipoAtividade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o tipo de atividade "${tipoAtividade.codigo} - ${tipoAtividade.descricao}"?'),
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
      final deleted = await _tipoAtividadeService.deleteTipoAtividade(tipoAtividade.id);
      if (deleted) {
        await _loadTiposAtividade();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo de atividade excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir tipo de atividade.'),
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
        title: const Text('Cadastro de Tipos de Atividade'),
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
            icon: const Icon(Icons.add),
            onPressed: _createTipoAtividade,
            tooltip: 'Novo Tipo de Atividade',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar tipos de atividade',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTiposAtividade.isEmpty
                    ? const Center(
                        child: Text('Nenhum tipo de atividade encontrado.'),
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
      itemCount: _filteredTiposAtividade.length,
      itemBuilder: (context, index) {
        final tipo = _filteredTiposAtividade[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: ListTile(
            title: Text('${tipo.codigo} - ${tipo.descricao}'),
            subtitle: tipo.segmentos.isNotEmpty
                ? Text('Segmentos: ${tipo.segmentos.join(", ")}')
                : const Text('Sem segmentos associados'),
            leading: tipo.ativo
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.red),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editTipoAtividade(tipo),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.orange,
                  onPressed: () => _duplicateTipoAtividade(tipo),
                  tooltip: 'Duplicar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteTipoAtividade(tipo),
                  tooltip: 'Excluir',
                  color: Colors.red,
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
            DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmentos', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredTiposAtividade.map((tipo) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    tipo.codigo,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(tipo.descricao)),
                DataCell(
                  Text(
                    tipo.segmentos.isNotEmpty
                        ? tipo.segmentos.join(', ')
                        : 'Sem segmentos',
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tipo.ativo ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tipo.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize: 12,
                        color: tipo.ativo ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editTipoAtividade(tipo),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateTipoAtividade(tipo),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteTipoAtividade(tipo),
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







