import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/ai_chart_widget.dart';
import '../../domain/models/ai_assistant_config.dart';
import '../../domain/services/nvidia_llm_service.dart';
import '../../data/services/ai_database_context_service.dart';

class AiAssistantTestScreen extends StatefulWidget {
  final AiAssistantConfig assistant;

  const AiAssistantTestScreen({super.key, required this.assistant});

  @override
  State<AiAssistantTestScreen> createState() => _AiAssistantTestScreenState();
}

class _AiAssistantTestScreenState extends State<AiAssistantTestScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _llmService = NvidiaLlmService();
  final _dbContextService = AiDatabaseContextService();
  
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _showSystemPrompt = false;

  String _dbContext = '';
  bool _isLoadingDb = false;
  int _activeTasksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDatabaseContext();
  }

  Future<void> _loadDatabaseContext() async {
    setState(() {
      _isLoadingDb = true;
    });
    try {
      final result = await _dbContextService.getDatabaseContext();
      setState(() {
        _dbContext = result.markdownContext;
        _activeTasksCount = result.activeTasksCount;
      });
    } catch (e) {
      print('⚠️ Erro ao carregar contexto de tarefas: $e');
    } finally {
      setState(() {
        _isLoadingDb = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messageController.clear();
      _isLoading = true;
    });
    
    _scrollToBottom();

    final systemPrompt = widget.assistant.systemPrompt;
    
    const chartInstructions = '''
# SUPORTE A GRÁFICOS INTERATIVOS
Você possui capacidade de renderizar gráficos interativos e visuais de alta qualidade diretamente na tela de chat do usuário.
Sempre que o usuário solicitar um gráfico, ou quando for extremamente benéfico para resumir informações numéricas quantitativas (como volume de tarefas por status, prioridades de notas SAP, ordens por tipo, etc.), insira um bloco de código com a tag ` ```chart ` contendo um objeto JSON estruturado da seguinte forma:
```json
{
  "type": "bar" | "pie" | "line",
  "title": "Título explicativo do gráfico",
  "data": [
    {"label": "Nome da Categoria", "value": 15},
    {"label": "Outra Categoria", "value": 8}
  ]
}
```
Use tipo "bar" ou "pie" para categorias (como locais, status, prioridades) e "line" para dados ordenados no tempo.
Não inclua textos explicativos dentro do bloco json do gráfico. Escreva o texto normal fora do bloco.
''';

    final consolidatedSystemPrompt = [
      systemPrompt,
      chartInstructions,
      if (_dbContext.isNotEmpty) _dbContext,
    ].join('\n\n');

    final history = _messages
        .take(_messages.length - 1)
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .map((m) => {
              'role': m['role'] as String,
              'content': m['content'] as String,
            })
        .toList();

    int assistantMessageIndex = -1;

    try {
      final stream = _llmService.generateResponseStream(
        systemPrompt: consolidatedSystemPrompt,
        userPrompt: text,
        modelName: widget.assistant.modelName,
        temperature: widget.assistant.temperature,
        maxTokens: widget.assistant.maxTokens,
        history: history,
      );

      String fullResponse = '';

      await for (final chunk in stream) {
        if (assistantMessageIndex == -1) {
          setState(() {
            assistantMessageIndex = _messages.length;
            _messages.add({'role': 'assistant', 'content': ''});
          });
        }

        fullResponse += chunk;
        setState(() {
          _messages[assistantMessageIndex]['content'] = fullResponse;
        });
        _scrollToBottom();
      }

      if (assistantMessageIndex == -1) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'A IA não retornou nenhuma resposta.',
          });
        });
      }
    } catch (e) {
      setState(() {
        if (assistantMessageIndex != -1) {
          _messages[assistantMessageIndex]['content'] = 
              '${_messages[assistantMessageIndex]['content']}\n\n⚠️ Erro de transmissão: ${e.toString().replaceFirst('Exception: ', '')}';
        } else {
          _messages.add({
            'role': 'error',
            'content': e.toString().replaceFirst('Exception: ', ''),
          });
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simular: ${widget.assistant.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Modelo: ${widget.assistant.modelName}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(_showSystemPrompt ? Icons.visibility : Icons.visibility_off),
            tooltip: 'Ver Prompt do Sistema',
            onPressed: () {
              setState(() {
                _showSystemPrompt = !_showSystemPrompt;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingDb)
            LinearProgressIndicator(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          if (_dbContext.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? Colors.green[950]!.withOpacity(0.2) : Colors.green[50],
                border: Border(
                  bottom: BorderSide(
                    color: dark ? Colors.green[900]!.withOpacity(0.4) : Colors.green[100]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conectado ao Supabase: $_activeTasksCount tarefas ativas carregadas no contexto da IA.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: dark ? Colors.green[300] : Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Prompt de Sistema Expansível
          if (_showSystemPrompt)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: dark ? Colors.grey[900] : Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dark ? Colors.grey[800]! : Colors.amber[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prompt do Sistema consolidado:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () => setState(() => _showSystemPrompt = false),
                        child: const Icon(Icons.close, size: 14),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        widget.assistant.systemPrompt,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: dark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Área de Balões
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 48,
                          color: dark ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Envie uma pergunta ou tarefa para simular o comportamento.',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      final isError = msg['role'] == 'error';

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.primaryColor
                                : (isError
                                    ? Colors.redAccent.withOpacity(0.15)
                                    : (dark ? Colors.grey[900] : Colors.grey[200])),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                            ),
                            border: isError
                                ? Border.all(color: Colors.redAccent, width: 0.5)
                                : null,
                          ),
                           child: isUser
                              ? Text(
                                  msg['content'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                )
                              : _buildAssistantMessage(
                                  msg['content'] ?? '',
                                  theme,
                                  dark,
                                  isError,
                                ),
                        ),
                      );
                    },
                  ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pensando...',
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Campo de Entrada
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: dark ? Colors.grey[950] : Colors.grey[100],
              border: Border(
                top: BorderSide(
                  color: dark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Pergunte algo...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      fillColor: dark ? Colors.grey[900] : Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: dark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: dark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: theme.primaryColor,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(String content, ThemeData theme, bool dark, bool isError) {
    if (isError) {
      return MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: const TextStyle(fontSize: 14, color: Colors.redAccent),
        ),
      );
    }

    final List<Widget> children = [];
    final RegExp regExp = RegExp(r'```chart([\s\S]*?)```');
    
    int lastIndex = 0;
    for (final Match match in regExp.allMatches(content)) {
      if (match.start > lastIndex) {
        final textBefore = content.substring(lastIndex, match.start).trim();
        if (textBefore.isNotEmpty) {
          children.add(
            MarkdownBody(
              data: textBefore,
              selectable: true,
              styleSheet: _getMarkdownStyleSheet(theme, dark),
            ),
          );
        }
      }

      final chartJson = match.group(1)?.trim() ?? '';
      if (chartJson.isNotEmpty) {
        children.add(
          AiChartWidget(jsonContent: chartJson),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      final textAfter = content.substring(lastIndex).trim();
      if (textAfter.isNotEmpty) {
        children.add(
          MarkdownBody(
            data: textAfter,
            selectable: true,
            styleSheet: _getMarkdownStyleSheet(theme, dark),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(ThemeData theme, bool dark) {
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        fontSize: 14,
        color: dark ? Colors.white : Colors.black87,
      ),
      h1: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black87,
      ),
      h2: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black87,
      ),
      h3: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black87,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black87,
      ),
      listBullet: TextStyle(
        color: dark ? Colors.white : Colors.black87,
      ),
      tableBody: TextStyle(
        fontSize: 13,
        color: dark ? Colors.white : Colors.black87,
      ),
      tableHead: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black87,
      ),
    );
  }
}

