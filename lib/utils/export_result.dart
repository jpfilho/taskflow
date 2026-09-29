class ExportResult {
  final bool success;
  final String filename;
  final String pathOrLocation;
  final String? errorMessage;
  final bool canOpenFile;
  final String? localFilePath;

  const ExportResult({
    required this.success,
    required this.filename,
    required this.pathOrLocation,
    this.errorMessage,
    this.canOpenFile = false,
    this.localFilePath,
  });
}
