import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/demand.dart';

class DemandService {
  final _supabase = Supabase.instance.client;
  final int pageSize = 50;

  Future<List<Demand>> list({
    int page = 0,
    Set<String>? status,
    Set<String>? prioridade,
    Set<String>? categorias,
    String? busca,
    DateTime? venceDe,
    DateTime? venceAte,
    String orderBy = 'data_vencimento',
    bool asc = true,
  }) async {
    dynamic query = _supabase
        .from('demands')
        .select('*');

    if (status != null && status.isNotEmpty) {
      query = query.in_('status', status.toList());
    }
    if (prioridade != null && prioridade.isNotEmpty) {
      query = query.in_('prioridade', prioridade.toList());
    }
    if (categorias != null && categorias.isNotEmpty) {
      query = query.in_('categoria_id', categorias.toList());
    }
    if (venceDe != null) {
      query = query.gte('data_vencimento', venceDe.toIso8601String());
    }
    if (venceAte != null) {
      query = query.lte('data_vencimento', venceAte.toIso8601String());
    }
    if (busca != null && busca.trim().isNotEmpty) {
      final b = busca.trim();
      query = query.or('titulo.ilike.%$b%,descricao.ilike.%$b%');
    }
    query = query.order(orderBy, ascending: asc).range(page * pageSize, page * pageSize + pageSize - 1);

    final data = await query;
    return (data as List).map((e) => Demand.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Demand> create(Demand d) async {
    final payload = Map<String, dynamic>.from(d.toMap());
    // Deixa o banco gerar o id
    if (payload['id'] == null || (payload['id'] is String && (payload['id'] as String).isEmpty)) {
      payload.remove('id');
    }
    // Garantir criado_por = usuário logado para atender RLS
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      payload['criado_por'] = uid;
    }
    final res = await _supabase.from('demands').insert(payload).select().single();
    return Demand.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<Demand> update(Demand d) async {
    final res = await _supabase.from('demands').update(d.toMap()).eq('id', d.id).select().single();
    return Demand.fromMap(res);
  }

  Future<void> delete(String id) async {
    await _supabase.from('demands').delete().eq('id', id);
  }

  RealtimeChannel subscribe({
    required void Function(Demand d) onUpsert,
    required void Function(String id) onDelete,
  }) {
    final channel = _supabase
        .channel('public:demands')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'demands',
          callback: (payload) {
            final record = payload.newRecord;
            onUpsert(Demand.fromMap(record));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'demands',
          callback: (payload) {
            final record = payload.newRecord;
            onUpsert(Demand.fromMap(record));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'demands',
          callback: (payload) {
            final record = payload.oldRecord;
            if (record['id'] != null) {
              onDelete(record['id'] as String);
            }
          },
        )
        .subscribe();
    return channel;
  }
}
