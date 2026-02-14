import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../models/anexo.dart';
import '../services/status_service.dart';
import '../services/anexo_service.dart';
import '../services/chat_service.dart';
import '../services/divisao_service.dart';
import '../services/auth_service_simples.dart';
import '../services/like_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import '../services/tipo_atividade_service.dart';
import '../models/tipo_atividade.dart';
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
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();
  final TipoAtividadeService _tipoService = TipoAtividadeService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  Map<String, int> _notasSAPCount =
      {}; // Mapa de taskId -> quantidade de notas SAP
  Map<String, int> _ordensCount = {}; // Mapa de taskId -> quantidade de ordens
  Map<String, int> _atsCount = {}; // Mapa de taskId -> quantidade de ATs
  Map<String, int> _sisCount = {}; // Mapa de taskId -> quantidade de SIs
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
  // Alertas geoespaciais por tarefa (id -> mapa de tipo+janela)
  // Controllers para campos de comentário (taskId -> TextEditingController)
  final Map<String, TextEditingController> _commentControllers = {};
  // Lista ordenada de tarefas
  List<Task> _sortedTasks = [];
  // Tipos de atividade
  Map<String, TipoAtividade> _tiposMap = {};
  // SIs por tarefa (detalhes)
  final Map<String, List<SI>> _sisPorTarefa = {};

  List<String> _siCodesFromTask(Task t) {
    final raw = t.si.trim();
    if (raw.isEmpty) return [];
    final lower = raw.toLowerCase();
    const invalids = {
      'n/a',
      '-n/a-',
      '-n/a',
      'n/a-',
      'na',
      'sem',
      '-',
      's/i',
      's.i',
    };
    if (invalids.contains(lower)) return [];
    return raw
        .split(RegExp(r'[;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !invalids.contains(e.toLowerCase()))
        .toList();
  }

  // Subscriptions de streams de mensagens (grupoId -> StreamSubscription)
  final Map<String, StreamSubscription<List<Mensagem>>>
  _mensagensSubscriptions = {};
  StreamSubscription<String>? _statusChangeSubscription;

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

  String _getTipoDescricao(String tipoCodigo) {
    final t = _tiposMap[tipoCodigo.toUpperCase()];
    if (t != null && t.descricao.isNotEmpty) {
      return t.descricao;
    }
    return tipoCodigo;
  }

  List<Widget> _buildExtraInfoLines(Task task) {
    final lines = <Widget>[];
    void addLine(String label, String value, {bool showLabel = true}) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            showLabel ? '$label: $value' : value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (task.frota.isNotEmpty) {
      addLine('Frota', task.frota);
    }
    final notaCount = _notasSAPCount[task.id] ?? 0;
    if (notaCount > 0) {
      addLine('Nota', notaCount.toString());
    }
    if (task.ordem != null && task.ordem!.isNotEmpty) {
      addLine('Ordem', task.ordem!);
    } else {
      final ordCount = _ordensCount[task.id] ?? 0;
      if (ordCount > 0) addLine('Ordem', ordCount.toString());
    }
    final atCount = _atsCount[task.id] ?? 0;
    if (atCount > 0) {
      addLine('AT', atCount.toString());
    }
    final siCodes = _siCodesFromTask(task);
    if (siCodes.isNotEmpty) {
      for (final code in siCodes) {
        // Se já carregamos detalhes, eles serão mostrados abaixo
        if ((_sisPorTarefa[task.id] ?? []).isEmpty) {
          addLine('SI', code, showLabel: false);
        }
      }
    }
    if (siCodes.isEmpty) {
      final siList = _sisPorTarefa[task.id] ?? [];
      if (siList.isNotEmpty) {
        for (final si in siList) {
          final dataIni = si.dataInicio != null
              ? '${si.dataInicio!.day}/${si.dataInicio!.month}/${si.dataInicio!.year}'
              : null;
          final dataFim = si.dataFim != null
              ? '${si.dataFim!.day}/${si.dataFim!.month}/${si.dataFim!.year}'
              : null;
          final partes = <String>[
            si.solicitacao,
            if ((si.tipo ?? '').isNotEmpty) si.tipo!,
            if ((si.textoBreve ?? '').isNotEmpty) si.textoBreve!,
            if (dataIni != null) 'Início: $dataIni',
            if (dataFim != null) 'Fim: $dataFim',
          ];
          addLine('SI', partes.join(' | '), showLabel: false);
        }
      } else {
        final siCount = _sisCount[task.id] ?? 0;
        if (siCount > 0) addLine('SI', siCount.toString(), showLabel: false);
      }
    }

    return lines;
  }

  @override
  void initState() {
    super.initState();
    // Inicializar mapa de datas com atualização da tarefa para já ordenar antes dos loads assíncronos
    for (final t in widget.tasks) {
      _ultimaMensagemPorTarefa[t.id] = t.dataAtualizacao ?? t.dataFim;
    }
    _sortedTasks = List<Task>.from(widget.tasks);
    _applySorting();
    _initializeData();
  }

  @override
  void didUpdateWidget(TaskCardsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se as tarefas mudaram, recarregar dados
    if (oldWidget.tasks.length != widget.tasks.length ||
        !_listsEqual(oldWidget.tasks, widget.tasks)) {
      // Resetar mapa de datas base para nova lista
      _ultimaMensagemPorTarefa.clear();
      for (final t in widget.tasks) {
        _ultimaMensagemPorTarefa[t.id] = t.dataAtualizacao ?? t.dataFim;
      }
      _sortedTasks = List<Task>.from(widget.tasks);
      _applySorting();
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

  void _applySorting() {
    DateTime _sortKey(Task t) {
      final v = _ultimaMensagemPorTarefa[t.id];
      if (v != null) return v;
      if (t.dataAtualizacao != null) return t.dataAtualizacao!;
      return t.dataFim;
    }

    _sortedTasks = List<Task>.from(widget.tasks);
    _sortedTasks.sort((a, b) {
      final dataA = _sortKey(a);
      final dataB = _sortKey(b);
      return dataB.compareTo(dataA); // Mais recente primeiro
    });
  }

  void _initializeData() {
    _loadStatus();
    _loadTipos();
    _loadAnexos();
    _loadUltimasMensagens();
    _loadSIs();
    _loadMensagens();
    _loadCurtidas();
    _loadSAPCounts();
    // Escutar mudanças nos status
    _statusChangeSubscription?.cancel();
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
  }

  Future<void> _loadSAPCounts() async {
    if (widget.tasks.isEmpty || !mounted) return;
    try {
      final taskIds = widget.tasks.map((t) => t.id).toList();

      final notasSAPFuture = _notaSAPService.contarNotasPorTarefas(taskIds);
      final ordensFuture = _ordemService.contarOrdensPorTarefas(taskIds);
      final atsFuture = _atService.contarATsPorTarefas(taskIds);
      final sisFuture = _siService.contarSIsPorTarefas(taskIds);

      final results = await Future.wait([
        notasSAPFuture,
        ordensFuture,
        atsFuture,
        sisFuture,
      ]);

      if (mounted) {
        setState(() {
          _notasSAPCount = results[0];
          _ordensCount = results[1];
          _atsCount = results[2];
          _sisCount = results[3];
        });
      }
    } catch (e) {
      print('Erro ao carregar contagens SAP: $e');
    }
  }

  Future<void> _loadSIs() async {
    if (widget.tasks.isEmpty) return;
    try {
      final futures = widget.tasks.map((t) => _siService.getSIsPorTarefa(t.id));
      final results = await Future.wait(futures);
      // Fallback: se não houver vínculo na tasks_sis mas a tarefa tem campo SI preenchido, buscar por solicitação
      for (int i = 0; i < widget.tasks.length; i++) {
        final codes = _siCodesFromTask(widget.tasks[i]);
        if (results[i].isEmpty && codes.isNotEmpty) {
          final fetched = <SI>[];
          for (final code in codes) {
            final si = await _siService.getSIPorSolicitacao(code);
            if (si != null) fetched.add(si);
          }
          if (fetched.isNotEmpty) {
            results[i] = fetched;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _sisPorTarefa.clear();
        for (int i = 0; i < widget.tasks.length; i++) {
          _sisPorTarefa[widget.tasks[i].id] = results[i];
        }
      });
    } catch (e) {
      print('Erro ao carregar SIs por tarefa: $e');
    }
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
              final imagens = anexos
                  .where((anexo) => anexo.tipoArquivo == 'imagem')
                  .toList();
              if (imagens.isNotEmpty) {
                final urls = imagens
                    .map((img) => _anexoService.getPublicUrl(img))
                    .toList();
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
    _statusChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final statusList = await _statusService.getAllStatus();
      setState(() {
        _statusMap = {for (var status in statusList) status.codigo: status};
      });
    } catch (e) {
      print('Erro ao carregar status: $e');
    }
  }

  Future<void> _loadTipos() async {
    try {
      final tipos = await _tipoService.getTiposAtividadeAtivos();
      setState(() {
        _tiposMap = {for (var t in tipos) t.codigo.toUpperCase(): t};
      });
    } catch (e) {
      print('Erro ao carregar tipos de atividade: $e');
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
                    _ultimaMensagemPorTarefa[task.id] = DateTime.parse(
                      response['created_at'] as String,
                    );
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

      _applySorting();
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
        .listen(
          (mensagens) {
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
              _applySorting();
            }
          },
          onError: (error) {
            print('Erro no stream de mensagens do grupo $grupoId: $error');
          },
        );

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
              content: Text(
                'Não é possível comentar: tarefa sem divisão ou segmento',
              ),
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
        final segmentoNome =
            segmentoIndex >= 0 && segmentoIndex < divisao.segmentos.length
            ? divisao.segmentos[segmentoIndex]
            : 'Segmento';

        final comunidade = await _chatService.criarOuObterComunidade(
          task.regionalId ?? '',
          task.regional,
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
      final usuarioNome =
          usuario?.nome ?? usuario?.email.split('@').first ?? 'Usuário';

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
      _applySorting();
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
              itemCount: _sortedTasks.length,
              cacheExtent: 500,
              itemBuilder: (context, index) {
                final task = _sortedTasks[index];
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: _sortedTasks.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final task = _sortedTasks[index];
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

  /// URLs de imagens a exibir no feed: anexos da tarefa + imagens enviadas no chat.
  List<String> _imagensParaCard(Task task) {
    final anexos = _imagensPorTarefa[task.id] ?? [];
    final mensagens = _mensagensPorTarefa[task.id] ?? [];
    final urlsChat = mensagens
        .where((m) =>
            (m.tipo == 'imagem' || m.tipo == 'image') &&
            m.arquivoUrl != null &&
            m.arquivoUrl!.trim().isNotEmpty)
        .map((m) => m.arquivoUrl!)
        .toList();
    if (urlsChat.isEmpty) return anexos;
    return [...anexos, ...urlsChat];
  }

  Widget _buildTaskCard(Task task, bool isMobile) {
    // Imagens: anexos da tarefa + imagens enviadas no chat
    final imagens = _imagensParaCard(task);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
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
                    Icons.assignment,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // Título (tarefa) e coordenador
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.tarefa,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.coordenador.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            task.coordenador,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge de status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.black87,
                  ),
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
          // Ações (curtir, comentar, compartilhar, SAP) - estilo rede social
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
                // SAP Actions
                if ((_notasSAPCount[task.id] ?? 0) > 0 ||
                    (_ordensCount[task.id] ?? 0) > 0 ||
                    (_atsCount[task.id] ?? 0) > 0 ||
                    (_sisCount[task.id] ?? 0) > 0) ...[
                  const SizedBox(width: 16),
                  _buildSAPActionButton(task, isMobile),
                ],
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
                // Linha de executores (sem tarefa)
                Builder(
                  builder: (_) {
                    final execText = task.executores.isNotEmpty
                        ? task.executores.join(', ')
                        : task.executor;
                    if (execText.isEmpty) return const SizedBox.shrink();
                    return Text(
                      execText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                // Observações (como legenda do post)
                if (task.observacoes != null &&
                    task.observacoes!.isNotEmpty) ...[
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
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
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
                          _getTipoDescricao(task.tipo),
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
                // Informações adicionais: Frota, Nota, Ordem, AT, SI (cada uma em linha separada)
                ..._buildExtraInfoLines(task),
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
                ...mensagens.reversed
                    .take(2)
                    .map(
                      (mensagem) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar pequeno
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[300],
                              child: Text(
                                mensagem.usuarioNome
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'U',
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
                                          text:
                                              mensagem.usuarioNome ?? 'Usuário',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(text: ' '),
                                        TextSpan(text: mensagem.conteudo),
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
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ],
        // Campo de input para novo comentário
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            children: [
              // Avatar do usuário atual
              Builder(
                builder: (context) {
                  final authService = AuthServiceSimples();
                  final usuario = authService.currentUser;
                  final usuarioNome =
                      usuario?.nome ?? usuario?.email.split('@').first ?? 'U';
                  final inicial = usuarioNome.isNotEmpty
                      ? usuarioNome.substring(0, 1).toUpperCase()
                      : 'U';

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
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
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

  Widget _buildSAPActionButton(Task task, bool isMobile) {
    final totalSAP =
        (_notasSAPCount[task.id] ?? 0) +
        (_ordensCount[task.id] ?? 0) +
        (_atsCount[task.id] ?? 0) +
        (_sisCount[task.id] ?? 0);

    return PopupMenuButton<String>(
      icon: Stack(
        children: [
          const Icon(Icons.inventory_2, size: 24, color: Colors.black87),
          if (totalSAP > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  totalSAP > 9 ? '9+' : '$totalSAP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onSelected: (value) {
        switch (value) {
          case 'notas':
            _mostrarNotasSAP(task);
            break;
          case 'ordens':
            _mostrarOrdens(task);
            break;
          case 'ats':
            _mostrarATs(task);
            break;
          case 'sis':
            _mostrarSIs(task);
            break;
        }
      },
      itemBuilder: (context) => [
        if ((_notasSAPCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'notas',
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text('Notas SAP'),
                const Spacer(),
                Text(
                  '${_notasSAPCount[task.id]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        if ((_ordensCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'ordens',
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text('Ordens'),
                const Spacer(),
                Text(
                  '${_ordensCount[task.id]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        if ((_atsCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'ats',
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                const Text('ATs'),
                const Spacer(),
                Text(
                  '${_atsCount[task.id]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        if ((_sisCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'sis',
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text('SIs'),
                const Spacer(),
                Text(
                  '${_sisCount[task.id]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _mostrarNotasSAP(Task task) async {
    try {
      final notas = await _notaSAPService.getNotasPorTarefa(task.id);
      if (!mounted) return;

      if (notas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma nota SAP vinculada')),
        );
        return;
      }

      _mostrarDialogNotasSAP(notas, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar notas: $e')));
      }
    }
  }

  Future<void> _mostrarOrdens(Task task) async {
    try {
      final ordens = await _ordemService.getOrdensPorTarefa(task.id);
      if (!mounted) return;

      if (ordens.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma ordem vinculada')),
        );
        return;
      }

      _mostrarDialogOrdens(ordens, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar ordens: $e')));
      }
    }
  }

  Future<void> _mostrarATs(Task task) async {
    try {
      final ats = await _atService.getATsPorTarefa(task.id);
      if (!mounted) return;

      if (ats.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nenhuma AT vinculada')));
        return;
      }

      _mostrarDialogATs(ats, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar ATs: $e')));
      }
    }
  }

  Future<void> _mostrarSIs(Task task) async {
    try {
      final sis = await _siService.getSIsPorTarefa(task.id);
      if (!mounted) return;

      if (sis.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nenhuma SI vinculada')));
        return;
      }

      _mostrarDialogSIs(sis, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar SIs: $e')));
      }
    }
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
      final curtidasUsuario = await _likeService.verificarCurtidasPorTarefas(
        taskIds,
      );
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
              content: Text(
                'Não é possível criar chat: tarefa sem divisão ou segmento',
              ),
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
              content: Text(
                'Não é possível criar chat: divisão não encontrada',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Verificar se o segmento está na lista de segmentos da divisão
        if (!divisao.segmentoIds.contains(task.segmentoId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não é possível criar chat: segmento não encontrado na divisão',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Obter nome do segmento
        final segmentoIndex = divisao.segmentoIds.indexOf(task.segmentoId!);
        final segmentoNome =
            segmentoIndex >= 0 && segmentoIndex < divisao.segmentos.length
            ? divisao.segmentos[segmentoIndex]
            : 'Segmento';

        final comunidade = await _chatService.criarOuObterComunidade(
          task.regionalId ?? '',
          task.regional,
          task.divisaoId!,
          divisao.divisao,
          task.segmentoId!,
          segmentoNome,
        );

        grupoChat = await _chatService.criarOuObterGrupo(
          task.id,
          task.tarefa,
          comunidade.id!,
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(Icons.message, 'Mensagem', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Compartilhando via Mensagem...'),
                    ),
                  );
                }),
                _buildShareOption(Icons.email, 'Email', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Compartilhando via Email...'),
                    ),
                  );
                }),
                _buildShareOption(Icons.link, 'Copiar Link', () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: 'Tarefa: ${task.tarefa}'),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado!')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Não foi possível copiar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
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

  Future<void> _copiarParaAreaTransferencia(
    String texto,
    String mensagemSucesso,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemSucesso),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
            Text(label, style: const TextStyle(fontSize: 12)),
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
        child: GestureDetector(
          onTap: () => _showFullscreenImages(imagens, 0),
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
            key: ValueKey(
              'carousel_${task.id}_${imagens.length}',
            ), // Key única para forçar rebuild quando necessário
            controller: controller,
            itemCount: imagens.length,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex[task.id] = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullscreenImages(imagens, index),
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

  void _showFullscreenImages(List<String> imagens, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        final PageController controller = PageController(
          initialPage: initialIndex,
        );
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: imagens.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: imagens[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white70,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 32,
                right: 24,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogNotasSAP(List<NotaSAP> notas, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notas SAP Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notas.length,
                  itemBuilder: (context, index) {
                    final nota = notas[index];
                    return _buildNotaSAPCard(nota, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotaSAPCard(NotaSAP nota, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Colors.blue, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Nota: ${nota.nota}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  _copiarParaAreaTransferencia(nota.nota, 'Nota copiada!'),
              tooltip: 'Copiar nota',
            ),
          ],
        ),
        subtitle: nota.tipo != null ? Text('Tipo: ${nota.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', nota.tipo),
                _buildInfoRowModern('Status Sistema', nota.statusSistema),
                _buildInfoRowModern('Status Usuário', nota.statusUsuario),
                _buildInfoRowModern('Descrição', nota.descricao),
                _buildInfoRowModern('Local Instalação', nota.localInstalacao),
                _buildInfoRowModern('Ordem', nota.ordem),
                _buildInfoRowModern('GPM', nota.gpm),
                _buildInfoRowModern(
                  'Centro Trabalho',
                  nota.centroTrabalhoResponsavel,
                ),
                if (nota.inicioDesejado != null)
                  _buildInfoRowModern(
                    'Início Desejado',
                    _formatDate(nota.inicioDesejado!),
                  ),
                if (nota.conclusaoDesejada != null)
                  _buildInfoRowModern(
                    'Conclusão Desejada',
                    _formatDate(nota.conclusaoDesejada!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogOrdens(List<Ordem> ordens, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ordens Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordens.length,
                  itemBuilder: (context, index) {
                    final ordem = ordens[index];
                    return _buildOrdemCard(ordem, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdemCard(Ordem ordem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.orange, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Ordem: ${ordem.ordem}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  _copiarParaAreaTransferencia(ordem.ordem, 'Ordem copiada!'),
              tooltip: 'Copiar ordem',
            ),
          ],
        ),
        subtitle: ordem.tipo != null ? Text('Tipo: ${ordem.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', ordem.tipo),
                _buildInfoRowModern('Status Sistema', ordem.statusSistema),
                _buildInfoRowModern('Status Usuário', ordem.statusUsuario),
                _buildInfoRowModern('Texto Breve', ordem.textoBreve),
                _buildInfoRowModern(
                  'Denominação Local',
                  ordem.denominacaoLocalInstalacao,
                ),
                _buildInfoRowModern(
                  'Denominação Objeto',
                  ordem.denominacaoObjeto,
                ),
                _buildInfoRowModern('Local Instalação', ordem.localInstalacao),
                _buildInfoRowModern('Código SI', ordem.codigoSI),
                _buildInfoRowModern('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRowModern(
                    'Início Base',
                    _formatDate(ordem.inicioBase!),
                  ),
                if (ordem.fimBase != null)
                  _buildInfoRowModern('Fim Base', _formatDate(ordem.fimBase!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogATs(List<AT> ats, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[600]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ATs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ats.length,
                  itemBuilder: (context, index) {
                    final at = ats[index];
                    return _buildATCard(at, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildATCard(AT at, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.assignment, color: Colors.purple, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'AT: ${at.autorzTrab}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
              tooltip: 'Copiar AT',
            ),
          ],
        ),
        subtitle: at.statusSistema != null
            ? Text('Status: ${at.statusSistema}')
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Edificação', at.edificacao),
                _buildInfoRowModern('Status Sistema', at.statusSistema),
                _buildInfoRowModern('Status Usuário', at.statusUsuario),
                _buildInfoRowModern('Texto Breve', at.textoBreve),
                _buildInfoRowModern('Local Instalação', at.localInstalacao),
                _buildInfoRowModern('Centro Trabalho', at.cntrTrab),
                _buildInfoRowModern('Cen', at.cen),
                _buildInfoRowModern('SI', at.si),
                if (at.dataInicio != null)
                  _buildInfoRowModern(
                    'Data Início',
                    _formatDate(at.dataInicio!),
                  ),
                if (at.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(at.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogSIs(List<SI> sis, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal[600]!, Colors.teal[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sis.length,
                  itemBuilder: (context, index) {
                    final si = sis[index];
                    return _buildSICard(si, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSICard(SI si, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info, color: Colors.teal, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'SI: ${si.solicitacao}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        subtitle: si.tipo != null ? Text('Tipo: ${si.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', si.tipo),
                _buildInfoRowModern('Status Sistema', si.statusSistema),
                _buildInfoRowModern('Status Usuário', si.statusUsuario),
                _buildInfoRowModern('Texto Breve', si.textoBreve),
                _buildInfoRowModern('Local Instalação', si.localInstalacao),
                _buildInfoRowModern('Criado Por', si.criadoPor),
                _buildInfoRowModern('Centro Trabalho', si.cntrTrab),
                _buildInfoRowModern('Cen', si.cen),
                _buildInfoRowModern('Atrib AT', si.atribAT),
                if (si.dataInicio != null)
                  _buildInfoRowModern(
                    'Data Início',
                    _formatDate(si.dataInicio!),
                  ),
                if (si.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(si.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowModern(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
