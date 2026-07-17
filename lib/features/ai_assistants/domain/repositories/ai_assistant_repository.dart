import '../models/ai_assistant_config.dart';

abstract class AiAssistantRepository {
  Future<List<AiAssistantConfig>> getAll();
  Future<AiAssistantConfig?> getById(String id);
  Future<void> save(AiAssistantConfig assistant);
  Future<void> delete(String id);
}
