import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/task.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../services/auth_service_simples.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import 'anexos_section.dart';
import 'pex_apr_crc_view.dart';
import 'task_form_dialog.dart';
import '../services/task_service.dart';
import '../services/executor_service.dart';
import '../services/chat_service.dart';
import '../models/grupo_chat.dart';
import '../utils/clipboard_helper.dart';
import 'chat_screen.dart';
import 'task/task_sap_notes_section.dart';
import '../features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import '../features/apoios_operacionais/presentation/widgets/gantt_integrado_apoios_widget.dart';
import '../features/apoios_operacionais/presentation/widgets/task_apoio_view_section.dart';

class TaskViewDialog extends StatefulWidget {
  final Task task;
  final Function(Task)? onEdit;
  final Function(Task)? onUpdated;
  final TaskApoioUiController? apoioController;

  const TaskViewDialog({
    super.key,
    required this.task,
    this.onEdit,
    this.onUpdated,
    this.apoioController,
  });

  @override
  State<TaskViewDialog> createState() => _TaskViewDialogState();
}

class _TaskViewDialogState extends State<TaskViewDialog> {
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();
  late final TaskApoioUiController _apoioController =
      widget.apoioController ?? TaskApoioUiController();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final TaskService _taskService = TaskService();
  final ExecutorService _executorService = ExecutorService();
  final ChatService _chatService = ChatService();
  
  List<NotaSAP> _notasSAP = [];
  List<Ordem> _ordens = [];
  List<AT> _ats = [];
  List<SI> _sis = [];
  bool _loadingSAP = true;
  bool _canEdit = false;

