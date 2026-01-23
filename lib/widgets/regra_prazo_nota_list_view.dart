import 'package:flutter/material.dart';
import '../models/regra_prazo_nota.dart';
import '../services/regra_prazo_nota_service.dart';
import '../services/segmento_service.dart';
import '../models/segmento.dart';
import 'regra_prazo_nota_form_dialog.dart';
import '../utils/responsive.dart';

class RegraPrazoNotaListView extends StatefulWidget {
  const RegraPrazoNotaListView({super.key});

  @override
  State<RegraPrazoNotaListView> createState() => _RegraPrazoNotaListViewState();
}

class _RegraPrazoNotaListViewState extends State<RegraPrazoNotaListView> {
  final RegraPrazoNotaService _service = RegraPrazoNotaService();
  final SegmentoService _segmentoService = SegmentoService();
  List<RegraPrazoNota> _regrasList = [];
  List<RegraPrazoNota> _filteredRegrasList = [];
  Map<String, Segmento> _segmentosMap = {}; // Cache de segmentos por ID
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false; // false = lista (cards), true = tabela

  @override
  void initState() {
    super.initState();
    _loadRegras();
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

  Future<void> _loadRegras() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar regras e segmentos em paralelo
      final results = await Future.wait([
        _service.getAllRegras(),
        _segmentoService.getAllSegmentos(),
      ]);
      
      final regrasList = results[0] as List<RegraPrazoNota>;
      final segmentosList = results[1] as List<Segmento>;
      
      // Criar mapa de segmentos por ID
      final segmentosMap = <String, Segmento>{};
      for (var segmento in segmentosList) {
        segmentosMap[segmento.id] = segmento;
      }
      
      setState(() {
        _regrasList = regrasList;
        _filteredRegrasList = regrasList;
        _segmentosMap = segmentosMap;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar regras de prazo: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar regras de prazo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  String _getSegmentosNomes(List<String> segmentoIds) {
    if (segmentoIds.isEmpty) return 'Todos os Segmentos';
    final nomes = segmentoIds
        .map((id) => _segmentosMap[id]?.segmento ?? 'Segmento não encontrado')
        .join(', ');
    return nomes;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredRegrasList = _regrasList;
      });
    } else {
      setState(() {
        _filteredRegrasList = _regrasList.where((regra) {
          final segmentosNomes = _getSegmentosNomes(regra.segmentoIds).toLowerCase();
          return regra.prioridade.toLowerCase().contains(query) ||
              regra.dataReferenciaLabel.toLowerCase().contains(query) ||
              segmentosNomes.contains(query) ||
              (regra.descricao?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  Future<void> _createRegra() async {
    final result = await showDialog<RegraPrazoNota>(
      context: context,
      builder: (context) => const RegraPrazoNotaFormDialog(),
    );

    if (result != null) {
      try {
        final created = await _service.createRegra(result);
        if (created != null) {
          await _loadRegras();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regra de prazo criada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao criar regra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editRegra(RegraPrazoNota regra) async {
    final result = await showDialog<RegraPrazoNota>(
      context: context,
      builder: (context) => RegraPrazoNotaFormDialog(regra: regra),
    );

    if (result != null) {
      try {
        final updated = await _service.updateRegra(regra.id, result);
        if (updated != null) {
          await _loadRegras();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regra de prazo atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar regra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRegra(RegraPrazoNota regra) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir a regra de prazo?\n\n'
          'Prioridade: ${regra.prioridade}\n'
          'Dias de Prazo: ${regra.diasPrazo}\n'
          'Data de Referência: ${regra.dataReferenciaLabel}',
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
      final deleted = await _service.deleteRegra(regra.id);
      if (deleted) {
        await _loadRegras();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Regra de prazo excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir regra de prazo'),
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
        title: const Text('Regras de Prazo para Notas'),
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
            onPressed: _loadRegras,
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
                      hintText: 'Buscar por prioridade ou data de referência...',
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
                  onPressed: _createRegra,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Regra'),
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
          // Lista de regras
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRegrasList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _regrasList.isEmpty
                                  ? 'Nenhuma regra de prazo cadastrada'
                                  : 'Nenhuma regra encontrada',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_regrasList.isEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createRegra,
                                icon: const Icon(Icons.add),
                                label: const Text('Criar Primeira Regra'),
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
      itemCount: _filteredRegrasList.length,
      itemBuilder: (context, index) {
        final regra = _filteredRegrasList[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: regra.ativo ? Colors.green : Colors.grey,
              child: Icon(
                regra.ativo ? Icons.check : Icons.block,
                color: Colors.white,
              ),
            ),
            title: Text(
              regra.prioridade,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Prazo: ${regra.diasPrazo} dias'),
                Text('Referência: ${regra.dataReferenciaLabel}'),
                Text('Segmentos: ${_getSegmentosNomes(regra.segmentoIds)}'),
                if (regra.descricao != null && regra.descricao!.isNotEmpty)
                  Text(
                    regra.descricao!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: regra.ativo ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    regra.ativo ? 'Ativa' : 'Inativa',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: regra.ativo ? Colors.green[800] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.blue,
                  onPressed: () => _editRegra(regra),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _deleteRegra(regra),
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
            DataColumn(label: Text('Prioridade', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Dias de Prazo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Data de Referência', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Segmento', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredRegrasList.map((regra) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    regra.prioridade,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Text('${regra.diasPrazo} dias'),
                ),
                DataCell(
                  Text(regra.dataReferenciaLabel),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      _getSegmentosNomes(regra.segmentoIds),
                      style: TextStyle(
                        fontWeight: regra.segmentoIds.isEmpty ? FontWeight.bold : FontWeight.normal,
                        color: regra.segmentoIds.isEmpty ? Colors.blue : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: regra.ativo ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      regra.ativo ? 'Ativa' : 'Inativa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: regra.ativo ? Colors.green[800] : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      regra.descricao ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        onPressed: () => _editRegra(regra),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteRegra(regra),
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
