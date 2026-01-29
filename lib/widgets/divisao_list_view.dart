import 'package:flutter/material.dart';
import '../models/divisao.dart';
import '../services/divisao_service.dart';
import 'divisao_form_dialog.dart';

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
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadDivisoes();
    _searchController.addListener(_onSearchChanged);
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
        _currentPage = 1; // Resetar página ao recarregar
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
        _currentPage = 1;
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
        _currentPage = 1;
      });
    } catch (e) {
      print('Erro ao buscar divisões: $e');
    }
  }

  List<Divisao> get _paginatedDivisoes {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredDivisoes.length > startIndex
        ? _filteredDivisoes.sublist(
            startIndex,
            endIndex > _filteredDivisoes.length ? _filteredDivisoes.length : endIndex,
          )
        : [];
  }

  int get _totalPages => (_filteredDivisoes.length / _itemsPerPage).ceil();

  Future<void> _createDivisao() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
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

      if (result != null && result['divisao'] != null) {
        try {
          final divisao = result['divisao'] as Divisao;
          final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;
          
          final created = await _divisaoService.createDivisao(divisao, telegramChatIds: telegramChatIds);
          if (created != null) {
            await _loadDivisoes();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                      ? 'Divisão criada e Chat IDs do Telegram cadastrados com sucesso!'
                      : 'Divisão criada com sucesso!'),
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

  Future<void> _duplicateDivisao(Divisao divisao) async {
    final duplicated = divisao.copyWith(
      id: '',
      divisao: '${divisao.divisao} (Cópia)',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => DivisaoFormDialog(divisao: duplicated),
    );

    if (result != null && result['divisao'] != null) {
      try {
        final divisaoResult = result['divisao'] as Divisao;
        final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;
        
        final created = await _divisaoService.createDivisao(divisaoResult, telegramChatIds: telegramChatIds);
        if (created != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                    ? 'Divisão duplicada e Chat IDs do Telegram cadastrados com sucesso!'
                    : 'Divisão duplicada com sucesso!'),
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

  Future<void> _editDivisao(Divisao divisao) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => DivisaoFormDialog(divisao: divisao),
    );

    if (result != null && result['divisao'] != null) {
      try {
        final divisaoResult = result['divisao'] as Divisao;
        final telegramChatIds = result['telegram_chat_ids'] as Map<String, String>?;
        
        final updated = await _divisaoService.updateDivisao(divisao.id, divisaoResult, telegramChatIds: telegramChatIds);
        if (updated != null) {
          await _loadDivisoes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(telegramChatIds != null && telegramChatIds.isNotEmpty
                    ? 'Divisão atualizada e Chat IDs do Telegram cadastrados com sucesso!'
                    : 'Divisão atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        print('❌ Erro ao atualizar divisão (UI): $e');
        print('❌ Stack trace: $stackTrace');
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
                      'Cadastro de Divisões',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createDivisao,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('+ Nova Divisão'),
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
                  hintText: 'Buscar por divisão, regional ou segmento...',
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
                  : _filteredDivisoes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 64,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _divisoes.isEmpty
                                    ? 'Nenhuma divisão cadastrada'
                                    : 'Nenhuma divisão encontrada',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                ),
                              ),
                              if (_divisoes.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _createDivisao,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Criar Primeira Divisão'),
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
                                        'Divisão',
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
                                        'Regional',
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
                                        'Segmentos',
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
                                  itemCount: _paginatedDivisoes.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                  ),
                                  itemBuilder: (context, index) {
                                    final divisao = _paginatedDivisoes[index];
                                    return InkWell(
                                      onTap: () => _editDivisao(divisao),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                divisao.divisao,
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
                                                divisao.regional.isNotEmpty ? divisao.regional : '-',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                divisao.segmentos.isEmpty
                                                    ? 'Nenhum'
                                                    : divisao.segmentos.join(', '),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
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
                                                    onPressed: () => _editDivisao(divisao),
                                                    tooltip: 'Editar',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 20),
                                                    color: const Color(0xFFf97316),
                                                    onPressed: () => _duplicateDivisao(divisao),
                                                    tooltip: 'Duplicar',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 20),
                                                    color: const Color(0xFFef4444),
                                                    onPressed: () => _deleteDivisao(divisao),
                                                    tooltip: 'Excluir',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
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
                                      'Mostrando ${_paginatedDivisoes.length} de ${_filteredDivisoes.length} divisões',
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
      // Botão de configurações no canto inferior direito
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Abrir configurações
        },
        backgroundColor: isDark ? const Color(0xFF1e293b) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
        elevation: 4,
        child: const Icon(Icons.settings),
      ),
    );
  }
}
