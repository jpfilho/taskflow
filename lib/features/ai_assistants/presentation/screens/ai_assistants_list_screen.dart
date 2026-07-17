import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/ai_assistant_config.dart';
import '../../data/repositories/local_ai_assistant_repository.dart';
import '../../data/services/nvidia_api_key_service.dart';
import '../widgets/ai_assistant_card.dart';
import 'ai_assistant_editor_screen.dart';
import 'ai_assistant_test_screen.dart';

class AiAssistantsListScreen extends StatefulWidget {
  static const bool emConstrucao = false;

  const AiAssistantsListScreen({super.key});

  @override
  State<AiAssistantsListScreen> createState() => _AiAssistantsListScreenState();
}

class _AiAssistantsListScreenState extends State<AiAssistantsListScreen> {
  final _repository = LocalAiAssistantRepository();
  final _apiKeyService = NvidiaApiKeyService();
  final _searchController = TextEditingController();

  List<AiAssistantConfig> _assistants = [];
  List<AiAssistantConfig> _filteredAssistants = [];
  String _maskedApiKey = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await _repository.getAll();
    final masked = await _apiKeyService.getMaskedApiKey();
    setState(() {
      _assistants = list;
      _filteredAssistants = list;
      _maskedApiKey = masked;
      _isLoading = false;
    });
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredAssistants = _assistants;
      } else {
        _filteredAssistants = _assistants.where((a) {
          return a.name.toLowerCase().contains(query) ||
              a.description.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openApiKeyDialog() async {
    final controller = TextEditingController();
    final hasKey = await _apiKeyService.hasApiKey();
    final isEnv = _apiKeyService.isEnvApiKey();

    if (hasKey && !isEnv) {
      // Pré-popular com a chave atual se houver e não for de ambiente
      controller.text = await _apiKeyService.getApiKey();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Configurar NVIDIA API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEnv) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Chave de API configurada via variável de ambiente (NVIDIA_API_KEY).',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Insira sua chave NVIDIA API para habilitar a simulação e melhoria de prompts via IA:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                enabled: !isEnv,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Chave API NVIDIA',
                  labelStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: dark ? Colors.grey[900] : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
              onPressed: () => Navigator.pop(context),
            ),
            if (hasKey && !isEnv)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Remover Chave', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await _apiKeyService.deleteApiKey();
                  await _loadData();
                  if (mounted) Navigator.pop(context);
                },
              ),
            if (!isEnv)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: const Text('Salvar', style: TextStyle(fontSize: 12, color: Colors.white)),
                onPressed: () async {
                  await _apiKeyService.saveApiKey(controller.text);
                  await _loadData();
                  if (mounted) Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  void _duplicateAssistant(AiAssistantConfig assistant) {
    final now = DateTime.now();
    final uuid = Uuid();
    final duplicate = assistant.copyWith(
      id: uuid.v4(),
      name: 'Cópia de ${assistant.name}',
      createdAt: now,
      updatedAt: now,
    );

    _repository.save(duplicate).then((_) => _loadData());
  }

  void _confirmDelete(AiAssistantConfig assistant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Assistente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Tem certeza que deseja excluir o assistente "${assistant.name}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir', style: TextStyle(fontSize: 12, color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _repository.delete(assistant.id).then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AiAssistantsListScreen.emConstrucao) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final primaryColor = theme.primaryColor;
      const accentColor = Color(0xFF8B5CF6); // Violeta IA
      
      final backgroundColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
      final cardColor = isDark ? const Color(0xFF151D30).withOpacity(0.8) : Colors.white.withOpacity(0.9);
      final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
      final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Central de Assistentes IA'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.9 + (value * 0.1),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge "EM CONSTRUÇÃO"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [accentColor, Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'EM CONSTRUÇÃO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Icone com Glow
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1A33) : const Color(0xFFEEF2F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.smart_toy_rounded,
                          size: 36,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Central de Assistentes IA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nossa nova central de inteligência artificial está sendo aprimorada. Em breve, você poderá simular prompts e gerenciar assistentes inteligentes baseados em NVIDIA LLM para auxiliar nas tomadas de decisão e distribuição de suas demandas operacionais.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Progresso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aprimorando LLMs & Prompts',
                              style: TextStyle(fontSize: 10.5, color: subtextColor, fontWeight: FontWeight.w500),
                            ),
                            const Text(
                              'Em breve',
                              style: TextStyle(fontSize: 10.5, color: accentColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: 0.7,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(accentColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Assistentes IA'),
        actions: [
          // Exibição da chave mascarada e botão de chave API
          InkWell(
            onTap: _openApiKeyDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Icon(
                    _maskedApiKey.isNotEmpty ? Icons.vpn_key : Icons.vpn_key_outlined,
                    size: 18,
                    color: _maskedApiKey.isNotEmpty ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _maskedApiKey.isNotEmpty ? _maskedApiKey : 'Sem Chave',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _maskedApiKey.isNotEmpty ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra de Busca
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar assistentes...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            filled: true,
                            fillColor: dark ? Colors.grey[900] : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo Assistente', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AiAssistantEditorScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Lista de Cards
                Expanded(
                  child: _filteredAssistants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.smart_toy_outlined,
                                size: 48,
                                color: dark ? Colors.grey[700] : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.trim().isEmpty
                                    ? 'Nenhum assistente cadastrado.'
                                    : 'Nenhum assistente correspondente à busca.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 450,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredAssistants.length,
                          itemBuilder: (context, index) {
                            final assistant = _filteredAssistants[index];
                            return AiAssistantCard(
                              assistant: assistant,
                              onEdit: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiAssistantEditorScreen(
                                      assistant: assistant,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadData();
                                }
                              },
                              onTest: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiAssistantTestScreen(
                                      assistant: assistant,
                                    ),
                                  ),
                                );
                              },
                              onDuplicate: () => _duplicateAssistant(assistant),
                              onDelete: () => _confirmDelete(assistant),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
