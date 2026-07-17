import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/supabase_config.dart';

class NvidiaApiKeyService {
  static final NvidiaApiKeyService _instance = NvidiaApiKeyService._internal();
  factory NvidiaApiKeyService() => _instance;
  NvidiaApiKeyService._internal();

  final _secureStorage = const FlutterSecureStorage();
  static const String _storageKey = 'nvidia_api_key';

  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Obtém a chave de API da NVIDIA seguindo a prioridade estabelecida:
  /// 1. Variável de ambiente (String.fromEnvironment)
  /// 2. Banco de dados do Supabase (tabela ai_configs)
  /// 3. Armazenamento seguro local (FlutterSecureStorage) - Fallback resiliente
  Future<String> getApiKey() async {
    // 1. Variável de ambiente
    const envKey = String.fromEnvironment('NVIDIA_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }

    // 2. Banco de dados do Supabase
    try {
      final data = await _supabase
          .from('ai_configs')
          .select('value')
          .eq('key', 'nvidia_api_key')
          .maybeSingle();
      if (data != null && data['value'] != null) {
        final val = data['value'] as String;
        if (val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (e) {
      // Ignora erro se a tabela não existir ou falhar a conexão, caindo no fallback local
      print('⚠️ Erro ao ler chave do Supabase: $e');
    }

    // 3. Armazenamento seguro local (Fallback)
    try {
      final secureKey = await _secureStorage.read(key: _storageKey);
      if (secureKey != null && secureKey.trim().isNotEmpty) {
        return secureKey;
      }
    } catch (_) {
      // Ignora erro de leitura segura e retorna vazio
    }

    return '';
  }

  /// Salva a chave de API no Supabase e no secure storage local
  Future<void> saveApiKey(String key) async {
    final cleanKey = key.trim();

    // 1. Tenta salvar no Supabase
    try {
      await _supabase.from('ai_configs').upsert({
        'key': 'nvidia_api_key',
        'value': cleanKey,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Erro ao salvar chave no Supabase: $e');
      // Tenta salvar localmente no secure storage como fallback para não perder
      try {
        await _secureStorage.write(key: _storageKey, value: cleanKey);
      } catch (_) {}
      rethrow;
    }

    // 2. Salva localmente no secure storage para redundância/cache
    try {
      await _secureStorage.write(key: _storageKey, value: cleanKey);
    } catch (_) {}
  }

  /// Remove a chave de API do Supabase e do secure storage local
  Future<void> deleteApiKey() async {
    // 1. Remove do Supabase
    try {
      await _supabase.from('ai_configs').delete().eq('key', 'nvidia_api_key');
    } catch (e) {
      print('⚠️ Erro ao deletar chave no Supabase: $e');
    }

    // 2. Remove localmente
    await _secureStorage.delete(key: _storageKey);
  }

  /// Verifica se há alguma chave de API configurada
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }

  /// Retorna a chave mascarada para exibição segura na interface (ex. nvapi-***...4A2)
  Future<String> getMaskedApiKey() async {
    final key = await getApiKey();
    if (key.isEmpty) return '';

    if (key.length <= 10) {
      return 'nvapi-****';
    }

    final prefix = key.substring(0, 6);
    final suffix = key.substring(key.length - 4);
    return '$prefix-***...$suffix';
  }

  /// Verifica se a chave é de ambiente
  bool isEnvApiKey() {
    const envKey = String.fromEnvironment('NVIDIA_API_KEY');
    return envKey.isNotEmpty;
  }
}
