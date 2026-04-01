import 'package:flutter/material.dart';
import '../models/grupo_chat.dart';
import '../services/chat_service.dart';

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
  List<GrupoChat> _grupos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrupos();
  }

  Future<void> _loadGrupos() async {
    setState(() => _isLoading = true);
    try {
      // Carregar grupos da comunidade
      var grupos = await _chatService.listarGruposPorComunidade(widget.comunidadeId);

      // Otimização: Coletar IPs sem precisar de N+1 queries.
      final gruposIds = grupos.where((g) => g.id != null).map((g) => g.id!).toList();

      if (gruposIds.isEmpty) {
         setState(() {
            _grupos = [];
            _isLoading = false;
         });
         return;
      }

      // 1. Obter a última mensagem de todos os grupos listados
      final ultimasMsgsMap = await _chatService.obterUltimaMensagemPorGrupos(gruposIds);

      // 2. Identificar grupos válidos e puxar Lidas
      final gruposAtivosIds = ultimasMsgsMap.keys.toList();

      if (gruposAtivosIds.isEmpty) {
         setState(() {
            _grupos = [];
            _isLoading = false;
         });
         return;
      }

      final naoLidasMap = await _chatService.contarMensagensNaoLidasEmLote(gruposAtivosIds);

      // 3. Montar matriz
      var gruposComMensagem = <GrupoChat>[];
      for (var grupo in grupos) {
         if (grupo.id != null && ultimasMsgsMap.containsKey(grupo.id!)) {
            final ultima = ultimasMsgsMap[grupo.id!]!;
            gruposComMensagem.add(grupo.copyWith(
               ultimaMensagemAt: ultima.createdAt,
               ultimaMensagemPreview: ultima.conteudo,
               mensagensNaoLidas: naoLidasMap[grupo.id!] ?? 0
            ));
         }
      }

      // Ordenar por última mensagem (mais recente primeiro)
      gruposComMensagem.sort((a, b) {
        final aData = a.ultimaMensagemAt ?? a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bData = b.ultimaMensagemAt ?? b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bData.compareTo(aData);
      });

      setState(() {
        _grupos = gruposComMensagem;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar grupos: $e');
      setState(() => _isLoading = false);
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
                      final naoLidas = grupo.mensagensNaoLidas ?? 0;

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
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                grupo.ultimaMensagemPreview ?? 'Nenhuma mensagem',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            if (grupo.ultimaMensagemAt != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatarData(grupo.ultimaMensagemAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: naoLidas > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366), // Verde do WhatsApp
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  naoLidas > 99 ? '99+' : naoLidas.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => widget.onGrupoSelected(grupo.id ?? grupo.tarefaId),
                      );
                    },
                  ),
                ),
    );
  }
}

