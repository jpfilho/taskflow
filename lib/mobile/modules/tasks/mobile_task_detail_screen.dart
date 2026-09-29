import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/task.dart';
import '../../../models/apr.dart';
import '../../../models/anexo.dart';
import '../../../models/grupo_chat.dart';
import '../../../services/task_service.dart';
import '../../../services/apr_service.dart';
import '../../../services/anexo_service.dart';
import '../../../services/chat_service.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_status_colors.dart';
import '../../core/widgets/tf_mobile_states.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import 'adapters/mobile_task_adapter.dart';
import 'models/mobile_task_detail_view_model.dart';
import 'widgets/mobile_task_status_header.dart';
import 'widgets/mobile_task_actions.dart';
import 'widgets/mobile_task_resources_card.dart';
import 'widgets/mobile_task_timeline.dart';
import 'widgets/mobile_task_evidence_section.dart';
import 'widgets/mobile_task_communication_section.dart';
import 'widgets/mobile_task_pending_items.dart';

/// Tela fullscreen de detalhes operacionais da atividade para smartphone.
/// Substitui os diálogos desktop comprimidos e organiza as informações em seções verticais
/// com carregamento progressivo, zona fácil do polegar e suporte offline-first.
class MobileTaskDetailScreen extends StatefulWidget {
  final String taskId;
  final String? initialTaskTitle;
  final Task? initialTask;
  final TFMobileNavigator? navigator;

  const MobileTaskDetailScreen({
    super.key,
    required this.taskId,
    this.initialTaskTitle,
    this.initialTask,
    this.navigator,
  });

  @override
  State<MobileTaskDetailScreen> createState() => _MobileTaskDetailScreenState();
}

class _MobileTaskDetailScreenState extends State<MobileTaskDetailScreen> {
  final TaskService _taskService = TaskService();
  final APRService _aprService = APRService();
  final AnexoService _anexoService = AnexoService();
  final ChatService _chatService = ChatService();
  final MobileTaskAdapter _adapter = MobileTaskAdapter();

  Task? _currentTask;
  APR? _apr;
  List<Anexo> _anexos = [];
  GrupoChat? _chatGroup;

