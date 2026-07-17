import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/ai_assistant_config.dart';
import '../../domain/models/prompt_version.dart';
import '../../domain/services/prompt_builder_service.dart';
import '../../domain/services/nvidia_llm_service.dart';
import '../../data/repositories/local_ai_assistant_repository.dart';
import '../../data/services/nvidia_api_key_service.dart';
import '../widgets/prompt_editor_field.dart';
import '../widgets/model_selector.dart';
import 'ai_assistant_test_screen.dart';
import 'prompt_version_history_screen.dart';

class AiAssistantEditorScreen extends StatefulWidget {
  final AiAssistantConfig? assistant;

  const AiAssistantEditorScreen({super.key, this.assistant});

  @override
  State<AiAssistantEditorScreen> createState() => _AiAssistantEditorScreenState();
}

class _AiAssistantEditorScreenState extends State<AiAssistantEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = LocalAiAssistantRepository();
  final _apiKeyService = NvidiaApiKeyService();
  final _llmService = NvidiaLlmService();
  final _uuid = const Uuid();

  late String _id;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _roleController;
  late TextEditingController _objectiveController;
  late TextEditingController _toneOfVoiceController;
  late TextEditingController _businessRulesController;
  late TextEditingController _avoidRulesController;
  late TextEditingController _contextController;
  late TextEditingController _systemPromptController;
  late String _modelName;
  late double _temperature;
  late int _maxTokens;
  late DateTime _createdAt;
  late List<PromptVersion> _versions;

  bool _isImproving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assistant;
    _id = a?.id ?? _uuid.v4();
    _nameController = TextEditingController(text: a?.name ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _roleController = TextEditingController(text: a?.role ?? '');
    _objectiveController = TextEditingController(text: a?.objective ?? '');
    _toneOfVoiceController = TextEditingController(text: a?.toneOfVoice ?? '');
    _businessRulesController = TextEditingController(text: a?.businessRules ?? '');
    _avoidRulesController = TextEditingController(text: a?.avoidRules ?? '');
    _contextController = TextEditingController(text: a?.context ?? '');
    _systemPromptController = TextEditingController(text: a?.systemPrompt ?? '');
    _modelName = a?.modelName ?? 'qwen/qwen3.5-122b-a10b';
    _temperature = a?.temperature ?? 0.3;
    _maxTokens = a?.maxTokens ?? 2048;
    _createdAt = a?.createdAt ?? DateTime.now();
    _versions = a?.versions != null ? List<PromptVersion>.from(a!.versions) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _roleController.dispose();
    _objectiveController.dispose();
    _toneOfVoiceController.dispose();
    _businessRulesController.dispose();
    _avoidRulesController.dispose();
    _contextController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  void _consolidatePrompt() {
    final consolidated = PromptBuilderService.buildSystemPrompt(
      role: _roleController.text,
      objective: _objectiveController.text,
      context: _contextController.text,
      businessRules: _businessRulesController.text,
      avoidRules: _avoidRulesController.text,
      toneOfVoice: _toneOfVoiceController.text,
    );
    setState(() {
      _systemPromptController.text = consolidated;
    });
  }

  Future<void> _improvePromptWithAi() async {
    final hasKey = await _apiKeyService.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chave da API NVIDIA não configurada. Configure-a na tela de listagem.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _consolidatePrompt();
    final currentPrompt = _systemPromptController.text.trim();
    if (currentPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos de prompt antes de solicitar melhorias.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isImproving = true);

    try {
      const expertSystemPrompt = 
          'Você é um especialista em engenharia de prompts.\n'
          'Melhore o prompt abaixo sem alterar sua intenção principal.\n'
          'Torne-o mais claro, robusto, seguro, estruturado e fácil de manter.\n'
          'Preserve regras de negócio, tom de voz e restrições.\n'
          'Não remova informações importantes.\n'
          'Retorne apenas a versão melhorada do prompt.';

      final response = await _llmService.generateResponse(
        systemPrompt: expertSystemPrompt,
        userPrompt: currentPrompt,
        modelName: _modelName,
        temperature: 0.4,
        maxTokens: _maxTokens,
      );

      if (mounted) {
        _showImprovementComparisonDialog(currentPrompt, response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao melhorar prompt: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImproving = false);
      }
    }
  }

  void _showImprovementComparisonDialog(String original, String improved) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revisar Prompt Melhorado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prompt Original:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: dark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: dark ? Colors.grey[800]! : Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            child: Text(original, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Melhoria Proposta (NVIDIA LLM):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                          ),
                          child: SingleChildScrollView(
                            child: Text(improved, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
              child: const Text('Aceitar e Aplicar', style: TextStyle(fontSize: 12, color: Colors.white)),
              onPressed: () {
                setState(() {
                  _systemPromptController.text = improved;
                  // Adiciona histórico antigo
                  _versions.add(PromptVersion(
                    id: _uuid.v4(),
                    prompt: original,
                    changeNote: 'Antes da melhoria automática com IA.',
                    createdAt: DateTime.now(),
                  ));
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prompt melhorado aplicado com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _saveAssistant() {
    if (!_formKey.currentState!.validate()) return;

    if (_systemPromptController.text.trim().isEmpty) {
      _consolidatePrompt();
    }

    final currentPrompt = _systemPromptController.text.trim();
    
    // Se o prompt atual for diferente do último prompt do histórico, salva uma nova versão
    final lastVer = _versions.isNotEmpty ? _versions.last.prompt : '';
    if (currentPrompt != lastVer) {
      _versions.add(PromptVersion(
        id: _uuid.v4(),
        prompt: currentPrompt,
        changeNote: widget.assistant == null ? 'Criação inicial do assistente.' : 'Edição manual do usuário.',
        createdAt: DateTime.now(),
      ));
    }

    final newConfig = AiAssistantConfig(
      id: _id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      role: _roleController.text.trim(),
      objective: _objectiveController.text.trim(),
      toneOfVoice: _toneOfVoiceController.text.trim(),
      businessRules: _businessRulesController.text.trim(),
      avoidRules: _avoidRulesController.text.trim(),
      context: _contextController.text.trim(),
      systemPrompt: currentPrompt,
      modelProvider: 'nvidia',
      modelName: _modelName,
      temperature: _temperature,
      maxTokens: _maxTokens,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      versions: _versions,
    );

    _repository.save(newConfig).then((_) {
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assistente salvo localmente com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _testAssistant() {
    if (_systemPromptController.text.trim().isEmpty) {
      _consolidatePrompt();
    }
    
    final tempConfig = AiAssistantConfig(
      id: _id,
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Testando...',
      description: _descriptionController.text.trim(),
      role: _roleController.text.trim(),
      objective: _objectiveController.text.trim(),
      toneOfVoice: _toneOfVoiceController.text.trim(),
      businessRules: _businessRulesController.text.trim(),
      avoidRules: _avoidRulesController.text.trim(),
      context: _contextController.text.trim(),
      systemPrompt: _systemPromptController.text.trim(),
      modelProvider: 'nvidia',
      modelName: _modelName,
      temperature: _temperature,
      maxTokens: _maxTokens,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      versions: _versions,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiAssistantTestScreen(assistant: tempConfig),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assistant == null ? 'Criar Assistente IA' : 'Editar Assistente IA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Ver Histórico',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PromptVersionHistoryScreen(
                    versions: _versions,
                    currentVersion: _versions.isNotEmpty ? _versions.last : null,
                    onRestoreVersion: (version) {
                      setState(() {
                        _systemPromptController.text = version.prompt;
                        // Opcional: preencher campos de texto a partir do histórico?
                        // Como o histórico guarda o systemPrompt consolidado, restauramos a área final.
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Versão antiga do prompt carregada na tela.'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Simular/Testar',
            onPressed: _testAssistant,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção Identificação
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 14, color: dark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Nome do Assistente *',
                        labelStyle: const TextStyle(fontSize: 13),
                        filled: true,
                        fillColor: dark ? Colors.grey[900] : Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Insira o nome do assistente';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black87),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Descrição Curta',
                        labelStyle: const TextStyle(fontSize: 13),
                        filled: true,
                        fillColor: dark ? Colors.grey[900] : Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Parâmetros NVIDIA
                    ModelSelector(
                      selectedModelName: _modelName,
                      onModelChanged: (val) {
                        setState(() {
                          _modelName = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temperatura: ${_temperature.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Slider(
                                value: _temperature,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                activeColor: theme.primaryColor,
                                onChanged: (val) {
                                  setState(() {
                                    _temperature = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _maxTokens.toString(),
                            style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black87),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max Tokens',
                              labelStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: dark ? Colors.grey[900] : Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (val) {
                              final numVal = int.tryParse(val);
                              if (numVal != null) {
                                _maxTokens = numVal;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Campos de Prompt
                    const Text(
                      'Estruturação dos Campos de Prompt',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'Papel do Assistente',
                      hintText: 'Ex: Você é um analista sênior de suporte...',
                      controller: _roleController,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'Objetivo',
                      hintText: 'Ex: Resolver chamados técnicos de primeiro nível de forma ágil...',
                      controller: _objectiveController,
                      icon: Icons.track_changes,
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'Contexto',
                      hintText: 'Ex: A empresa trabalha com suporte 24h e o SLA é de 4 horas...',
                      controller: _contextController,
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'Regras de Negócio',
                      hintText: 'Ex: 1. Sempre peça o ID da máquina.\n2. Priorize panes severas...',
                      controller: _businessRulesController,
                      icon: Icons.rule,
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'Tom de Voz',
                      hintText: 'Ex: Amigável, técnico, claro e sem gírias...',
                      controller: _toneOfVoiceController,
                      icon: Icons.record_voice_over_outlined,
                    ),
                    const SizedBox(height: 12),
                    PromptEditorField(
                      label: 'O que Evitar',
                      hintText: 'Ex: 1. Não prometa prazos de entrega finais.\n2. Evite jargões excessivos...',
                      controller: _avoidRulesController,
                      icon: Icons.block_outlined,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.merge_type, size: 16),
                          label: const Text('Consolidar Prompt', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dark ? Colors.grey[800] : Colors.grey[300],
                            foregroundColor: dark ? Colors.white : Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _consolidatePrompt,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: _isImproving 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Melhorar com IA', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isImproving ? null : _improvePromptWithAi,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Área Final / Preview
                    PromptEditorField(
                      label: 'Prompt do Sistema Final (Enviado para a NVIDIA)',
                      hintText: 'Consolide os campos ou edite este prompt manualmente.',
                      controller: _systemPromptController,
                      maxLines: 8,
                      icon: Icons.terminal,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Barra de Botões
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: dark ? Colors.grey[950] : Colors.grey[100],
                border: Border(top: BorderSide(color: dark ? Colors.grey[800]! : Colors.grey[300]!, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveAssistant,
                    child: const Text('Salvar Assistente'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
