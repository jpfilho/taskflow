import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // URL do seu projeto Supabase (HTTP na porta 8000)
  // NOTA: HTTPS está dando "Unauthorized" - proxy Nginx precisa ser configurado
  static const String supabaseUrl = 'http://212.85.0.249:8000';
  // API Node (webhook/geo), mesma máquina na porta 3001
  static const String apiBaseUrl = 'http://212.85.0.249:3001';
  
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



