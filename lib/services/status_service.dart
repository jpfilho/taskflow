import '../models/status.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class StatusService {
  static final StatusService _instance = StatusService._internal();
  factory StatusService() => _instance;
  StatusService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  
  // StreamController para notificar mudanças nos status
  final _statusChangeController = StreamController<String>.broadcast();
  
  Stream<String> get statusChangeStream => _statusChangeController.stream;
  
  void notifyStatusChanged(String statusId) {
    _statusChangeController.add(statusId);
  }
  
  void notifyAllStatusChanged() {
    _statusChangeController.add('all');
  }
  
  void dispose() {
    _statusChangeController.close();
  }

  // Converter Map do Supabase para Status
  Status _statusFromMap(Map<String, dynamic> map) {
    final cor = map['cor'] as String?;
    final corSegmento = map['cor_segmento'] as String?;
    final corTextoSegmento = map['cor_texto_segmento'] as String?;
    return Status(
      id: map['id'] as String,
      codigo: map['codigo'] as String,
      status: map['status'] as String,
      cor: cor ?? '#2196F3',
      corSegmento: corSegmento,
      corTextoSegmento: corTextoSegmento,
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
      'cor_segmento': status.corSegmento,
      'cor_texto_segmento': status.corTextoSegmento,
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
        // debug silenciado
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

      final createdStatus = _statusFromMap(response);
      notifyAllStatusChanged(); // Notificar mudança
      return createdStatus;
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
      notifyStatusChanged(id); // Notificar mudança específica
      notifyAllStatusChanged(); // Notificar mudança geral também
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
      notifyAllStatusChanged(); // Notificar mudança
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