  bool _isLoadingTask = true;
  bool _isProcessingAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      _currentTask = widget.initialTask;
      _isLoadingTask = false;
      _loadSecondaryData();
    } else {
      _loadTask();
    }
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoadingTask = true;
      _errorMessage = null;
    });

    try {
      final task = await _taskService.getTaskById(widget.taskId);
      if (task != null) {
        if (!mounted) return;
        setState(() {
          _currentTask = task;
          _isLoadingTask = false;
        });
        _loadSecondaryData();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Atividade não encontrada no sistema.';
          _isLoadingTask = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao carregar atividade: $e';
        _isLoadingTask = false;
      });
    }
  }

  /// Carregamento progressivo de dados secundários (APR, anexos, chat)
  /// sem bloquear a abertura imediata dos dados essenciais da atividade.
  Future<void> _loadSecondaryData() async {
    final id = widget.taskId;

    // 1. Carregar APR
    try {
      final apr = await _aprService.getAPRByTaskId(id);
      if (mounted) setState(() => _apr = apr);
    } catch (_) {}

    // 2. Carregar Anexos / Fotos
    try {
      final anexos = await _anexoService.getAnexosByTaskId(id);
      if (mounted) setState(() => _anexos = anexos);
    } catch (_) {}

    // 3. Carregar Grupo de Chat
    try {
      final grupo = await _chatService.obterGrupoPorTarefaId(id);
      if (mounted) setState(() => _chatGroup = grupo);
    } catch (_) {}
  }

  // ========== MUTAÇÕES DE STATUS ==========

  Future<void> _handleStart() async {
    if (_currentTask == null || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final res = await _adapter.startTask(_currentTask!);
    _handleTransitionResult(res);
  }

  Future<void> _handlePause() async {
    if (_currentTask == null || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final res = await _adapter.pauseTask(_currentTask!);
    _handleTransitionResult(res);
  }

  Future<void> _handleResume() async {
    if (_currentTask == null || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final res = await _adapter.resumeTask(_currentTask!);
    _handleTransitionResult(res);
  }

  Future<void> _handleComplete() async {
    if (_currentTask == null || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final res = await _adapter.completeTask(_currentTask!);
    _handleTransitionResult(res);
  }

  void _handleTransitionResult(TaskTransitionResult res) {
    if (!mounted) return;
    setState(() {
      _isProcessingAction = false;
      if (res.updatedTask != null) {
        _currentTask = res.updatedTask;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success
            ? (res.isOfflineQueued ? const Color(0xFFD97706) : TFMobileColors.success)
            : TFMobileColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ========== REGISTRO DE FOTOS ==========

  Future<void> _handleAddPhoto(XFile file) async {
    if (_currentTask == null) return;
    try {
      final ioFile = File(file.path);
      final anexo = await _anexoService.uploadAnexo(
        taskId: _currentTask!.id,
        file: ioFile,
      );

      if (mounted) {
        setState(() {
          _anexos.insert(0, anexo);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidência fotográfica registrada com sucesso!'),
            backgroundColor: TFMobileColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [MobileTaskDetailScreen] Erro no upload imediato: $e. Gravando pendência local.');
      // Adicionar à lista local como pendente de envio
      final localAnexo = Anexo(
        taskId: _currentTask!.id,
        nomeArquivo: file.name,
        tipoArquivo: 'imagem',
        caminhoArquivo: file.path,
        tamanhoBytes: 0,
        createdAt: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _anexos.insert(0, localAnexo);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto salva no aparelho. Pendente de envio.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado para a área de transferência!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTask) {
      return Scaffold(
        backgroundColor: TFMobileColors.background(context),
        appBar: AppBar(
          title: Text(widget.initialTaskTitle ?? 'Carregando Atividade...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(_currentTask),
          ),
        ),
        body: const TFLoadingState(message: 'Carregando dados da atividade...'),
      );
    }

    if (_errorMessage != null || _currentTask == null) {
      return Scaffold(
        backgroundColor: TFMobileColors.background(context),
        appBar: AppBar(title: const Text('Detalhes da Atividade')),
        body: TFErrorState(
          title: 'Não foi possível abrir a atividade',
          description: _errorMessage ?? 'Atividade não encontrada.',
          onRetry: _loadTask,
        ),
      );
    }

    final viewModel = _adapter.toDetailViewModel(
      _currentTask!,
      apr: _apr,
      anexos: _anexos,
      chatGroup: _chatGroup,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_currentTask);
        }
      },
      child: Scaffold(
        backgroundColor: TFMobileColors.background(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Cabeçalho Fixo
              MobileTaskStatusHeader(
                task: viewModel,
                onBack: () => Navigator.of(context).pop(_currentTask),
              ),

              // Conteúdo em Scroll Vertical (Progressive Disclosure)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: TFMobileSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: TFMobileSpacing.sm),

                      // 1. Resumo & Janela de Execução
                      _buildSummarySection(viewModel, isDark),

                      // 2. Equipe e Recursos
                      MobileTaskResourcesCard(task: viewModel),

                      // 3. Segurança e APR
                      MobileTaskPendingItems(
                        aprStatus: viewModel.aprStatus,
                        hasPendingSync: viewModel.syncStatus != TFSyncStatus.synced,
                        onOpenApr: () => (widget.navigator ?? TFMobileNavigator(context: context)).openApr(activityId: viewModel.id),
                      ),

                      // 4. Referências SAP (somente se preenchidas)
                      if (viewModel.hasSapReferences) _buildSapSection(viewModel, isDark),

                      // 5. Evidências Fotográficas
                      MobileTaskEvidenceSection(
                        evidences: viewModel.evidences,
                        onAddPhoto: _handleAddPhoto,
                        isReadOnly: viewModel.actions.isReadOnly,
                      ),

                      // 6. Comunicação Contextual
                      MobileTaskCommunicationSection(
                        chatGroupId: viewModel.chatGroupId,
                        unreadCount: viewModel.unreadChatCount,
                        onOpenChat: () {
                          (widget.navigator ?? TFMobileNavigator(context: context)).openChat(
                            conversationId: viewModel.chatGroupId,
                            title: viewModel.title,
                          );
                        },
                      ),

                      // 7. Histórico & Linha do Tempo
                      MobileTaskTimeline(events: viewModel.timelineEvents),
                    ],
                  ),
                ),
              ),

              // Barra de Ação Fixa na Base da Tela
              MobileTaskActions(
                actions: viewModel.actions,
                isProcessing: _isProcessingAction,
                onStart: _handleStart,
                onPause: _handlePause,
                onResume: _handleResume,
                onComplete: _handleComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(MobileTaskDetailViewModel vm, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg, vertical: TFMobileSpacing.xs),
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Resumo da Execução',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),
          if (vm.formattedDate != null || vm.timeWindow != null)
            _buildDetailItem(
              icon: Icons.calendar_month_outlined,
              label: 'Programação',
              value: [
                if (vm.formattedDate != null) vm.formattedDate,
                if (vm.timeWindow != null) vm.timeWindow,
              ].join(' • '),
              isDark: isDark,
            ),
          if (vm.horasPrevistas != null || vm.horasExecutadas != null)
            _buildDetailItem(
              icon: Icons.timelapse_outlined,
              label: 'Horas',
              value:
                  'Previstas: ${vm.horasPrevistas ?? 0}h | Executadas: ${vm.horasExecutadas ?? 0}h',
              isDark: isDark,
            ),
          if (vm.location != null)
            _buildDetailItem(
              icon: Icons.place_outlined,
              label: 'Localidade',
              value: vm.location!,
              isDark: isDark,
            ),
          if (vm.asset != null)
            _buildDetailItem(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Ativo / Segmento',
              value: vm.asset!,
              isDark: isDark,
            ),
          if (vm.observations != null) ...[
            const SizedBox(height: TFMobileSpacing.xs),
            Text(
              'Observações:',
              style: TFMobileTypography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4.0),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TFMobileSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                vm.observations!,
                style: TFMobileTypography.bodyMedium.copyWith(height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSapSection(MobileTaskDetailViewModel vm, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg, vertical: TFMobileSpacing.xs),
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Referências SAP',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),
          if (vm.sapOrder != null)
            _buildSapCopyItem('Ordem SAP', vm.sapOrder!, isDark),
          if (vm.sapNotification != null)
            _buildSapCopyItem('Nota SAP', vm.sapNotification!, isDark),
          if (vm.sapSi != null)
            _buildSapCopyItem('Solicitação (SI)', vm.sapSi!, isDark),
          if (vm.sapAt != null)
            _buildSapCopyItem('Autorização (AT)', vm.sapAt!, isDark),
        ],
      ),
    );
  }

  Widget _buildSapCopyItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md, vertical: TFMobileSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: TFMobileTypography.bodyMedium.copyWith(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: TFMobileTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: () => _copyToClipboard(label, value),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.copy_rounded, size: 18.0, color: Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16.0,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: TFMobileSpacing.xs),
          Text(
            '$label: ',
            style: TFMobileTypography.caption.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TFMobileTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
