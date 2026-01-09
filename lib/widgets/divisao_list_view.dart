import 'package:flutter/material.dart';
import '../models/divisao.dart';
import '../services/divisao_service.dart';
import 'divisao_form_dialog.dart';
import '../utils/responsive.dart';

class DivisaoListView extends StatefulWidget {
  const DivisaoListView({super.key});

  @override
  State<DivisaoListView> createState() => _DivisaoListViewState();
}

class _DivisaoListViewState extends State<DivisaoListView> {
  final DivisaoService _divisaoService = DivisaoService();
  List<Divisao> _divisoes = [];
  List<Divisao> _filteredDivisoes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadDivisoes();
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

  Future<void> _loadDivisoes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final divisoes = await _divisaoService.getAllDivisoes();
      setState(() {
        _divisoes = divisoes;
        _filteredDivisoes = divisoes;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar divisões: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar divisões: $e'),
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
        _filteredDivisoes = _divisoes;
      });
    } else {
      _searchDivisoes(query);
    }
  }

  Future<void> _searchDivisoes(String query) async {
    try {
      final results = await _divisaoService.searchDivisoes(query);
      setState(() {
        _filteredDivisoes = results;
      });
    } catch (e) {
      print('Erro ao buscar divisões: $e');
    }
  }

  Future<void> _createDivisao() async {
    print('🔍 DEBUG: Abrindo diálogo de criação de divisão...');
    try {
      final result = await showDialog<Divisao>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          try {
            return const DivisaoFormDialog();
          } catch (e, stackTrace) {
            print('❌ Erro ao construir DivisaoFormDialog: $e');
            print('❌ Stack trace: $stackTrace');
            return AlertDialog(
              title: const Text('Erro'),
              content: Text('Erro ao abrir formulário: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          }
        },
      );

      if (result != null) {
        try {
          final created = await _divisaoService.createDivisao(result);
          if (created != null) {
            await _loadDivisoes();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Divisão criada com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          print('❌ Erro ao criar divisão (UI): $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.toString().replaceFirst('Exception: ', '').replaceFirst('PostgrestException: ', ''),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao abrir diálogo de divisão: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir formulário: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _editDivisao(Divisao divisao) async {
    final result = await showDialog<Divisao>(
      context: context,
      builder: (context) => DivisaoFormDialog(divisao: divisao),
    );

    if (result != null) {
      try {
        final updated = await _divisaoService.updateDivisao(divisao.id, result);
        if (updated != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Divisão atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Erro ao atualizar divisão (UI): $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', '').replaceFirst('PostgrestException: ', ''),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }


  Future<void> _deleteDivisao(Divisao divisao) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir a divisão:\n\n'
          'Divisão: ${divisao.divisao}\n'
          'Regional: ${divisao.regional}\n'
          'Segmentos: ${divisao.segmentos.isEmpty ? "Nenhum" : divisao.segmentos.join(", ")}',
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
      final deleted = await _divisaoService.deleteDivisao(divisao.id);
      if (deleted) {
        await _loadDivisoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Divisão excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir divisão'),
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
        title: const Text('Cadastro de Divisões'),
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
            onPressed: _loadDivisoes,
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
                      hintText: 'Buscar por divisão, regional ou segmento...',
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
                  onPressed: _createDivisao,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Divisão'),
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
          // Lista ou Tabela de divisões
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDivisoes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _divisoes.isEmpty
                                  ? 'Nenhuma divisão cadastrada'
                                  : 'Nenhuma divisão encontrada',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_divisoes.isEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createDivisao,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar Primeira Divisão'),
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
      itemCount: _filteredDivisoes.length,
      itemBuilder: (context, index) {
        final divisao = _filteredDivisoes[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(
                Icons.business,
                color: Colors.orange[700],
              ),
            ),
            title: Text(
              divisao.divisao,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Regional: ${divisao.regional}'),
                Text(
                  divisao.segmentos.isEmpty
                      ? 'Segmentos: Nenhum'
                      : 'Segmentos: ${divisao.segmentos.join(", ")}',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.blue,
                  onPressed: () => _editDivisao(divisao),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _deleteDivisao(divisao),
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
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmentos', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredDivisoes.map((divisao) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    divisao.divisao,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(divisao.regional.isNotEmpty ? divisao.regional : '-')),
                DataCell(
                  Text(
                    divisao.segmentos.isEmpty
                        ? 'Nenhum'
                        : divisao.segmentos.join(', '),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editDivisao(divisao),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteDivisao(divisao),
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

