import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_feedback_form.dart';

class ChatFeedbackItemPicker extends StatefulWidget {
  final String taskId;
  
  /// Pode vir pre-selecionado (ex: recuperar de um draft)
  final Set<String> initialSelectedNotaIds;
  final Set<String> initialSelectedOrdemIds;
  final bool initialIsGeralSelected;
  final Map<String, Map<String, dynamic>> initialFeedbacks;

  const ChatFeedbackItemPicker({
    super.key,
    required this.taskId,
    this.initialSelectedNotaIds = const {},
    this.initialSelectedOrdemIds = const {},
    this.initialIsGeralSelected = true,
    this.initialFeedbacks = const {},
  });

  @override
  State<ChatFeedbackItemPicker> createState() => _ChatFeedbackItemPickerState();
}

class _ChatFeedbackItemPickerState extends State<ChatFeedbackItemPicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Estados de seleção
  late Set<String> _selectedNotaIds;
  late Set<String> _selectedOrdemIds;
  late bool _isGeralSelected;

  // Estados de preenchimento
  late Map<String, Map<String, dynamic>> _feedbacks;
  bool _isFilling = false;

  // Estados de dados
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _ordens = [];

  // Filtros
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'answered'
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _selectedNotaIds = Set.from(widget.initialSelectedNotaIds);
    _selectedOrdemIds = Set.from(widget.initialSelectedOrdemIds);
    _isGeralSelected = widget.initialIsGeralSelected;
    _feedbacks = Map.from(widget.initialFeedbacks);

    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Carregar Notas
      final notasResponse = await supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id, notas_sap(id, nota, descricao, sala)')
          .eq('task_id', widget.taskId);

      final List<Map<String, dynamic>> loadedNotas = (notasResponse as List).map((item) {
        final nota = item['notas_sap'] as Map<String, dynamic>?;
        return {
          'id': item['nota_sap_id'],
          'nota': nota?['nota'] ?? '',
          'descricao': nota?['descricao'] ?? '',
          'sala': nota?['sala'] ?? '',
          'has_feedback': false, // Mock por enquanto. Na Etapa B2 integraremos a leitura real de chat_feedback_items
        };
      }).toList();

      // 2. Carregar Ordens
      final ordensResponse = await supabase
          .from('tasks_ordens')
          .select('ordem_id, ordens(id, ordem, texto_breve, sala)')
          .eq('task_id', widget.taskId);

      final List<Map<String, dynamic>> loadedOrdens = (ordensResponse as List).map((item) {
        final ordem = item['ordens'] as Map<String, dynamic>?;
        return {
          'id': item['ordem_id'],
          'ordem': ordem?['ordem'] ?? '',
          'descricao': ordem?['texto_breve'] ?? '',
          'sala': ordem?['sala'] ?? '',
          'has_feedback': false, // Mock
        };
      }).toList();

      if (mounted) {
        setState(() {
          _notas = loadedNotas;
          _ordens = loadedOrdens;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ocorreu um erro ao carregar notas e ordens.\nPor favor, tente novamente.';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleNota(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedNotaIds.add(id);
        _isGeralSelected = false;
      } else {
        _selectedNotaIds.remove(id);
      }
    });
  }

  void _toggleOrdem(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedOrdemIds.add(id);
        _isGeralSelected = false;
      } else {
        _selectedOrdemIds.remove(id);
      }
    });
  }

  void _selectGeral() {
    setState(() {
      _isGeralSelected = true;
      _selectedNotaIds.clear();
      _selectedOrdemIds.clear();
    });
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items, String numKey) {
    return items.where((item) {
      // 1. Busca textual
      final matchesSearch = _searchQuery.isEmpty ||
          (item[numKey]?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (item['descricao']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          
      // 2. Filtro de status
      bool matchesFilter = true;
      final bool isAnswered = item['has_feedback'] == true;
      
      if (_selectedFilter == 'pending') {
        matchesFilter = !isAnswered;
      } else if (_selectedFilter == 'answered') {
        matchesFilter = isAnswered;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int get _totalSelected => _selectedNotaIds.length + _selectedOrdemIds.length;
  bool get _canProceed => _isGeralSelected || _totalSelected > 0;

  @override
  Widget build(BuildContext context) {
    final filteredNotas = _filterItems(_notas, 'nota');
    final filteredOrdens = _filterItems(_ordens, 'ordem');

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: _buildError())
            else if (_isFilling)
              Expanded(child: _buildFillingUI())
            else ...[
              _buildFiltersAndGeral(),
              const Divider(height: 1),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Notas (${filteredNotas.length})'),
                  Tab(text: 'Ordens (${filteredOrdens.length})'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(filteredNotas, isNota: true, isMobile: isMobile),
                    _buildList(filteredOrdens, isNota: false, isMobile: isMobile),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildFooter(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (_isFilling)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _isFilling = false),
            ),
          Expanded(
            child: Text(
              _isFilling ? 'Preencher Feedbacks' : 'Vincular e Avaliar Itens',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndGeral() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Row do GERAL
          Material(
            color: _isGeralSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: _isGeralSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RadioListTile<bool>(
              value: true,
              groupValue: _isGeralSelected,
              onChanged: (_) => _selectGeral(),
              title: const Text('Comentário Geral (Nenhum item específico)'),
              subtitle: const Text('Limpa todas as seleções abaixo'),
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // Busca e Filtro
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por número ou descrição...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  initialValue: _selectedFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'pending', child: Text('Somente pendentes')),
                    DropdownMenuItem(value: 'answered', child: Text('Já respondidos')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFilter = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isNota, required bool isMobile}) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Nenhum item encontrado para esta aba/filtro.', style: TextStyle(color: Colors.grey)),
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = item['id'];
          final isSelected = isNota ? _selectedNotaIds.contains(id) : _selectedOrdemIds.contains(id);
          final numKey = isNota ? 'nota' : 'ordem';
          final numStr = item[numKey];
          final descStr = item['descricao'] ?? '';
          final sala = item['sala'] ?? '';

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (val) => isNota ? _toggleNota(id, val) : _toggleOrdem(id, val),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$numStr - $descStr',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sala.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Sala: $sala', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                  const SizedBox(height: 4),
                  if (item['has_feedback'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Já avaliado', style: TextStyle(fontSize: 10, color: Colors.green)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Pendente', style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(flex: 2, child: Text('Número', style: TextStyle(fontWeight: FontWeight.bold))),
              const Expanded(flex: 4, child: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
              const Expanded(flex: 2, child: Text('Sala', style: TextStyle(fontWeight: FontWeight.bold))),
              const Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item['id'];
              final isSelected = isNota ? _selectedNotaIds.contains(id) : _selectedOrdemIds.contains(id);
              final numKey = isNota ? 'nota' : 'ordem';
              
              return InkWell(
                onTap: () => isNota ? _toggleNota(id, !isSelected) : _toggleOrdem(id, !isSelected),
                child: Container(
                  color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) => isNota ? _toggleNota(id, val) : _toggleOrdem(id, val),
                        ),
                      ),
                      Expanded(
                        flex: 2, 
                        child: SelectableText(
                          item[numKey]?.toString() ?? '', 
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 4, 
                        child: Text(
                          item['descricao']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2, 
                        child: Text(item['sala']?.toString() ?? '-'),
                      ),
                      Expanded(
                        flex: 2, 
                        child: Row(
                          children: [
                            if (item['has_feedback'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  border: Border.all(color: Colors.green.shade200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Já avaliado', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  border: Border.all(color: Colors.orange.shade200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Pendente', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
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
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isGeralSelected)
            const Text(
              'Modo Geral Selecionado',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            )
          else
            Text(
              '$_totalSelected item(ns) selecionado(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canProceed ? _onProceed : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Continuar'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFillingUI() {
    final List<Map<String, dynamic>> selectedNotasInfo = _notas
        .where((n) => _selectedNotaIds.contains(n['id']))
        .toList();
        
    final List<Map<String, dynamic>> selectedOrdensInfo = _ordens
        .where((o) => _selectedOrdemIds.contains(o['id']))
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (selectedNotasInfo.isNotEmpty) ...[
                const Text('Notas Selecionadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...selectedNotasInfo.map((n) => ChatFeedbackForm(
                  itemInfo: n,
                  refType: 'NOTA',
                  initialData: _feedbacks[n['id']],
                  onChanged: (data) => _feedbacks[n['id']] = data,
                )).toList(),
                const SizedBox(height: 16),
              ],
              if (selectedOrdensInfo.isNotEmpty) ...[
                const Text('Ordens Selecionadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...selectedOrdensInfo.map((o) => ChatFeedbackForm(
                  itemInfo: o,
                  refType: 'ORDEM',
                  initialData: _feedbacks[o['id']],
                  onChanged: (data) => _feedbacks[o['id']] = data,
                )).toList(),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isFilling = false),
                child: const Text('Voltar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'isGeral': _isGeralSelected,
                    'selectedNotaIds': _selectedNotaIds.toList(),
                    'selectedOrdemIds': _selectedOrdemIds.toList(),
                    'selectedNotasInfo': selectedNotasInfo,
                    'selectedOrdensInfo': selectedOrdensInfo,
                    'feedbacks': _feedbacks,
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirmar Tudo'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onProceed() {
    if (_isGeralSelected) {
      Navigator.pop(context, {
        'isGeral': true,
        'selectedNotaIds': <String>[],
        'selectedOrdemIds': <String>[],
        'selectedNotasInfo': <Map<String, dynamic>>[],
        'selectedOrdensInfo': <Map<String, dynamic>>[],
        'feedbacks': <String, Map<String, dynamic>>{},
      });
      return;
    }

    setState(() {
      _isFilling = true;
    });
  }
}
