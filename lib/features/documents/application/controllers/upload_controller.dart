import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../data/models/document.dart';
import '../../data/repositories/supabase_documents_repository.dart';
import '../../util/mime_utils.dart';

class DocumentUploadItem {
  final String fileName;
  final Uint8List bytes;
  double progress;
  Document? created;
  Object? error;

  DocumentUploadItem({
    required this.fileName,
    required this.bytes,
    this.progress = 0,
    this.created,
    this.error,
  });
}

class DocumentUploadController extends ChangeNotifier {
  final SupabaseDocumentsRepository repository;
  final List<DocumentUploadItem> uploads = [];
  bool isUploading = false;

  DocumentUploadController(this.repository);

  void addFiles(List<DocumentUploadItem> items) {
    uploads.addAll(items);
    notifyListeners();
  }

  Future<void> uploadAll({
    required String userId,
    String? regionalId,
    String? divisaoId,
    String? localId,
    String? segmentId,
    String? titlePrefix,
    String? description,
    List<String> tags = const [],
    String? equipmentId,
    String? roomId,
    String? statusDocumentId,
  }) async {
    if (isUploading) return;
    isUploading = true;
    notifyListeners();

    for (final item in uploads) {
      try {
        item.progress = 0.1;
        notifyListeners();

        final mime = MimeUtilsDocuments.guessMime(item.fileName);
        final created = await repository.uploadAndCreateDocument(
          userId: userId,
          fileBytes: item.bytes,
          fileName: item.fileName,
          mimeType: mime,
          title: '${titlePrefix ?? ''}${titlePrefix != null ? ' ' : ''}${item.fileName}',
          description: description,
          tags: tags,
          regionalId: regionalId,
          divisaoId: divisaoId,
          segmentId: segmentId,
          localId: localId,
          equipmentId: equipmentId,
          roomId: roomId,
          statusDocumentId: statusDocumentId,
        );
        item.progress = 1;
        item.created = created;
      } catch (e) {
        item.error = e;
        item.progress = 1;
      }
      notifyListeners();
    }
    isUploading = false;
    notifyListeners();
  }
}
