import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // URLs de Desenvolvimento (Servidor Antigo VPS)
  static const String _devSupabaseUrl = 'http://212.85.0.249:8000';
  static const String _devApiBaseUrl  = 'http://212.85.0.249:3001';

  // URLs de Produção (Rede Interna - Supabase/Kong: 8000, Node/API: 3001, Web: 8085)
  static const String _prodSupabaseUrl = 'http://10.140.50.12:8000';
  static const String _prodApiBaseUrl  = 'http://10.140.50.12:3001';

  // Release (Produção) vs Debug/Local (Desenvolvimento) com detecção inteligente por host
  static const String _env = String.fromEnvironment('ENVIRONMENT', defaultValue: '');

  static String get supabaseUrl {
    if (_env == 'dev') return _devSupabaseUrl;
    if (_env == 'prod') return _prodSupabaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('212.85.0.249') || host.contains('localhost') || host.contains('127.0.0.1')) {
        return _devSupabaseUrl;
      }
      if (host.contains('10.140.50.12')) {
        return _prodSupabaseUrl;
      }
    }
    return kReleaseMode ? _prodSupabaseUrl : _devSupabaseUrl;
  }

  static String get apiBaseUrl {
    if (_env == 'dev') return _devApiBaseUrl;
    if (_env == 'prod') return _prodApiBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('212.85.0.249') || host.contains('localhost') || host.contains('127.0.0.1')) {
        return _devApiBaseUrl;
      }
      if (host.contains('10.140.50.12')) {
        return _prodApiBaseUrl;
      }
    }
    return kReleaseMode ? _prodApiBaseUrl : _devApiBaseUrl;
  }
  
  // Chave anon do Supabase
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}



