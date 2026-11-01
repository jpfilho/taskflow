/// Helper central para identificação, extração canônica e comparação
/// de chave de instalações elétricas (Subestações - SE, Linhas de Transmissão - LT e Usinas - U)
/// a partir do `local_instalacao` e campos correlatos do SAP.
class InstalacaoSapHelper {
  InstalacaoSapHelper._();

  /// Termos genéricos que NÃO devem ser considerados salas/estruturas específicas para Critério B.
  static const Set<String> _blacklistSalas = {
    '',
    '-',
    '--',
    '---',
    '.',
    '/',
    '//',
    'GERAL',
    'GERAL.',
    'GERAL-',
    'GERAL -',
    'NA',
    'N/A',
    'NAO APLICAVEL',
    'NÃO APLICÁVEL',
    'NAO APLICA',
    'NÃO APLICA',
    'SEM SALA',
    'SEM LOCAL',
    'NAO INFORMADO',
    'NÃO INFORMADO',
    'INDEFINIDO',
    'DIVERSOS',
    'PADRAO',
    'PADRÃO',
    'OUTROS',
    'TOTAL',
  };

  /// Extrai a chave canônica da instalação a partir do `local_instalacao` SAP.
  ///
  /// Casos atendidos:
  /// - Subestação (SE): 'H-S-SCTU-RB4T02-4CT1-DJ01' -> 'H-S-SCTU'
  /// - Linha de Transmissão (LT): 'H-L-SMTDSBNO-RB4F04-4LT1' -> 'H-L-SMTDSBNO'
  /// - Usina (U): 'H-U-HUSQ-VTDR01' -> 'H-U-HUSQ'
  /// - Curto / Incompleto: 'H-S-STSA' -> 'H-S-STSA'
  /// - Fallback com comprimento >= 8 caracteres se não contiver hífen padrão.
  /// - Retorna `null` se for nulo, vazio, ou com menos de 3 caracteres significativos.
  static String? extrairChaveInstalacao(String? localInstalacao) {
    if (localInstalacao == null) return null;
    final limpo = localInstalacao.trim().toUpperCase();
    if (limpo.length < 3) return null;

    final partes = limpo.split('-');
    // Padrão estruturado do SAP no setor elétrico: PREFIXO-TIPO-IDENTIFICADOR-... (ex: H-S-SCTU, H-L-SPDDSTSD)
    if (partes.length >= 3) {
      final p0 = partes[0].trim();
      final p1 = partes[1].trim();
      final p2 = partes[2].trim();
      if (p0.isNotEmpty && p1.isNotEmpty && p2.isNotEmpty) {
        return '$p0-$p1-$p2';
      }
    }

    // Se tiver 2 partes e comprimento razoável (ex: H-U-HUSQ pode vir como H-HUSQ ou partes menores)
    if (partes.length == 2) {
      final p0 = partes[0].trim();
      final p1 = partes[1].trim();
      if (p0.isNotEmpty && p1.isNotEmpty) {
        return '$p0-$p1';
      }
    }

    // Fallback: se tiver pelo menos 8 caracteres
    if (limpo.length >= 8) {
      return limpo.substring(0, 8);
    }

    // Se for curto mas sem hífen, só retorna se tiver 4 a 7 caracteres alfanuméricos
    if (RegExp(r'^[A-Z0-9]{3,}$').hasMatch(limpo)) {
      return limpo;
    }

    return null;
  }

  /// Valida se duas instalações pertencem à mesma instalação física canônica.
  static bool saoMesmaInstalacao(String? localA, String? localB) {
    final chaveA = extrairChaveInstalacao(localA);
    final chaveB = extrairChaveInstalacao(localB);

    if (chaveA == null || chaveB == null) return false;
    return chaveA == chaveB;
  }

  /// Normaliza uma sala/estrutura para comparação do Critério B.
  /// Remove espaços extras, converte para maiúsculo e padroniza separadores.
  static String normalizarSala(String? sala) {
    if (sala == null) return '';
    var s = sala.trim().toUpperCase();
    // Normaliza múltiplos espaços
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Verifica se uma sala/estrutura é tecnicamente válida para o Critério B.
  /// Descarta termos genéricos (blacklist como 'GERAL', 'N/A', em branco, etc.).
  static bool ehSalaValidaParaCriterioB(String? sala) {
    if (sala == null) return false;
    final norm = normalizarSala(sala);

    if (norm.isEmpty) return false;
    if (_blacklistSalas.contains(norm)) return false;

    // Se for apenas pontuação ou números isolados sem contexto
    if (RegExp(r'^[\s\.\-_/]+$').hasMatch(norm)) return false;

    // Deve ter pelo menos um caractere alfanumérico
    if (!RegExp(r'[A-Z0-9]').hasMatch(norm)) return false;

    return true;
  }
}
