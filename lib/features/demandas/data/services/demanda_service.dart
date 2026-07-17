import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/supabase_config.dart';
import '../../../../services/auth_service_simples.dart';
import '../models/demanda_model.dart';
import '../models/demanda_anexo_model.dart';
import '../models/demanda_historico_model.dart';

class DemandaService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Listar demandas com filtros aplicados
  Future<List<Demanda>> listarDemandas({
    String? status,
    String? origem,
    String? local,
    String? responsavel,
    String? prioridade,
    DateTime? prazoInicio,
    DateTime? prazoFim,
    String? busca,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('demandas').select('*');

      if (status != null && status != 'Todas') {
        query = query.eq('status', status);
      }
      if (origem != null && origem.isNotEmpty) {
        query = query.eq('origem', origem);
      }
      if (local != null && local.isNotEmpty) {
        query = query.eq('local', local);
      }
      if (responsavel != null && responsavel.isNotEmpty) {
        query = query.eq('responsavel', responsavel);
      }
      if (prioridade != null && prioridade != 'Todas') {
        query = query.eq('prioridade', prioridade);
      }
      if (prazoInicio != null) {
        query = query.gte('prazo', prazoInicio.toIso8601String().substring(0, 10));
      }
      if (prazoFim != null) {
        query = query.lte('prazo', prazoFim.toIso8601String().substring(0, 10));
      }

      if (busca != null && busca.trim().isNotEmpty) {
        final b = busca.trim();
        query = query.or(
          'demanda.ilike.%$b%,observacoes.ilike.%$b%,nota.ilike.%$b%,ordem.ilike.%$b%,si.ilike.%$b%,at.ilike.%$b%,local.ilike.%$b%,sala.ilike.%$b%,responsavel.ilike.%$b%'
        );
      }

      final response = await query
          .order('prazo', ascending: true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((map) => Demanda.fromMap(map)).toList();
    } catch (e) {
      print('Erro ao listar demandas: $e');
      rethrow;
    }
  }

  // Criar demanda e registrar histórico
  Future<Demanda> criarDemanda(Demanda demanda) async {
    try {
      final uid = AuthServiceSimples().currentUser?.id;
      final map = demanda.toMap();
      if (uid != null) {
        map['created_by'] = uid;
        map['updated_by'] = uid;
      }

      final response = await _supabase.from('demandas').insert(map).select().single();
      final novaDemanda = Demanda.fromMap(response);

      // Registrar histórico de criação
      await registrarHistorico(
        demandaId: novaDemanda.id,
        observacao: 'Demanda criada',
      );

      return novaDemanda;
    } catch (e) {
      print('Erro ao criar demanda: $e');
      rethrow;
    }
  }

  // Atualizar demanda e registrar histórico de alterações relevantes
  Future<Demanda> atualizarDemanda(Demanda demanda, {Demanda? versaoAnterior}) async {
    try {
      final uid = AuthServiceSimples().currentUser?.id;
      final map = demanda.toMap();
      if (uid != null) {
        map['updated_by'] = uid;
      }

      // Se passou para Concluída, setar data de conclusão
      if (demanda.status == 'Concluída' && (versaoAnterior == null || versaoAnterior.status != 'Concluída')) {
        map['data_conclusao'] = DateTime.now().toIso8601String();
      } else if (demanda.status != 'Concluída') {
        map['data_conclusao'] = null;
      }

      final response = await _supabase.from('demandas').update(map).eq('id', demanda.id).select().single();
      final demandaAtualizada = Demanda.fromMap(response);

      // Comparar e registrar históricos
      if (versaoAnterior != null) {
        if (versaoAnterior.status != demandaAtualizada.status) {
          await registrarHistorico(
            demandaId: demandaAtualizada.id,
            campo: 'status',
            valorAnterior: versaoAnterior.status,
            valorNovo: demandaAtualizada.status,
            observacao: 'Status alterado para ${demandaAtualizada.status}',
          );
        }
        if (versaoAnterior.prazo.year != demandaAtualizada.prazo.year ||
            versaoAnterior.prazo.month != demandaAtualizada.prazo.month ||
            versaoAnterior.prazo.day != demandaAtualizada.prazo.day) {
          await registrarHistorico(
            demandaId: demandaAtualizada.id,
            campo: 'prazo',
            valorAnterior: versaoAnterior.prazo.toIso8601String().substring(0, 10),
            valorNovo: demandaAtualizada.prazo.toIso8601String().substring(0, 10),
            observacao: 'Prazo alterado',
          );
        }
        if (versaoAnterior.responsavel != demandaAtualizada.responsavel) {
          await registrarHistorico(
            demandaId: demandaAtualizada.id,
            campo: 'responsavel',
            valorAnterior: versaoAnterior.responsavel,
            valorNovo: demandaAtualizada.responsavel,
            observacao: 'Responsável alterado para ${demandaAtualizada.responsavel}',
          );
        }
      } else {
        await registrarHistorico(
          demandaId: demandaAtualizada.id,
          observacao: 'Dados da demanda atualizados',
        );
      }

      return demandaAtualizada;
    } catch (e) {
      print('Erro ao atualizar demanda: $e');
      rethrow;
    }
  }

  // Excluir demanda
  Future<void> excluirDemanda(String id) async {
    try {
      await _supabase.from('demandas').delete().eq('id', id);
    } catch (e) {
      print('Erro ao excluir demanda: $e');
      rethrow;
    }
  }

  // Listar anexos de uma demanda
  Future<List<DemandaAnexo>> listarAnexos(String demandaId) async {
    try {
      final response = await _supabase
          .from('demanda_anexos')
          .select('*')
          .eq('demanda_id', demandaId)
          .order('created_at', ascending: false);

      return (response as List).map((map) => DemandaAnexo.fromMap(map)).toList();
    } catch (e) {
      print('Erro ao listar anexos: $e');
      rethrow;
    }
  }

  // Fazer upload de anexo (suporta Web e Mobile)
  Future<DemandaAnexo> uploadAnexo({
    required String demandaId,
    required String tipo, // evidencia_antes, evidencia_depois, anexo_geral
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      final uid = AuthServiceSimples().currentUser?.id;
      final subPasta = tipo == 'evidencia_antes'
          ? 'antes'
          : tipo == 'evidencia_depois'
              ? 'depois'
              : 'geral';

      // Sanitizar nome do arquivo para evitar caracteres incompatíveis no path do storage
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final fileStoragePath = '$demandaId/$subPasta/$cleanFileName';

      // Mapear extensões comuns para tipos MIME válidos (evita erro "Invalid media type: expected '/'")
      String contentType = 'application/octet-stream';
      final ext = (mimeType ?? fileName.split('.').last).toLowerCase().replaceAll('.', '');
      if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      } else if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (ext == 'txt') {
        contentType = 'text/plain';
      } else if (ext == 'xlsx') {
        contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else if (ext == 'docx') {
        contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }

      // Upload do arquivo binário para o Supabase Storage
      await _supabase.storage.from('demandas').uploadBinary(
            fileStoragePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      // Obter URL pública do arquivo no bucket
      final fileUrl = _supabase.storage.from('demandas').getPublicUrl(fileStoragePath);

      // Salvar metadados na tabela
      final mapAnexo = {
        'demanda_id': demandaId,
        'tipo': tipo,
        'file_name': fileName,
        'file_path': fileStoragePath,
        'file_url': fileUrl,
        'mime_type': mimeType,
        'file_size': bytes.length,
      };

      if (uid != null) {
        mapAnexo['created_by'] = uid;
      }

      final response = await _supabase.from('demanda_anexos').insert(mapAnexo).select().single();
      final anexo = DemandaAnexo.fromMap(response);

      // Registrar histórico de upload
      await registrarHistorico(
        demandaId: demandaId,
        observacao: 'Upload de anexo concluído: $fileName (${tipo.replaceAll("evidencia_", "evidência ")})',
      );

      return anexo;
    } catch (e) {
      print('Erro no upload de anexo: $e');
      rethrow;
    }
  }

  // Excluir anexo
  Future<void> excluirAnexo(DemandaAnexo anexo) async {
    try {
      // 1. Remover arquivo físico do storage
      await _supabase.storage.from('demandas').remove([anexo.filePath]);

      // 2. Remover do banco de dados (o RLS e a constraint cuidam de seguranças)
      await _supabase.from('demanda_anexos').delete().eq('id', anexo.id);

      // 3. Registrar histórico
      await registrarHistorico(
        demandaId: anexo.demandaId,
        observacao: 'Anexo removido: ${anexo.fileName}',
      );
    } catch (e) {
      print('Erro ao excluir anexo: $e');
      rethrow;
    }
  }

  // Listar histórico de uma demanda
  Future<List<DemandaHistorico>> listarHistorico(String demandaId) async {
    try {
      final response = await _supabase
          .from('demanda_historico')
          .select('*')
          .eq('demanda_id', demandaId)
          .order('created_at', ascending: false);

      return (response as List).map((map) => DemandaHistorico.fromMap(map)).toList();
    } catch (e) {
      print('Erro ao listar historico: $e');
      rethrow;
    }
  }

  // Registrar entrada de histórico
  Future<void> registrarHistorico({
    required String demandaId,
    String? campo,
    String? valorAnterior,
    String? valorNovo,
    String? observacao,
  }) async {
    try {
      final uid = AuthServiceSimples().currentUser?.id;
      final map = {
        'demanda_id': demandaId,
        'campo': campo,
        'valor_anterior': valorAnterior,
        'valor_novo': valorNovo,
        'observacao': observacao,
      };

      if (uid != null) {
        map['created_by'] = uid;
      }

      await _supabase.from('demanda_historico').insert(map);
    } catch (e) {
      print('Erro ao registrar histórico: $e');
    }
  }
}
