import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/anexo.dart';
import '../config/supabase_config.dart';

class AnexoService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _bucketName = 'anexos-tarefas';

  // Criar bucket se não existir (deve ser feito manualmente no Supabase ou via código de inicialização)
  Future<void> _ensureBucketExists() async {
    try {
      await _supabase.storage.from(_bucketName).list();
    } catch (e) {
      // Bucket não existe, mas não vamos criar aqui (deve ser feito no Supabase Dashboard)
      debugPrint('⚠️ Bucket não encontrado: $_bucketName');
      debugPrint('⚠️ Por favor, crie o bucket "$_bucketName" no Supabase Dashboard > Storage');
      debugPrint('⚠️ Erro: $e');
      rethrow;
    }
  }

  // Sanitizar nome do arquivo para remover caracteres especiais
  String _sanitizeFileName(String fileName) {
    // Extrair extensão
    final parts = fileName.split('.');
    final extension = parts.length > 1 ? parts.last : '';
    final nameWithoutExt = parts.length > 1 
        ? parts.sublist(0, parts.length - 1).join('.')
        : fileName;
    
    // Remover acentos e caracteres especiais
    String sanitized = nameWithoutExt
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
        // Remover outros caracteres especiais, mantendo apenas letras, números, hífen e underscore
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        // Remover underscores múltiplos
        .replaceAll(RegExp(r'_+'), '_')
        // Remover underscores no início e fim
        .replaceAll(RegExp(r'^_+|_+$'), '');
    
    // Se ficou vazio, usar nome padrão
    if (sanitized.isEmpty) {
      sanitized = 'arquivo';
    }
    
    // Adicionar extensão de volta
    return extension.isNotEmpty ? '$sanitized.$extension' : sanitized;
  }

  // Upload de arquivo
  Future<Anexo> uploadAnexo({
    required String taskId,
    required File file,
    String? nomeCustomizado,
  }) async {
    try {
      await _ensureBucketExists();

      final nomeArquivoOriginal = nomeCustomizado ?? file.path.split('/').last;
      final nomeArquivo = _sanitizeFileName(nomeArquivoOriginal);
      final tipoArquivo = Anexo.getTipoArquivo(nomeArquivo);
      final tamanhoBytes = await file.length();
      
      // Gerar caminho único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final caminhoArquivo = '$taskId/$timestamp-$nomeArquivo';

      // Upload para Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            caminhoArquivo,
            await file.readAsBytes(),
            fileOptions: FileOptions(
              contentType: _getMimeType(nomeArquivo),
              upsert: false,
            ),
          );

      // Salvar metadados no banco de dados (usar nome original para exibição)
      final response = await _supabase
          .from('anexos')
          .insert({
            'task_id': taskId,
            'nome_arquivo': nomeArquivoOriginal, // Salvar nome original para exibição
            'tipo_arquivo': tipoArquivo,
            'caminho_arquivo': caminhoArquivo,
            'tamanho_bytes': tamanhoBytes,
            'mime_type': _getMimeType(nomeArquivo),
          })
          .select()
          .single();

      return Anexo.fromMap(response);
    } catch (e) {
      debugPrint('Erro ao fazer upload do anexo: $e');
      rethrow;
    }
  }

  // Upload de arquivo a partir de bytes (para web)
  Future<Anexo> uploadAnexoFromBytes({
    required String taskId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? mimeType,
  }) async {
    try {
      await _ensureBucketExists();

      final nomeArquivoOriginal = nomeArquivo;
      final nomeArquivoSanitizado = _sanitizeFileName(nomeArquivo);
      final tipoArquivo = Anexo.getTipoArquivo(nomeArquivoSanitizado);
      final tamanhoBytes = bytes.length;
      
      // Gerar caminho único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final caminhoArquivo = '$taskId/$timestamp-$nomeArquivoSanitizado';

      // Upload para Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            caminhoArquivo,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType ?? _getMimeType(nomeArquivoSanitizado),
              upsert: false,
            ),
          );

      // Salvar metadados no banco de dados (usar nome original para exibição)
      final response = await _supabase
          .from('anexos')
          .insert({
            'task_id': taskId,
            'nome_arquivo': nomeArquivoOriginal, // Salvar nome original para exibição
            'tipo_arquivo': tipoArquivo,
            'caminho_arquivo': caminhoArquivo,
            'tamanho_bytes': tamanhoBytes,
            'mime_type': mimeType ?? _getMimeType(nomeArquivoSanitizado),
          })
          .select()
          .single();

      return Anexo.fromMap(response);
    } catch (e) {
      debugPrint('Erro ao fazer upload do anexo: $e');
      rethrow;
    }
  }

  // Listar anexos de uma tarefa
  Future<List<Anexo>> getAnexosByTaskId(String taskId) async {
    try {
      final response = await _supabase
          .from('anexos')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((map) => Anexo.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar anexos: $e');
      return [];
    }
  }

  // Contar anexos de uma tarefa
  Future<int> contarAnexosPorTarefa(String taskId) async {
    try {
      final response = await _supabase
          .from('anexos')
          .select()
          .eq('task_id', taskId);

      return (response as List).length;
    } catch (e) {
      debugPrint('Erro ao contar anexos da tarefa: $e');
      return 0;
    }
  }

  // Contar anexos de múltiplas tarefas (otimizado)
  Future<Map<String, int>> contarAnexosPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Buscar anexos de cada tarefa individualmente
      final contagens = <String, int>{};
      for (var taskId in taskIds) {
        try {
          final response = await _supabase
              .from('anexos')
              .select('task_id')
              .eq('task_id', taskId);
          
          final count = (response as List).length;
          if (count > 0) {
            contagens[taskId] = count;
          }
        } catch (e) {
          // Ignorar erros individuais
        }
      }

      return contagens;
    } catch (e) {
      debugPrint('Erro ao contar anexos das tarefas: $e');
      return {};
    }
  }

  // Obter URL pública do arquivo
  String getPublicUrl(Anexo anexo) {
    return _supabase.storage
        .from(_bucketName)
        .getPublicUrl(anexo.caminhoArquivo);
  }

  // Download de arquivo
  Future<Uint8List> downloadAnexo(Anexo anexo) async {
    try {
      final bytes = await _supabase.storage
          .from(_bucketName)
          .download(anexo.caminhoArquivo);
      return bytes;
    } catch (e) {
      debugPrint('Erro ao fazer download do anexo: $e');
      rethrow;
    }
  }

  // Deletar anexo
  Future<void> deleteAnexo(Anexo anexo) async {
    try {
      // Deletar do storage
      await _supabase.storage
          .from(_bucketName)
          .remove([anexo.caminhoArquivo]);

      // Deletar do banco de dados
      if (anexo.id != null) {
        await _supabase
            .from('anexos')
            .delete()
            .eq('id', anexo.id!);
      }
    } catch (e) {
      debugPrint('Erro ao deletar anexo: $e');
      rethrow;
    }
  }

  // Deletar todos os anexos de uma tarefa
  Future<void> deleteAnexosByTaskId(String taskId) async {
    try {
      final anexos = await getAnexosByTaskId(taskId);
      
      for (final anexo in anexos) {
        await deleteAnexo(anexo);
      }
    } catch (e) {
      debugPrint('Erro ao deletar anexos da tarefa: $e');
      rethrow;
    }
  }

  // Obter MIME type baseado na extensão
  String _getMimeType(String nomeArquivo) {
    final extensao = nomeArquivo.split('.').last.toLowerCase();
    
    final mimeTypes = {
      // Imagens
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'bmp': 'image/bmp',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      
      // Vídeos
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'wmv': 'video/x-ms-wmv',
      'flv': 'video/x-flv',
      'webm': 'video/webm',
      'mkv': 'video/x-matroska',
      
      // Documentos
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
    };
    
    return mimeTypes[extensao] ?? 'application/octet-stream';
  }

  // Formatar tamanho do arquivo
  static String formatarTamanho(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

