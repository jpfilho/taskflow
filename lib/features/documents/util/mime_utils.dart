class MimeUtilsDocuments {
  static const Map<String, String> _byExtension = {
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'zip': 'application/zip',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String guessMime(String fileName, {String fallback = 'application/octet-stream'}) {
    final ext = _extractExtension(fileName).toLowerCase();
    return _byExtension[ext] ?? fallback;
  }

  static String _extractExtension(String fileName) {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last;
  }
}
