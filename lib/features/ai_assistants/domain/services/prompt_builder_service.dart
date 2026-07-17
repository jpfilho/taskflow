class PromptBuilderService {
  /// Gera o prompt do sistema consolidado com base nos campos individuais do assistente.
  static String buildSystemPrompt({
    required String role,
    required String objective,
    required String context,
    required String businessRules,
    required String avoidRules,
    required String toneOfVoice,
  }) {
    final buffer = StringBuffer();

    if (role.trim().isNotEmpty) {
      buffer.writeln('# PAPEL DO ASSISTENTE');
      buffer.writeln(role.trim());
      buffer.writeln();
    }

    if (objective.trim().isNotEmpty) {
      buffer.writeln('# OBJETIVO');
      buffer.writeln(objective.trim());
      buffer.writeln();
    }

    if (context.trim().isNotEmpty) {
      buffer.writeln('# CONTEXTO');
      buffer.writeln(context.trim());
      buffer.writeln();
    }

    if (businessRules.trim().isNotEmpty) {
      buffer.writeln('# REGRAS DE NEGÓCIO');
      buffer.writeln(businessRules.trim());
      buffer.writeln();
    }

    if (toneOfVoice.trim().isNotEmpty) {
      buffer.writeln('# TOM DE VOZ');
      buffer.writeln(toneOfVoice.trim());
      buffer.writeln();
    }

    if (avoidRules.trim().isNotEmpty) {
      buffer.writeln('# O QUE EVITAR');
      buffer.writeln(avoidRules.trim());
      buffer.writeln();
    }

    buffer.writeln('# FORMATO DE RESPOSTA');
    buffer.writeln('Responda de forma clara, objetiva e acionável.');
    buffer.writeln('Quando houver incerteza, informe a limitação.');
    buffer.writeln('Não invente dados.');
    buffer.writeln('Quando necessário, peça dados adicionais.');
    buffer.writeln();
    buffer.writeln('# SUPORTE A GRÁFICOS INTERATIVOS');
    buffer.writeln('Você possui capacidade de renderizar gráficos interativos e visuais de alta qualidade diretamente na tela do usuário.');
    buffer.writeln('Sempre que o usuário solicitar um gráfico, ou quando for extremamente benéfico para resumir informações numéricas quantitativas (como volume de tarefas por status, prioridades de notas SAP, ordens por tipo, etc.), insira um bloco de código com a tag ` ```chart ` contendo um objeto JSON estruturado da seguinte forma:');
    buffer.writeln('```json');
    buffer.writeln('{');
    buffer.writeln('  "type": "bar" | "pie" | "line",');
    buffer.writeln('  "title": "Título explicativo do gráfico",');
    buffer.writeln('  "data": [');
    buffer.writeln('    {"label": "Nome da Categoria", "value": 15},');
    buffer.writeln('    {"label": "Outra Categoria", "value": 8}');
    buffer.writeln('  ]');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln('Use tipo "bar" ou "pie" para categorias (como locais, status, prioridades) e "line" para dados ordenados no tempo.');
    buffer.writeln('Não inclua textos explicativos dentro do bloco json do gráfico. Escreva o texto normal fora do bloco.');

    return buffer.toString().trim();
  }
}
