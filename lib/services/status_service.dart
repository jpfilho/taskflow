import '../models/status.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatusService {
  static final StatusService _instance = StatusService._internal();
  factory StatusService() => _instance;
  StatusService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Status
  Status _statusFromMap(Map<String, dynamic> map) {
    final cor = map['cor'] as String?;
    print('📥 Carregando status ${map['codigo']} com cor: $cor');
    return Status(
      id: map['id'] as String,
      codigo: map['codigo'] as String,
      status: map['status'] as String,
      cor: cor ?? '#2196F3',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Converter Status para Map (para Supabase)
  Map<String, dynamic> _statusToMap(Status status) {
    return {
      'codigo': status.codigo,
      'status': status.status,
      'cor': status.cor,
    };
  }

  // Buscar todos os status
  Future<List<Status>> getAllStatus() async {
    try {
      final response = await _supabase
          .from('status')
          .select()
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar status');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final statusList = response as List;
      final statuses = statusList
          .map((map) => _statusFromMap(map as Map<String, dynamic>))
          .toList();
      
      // Log para debug
      for (var status in statuses) {
        print('📋 Status carregado: ${status.codigo} - Cor: ${status.cor}');
      }
      
      return statuses;
    } catch (e) {
      print('Erro ao buscar status: $e');
      return [];
    }
  }

  // Buscar status por ID
  Future<Status?> getStatusById(String id) async {
    try {
      final response = await _supabase
          .from('status')
          .select()
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Timeout ao buscar status por ID');
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) return null;

      return _statusFromMap(response);
    } catch (e) {
      print('Erro ao buscar status por ID: $e');
      return null;
    }
  }

  // Buscar status por código
  Future<Status?> getStatusByCodigo(String codigo) async {
    try {
      final response = await _supabase
          .from('status')
          .select()
          .eq('codigo', codigo)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Timeout ao buscar status por código');
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) return null;

      return _statusFromMap(response);
    } catch (e) {
      print('Erro ao buscar status por código: $e');
      return null;
    }
  }

  // Criar status
  Future<Status?> createStatus(Status status) async {
    try {
      final statusMap = _statusToMap(status);
      statusMap.remove('id'); // Remover ID para gerar UUID no Supabase

      final response = await _supabase
          .from('status')
          .insert(statusMap)
          .select()
          .single();

      return _statusFromMap(response);
    } catch (e) {
      print('Erro ao criar status: $e');
      return null;
    }
  }

  // Atualizar status
  Future<Status?> updateStatus(String id, Status status) async {
    try {
      final statusMap = _statusToMap(status);
      print('🔄 Atualizando status $id com cor: ${statusMap['cor']}');

      final response = await _supabase
          .from('status')
          .update(statusMap)
          .eq('id', id)
          .select()
          .single();

      final updatedStatus = _statusFromMap(response);
      print('✅ Status atualizado. Cor retornada: ${updatedStatus.cor}');
      return updatedStatus;
    } catch (e) {
      print('❌ Erro ao atualizar status: $e');
      return null;
    }
  }

  // Deletar status
  Future<bool> deleteStatus(String id) async {
    try {
      await _supabase.from('status').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar status: $e');
      return false;
    }
  }

  // Buscar status por filtros
  Future<List<Status>> filterStatus({
    String? codigo,
    String? status,
  }) async {
    try {
      var query = _supabase.from('status').select();

      if (codigo != null && codigo.isNotEmpty) {
        query = query.ilike('codigo', '%$codigo%');
      }
      if (status != null && status.isNotEmpty) {
        query = query.ilike('status', '%$status%');
      }

      final response = await query
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao filtrar status');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar status: $e');
      return [];
    }
  }

  // Buscar status por texto (busca em todos os campos)
  Future<List<Status>> searchStatus(String query) async {
    if (query.isEmpty) {
      return getAllStatus();
    }

    try {
      final response = await _supabase
          .from('status')
          .select()
          .or(
            'codigo.ilike.%$query%,status.ilike.%$query%',
          )
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar status');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar status: $e');
      return [];
    }
  }
}

