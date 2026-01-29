import 'package:flutter/material.dart';
import '../models/segmento.dart';
import '../services/segmento_service.dart';
import 'segmento_form_dialog.dart';

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
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadSegmentos();
    _searchController.addListener(_onSearchChanged);
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
        _currentPage = 1;
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
        _currentPage = 1;
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
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao buscar segmentos: $e');
    }
  }

  List<Segmento> get _paginatedSegmentos {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredSegmentos.length > startIndex
        ? _filteredSegmentos.sublist(
            startIndex,
            endIndex > _filteredSegmentos.length ? _filteredSegmentos.length : endIndex,
          )
        : [];
  }

  int get _totalPages => (_filteredSegmentos.length / _itemsPerPage).ceil();

  Future<void> _createSegmento() async {
    final result = await showDialog<Segmento>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
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

  Future<void> _editSegmento(Segmento segmento) async {
    final result = await showDialog<Segmento>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
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

  Future<void> _duplicateSegmento(Segmento segmento) async {
    final duplicated = segmento.copyWith(
      id: '',
      segmento: '${segmento.segmento} (Cópia)',
    );

    final result = await showDialog<Segmento>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
      body: SafeArea(
        child: Column(
          children: [
            // Header moderno
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e293b) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cadastro de Segmentos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createSegmento,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Novo Segmento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            // Barra de busca
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e293b) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por segmento ou descrição...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF3b82f6),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                ),
              ),
            ),

            // Tabela
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF3b82f6),
                      ),
                    )
                  : _filteredSegmentos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category,
                                size: 64,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _segmentos.isEmpty
                                    ? 'Nenhum segmento cadastrado'
                                    : 'Nenhum segmento encontrado',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                ),
                              ),
                              if (_segmentos.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _createSegmento,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Criar Primeiro Segmento'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3b82f6),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1e293b) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Cabeçalho da tabela
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Segmento',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Descrição',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Cor',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        'Ações',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Corpo da tabela
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _paginatedSegmentos.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                  ),
                                  itemBuilder: (context, index) {
                                    final segmento = _paginatedSegmentos[index];
                                    return InkWell(
                                      onTap: () => _editSegmento(segmento),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: segmento.backgroundColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      segmento.segmento,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                segmento.descricao != null && segmento.descricao!.isNotEmpty
                                                    ? segmento.descricao!
                                                    : 'Sem descrição',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                                  fontStyle: segmento.descricao != null && segmento.descricao!.isNotEmpty
                                                      ? FontStyle.normal
                                                      : FontStyle.italic,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: segmento.backgroundColor,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 120,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 20),
                                                    color: const Color(0xFF3b82f6),
                                                    onPressed: () => _editSegmento(segmento),
                                                    tooltip: 'Editar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 20),
                                                    color: const Color(0xFFf59e0b),
                                                    onPressed: () => _duplicateSegmento(segmento),
                                                    tooltip: 'Duplicar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 20),
                                                    color: const Color(0xFFef4444),
                                                    onPressed: () => _deleteSegmento(segmento),
                                                    tooltip: 'Excluir',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Rodapé com paginação
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  border: Border(
                                    top: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Mostrando ${_paginatedSegmentos.length} de ${_filteredSegmentos.length} segmentos',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: _currentPage > 1
                                              ? () {
                                                  setState(() {
                                                    _currentPage--;
                                                  });
                                                }
                                              : null,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _currentPage > 1
                                                ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8)),
                                          ),
                                          child: const Text('Anterior'),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3b82f6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$_currentPage',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _currentPage < _totalPages
                                              ? () {
                                                  setState(() {
                                                    _currentPage++;
                                                  });
                                                }
                                              : null,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _currentPage < _totalPages
                                                ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8)),
                                          ),
                                          child: const Text('Próximo'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSegmentos,
        backgroundColor: const Color(0xFF3b82f6),
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Atualizar',
      ),
    );
  }
}