  GrupoChat? _grupoChat;
  bool _loadingChat = true;
  bool _creatingChat = false;
  bool _chatVisible = true;
  bool _chatExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSAPData();
    _checkEditPermission();
    _loadChatGrupo();
  }

  Future<void> _loadChatGrupo() async {
    try {
      final grupo = await _chatService.obterGrupoPorTarefaId(widget.task.id);
      if (mounted) {
        setState(() {
          _grupoChat = grupo;
          _loadingChat = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChat = false;
        });
      }
    }
  }

  Future<void> _iniciarOuAbrirChat() async {
    if (_creatingChat) return;
    setState(() => _creatingChat = true);
    try {
      GrupoChat? grupo = await _chatService.obterGrupoPorTarefaId(widget.task.id);
      if (grupo == null) {
        final task = widget.task;
        if (task.divisaoId != null && task.segmentoId != null) {
          final divisaoNome = task.divisao.isNotEmpty ? task.divisao : 'Divisão';
          final segmentoNome = task.segmento.isNotEmpty ? task.segmento : 'Segmento';
          final comunidade = await _chatService.criarOuObterComunidade(
            task.regionalId ?? '',
            task.regional,
            task.divisaoId!,
            divisaoNome,
            task.segmentoId!,
            segmentoNome,
          );
          if (comunidade.id != null) {
            grupo = await _chatService.criarOuObterGrupo(
              task.id,
              task.tarefa,
              comunidade.id!,
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não é possível criar chat: tarefa precisa ter divisão e segmento configurados.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _grupoChat = grupo;
          _creatingChat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creatingChat = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar chat: $e')),
        );
      }
    }
  }

  Future<void> _checkEditPermission() async {
    try {
      final usuario = _authService.currentUser;
      if (usuario == null) {
        setState(() {
          _canEdit = false;
        });
        return;
      }

      if (usuario.isRoot) {
        setState(() {
          _canEdit = true;
        });
        return;
      }

      final email = usuario.email;
      if (email.isEmpty) {
        setState(() {
          _canEdit = false;
        });
        return;
      }

      final permitido = await _executorService.isCoordenadorOuGerentePorLogin(email);
      setState(() {
        _canEdit = permitido;
      });
    } catch (e) {
      print('⚠️ Erro ao verificar permissão de edição: $e');
      if (!mounted) return;
      setState(() {
        _canEdit = false;
      });
    }
  }

  Future<void> _editarTarefa() async {
    if (!_canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para editar tarefas'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Se há um callback onEdit, usar ele (permite que o widget pai controle a abertura)
      if (widget.onEdit != null) {
        Navigator.of(context).pop();
        widget.onEdit!(widget.task);
        return;
      }

      // Buscar a tarefa atualizada primeiro
      final taskAtualizada = await _taskService.getTaskById(widget.task.id);
      
      if (taskAtualizada == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarefa não encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      // Capturar o navegador raiz e o contexto antes de fechar este diálogo
      final nav = Navigator.of(context, rootNavigator: true);
      final parentContext = nav.context;

      // Fechar o diálogo de visualização primeiro
      Navigator.of(context).pop();
      
      // Aguardar um momento para garantir que a rota foi desempilhada
      await Future.delayed(const Duration(milliseconds: 150));
      if (!parentContext.mounted) return;
      
      final result = await showDialog<Task>(
        context: parentContext,
        builder: (context) => TaskFormDialog(
          task: taskAtualizada,
          startDate: taskAtualizada.dataInicio,
          endDate: taskAtualizada.dataFim,
        ),
      );

      if (result != null) {
        final updated = await _taskService.updateTask(taskAtualizada.id, result);
        if (updated != null) {
          if (widget.onUpdated != null) {
            widget.onUpdated!(updated);
          }
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              const SnackBar(
                content: Text('Atividade atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Erro ao abrir edição de tarefa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir edição: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSAPData() async {
    try {
      final results = await Future.wait([
        _notaSAPService.getNotasPorTarefa(widget.task.id),
        _ordemService.getOrdensPorTarefa(widget.task.id),
        _atService.getATsPorTarefa(widget.task.id),
        _siService.getSIsPorTarefa(widget.task.id),
      ]);
      
      if (mounted) {
        setState(() {
          _notasSAP = results[0] as List<NotaSAP>;
          _ordens = results[1] as List<Ordem>;
          _ats = results[2] as List<AT>;
          _sis = results[3] as List<SI>;
          _loadingSAP = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSAP = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final showSideChat = !isMobile && screenSize.width >= 960 && _chatVisible;
    final task = widget.task;
    final hasBoundedHeight = showSideChat || _chatExpanded;

    final detailsScroll = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSummaryStrip(context, task, isMobile),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 680;
              final col1 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClassificationCard(context, task),
                  const SizedBox(height: 16),
                  _buildLocationsCard(context, task),
                  if (task.observacoes != null &&
                      task.observacoes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildObservationsCard(context, task),
                  ],
                ],
              );
              final col2 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamAndResourcesCard(context, task),
                  const SizedBox(height: 16),
                  _buildScheduleAndPeriodsCard(context, task),
                  const SizedBox(height: 16),
                  _buildAuditCard(context, task),
                ],
              );

              if (!useTwoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    col1,
                    const SizedBox(height: 16),
                    col2,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: col1),
                  const SizedBox(width: 16),
                  Expanded(child: col2),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSAPSectionWrapper(context),
          const SizedBox(height: 16),
          _buildSection(
            'Apoios Operacionais',
            [
              TaskApoioViewSection(
                task: task,
                controller: _apoioController,
                usuarioAtualId: AuthServiceSimples().currentUser?.id ?? '',
                usuarioAtualNome: AuthServiceSimples().currentUser?.nome,
                showHeader: false,
                podeEditar: widget.onEdit != null,
                onAbrirAtividade: (linked) {
                  showDialog(
                    context: context,
                    builder: (_) => TaskViewDialog(
                      task: linked,
                      onEdit: widget.onEdit,
                      onUpdated: widget.onUpdated,
                      apoioController: _apoioController,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => GanttIntegradoDialog.abrir(
                    context,
                    controller: _apoioController,
                    atividadePrincipal: task,
                    usuarioAtualId: AuthServiceSimples().currentUser?.id ?? '',
                    usuarioAtualNome: AuthServiceSimples().currentUser?.nome,
                    onAbrirAtividade: (linked) {
                      showDialog(
                        context: context,
                        builder: (_) => TaskViewDialog(
                          task: linked,
                          onEdit: widget.onEdit,
                          onUpdated: widget.onUpdated,
                          apoioController: _apoioController,
                        ),
                      );
                    },
                  ),
                  icon: const Icon(Icons.view_timeline_outlined, size: 16),
                  label: const Text('Visualizar Gantt Integrado'),
                ),
              ),
            ],
            icon: Icons.handshake_outlined,
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Anexos',
            [
              AnexosSection(
                taskId: task.id,
                isEditing: true,
              ),
            ],
            icon: Icons.attach_file,
          ),
          if (_authService.currentUser?.isRoot == true) ...[
            const SizedBox(height: 16),
            _buildSection(
              'Documentos (PEX, APR, CRC)',
              [
                PEXAPRCRCView(task: task),
              ],
              icon: Icons.description_outlined,
            ),
          ],
          if (!showSideChat) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: _buildChatColumn(context, isExpandedMode: false, isCardMode: true),
            ),
          ],
        ],
      ),
    );

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.tfRadius.lg),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Container(
        width: isMobile ? double.infinity : (showSideChat || _chatExpanded ? 1340 : 1040),
        height: hasBoundedHeight ? screenSize.height * 0.90 : null,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.92,
          maxWidth: screenSize.width * 0.96,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(context.tfRadius.lg),
        ),
        child: Column(
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildHeader(context, task, isMobile, showSideChat: showSideChat),
            if (_chatExpanded)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 8 : 16),
                  child: _buildChatColumn(context, isExpandedMode: true),
                ),
              )
            else if (showSideChat)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: detailsScroll),
                    Container(width: 1, color: colors.borderDefault),
                    SizedBox(
                      width: 370,
                      child: _buildChatColumn(context, isExpandedMode: false),
                    ),
                  ],
                ),
              )
            else
              Flexible(child: detailsScroll),
            _buildFooter(context, colors, typography),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Task task,
    bool isMobile, {
    bool showSideChat = false,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final statusLabel = task.statusNome.isNotEmpty &&
            task.statusNome.toUpperCase() != task.status.toUpperCase()
        ? '${task.status} — ${task.statusNome}'
        : task.status;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(context.tfRadius.lg),
          topRight: Radius.circular(context.tfRadius.lg),
        ),
        border: Border(
          bottom: BorderSide(color: colors.borderDefault, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.tfRadius.md),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(Icons.assignment_outlined, color: colors.primary, size: 24),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TFStatusBadge(
                      label: isMobile ? task.status : statusLabel,
                      severity: _statusSeverity(task.status),
                      icon: Icons.flag_outlined,
                      compact: true,
                    ),
                    if (task.tipo.isNotEmpty)
                      TFStatusBadge(
                        label: task.tipo,
                        severity: TFStatusSeverity.info,
                        icon: Icons.category_outlined,
                        compact: true,
                      ),
                    if (task.prioridade != null && task.prioridade!.trim().isNotEmpty)
                      TFStatusBadge(
                        label: 'Prioridade: ${task.prioridade!.trim()}',
                        severity: _prioridadeSeverity(task.prioridade!),
                        icon: Icons.priority_high,
                        compact: true,
                      ),
                    if (task.hasConflict)
                      const TFStatusBadge(
                        label: 'Conflito de Agenda',
                        severity: TFStatusSeverity.danger,
                        icon: Icons.warning_amber_rounded,
                        compact: true,
                      ),
                    if (task.parentId != null && task.parentId!.isNotEmpty)
                      const TFStatusBadge(
                        label: 'Subtarefa',
                        severity: TFStatusSeverity.neutral,
                        icon: Icons.subdirectory_arrow_right,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  task.tarefa,
                  style: typography.sectionTitle.copyWith(
                    color: colors.textPrimary,
                    fontSize: isMobile ? 16 : 19,
                    height: 1.25,
                  ),
                ),
                if (task.ordem != null && task.ordem!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _copiarParaAreaTransferencia(task.ordem!.trim(), 'Ordem copiada!'),
                    borderRadius: BorderRadius.circular(context.tfRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 14, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Ordem: ${task.ordem!.trim()}',
                            style: typography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy, size: 13, color: colors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isMobile && MediaQuery.of(context).size.width >= 960 && !_chatExpanded)
            IconButton(
              icon: Icon(
                _chatVisible ? Icons.chat : Icons.chat_bubble_outline,
                color: _chatVisible ? colors.primary : colors.textSecondary,
              ),
              tooltip: _chatVisible ? 'Ocultar coluna do Chat' : 'Mostrar coluna do Chat',
              onPressed: () {
                setState(() {
                  _chatVisible = !_chatVisible;
                });
              },
            ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildChatColumn(
    BuildContext context, {
    required bool isExpandedMode,
    bool isCardMode = false,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: (isExpandedMode || isCardMode)
            ? BorderRadius.circular(context.tfRadius.lg)
            : null,
        border: (isExpandedMode || isCardMode)
            ? Border.all(color: colors.borderSubtle)
            : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: (isExpandedMode || isCardMode)
                  ? BorderRadius.only(
                      topLeft: Radius.circular(context.tfRadius.lg),
                      topRight: Radius.circular(context.tfRadius.lg),
                    )
                  : null,
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat da Atividade',
                    style: typography.cardTitle.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpandedMode ? Icons.close_fullscreen : Icons.open_in_full,
                    size: 18,
                    color: colors.primary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: isExpandedMode ? 'Recolher Chat' : 'Expandir Chat',
                  onPressed: () {
                    setState(() {
                      _chatExpanded = !isExpandedMode;
                      if (!_chatExpanded) {
                        _chatVisible = true;
                      }
                    });
                  },
                ),
                if (!isExpandedMode && !isCardMode)
                  IconButton(
                    icon: Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Recolher coluna do Chat',
                    onPressed: () {
                      setState(() {
                        _chatVisible = false;
                      });
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loadingChat
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        const SizedBox(height: 10),
                        Text(
                          'Carregando chat...',
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : (_grupoChat != null && _grupoChat!.id != null)
                    ? ClipRRect(
                        borderRadius: (isExpandedMode || isCardMode)
                            ? BorderRadius.only(
                                bottomLeft: Radius.circular(context.tfRadius.lg),
                                bottomRight: Radius.circular(context.tfRadius.lg),
                              )
                            : BorderRadius.zero,
                        child: ChatScreen(
                          grupoId: _grupoChat!.id!,
                          isEmbedded: true,
                          onBack: () {
                            if (mounted && _chatExpanded) {
                              setState(() => _chatExpanded = false);
                            }
                          },
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 36,
                                color: colors.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Nenhum chat iniciado para esta atividade.',
                                textAlign: TextAlign.center,
                                style: typography.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Inicie uma conversa vinculada a esta tarefa para alinhar execução e evidências com a equipe.',
                                textAlign: TextAlign.center,
                                style: typography.caption.copyWith(color: colors.textMuted),
                              ),
                              const SizedBox(height: 14),
                              TFButton(
                                label: 'Iniciar Chat',
                                leadingIcon: Icons.add_comment_outlined,
                                variant: TFButtonVariant.primary,
                                size: TFButtonSize.small,
                                loading: _creatingChat,
                                onPressed: _iniciarOuAbrirChat,
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryStrip(BuildContext context, Task task, bool isMobile) {
    final colors = context.tfColors;
    final duracaoDias = task.dataFim.difference(task.dataInicio).inDays + 1;
    final duracaoLabel = duracaoDias <= 1 ? '1 dia' : '$duracaoDias dias';

    final totalSap = _notasSAP.length + _ordens.length + _ats.length + _sis.length;
    final sapTexto = _loadingSAP
        ? 'Carregando...'
        : totalSap == 0
            ? (task.precisaSi ? 'Sem itens · Requer SI' : 'Nenhum vínculo')
            : '${_notasSAP.length} Nota(s) · ${_ordens.length} Ord. · ${_ats.length} AT · ${_sis.length} SI';

    final cards = [
      _buildKpiTile(
        context,
        icon: Icons.date_range_outlined,
        accent: colors.primary,
        title: 'Período ($duracaoLabel)',
        value: '${_formatDate(task.dataInicio)} → ${_formatDate(task.dataFim)}',
      ),
      _buildKpiTile(
        context,
        icon: Icons.groups_outlined,
        accent: colors.success,
        title: 'Recursos Alocados',
        value: '${task.executores.length} Exec. · ${task.equipes.length} Eq. · ${task.locais.length} Loc.',
      ),
      _buildKpiTile(
        context,
        icon: Icons.link_outlined,
        accent: colors.warning,
        title: 'Integração SAP / SI',
        value: sapTexto,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: c,
                    ))
                .toList(),
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKpiTile(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String value,
    double? progress,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.tfRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: typography.caption.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassificationCard(BuildContext context, Task task) {
    final statusDisplay = task.statusNome.isNotEmpty &&
            task.statusNome.toUpperCase() != task.status.toUpperCase()
        ? '${task.status} (${task.statusNome})'
        : task.status;

    return _buildSection(
      'Classificação e Escopo',
      [
        _buildDetailRow('Status', statusDisplay),
        _buildDetailRow('Tipo', task.tipo.isNotEmpty ? task.tipo : '-'),
        _buildDetailRow(
          'Ordem',
          task.ordem != null && task.ordem!.trim().isNotEmpty ? task.ordem!.trim() : '-',
          copyValue: task.ordem != null && task.ordem!.trim().isNotEmpty ? task.ordem!.trim() : null,
          copyMessage: 'Ordem copiada!',
        ),
        _buildDetailRow(
          'SI',
          task.si.trim().isNotEmpty ? task.si.trim() : '-',
          copyValue: task.si.trim().isNotEmpty ? task.si.trim() : null,
          copyMessage: 'SI copiada!',
        ),
        _buildDetailRow('Requer SI', task.precisaSi ? 'Sim' : 'Não'),
        _buildDetailRow('Prioridade', task.prioridade?.trim().isNotEmpty == true ? task.prioridade!.trim() : '-'),
        _buildDetailRow('Regional', task.regional.isNotEmpty ? task.regional : '-'),
        _buildDetailRow('Divisão', task.divisao.isNotEmpty ? task.divisao : '-'),
        _buildDetailRow('Segmento', task.segmento.isNotEmpty ? task.segmento : '-'),
        if (task.parentId != null && task.parentId!.isNotEmpty)
          _buildDetailRow(
            'Tarefa Pai (ID)',
            task.parentId!,
            copyValue: task.parentId!,
            copyMessage: 'ID da tarefa pai copiado!',
          ),
      ],
      icon: Icons.info_outline,
    );
  }

  Widget _buildLocationsCard(BuildContext context, Task task) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return _buildSection(
      'Localização (${task.locais.length})',
      [
        if (task.locais.isEmpty)
          Text(
            'Nenhum local associado.',
            style: typography.bodyMedium.copyWith(color: colors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: task.locais
                .map((loc) => _buildChipItem(context, loc, Icons.place_outlined, colors.primary))
                .toList(),
          ),
      ],
      icon: Icons.location_on_outlined,
    );
  }

  Widget _buildTeamAndResourcesCard(BuildContext context, Task task) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final papelPorExecutor = <String, String>{};
    if (task.equipeExecutores != null) {
      for (final info in task.equipeExecutores!) {
        if (info.executorNome.isNotEmpty && info.papel.isNotEmpty) {
          papelPorExecutor[info.executorNome.toLowerCase().trim()] = info.papel;
        }
      }
    }

    return _buildSection(
      'Equipe e Recursos',
      [
        _buildDetailRow(
          'Coordenador',
          task.coordenador.trim().isNotEmpty ? task.coordenador.trim() : '-',
        ),
        const SizedBox(height: 6),
        Text(
          'Equipes (${task.equipes.length})',
          style: typography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (task.equipes.isEmpty)
          Text(
            'Nenhuma equipe informada.',
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: task.equipes
                .map((eq) => _buildChipItem(context, eq, Icons.diversity_3_outlined, colors.info))
                .toList(),
          ),
        const SizedBox(height: 12),
        Text(
          'Executores (${task.executores.length})',
          style: typography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (task.executores.isEmpty)
          Text(
            task.executor.trim().isNotEmpty ? task.executor.trim() : 'Nenhum executor alocado.',
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: task.executores.map((ex) {
              final papel = papelPorExecutor[ex.toLowerCase().trim()];
              final label = papel != null ? '$ex ($papel)' : ex;
              return _buildChipItem(context, label, Icons.person_outline, colors.success);
            }).toList(),
          ),
        const SizedBox(height: 10),
        _buildDetailRow(
          'Frota',
          task.frota.trim().isNotEmpty ? task.frota.trim() : '-',
        ),
      ],
      icon: Icons.people_outline,
    );
  }

  Widget _buildScheduleAndPeriodsCard(BuildContext context, Task task) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final duracao = task.dataFim.difference(task.dataInicio).inDays + 1;

    return _buildSection(
      'Cronograma e Períodos',
      [
        _buildDetailRow('Data Início', _formatDate(task.dataInicio)),
        _buildDetailRow('Data Fim', _formatDate(task.dataFim)),
        _buildDetailRow('Duração', duracao <= 1 ? '1 dia' : '$duracao dias'),
        if (task.ganttSegments.isNotEmpty) ...[
          Divider(color: colors.borderSubtle, height: 20),
          Text(
            'Segmentos do Cronograma (${task.ganttSegments.length})',
            style: typography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: task.ganttSegments
                .map((seg) => _buildSegmentTile(context, seg))
                .toList(),
          ),
          const SizedBox(height: 12),
          _buildSegmentsCalendar(context, task),
        ],
        if (task.executorPeriods.isNotEmpty) ...[
          Divider(color: colors.borderSubtle, height: 20),
          Text(
            'Períodos por Executor (${task.executorPeriods.length})',
            style: typography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...task.executorPeriods.map((ep) => _buildResourcePeriodItem(
                context,
                title: ep.executorNome,
                icon: Icons.person_outline,
                segments: ep.periods,
              )),
        ],
        if (task.frotaPeriods.isNotEmpty) ...[
          Divider(color: colors.borderSubtle, height: 20),
          Text(
            'Períodos por Frota (${task.frotaPeriods.length})',
            style: typography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...task.frotaPeriods.map((fp) => _buildResourcePeriodItem(
                context,
                title: fp.frotaNome,
                icon: Icons.directions_car_outlined,
                segments: fp.periods,
              )),
        ],
      ],
      icon: Icons.calendar_today_outlined,
    );
  }

  Color _periodColor(BuildContext context, String tipoPeriodo) {
    final colors = context.tfColors;
    switch (tipoPeriodo.toUpperCase().trim()) {
      case 'EXECUCAO':
        return colors.success;
      case 'PLANEJAMENTO':
        return colors.warning;
      case 'DESLOCAMENTO':
        return colors.primary;
      default:
        return colors.textSecondary;
    }
  }

  String _periodLabel(String tipoPeriodo) {
    switch (tipoPeriodo.toUpperCase().trim()) {
      case 'EXECUCAO':
        return 'Execução';
      case 'PLANEJAMENTO':
        return 'Planejamento';
      case 'DESLOCAMENTO':
        return 'Deslocamento';
      default:
        return tipoPeriodo.isNotEmpty ? tipoPeriodo : 'Período';
    }
  }

  Widget _buildSegmentTile(BuildContext context, GanttSegment seg) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final badgeColor = _periodColor(context, seg.tipoPeriodo);
    final periodoLabel = _periodLabel(seg.tipoPeriodo);
    final isSameDay = seg.dataInicio.year == seg.dataFim.year &&
        seg.dataInicio.month == seg.dataFim.month &&
        seg.dataInicio.day == seg.dataFim.day;
    final dateText = isSameDay
        ? _formatDateShort(seg.dataInicio)
        : '${_formatDateShort(seg.dataInicio)} → ${_formatDateShort(seg.dataFim)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.tfRadius.sm),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            periodoLabel,
            style: typography.caption.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            dateText,
            style: typography.caption.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsCalendar(BuildContext context, Task task) {
    final colors = context.tfColors;

    // Coletar todos os meses distintos cobertos pelos segmentos (máx. 3 meses para manter compacto)
    final monthsSet = <DateTime>{};
    for (final seg in task.ganttSegments) {
      var current = DateTime(seg.dataInicio.year, seg.dataInicio.month);
      final end = DateTime(seg.dataFim.year, seg.dataFim.month);
      while (!current.isAfter(end) && monthsSet.length < 3) {
        monthsSet.add(current);
        current = DateTime(current.year, current.month + 1);
      }
    }
    if (monthsSet.isEmpty) return const SizedBox.shrink();

    final months = monthsSet.toList()..sort();
    final tiposPresentes = task.ganttSegments
        .map((s) => s.tipoPeriodo.toUpperCase().trim())
        .toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(context.tfRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (tiposPresentes.contains('EXECUCAO'))
                _buildCalendarLegendItem(context, 'Execução', colors.success),
              if (tiposPresentes.contains('PLANEJAMENTO'))
                _buildCalendarLegendItem(context, 'Planejamento', colors.warning),
              if (tiposPresentes.contains('DESLOCAMENTO'))
                _buildCalendarLegendItem(context, 'Deslocamento', colors.primary),
            ],
          ),
          const SizedBox(height: 10),
          ...months.map((m) => Padding(
                padding: EdgeInsets.only(bottom: m == months.last ? 0 : 12),
                child: _buildMonthCalendarGrid(context, m, task.ganttSegments),
              )),
        ],
      ),
    );
  }

  Widget _buildCalendarLegendItem(BuildContext context, String label, Color color) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: typography.caption.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCalendarGrid(
    BuildContext context,
    DateTime monthStart,
    List<GanttSegment> segments,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    const monthNames = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    const weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    // weekday: 1=Seg .. 7=Dom -> queremos 0=Dom .. 6=Sab
    final firstWeekdayOffset = monthStart.weekday % 7;
    final totalCells = firstWeekdayOffset + daysInMonth;
    final numRows = (totalCells / 7).ceil();

    String? tipoNoDia(DateTime day) {
      // Prioridade visual: DESLOCAMENTO (ida/volta) -> EXECUCAO -> PLANEJAMENTO
      for (final seg in segments) {
        final per = seg.tipoPeriodo.toUpperCase().trim();
        final s = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
        final e = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
        if (per == 'DESLOCAMENTO') {
          if (day.isAtSameMomentAs(s) || day.isAtSameMomentAs(e)) {
            return 'DESLOCAMENTO';
          }
        }
      }
      for (final seg in segments) {
        final per = seg.tipoPeriodo.toUpperCase().trim();
        if (per == 'DESLOCAMENTO') continue;
        final s = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
        final e = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
        if (!day.isBefore(s) && !day.isAfter(e)) {
          return per.isNotEmpty ? per : 'EXECUCAO';
        }
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${monthNames[monthStart.month - 1]} / ${monthStart.year}',
          style: typography.caption.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: weekDays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: typography.caption.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        for (int row = 0; row < numRows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cellIndex = row * 7 + col;
                        final dayNum = cellIndex - firstWeekdayOffset + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox(height: 24);
                        }
                        final dayDate = DateTime(monthStart.year, monthStart.month, dayNum);
                        final tipo = tipoNoDia(dayDate);
                        final bg = tipo != null ? _periodColor(context, tipo) : Colors.transparent;
                        final fg = tipo != null ? Colors.white : colors.textSecondary;

                        final cell = Container(
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: tipo == null
                                ? Border.all(color: colors.borderSubtle.withValues(alpha: 0.5))
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: tipo != null ? FontWeight.w700 : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        );

                        if (tipo != null) {
                          return Tooltip(
                            message: '${_formatDateShort(dayDate)} — ${_periodLabel(tipo)}',
                            child: cell,
                          );
                        }
                        return cell;
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResourcePeriodItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<GanttSegment> segments,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(context.tfRadius.sm),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: typography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: segments.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.borderDefault),
                  ),
                  child: Text(
                    '${s.tipoPeriodo}: ${_formatDateShort(s.dataInicio)}–${_formatDateShort(s.dataFim)}',
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservationsCard(BuildContext context, Task task) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return _buildSection(
      'Observações',
      [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.infoBackground,
            borderRadius: BorderRadius.circular(context.tfRadius.md),
            border: Border.all(color: colors.info.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            task.observacoes!.trim(),
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
      icon: Icons.notes_outlined,
    );
  }

  Widget _buildAuditCard(BuildContext context, Task task) {
    return _buildSection(
      'Auditoria e Registro',
      [
        _buildDetailRow(
          'Criada em',
          task.dataCriacao != null ? _formatDateTime(task.dataCriacao!) : '-',
        ),
        _buildDetailRow(
          'Atualizada em',
          task.dataAtualizacao != null ? _formatDateTime(task.dataAtualizacao!) : '-',
        ),
      ],
      icon: Icons.history_outlined,
    );
  }

  Widget _buildSAPSectionWrapper(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    if (_loadingSAP) {
      return _buildSection(
        'Vínculos SAP',
        [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Carregando Notas SAP, Ordens, ATs e SIs...',
                  style: typography.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
        icon: Icons.hub_outlined,
      );
    }

    if (_notasSAP.isEmpty && _ordens.isEmpty && _ats.isEmpty && _sis.isEmpty) {
      return _buildSection(
        'Vínculos SAP',
        [
          Text(
            'Nenhuma Nota SAP, Ordem, AT ou SI vinculada a esta atividade.',
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
        ],
        icon: Icons.hub_outlined,
      );
    }

    return _buildSAPSection();
  }

  Widget _buildSAPSection() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_notasSAP.isNotEmpty) ...[
          TaskSapNotesSection(
            notasSAP: _notasSAP,
            task: widget.task,
            readOnly: !_canEdit,
          ),
          const SizedBox(height: 16),
        ],
        if (_ordens.isNotEmpty || _ats.isNotEmpty || _sis.isNotEmpty) ...[
          _buildSection(
            'Outros Itens SAP Vinculados',
            [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_ordens.isNotEmpty)
                    _buildSAPItem(
                      icon: Icons.receipt_long,
                      label: 'Ordens',
                      count: _ordens.length,
                      color: colors.warning,
                      onTap: () => _mostrarDialogOrdens(_ordens, widget.task),
                    ),
                  if (_ats.isNotEmpty)
                    _buildSAPItem(
                      icon: Icons.assignment,
                      label: 'ATs',
                      count: _ats.length,
                      color: colors.primary,
                      onTap: () => _mostrarDialogATs(_ats, widget.task),
                    ),
                  if (_sis.isNotEmpty)
                    _buildSAPItem(
                      icon: Icons.info_outline,
                      label: 'SIs',
                      count: _sis.length,
                      color: colors.info,
                      onTap: () => _mostrarDialogSIs(_sis, widget.task),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Clique em qualquer item acima para abrir os detalhes completos.',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
            icon: Icons.hub_outlined,
          ),
        ],
      ],
    );
  }

  Widget _buildSAPItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.tfRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.tfRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    TFSemanticColors colors,
    TFTypography typography,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.tfRadius.lg),
          bottomRight: Radius.circular(context.tfRadius.lg),
        ),
        border: Border(
          top: BorderSide(color: colors.borderDefault, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_canEdit) ...[
            TFButton(
              label: 'Editar Tarefa',
              leadingIcon: Icons.edit_outlined,
              variant: TFButtonVariant.primary,
              onPressed: _editarTarefa,
            ),
            const SizedBox(width: 10),
          ],
          TFButton(
            label: 'Fechar',
            leadingIcon: Icons.close,
            variant: TFButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.tfRadius.lg),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: colors.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: typography.cardTitle.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: colors.borderSubtle, height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    String? copyValue,
    String? copyMessage,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: typography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          if (copyValue != null)
            IconButton(
              icon: Icon(Icons.copy, size: 15, color: colors.primary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Copiar $label',
              onPressed: () => _copiarParaAreaTransferencia(
                copyValue,
                copyMessage ?? '$label copiado!',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChipItem(
    BuildContext context,
    String label,
    IconData icon,
    Color accentColor,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(context.tfRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: typography.bodySmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TFStatusSeverity _statusSeverity(String status) {
    switch (status.trim().toUpperCase()) {
      case 'CONC':
        return TFStatusSeverity.success;
      case 'ANDA':
        return TFStatusSeverity.info;
      case 'PROG':
        return TFStatusSeverity.warning;
      case 'CANC':
      case 'RPAR':
      case 'RPGR':
        return TFStatusSeverity.danger;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  TFStatusSeverity _prioridadeSeverity(String prioridade) {
    final p = prioridade.trim().toUpperCase();
    if (p.contains('ALTA') || p.contains('CRIT') || p.contains('URG')) {
      return TFStatusSeverity.danger;
    }
    if (p.contains('MED') || p.contains('MÉD')) {
      return TFStatusSeverity.warning;
    }
    return TFStatusSeverity.info;
  }

  String _formatDateShort(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime d) {
    final local = d.toLocal();
    return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _copiarParaAreaTransferencia(String texto, String mensagemSucesso) async {
    await ClipboardHelper.copyAndNotify(
      context,
      texto,
      successMessage: mensagemSucesso,
      errorMessage: 'Não foi possível copiar o texto.',
      duration: const Duration(seconds: 1),
    );
  }

  Color _getStatusUsuarioColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.grey;
    final status = statusUsuario.toUpperCase();
    if (status.contains('CONC')) return Colors.green;
    if (status.contains('CADU') || status.contains('CAIM')) return Colors.grey;
    if (status.contains('REGI')) return Colors.orange;
    if (status.contains('EMAM')) return Colors.yellow[700] ?? Colors.amber;
    if (status.contains('ANLS')) return Colors.blue;
    return Colors.grey;
  }

  Color _getStatusUsuarioTextColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.white;
    final status = statusUsuario.toUpperCase();
    if (status.contains('EMAM')) return Colors.black;
    return Colors.white;
  }

  Color _getStatusSistemaColor(String? statusSistema) {
    if (statusSistema == null || statusSistema.isEmpty) return Colors.grey;
    final status = statusSistema.toUpperCase();
    if (status.contains('MSPR')) return Colors.orange;
    if (status.contains('MSPN')) return Colors.blue;
    if (status.contains('MECE') || status.contains('CONC')) return Colors.green;
    return const Color(0xFF1E3A5F);
  }

  void _mostrarDialogOrdens(List<Ordem> ordens, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
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
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
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
    final statusSis = ordem.statusSistema?.trim();
    final statusUsu = ordem.statusUsuario?.trim();
    final sala = ordem.sala?.trim();
    final descricao = (ordem.textoBreve?.trim().isNotEmpty == true)
        ? ordem.textoBreve!.trim()
        : ordem.denominacaoObjeto?.trim();
    final local = (ordem.localInstalacao?.trim().isNotEmpty == true)
        ? ordem.localInstalacao!.trim()
        : (ordem.denominacaoLocalInstalacao?.trim().isNotEmpty == true
            ? ordem.denominacaoLocalInstalacao!.trim()
            : ordem.local?.trim());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Colors.orange, size: 20),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Ordem: ${ordem.ordem}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    if (ordem.tipo != null && ordem.tipo!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ordem.tipo!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    if (statusSis != null && statusSis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusSistemaColor(statusSis).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusSistemaColor(statusSis).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          statusSis,
                          style: TextStyle(
                            color: _getStatusSistemaColor(statusSis),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (statusUsu != null && statusUsu.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusUsuarioColor(statusUsu),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusUsu,
                          style: TextStyle(
                            color: _getStatusUsuarioTextColor(statusUsu),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (sala != null && sala.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 13, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(
                              'Sala: $sala',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (descricao != null && descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[850],
                        ),
                      ),
                    if (local != null && local.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              local,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copiarParaAreaTransferencia(ordem.ordem, 'Ordem copiada!'),
                tooltip: 'Copiar ordem',
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildInfoRowModern('Tipo', ordem.tipo),
                _buildInfoRowModern('Status Sistema', ordem.statusSistema),
                _buildInfoRowModern('Status Usuário', ordem.statusUsuario),
                _buildInfoRowModern('Texto Breve', ordem.textoBreve),
                _buildInfoRowModern('Denominação Local', ordem.denominacaoLocalInstalacao),
                _buildInfoRowModern('Denominação Objeto', ordem.denominacaoObjeto),
                _buildInfoRowModern('Local Instalação', ordem.localInstalacao),
                _buildInfoRowModern('Sala', ordem.sala),
                _buildInfoRowModern('Local', ordem.local),
                if (ordem.tolerancia != null)
                  _buildInfoRowModern('Tolerância', _formatDate(ordem.tolerancia!)),
                _buildInfoRowModern('Código SI', ordem.codigoSI),
                _buildInfoRowModern('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRowModern('Início Base', _formatDate(ordem.inicioBase!)),
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
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
                      child: const Icon(Icons.assignment, color: Colors.white, size: 24),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
              tooltip: 'Copiar AT',
            ),
          ],
        ),
        subtitle: at.statusSistema != null ? Text('Status: ${at.statusSistema}') : null,
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
                  _buildInfoRowModern('Data Início', _formatDate(at.dataInicio!)),
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
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
                      child: const Icon(Icons.info, color: Colors.white, size: 24),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        subtitle: (si.tipo != null || si.resumoPeriodo != null)
            ? Text(
                [
                  if (si.tipo != null) 'Tipo: ${si.tipo}',
                  if (si.resumoPeriodo != null) si.resumoPeriodo!,
                ].join(' · '),
              )
            : null,
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
                  _buildInfoRowModern('Data Início', _formatDate(si.dataInicio!)),
                if (si.horaInicioFormatada != null)
                  _buildInfoRowModern('Hora Início', si.horaInicioFormatada),
                if (si.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(si.dataFim!)),
                if (si.horaFimFormatada != null)
                  _buildInfoRowModern('Hora Fim', si.horaFimFormatada),
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
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
              maxLines: label == 'Detalhes' ? null : 3,
              overflow: label == 'Detalhes' ? TextOverflow.visible : TextOverflow.ellipsis,
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

