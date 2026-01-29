import 'package:flutter/material.dart';
import '../../data/models/status_album.dart';
import '../../data/repositories/status_album_repository.dart';
import 'status_album_form_dialog.dart';

class StatusAlbumListView extends StatefulWidget {
  const StatusAlbumListView({super.key});

  @override
  State<StatusAlbumListView> createState() => _StatusAlbumListViewState();
}

class _StatusAlbumListViewState extends State<StatusAlbumListView> {
  final StatusAlbumRepository _repository = StatusAlbumRepository();
  List<StatusAlbum> _statusAlbums = [];
  List<StatusAlbum> _filteredStatusAlbums = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadStatusAlbums();
    _searchController.addListener(_onSearchChanged);
    // No desktop, tabela é o padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && MediaQuery.of(context).size.width > 600) {
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

  Future<void> _loadStatusAlbums() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _repository.getAllStatusAlbums();
      setState(() {
        _statusAlbums = status;
        _filteredStatusAlbums = status;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar status de álbuns: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar status de álbuns: $e'),
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
        _filteredStatusAlbums = _statusAlbums;
      });
    } else {
      _searchStatusAlbums(query);
    }
  }

  Future<void> _searchStatusAlbums(String query) async {
    try {
      final results = await _repository.searchStatusAlbums(query);
      setState(() {
        _filteredStatusAlbums = results;
      });
    } catch (e) {
      print('Erro ao buscar status de álbuns: $e');
    }
  }

  Future<void> _createStatusAlbum() async {
    final result = await showDialog<StatusAlbum>(
      context: context,
      builder: (context) => const StatusAlbumFormDialog(),
    );

    if (result != null) {
      final created = await _repository.createStatusAlbum(result);
      if (created != null) {
        await _loadStatusAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status de álbum criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar status de álbum.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateStatusAlbum(StatusAlbum statusAlbum) async {
    // Buscar status atualizado do banco para garantir dados completos
    final statusAtualizado = await _repository.getStatusAlbumById(statusAlbum.id);
    if (statusAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do status de álbum'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Criar cópia com nome modificado
    final duplicated = statusAtualizado.copyWith(
      id: '',
      nome: '${statusAtualizado.nome} (Cópia)',
    );

    final result = await showDialog<StatusAlbum>(
      context: context,
      builder: (context) => StatusAlbumFormDialog(statusAlbum: duplicated),
    );

    if (result != null) {
      final created = await _repository.createStatusAlbum(result);
      if (created != null) {
        await _loadStatusAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status de álbum duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar status de álbum'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editStatusAlbum(StatusAlbum statusAlbum) async {
    // Buscar status atualizado do banco para garantir dados completos
    final statusAtualizado = await _repository.getStatusAlbumById(statusAlbum.id);
    if (statusAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do status de álbum'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<StatusAlbum>(
      context: context,
      builder: (context) => StatusAlbumFormDialog(statusAlbum: statusAtualizado),
    );

    if (result != null) {
      final updated = await _repository.updateStatusAlbum(statusAlbum.id, result);
      if (updated != null) {
        await _loadStatusAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status de álbum atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar status de álbum.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteStatusAlbum(StatusAlbum statusAlbum) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o status "${statusAlbum.nome}"?'),
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
      final deleted = await _repository.deleteStatusAlbum(statusAlbum.id);
      if (deleted) {
        await _loadStatusAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status de álbum excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir status de álbum.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static double _responsivePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return 12;
    if (w < 1024) return 16;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = _responsivePadding(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
      appBar: AppBar(
        title: Text(
          'Cadastro de Status de Álbuns',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1e293b) : Colors.white,
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
            onPressed: _createStatusAlbum,
            tooltip: 'Novo Status de Álbum',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar status de álbuns',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1e293b) : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStatusAlbums.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum status de álbum encontrado.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      )
                    : _isTableView
                        ? _buildTableView(context, isDark)
                        : _buildListView(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, bool isDark) {
    final padding = MediaQuery.of(context).size.width < 600 ? 12.0 : 16.0;
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: _filteredStatusAlbums.length,
      itemBuilder: (context, index) {
        final status = _filteredStatusAlbums[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                ),
              ),
              child: Center(
                child: Text(
                  status.nome.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: status.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              status.nome,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1e293b),
              ),
            ),
            subtitle: status.descricao != null
                ? Text(
                    status.descricao!,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.ativo
                        ? (isDark ? Colors.green[900] : Colors.green[100])
                        : (isDark ? Colors.red[900] : Colors.red[100]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.ativo ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: status.ativo
                          ? (isDark ? Colors.green[300] : Colors.green[800])
                          : (isDark ? Colors.red[300] : Colors.red[800]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStatusAlbum(status),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.orange,
                  onPressed: () => _duplicateStatusAlbum(status),
                  tooltip: 'Duplicar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteStatusAlbum(status),
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

  Widget _buildTableView(BuildContext context, bool isDark) {
    final padding = MediaQuery.of(context).size.width < 600 ? 12.0 : 16.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            isDark ? const Color(0xFF1e293b) : Colors.blue[50],
          ),
          columns: [
            const DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Cor de Fundo', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Cor do Texto', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredStatusAlbums.map((status) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: status.backgroundColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: status.textColor,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.nome,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(status.descricao ?? '-')),
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: status.backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.corFundo ?? '-'),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: status.textColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.corTexto ?? '-'),
                    ],
                  ),
                ),
                DataCell(Text(status.ordem.toString())),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.ativo ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize: 12,
                        color: status.ativo ? Colors.green[800] : Colors.red[800],
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
                        onPressed: () => _editStatusAlbum(status),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateStatusAlbum(status),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteStatusAlbum(status),
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
      ),
    );
  }
}
