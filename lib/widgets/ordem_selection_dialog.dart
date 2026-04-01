import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ordem.dart';
import '../utils/responsive.dart';

class OrdemSelectionDialog extends StatefulWidget {
  final List<Ordem> ordens;
  final String title;
  final String? taskTarefa; // Nome da tarefa para contexto
  final String? taskLocal; // Local da tarefa para pré-filtrar

  const OrdemSelectionDialog({
    super.key,
    required this.ordens,
    this.title = 'Selecionar Ordem',
    this.taskTarefa,
    this.taskLocal,
  });

  @override
  State<OrdemSelectionDialog> createState() => _OrdemSelectionDialogState();
}

class _OrdemSelectionDialogState extends State<OrdemSelectionDialog> {
  List<Ordem> _filteredOrdens = [];
  List<Ordem> _displayedOrdens = [];
  final Set<String> _selectedOrdemIds = {}; // IDs das ordens selecionadas
  String _searchQuery = '';
  String _viewMode = 'cards'; // 'cards', 'list', 'table'
  final Set<String> _filterStatusUsuario = {};
  final Set<String> _filterTipo = {};
  final Set<String> _filterLocal = {};
  final Set<String> _filterSala = {};
  final Set<String> _filterOrdem = {};
  bool _filtersExpanded = false;
  final int _itemsPerPage = 50;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.taskLocal != null && widget.taskLocal!.trim().isNotEmpty) {
      // Segue a mesma estratégia do formulário de notas: filtra usando a busca,
      // em vez de depender apenas do dropdown de local.
      _searchQuery = widget.taskLocal!.trim();
    }
    _filteredOrdens = widget.ordens;
    _applyFilters();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No desktop, usar visualização de tabela por padrão
    if (_viewMode == 'cards') {
      final isDesktop = Responsive.isDesktop(context);
      if (isDesktop) {
        _viewMode = 'table';
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredOrdens.length);
    
    if (startIndex < _filteredOrdens.length) {
      setState(() {
        _displayedOrdens = _filteredOrdens.sublist(0, endIndex);
        _currentPage++;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrdens = widget.ordens.where((ordem) {
        // Filtro de pesquisa
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = 
              ordem.ordem.toLowerCase().contains(query) ||
              (ordem.textoBreve != null && ordem.textoBreve!.toLowerCase().contains(query)) ||
              ((ordem.local != null && ordem.local!.toLowerCase().contains(query)) ||
              (ordem.localInstalacao != null && ordem.localInstalacao!.toLowerCase().contains(query))) ||
              (ordem.denominacaoLocalInstalacao != null && ordem.denominacaoLocalInstalacao!.toLowerCase().contains(query)) ||
              (ordem.denominacaoObjeto != null && ordem.denominacaoObjeto!.toLowerCase().contains(query)) ||
              (ordem.codigoSI != null && ordem.codigoSI!.toLowerCase().contains(query));
          
          if (!matchesSearch) return false;
        }

        // Filtro de status
        if (_filterStatusUsuario.isNotEmpty &&
            (ordem.statusUsuario == null ||
                !_filterStatusUsuario.contains(
                    ordem.statusUsuario!.substring(0, ordem.statusUsuario!.length >= 4 ? 4 : ordem.statusUsuario!.length)))) {
          return false;
        }

        // Filtro de tipo
        if (_filterTipo.isNotEmpty && (ordem.tipo == null || !_filterTipo.contains(ordem.tipo!))) {
          return false;
        }

        // Filtro de sala
        if (_filterSala.isNotEmpty && (ordem.sala == null || !_filterSala.contains(ordem.sala!))) {
          return false;
        }

        // Filtro de ordem
        if (_filterOrdem.isNotEmpty && !_filterOrdem.contains(ordem.ordem)) {
          return false;
        }

        // Filtro de local (usar campo 'local' mapeado se disponível)
        if (_filterLocal.isNotEmpty) {
          final localParaFiltro = (ordem.local != null && ordem.local!.isNotEmpty) 
              ? ordem.local 
              : ordem.localInstalacao;
          if (localParaFiltro == null || !_filterLocal.contains(localParaFiltro)) {
            return false;
          }
        }

        return true;
      }).toList();

      // Ordenar pela data de tolerância (mais antigas primeiro; nulos por último)
      _filteredOrdens.sort((a, b) {
        if (a.tolerancia == null && b.tolerancia == null) return 0;
        if (a.tolerancia == null) return 1;
        if (b.tolerancia == null) return -1;
        return a.tolerancia!.compareTo(b.tolerancia!);
      });
      // Resetar paginação quando filtrar
      _currentPage = 0;
      _displayedOrdens = [];
      _loadMoreItems();
    });
  }

  List<String> _getUniqueStatusesUsuario() {
    final base = _filteredOrdens.isNotEmpty ? _filteredOrdens : widget.ordens;
    return base
        .where((o) => o.statusUsuario != null && o.statusUsuario!.isNotEmpty)
        .map((o) => o.statusUsuario!.substring(0, o.statusUsuario!.length >= 4 ? 4 : o.statusUsuario!.length))
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueTipos() {
    final base = _filteredOrdens.isNotEmpty ? _filteredOrdens : widget.ordens;
    return base
        .where((o) => o.tipo != null)
        .map((o) => o.tipo!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueLocais() {
    // Usar o campo 'local' (mapeado) se disponível, senão usar 'localInstalacao'
    final base = _filteredOrdens.isNotEmpty ? _filteredOrdens : widget.ordens;
    return base
        .where((o) => (o.local != null && o.local!.isNotEmpty) || (o.localInstalacao != null && o.localInstalacao!.isNotEmpty))
        .map((o) => (o.local != null && o.local!.isNotEmpty) ? o.local! : (o.localInstalacao ?? ''))
        .where((local) => local.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueSalas() {
    final base = _filteredOrdens.isNotEmpty ? _filteredOrdens : widget.ordens;
    return base
        .where((o) => o.sala != null && o.sala!.isNotEmpty)
        .map((o) => o.sala!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getUniqueOrdens() {
    final base = _filteredOrdens.isNotEmpty ? _filteredOrdens : widget.ordens;
    return base.map((o) => o.ordem).toSet().toList()..sort();
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('ABER')) return Colors.orange;
    if (status.contains('CAPC')) return Colors.blue;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _copiarOrdem(String texto) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem copiada!'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível copiar: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  Widget _buildPrazoWithDateBadge(Ordem ordem) {
    if (ordem.tolerancia == null) {
      return const Text('-', style: TextStyle(color: Colors.grey, fontSize: 11));
    }

    final data = _formatDate(ordem.tolerancia!);
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final prazoSemHora = DateTime(ordem.tolerancia!.year, ordem.tolerancia!.month, ordem.tolerancia!.day);
    final diasRestantes = prazoSemHora.difference(hojeSemHora).inDays;

    Color badgeColor;
    Color textColor;

    if (diasRestantes <= 0) {
      badgeColor = Colors.black;
      textColor = Colors.white;
    } else if (diasRestantes <= 30) {
      badgeColor = Colors.red;
      textColor = Colors.white;
    } else if (diasRestantes <= 90) {
      badgeColor = Colors.yellow[700] ?? Colors.amber;
      textColor = Colors.black;
    } else {
      badgeColor = Colors.blue;
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // data
          Text(
            data,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // dias
          Text(
            diasRestantes < 0
                ? '$diasRestantes dias'
                : diasRestantes == 0
                    ? 'Vence hoje'
                    : diasRestantes == 1
                        ? '1 dia'
                        : '$diasRestantes dias',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final statusesUsuario = _getUniqueStatusesUsuario();
    final tipos = _getUniqueTipos();
    final locais = _getUniqueLocais();

    _filterStatusUsuario.removeWhere((s) => !statusesUsuario.contains(s));
    _filterTipo.removeWhere((t) => !tipos.contains(t));
    _filterLocal.removeWhere((l) => !locais.contains(l));
    _filterSala.removeWhere((s) => !_getUniqueSalas().contains(s));
    _filterOrdem.removeWhere((o) => !_getUniqueOrdens().contains(o));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: isMobile ? double.infinity : 1100,
        height: isMobile ? double.infinity : 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.taskTarefa != null)
                          Text(
                            'Tarefa: ${widget.taskTarefa}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filtros e pesquisa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  // Campo de pesquisa + toggle de filtros na mesma linha
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar ordem, texto breve, local, objeto...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                                setState(() {
                            _filtersExpanded = !_filtersExpanded;
                                });
                              },
                        icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.filter_list),
                        label: Text(_filtersExpanded ? 'Ocultar filtros' : 'Mostrar filtros'),
                            ),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                              ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildViewButton(Icons.view_module, 'cards'),
                              _buildViewButton(Icons.view_list, 'list'),
                              _buildViewButton(Icons.table_chart, 'table'),
                              ],
                          ),
                        ),
                      ],
                    ],
                            ),
                            const SizedBox(height: 8),
                  AnimatedCrossFade(
                    crossFadeState: _filtersExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                    firstChild: isMobile
                        ? Column(
                            children: [
                              _buildMultiSelect(label: 'Local', selected: _filterLocal, items: _getUniqueLocais()),
                              const SizedBox(height: 8),
                              _buildMultiSelect(label: 'Tipo', selected: _filterTipo, items: _getUniqueTipos()),
                              const SizedBox(height: 8),
                              _buildMultiSelect(label: 'Ordem', selected: _filterOrdem, items: _getUniqueOrdens()),
                              const SizedBox(height: 8),
                              _buildMultiSelect(label: 'Sala', selected: _filterSala, items: _getUniqueSalas()),
                              const SizedBox(height: 8),
                              _buildMultiSelect(label: 'Status Usuário', selected: _filterStatusUsuario, items: _getUniqueStatusesUsuario()),
                              const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildViewButton(Icons.view_module, 'cards'),
                                  _buildViewButton(Icons.view_list, 'list'),
                                  _buildViewButton(Icons.table_chart, 'table'),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                              Expanded(
                                flex: 3,
                                child: _buildMultiSelect(label: 'Local', selected: _filterLocal, items: _getUniqueLocais()),
                              ),
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                                child: _buildMultiSelect(label: 'Tipo', selected: _filterTipo, items: _getUniqueTipos()),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildMultiSelect(label: 'Ordem', selected: _filterOrdem, items: _getUniqueOrdens()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                                child: _buildMultiSelect(label: 'Sala', selected: _filterSala, items: _getUniqueSalas()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 2,
                                child: _buildMultiSelect(label: 'Status Usuário', selected: _filterStatusUsuario, items: _getUniqueStatusesUsuario()),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildViewButton(Icons.view_module, 'cards'),
                                  _buildViewButton(Icons.view_list, 'list'),
                                  _buildViewButton(Icons.table_chart, 'table'),
                                ],
                              ),
                            ),
                          ],
                          ),
                    secondChild: const SizedBox.shrink(),
                        ),
                  const SizedBox(height: 8),
                  // Contador
                  Row(
                    children: [
                      Text(
                        '${_displayedOrdens.length}${_displayedOrdens.length < _filteredOrdens.length ? '+' : ''} de ${_filteredOrdens.length} ordens (${widget.ordens.length} total)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_filterStatusUsuario.isNotEmpty ||
                          _filterTipo.isNotEmpty ||
                          _filterLocal.isNotEmpty ||
                          _filterSala.isNotEmpty ||
                          _filterOrdem.isNotEmpty ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _filterStatusUsuario.clear();
                              _filterTipo.clear();
                              _filterLocal.clear();
                              _filterSala.clear();
                              _filterOrdem.clear();
                              _applyFilters();
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Limpar filtros'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Lista de ordens
            Expanded(
              child: _filteredOrdens.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma ordem encontrada',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _filterStatusUsuario.isNotEmpty ||
                              _filterTipo.isNotEmpty ||
                              _filterLocal.isNotEmpty ||
                              _filterSala.isNotEmpty ||
                              _filterOrdem.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatusUsuario.clear();
                                    _filterTipo.clear();
                                    _filterLocal.clear();
                                    _filterSala.clear();
                                    _filterOrdem.clear();
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _buildOrdensView(),
            ),

            // Rodapé com botões
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedOrdemIds.length} ordem(ns) selecionada(s)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<List<Ordem>>(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedOrdemIds.isEmpty
                        ? null
                        : () {
                            final selectedOrdens = widget.ordens
                                .where((o) => _selectedOrdemIds.contains(o.id))
                                .toList();
                            Navigator.of(context).pop<List<Ordem>>(selectedOrdens);
                          },
                    child: Text('Adicionar ${_selectedOrdemIds.isEmpty ? '' : '(${_selectedOrdemIds.length})'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOrdemSelection(String ordemId) {
    setState(() {
      if (_selectedOrdemIds.contains(ordemId)) {
        _selectedOrdemIds.remove(ordemId);
      } else {
        _selectedOrdemIds.add(ordemId);
      }
    });
  }

  Widget _buildMultiSelect({
    required String label,
    required Set<String> selected,
    required List<String> items,
  }) {
    final displayText = selected.isEmpty ? 'Todos' : selected.join(', ');

    return InkWell(
      onTap: () async {
        final result = await _showMultiSelectDialog(label, items, selected);
        if (result != null) {
          setState(() {
            selected
              ..clear()
              ..addAll(result);
            _applyFilters();
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<Set<String>?> _showMultiSelectDialog(
    String title,
    List<String> options,
    Set<String> current,
  ) async {
    final temp = {...current};
    return showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecionar $title'),
          content: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return ListView(
                  shrinkWrap: true,
                  children: options
                      .map(
                        (opt) => CheckboxListTile(
                          dense: true,
                          value: temp.contains(opt),
                          title: Text(opt),
                          onChanged: (checked) {
                            setStateDialog(() {
                              if (checked == true) {
                                temp.add(opt);
                              } else {
                                temp.remove(opt);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(temp),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewButton(IconData icon, String mode) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () {
        if (_viewMode == mode) return;
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.blue[700] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildOrdensView() {
    if (_viewMode == 'list') {
      return _buildListView();
    } else if (_viewMode == 'table') {
      return _buildTableView();
    } else {
      return _buildCardsView();
    }
  }

  Widget _buildCardsView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _displayedOrdens.length + (_displayedOrdens.length < _filteredOrdens.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedOrdens.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final ordem = _displayedOrdens[index];
        final isSelected = _selectedOrdemIds.contains(ordem.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: isSelected ? Colors.blue[50] : null,
          child: InkWell(
            onTap: () => _toggleOrdemSelection(ordem.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ordem.statusUsuario),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ordem.statusUsuario != null
                              ? ordem.statusUsuario!.substring(0, ordem.statusUsuario!.length >= 4 ? 4 : ordem.statusUsuario!.length)
                              : '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (ordem.localInstalacao != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                ordem.localInstalacao!,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ordem: ${ordem.ordem}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copiarOrdem(ordem.ordem),
                        tooltip: 'Copiar ordem',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (ordem.textoBreve != null)
                    Text(
                      ordem.textoBreve!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (ordem.tipo != null)
                        _buildInfoChip(Icons.category, ordem.tipo!),
                      if (ordem.denominacaoLocalInstalacao != null)
                        _buildInfoChip(Icons.location_city, ordem.denominacaoLocalInstalacao!),
                      if (ordem.gpm != null)
                        _buildInfoChip(Icons.numbers, 'GPM: ${ordem.gpm}'),
                      if (ordem.statusUsuario != null)
                        _buildInfoChip(Icons.person, ordem.statusUsuario!),
                    ],
                  ),
                  if (ordem.inicioBase != null || ordem.fimBase != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          ordem.inicioBase != null && ordem.fimBase != null
                              ? '${_formatDate(ordem.inicioBase!)} - ${_formatDate(ordem.fimBase!)}'
                              : ordem.inicioBase != null
                                  ? 'Início: ${_formatDate(ordem.inicioBase!)}'
                                  : 'Fim: ${_formatDate(ordem.fimBase!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _displayedOrdens.length + (_displayedOrdens.length < _filteredOrdens.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedOrdens.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final ordem = _displayedOrdens[index];
        final isSelected = _selectedOrdemIds.contains(ordem.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(ordem.statusUsuario),
            child: Text(
              ordem.tipo ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            'Ordem: ${ordem.ordem}',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((ordem.local != null && ordem.local!.isNotEmpty) || (ordem.localInstalacao != null && ordem.localInstalacao!.isNotEmpty))
                Text(
                  'Local: ${(ordem.local != null && ordem.local!.isNotEmpty) ? ordem.local! : ordem.localInstalacao ?? ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (ordem.textoBreve != null)
                Text(
                  ordem.textoBreve!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (ordem.inicioBase != null || ordem.fimBase != null)
                Text(
                  ordem.inicioBase != null && ordem.fimBase != null
                      ? '${_formatDate(ordem.inicioBase!)} - ${_formatDate(ordem.fimBase!)}'
                      : ordem.inicioBase != null
                          ? 'Início: ${_formatDate(ordem.inicioBase!)}'
                          : 'Fim: ${_formatDate(ordem.fimBase!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.blue)
              : const Icon(Icons.chevron_right),
          selected: isSelected,
          selectedTileColor: Colors.blue[50],
          onTap: () => _toggleOrdemSelection(ordem.id),
        );
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTable(
          columnSpacing: 35,
          horizontalMargin: 8,
          headingRowHeight: 38,
          dataRowMinHeight: 26,
          dataRowMaxHeight: 42,
          headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
          columns: const [
            DataColumn(label: Text('Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Ordem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Sala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Texto Breve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tolerância', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Início Base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Fim Base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('GPM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: [
            ..._displayedOrdens.map((ordem) {
            final isSelected = _selectedOrdemIds.contains(ordem.id);
            return DataRow(
              selected: isSelected,
              cells: [
                // 1. Local
                DataCell(
                  SizedBox(
                    width: 40,
                    child: Text(
                      (ordem.local != null && ordem.local!.isNotEmpty) 
                          ? ordem.local! 
                          : (ordem.localInstalacao ?? '-'),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 2. Tipo
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ordem.tipo ?? '-',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                // 3. Ordem
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ordem.ordem,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copiarOrdem(ordem.ordem),
                        child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                // 4. Sala
                DataCell(
                  Text(
                    ordem.sala ?? '-',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                // 5. Texto Breve
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      ordem.textoBreve ?? '-',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 6. Status (badge)
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ordem.statusUsuario),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ordem.statusUsuario != null
                          ? ordem.statusUsuario!.substring(0, ordem.statusUsuario!.length >= 4 ? 4 : ordem.statusUsuario!.length)
                          : '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ),
                // 7. Tolerância (data + dias, como na tela de ordens)
                DataCell(_buildPrazoWithDateBadge(ordem)),
                // 8. Início Base
                DataCell(
                  Text(
                    ordem.inicioBase != null ? _formatDate(ordem.inicioBase!) : '-',
                    style: const TextStyle(fontSize: 11),
                ),
                ),
                // 9. Fim Base
                DataCell(
                  Text(
                    ordem.fimBase != null ? _formatDate(ordem.fimBase!) : '-',
                    style: const TextStyle(fontSize: 11),
                ),
                ),
                // 10. GPM
                DataCell(
                  Text(
                    ordem.gpm?.toString() ?? '-',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              onSelectChanged: (_) => _toggleOrdemSelection(ordem.id),
            );
            }),
            if (_displayedOrdens.length < _filteredOrdens.length)
              DataRow(
                cells: List.generate(10, (_) => const DataCell(
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
