import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // URLs de Desenvolvimento (Servidor Antigo VPS)
  static const String _devSupabaseUrl = 'http://212.85.0.249:8000';
  static const String _devApiBaseUrl  = 'http://212.85.0.249:3001';

  // URLs de Produção (Rede Interna - Supabase/Kong: 8000, Node/API: 3001, Web: 8085)
  static const String _prodSupabaseUrl = 'http://10.140.50.12:8000';
  static const String _prodApiBaseUrl  = 'http://10.140.50.12:3001';

  // Release (Produção) vs Debug/Local (Desenvolvimento)
  static const String supabaseUrl = kReleaseMode ? _prodSupabaseUrl : _devSupabaseUrl;
  static const String apiBaseUrl  = kReleaseMode ? _prodApiBaseUrl  : _devApiBaseUrl;
  
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



