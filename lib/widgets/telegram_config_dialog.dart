import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/telegram_service.dart';

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

      setState(() {
        _isLinked = isLinked;
        _identity = identity;
        _subscriptions = subscriptions;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar dados Telegram: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _vincularConta() async {
    final linkUrl = _telegramService.generateLinkUrl();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular Telegram'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para vincular sua conta Telegram ao TaskFlow:\n\n'
              '1. Abra o link abaixo no Telegram\n'
              '2. Inicie o bot\n'
              '3. Siga as instruções',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                linkUrl,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: linkUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado!')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Não foi possível copiar: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
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
        Navigator.pop(context); // Fechar dialog de criação
        _loadData(); // Recarregar dados
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
      builder: (context) => AlertDialog(
        title: const Text('Remover espelhamento'),
        content: const Text('Tem certeza que deseja desativar o espelhamento para o Telegram?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        title: const Text('Ativar espelhamento Telegram'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure o espelhamento das mensagens para o Telegram:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Modo
              const Text('Modo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'group_topic',
                    child: Text('Grupo com tópicos'),
                  ),
                  DropdownMenuItem(
                    value: 'group_plain',
                    child: Text('Grupo simples'),
                  ),
                  DropdownMenuItem(
                    value: 'dm',
                    child: Text('Mensagem direta (DM)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMode = value ?? 'group_topic';
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Chat ID
              const Text('Chat ID do Telegram:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _chatIdController,
                decoration: const InputDecoration(
                  hintText: 'Ex: -1001234567890',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                'Para obter o Chat ID, adicione @userinfobot ao grupo',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              
              // Topic ID (se mode = group_topic)
              if (_selectedMode == 'group_topic') ...[
                const SizedBox(height: 16),
                const Text('Topic ID (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _topicIdController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 123',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _criarSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Telegram',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Status da vinculação
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isLinked ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isLinked ? Colors.green[200]! : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isLinked ? Icons.check_circle : Icons.warning,
                      color: _isLinked ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLinked ? 'Conta vinculada' : 'Conta não vinculada',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_isLinked && _identity != null)
                            Text(
                              '@${_identity!.telegramUsername ?? _identity!.telegramFirstName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                        ],
                      ),
                    ),
                    if (!_isLinked)
                      ElevatedButton(
                        onPressed: _vincularConta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Vincular'),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Subscriptions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Espelhamento ativo:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_isLinked)
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF075E54)),
                      onPressed: _mostrarFormCriarSubscription,
                      tooltip: 'Adicionar espelhamento',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync_disabled, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _isLinked
                                  ? 'Nenhum espelhamento ativo'
                                  : 'Vincule sua conta para ativar',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _subscriptions.length,
                        itemBuilder: (context, index) {
                          final sub = _subscriptions[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                sub.mode == 'dm'
                                    ? Icons.person
                                    : sub.mode == 'group_topic'
                                        ? Icons.forum
                                        : Icons.group,
                                color: const Color(0xFF0088CC),
                              ),
                              title: Text(_getModeLabel(sub.mode)),
                              subtitle: Text(
                                'Chat: ${sub.telegramChatId}${sub.telegramTopicId != null ? ' • Tópico: ${sub.telegramTopicId}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
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
