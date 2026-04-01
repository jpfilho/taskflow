import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/demand_attachment.dart';

class DemandAttachmentService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _bucket = 'demands-attachments';
  static const String _table = 'demand_attachments';

  Future<void> _ensureBucket() async {
    try {
      await _supabase.storage.from(_bucket).list(path: '');
    } catch (e) {
      debugPrint('⚠️ Bucket $_bucket não encontrado. Crie no Dashboard > Storage.');
      rethrow;
    }
  }

  String _sanitizeFileName(String name) {
    final parts = name.split('.');
    final ext = parts.length > 1 ? parts.removeLast() : '';
    String base = parts.join('.');
    base = base
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅ]'), 'A')
        .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
        .replaceAll(RegExp(r'[ÌÍÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜ]'), 'U')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[Ñ]'), 'N')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'arquivo';
    return ext.isNotEmpty ? '$base.$ext' : base;
  }

  Future<List<DemandAttachment>> listByDemand(String demandaId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('demanda_id', demandaId)
        .order('criado_em', ascending: false);
    return (data as List<dynamic>)
        .map((e) => DemandAttachment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> _mimeFromName(String name) {
    // Supabase storage aceita null; retornar genérico se não detectar.
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return Future.value('image/png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return Future.value('image/jpeg');
    if (lower.endsWith('.pdf')) return Future.value('application/pdf');
    if (lower.endsWith('.txt')) return Future.value('text/plain');
    return Future.value('application/octet-stream');
  }

  Future<DemandAttachment> uploadFile({
    required String demandaId,
    required File file,
    String? nomeCustomizado,
  }) async {
    await _ensureBucket();
    final original = nomeCustomizado ?? file.path.split('/').last;
    final sanitized = _sanitizeFileName(original);
    final path = '$demandaId/${DateTime.now().millisecondsSinceEpoch}-$sanitized';
    final mime = await _mimeFromName(sanitized);

    final bytes = await file.readAsBytes();
    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    final inserted = await _supabase.from(_table).insert({
      'demanda_id': demandaId,
      'url': path, // guardamos caminho, usamos signed URL na leitura
      'nome': original,
      'tamanho_bytes': bytes.length,
      'content_type': mime,
    }).select().single();

    return DemandAttachment.fromMap(inserted);
  }

  Future<DemandAttachment> uploadBytes({
    required String demandaId,
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    await _ensureBucket();
    final sanitized = _sanitizeFileName(nomeArquivo);
    final path = '$demandaId/${DateTime.now().millisecondsSinceEpoch}-$sanitized';
    final mime = await _mimeFromName(sanitized);

    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    final inserted = await _supabase.from(_table).insert({
      'demanda_id': demandaId,
      'url': path,
      'nome': nomeArquivo,
      'tamanho_bytes': bytes.length,
      'content_type': mime,
    }).select().single();

    return DemandAttachment.fromMap(inserted);
  }

  Future<void> deleteAttachment(DemandAttachment attachment) async {
    await _ensureBucket();
    try {
      await _supabase.storage.from(_bucket).remove([attachment.url]);
    } catch (_) {
      // Se remover no storage falhar, tentamos ainda remover no banco
    }
    await _supabase.from(_table).delete().eq('id', attachment.id);
  }

  Future<String> getDownloadUrl(DemandAttachment attachment, {int expiresInSeconds = 3600}) async {
    await _ensureBucket();
    final signed = await _supabase.storage.from(_bucket).createSignedUrl(
          attachment.url,
          expiresInSeconds,
        );
    return signed;
  }
}
