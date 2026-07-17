class LlmModelConfig {
  final String provider;
  final String name;
  final String label;
  final String description;
  final bool enabled;

  const LlmModelConfig({
    required this.provider,
    required this.name,
    required this.label,
    required this.description,
    required this.enabled,
  });
}

const List<LlmModelConfig> availableNvidiaModels = [
  LlmModelConfig(
    provider: 'nvidia',
    name: 'qwen/qwen3.5-122b-a10b',
    label: 'Qwen 3.5 (122B MoE)',
    description: 'Modelo multimodal de última geração otimizado para raciocínio complexo, lógica e código.',
    enabled: true,
  ),
  LlmModelConfig(
    provider: 'nvidia',
    name: 'qwen/qwen3-next-80b-a3b-instruct',
    label: 'Qwen 3 Next (80B MoE)',
    description: 'Modelo de contexto longo e alta velocidade para processamento de regras e prompts.',
    enabled: true,
  ),
  LlmModelConfig(
    provider: 'nvidia',
    name: 'nvidia/llama-3.1-nemotron-51b-instruct',
    label: 'Llama 3.1 Nemotron 51B',
    description: 'Modelo otimizado pela NVIDIA para respostas estruturadas e conversação fluida.',
    enabled: true,
  ),
  LlmModelConfig(
    provider: 'nvidia',
    name: 'deepseek-ai/deepseek-coder-6.7b-instruct',
    label: 'DeepSeek Coder 6.7B',
    description: 'Modelo de código aberto altamente qualificado para codificação e lógica de programação.',
    enabled: true,
  ),
];
