import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/status.dart';
import '../models/anexo.dart';
import '../services/status_service.dart';
import '../services/anexo_service.dart';
import '../services/chat_service.dart';
import '../services/divisao_service.dart';
import '../services/auth_service_simples.dart';
import '../services/like_service.dart';
import '../widgets/chat_screen.dart';
import '../utils/responsive.dart';
import '../config/supabase_config.dart';
import '../models/mensagem.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TaskCardsView extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const TaskCardsView({
    super.key,
    required this.tasks,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<TaskCardsView> createState() => _TaskCardsViewState();
}

class _TaskCardsViewState extends State<TaskCardsView> {
  // Mapa para armazenar o estado de curtida de cada tarefa
  final Map<String, bool> _likedTasks = {};
  // Mapa para armazenar contadores de curtidas
  final Map<String, int> _likeCounts = {};
  final StatusService _statusService = StatusService();
  final AnexoService _anexoService = AnexoService();
  final ChatService _chatService = ChatService();
  final LikeService _likeService = LikeService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  // Mapa para armazenar anexos de cada tarefa (taskId -> List<Anexo>)
  final Map<String, List<Anexo>> _anexosPorTarefa = {};
  // Mapa para armazenar URLs públicas das imagens (taskId -> List<String> de URLs)
  final Map<String, List<String>> _imagensPorTarefa = {};
  // Controllers para os carrosséis de cada tarefa
  final Map<String, PageController> _pageControllers = {};
  // Índice atual de cada carrossel
  final Map<String, int> _currentPageIndex = {};
  // Mapa para armazenar a data da última mensagem de cada tarefa (taskId -> DateTime?)
  final Map<String, DateTime?> _ultimaMensagemPorTarefa = {};
  // Mapa para armazenar mensagens de cada tarefa (taskId -> List<Mensagem>)
  final Map<String, List<Mensagem>> _mensagensPorTarefa = {};
  // Mapa para armazenar grupos de chat por tarefa (taskId -> grupoId)
  final Map<String, String?> _grupoIdPorTarefa = {};
  // Controllers para campos de comentário (taskId -> TextEditingController)
  final Map<String, TextEditingController> _commentControllers = {};
  // Lista ordenada de tarefas
  List<Task> _sortedTasks = [];
  // Subscriptions de streams de mensagens (grupoId -> StreamSubscription)
  final Map<String, StreamSubscription<List<Mensagem>>> _mensagensSubscriptions = {};

  Color _getStatusBadgeColor(String status) {
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      // Usar a cor do status para o badge
      return statusObj.color;
    }
    
    // Fallback para cores padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return Colors.yellow[600]!;
      case 'CONC':
        return Colors.green[600]!;
      case 'PROG':
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getStatusLabel(String status) {
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      return statusObj.status; // Retornar o nome do status
    }
    
    // Fallback para labels padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return 'Em Andamento';
      case 'CONC':
        return 'Concluído';
      case 'PROG':
        return 'Programado';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(TaskCardsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se as tarefas mudaram, recarregar dados
    if (oldWidget.tasks.length != widget.tasks.length ||
        !_listsEqual(oldWidget.tasks, widget.tasks)) {
      _initializeData();
    }
  }

