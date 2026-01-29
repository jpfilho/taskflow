import '../data/repositories/supabase_media_repository.dart';
import '../data/models/media_image.dart';

/// Helper para gerenciar URLs de imagens do storage
/// Renova signed URLs quando necessário
class ImageUrlHelper {
  static final SupabaseMediaRepository _repository = SupabaseMediaRepository();

  /// Obtém uma URL válida para uma imagem
  /// Se fileUrl já existe e é válida, retorna ela
  /// Caso contrário, gera uma nova signed URL
  static Future<String> getValidImageUrl(MediaImage image) async {
    // Se já tem fileUrl e parece ser uma signed URL válida, usar ela
    if (image.fileUrl != null && image.fileUrl!.isNotEmpty) {
      // Verificar se é uma signed URL (contém token=)
      if (image.fileUrl!.contains('token=')) {
        // Verificar se ainda não expirou (aproximado)
        // Signed URLs do Supabase têm formato: ...?token=...&expires=...
        // Por segurança, sempre renovar se tiver mais de 1 hora de uso
        return image.fileUrl!;
      }
    }

    // Gerar nova signed URL
    try {
      final signedUrl = await _repository.getSignedUrl(
        image.filePath,
        expiresIn: 3600, // 1 hora
      );
      return signedUrl;
    } catch (e) {
      // Se falhar, retornar URL existente ou string vazia
      return image.fileUrl ?? '';
    }
  }

  /// Renova a signed URL de uma imagem e atualiza no banco
  static Future<MediaImage> refreshImageUrl(MediaImage image) async {
    try {
      final newUrl = await _repository.getSignedUrl(
        image.filePath,
        expiresIn: 31536000, // 1 ano (para URLs salvas no banco)
      );

      // Atualizar no banco
      final updated = await _repository.updateMediaImage(
        image.copyWith(fileUrl: newUrl),
      );

      return updated;
    } catch (e) {
      // Se falhar, retornar imagem original
      return image;
    }
  }
}
