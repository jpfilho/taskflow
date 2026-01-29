import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'auth_service_simples.dart';

/// Serviço para integração com Telegram
/// Gerencia vinculação de identidade e subscriptions
class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final AuthServiceSimples _authService = AuthServiceSimples();

  // ========== IDENTIDADE TELEGRAM ==========

  /// Verifica se o usuário atual tem conta Telegram vinculada
  Future<bool> isLinked() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('telegram_identities')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Erro ao verificar vinculação Telegram: $e');
      return false;
    }
  }

  /// Obtém a identidade Telegram do usuário atual
  Future<TelegramIdentity?> getIdentity() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('telegram_identities')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return TelegramIdentity.fromMap(response);
    } catch (e) {
      print('Erro ao obter identidade Telegram: $e');
      return null;
    }
  }

  /// Gera um deep link para vincular conta Telegram
  /// O usuário deve abrir este link no Telegram
  String generateLinkUrl() {
    final userId = _authService.currentUser?.id ?? 'unknown';
    // Username real do bot
    const botUsername = 'TaskFlow_chat_bot';
    
    // Payload codifica o user_id para o bot identificar quem está vinculando
    final payload = 'link_$userId';
    
    return 'https://t.me/$botUsername?start=$payload';
  }

  /// Desvincular conta Telegram
  Future<void> unlink() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      await _supabase
          .from('telegram_identities')
          .delete()
          .eq('user_id', userId);

      print('✅ Conta Telegram desvinculada');
    } catch (e) {
      throw Exception('Erro ao desvincular Telegram: $e');
    }
  }

  // ========== SUBSCRIPTIONS ==========

  /// Verifica se um thread (comunidade ou tarefa) tem subscription ativa
  Future<bool> hasSubscription(String threadType, String threadId) async {
    try {
      print('🔍 [Telegram] Verificando subscription: threadType=$threadType, threadId=$threadId');
      
      // Usar .select() ao invés de .maybeSingle() para lidar com múltiplas subscriptions
      final response = await _supabase
          .from('telegram_subscriptions')
          .select('id')
          .eq('thread_type', threadType)
          .eq('thread_id', threadId)
          .eq('active', true);

      print('🔍 [Telegram] Resposta da query: $response');
      final hasSub = response != null && (response as List).isNotEmpty;
      print('🔍 [Telegram] Subscription encontrada: $hasSub (${(response as List).length} subscriptions)');
      
      return hasSub;
    } catch (e, stackTrace) {
      print('❌ [Telegram] Erro ao verificar subscription: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Lista subscriptions de um thread
  Future<List<TelegramSubscription>> getSubscriptions(
    String threadType,
    String threadId,
  ) async {
    try {
      final response = await _supabase
          .from('telegram_subscriptions')
          .select('*')
          .eq('thread_type', threadType)
          .eq('thread_id', threadId)
          .eq('active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((map) => TelegramSubscription.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao listar subscriptions: $e');
      return [];
    }
  }

  /// Criar uma nova subscription
  Future<TelegramSubscription> createSubscription({
    required String threadType,
    required String threadId,
    required String mode,
    required int telegramChatId,
    int? telegramTopicId,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      final data = {
        'thread_type': threadType,
        'thread_id': threadId,
        'mode': mode,
        'telegram_chat_id': telegramChatId,
        'telegram_topic_id': telegramTopicId,
        'created_by': userId,
        'active': true,
        'settings': settings ?? {
          'send_notifications': true,
          'send_attachments': true,
          'send_locations': true,
          'bi_directional': true,
        },
      };

      final response = await _supabase
          .from('telegram_subscriptions')
          .insert(data)
          .select()
          .single();

      print('✅ Subscription criada: ${response['id']}');
      return TelegramSubscription.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao criar subscription: $e');
    }
  }

  /// Atualizar configurações de uma subscription
  Future<void> updateSubscription(
    String subscriptionId, {
    bool? active,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (active != null) data['active'] = active;
      if (settings != null) data['settings'] = settings;
      data['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('telegram_subscriptions')
          .update(data)
          .eq('id', subscriptionId);

      print('✅ Subscription atualizada: $subscriptionId');
    } catch (e) {
      throw Exception('Erro ao atualizar subscription: $e');
    }
  }

  /// Desativar (soft delete) uma subscription
  Future<void> deleteSubscription(String subscriptionId) async {
    try {
      await _supabase
          .from('telegram_subscriptions')
          .update({'active': false})
          .eq('id', subscriptionId);

      print('✅ Subscription desativada: $subscriptionId');
    } catch (e) {
      throw Exception('Erro ao desativar subscription: $e');
    }
  }

  // ========== ENVIO DE MENSAGENS ==========

  /// Envia uma mensagem para o Telegram via HTTP endpoint
  /// Com retry automático em caso de timeout ou erro de rede
  /// Usa fallback para IP direto se DNS falhar
  Future<void> sendMessageToTelegram({
    required String mensagemId,
    String? threadType,
    String? threadId,
    int maxRetries = 2,
    // Campos para tags Nota/Ordem
    String? refType,  // 'GERAL' | 'NOTA' | 'ORDEM'
    String? refId,    // UUID da nota_sap ou ordem
    String? refLabel, // Label para exibição (ex: "NOTA 12345")
  }) async {
    // Tentar primeiro com domínio, depois com IP direto se falhar
    const telegramServerUrl = 'https://api.taskflowv3.com.br';
    const telegramServerUrlFallback = 'https://212.85.0.249'; // IP direto como fallback
    final url = Uri.parse('$telegramServerUrl/send-message');
    
    final payload = {
      'mensagem_id': mensagemId,
      'thread_type': threadType ?? 'TASK',
      'thread_id': threadId,
    };
    
    // Adicionar tags se fornecidas
    if (refType != null) {
      payload['ref_type'] = refType;
      if (refId != null) {
        payload['ref_id'] = refId;
      }
      if (refLabel != null) {
        payload['ref_label'] = refLabel;
      }
    }
    
    final body = jsonEncode(payload);
    
    int attempt = 0;
    final totalAttempts = maxRetries + 1; // Total de tentativas (inicial + retries)
    while (attempt <= maxRetries) {
      try {
        attempt++;
        if (attempt > 1) {
          print('🔄 [Telegram] Tentativa $attempt de $totalAttempts para mensagem $mensagemId');
          // Aguardar antes de retry (backoff exponencial)
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          print('📡 [Telegram] Chamando endpoint: $url');
          print('📡 [Telegram] Body: $body');
        }
        
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(
          const Duration(seconds: 30), // Aumentado de 10s para 30s
          onTimeout: () {
            throw TimeoutException('Timeout ao chamar endpoint /send-message após 30s');
          },
        );

        print('📡 [Telegram] Status code: ${response.statusCode}');
        print('📡 [Telegram] Resposta: ${response.body}');

        if (response.statusCode != 200) {
          print('⚠️ [Telegram] Erro HTTP ${response.statusCode} ao enviar mensagem: $mensagemId');
          print('   Resposta: ${response.body}');
          
          // Se for erro 5xx (servidor), tentar novamente
          if (response.statusCode >= 500 && attempt <= maxRetries) {
            print('🔄 [Telegram] Erro do servidor, tentando novamente...');
            continue;
          }
          return; // Erro 4xx não deve ser retentado
        }
        
        // Sucesso - processar resposta
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['sent'] == true || data['ok'] == true) {
            print('✅ [Telegram] Mensagem enviada para Telegram: $mensagemId');
            return; // Sucesso, sair do loop
          } else {
            print('⚠️ [Telegram] Mensagem não enviada (sent: false): $mensagemId');
            print('   Resposta completa: ${response.body}');
            // Se não foi enviada mas não é erro, não retentar
            return;
          }
        } catch (e) {
          print('⚠️ [Telegram] Erro ao parsear resposta JSON: $e');
          print('   Resposta: ${response.body}');
          // Se não conseguiu parsear mas status é 200, considerar sucesso
          if (response.statusCode == 200) {
            print('✅ [Telegram] Resposta 200 OK (mesmo com erro de parse)');
            return;
          }
        }
      } on TimeoutException catch (e) {
        print('⏱️ [Telegram] Timeout na tentativa $attempt/$totalAttempts: $e');
        if (attempt <= maxRetries) {
          print('🔄 [Telegram] Tentando novamente após timeout...');
          continue;
        } else {
          print('❌ [Telegram] Timeout após $totalAttempts tentativas para mensagem $mensagemId');
          return; // Não propagar erro para não afetar chat
        }
      } on http.ClientException catch (e) {
        print('🌐 [Telegram] Erro de rede na tentativa $attempt/$totalAttempts: $e');
        // Verificar se é erro de DNS ou SSL
        final errorStr = e.toString().toLowerCase();
        final isDnsError = errorStr.contains('failed to fetch') || 
                          errorStr.contains('err_name_not_resolved') ||
                          errorStr.contains('name not resolved') ||
                          errorStr.contains('network is unreachable');
        final isSslError = errorStr.contains('err_cert') ||
                          errorStr.contains('certificate') ||
                          errorStr.contains('ssl') ||
                          errorStr.contains('tls');
        
        if ((isDnsError || isSslError) && attempt == 1) {
          // Na primeira tentativa com erro de DNS ou SSL, tentar com IP direto via HTTP
          // (certificado SSL não funciona para IP direto)
          print('🔍 [Telegram] Erro de DNS/SSL detectado. Tentando com IP direto via HTTP como fallback...');
          // Usar HTTP na porta 3001 (Node.js direto) ao invés de HTTPS via Nginx
          final urlFallback = Uri.parse('http://212.85.0.249:3001/send-message');
          try {
            print('📡 [Telegram] Tentando endpoint via IP (HTTP porta 3001): $urlFallback');
            final responseFallback = await http.post(
              urlFallback,
              headers: {'Content-Type': 'application/json'},
              body: body,
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Timeout ao chamar endpoint /send-message via IP após 30s');
              },
            );
            
            print('📡 [Telegram] Status code (via IP HTTP): ${responseFallback.statusCode}');
            if (responseFallback.statusCode == 200) {
              try {
                final data = jsonDecode(responseFallback.body) as Map<String, dynamic>;
                if (data['sent'] == true || data['ok'] == true) {
                  print('✅ [Telegram] Mensagem enviada via IP direto (HTTP): $mensagemId');
                  return; // Sucesso com IP direto
                }
              } catch (_) {
                // Se status é 200, considerar sucesso
                print('✅ [Telegram] Resposta 200 OK via IP direto (HTTP)');
                return;
              }
            }
          } catch (e2) {
            print('⚠️ [Telegram] Fallback para IP (HTTP) também falhou: $e2');
            print('   💡 Verifique se a porta 3001 está acessível e o Node.js está rodando');
            // Continuar com retry normal
          }
        }
        
        if (attempt <= maxRetries) {
          print('🔄 [Telegram] Tentando novamente após erro de rede...');
          continue;
        } else {
          print('❌ [Telegram] Erro de rede após $totalAttempts tentativas para mensagem $mensagemId');
          print('   Possíveis causas:');
          print('   - DNS não resolve (api.taskflowv3.com.br)');
          print('   - Certificado SSL inválido para IP direto');
          print('   - Servidor Node.js offline ou porta 3001 bloqueada');
          print('   - Problema de conectividade de rede');
          print('   💡 Verifique:');
          print('   1. DNS: nslookup api.taskflowv3.com.br');
          print('   2. Servidor: ssh root@212.85.0.249 "systemctl status telegram-webhook"');
          print('   3. Porta 3001: ssh root@212.85.0.249 "netstat -tlnp | grep 3001"');
          return; // Não propagar erro
        }
      } catch (e, stackTrace) {
        print('❌ [Telegram] Erro inesperado na tentativa $attempt/$totalAttempts: $e');
        print('   Stack trace: $stackTrace');
        if (attempt <= maxRetries) {
          print('🔄 [Telegram] Tentando novamente...');
          continue;
        } else {
          print('❌ [Telegram] Erro após $totalAttempts tentativas para mensagem $mensagemId');
          return; // Não propagar erro para não afetar envio da mensagem no app
        }
      }
    }
  }

  /// Deleta uma mensagem do Telegram quando excluída no Flutter
  Future<void> deleteMessageFromTelegram(String mensagemId) async {
    try {
      const telegramServerUrl = 'https://api.taskflowv3.com.br';
      
      final url = Uri.parse('$telegramServerUrl/delete-message');
      final body = jsonEncode({
        'mensagem_id': mensagemId,
      });
      
      print('🗑️ [Telegram] Chamando endpoint: $url');
      print('🗑️ [Telegram] Body: $body');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout ao chamar endpoint /delete-message');
        },
      );

      print('🗑️ [Telegram] Status code: ${response.statusCode}');
      print('🗑️ [Telegram] Resposta: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          if (data['deleted'] == true) {
            final deletedCount = data['deletedCount'] ?? 0;
            if (deletedCount > 0) {
              print('✅ [Telegram] Mensagem deletada do Telegram: $mensagemId ($deletedCount instância(s))');
            } else {
              // Mensagem foi deletada do Supabase, mas não havia no Telegram
              final reason = data['reason'] ?? data['info'] ?? 'No delivery logs found';
              print('ℹ️ [Telegram] Mensagem deletada do Supabase, mas não havia no Telegram: $reason');
            }
          } else {
            print('⚠️ [Telegram] Mensagem não foi deletada: ${data['reason'] ?? 'Unknown reason'}');
          }
        } else {
          print('⚠️ [Telegram] Resposta não OK: ${data['error'] ?? response.body}');
        }
      } else {
        print('⚠️ [Telegram] Erro ao deletar mensagem: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ [Telegram] Erro ao deletar mensagem do Telegram: $e');
      // Não rethrow - não queremos que a exclusão no Flutter falhe se o Telegram falhar
    }
  }
}

