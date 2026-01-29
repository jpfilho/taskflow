import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PathBuilder {
  static const String bucketName = 'taskflow-media';

  /// Constrói o caminho completo para armazenar uma imagem
  /// Formato: {userId}/{segmentId}/{equipmentId}/{roomId}/{yyyy}/{mm}/{uuid}.jpg
  static String buildImagePath({
    required String userId,
    String? segmentId,
    String? equipmentId,
    String? roomId,
    required String extension,
  }) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final fileName = '${_uuid.v4()}.${extension.replaceAll('.', '')}';

    final parts = <String>[userId];
    if (segmentId != null) parts.add(segmentId);
    if (equipmentId != null) parts.add(equipmentId);
    if (roomId != null) parts.add(roomId);
    parts.addAll([year, month, fileName]);

    return parts.join('/');
  }

  /// Constrói o caminho para thumbnail
  static String buildThumbPath(String originalPath) {
    final parts = originalPath.split('/');
    final fileName = parts.last;
    final nameWithoutExt = fileName.split('.').first;
    final ext = fileName.split('.').last;
    parts[parts.length - 1] = '${nameWithoutExt}_thumb.$ext';
    return parts.join('/');
  }

  /// Constrói o caminho para PNG anotado (export).
  /// Formato: {userId}/{segmentId}/{equipmentId}/{roomId}/annotated/{mediaImageId}/{yyyy}/{mm}/{uuid}.png
  static String buildAnnotatedPngPath({
    required String userId,
    required String mediaImageId,
    String? segmentId,
    String? equipmentId,
    String? roomId,
  }) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final fileName = '${_uuid.v4()}.png';
    final parts = <String>[userId];
    if (segmentId != null) parts.add(segmentId);
    if (equipmentId != null) parts.add(equipmentId);
    if (roomId != null) parts.add(roomId);
    parts.addAll(['annotated', mediaImageId, year, month, fileName]);
    return parts.join('/');
  }

  /// Extrai o userId do caminho
  static String? extractUserId(String path) {
    final parts = path.split('/');
    if (parts.isNotEmpty) return parts[0];
    return null;
  }
}
