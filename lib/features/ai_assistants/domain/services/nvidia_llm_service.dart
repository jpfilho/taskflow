import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';
import '../../data/services/nvidia_api_key_service.dart';

class NvidiaLlmService implements LlmProvider {
  final _apiKeyService = NvidiaApiKeyService();

  @override
  Future<String> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required String modelName,
    double temperature = 0.3,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async {
    final apiKey = await _apiKeyService.getApiKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Chave da API NVIDIA não configurada. Configure a chave antes de testar o assistente.'
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            if (history != null) ...history,
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody.containsKey('error')) {
            final error = errBody['error'];
            final errorMsg = error is Map ? error['message'] : error.toString();
            throw Exception('Erro NVIDIA ($errorMsg)');
          }
        } catch (_) {}
        throw Exception('Erro na requisição NVIDIA: Status ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final error = data['error'];
          final errorMsg = error is Map ? error['message'] : error.toString();
          throw Exception(errorMsg);
        }

        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map<String, dynamic>;
          final message = firstChoice['message'] as Map<String, dynamic>;
          return (message['content'] as String? ?? '').trim();
        }
      }
      throw Exception('Resposta inválida recebida da API NVIDIA.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('A requisição para o Assistente expirou (Timeout). Tente novamente.');
      }
      rethrow;
    }
  }

  @override
  Stream<String> generateResponseStream({
    required String systemPrompt,
    required String userPrompt,
    required String modelName,
    double temperature = 0.3,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async* {
    final apiKey = await _apiKeyService.getApiKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Chave da API NVIDIA não configurada. Configure a chave antes de testar o assistente.'
      );
    }

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
      );
      
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      
      request.body = jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          if (history != null) ...history,
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 120));

      if (streamedResponse.statusCode != 200) {
        throw Exception('Erro na requisição NVIDIA: Status ${streamedResponse.statusCode}');
      }

      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') {
            break;
          }
          
          try {
            final decoded = jsonDecode(dataStr);
            final choices = decoded['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('A requisição para o Assistente expirou (Timeout). Tente novamente.');
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
