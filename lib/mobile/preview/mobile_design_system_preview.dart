import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/tf_mobile_spacing.dart';
import '../core/theme/tf_mobile_typography.dart';
import '../core/theme/tf_mobile_colors.dart';
import '../core/theme/tf_mobile_touch_targets.dart';
import '../core/theme/tf_mobile_status_colors.dart';
import '../core/widgets/tf_mobile_status_chip.dart';
import '../core/widgets/tf_mobile_card.dart';
import '../core/widgets/tf_mobile_buttons.dart';
import '../core/widgets/tf_mobile_text_field.dart';
import '../core/widgets/tf_mobile_bottom_sheet.dart';
import '../core/widgets/tf_mobile_filter_sheet.dart';
import '../core/widgets/tf_mobile_offline_banner.dart';
import '../core/widgets/tf_mobile_states.dart';
import '../core/widgets/tf_mobile_app_bar.dart';
import '../modules/chat/widgets/tf_message_bubble.dart';
import '../modules/chat/widgets/tf_chat_input.dart';
import '../modules/chat/widgets/tf_community_tile.dart';
import '../modules/feed/widgets/tf_feed_models.dart';
import '../modules/feed/widgets/tf_feed_card.dart';
import '../modules/feed/widgets/tf_feed_composer.dart';

/// Tela SOMENTE DE DESENVOLVIMENTO para validação interativa do TaskFlow Mobile Redesign (Fase 1).
class MobileDesignSystemPreview extends StatefulWidget {
  const MobileDesignSystemPreview({super.key});

  @override
  State<MobileDesignSystemPreview> createState() => _MobileDesignSystemPreviewState();
}