  bool _listsEqual(List<Task> list1, List<Task> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  void _initializeData() {
    _loadStatus();
    _loadAnexos();
    _loadUltimasMensagens();
    _loadMensagens();
    _loadCurtidas();
  }

  Future<void> _loadAnexos() async {
    try {
      // Carregar anexos para todas as tarefas
      for (var task in widget.tasks) {
        try {
          final anexos = await _anexoService.getAnexosByTaskId(task.id);
          setState(() {
            _anexosPorTarefa[task.id] = anexos;
            // Encontrar todas as imagens
            if (anexos.isNotEmpty) {
              final imagens = anexos.where((anexo) => anexo.tipoArquivo == 'imagem').toList();
              if (imagens.isNotEmpty) {
                final urls = imagens.map((img) => _anexoService.getPublicUrl(img)).toList();
                _imagensPorTarefa[task.id] = urls;
                // Inicializar índice apenas se houver múltiplas imagens
                if (imagens.length > 1) {
                  _currentPageIndex[task.id] = 0;
                  // Garantir que o controller seja criado se ainda não existir
                  if (!_pageControllers.containsKey(task.id)) {
                    _pageControllers[task.id] = PageController();
                  }
                }
              } else {
                _imagensPorTarefa[task.id] = [];
              }
            } else {
              _imagensPorTarefa[task.id] = [];
            }
          });
        } catch (e) {
          // Ignorar erros individuais
          print('Erro ao carregar anexos da tarefa ${task.id}: $e');
          setState(() {
            _imagensPorTarefa[task.id] = [];
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar anexos: $e');
    }
  }

  @override
  void dispose() {
    // Limpar controllers
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    _pageControllers.clear();
    // Limpar controllers de comentários
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    _commentControllers.clear();
    // Cancelar todas as subscriptions de streams
    for (var subscription in _mensagensSubscriptions.values) {
      subscription.cancel();
    }
    _mensagensSubscriptions.clear();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final statusList = await _statusService.getAllStatus();
      setState(() {
        _statusMap = {
          for (var status in statusList) status.codigo: status
        };
      });
    } catch (e) {
      print('Erro ao carregar status: $e');
    }
  }

  Future<void> _loadUltimasMensagens() async {
    try {
      // Buscar a última mensagem de cada tarefa
      for (var task in widget.tasks) {
        try {
          final grupo = await _chatService.obterGrupoPorTarefaId(task.id);
          if (grupo != null && grupo.id != null) {
            // Usar ultimaMensagemAt do grupo se disponível, senão buscar
            if (grupo.ultimaMensagemAt != null) {
              setState(() {
                _ultimaMensagemPorTarefa[task.id] = grupo.ultimaMensagemAt;
              });
            } else {
              // Buscar a última mensagem do grupo diretamente do banco
              try {
                final supabase = SupabaseConfig.client;
                final response = await supabase
                    .from('mensagens')
                    .select('created_at')
                    .eq('grupo_id', grupo.id!)
                    .order('created_at', ascending: false)
                    .limit(1)
                    .maybeSingle();
                
                if (response != null && response['created_at'] != null) {
                  setState(() {
                    _ultimaMensagemPorTarefa[task.id] = DateTime.parse(response['created_at'] as String);
                  });
                } else {
                  setState(() {
                    _ultimaMensagemPorTarefa[task.id] = null;
                  });
                }
              } catch (e) {
                setState(() {
                  _ultimaMensagemPorTarefa[task.id] = null;
                });
              }
            }
          } else {
            setState(() {
              _ultimaMensagemPorTarefa[task.id] = null;
            });
          }
        } catch (e) {
          print('Erro ao carregar última mensagem da tarefa ${task.id}: $e');
          setState(() {
            _ultimaMensagemPorTarefa[task.id] = null;
          });
        }
      }
      
      // Ordenar tarefas pela data da última mensagem (mais recente primeiro)
      _sortedTasks = List<Task>.from(widget.tasks);
      _sortedTasks.sort((a, b) {
        final dataA = _ultimaMensagemPorTarefa[a.id];
        final dataB = _ultimaMensagemPorTarefa[b.id];
        
        // Tarefas com mensagens aparecem primeiro
        if (dataA != null && dataB != null) {
          return dataB.compareTo(dataA); // Mais recente primeiro
        } else if (dataA != null) {
          return -1; // A tem mensagem, B não
        } else if (dataB != null) {
          return 1; // B tem mensagem, A não
        } else {
          // Ambos sem mensagens, manter ordem original
          return 0;
        }
      });
      
      setState(() {});
    } catch (e) {
      print('Erro ao carregar últimas mensagens: $e');
      // Em caso de erro, usar lista original
      _sortedTasks = List<Task>.from(widget.tasks);
      setState(() {});
    }
  }

  Future<void> _loadMensagens() async {
    try {
      // Cancelar subscriptions antigas de grupos que não pertencem mais a nenhuma tarefa atual
      final gruposAtuais = <String>{};
      
      // Primeiro, coletar todos os grupos das tarefas atuais
      for (var task in widget.tasks) {
        final grupoId = _grupoIdPorTarefa[task.id];
        if (grupoId != null) {
          gruposAtuais.add(grupoId);
        }
      }
      
      // Remover subscriptions de grupos que não estão mais nas tarefas atuais
      final gruposParaRemover = <String>[];
      for (var entry in _mensagensSubscriptions.entries) {
        final grupoId = entry.key;
        if (!gruposAtuais.contains(grupoId)) {
          gruposParaRemover.add(grupoId);
        }
      }
      
      for (var grupoId in gruposParaRemover) {
        _mensagensSubscriptions[grupoId]?.cancel();
        _mensagensSubscriptions.remove(grupoId);
      }
      
      // Carregar mensagens para todas as tarefas
      for (var task in widget.tasks) {
        try {
          final grupo = await _chatService.obterGrupoPorTarefaId(task.id);
          if (grupo != null && grupo.id != null) {
            final grupoId = grupo.id!;
            setState(() {
              _grupoIdPorTarefa[task.id] = grupoId;
            });
            
            // Carregar mensagens do grupo inicialmente
            try {
              final mensagens = await _chatService.listarMensagens(grupoId);
              setState(() {
                _mensagensPorTarefa[task.id] = mensagens;
              });
              
              // Configurar stream de mensagens em tempo real para refletir edições/exclusões
              if (!_mensagensSubscriptions.containsKey(grupoId)) {
                _setupMensagensStream(grupoId, task.id);
              }
            } catch (e) {
              print('Erro ao carregar mensagens da tarefa ${task.id}: $e');
              setState(() {
                _mensagensPorTarefa[task.id] = [];
              });
            }
          } else {
            setState(() {
              _grupoIdPorTarefa[task.id] = null;
              _mensagensPorTarefa[task.id] = [];
            });
          }
        } catch (e) {
          print('Erro ao obter grupo da tarefa ${task.id}: $e');
          setState(() {
            _grupoIdPorTarefa[task.id] = null;
            _mensagensPorTarefa[task.id] = [];
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
    }
  }

  void _setupMensagensStream(String grupoId, String taskId) {
    // Cancelar subscription anterior se existir
    _mensagensSubscriptions[grupoId]?.cancel();
    
    // Criar nova subscription para o stream de mensagens
    final subscription = _chatService
        .streamMensagens(grupoId)
        .listen((mensagens) {
      // Atualizar mensagens da tarefa quando houver mudanças (edições/exclusões)
      if (mounted) {
        setState(() {
          _mensagensPorTarefa[taskId] = mensagens;
          
          // Atualizar data da última mensagem se houver mensagens
          if (mensagens.isNotEmpty) {
            final ultimaMensagem = mensagens.last;
            _ultimaMensagemPorTarefa[taskId] = ultimaMensagem.createdAt;
          } else {
            // Se não há mais mensagens, limpar a data
            _ultimaMensagemPorTarefa[taskId] = null;
          }
        });
        
        // Reordenar tarefas após atualização
        _sortedTasks.sort((a, b) {
          final dataA = _ultimaMensagemPorTarefa[a.id];
          final dataB = _ultimaMensagemPorTarefa[b.id];
          
          if (dataA != null && dataB != null) {
            return dataB.compareTo(dataA);
          } else if (dataA != null) {
            return -1;
          } else if (dataB != null) {
            return 1;
          } else {
            return 0;
          }
        });
      }
    }, onError: (error) {
      print('Erro no stream de mensagens do grupo $grupoId: $error');
    });
    
    _mensagensSubscriptions[grupoId] = subscription;
  }

  Future<void> _enviarComentario(Task task) async {
    final controller = _commentControllers[task.id];
    if (controller == null || controller.text.trim().isEmpty) {
      return;
    }

    final conteudo = controller.text.trim();
    controller.clear();

    try {
      // Obter ou criar grupo
      var grupo = await _chatService.obterGrupoPorTarefaId(task.id);
      
      if (grupo == null) {
        // Criar grupo se não existir
        if (task.divisaoId == null || task.segmentoId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível comentar: tarefa sem divisão ou segmento'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        final divisaoService = DivisaoService();
        final divisao = await divisaoService.getDivisaoById(task.divisaoId!);
        
        if (divisao == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível comentar: divisão não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        if (!divisao.segmentoIds.contains(task.segmentoId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível comentar: segmento não encontrado'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        final segmentoIndex = divisao.segmentoIds.indexOf(task.segmentoId!);
        final segmentoNome = segmentoIndex >= 0 && segmentoIndex < divisao.segmentos.length
            ? divisao.segmentos[segmentoIndex]
            : 'Segmento';
        
        final comunidade = await _chatService.criarOuObterComunidade(
          task.divisaoId!,
          divisao.divisao,
          task.segmentoId!,
          segmentoNome,
        );
        
        if (comunidade.id == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar comunidade'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        grupo = await _chatService.criarOuObterGrupo(
          task.id,
          task.tarefa,
          comunidade.id!,
        );
      }

      final grupoId = grupo.id;
      if (grupoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao criar grupo de chat'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obter nome do usuário atual
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final usuarioNome = usuario?.nome ?? usuario?.email.split('@').first ?? 'Usuário';

      // Enviar mensagem
      final mensagem = await _chatService.enviarMensagem(
        grupoId,
        conteudo,
        usuarioNome: usuarioNome,
      );

      // Atualizar lista de mensagens
      setState(() {
        _grupoIdPorTarefa[task.id] = grupoId;
        _mensagensPorTarefa[task.id] = [
          ...(_mensagensPorTarefa[task.id] ?? []),
          mensagem,
        ];
        // Atualizar data da última mensagem para reordenar
        _ultimaMensagemPorTarefa[task.id] = mensagem.createdAt;
      });
      
      // Garantir que o stream está configurado para esta tarefa
      if (!_mensagensSubscriptions.containsKey(grupoId)) {
        _setupMensagensStream(grupoId, task.id);
      }

      // Reordenar tarefas
      _sortedTasks.sort((a, b) {
        final dataA = _ultimaMensagemPorTarefa[a.id];
        final dataB = _ultimaMensagemPorTarefa[b.id];
        
        if (dataA != null && dataB != null) {
          return dataB.compareTo(dataA);
        } else if (dataA != null) {
          return -1;
        } else if (dataB != null) {
          return 1;
        } else {
          return 0;
        }
      });

      setState(() {});
    } catch (e) {
      print('Erro ao enviar comentário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar comentário: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    // Calcular largura máxima do card (centralizado)
    double maxWidth;
    if (isMobile) {
      maxWidth = double.infinity;
    } else if (isTablet) {
      maxWidth = 600;
    } else {
      maxWidth = 500;
    }

    return Container(
      color: Colors.grey[50],
      child: isMobile
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sortedTasks.isEmpty ? widget.tasks.length : _sortedTasks.length,
              cacheExtent: 500,
              itemBuilder: (context, index) {
                final task = _sortedTasks.isEmpty ? widget.tasks[index] : _sortedTasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTaskCard(task, isMobile),
                );
              },
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _sortedTasks.isEmpty ? widget.tasks.length : _sortedTasks.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final task = _sortedTasks.isEmpty ? widget.tasks[index] : _sortedTasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildTaskCard(task, isMobile),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildTaskCard(Task task, bool isMobile) {
    // Obter lista de URLs das imagens dos anexos, se houver
    final imagens = _imagensPorTarefa[task.id] ?? [];
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header com avatar e status (estilo rede social)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getStatusBadgeColor(task.status),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // Nome do executor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.executor,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.coordenador.isNotEmpty)
                        Text(
                          task.coordenador,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Badge de status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBadgeColor(task.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(task.status),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Menu de ações
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.black87),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        widget.onEdit?.call(task);
                        break;
                      case 'delete':
                        widget.onDelete?.call(task);
                        break;
                      case 'duplicate':
                        widget.onDuplicate?.call(task);
                        break;
                      case 'subtask':
                        widget.onCreateSubtask?.call(task);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Duplicar'),
                        ],
                      ),
                    ),
                    if (task.isMainTask)
                      const PopupMenuItem(
                        value: 'subtask',
                        child: Row(
                          children: [
                            Icon(Icons.add_task, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Inserir Subtarefa'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Imagens dos anexos (carrossel se houver múltiplas, ou apenas uma)
          if (imagens.isNotEmpty) _buildImageCarousel(task, imagens),
          // Ações (curtir, comentar, compartilhar) - estilo rede social
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildActionButton(
                  task.id,
                  Icons.favorite_border,
                  Icons.favorite,
                  'Curtir',
                  isMobile,
                  _likedTasks[task.id] ?? false,
                  _likeCounts[task.id] ?? 0,
                  () => _handleLike(task.id),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  task.id,
                  Icons.comment_outlined,
                  Icons.comment,
                  'Comentar',
                  isMobile,
                  false,
                  null,
                  () => _handleComment(task),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  task.id,
                  Icons.share_outlined,
                  Icons.share,
                  'Compartilhar',
                  isMobile,
                  false,
                  null,
                  () => _handleShare(task),
                ),
              ],
            ),
          ),
          // Conteúdo do card (título e observações)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Curtidas (se houver)
                if ((_likeCounts[task.id] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_formatCount(_likeCounts[task.id] ?? 0)} curtidas',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                // Título da tarefa (como nome do usuário na legenda)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: task.executor,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: task.tarefa,
                      ),
                    ],
                  ),
                ),
                // Observações (como legenda do post)
                if (task.observacoes != null && task.observacoes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.observacoes!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Informações adicionais (localização e tipo)
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (task.locais.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            task.locais.join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          task.tipo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Seção de comentários
          _buildComentariosSection(task, isMobile),
        ],
      ),
    );
  }

  Widget _buildComentariosSection(Task task, bool isMobile) {
    final mensagens = _mensagensPorTarefa[task.id] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de comentários
        if (mensagens.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ver todos os comentários (se houver mais de 2)
                if (mensagens.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _handleComment(task),
                      child: Text(
                        'Ver todos os ${mensagens.length} comentários',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Mostrar últimos 2 comentários
                ...mensagens.reversed.take(2).map((mensagem) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar pequeno
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          mensagem.usuarioNome?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Comentário
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: mensagem.usuarioNome ?? 'Usuário',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: mensagem.conteudo,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(mensagem.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
        // Campo de input para novo comentário
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Avatar do usuário atual
              Builder(
                builder: (context) {
                  final authService = AuthServiceSimples();
                  final usuario = authService.currentUser;
                  final usuarioNome = usuario?.nome ?? usuario?.email.split('@').first ?? 'U';
                  final inicial = usuarioNome.isNotEmpty ? usuarioNome.substring(0, 1).toUpperCase() : 'U';
                  
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Campo de texto
              Expanded(
                child: TextField(
                  controller: _commentControllers.putIfAbsent(
                    task.id,
                    () => TextEditingController(),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Adicione um comentário...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviarComentario(task),
                ),
              ),
              // Botão de enviar
              IconButton(
                icon: const Icon(Icons.send, size: 20, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _enviarComentario(task),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'Agora';
    }
  }

  Widget _buildActionButton(
    String taskId,
    IconData icon,
    IconData filledIcon,
    String label,
    bool isMobile,
    bool isActive,
    int? count,
    VoidCallback onTap,
  ) {
    final isLiked = label == 'Curtir' && isActive;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(
          isLiked ? filledIcon : icon,
          size: 24,
          color: isLiked ? Colors.red : Colors.black87,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  Future<void> _loadCurtidas() async {
    try {
      if (widget.tasks.isEmpty) return;

      final taskIds = widget.tasks.map((t) => t.id).toList();

      // Carregar contadores de curtidas
      final contagens = await _likeService.contarCurtidasPorTarefas(taskIds);
      setState(() {
        for (var taskId in taskIds) {
          _likeCounts[taskId] = contagens[taskId] ?? 0;
        }
      });

      // Carregar estado de curtidas do usuário atual
      final curtidasUsuario = await _likeService.verificarCurtidasPorTarefas(taskIds);
      setState(() {
        for (var taskId in taskIds) {
          _likedTasks[taskId] = curtidasUsuario[taskId] ?? false;
        }
      });
    } catch (e) {
      print('Erro ao carregar curtidas: $e');
    }
  }

  Future<void> _handleLike(String taskId) async {
    // Feedback visual imediato
    HapticFeedback.lightImpact();
    
    // Otimistic update
    final isLiked = _likedTasks[taskId] ?? false;
    final currentCount = _likeCounts[taskId] ?? 0;
    
    setState(() {
      _likedTasks[taskId] = !isLiked;
      _likeCounts[taskId] = isLiked ? currentCount - 1 : currentCount + 1;
    });

    try {
      // Alternar curtida no banco
      final novoEstado = await _likeService.alternarCurtida(taskId);
      
      // Atualizar contador real
      final contagemReal = await _likeService.contarCurtidas(taskId);
      
      setState(() {
        _likedTasks[taskId] = novoEstado;
        _likeCounts[taskId] = contagemReal;
      });
    } catch (e) {
      // Reverter em caso de erro
      setState(() {
        _likedTasks[taskId] = isLiked;
        _likeCounts[taskId] = currentCount;
      });
      
      if (mounted) {
        final errorMessage = e.toString();
        final mensagem = errorMessage.contains('não encontrada') 
            ? 'Tabela de curtidas não configurada. Execute o script SQL criar_tabela_curtidas.sql no Supabase.'
            : 'Erro ao ${isLiked ? 'descurtir' : 'curtir'}: ${errorMessage.replaceAll('Exception: ', '')}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: errorMessage.contains('não encontrada') 
                ? SnackBarAction(
                    label: 'Ver SQL',
                    textColor: Colors.white,
                    onPressed: () {
                      // Pode abrir o arquivo SQL se necessário
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _handleComment(Task task) async {
    HapticFeedback.mediumImpact();
    
    try {
      // Obter ou criar grupo de chat para a tarefa
      var grupoChat = await _chatService.obterGrupoPorTarefaId(task.id);
      
      if (grupoChat == null) {
        // Criar grupo se não existir
        // Primeiro, obter ou criar comunidade
        if (task.divisaoId == null || task.segmentoId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível criar chat: tarefa sem divisão ou segmento'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        final divisaoService = DivisaoService();
        final divisao = await divisaoService.getDivisaoById(task.divisaoId!);
        
        if (divisao == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível criar chat: divisão não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        // Verificar se o segmento está na lista de segmentos da divisão
        if (!divisao.segmentoIds.contains(task.segmentoId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível criar chat: segmento não encontrado na divisão'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        // Obter nome do segmento
        final segmentoIndex = divisao.segmentoIds.indexOf(task.segmentoId!);
        final segmentoNome = segmentoIndex >= 0 && segmentoIndex < divisao.segmentos.length
            ? divisao.segmentos[segmentoIndex]
            : 'Segmento';
        
        final comunidade = await _chatService.criarOuObterComunidade(
          task.divisaoId!,
          divisao.divisao,
          task.segmentoId!,
          segmentoNome,
        );
        
        grupoChat = await _chatService.criarOuObterGrupo(
          comunidade.id!,
          task.id,
          task.tarefa,
        );
      }
      
      if (mounted) {
        final grupoId = grupoChat.id;
        if (grupoId != null) {
          // Navegar para a tela de chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                grupoId: grupoId,
                onBack: () => Navigator.pop(context),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao abrir chat da tarefa'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao abrir chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _handleShare(Task task) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Compartilhar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(Icons.message, 'Mensagem', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compartilhando via Mensagem...')),
                  );
                }),
                _buildShareOption(Icons.email, 'Email', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compartilhando via Email...')),
                  );
                }),
                _buildShareOption(Icons.link, 'Copiar Link', () {
                  Clipboard.setData(ClipboardData(text: 'Tarefa: ${task.tarefa}'));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado!')),
                  );
                }),
                _buildShareOption(Icons.more_horiz, 'Mais', () {
                  Navigator.pop(context);
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }


  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'PMP':
        return Icons.build;
      case 'FERIAS':
        return Icons.beach_access;
      case 'TREINAMENTO':
        return Icons.school;
      case 'COMPENSACAO':
        return Icons.access_time;
      case 'CORRECAO':
        return Icons.construction;
      default:
        return Icons.work;
    }
  }

  Widget _buildImageCarousel(Task task, List<String> imagens) {
    final hasMultipleImages = imagens.length > 1;
    final isMobile = Responsive.isMobile(context);
    
    // Se houver apenas uma imagem, mostrar diretamente sem PageView
    if (!hasMultipleImages) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: CachedNetworkImage(
          imageUrl: imagens.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                _getIconForType(task.tipo),
                size: 48,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
      );
    }

    // Se houver múltiplas imagens, criar carrossel
    // Garantir que o controller existe
    if (!_pageControllers.containsKey(task.id)) {
      _pageControllers[task.id] = PageController();
    }
    if (!_currentPageIndex.containsKey(task.id)) {
      _currentPageIndex[task.id] = 0;
    }
    
    final controller = _pageControllers[task.id]!;
    final currentIndex = _currentPageIndex[task.id]!;

    return AspectRatio(
      aspectRatio: 1.0, // Quadrado (1:1)
      child: Stack(
        children: [
          // Carrossel de imagens
          PageView.builder(
            key: ValueKey('carousel_${task.id}_${imagens.length}'), // Key única para forçar rebuild quando necessário
            controller: controller,
            itemCount: imagens.length,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex[task.id] = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // No desktop, permitir clique para navegar (alternativa ao arrastar)
                  // Mas não interferir com o arrastar
                },
                child: CachedNetworkImage(
                  imageUrl: imagens[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        _getIconForType(task.tipo),
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Botões de navegação (apenas no desktop)
          if (!isMobile) ...[
            // Botão anterior (esquerda)
            if (currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withOpacity(0.3),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Botão próximo (direita)
            if (currentIndex < imagens.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black.withOpacity(0.3),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          // Indicadores de página (dots) - torná-los clicáveis no desktop
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imagens.length,
                (index) => GestureDetector(
                  onTap: () {
                    controller.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      border: currentIndex == index
                          ? null
                          : Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

