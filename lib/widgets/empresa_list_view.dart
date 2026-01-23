import 'package:flutter/material.dart';
import '../models/empresa.dart';
import '../services/empresa_service.dart';
import 'empresa_form_dialog.dart';
import '../utils/responsive.dart';

class EmpresaListView extends StatefulWidget {
  const EmpresaListView({super.key});

  @override
  State<EmpresaListView> createState() => _EmpresaListViewState();
}

class _EmpresaListViewState extends State<EmpresaListView> {
  final EmpresaService _empresaService = EmpresaService();
  List<Empresa> _empresas = [];
  List<Empresa> _filteredEmpresas = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadEmpresas();
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

  Future<void> _loadEmpresas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final empresas = await _empresaService.getAllEmpresas();
      setState(() {
        _empresas = empresas;
        _filteredEmpresas = empresas;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar empresas: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar empresas: $e'),
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
        _filteredEmpresas = _empresas;
      });
    } else {
      _searchEmpresas(query);
    }
  }

  Future<void> _searchEmpresas(String query) async {
    try {
      final results = await _empresaService.searchEmpresas(query);
      setState(() {
        _filteredEmpresas = results;
      });
    } catch (e) {
      print('Erro ao buscar empresas: $e');
    }
  }

  Future<void> _createEmpresa() async {
    final result = await showDialog<Empresa>(
      context: context,
      builder: (context) => const EmpresaFormDialog(),
    );

    if (result != null) {
      final created = await _empresaService.createEmpresa(result);
      if (created != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar empresa.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateEmpresa(Empresa empresa) async {
    // Criar cópia com nome modificado
    final duplicated = empresa.copyWith(
      id: '',
      empresa: '${empresa.empresa} (Cópia)',
    );

    final result = await showDialog<Empresa>(
      context: context,
      builder: (context) => EmpresaFormDialog(empresa: duplicated),
    );

    if (result != null) {
      final created = await _empresaService.createEmpresa(result);
      if (created != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa duplicada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao duplicar empresa'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editEmpresa(Empresa empresa) async {
    // Buscar empresa atualizada do banco para garantir dados completos
    final fetchedEmpresa = await _empresaService.getEmpresaById(empresa.id);
    if (fetchedEmpresa == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar empresa para edição.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<Empresa>(
      context: context,
      builder: (context) => EmpresaFormDialog(empresa: fetchedEmpresa),
    );

    if (result != null) {
      final updated = await _empresaService.updateEmpresa(empresa.id, result);
      if (updated != null) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao atualizar empresa.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEmpresa(Empresa empresa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a empresa "${empresa.empresa}"?'),
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
      final deleted = await _empresaService.deleteEmpresa(empresa.id);
      if (deleted) {
        await _loadEmpresas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir empresa.'),
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
        title: const Text('Cadastro de Empresas'),
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
            onPressed: _createEmpresa,
            tooltip: 'Nova Empresa',
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
                labelText: 'Buscar empresas',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmpresas.isEmpty
                    ? const Center(
                        child: Text('Nenhuma empresa encontrada.'),
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
      itemCount: _filteredEmpresas.length,
      itemBuilder: (context, index) {
        final empresa = _filteredEmpresas[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: ListTile(
            title: Text(empresa.empresa),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Regional: ${empresa.regional}'),
                Text('Divisão: ${empresa.divisao}'),
                Text('Tipo: ${empresa.tipo}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editEmpresa(empresa),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.orange,
                  onPressed: () => _duplicateEmpresa(empresa),
                  tooltip: 'Duplicar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteEmpresa(empresa),
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
            DataColumn(label: Text('Empresa', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Regional', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisão', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredEmpresas.map((empresa) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    empresa.empresa,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(empresa.regional.isNotEmpty ? empresa.regional : '-')),
                DataCell(Text(empresa.divisao.isNotEmpty ? empresa.divisao : '-')),
                DataCell(Text(empresa.tipo)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editEmpresa(empresa),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.orange),
                        onPressed: () => _duplicateEmpresa(empresa),
                        tooltip: 'Duplicar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteEmpresa(empresa),
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







