import 'package:flutter/material.dart';
import '../models/regional.dart';
import '../services/regional_service.dart';
import 'regional_form_dialog.dart';

class RegionalListView extends StatefulWidget {
  const RegionalListView({super.key});

  @override
  State<RegionalListView> createState() => _RegionalListViewState();
}

class _RegionalListViewState extends State<RegionalListView> {
  final RegionalService _regionalService = RegionalService();
  List<Regional> _regionais = [];
  List<Regional> _filteredRegionais = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadRegionais();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      setState(() {
        _regionais = regionais;
        _filteredRegionais = regionais;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar regionais: $e'),
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
        _filteredRegionais = _regionais;
        _currentPage = 1;
      });
    } else {
      _searchRegionais(query);
    }
  }

  Future<void> _searchRegionais(String query) async {
    try {
      final results = await _regionalService.searchRegionais(query);
      setState(() {
        _filteredRegionais = results;
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao buscar regionais: $e');
    }
  }

  List<Regional> get _paginatedRegionais {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredRegionais.length > startIndex
        ? _filteredRegionais.sublist(
            startIndex,
            endIndex > _filteredRegionais.length ? _filteredRegionais.length : endIndex,
          )
        : [];
  }

  int get _totalPages => (_filteredRegionais.length / _itemsPerPage).ceil();

  Future<void> _createRegional() async {
    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const RegionalFormDialog(),
    );

    if (result != null) {
      try {
        final created = await _regionalService.createRegional(result);
        if (created != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional criada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _editRegional(Regional regional) async {
    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => RegionalFormDialog(regional: regional),
    );

    if (result != null) {
      try {
        final updated = await _regionalService.updateRegional(regional.id, result);
        if (updated != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateRegional(Regional regional) async {
    final duplicated = regional.copyWith(
      id: '',
      regional: '${regional.regional} (Cópia)',
    );

    final result = await showDialog<Regional>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => RegionalFormDialog(regional: duplicated),
    );

    if (result != null) {
      try {
        final created = await _regionalService.createRegional(result);
        if (created != null) {
          await _loadRegionais();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regional duplicada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRegional(Regional regional) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir a regional:\n\n'
          'Regional: ${regional.regional}\n'
          'Sigla: ${regional.divisao}\n'
          'Empresa: ${regional.empresa}',
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
      final deleted = await _regionalService.deleteRegional(regional.id);
      if (deleted) {
        await _loadRegionais();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Regional excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao excluir regional'),
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
                      'Cadastro de Regionais',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createRegional,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Nova Regional'),
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
                  hintText: 'Buscar por regional, divisão ou empresa...',
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
                  : _filteredRegionais.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 64,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _regionais.isEmpty
                                    ? 'Nenhuma regional cadastrada'
                                    : 'Nenhuma regional encontrada',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                ),
                              ),
                              if (_regionais.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _createRegional,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Criar Primeira Regional'),
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
                                        'Regional',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Sigla',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Empresa',
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
                                  itemCount: _paginatedRegionais.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                  ),
                                  itemBuilder: (context, index) {
                                    final regional = _paginatedRegionais[index];
                                    return InkWell(
                                      onTap: () => _editRegional(regional),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                regional.regional,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                regional.divisao.isNotEmpty ? regional.divisao : '-',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                regional.empresa.isNotEmpty ? regional.empresa : '-',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                                ),
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
                                                    onPressed: () => _editRegional(regional),
                                                    tooltip: 'Editar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 20),
                                                    color: const Color(0xFFf59e0b),
                                                    onPressed: () => _duplicateRegional(regional),
                                                    tooltip: 'Duplicar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 20),
                                                    color: const Color(0xFFef4444),
                                                    onPressed: () => _deleteRegional(regional),
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
                                      'Mostrando ${_paginatedRegionais.length} de ${_filteredRegionais.length} regionais',
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
        onPressed: _loadRegionais,
        backgroundColor: const Color(0xFF3b82f6),
        child: const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Atualizar',
      ),
    );
  }
}