// ========== MODELS ==========

class TelegramIdentity {
  final String id;
  final String userId;
  final int telegramUserId;
  final String? telegramUsername;
  final String? telegramFirstName;
  final String? telegramLastName;
  final int? lastChatId;
  final DateTime linkedAt;
  final DateTime? lastActiveAt;

  TelegramIdentity({
    required this.id,
    required this.userId,
    required this.telegramUserId,
    this.telegramUsername,
    this.telegramFirstName,
    this.telegramLastName,
    this.lastChatId,
    required this.linkedAt,
    this.lastActiveAt,
  });

  factory TelegramIdentity.fromMap(Map<String, dynamic> map) {
    return TelegramIdentity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      telegramUserId: map['telegram_user_id'] as int,
      telegramUsername: map['telegram_username'] as String?,
      telegramFirstName: map['telegram_first_name'] as String?,
      telegramLastName: map['telegram_last_name'] as String?,
      lastChatId: map['last_chat_id'] as int?,
      linkedAt: DateTime.parse(map['linked_at'] as String),
      lastActiveAt: map['last_active_at'] != null
          ? DateTime.parse(map['last_active_at'] as String)
          : null,
    );
  }
}

class TelegramSubscription {
  final String id;
  final String threadType; // COMMUNITY ou TASK
  final String threadId;
  final String mode; // dm, group_topic, group_plain
  final int telegramChatId;
  final int? telegramTopicId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool active;
  final Map<String, dynamic>? settings;

  TelegramSubscription({
    required this.id,
    required this.threadType,
    required this.threadId,
    required this.mode,
    required this.telegramChatId,
    this.telegramTopicId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.active,
    this.settings,
  });

  factory TelegramSubscription.fromMap(Map<String, dynamic> map) {
    return TelegramSubscription(
      id: map['id'] as String,
      threadType: map['thread_type'] as String,
      threadId: map['thread_id'] as String,
      mode: map['mode'] as String,
      telegramChatId: map['telegram_chat_id'] as int,
      telegramTopicId: map['telegram_topic_id'] as int?,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      active: map['active'] as bool,
      settings: map['settings'] as Map<String, dynamic>?,
    );
  }
}
