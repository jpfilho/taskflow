import 'package:flutter/material.dart';
import '../models/executor.dart';
import '../services/executor_service.dart';
import 'executor_form_dialog.dart';
import '../utils/responsive.dart';

class ExecutorListView extends StatefulWidget {
  const ExecutorListView({super.key});

  @override
  State<ExecutorListView> createState() => _ExecutorListViewState();
}

class _ExecutorListViewState extends State<ExecutorListView> {
  final ExecutorService _executorService = ExecutorService();
  List<Executor> _executores = [];
  List<Executor> _filteredExecutores = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadExecutores();
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

  Future<void> _loadExecutores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final executores = await _executorService.getAllExecutores();
      setState(() {
        _executores = executores;
        _filteredExecutores = executores;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar executores: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar executores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredExecutores = _executores;
      } else {
        _filteredExecutores = _executores.where((executor) {
          return executor.nome.toLowerCase().contains(query) ||
              (executor.nomeCompleto?.toLowerCase().contains(query) ?? false) ||
              (executor.matricula?.toLowerCase().contains(query) ?? false) ||
              (executor.login?.toLowerCase().contains(query) ?? false) ||
              (executor.empresa?.toLowerCase().contains(query) ?? false) ||
              (executor.funcao?.toLowerCase().contains(query) ?? false) ||
              (executor.divisao?.toLowerCase().contains(query) ?? false) ||
              executor.segmentos.any((s) => s.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  Future<void> _createExecutor() async {
    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => const ExecutorFormDialog(),
    );

    if (result != null) {
      try {
        await _executorService.createExecutor(result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateExecutor(Executor executor) async {
    // Criar cópia com nome modificado
    final duplicated = executor.copyWith(
      id: '',
      nome: '${executor.nome} (Cópia)',
    );

    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => ExecutorFormDialog(executor: duplicated),
    );

    if (result != null) {
      try {
        await _executorService.createExecutor(result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor duplicado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao duplicar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editExecutor(Executor executor) async {
    // Buscar executor atualizado do banco para garantir dados completos
    final executorAtualizado = await _executorService.getExecutorById(executor.id);
    if (executorAtualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do executor'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<Executor>(
      context: context,
      builder: (context) => ExecutorFormDialog(executor: executorAtualizado),
    );

    if (result != null) {
      try {
        await _executorService.updateExecutor(executor.id, result);
        await _loadExecutores();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Executor atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar executor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteExecutor(Executor executor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o executor "${executor.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await _executorService.deleteExecutor(executor.id);
        if (success) {
          await _loadExecutores();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Executor excluído com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao excluir executor'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir executor: $e'),
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
        title: const Text('Cadastro de Executores'),
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
            onPressed: _createExecutor,
            tooltip: 'Adicionar Executor',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, matrícula, login, empresa, função...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Lista ou Tabela de executores
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExecutores.isEmpty
                    ? const Center(
                        child: Text('Nenhum executor encontrado'),
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
                        itemCount: _filteredExecutores.length,
                        itemBuilder: (context, index) {
                          final executor = _filteredExecutores[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      executor.nomeCompleto ?? executor.nome,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: executor.ativo
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  if (executor.matricula != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        executor.matricula!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (executor.nomeCompleto != null &&
                                      executor.nomeCompleto != executor.nome)
                                    Text('Nome: ${executor.nome}'),
                                  if (executor.login != null)
                                    Text('Login: ${executor.login}'),
                                  if (executor.empresa != null)
                                    Text('Empresa: ${executor.empresa}'),
                                  if (executor.funcao != null)
                                    Text('Função: ${executor.funcao}'),
                                  if (executor.divisao != null)
                                    Text('Divisão: ${executor.divisao}'),
                                  if (executor.segmentos.isNotEmpty)
                                    Text('Segmentos: ${executor.segmentos.join(", ")}'),
                                  if (executor.ramal != null ||
                                      executor.telefone != null)
                                    Row(
                                      children: [
                                        if (executor.ramal != null)
                                          Text('Ramal: ${executor.ramal}'),
                                        if (executor.ramal != null &&
                                            executor.telefone != null)
                                          const Text(' | '),
                                        if (executor.telefone != null)
                                          Text('Tel: ${executor.telefone}'),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: executor.ativo
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          executor.ativo ? 'Ativo' : 'Inativo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: executor.ativo
                                                ? Colors.green[800]
                                                : Colors.red[800],
                                            fontWeight: FontWeight.bold,
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
                                    onPressed: () => _editExecutor(executor),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    color: Colors.orange,
                                    onPressed: () => _duplicateExecutor(executor),
                                    tooltip: 'Duplicar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteExecutor(executor),
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
          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nome Completo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Matrícula', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Login', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Empresa', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Função', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmentos', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ramal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Telefone', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredExecutores.map((executor) {
            return DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  if (!executor.ativo) {
                    return Colors.grey[100];
                  }
                  return null;
                },
              ),
              cells: [
                DataCell(
                  Text(
                    executor.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.nomeCompleto ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.matricula ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.login ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.empresa ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.funcao ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.divisao ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.segmentos.isEmpty ? '-' : executor.segmentos.join(', '),
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.ramal ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    executor.telefone ?? '-',
                    style: TextStyle(
                      color: executor.ativo ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: executor.ativo ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      executor.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize: 12,
                        color: executor.ativo ? Colors.green[800] : Colors.red[800],
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
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editExecutor(executor),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateExecutor(executor),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteExecutor(executor),
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

