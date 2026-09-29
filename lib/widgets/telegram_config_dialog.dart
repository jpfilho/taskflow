import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../design_system/taskflow_design_system.dart';
import '../utils/clipboard_helper.dart';

class TelegramConfigDialog extends StatefulWidget {
  final String grupoId;
  final String grupoNome;

  const TelegramConfigDialog({
    super.key,
    required this.grupoId,
    required this.grupoNome,
  });

  @override
  State<TelegramConfigDialog> createState() => _TelegramConfigDialogState();
}

class _TelegramConfigDialogState extends State<TelegramConfigDialog> {
  final TelegramService _telegramService = TelegramService();

  bool _isLoading = true;
  bool _isLinked = false;
  TelegramIdentity? _identity;
  List<TelegramSubscription> _subscriptions = [];

  // Form fields
  final _chatIdController = TextEditingController();
  final _topicIdController = TextEditingController();
  String _selectedMode = 'group_topic';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chatIdController.dispose();
    _topicIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final isLinked = await _telegramService.isLinked();
      TelegramIdentity? identity;
      List<TelegramSubscription> subscriptions = [];

      if (isLinked) {
        identity = await _telegramService.getIdentity();
        subscriptions = await _telegramService.getSubscriptions('TASK', widget.grupoId);
      }

      if (mounted) {
        setState(() {
          _isLinked = isLinked;
          _identity = identity;
          _subscriptions = subscriptions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _vincularConta() async {
    final linkUrl = _telegramService.generateLinkUrl();

    showDialog(
      context: context,
      builder: (context) {
        final colors = context.tfColors;
        final typography = context.tfTypography;

        return TFModalDialog(
          title: 'Vincular Telegram',
          subtitle: 'Conecte sua conta do Telegram ao TaskFlow',
          icon: Icons.telegram,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para vincular sua conta Telegram ao TaskFlow:\n\n'
                '1. Abra o link abaixo no Telegram\n'
                '2. Inicie o bot oficial\n'
                '3. Siga as instruções na conversa',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(TFRadius.r12),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: SelectableText(
                  linkUrl,
                  style: typography.caption.copyWith(
                    fontFamily: 'monospace',
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          primaryAction: TFButton(
            label: 'Copiar Link',
            leadingIcon: Icons.copy,
            onPressed: () async {
              await ClipboardHelper.copyAndNotify(
                context,
                linkUrl,
                successMessage: 'Link copiado!',
                errorMessage: 'Não foi possível copiar o link.',
              );
            },
          ),
          secondaryAction: TFButton(
            label: 'Fechar',
            variant: TFButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  Future<void> _criarSubscription() async {
    final chatId = int.tryParse(_chatIdController.text.trim());

    if (chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat ID inválido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? topicId;
    if (_selectedMode == 'group_topic' && _topicIdController.text.isNotEmpty) {
      topicId = int.tryParse(_topicIdController.text.trim());
    }

    try {
      await _telegramService.createSubscription(
        threadType: 'TASK',
        threadId: widget.grupoId,
        mode: _selectedMode,
        telegramChatId: chatId,
        telegramTopicId: topicId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espelhamento ativado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removerSubscription(String subscriptionId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => TFModalDialog(
        title: 'Remover espelhamento',
        content: const Text('Tem certeza que deseja desativar o espelhamento para o Telegram?'),
        primaryAction: TFButton(
          label: 'Remover',
          variant: TFButtonVariant.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
        secondaryAction: TFButton(
          label: 'Cancelar',
          variant: TFButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
    );

    if (confirmar == true) {
      try {
        await _telegramService.deleteSubscription(subscriptionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Espelhamento removido'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _mostrarFormCriarSubscription() {
    showDialog(
      context: context,
      builder: (context) {
        return TFModalDialog(
          title: 'Ativar espelhamento Telegram',
          subtitle: 'Configure a integração de mensagens com o canal/grupo',
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TFDropdown<String>(
                      label: 'Modo de Espelhamento',
                      value: _selectedMode,
                      items: const ['group_topic', 'group_plain', 'dm'],
                      displayText: _getModeLabel,
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedMode = value ?? 'group_topic';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TFTextField(
                      label: 'Chat ID do Telegram',
                      controller: _chatIdController,
                      hint: 'Ex: -1001234567890',
                      keyboardType: TextInputType.number,
                      helperText: 'Para obter o Chat ID, adicione @userinfobot ao grupo',
                    ),
                    if (_selectedMode == 'group_topic') ...[
                      const SizedBox(height: 16),
                      TFTextField(
                        label: 'Topic ID (opcional)',
                        controller: _topicIdController,
                        hint: 'Ex: 123',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          primaryAction: TFButton(
            label: 'Ativar',
            variant: TFButtonVariant.primary,
            onPressed: _criarSubscription,
          ),
          secondaryAction: TFButton(
            label: 'Cancelar',
            variant: TFButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.telegram, color: colors.info, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configuração Telegram',
                    style: typography.pageTitle.copyWith(color: colors.textPrimary),
                  ),
                ),
                TFIconButton(
                  icon: Icons.close,
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(height: 32, color: colors.borderSubtle),
            if (_isLoading)
              const Center(child: TFLoading(message: 'Carregando dados do Telegram...'))
            else ...[
              // Status da vinculação
              TFCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _isLinked ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _isLinked ? colors.success : colors.warning,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLinked ? 'Conta vinculada' : 'Conta não vinculada',
                              style: typography.cardTitle.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            if (_isLinked && _identity != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@${_identity!.telegramUsername ?? _identity!.telegramFirstName}',
                                style: typography.caption.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!_isLinked)
                        TFButton(
                          label: 'Vincular',
                          size: TFButtonSize.small,
                          onPressed: _vincularConta,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Subscriptions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Espelhamentos Ativos',
                    style: typography.sectionTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_isLinked)
                    TFButton(
                      label: 'Novo',
                      leadingIcon: Icons.add,
                      size: TFButtonSize.small,
                      variant: TFButtonVariant.secondary,
                      onPressed: _mostrarFormCriarSubscription,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _subscriptions.isEmpty
                    ? Center(
                        child: TFEmptyState(
                          icon: Icons.sync_disabled,
                          title: _isLinked ? 'Nenhum espelhamento ativo' : 'Vincule sua conta',
                          description: _isLinked
                              ? 'Adicione um grupo ou tópico para receber notificações.'
                              : 'Vincule sua conta Telegram para gerenciar espelhamentos.',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _subscriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sub = _subscriptions[index];
                          return TFCard(
                            child: ListTile(
                              leading: Icon(
                                sub.mode == 'dm'
                                    ? Icons.person
                                    : sub.mode == 'group_topic'
                                        ? Icons.forum
                                        : Icons.group,
                                color: colors.info,
                              ),
                              title: Text(
                                _getModeLabel(sub.mode),
                                style: typography.labelLarge.copyWith(color: colors.textPrimary),
                              ),
                              subtitle: Text(
                                'Chat: ${sub.telegramChatId}${sub.telegramTopicId != null ? ' • Tópico: ${sub.telegramTopicId}' : ''}',
                                style: typography.caption.copyWith(color: colors.textSecondary),
                              ),
                              trailing: TFIconButton(
                                icon: Icons.delete_outline,
                                tooltip: 'Remover espelhamento',
                                onPressed: () => _removerSubscription(sub.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'dm':
        return 'Mensagem Direta';
      case 'group_topic':
        return 'Grupo com Tópicos';
      case 'group_plain':
        return 'Grupo Simples';
      default:
        return mode;
    }
  }
}
