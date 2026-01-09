import 'package:flutter/material.dart';
import '../models/equipe.dart';
import '../services/equipe_service.dart';
import 'equipe_form_dialog.dart';
import '../utils/responsive.dart';

class EquipeListView extends StatefulWidget {
  const EquipeListView({super.key});

  @override
  State<EquipeListView> createState() => _EquipeListViewState();
}

class _EquipeListViewState extends State<EquipeListView> {
  final EquipeService _equipeService = EquipeService();
  List<Equipe> _equipes = [];
  List<Equipe> _filteredEquipes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadEquipes();
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

  Future<void> _loadEquipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final equipes = await _equipeService.getAllEquipes();
      setState(() {
        _equipes = equipes;
        _filteredEquipes = equipes;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar equipes: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar equipes: $e'),
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
        _filteredEquipes = _equipes;
      });
    } else {
      _searchEquipes(query);
    }
  }

  Future<void> _searchEquipes(String query) async {
    try {
      final results = await _equipeService.searchEquipes(query);
      setState(() {
        _filteredEquipes = results;
      });
    } catch (e) {
      print('Erro ao buscar equipes: $e');
    }
  }

  Future<void> _createEquipe() async {
    final result = await showDialog<Equipe>(
      context: context,
      builder: (context) => const EquipeFormDialog(),
    );

    if (result != null) {
      final created = await _equipeService.createEquipe(result);
      if (created != null) {
        await _loadEquipes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipe criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar equipe.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editEquipe(Equipe equipe) async {
    // Buscar equipe atualizada do banco para garantir dados completos
    final equipeAtualizada = await _equipeService.getEquipeById(equipe.id);
    if (equipeAtualizada == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados da equipe'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<Equipe>(
      context: context,
      builder: (context) => EquipeFormDialog(equipe: equipeAtualizada),
    );

    if (result != null) {
      final updated = await _equipeService.updateEquipe(equipe.id, result);
      if (updated != null) {
        await _loadEquipes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipe atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar equipe.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEquipe(Equipe equipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a equipe "${equipe.nome}"?'),
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
      final deleted = await _equipeService.deleteEquipe(equipe.id);
      if (deleted) {
        await _loadEquipes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipe excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir equipe.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getTipoLabel(String tipo) {
    return tipo == 'FIXA' ? 'Fixa' : 'Flexível';
  }

  String _getPapelLabel(String papel) {
    switch (papel) {
      case 'FISCAL':
        return 'Fiscal';
      case 'TST':
        return 'TST';
      case 'ENCARREGADO':
        return 'Encarregado';
      case 'EXECUTOR':
        return 'Executor';
      default:
        return papel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Equipes'),
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
            onPressed: _createEquipe,
            tooltip: 'Nova Equipe',
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
                labelText: 'Buscar equipes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEquipes.isEmpty
                    ? const Center(
                        child: Text('Nenhuma equipe encontrada.'),
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
      itemCount: _filteredEquipes.length,
      itemBuilder: (context, index) {
        final equipe = _filteredEquipes[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: ExpansionTile(
            leading: equipe.ativo
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.red),
            title: Text(equipe.nome),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: ${_getTipoLabel(equipe.tipo)}'),
                if (equipe.regional != null)
                  Text('Regional: ${equipe.regional}'),
                if (equipe.divisao != null)
                  Text('Divisão: ${equipe.divisao}'),
                if (equipe.segmento != null)
                  Text('Segmento: ${equipe.segmento}'),
                if (equipe.descricao != null && equipe.descricao!.isNotEmpty)
                  Text(equipe.descricao!),
                Text('Executores: ${equipe.executores.length}'),
              ],
            ),
            children: [
              if (equipe.executores.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhum executor cadastrado',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...equipe.executores.map((equipeExecutor) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      _getPapelIcon(equipeExecutor.papel),
                      size: 20,
                    ),
                    title: Text(equipeExecutor.executorNome),
                    trailing: Chip(
                      label: Text(
                        _getPapelLabel(equipeExecutor.papel),
                        style: const TextStyle(fontSize: 12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  );
                }),
            ],
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editEquipe(equipe),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteEquipe(equipe),
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
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmento', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Executores', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredEquipes.map((equipe) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    equipe.nome,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(_getTipoLabel(equipe.tipo))),
                DataCell(Text(equipe.regional ?? '-')),
                DataCell(Text(equipe.divisao ?? '-')),
                DataCell(Text(equipe.segmento ?? '-')),
                DataCell(Text('${equipe.executores.length}')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: equipe.ativo ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      equipe.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize: 12,
                        color: equipe.ativo ? Colors.green[800] : Colors.red[800],
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
                        onPressed: () => _editEquipe(equipe),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteEquipe(equipe),
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

  IconData _getPapelIcon(String papel) {
    switch (papel) {
      case 'FISCAL':
        return Icons.gavel;
      case 'TST':
        return Icons.health_and_safety;
      case 'ENCARREGADO':
        return Icons.badge;
      case 'EXECUTOR':
        return Icons.person;
      default:
        return Icons.person;
    }
  }
}

