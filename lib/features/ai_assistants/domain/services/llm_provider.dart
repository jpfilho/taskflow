abstract class LlmProvider {
  Future<String> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required String modelName,
    double temperature,
    int maxTokens,
    List<Map<String, String>>? history,
  });

  Stream<String> generateResponseStream({
    required String systemPrompt,
    required String userPrompt,
    required String modelName,
    double temperature,
    int maxTokens,
    List<Map<String, String>>? history,
  });
}
