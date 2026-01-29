/// Serviço de verificação de nova versão (web: consulta version.txt; outras plataformas: no-op).
export 'version_check_service_stub.dart'
    if (dart.library.html) 'version_check_service_web.dart';