class _MobileDesignSystemPreviewState extends State<MobileDesignSystemPreview>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDarkMode = false;
  TFSyncStatus _syncStatus = TFSyncStatus.synced;
  int _offlinePendingCount = 0;

  // Lista mock de feed para demonstração interativa
  late List<TFFeedItem> _feedItems;

  // Lista mock de mensagens de chat
  final List<Map<String, dynamic>> _chatMessages = [
    {
      'text': 'Bom dia equipe! Já estamos a caminho da SE Miracema para o desligamento.',
      'time': '07:45',
      'isMe': false,
      'sender': 'Carlos Encarregado',
      'role': 'Líder de Turma',
      'status': TFMessageDeliveryStatus.delivered,
    },
    {
      'text': 'Confirmado. A APR foi assinada digitalmente por todos no veículo.',
      'time': '07:48',
      'isMe': true,
      'status': TFMessageDeliveryStatus.delivered,
      'activity': 'OS 40291 - Manutenção de Disjuntor',
    },
    {
      'text': 'Registrei a foto do isolador trincado na torre 88. Salva localmente até restabelecer 4G.',
      'time': '08:12',
      'isMe': true,
      'status': TFMessageDeliveryStatus.pendingOffline,
      'image': 'dummy_photo',
    },
    {
      'text': 'Atenção com a velocidade do vento na subida da torre. Qualquer anormalidade paralisem o serviço.',
      'time': '08:14',
      'isMe': false,
      'sender': 'Eng. Marcos',
      'role': 'Segurança do Trabalho',
      'status': TFMessageDeliveryStatus.delivered,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _feedItems = [
      // Mock 1: Maria Silva (Prompt Item 37)
      const TFFeedItem(
        id: '1',
        sourceType: TFFeedSourceType.userPost,
        authorName: 'Maria Silva',
        authorRole: 'Técnica de Manutenção',
        communityOrTeam: 'Equipe de Subestação',
        timestamp: 'há 12 min',
        content: 'Concluída inspeção no equipamento 14D3/BES. Sem anormalidades identificadas.',
        imageUrl: 'inspection_pic',
        contextType: TFFeedContextType.activity,
        linkedEntityTitle: 'Inspeção Disjuntor 14D3/BES',
        likesCount: 8,
        commentsCount: 3,
        isLikedByMe: true,
      ),

      // Mock Evento Automático: Atividade concluída (Ajustes #1 e #3)
      const TFFeedItem(
        id: '2',
        sourceType: TFFeedSourceType.activityEvent,
        authorName: 'Equipe Linhas Norte',
        timestamp: 'há 24 min',
        content: 'Atividade concluída',
        linkedEntityTitle: 'Substituição de Cadeia de Isoladores - Torre 112',
      ),

      // Mock 2: Regional Fortaleza (Prompt Item 37)
      const TFFeedItem(
        id: '3',
        sourceType: TFFeedSourceType.teamUpdate,
        authorName: 'Regional Fortaleza',
        communityOrTeam: 'Comunidade Regional Ceará',
        timestamp: 'há 35 min',
        content: 'Atualização da programação operacional desta semana. Prioridade para intervenções em alimentadores da Zona Metropolitana.',
        likesCount: 15,
        commentsCount: 4,
      ),

      // Mock 3: João Pereira (Prompt Item 37)
      const TFFeedItem(
        id: '4',
        sourceType: TFFeedSourceType.userPost,
        authorName: 'João Pereira',
        authorRole: 'Operador de Campo',
        communityOrTeam: 'Linha de Transmissão',
        timestamp: 'há 1 h',
        content: 'Vegetação próxima à faixa de servidão identificada no vão 104–105 da LT 230kV. Solicitada programação de supressão.',
        imageUrl: 'vegetation_pic',
        likesCount: 5,
        commentsCount: 1,
      ),

      // Mock Publicação Pendente Offline (Ajuste #11)
      const TFFeedItem(
        id: '5',
        sourceType: TFFeedSourceType.userPost,
        authorName: 'Eu (Você)',
        authorRole: 'Eletricista de Manutenção',
        communityOrTeam: 'Turma de Linha Viva',
        timestamp: 'Pendente de envio',
        content: 'Registro de evidência fotográfica do aterramento temporário antes de iniciar a limpeza técnica.',
        imageUrl: 'grounding_pic',
        isOfflinePending: true,
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Ambiente exclusivo de desenvolvimento.'),
        ),
      );
    }

    final themeData = _isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: TFMobileColors.background(context),
        appBar: TFMobileAppBar(
          title: 'TaskFlow Mobile Preview',
          subtitle: 'Fase 1 — Fundação & Comunicação',
          syncStatus: _syncStatus,
          actions: [
            // Alternador de Modo Escuro / Claro
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: 'Alternar Tema',
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
            ),
            // Alternador de Estado de Conectividade para testes
            PopupMenuButton<TFSyncStatus>(
              icon: const Icon(Icons.network_check_rounded),
              tooltip: 'Simular Estado de Conectividade',
              onSelected: (status) {
                setState(() {
                  _syncStatus = status;
                  if (status == TFSyncStatus.offline || status == TFSyncStatus.pending) {
                    _offlinePendingCount = 3;
                  } else {
                    _offlinePendingCount = 0;
                  }
                });
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: TFSyncStatus.synced,
                  child: Text('Online (Sincronizado)'),
                ),
                const PopupMenuItem(
                  value: TFSyncStatus.offline,
                  child: Text('Offline (3 pendentes)'),
                ),
                const PopupMenuItem(
                  value: TFSyncStatus.syncing,
                  child: Text('Sincronizando...'),
                ),
                const PopupMenuItem(
                  value: TFSyncStatus.error,
                  child: Text('Erro de Sincronização'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Banner Offline Contextual
            TFOfflineBanner(
              status: _syncStatus,
              pendingCount: _offlinePendingCount,
              onSyncNow: () {
                setState(() {
                  _syncStatus = TFSyncStatus.syncing;
                });
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _syncStatus = TFSyncStatus.synced;
                      _offlinePendingCount = 0;
                    });
                  }
                });
              },
            ),

            // TabBar Mobile ergonômica (scrollable para não quebrar)
            Container(
              color: TFMobileColors.surface(context),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: TFMobileColors.primaryBlue,
                unselectedLabelColor: TFMobileColors.textSecondary(context),
                indicatorColor: TFMobileColors.primaryBlue,
                indicatorWeight: 3.0,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Tokens & Fundações'),
                  Tab(text: 'Componentes Base'),
                  Tab(text: 'Feed Corporativo'),
                  Tab(text: 'Chat & Mensagens'),
                  Tab(text: 'Home "Hoje"'),
                ],
              ),
            ),

            // Conteúdo das Abas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTokensTab(),
                  _buildComponentsTab(),
                  _buildFeedTab(),
                  _buildChatTab(),
                  _buildHomeTodayTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA 1: TOKENS E FUNDAÇÕES
  // ==========================================
  Widget _buildTokensTab() {
    return ListView(
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      children: [
        _buildSectionHeader('1. Escala Tipográfica (Mínimo 11px)'),
        const Text('Display (24sp / Bold 700)', style: TFMobileTypography.display),
        const SizedBox(height: 8.0),
        const Text('Title Large (18sp / SemiBold 600)', style: TFMobileTypography.titleLarge),
        const SizedBox(height: 8.0),
        const Text('Title Medium (16sp / SemiBold 600)', style: TFMobileTypography.titleMedium),
        const SizedBox(height: 8.0),
        const Text('Body Large (16sp / Regular 400)', style: TFMobileTypography.bodyLarge),
        const SizedBox(height: 8.0),
        const Text('Body Medium (14sp / Regular 400)', style: TFMobileTypography.bodyMedium),
        const SizedBox(height: 8.0),
        const Text('Label (12sp / Medium 600)', style: TFMobileTypography.label),
        const SizedBox(height: 8.0),
        const Text('Caption (11sp / Mínimo Absoluto)', style: TFMobileTypography.caption),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('2. Status Chips Operacionais (Alto Contraste)'),
        Wrap(
          spacing: TFMobileSpacing.sm,
          runSpacing: TFMobileSpacing.sm,
          children: TFOperationalStatus.values.map((s) {
            return TFMobileStatusChip.operational(status: s);
          }).toList(),
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('3. Estados de Conectividade / Sync'),
        Wrap(
          spacing: TFMobileSpacing.sm,
          runSpacing: TFMobileSpacing.sm,
          children: TFSyncStatus.values.map((s) {
            return TFMobileStatusChip.sync(status: s);
          }).toList(),
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('4. Touch Targets (Área Mínima ≥ 48 × 48 px)'),
        Container(
          padding: const EdgeInsets.all(TFMobileSpacing.md),
          decoration: BoxDecoration(
            color: TFMobileColors.surface(context),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.green.shade600, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gabarito Visual de Toque Seguro:', style: TFMobileTypography.titleMedium),
              const SizedBox(height: TFMobileSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTouchTargetBox('Mínimo: 48px', TFMobileTouchTargets.min),
                  _buildTouchTargetBox('Padrão: 52px', TFMobileTouchTargets.standard),
                  _buildTouchTargetBox('Campo: 56px', TFMobileTouchTargets.large),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTouchTargetBox(String label, double size) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: TFMobileColors.primaryBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: TFMobileColors.primaryBlue, width: 2.0),
          ),
          child: Center(
            child: Text('${size.toInt()}', style: TFMobileTypography.label),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(label, style: TFMobileTypography.caption),
      ],
    );
  }

  // ==========================================
  // ABA 2: COMPONENTES BASE
  // ==========================================
  Widget _buildComponentsTab() {
    return ListView(
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      children: [
        _buildSectionHeader('1. Botões Operacionais (48 a 56px de altura)'),
        TFPrimaryButton(
          label: 'Iniciar Atividade (52px)',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
        const SizedBox(height: TFMobileSpacing.md),
        TFSecondaryButton(
          label: 'Adicionar Evidência Fotográfica',
          icon: Icons.photo_camera_rounded,
          onPressed: () {},
        ),
        const SizedBox(height: TFMobileSpacing.md),
        TFDestructiveButton(
          label: 'Registrar Impedimento Técnico',
          icon: Icons.block_rounded,
          onPressed: () {},
        ),
        const SizedBox(height: TFMobileSpacing.md),
        Row(
          children: [
            TFTertiaryButton(label: 'Cancelar', onPressed: () {}),
            const Spacer(),
            TFIconButton(
              icon: Icons.share_rounded,
              tooltip: 'Compartilhar',
              onPressed: () {},
            ),
            TFIconButton(
              icon: Icons.bookmark_border_rounded,
              tooltip: 'Salvar',
              onPressed: () {},
            ),
          ],
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('2. TFMobileCard Universal Reutilizável'),
        TFMobileCard(
          title: 'Manutenção de Disjuntor 14D3/BES',
          subtitle: 'Subestação Miracema • Bay 03',
          status: TFOperationalStatus.emExecucao,
          leadingAccent: TFMobileColors.primaryBlue,
          leading: const Icon(Icons.bolt_rounded, size: 28.0, color: TFMobileColors.primaryBlue),
          metadata: [
            _buildMetaChip(Icons.group_rounded, 'Equipe de Subestação'),
            _buildMetaChip(Icons.directions_car_rounded, 'Vtr-402 (Hilux)'),
            _buildMetaChip(Icons.access_time_rounded, '08:00 - 12:00'),
          ],
          primaryAction: TFPrimaryButton(
            label: 'Concluir',
            height: 48.0,
            onPressed: () {},
          ),
          secondaryAction: TFSecondaryButton(
            label: 'Checklist',
            height: 48.0,
            onPressed: () {},
          ),
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('3. Campos de Entrada (Touch Target Ergonômico)'),
        TFMobileTextField(
          label: 'Número da Nota ou Ordem SAP',
          hint: 'Ex: 40019283',
          prefixIcon: const Icon(Icons.search_rounded),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: TFMobileSpacing.md),
        TFMobileTextField(
          label: 'Observações de Campo (Multiline)',
          hint: 'Descreva a situação encontrada no local...',
          maxLines: 3,
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('4. BottomSheets e Filtros'),
        TFSecondaryButton(
          label: 'Abrir BottomSheet de Filtros',
          icon: Icons.tune_rounded,
          onPressed: () {
            TFMobileFilterSheet.show(
              context: context,
              options: const [
                TFFilterOption(id: '1', label: 'Equipe Subestação'),
                TFFilterOption(id: '2', label: 'Equipe Linhas Norte'),
                TFFilterOption(id: '3', label: 'Equipe Linha Viva'),
                TFFilterOption(id: '4', label: 'SE Miracema'),
                TFFilterOption(id: '5', label: 'SE Fortaleza'),
                TFFilterOption(id: '6', label: 'Status Em Execução'),
              ],
              initialSelectedIds: const {'1'},
              onApply: (sel) {},
            );
          },
        ),

        const SizedBox(height: TFMobileSpacing.xxl),
        _buildSectionHeader('5. Empty State de Adoção (Comunidade/Feed)'),
        const TFEmptyState.feedCommunity(),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.0, color: TFMobileColors.textSecondary(context)),
        const SizedBox(width: 4.0),
        Text(text, style: TFMobileTypography.caption),
      ],
    );
  }

  // ==========================================
  // ABA 3: FEED CORPORATIVO OPERACIONAL
  // ==========================================
  Widget _buildFeedTab() {
    return ListView(
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      children: [
        // Composer Contextual
        TFFeedComposer(
          contextLabel: 'na Equipe de Manutenção',
          onTap: () {
            _showPostCreationSheet(context);
          },
        ),

        // Lista de Itens do Feed (Humanos e Automáticos)
        ..._feedItems.map((item) {
          return TFFeedCard(
            item: item,
            onLike: () {
              setState(() {
                final idx = _feedItems.indexWhere((it) => it.id == item.id);
                if (idx != -1) {
                  final cur = _feedItems[idx];
                  _feedItems[idx] = TFFeedItem(
                    id: cur.id,
                    sourceType: cur.sourceType,
                    authorName: cur.authorName,
                    authorRole: cur.authorRole,
                    communityOrTeam: cur.communityOrTeam,
                    timestamp: cur.timestamp,
                    content: cur.content,
                    imageUrl: cur.imageUrl,
                    contextType: cur.contextType,
                    linkedEntityTitle: cur.linkedEntityTitle,
                    likesCount: cur.isLikedByMe ? cur.likesCount - 1 : cur.likesCount + 1,
                    commentsCount: cur.commentsCount,
                    isLikedByMe: !cur.isLikedByMe,
                    isOfflinePending: cur.isOfflinePending,
                  );
                }
              });
            },
            onComment: () {
              TFMobileBottomSheet.show(
                context: context,
                title: 'Comentários da Publicação',
                content: Column(
                  children: [
                    const Text('João: Excelente trabalho da turma!'),
                    const SizedBox(height: 12.0),
                    const Text('Carlos: APR e bloqueio elétrico já encerrados.'),
                    const SizedBox(height: 24.0),
                    TFMobileTextField(
                      hint: 'Adicionar comentário...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              );
            },
            onViewLinkedEntity: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Navegando para detalhes da atividade: ${item.linkedEntityTitle}')),
              );
            },
          );
        }),
      ],
    );
  }

  void _showPostCreationSheet(BuildContext context) {
    final postController = TextEditingController();
    TFMobileBottomSheet.show(
      context: context,
      title: 'Nova Publicação Operacional',
      content: Column(
        children: [
          TFMobileTextField(
            controller: postController,
            hint: 'O que você gostaria de compartilhar com a equipe?',
            maxLines: 4,
          ),
          const SizedBox(height: TFMobileSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TFSecondaryButton(
                  label: 'Tirar Foto',
                  icon: Icons.camera_alt_rounded,
                  height: 48.0,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: TFSecondaryButton(
                  label: 'Vincular Tarefa',
                  icon: Icons.link_rounded,
                  height: 48.0,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
      stickyFooter: TFPrimaryButton(
        label: 'Publicar no Feed',
        height: TFMobileTouchTargets.standard,
        onPressed: () {
          if (postController.text.trim().isNotEmpty) {
            setState(() {
              _feedItems.insert(
                0,
                TFFeedItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  sourceType: TFFeedSourceType.userPost,
                  authorName: 'Eu (Técnico Operacional)',
                  communityOrTeam: 'Equipe de Campo',
                  timestamp: 'agora',
                  content: postController.text.trim(),
                  likesCount: 0,
                  commentsCount: 0,
                  isOfflinePending: _syncStatus != TFSyncStatus.synced,
                ),
              );
            });
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  // ==========================================
  // ABA 4: CHAT E MENSAGENS
  // ==========================================
  Widget _buildChatTab() {
    return Column(
      children: [
        // Lista de Mensagens com Balões
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(TFMobileSpacing.sm),
            children: [
              // Exemplo de Comunidade e Conversa rápida no topo
              Padding(
                padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
                child: TFCommunityTile(
                  name: 'Equipe de Subestação',
                  description: 'Canal operacional da turma de manutenção',
                  category: 'Equipe',
                  membersCount: 8,
                  unreadCount: 2,
                  onTap: () {},
                ),
              ),
              const Divider(height: 1.0),
              const SizedBox(height: TFMobileSpacing.sm),

              // Balões de Mensagem
              ..._chatMessages.map((msg) {
                return TFMessageBubble(
                  text: msg['text'],
                  time: msg['time'],
                  isMe: msg['isMe'],
                  senderName: msg['sender'],
                  senderRole: msg['role'],
                  deliveryStatus: msg['status'],
                  attachedImageUrl: msg['image'],
                  linkedActivityTitle: msg['activity'],
                  onLinkedActivityTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Abrindo ${msg['activity']}')),
                    );
                  },
                );
              }),
            ],
          ),
        ),

        // Barra de Entrada de Chat Multiline Ancorada
        TFChatInput(
          isOfflinePending: _syncStatus != TFSyncStatus.synced,
          onSend: (text) {
            setState(() {
              _chatMessages.add({
                'text': text,
                'time': 'agora',
                'isMe': true,
                'status': _syncStatus == TFSyncStatus.synced
                    ? TFMessageDeliveryStatus.sent
                    : TFMessageDeliveryStatus.pendingOffline,
              });
            });
          },
          onCameraTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Câmera rápida acionada')),
            );
          },
          onAttachmentTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Seletor de evidências/documentos')),
            );
          },
          onVoiceTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gravação de áudio operacional mantida')),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // ABA 5: HOME "HOJE" + ACONTECENDO AGORA
  // ==========================================
  Widget _buildHomeTodayTab() {
    return ListView(
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      children: [
        // Saudação e Resumo Operacional
        Text('Bom dia, Carlos', style: TFMobileTypography.display),
        const SizedBox(height: 4.0),
        Text('Quinta-feira, 17 de Setembro • Equipe Subestação Norte',
            style: TFMobileTypography.bodyMedium),

        const SizedBox(height: TFMobileSpacing.lg),

        // Card de Recursos do Dia (Veículo e Turma)
        Container(
          padding: const EdgeInsets.all(TFMobileSpacing.md),
          decoration: BoxDecoration(
            color: TFMobileColors.surface(context),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: TFMobileColors.border(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: TFMobileColors.primaryBlue, size: 28.0),
              const SizedBox(width: TFMobileSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Veículo do Dia: Hilux 4x4 (Placa: ABC-1234)', style: TFMobileTypography.label),
                    Text('Motorista: Marcos Silva • 3 técnicos a bordo', style: TFMobileTypography.caption),
                  ],
                ),
              ),
              TFMobileStatusChip.operational(status: TFOperationalStatus.emExecucao, dense: true),
            ],
          ),
        ),

        const SizedBox(height: TFMobileSpacing.xl),
        _buildSectionHeader('MINHAS ATIVIDADES DE HOJE (3)'),

        TFMobileCard(
          title: 'Substituição de Isolador 69kV',
          subtitle: 'SE Miracema • Alimentador 02',
          status: TFOperationalStatus.emExecucao,
          leadingAccent: TFMobileColors.primaryBlue,
          metadata: [
            _buildMetaChip(Icons.access_time_rounded, '08:30 - 11:30'),
            _buildMetaChip(Icons.assignment_outlined, 'Nota SAP: 4002911'),
          ],
          primaryAction: TFPrimaryButton(
            label: 'Concluir Atividade',
            height: 48.0,
            onPressed: () {},
          ),
        ),

        TFMobileCard(
          title: 'Checklist de Segurança APR',
          subtitle: 'Inspeção de EPIs e Aterramento',
          status: TFOperationalStatus.pendente,
          leadingAccent: TFMobileColors.warning,
          primaryAction: TFPrimaryButton(
            label: 'Preencher APR',
            height: 48.0,
            onPressed: () {},
          ),
        ),

        const SizedBox(height: TFMobileSpacing.xl),
        // Seção Obrigatória: ACONTECENDO AGORA (Sincronizada com o Feed)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('ACONTECENDO AGORA'),
            TextButton(
              onPressed: () {
                _tabController.animateTo(2); // Vai para a aba de Feed
              },
              child: const Text('Ver Feed Completo'),
            ),
          ],
        ),

        // Mini cards de eventos recentes
        ..._feedItems.take(2).map((item) {
          return TFFeedCard(item: item);
        }),

        const SizedBox(height: TFMobileSpacing.xxl),
        // Teste de Conteúdo Extremo (Ajuste #11)
        _buildSectionHeader('TESTE DE CASOS EXTREMOS (SEM OVERFLOW)'),
        TFMobileCard(
          title: 'Manutenção Preventiva e Inspeção Termográfica Periódica em Chave Seccionadora Tripolar 230kV com Abertura em Carga sob Tensão da Subestação Elevadora Central',
          subtitle: 'Linha de Transmissão 500kV Tucuruí-Miracema-Imperatriz Circuito Duplo C1/C2 Trecho Extenso Vão 400 a 450 com Travessia Fluvial de Alta Complexidade Operacional',
          status: TFOperationalStatus.atrasado,
          metadata: [
            _buildMetaChip(Icons.warning_amber_rounded, 'Texto longo validado sem quebra ou RenderFlex overflow'),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      child: Text(
        title,
        style: TFMobileTypography.titleMedium.copyWith(
          color: TFMobileColors.primaryBlue,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
