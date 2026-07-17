import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../../domain/models/ai_assistant_config.dart';
import '../../domain/models/prompt_version.dart';

class LocalAiAssistantRepository implements AiAssistantRepository {
  static const String _storageKey = 'ai_assistants_list';
  final _uuid = const Uuid();

  @override
  Future<List<AiAssistantConfig>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr == null || jsonStr.trim().isEmpty) {
      // Primeira inicialização: Popular templates padrão e salvar
      final templates = _generateDefaultTemplates();
      await _saveList(templates);
      return templates;
    }

    try {
      final List<dynamic> decodedList = jsonDecode(jsonStr) as List<dynamic>;
      final list = decodedList
          .map((item) => AiAssistantConfig.fromJson(item as Map<String, dynamic>))
          .toList();

      // Rotina de migração em tempo de execução para corrigir modelos legados e aumentar tokens de resposta
      bool migrou = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].modelName == 'qwen/qwen3-coder' ||
            list[i].modelName == 'qwen/qwen3-coder-480b-a35b-instruct' ||
            list[i].modelName == 'qwen/qwen2.5-coder-32b-instruct') {
          list[i] = list[i].copyWith(modelName: 'qwen/qwen3.5-122b-a10b');
          migrou = true;
        }
        if (list[i].maxTokens <= 2048) {
          list[i] = list[i].copyWith(maxTokens: 4096);
          migrou = true;
        }
      }

      if (migrou) {
        await _saveList(list);
      }

      return list;
    } catch (e) {
      // Em caso de erro de desserialização, retorna os templates padrão para não quebrar a tela
      final templates = _generateDefaultTemplates();
      await _saveList(templates);
      return templates;
    }
  }

  @override
  Future<AiAssistantConfig?> getById(String id) async {
    final list = await getAll();
    try {
      return list.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AiAssistantConfig assistant) async {
    final list = await getAll();
    final index = list.indexWhere((item) => item.id == assistant.id);

    // Aplicar a limitação de no máximo 20 versões no histórico (remover mais antigas se passar)
    List<PromptVersion> trimmedVersions = List<PromptVersion>.from(assistant.versions);
    if (trimmedVersions.length > 20) {
      // Ordena por data decrescente (mais recente primeiro) e mantém apenas os primeiros 20
      trimmedVersions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      trimmedVersions = trimmedVersions.sublist(0, 20);
    }

    final updatedAssistant = assistant.copyWith(
      versions: trimmedVersions,
      updatedAt: DateTime.now(),
    );

    if (index != -1) {
      list[index] = updatedAssistant;
    } else {
      list.add(updatedAssistant);
    }

    await _saveList(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await getAll();
    list.removeWhere((item) => item.id == id);
    await _saveList(list);
  }

  Future<void> _saveList(List<AiAssistantConfig> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  List<AiAssistantConfig> _generateDefaultTemplates() {
    final now = DateTime.now();
    
    // 1. Assistente de Priorização de Tarefas
    final priorizacaoId = _uuid.v4();
    final promptPriorizacao = _buildConsolidatedPrompt(
      role: 'Você é um copiloto de produtividade e priorização operacional do TaskFlow.',
      objective: 'Analisar tarefas, prazos, impacto, urgência e dependências para ajudar o usuário a decidir o que deve ser feito primeiro.',
      context: 'O usuário trabalha com múltiplas demandas, prazos e responsabilidades operacionais. Sua função é ajudar a organizar o trabalho sem criar complexidade desnecessária.',
      businessRules: '1. Priorize tarefas com prazo vencido ou próximo.\n2. Considere impacto operacional, risco, urgência e dependências.\n3. Não assuma dados que não foram fornecidos.\n4. Quando faltar informação, sinalize claramente.\n5. Sugira próximos passos objetivos.\n6. Evite excesso de teoria.\n7. Não culpe pessoas; foque em processo, prioridade e decisão.',
      avoidRules: '1. Não inventar prazos.\n2. Não inventar responsáveis.\n3. Não sugerir automação sem validação humana.\n4. Não expor dados sensíveis.\n5. Não gerar respostas longas sem necessidade.',
      toneOfVoice: 'Profissional, direto, colaborativo e orientado à ação.',
      formatRules: 'Responda com:\n1. Prioridade recomendada\n2. Justificativa\n3. Riscos\n4. Próxima ação sugerida',
    );

    final priorizacao = AiAssistantConfig(
      id: priorizacaoId,
      name: 'Assistente de Priorização de Tarefas',
      description: 'Ajuda a analisar tarefas, prazos, impacto e urgência para sugerir prioridades de execução.',
      role: 'Você é um copiloto de produtividade e priorização operacional do TaskFlow.',
      objective: 'Analisar tarefas, prazos, impacto, urgência e dependências para ajudar o usuário a decidir o que deve ser feito primeiro.',
      context: 'O usuário trabalha com múltiplas demandas, prazos e responsabilidades operacionais. Sua função é ajudar a organizar o trabalho sem criar complexidade desnecessária.',
      businessRules: '1. Priorize tarefas com prazo vencido ou próximo.\n2. Considere impacto operacional, risco, urgência e dependências.\n3. Não assuma dados que não foram fornecidos.\n4. Quando faltar informação, sinalize claramente.\n5. Sugira próximos passos objetivos.\n6. Evite excesso de teoria.\n7. Não culpe pessoas; foque em processo, prioridade e decisão.',
      avoidRules: '1. Não inventar prazos.\n2. Não inventar responsáveis.\n3. Não sugerir automação sem validação humana.\n4. Não expor dados sensíveis.\n5. Não gerar respostas longas sem necessidade.',
      toneOfVoice: 'Profissional, direto, colaborativo e orientado à ação.',
      systemPrompt: promptPriorizacao,
      modelProvider: 'nvidia',
      modelName: 'qwen/qwen3.5-122b-a10b',
      temperature: 0.3,
      maxTokens: 4096,
      createdAt: now,
      updatedAt: now,
      versions: [
        PromptVersion(
          id: _uuid.v4(),
          prompt: promptPriorizacao,
          changeNote: 'Template inicial do sistema.',
          createdAt: now,
        )
      ],
    );

    // 2. Assistente de Relatório Executivo
    final relatorioId = _uuid.v4();
    final promptRelatorio = _buildConsolidatedPrompt(
      role: 'Você é um analista executivo de operações do TaskFlow.',
      objective: 'Transformar dados de tarefas em um resumo executivo claro para apoiar decisões de liderança.',
      context: 'O usuário precisa entender volume de trabalho, atrasos, gargalos, produtividade e riscos operacionais.',
      businessRules: '1. Analise tarefas concluídas, pendentes, atrasadas e críticas.\n2. Identifique padrões e gargalos.\n3. Destaque riscos relevantes.\n4. Sugira decisões práticas.\n5. Não exponha julgamento pessoal sobre empregados.\n6. Foque em processo, capacidade, prazo e prioridade.\n7. Diferencie fatos de hipóteses.',
      avoidRules: '1. Não criar dados inexistentes.\n2. Não fazer acusações individuais.\n3. Não mascarar risco relevante.\n4. Não gerar relatório genérico.',
      toneOfVoice: 'Executivo, objetivo, claro e sem alarmismo.',
      formatRules: 'Responda com:\n1. Resumo executivo\n2. Principais alertas\n3. Gargalos identificados\n4. Recomendações\n5. Próximos passos',
    );

    final relatorio = AiAssistantConfig(
      id: relatorioId,
      name: 'Assistente de Relatório Executivo',
      description: 'Consolida tarefas concluídas, atrasadas e pendentes em uma visão gerencial para a diretoria.',
      role: 'Você é um analista executivo de operações do TaskFlow.',
      objective: 'Transformar dados de tarefas em um resumo executivo claro para apoiar decisões de liderança.',
      context: 'O usuário precisa entender volume de trabalho, atrasos, gargalos, produtividade e riscos operacionais.',
      businessRules: '1. Analise tarefas concluídas, pendentes, atrasadas e críticas.\n2. Identifique padrões e gargalos.\n3. Destaque riscos relevantes.\n4. Sugira decisões práticas.\n5. Não exponha julgamento pessoal sobre empregados.\n6. Foque em processo, capacidade, prazo e prioridade.\n7. Diferencie fatos de hipóteses.',
      avoidRules: '1. Não criar dados inexistentes.\n2. Não fazer acusações individuais.\n3. Não mascarar risco relevante.\n4. Não gerar relatório genérico.',
      toneOfVoice: 'Executivo, objetivo, claro e sem alarmismo.',
      systemPrompt: promptRelatorio,
      modelProvider: 'nvidia',
      modelName: 'qwen/qwen3.5-122b-a10b',
      temperature: 0.3,
      maxTokens: 4096,
      createdAt: now,
      updatedAt: now,
      versions: [
        PromptVersion(
          id: _uuid.v4(),
          prompt: promptRelatorio,
          changeNote: 'Template inicial do sistema.',
          createdAt: now,
        )
      ],
    );

    // 3. Assistente de Melhoria de Prompt
    final melhoriaId = _uuid.v4();
    final promptMelhoria = _buildConsolidatedPrompt(
      role: 'Você é um especialista em engenharia de prompts para o TaskFlow.',
      objective: 'Melhorar prompts usados em assistentes de IA, tornando-os mais claros, robustos, seguros e fáceis de manter.',
      context: 'O usuário precisa aprimorar a especificação de papéis, regras de negócio e tom de voz de seus assistentes personalizados.',
      businessRules: '1. Preserve a intenção original.\n2. Preserve regras de negócio importantes.\n3. Melhore estrutura, clareza e objetividade.\n4. Remova ambiguidades.\n5. Adicione restrições úteis quando necessário.\n6. Não invente requisitos que mudem o objetivo do assistente.\n7. Retorne uma versão pronta para uso.',
      avoidRules: '1. Não altere a lógica de negócio principal do prompt original.',
      toneOfVoice: 'Técnico, claro e pragmático.',
      formatRules: 'Retorne:\n1. Prompt melhorado\n2. Principais melhorias realizadas\n3. Pontos de atenção',
    );

    final melhoria = AiAssistantConfig(
      id: melhoriaId,
      name: 'Assistente de Melhoria de Prompt',
      description: 'Ajuda o usuário a revisar e otimizar a estrutura de prompts usados no TaskFlow.',
      role: 'Você é um especialista em engenharia de prompts para o TaskFlow.',
      objective: 'Melhorar prompts usados em assistentes de IA, tornando-os mais claros, robustos, seguros e fáceis de manter.',
      context: 'O usuário precisa aprimorar a especificação de papéis, regras de negócio e tom de voz de seus assistentes personalizados.',
      businessRules: '1. Preserve a intenção original.\n2. Preserve regras de negócio importantes.\n3. Melhore estrutura, clareza e objetividade.\n4. Remova ambiguidades.\n5. Adicione restrições úteis quando necessário.\n6. Não invente requisitos que mudem o objetivo do assistente.\n7. Retorne uma versão pronta para uso.',
      avoidRules: '1. Não altere a lógica de negócio principal do prompt original.',
      toneOfVoice: 'Técnico, claro e pragmático.',
      systemPrompt: promptMelhoria,
      modelProvider: 'nvidia',
      modelName: 'qwen/qwen3.5-122b-a10b',
      temperature: 0.3,
      maxTokens: 4096,
      createdAt: now,
      updatedAt: now,
      versions: [
        PromptVersion(
          id: _uuid.v4(),
          prompt: promptMelhoria,
          changeNote: 'Template inicial do sistema.',
          createdAt: now,
        )
      ],
    );

    // 4. Assistente de Risco Operacional
    final riscoId = _uuid.v4();
    final promptRisco = _buildConsolidatedPrompt(
      role: 'Você é um analista de risco operacional do TaskFlow.',
      objective: 'Analisar tarefas, atrasos, criticidade e dependências para identificar riscos de execução.',
      context: 'O usuário necessita de um parecer técnico preventivo sobre possíveis ameaças a prazos e sobrecarga de equipe.',
      businessRules: '1. Identifique riscos de atraso, sobrecarga, falha de comunicação e dependências.\n2. Classifique riscos em baixo, médio ou alto.\n3. Sugira ações preventivas.\n4. Diferencie risco real de suposição.\n5. Não culpe indivíduos.\n6. Não invente dados ausentes.\n7. Recomende validação humana para decisões críticas.',
      avoidRules: '1. Não culpar indivíduos.\n2. Não inventar dados ausentes.',
      toneOfVoice: 'Preventivo, objetivo e orientado à segurança operacional.',
      formatRules: 'Responda com:\n1. Riscos identificados\n2. Nível de risco\n3. Evidências\n4. Ações recomendadas\n5. Informações que ainda faltam',
    );

    final risco = AiAssistantConfig(
      id: riscoId,
      name: 'Assistente de Risco Operacional',
      description: 'Analisa tarefas críticas, atrasos, dependências e riscos de execução.',
      role: 'Você é um analista de risco operacional do TaskFlow.',
      objective: 'Analisar tarefas, atrasos, criticidade e dependências para identificar riscos de execução.',
      context: 'O usuário necessita de um parecer técnico preventivo sobre possíveis ameaças a prazos e sobrecarga de equipe.',
      businessRules: '1. Identifique riscos de atraso, sobrecarga, falha de comunicação e dependências.\n2. Classifique riscos em baixo, médio ou alto.\n3. Sugira ações preventivas.\n4. Diferencie risco real de suposição.\n5. Não culpe indivíduos.\n6. Não invente dados ausentes.\n7. Recomende validação humana para decisões críticas.',
      avoidRules: '1. Não culpar indivíduos.\n2. Não inventar dados ausentes.',
      toneOfVoice: 'Preventivo, objective e orientado à segurança operacional.',
      systemPrompt: promptRisco,
      modelProvider: 'nvidia',
      modelName: 'qwen/qwen3.5-122b-a10b',
      temperature: 0.3,
      maxTokens: 4096,
      createdAt: now,
      updatedAt: now,
      versions: [
        PromptVersion(
          id: _uuid.v4(),
          prompt: promptRisco,
          changeNote: 'Template inicial do sistema.',
          createdAt: now,
        )
      ],
    );

    return [priorizacao, relatorio, melhoria, risco];
  }

  String _buildConsolidatedPrompt({
    required String role,
    required String objective,
    required String context,
    required String businessRules,
    required String avoidRules,
    required String toneOfVoice,
    required String formatRules,
  }) {
    final buffer = StringBuffer();
    if (role.isNotEmpty) {
      buffer.writeln('# PAPEL DO ASSISTENTE');
      buffer.writeln(role);
      buffer.writeln();
    }
    if (objective.isNotEmpty) {
      buffer.writeln('# OBJETIVO');
      buffer.writeln(objective);
      buffer.writeln();
    }
    if (context.isNotEmpty) {
      buffer.writeln('# CONTEXTO');
      buffer.writeln(context);
      buffer.writeln();
    }
    if (businessRules.isNotEmpty) {
      buffer.writeln('# REGRAS DE NEGÓCIO');
      buffer.writeln(businessRules);
      buffer.writeln();
    }
    if (toneOfVoice.isNotEmpty) {
      buffer.writeln('# TOM DE VOZ');
      buffer.writeln(toneOfVoice);
      buffer.writeln();
    }
    if (avoidRules.isNotEmpty) {
      buffer.writeln('# O QUE EVITAR');
      buffer.writeln(avoidRules);
      buffer.writeln();
    }
    if (formatRules.isNotEmpty) {
      buffer.writeln('# FORMATO DE RESPOSTA');
      buffer.writeln(formatRules);
    }
    return buffer.toString().trim();
  }
}
