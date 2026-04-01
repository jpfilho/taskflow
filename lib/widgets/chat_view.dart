import 'package:flutter/material.dart';
import '../models/comunidade.dart';
import '../services/chat_service.dart';
import 'chat_comunidades_list.dart';
import 'chat_grupos_list.dart';
import 'chat_screen.dart';

class ChatView extends StatefulWidget {
  final String? initialComunidadeId;
  final String? initialGrupoId;

  const ChatView({
    super.key,
    this.initialComunidadeId,
    this.initialGrupoId,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ChatService _chatService = ChatService();
  
  List<Comunidade> _comunidades = [];
  Map<String, int> _unreadPerCommunity = {};
  bool _isLoading = true;
  String? _selectedComunidadeId;
  String? _selectedGrupoId;

  @override
  void initState() {
    super.initState();
    _selectedComunidadeId = widget.initialComunidadeId;
    _selectedGrupoId = widget.initialGrupoId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Carregar comunidades diretamente (sem recriar/verificar a cada abertura)
      final comunidades = await _chatService.listarComunidades();
      
      setState(() {
        _comunidades = comunidades;
        _isLoading = false;
      });

      // Carregar contagens de não lidas em background (não bloqueia a UI)
      _loadUnreadCounts();
    } catch (e) {
      print('Erro ao carregar dados do chat: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final ids = _comunidades
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toList();
      if (ids.isEmpty) return;

      final counts = await _chatService.contarNaoLidasPorComunidade(ids);
      if (mounted) {
        setState(() {
          _unreadPerCommunity = counts;
        });
      }
    } catch (e) {
      print('Erro ao carregar contagens de não lidas: $e');
    }
  }

  void _onComunidadeSelected(String? comunidadeId) {
    setState(() {
      _selectedComunidadeId = comunidadeId;
      _selectedGrupoId = null; // Resetar grupo selecionado
    });
  }

  void _onGrupoSelected(String grupoId) {
    setState(() {
      _selectedGrupoId = grupoId;
    });
  }

  void _onBack() {
    if (_selectedGrupoId != null) {
      setState(() {
        _selectedGrupoId = null;
      });
      // Recarregar contagens ao voltar de um chat (pode ter lido mensagens)
      _loadUnreadCounts();
    } else if (_selectedComunidadeId != null) {
      setState(() {
        _selectedComunidadeId = null;
      });
    }
  }

  Widget _buildUnreadBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // Assegura que tenha uma comunidade selecionada para o Master-Detail
          if (_selectedComunidadeId == null && _comunidades.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedComunidadeId = _comunidades.first.id;
                });
              }
            });
          }

          return Row(
            children: [
              // COLUNA ESQUERDA (Master)
              Container(
                width: 350,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: _selectedComunidadeId != null
                    ? ChatGruposList(
                        key: ValueKey('master_$_selectedComunidadeId'),
                        comunidadeId: _selectedComunidadeId!,
                        onGrupoSelected: _onGrupoSelected,
                        onBack: _onBack,
                        isEmbedded: true,
                        embeddedTitle: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedComunidadeId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF075E54),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            items: _comunidades.map((c) {
                              final unread = _unreadPerCommunity[c.id] ?? 0;
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c.divisaoNome} - ${c.segmentoNome}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildUnreadBadge(unread),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedComunidadeId = val;
                                _selectedGrupoId = null;
                              });
                            },
                          ),
                        ),
                      )
                    : const Center(child: Text('Selecione uma comunidade')),
              ),
              // COLUNA DIREITA (Detail)
              Expanded(
                child: _selectedGrupoId != null
                    ? ChatScreen(
                        key: ValueKey('detail_$_selectedGrupoId'),
                        grupoId: _selectedGrupoId!,
                        onBack: _onBack,
                        isEmbedded: true,
                      )
                    : Container(
                        color: const Color(0xFFF0F2F5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 100, color: Colors.grey[400]),
                              const SizedBox(height: 20),
                              Text(
                                'Selecione uma conversa',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        }

        // Layout Mobile Original
        if (_selectedGrupoId != null) {
          return ChatScreen(
            grupoId: _selectedGrupoId!,
            onBack: _onBack,
          );
        }

        if (_selectedComunidadeId != null) {
          return ChatGruposList(
            comunidadeId: _selectedComunidadeId!,
            onGrupoSelected: _onGrupoSelected,
            onBack: _onBack,
          );
        }

        return ChatComunidadesList(
          comunidades: _comunidades,
          unreadPerCommunity: _unreadPerCommunity,
          onComunidadeSelected: _onComunidadeSelected,
          onRefresh: _loadData,
        );
      },
    );
  }
}
