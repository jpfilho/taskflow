import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PathBuilderDocuments {
  static const String bucketName = 'taskflow-documents';

  /// Formato: {userId}/{segmentId}/{equipmentId}/{roomId}/{yyyy}/{mm}/{uuid}.{ext}
  static String buildDocumentPath({
    required String userId,
    String? segmentId,
    String? equipmentId,
    String? roomId,
    required String extension,
  }) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final cleanExt = extension.replaceAll('.', '');
    final fileName = '${_uuid.v4()}.$cleanExt';

    final parts = <String>[userId];
    if (segmentId != null) parts.add(segmentId);
    if (equipmentId != null) parts.add(equipmentId);
    if (roomId != null) parts.add(roomId);
    parts.addAll([year, month, fileName]);

    return parts.join('/');
  }

  /// Gera caminho para thumbnails/preview se existirem.
  static String buildThumbPath(String originalPath) {
    final parts = originalPath.split('/');
    final fileName = parts.last;
    final nameWithoutExt = fileName.split('.').first;
    final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
    parts[parts.length - 1] = '${nameWithoutExt}_thumb.$ext';
    return parts.join('/');
  }
}
