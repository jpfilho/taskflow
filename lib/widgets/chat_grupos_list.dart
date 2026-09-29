import 'dart:async';
import 'package:flutter/material.dart';
import '../models/grupo_chat.dart';
import '../models/mensagem.dart';
import '../services/chat_service.dart';
import '../services/unread_chat_manager.dart';

class ChatGruposList extends StatefulWidget {
  final String comunidadeId;
  final Function(String) onGrupoSelected;
  final VoidCallback onBack;
  final bool isEmbedded;
  final Widget? embeddedTitle;

  const ChatGruposList({
    super.key,
    required this.comunidadeId,
    required this.onGrupoSelected,
    required this.onBack,
    this.isEmbedded = false,
    this.embeddedTitle,
  });

  @override
  State<ChatGruposList> createState() => _ChatGruposListState();
}

class _ChatGruposListState extends State<ChatGruposList> {
  final ChatService _chatService = ChatService();
  final UnreadChatManager _unreadChatManager = UnreadChatManager();
  StreamSubscription<Mensagem>? _mensagemEnviadaSub;
  List<GrupoChat> _grupos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _unreadChatManager.addListener(_onUnreadManagerChanged);
    _mensagemEnviadaSub = ChatService.onMensagemEnviada.listen((msg) {
      if (mounted) {
        _atualizarUltimaMensagemLocal(msg);
      }
    });
    _loadGrupos();
  }

  @override
  void dispose() {
    _mensagemEnviadaSub?.cancel();
    _unreadChatManager.removeListener(_onUnreadManagerChanged);
    super.dispose();
  }

  void _onUnreadManagerChanged() {
    if (mounted) {
      _loadGrupos(silent: true);
    }
  }

  void _atualizarUltimaMensagemLocal(Mensagem msg) {
    if (_grupos.isEmpty) return;
    final index = _grupos.indexWhere((g) => g.id == msg.grupoId);
    if (index != -1) {
      final grupo = _grupos[index];
      String? preview = msg.conteudo.trim();
      if (preview.isEmpty) {
        if (msg.tipo == 'imagem') {
          preview = '📷 Imagem';
        } else if (msg.tipo == 'audio') {
          preview = '🎵 Áudio';
        } else if (msg.tipo == 'video') {
          preview = '🎥 Vídeo';
        } else if (msg.tipo == 'documento') {
          preview = '📄 Documento';
        }
      }
      final updated = grupo.copyWith(
        ultimaMensagemAt: msg.createdAt,
        ultimaMensagemPreview: preview,
        totalMensagens: (grupo.totalMensagens ?? 0) + 1,
      );
      final novaLista = List<GrupoChat>.from(_grupos);
      novaLista.removeAt(index);
      novaLista.insert(0, updated);
      setState(() {
        _grupos = novaLista;
      });
    } else {
      _loadGrupos(silent: true);
    }
  }

  Future<void> _loadGrupos({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      // Carregar grupos da comunidade (já vem com a última mensagem pré-populada e ordenados)
      var grupos = await _chatService.listarGruposPorComunidade(widget.comunidadeId);

      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar grupos: $e');
      if (!mounted) return;
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatarData(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.isEmbedded && widget.embeddedTitle != null
            ? widget.embeddedTitle
            : const Text('Grupos'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leading: widget.isEmbedded ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGrupos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _grupos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum grupo encontrado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGrupos,
                  child: ListView.builder(
                    itemCount: _grupos.length,
                    itemBuilder: (context, index) {
                      final grupo = _grupos[index];
                      final grupoKey = grupo.id ?? grupo.tarefaId;
                      final naoLidas = _unreadChatManager.getUnreadForGroup(grupoKey);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF075E54),
                          child: Text(
                            grupo.tarefaNome.isNotEmpty
                                ? grupo.tarefaNome[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          grupo.tarefaNome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          grupo.ultimaMensagemPreview ?? 'Nenhuma mensagem',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (grupo.ultimaMensagemAt != null)
                              Text(
                                _formatarData(grupo.ultimaMensagemAt),
                                style: TextStyle(
                                  color: naoLidas > 0 ? const Color(0xFF075E54) : Colors.grey[600],
                                  fontSize: 11,
                                  fontWeight: naoLidas > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (grupo.totalMensagens != null && grupo.totalMensagens! > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    margin: EdgeInsets.only(right: naoLidas > 0 ? 4 : 0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[350]!, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 9, color: Colors.grey[600]),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          '${grupo.totalMensagens}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (naoLidas > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366), // Verde do WhatsApp
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      naoLidas > 99 ? '99+' : naoLidas.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => widget.onGrupoSelected(grupo.id ?? grupo.tarefaId),
                      );
                    },
                  ),
                ),
    );
  }
}

