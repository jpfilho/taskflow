import 'package:flutter/material.dart';
import '../models/grupo_chat.dart';
import '../services/chat_service.dart';
import '../services/task_service.dart';

class ChatGruposList extends StatefulWidget {
  final String comunidadeId;
  final Function(String) onGrupoSelected;
  final VoidCallback onBack;

  const ChatGruposList({
    super.key,
    required this.comunidadeId,
    required this.onGrupoSelected,
    required this.onBack,
  });

  @override
  State<ChatGruposList> createState() => _ChatGruposListState();
}

class _ChatGruposListState extends State<ChatGruposList> {
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
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

      // Carregar tarefas para criar grupos que ainda não existem
      final todasTarefas = await _taskService.getAllTasks();
      
      // Filtrar tarefas que pertencem a esta comunidade (via divisão + segmento)
      // Precisamos obter a comunidade para saber qual divisão e segmento
      final comunidade = await _chatService.obterComunidadePorId(widget.comunidadeId);
      if (comunidade != null) {
        final tarefasDaComunidade = todasTarefas
            .where((t) => 
                t.divisaoId == comunidade.divisaoId &&
                t.segmentoId == comunidade.segmentoId)
            .toList();

        // Criar grupos para tarefas que ainda não têm
        for (var tarefa in tarefasDaComunidade) {
          final grupoExistente = grupos.firstWhere(
            (g) => g.tarefaId == tarefa.id,
            orElse: () => GrupoChat(
              tarefaId: '',
              tarefaNome: '',
              comunidadeId: '',
            ),
          );

          if (grupoExistente.tarefaId.isEmpty) {
            try {
              final novoGrupo = await _chatService.criarOuObterGrupo(
                tarefa.id,
                tarefa.tarefa,
                widget.comunidadeId,
              );
              grupos.add(novoGrupo);
            } catch (e) {
              print('Erro ao criar grupo para tarefa ${tarefa.id}: $e');
            }
          }
        }
      }

      // Atualizar contadores de mensagens não lidas
      for (var grupo in grupos) {
        final naoLidas = await _chatService.contarMensagensNaoLidas(grupo.id ?? '');
        grupos[grupos.indexOf(grupo)] = grupo.copyWith(
          mensagensNaoLidas: naoLidas,
        );
      }

      // Ordenar por última mensagem (mais recente primeiro)
      grupos.sort((a, b) {
        final aData = a.ultimaMensagemAt ?? DateTime(1970);
        final bData = b.ultimaMensagemAt ?? DateTime(1970);
        return bData.compareTo(aData);
      });

      setState(() {
        _grupos = grupos;
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
        title: const Text('Grupos'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leading: IconButton(
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

