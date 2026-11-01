import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_analise.dart';
import '../models/nota_sap_similaridade.dart';

/// Serviço do Módulo H: Motor Determinístico de Similaridade de Notas SAP.
///
/// Responsável por:
/// 1. Busca eficiente de candidatos históricos no Supabase (funil de 2 etapas).
/// 2. Normalização lexical técnica de termos elétricos e avarias.
/// 3. Cálculo de score determinístico e auditável (0 a 100 pontos).
/// 4. Separação entre Ocorrência Semelhante e Histórico do Mesmo Ativo.
/// 5. Extração estatística de mediana de tempo e equipe.
/// 6. Levantamento de frequência de materiais e possíveis demandas abertas.
class NotaSapSimilaridadeService {
  final SupabaseClient? _supabaseClient;

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  // Cache em memória de curta duração (5 minutos) indexado pelo ID da Nota de referência.
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Configuração de uso dos pontos de Tipo SAP (default: false com pontos redistribuídos para a descrição).
  final bool usarPontosTipo;

  NotaSapSimilaridadeService({
    SupabaseClient? supabaseClient,
    this.usarPontosTipo = false,
  }) : _supabaseClient = supabaseClient;

  // ===========================================================================
  // 1. DICIONÁRIO TÉCNICO E NORMALIZAÇÃO LEXICAL TÉCNICA
  // ===========================================================================

  /// Sinônimos e equivalências operacionais comprovadas na base SAP do TaskFlow.
  static const Map<String, String> sinonimosTecnicos = {
    'dj': 'disjuntor',
    'disj': 'disjuntor',
    'disjuntores': 'disjuntor',
    'trafo': 'transformador',
    'trafos': 'transformador',
    'transformadores': 'transformador',
    'vaz': 'vazamento',
    'vazamentos': 'vazamento',
    'prot': 'protecao',
    'isol': 'isolador',
    'isolad': 'isolador',
    'isoladores': 'isolador',
    'subst': 'substituicao',
    'substituir': 'substituicao',
    'sec': 'seccionadora',
    'secc': 'seccionadora',
    'seccionadores': 'seccionadora',
    'estrut': 'estrutura',
    'term': 'terminal',
    'terminais': 'terminal',
    'oleo': 'oleo',
    'mola': 'mola',
    'sf6': 'sf6',
    'bucha': 'bucha',
    'buchas': 'bucha',
    'radiador': 'radiador',
    'radiadores': 'radiador',
    'infiltracao': 'infiltracao',
    'infiltração': 'infiltracao',
    'oxidacao': 'oxidacao',
    'oxidação': 'oxidacao',
    'corrosao': 'oxidacao',
    'corrosão': 'oxidacao',
    'reator': 'reator',
    'reatores': 'reator',
    'vao': 'vao',
    'vão': 'vao',
    'ninho': 'ninho',
    'vegetacao': 'vegetacao',
    'vegetação': 'vegetacao',
    'roco': 'vegetacao',
    'roço': 'vegetacao',
  };

  /// Termos sem valor discriminatório comprovados na auditoria real de Notas SAP.
  static const Set<String> stopwordsGeraisETecnicas = {
    // Stopwords da língua portuguesa
    'de', 'a', 'o', 'em', 'para', 'com', 'no', 'na', 'do', 'da', 'e', 'ou',
    'por', 'sem', 'um', 'uma', 'os', 'as', 'dos', 'das', 'nos', 'nas', 'ao',
    'aos', 'se', 'ja', 'sob', 'sobre', 'que', 'qual', 'pela', 'pelo',
    // Stopwords operacionais genéricas sem valor discriminatório
    'manutencao', 'manutenção', 'corretiva', 'preventiva', 'inspecao',
    'inspeção', 'verificar', 'verificacao', 'verificação', 'equipamento',
    'equipamentos', 'realizar', 'executar', 'conforme', 'item', 'sgpmr',
    'solicitacao', 'solicitação', 'servico', 'serviço', 'atendimento',
    'apresenta', 'necessita', 'necessario', 'necessário', 'falta',
  };

  /// Remove acentos gráficos de uma string de forma determinística.
  static String removerAcentos(String texto) {
    var comAcento = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    var semAcento = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    var resultado = texto;
    for (int i = 0; i < comAcento.length; i++) {
      resultado = resultado.replaceAll(comAcento[i], semAcento[i]);
    }
    return resultado;
  }

  /// Normaliza texto em caixa baixa, sem acentos, sem pontuações e com espaços simples.
  static String normalizarTexto(String? texto) {
    if (texto == null || texto.isEmpty) return '';
    var s = removerAcentos(texto).toLowerCase();
    // Substituir pontuações e caracteres especiais por espaço
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // Normalizar múltiplos espaços em branco
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extrai tokens técnicos após aplicação de sinônimos e eliminação de stopwords.
  static List<String> extrairTokensTecnicos(String? texto) {
    final limpo = normalizarTexto(texto);
    if (limpo.isEmpty) return const [];

    final partes = limpo.split(' ');
    final resultado = <String>[];

    for (final parte in partes) {
      if (parte.length < 2) continue; // Descarta caracteres isolados
      if (stopwordsGeraisETecnicas.contains(parte)) continue;

      // Aplicar equivalência no dicionário técnico
      final termoMapeado = sinonimosTecnicos[parte] ?? parte;
      if (stopwordsGeraisETecnicas.contains(termoMapeado)) continue;

      if (!resultado.contains(termoMapeado)) {
        resultado.add(termoMapeado);
      }
    }
    return resultado;
  }

  /// Calcula a taxa de sobreposição de tokens técnicos (Overlap Szymkiewicz–Simpson).
  ///
  /// Fórmula: |A ∩ B| / min(|A|, |B|)
  static double calcularSobreposicaoTokens(
      List<String> tokensRef, List<String> tokensCandidato) {
    if (tokensRef.isEmpty || tokensCandidato.isEmpty) return 0.0;

    final setRef = tokensRef.toSet();
    final setCand = tokensCandidato.toSet();
    final intersecao = setRef.intersection(setCand);

    if (intersecao.isEmpty) return 0.0;

    final menorTamanho = setRef.length < setCand.length ? setRef.length : setCand.length;
    return (intersecao.length / menorTamanho).clamp(0.0, 1.0);
  }

  /// Extrai o prefixo do Vão / Bay a partir do local de instalação (Ex: H-S-STSA-DT1E01-1CR1-S601 -> H-S-STSA-DT1E01).
  static String? extrairPrefixoVao(String? localInstalacao) {
    if (localInstalacao == null || localInstalacao.trim().isEmpty) return null;
    final partes = localInstalacao.trim().split('-');
    if (partes.length >= 4) {
      return partes.take(4).join('-');
    }
    return null;
  }

  /// Extrai o prefixo da Subestação / Instalação (Ex: H-S-STSA-DT1E01-1CR1-S601 -> H-S-STSA).
  static String? extrairPrefixoSubestacao(String? localInstalacao) {
    if (localInstalacao == null || localInstalacao.trim().isEmpty) return null;
    final partes = localInstalacao.trim().split('-');
    if (partes.length >= 3) {
      return partes.take(3).join('-');
    }
    return null;
  }

  /// Extrai os 8 primeiros caracteres do local de instalação (identificador de subestação ou linha de transmissão).
  /// Ex: 'H-S-STSA-DT1E01-1CR1-S601' -> 'H-S-STSA'
  /// Ex: 'H-S-SIRE-DT1E01-1EQ1-RE01' -> 'H-S-SIRE'
  /// Ex: 'H-S-SBJS-DT1E01-1EQ1-RE01' -> 'H-S-SBJS'
  /// Ex: 'H-L-LT01-...' -> 'H-L-LT01'
  /// Regra mandatória: os 8 primeiros caracteres delimitam a instalação física/elétrica.
  /// Subestações ou linhas totalmente diferentes não justificam similaridade nem demandas compartilhadas.
  static String? extrairPrefixoInstalacao8(String? localInstalacao) {
    if (localInstalacao == null) return null;
    final limpo = localInstalacao.trim().toUpperCase();
    if (limpo.length >= 8) {
      return limpo.substring(0, 8);
    }
    return null;
  }

  /// Valida se duas notas pertencem à mesma instalação/subestação/linha de transmissão pelos 8 primeiros caracteres.
  /// Regra mandatória: subestações ou linhas de transmissão totalmente diferentes desqualificam a similaridade.
  static bool saoMesmaInstalacao8({
    required NotaSAP notaReferencia,
    required NotaSAP notaCandidata,
  }) {
    final prefRef = extrairPrefixoInstalacao8(notaReferencia.localInstalacao);
    final prefCand = extrairPrefixoInstalacao8(notaCandidata.localInstalacao);

    // 1. Se ambas possuem o prefixo de 8 caracteres, DEVEM ser estritamente iguais
    if (prefRef != null && prefCand != null) {
      return prefRef == prefCand;
    }

    // 2. Se a referência possui os 8 caracteres e a candidata tem local_instalacao com 8 chars mas diferente
    if (prefRef != null && prefCand != null && prefRef != prefCand) {
      return false;
    }

    // 3. Fallback por sigla da subestação (ex: TSA vs IRE vs BJS)
    final siglaRef = extrairSiglaSubestacao(notaReferencia);
    final siglaCand = extrairSiglaSubestacao(notaCandidata);
    if (siglaRef != null && siglaCand != null) {
      final compativel = siglaRef == siglaCand ||
          siglaRef.endsWith(siglaCand) ||
          siglaCand.endsWith(siglaRef);
      if (!compativel) return false;
    }

    // 4. Fallback por campo local (tabela locais)
    final locRef = notaReferencia.local?.trim().toUpperCase();
    final locCand = notaCandidata.local?.trim().toUpperCase();
    if (locRef != null && locRef.isNotEmpty && locCand != null && locCand.isNotEmpty) {
      if (locRef != locCand) return false;
    }

    return true;
  }

  /// Extrai o radical do vão elétrico a partir da sala, campo de ordenação ou descrição.
  /// Exemplos:
  /// - '01E1' -> '1E1'
  /// - '31E1-6' -> '1E1'
  /// - '11E1' -> '1E1'
  /// - '35T4-4' -> '5T4'
  static String? extrairRadicalVao(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final match = RegExp(r'([0-9]{1,2})([A-Z])([0-9]{1,2})').firstMatch(texto.toUpperCase());
    if (match != null) {
      final prefixoNum = match.group(1)!;
      final letra = match.group(2)!;
      final sufixoNum = match.group(3)!;
      final digitoVao = prefixoNum.substring(prefixoNum.length - 1);
      return '$digitoVao$letra$sufixoNum';
    }
    return null;
  }

  /// Extrai os 2º, 3º e 4º dígitos da sala da nota SAP (identificador do vão operativo).
  /// Regra do setor elétrico: o segundo, terceiro e quarto dígito da sala (ex: '31E1-6' -> '1E1', '01E1' -> '1E1')
  /// identificam o mesmo vão e configuram critério de similaridade técnica forte.
  static String? extrairDigitosVaoSala(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final limpo = texto.trim().toUpperCase().replaceAll(' ', '');
    if (limpo.length >= 4 && RegExp(r'^[0-9]').hasMatch(limpo)) {
      final sub = limpo.substring(1, 4);
      if (RegExp(r'^[0-9][A-Z][0-9]$').hasMatch(sub)) {
        return sub;
      }
    }
    return extrairRadicalVao(texto);
  }

  /// Extrai a sigla/mnemônico da subestação (ex: TSA, STSA, SOB, etc.)
  static String? extrairSiglaSubestacao(NotaSAP nota) {
    if (nota.local != null && nota.local!.trim().isNotEmpty) {
      return nota.local!.trim().toUpperCase();
    }
    final locInst = nota.localInstalacao?.trim().toUpperCase();
    if (locInst != null && locInst.isNotEmpty) {
      final partes = locInst.split('-');
      if (partes.length >= 3) {
        var sub = partes[2];
        if (sub.startsWith('S') && sub.length > 2) {
          sub = sub.substring(1); // 'STSA' -> 'TSA'
        }
        return sub;
      }
    }
    if (nota.descricao != null) {
      final match = RegExp(r'^([A-Z0-9]{3,4}):').firstMatch(nota.descricao!.trim().toUpperCase());
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  // ===========================================================================
  // 2. MOTOR DE SCORE DETERMINÍSTICO
  // ===========================================================================

  /// Avalia a similaridade entre uma nota de referência e uma nota candidata.
  NotaSapSimilar avaliarSimilaridade({
    required NotaSAP notaReferencia,
    required NotaSAP notaCandidata,
    List<TarefaHistoricaResumo> tarefas = const [],
    double? horasSapConfirmadas,
    NotaSapAnalise? analise,
    List<NotaSapMaterial> materiais = const [],
    int totalAnexos = 0,
  }) {
    double pontosEq = 0.0;
    double pontosLoc = 0.0;
    double pontosDesc = 0.0;
    double pontosCt = 0.0;
    double pontosTp = 0.0;
    final explicacoes = <String>[];

    // REGRA MANDATÓRIA (Critério de 8 Caracteres do Local de Instalação):
    // Os 8 primeiros caracteres delimitam a instalação física/elétrica (subestação ou linha de transmissão).
    // Subestações ou linhas totalmente diferentes não justificam similaridade.
    final mesmaInstalacao = saoMesmaInstalacao8(
      notaReferencia: notaReferencia,
      notaCandidata: notaCandidata,
    );

    if (!mesmaInstalacao) {
      final pRef = extrairPrefixoInstalacao8(notaReferencia.localInstalacao) ??
          extrairSiglaSubestacao(notaReferencia) ??
          'N/A';
      final pCand = extrairPrefixoInstalacao8(notaCandidata.localInstalacao) ??
          extrairSiglaSubestacao(notaCandidata) ??
          'N/A';
      return NotaSapSimilar(
        nota: notaCandidata,
        scoreTotal: 0.0,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        faixa: FaixaSimilaridade.descartada,
        evidencias: EvidenciaScore(
          pontosEquipamento: 0,
          pontosLocalInstalacao: 0,
          pontosDescricao: 0,
          pontosCentroTrabalho: 0,
          pontosTipo: 0,
          explicacoes: ['Instalação/Subestação diferente ($pCand ≠ $pRef)'],
          tokensCoincidentes: const [],
        ),
        tarefasVinculadas: tarefas,
        horasSapConfirmadas: horasSapConfirmadas,
        analise: analise,
        materiaisLevantados: materiais,
        totalAnexos: totalAnexos,
      );
    }

    // Peso da descrição: 25 pontos padrão ou 30 se tipo não for pontuado
    final pesoMaxDescricao = usarPontosTipo ? 25.0 : 30.0;

    // 1. Mesmo Equipamento (+40 pontos)
    final eqRef = notaReferencia.equipamento?.trim();
    final eqCand = notaCandidata.equipamento?.trim();
    final temMesmoEquipamento =
        eqRef != null && eqRef.isNotEmpty && eqCand != null && eqCand == eqRef;

    if (temMesmoEquipamento) {
      pontosEq = 40.0;
      explicacoes.add('+40 Mesmo equipamento ($eqCand)');
    }

    // 2. Localização Física: Vão Operativo, Sala e Subestação (Até 35 pontos)
    final locInstRef = notaReferencia.localInstalacao?.trim();
    final locInstCand = notaCandidata.localInstalacao?.trim();
    final subSiglaRef = extrairSiglaSubestacao(notaReferencia);
    final subSiglaCand = extrairSiglaSubestacao(notaCandidata);
    final mesmaSub = subSiglaRef != null &&
        subSiglaCand != null &&
        (subSiglaRef == subSiglaCand ||
            subSiglaRef.endsWith(subSiglaCand) ||
            subSiglaCand.endsWith(subSiglaRef));

    final vaoRef = extrairPrefixoVao(locInstRef);
    final vaoCand = extrairPrefixoVao(locInstCand);
    final mesmoVaoInst = vaoRef != null && vaoCand != null && vaoRef == vaoCand;

    final radRef = extrairDigitosVaoSala(notaReferencia.sala) ??
        extrairRadicalVao(notaReferencia.campoOrdenacao) ??
        extrairRadicalVao(notaReferencia.descricao);
    final radCand = extrairDigitosVaoSala(notaCandidata.sala) ??
        extrairRadicalVao(notaCandidata.campoOrdenacao) ??
        extrairRadicalVao(notaCandidata.descricao);
    final mesmoRadicalVao = radRef != null && radCand != null && radRef == radCand;

    final temMesmoVao = mesmoVaoInst ||
        (mesmoRadicalVao &&
            (mesmaSub ||
                notaReferencia.centroTrabalhoResponsavel ==
                    notaCandidata.centroTrabalhoResponsavel));

    bool temMesmoLocal = false;

    if (locInstRef != null &&
        locInstRef.isNotEmpty &&
        locInstCand != null &&
        locInstCand == locInstRef) {
      pontosLoc = 20.0;
      temMesmoLocal = true;
      explicacoes.add('+20 Mesmo local de instalação');
    } else if (temMesmoVao) {
      pontosLoc = 20.0;
      temMesmoLocal = true;
      final nomeVao = mesmoVaoInst ? vaoCand : 'Vão $radCand';
      explicacoes.add('+20 Mesmo vão operativo ($nomeVao)');
    } else {
      final salaRef = notaReferencia.sala?.trim();
      final salaCand = notaCandidata.sala?.trim();
      if (salaRef != null && salaRef.isNotEmpty && salaCand != null && salaCand == salaRef) {
        pontosLoc = 15.0;
        temMesmoLocal = true;
        explicacoes.add('+15 Mesma sala/vão ($salaCand)');
      } else if (mesmaSub) {
        pontosLoc = 10.0;
        temMesmoLocal = true;
        final nomeSub = (notaCandidata.local != null && notaCandidata.local!.isNotEmpty)
            ? notaCandidata.local!
            : subSiglaCand;
        explicacoes.add('+10 Mesma subestação/local ($nomeSub)');
      }
    }

    // 3. Mesmo Centro de Trabalho (+10 pontos)
    final ctRef = notaReferencia.centroTrabalhoResponsavel?.trim();
    final ctCand = notaCandidata.centroTrabalhoResponsavel?.trim();
    final temMesmoCt = ctRef != null && ctRef.isNotEmpty && ctCand != null && ctCand == ctRef;

    if (temMesmoCt) {
      pontosCt = 10.0;
      explicacoes.add('+10 Mesmo centro de trabalho ($ctCand)');
    }

    // 4. Mesmo Tipo de Nota (5 pontos opcionais calibráveis)
    if (usarPontosTipo) {
      final tpRef = notaReferencia.tipo?.trim();
      final tpCand = notaCandidata.tipo?.trim();
      if (tpRef != null && tpRef.isNotEmpty && tpCand != null && tpCand == tpRef) {
        pontosTp = 5.0;
        explicacoes.add('+5 Mesmo tipo de nota SAP ($tpCand)');
      }
    }

    // 5. Similaridade Textual da Descrição / Avaria
    final tokensRef = extrairTokensTecnicos(notaReferencia.descricao);
    final tokensCand = extrairTokensTecnicos(notaCandidata.descricao);
    final taxaSobreposicao = calcularSobreposicaoTokens(tokensRef, tokensCand);
    final tokensCoincidentes =
        tokensRef.toSet().intersection(tokensCand.toSet()).toList();

    if (taxaSobreposicao > 0) {
      var pontosCalculados = taxaSobreposicao * pesoMaxDescricao;

      // REGRA DE SEGURANÇA TEXTUAL (Seção 8):
      // Se não houver vínculo de equipamento, local ou centro, limita a contribuição a 10 pontos.
      if (!temMesmoEquipamento && !temMesmoLocal && !temMesmoCt) {
        if (pontosCalculados > 10.0) {
          pontosCalculados = 10.0;
        }
      }

      pontosDesc = double.parse(pontosCalculados.toStringAsFixed(1));
      if (pontosDesc > 0) {
        final pct = (taxaSobreposicao * 100).toStringAsFixed(0);
        explicacoes.add(
            '+${pontosDesc.toStringAsFixed(0)} Falha semelhante ($pct% termos em comum: ${tokensCoincidentes.join(", ")})');
      }
    }

    final evidencia = EvidenciaScore(
      pontosEquipamento: pontosEq,
      pontosLocalInstalacao: pontosLoc,
      pontosDescricao: pontosDesc,
      pontosCentroTrabalho: pontosCt,
      pontosTipo: pontosTp,
      explicacoes: explicacoes,
      tokensCoincidentes: tokensCoincidentes,
    );

    final scoreTotal = evidencia.scoreTotal;
    final bool temVinculoVaoOuAtivo = temMesmoEquipamento || (temMesmoVao && mesmaSub);
    final faixa = (scoreTotal < 40.0 && temVinculoVaoOuAtivo)
        ? FaixaSimilaridade.fraca
        : FaixaSimilaridade.fromScore(scoreTotal);

    // SEÇÃO 4: DUAS CLASSIFICAÇÕES DIFERENTES
    // Se for o mesmo equipamento mas a similaridade textual de falha for < 30%,
    // classifica como Histórico do Mesmo Ativo (intervenção tecnicamente distinta).
    final TipoClassificacaoSimilaridade classificacao;
    if (temMesmoEquipamento && taxaSobreposicao < 0.30) {
      classificacao = TipoClassificacaoSimilaridade.historicoMesmoAtivo;
    } else {
      classificacao = TipoClassificacaoSimilaridade.ocorrenciaSemelhante;
    }

    return NotaSapSimilar(
      nota: notaCandidata,
      scoreTotal: scoreTotal,
      classificacao: classificacao,
      faixa: faixa,
      evidencias: evidencia,
      tarefasVinculadas: tarefas,
      horasSapConfirmadas: horasSapConfirmadas,
      analise: analise,
      materiaisLevantados: materiais,
      totalAnexos: totalAnexos,
    );
  }

  // ===========================================================================
  // 3. ESTATÍSTICAS DETERMINÍSTICAS (MEDIANA DE HORAS E EQUIPE)
  // ===========================================================================

  /// Calcula estatísticas consolidadas de horas e executores com base nas ocorrências semelhantes.
  static EstatisticasTempoEquipe calcularEstatisticas(
      List<NotaSapSimilar> ocorrencias) {
    final amostrasHoras = <double>[];
    String fonteHoras = 'Nenhuma';
    int totalConfirmadasSap = 0;
    int totalTaskFlow = 0;

    final amostrasEquipe = <int>[];

    for (final oc in ocorrencias) {
      // 1. Horas SAP confirmadas têm prioridade máxima
      if (oc.horasSapConfirmadas != null && oc.horasSapConfirmadas! > 0) {
        amostrasHoras.add(oc.horasSapConfirmadas!);
        totalConfirmadasSap++;
      } else {
        // 2. Horas executadas no TaskFlow
        for (final t in oc.tarefasVinculadas) {
          if (t.horasExecutadas != null && t.horasExecutadas! > 0) {
            amostrasHoras.add(t.horasExecutadas!);
            totalTaskFlow++;
            break;
          }
        }
      }

      // Amostra de equipe (executores da tarefa vinculada)
      for (final t in oc.tarefasVinculadas) {
        if (t.totalExecutores > 0) {
          amostrasEquipe.add(t.totalExecutores);
          break;
        }
      }
    }

    if (totalConfirmadasSap > 0 && totalTaskFlow == 0) {
      fonteHoras = 'Horas SAP confirmadas';
    } else if (totalTaskFlow > 0 && totalConfirmadasSap == 0) {
      fonteHoras = 'Duração registrada TaskFlow';
    } else if (totalConfirmadasSap > 0 && totalTaskFlow > 0) {
      fonteHoras = 'Horas SAP + Duração TaskFlow';
    }

    double? medianaHoras;
    double? minHoras;
    double? maxHoras;

    if (amostrasHoras.isNotEmpty) {
      amostrasHoras.sort();
      minHoras = amostrasHoras.first;
      maxHoras = amostrasHoras.last;
      medianaHoras = calcularMedianaNumerica(amostrasHoras);
    }

    int? medianaEquipe;
    int? minEquipe;
    int? maxEquipe;

    if (amostrasEquipe.isNotEmpty) {
      amostrasEquipe.sort();
      minEquipe = amostrasEquipe.first;
      maxEquipe = amostrasEquipe.last;
      final m = calcularMedianaNumerica(
          amostrasEquipe.map((e) => e.toDouble()).toList());
      medianaEquipe = m.round();
    }

    return EstatisticasTempoEquipe(
      duracaoMedianaHoras: medianaHoras != null
          ? double.parse(medianaHoras.toStringAsFixed(1))
          : null,
      duracaoMinimaHoras: minHoras != null
          ? double.parse(minHoras.toStringAsFixed(1))
          : null,
      duracaoMaximaHoras: maxHoras != null
          ? double.parse(maxHoras.toStringAsFixed(1))
          : null,
      totalAmostrasHoras: amostrasHoras.length,
      fonteHoras: fonteHoras,
      equipeMedianaTecnicos: medianaEquipe,
      equipeMinimaTecnicos: minEquipe,
      equipeMaximaTecnicos: maxEquipe,
      totalAmostrasEquipe: amostrasEquipe.length,
    );
  }

  /// Calcula a mediana exata de uma lista ordenada de valores numéricos.
  static double calcularMedianaNumerica(List<double> valoresOrdenados) {
    if (valoresOrdenados.isEmpty) return 0.0;
    final n = valoresOrdenados.length;
    if (n % 2 == 1) {
      return valoresOrdenados[n ~/ 2];
    } else {
      return (valoresOrdenados[n ~/ 2 - 1] + valoresOrdenados[n ~/ 2]) / 2.0;
    }
  }

  // ===========================================================================
  // 4. FREQUÊNCIA DE MATERIAIS LEVANTADOS
  // ===========================================================================

  /// Agrupa materiais das ocorrências semelhantes por descrição e calcula sua frequência.
  static List<MaterialFrequencia> levantarMateriaisFrequentes(
      List<NotaSapSimilar> ocorrencias) {
    final contagem = <String, _MaterialAcc>{};
    int totalAnalisesAvaliadas = 0;

    for (final oc in ocorrencias) {
      if (oc.materiaisLevantados.isNotEmpty) {
        totalAnalisesAvaliadas++;
        final vistosNestaNota = <String>{};

        for (final m in oc.materiaisLevantados) {
          final chave = m.descricao.trim().toLowerCase();
          if (chave.isEmpty) continue;

          if (!vistosNestaNota.contains(chave)) {
            vistosNestaNota.add(chave);
            final acc = contagem.putIfAbsent(
              chave,
              () => _MaterialAcc(
                codigoSap: m.codigoSap,
                descricao: m.descricao.trim(),
                unidade: m.unidade,
              ),
            );
            acc.quantidadeOcorrencias++;
          }
        }
      }
    }

    final lista = contagem.values.map((acc) {
      return MaterialFrequencia(
        codigoSap: acc.codigoSap,
        descricao: acc.descricao,
        quantidadeOcorrencias: acc.quantidadeOcorrencias,
        totalAnalisesAvaliadas: totalAnalisesAvaliadas > 0 ? totalAnalisesAvaliadas : 1,
        unidade: acc.unidade,
      );
    }).toList();

    // Ordena por maior frequência
    lista.sort((a, b) => b.quantidadeOcorrencias.compareTo(a.quantidadeOcorrencias));
    return lista;
  }

  // ===========================================================================
  // 5. DEMANDAS ABERTAS RELACIONADAS (CANDIDATAS A EXECUÇÃO CONJUNTA)
  // ===========================================================================

  /// Filtra notas abertas (não concluídas) candidatas a intervenção conjunta.
  static List<DemandaAbertaRelacionada> identificarDemandasAbertas({
    required NotaSAP notaReferencia,
    required List<NotaSAP> notasCandidatas,
  }) {
    final resultado = <DemandaAbertaRelacionada>[];

    for (final nota in notasCandidatas) {
      // Excluir a própria nota
      if (nota.id == notaReferencia.id || nota.nota == notaReferencia.nota) {
        continue;
      }

      // Verificar se está aberta (status_sistema contém MSPN ou MSPR e não contém CONC/ENC)
      final status = (nota.statusSistema ?? '').toUpperCase();
      final estaAberta = (status.contains('MSPN') || status.contains('MSPR')) &&
          !status.contains('CONC') &&
          !status.contains('ENCE') &&
          !status.contains('CANC');

      if (!estaAberta) continue;

      // CRITÉRIO MANDATÓRIO (8 Caracteres do Local de Instalação):
      // Apenas notas da mesma instalação/subestação/linha de transmissão podem ser demandas relacionadas.
      final mesmaInstalacao = saoMesmaInstalacao8(
        notaReferencia: notaReferencia,
        notaCandidata: nota,
      );
      if (!mesmaInstalacao) continue;

      final eqRef = notaReferencia.equipamento?.trim();
      final eqCand = nota.equipamento?.trim();
      final temMesmoEquipamento =
          eqRef != null && eqRef.isNotEmpty && eqCand != null && eqCand == eqRef;

      final locRef = notaReferencia.localInstalacao?.trim();
      final locCand = nota.localInstalacao?.trim();
      final temMesmoLocalInstalacao =
          locRef != null && locRef.isNotEmpty && locCand != null && locCand == locRef;

      final vaoRef = extrairPrefixoVao(locRef);
      final vaoCand = extrairPrefixoVao(locCand);
      final radRef = extrairDigitosVaoSala(notaReferencia.sala) ??
          extrairRadicalVao(notaReferencia.campoOrdenacao) ??
          extrairRadicalVao(notaReferencia.descricao);
      final radCand = extrairDigitosVaoSala(nota.sala) ??
          extrairRadicalVao(nota.campoOrdenacao) ??
          extrairRadicalVao(nota.descricao);
      final subRef = extrairPrefixoSubestacao(locRef);
      final subCand = extrairPrefixoSubestacao(locCand);
      final subSiglaRef = extrairSiglaSubestacao(notaReferencia);
      final subSiglaCand = extrairSiglaSubestacao(nota);
      final mesmaSub = subSiglaRef != null &&
          subSiglaCand != null &&
          (subSiglaRef == subSiglaCand ||
              subSiglaRef.endsWith(subSiglaCand) ||
              subSiglaCand.endsWith(subSiglaRef));

      final mesmaRegionalOuSub = mesmaSub ||
          (subRef != null && subCand != null && subRef == subCand) ||
          (notaReferencia.centroTrabalhoResponsavel != null &&
              notaReferencia.centroTrabalhoResponsavel == nota.centroTrabalhoResponsavel);

      final temMesmoVao = (vaoRef != null && vaoCand != null && vaoRef == vaoCand) ||
          (radRef != null && radCand != null && radRef == radCand && mesmaRegionalOuSub);

      final salaRef = notaReferencia.sala?.trim();
      final salaCand = nota.sala?.trim();
      final temMesmaSala =
          salaRef != null && salaRef.isNotEmpty && salaCand != null && salaCand == salaRef;

      // REGRA MANDATÓRIA:
      // "SÓ A SUBESTACAO E O MESMO CENTRO DE TRABALHO NAO DEVE SER DEMANDA RELACIONADA"
      // Para ser demanda relacionada (candidata a intervenção/desligamento conjunto),
      // DEVE obrigatoriamente haver vínculo físico/operativo real no vão ou ativo:
      // mesmo vão operativo, mesmo equipamento, mesmo local de instalação ou mesma sala/vão.
      final bool temVinculoOperativo = temMesmoEquipamento ||
          temMesmoLocalInstalacao ||
          temMesmoVao ||
          temMesmaSala;

      if (!temVinculoOperativo) {
        continue;
      }

      final criterios = <String>[];
      if (temMesmoEquipamento) {
        criterios.add('Mesmo equipamento ($eqCand)');
      }

      if (temMesmoLocalInstalacao) {
        criterios.add('Mesmo local de instalação');
      } else if (vaoRef != null && vaoCand != null && vaoRef == vaoCand) {
        criterios.add('Mesmo vão operativo ($vaoCand)');
      } else if (radRef != null && radCand != null && radRef == radCand && mesmaRegionalOuSub) {
        criterios.add('Mesmo vão operativo (Vão $radCand)');
      }

      if (temMesmaSala) {
        criterios.add('Mesma sala/vão ($salaCand)');
      }

      // Critérios complementares de contexto (exibidos apenas quando há vínculo operativo)
      if (mesmaSub) {
        criterios.add('Mesma subestação ($subSiglaCand)');
      } else if (subRef != null && subCand != null && subRef == subCand) {
        criterios.add('Mesma subestação ($subCand)');
      } else if (notaReferencia.local != null &&
          nota.local != null &&
          nota.local == notaReferencia.local) {
        criterios.add('Mesmo local/subestação (${nota.local})');
      }

      final ctRef = notaReferencia.centroTrabalhoResponsavel?.trim();
      final ctCand = nota.centroTrabalhoResponsavel?.trim();
      if (ctRef != null && ctRef.isNotEmpty && ctCand != null && ctCand == ctRef) {
        criterios.add('Mesmo centro de trabalho ($ctCand)');
      }

      if (criterios.isNotEmpty) {
        resultado.add(
          DemandaAbertaRelacionada(
            nota: nota,
            motivo: criterios.join(' • '),
            criteriosCoincidentes: criterios,
          ),
        );
      }
    }

    // Ordenação por relevância operacional: Vão/Equipamento > Quantidade de critérios > Recência
    resultado.sort((a, b) {
      final aTemEqOuVao = a.criteriosCoincidentes.any((c) =>
          c.contains('equipamento') || c.contains('vão operativo') || c.contains('local de instalação'));
      final bTemEqOuVao = b.criteriosCoincidentes.any((c) =>
          c.contains('equipamento') || c.contains('vão operativo') || c.contains('local de instalação'));
      if (aTemEqOuVao && !bTemEqOuVao) return -1;
      if (!aTemEqOuVao && bTemEqOuVao) return 1;

      final compCriterios = b.criteriosCoincidentes.length.compareTo(a.criteriosCoincidentes.length);
      if (compCriterios != 0) return compCriterios;

      final dataA = a.nota.criadoEm ?? DateTime(1970);
      final dataB = b.nota.criadoEm ?? DateTime(1970);
      return dataB.compareTo(dataA);
    });

    return resultado;
  }

  // ===========================================================================
  // 6. CONSULTA COMPLETA COM FUNIL NO SUPABASE
  // ===========================================================================

  /// Executa o funil de busca e scoring determinístico para uma Nota SAP.
  Future<ResultadoSimilaridadeNotaSap> buscarSimilaridades({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    // 1. Verificar Cache
    final agora = DateTime.now();
    if (!forceRefresh && _cache.containsKey(notaReferencia.id)) {
      final entrada = _cache[notaReferencia.id]!;
      if (agora.difference(entrada.timestamp) < _cacheTtl) {
        return entrada.resultado;
      }
    }

    try {
      // 2. Funil de Busca de Candidatos no Supabase (máx 50)
      final candidatosBrutos = await _buscarCandidatosNoSupabase(notaReferencia);

      // 3. Excluir a própria Nota (Seção 12)
      final candidatosValidos = candidatosBrutos
          .where((n) => n.id != notaReferencia.id && n.nota != notaReferencia.nota)
          .toList();

      if (candidatosValidos.isEmpty) {
        final vazio = ResultadoSimilaridadeNotaSap(
          notaReferencia: notaReferencia,
          calculadoEm: agora,
        );
        _cache[notaReferencia.id] = _CacheEntry(vazio, agora);
        return vazio;
      }

      // 4. Carregar vínculos das notas candidatas (tarefas, análises, materiais, anexos)
      final idsNotas = candidatosValidos.map((n) => n.id).toList();
      final tarefasMap = await _carregarTarefasVinculadas(idsNotas);
      final analisesMap = await _carregarAnalises(idsNotas);
      final materiaisMap = await _carregarMateriais(idsNotas);
      final anexosCountMap = await _contarAnexos(idsNotas);
      final horasSapMap = await _carregarHorasSap(candidatosValidos);

      // 5. Avaliação do Score Determinístico
      final todasAvaliadas = <NotaSapSimilar>[];
      for (final cand in candidatosValidos) {
        final similar = avaliarSimilaridade(
          notaReferencia: notaReferencia,
          notaCandidata: cand,
          tarefas: tarefasMap[cand.id] ?? const [],
          horasSapConfirmadas: horasSapMap[cand.ordem ?? ''],
          analise: analisesMap[cand.id],
          materiais: materiaisMap[cand.id] ?? const [],
          totalAnexos: anexosCountMap[cand.id] ?? 0,
        );
        todasAvaliadas.add(similar);
      }

      // 6. Filtragem e Descarte (< 40 pts descartado - Seção 10)
      final relevantes = todasAvaliadas
          .where((s) => s.faixa != FaixaSimilaridade.descartada)
          .toList();

      // 7. Ordenação: Score DESC, Recência da Nota DESC (Seção 13)
      relevantes.sort((a, b) {
        final compScore = b.scoreTotal.compareTo(a.scoreTotal);
        if (compScore != 0) return compScore;
        final dataA = a.nota.criadoEm ?? DateTime(1970);
        final dataB = b.nota.criadoEm ?? DateTime(1970);
        return dataB.compareTo(dataA);
      });

      // 8. Separação: Ocorrências Semelhantes vs Histórico do Mesmo Ativo (Seção 4)
      final semelhantes = relevantes
          .where((s) =>
              s.classificacao == TipoClassificacaoSimilaridade.ocorrenciaSemelhante)
          .toList();

      final historicoAtivo = relevantes
          .where((s) =>
              s.classificacao == TipoClassificacaoSimilaridade.historicoMesmoAtivo)
          .toList();

      // 9. Estatísticas e Frequência de Materiais
      final estatisticas = calcularEstatisticas(semelhantes);
      final materiaisFrequentes = levantarMateriaisFrequentes(semelhantes);

      // 10. Demandas Abertas Relacionadas (Seção 23)
      final demandasAbertas = identificarDemandasAbertas(
        notaReferencia: notaReferencia,
        notasCandidatas: candidatosValidos,
      );

      // 11. Top 5 inicial para limite visual (Seção 14)
      final top5 = semelhantes.take(5).toList();

      final resultado = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaReferencia,
        ocorrenciasSemelhantes: top5,
        todasOcorrencias: semelhantes,
        historicoMesmoAtivo: historicoAtivo,
        estatisticas: estatisticas,
        materiaisFrequentes: materiaisFrequentes,
        demandasAbertasRelacionadas: demandasAbertas,
        calculadoEm: agora,
      );

      _cache[notaReferencia.id] = _CacheEntry(resultado, agora);
      return resultado;
    } catch (e) {
      debugPrint('[NotaSapSimilaridadeService] Erro ao buscar similaridades: $e');
      // Resiliência: retorna vazio sem quebrar
      return ResultadoSimilaridadeNotaSap(
        notaReferencia: notaReferencia,
        calculadoEm: agora,
      );
    }
  }

  /// Invalida o cache de uma Nota de referência específica.
  void invalidarCache(String notaId) {
    _cache.remove(notaId);
  }

  /// Limpa todo o cache de similaridade.
  void limparTodoCache() {
    _cache.clear();
  }

  // ===========================================================================
  // 7. MÉTODOS INTERNOS DE BUSCA NO SUPABASE
  // ===========================================================================

  Future<List<NotaSAP>> _buscarCandidatosNoSupabase(NotaSAP ref) async {
    final eq = ref.equipamento?.trim();
    final locInst = ref.localInstalacao?.trim();
    final ct = ref.centroTrabalhoResponsavel?.trim();
    final vaoRef = extrairPrefixoVao(locInst);
    final prefixo8 = extrairPrefixoInstalacao8(locInst) ?? extrairPrefixoSubestacao(locInst);
    final subRef = prefixo8;
    final subSigla = extrairSiglaSubestacao(ref);

    final candidatosMap = <String, NotaSAP>{};

    // Consulta 1: Mesmo Equipamento (alta prioridade, na mesma instalação)
    if (eq != null && eq.isNotEmpty) {
      try {
        var queryEq = _supabase.from('notas_sap').select().eq('equipamento', eq);
        if (prefixo8 != null && prefixo8.isNotEmpty) {
          queryEq = queryEq.ilike('local_instalacao', '$prefixo8%');
        }
        final resEq = await queryEq.order('criado_em', ascending: false).limit(50);
        for (final map in resEq) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap[nota.id] = nota;
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 1 (Eq): $e');
      }
    }

    // Consulta 2: Mesmo Local de Instalação Exato
    if (locInst != null && locInst.isNotEmpty && candidatosMap.length < 50) {
      try {
        final limiteRestante = 50 - candidatosMap.length;
        final resLoc = await _supabase
            .from('notas_sap')
            .select()
            .eq('local_instalacao', locInst)
            .order('criado_em', ascending: false)
            .limit(limiteRestante);
        for (final map in resLoc) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap.putIfAbsent(nota.id, () => nota);
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 2 (LocInst): $e');
      }
    }

    // Consulta 3: Mesmo Vão / Bay Operativo (Ex: H-S-STSA-DT1E01%)
    if (vaoRef != null && vaoRef.isNotEmpty && candidatosMap.length < 50) {
      try {
        final limiteRestante = 50 - candidatosMap.length;
        final resVao = await _supabase
            .from('notas_sap')
            .select()
            .ilike('local_instalacao', '$vaoRef%')
            .order('criado_em', ascending: false)
            .limit(limiteRestante);
        for (final map in resVao) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap.putIfAbsent(nota.id, () => nota);
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 3 (Vao): $e');
      }
    }

    // Consulta 3.1: Mesmo Radical de Vão / Dígitos 2, 3 e 4 da Sala (na mesma instalação)
    final radRef = extrairDigitosVaoSala(ref.sala) ??
        extrairRadicalVao(ref.campoOrdenacao) ??
        extrairRadicalVao(ref.descricao);
    if (radRef != null && radRef.isNotEmpty && candidatosMap.length < 50) {
      if (prefixo8 != null && prefixo8.isNotEmpty) {
        try {
          final limiteRestante = 50 - candidatosMap.length;
          final resRad = await _supabase
              .from('notas_sap')
              .select()
              .ilike('local_instalacao', '$prefixo8%')
              .or('sala.ilike.%$radRef%,descricao.ilike.%$radRef%,campo_ordenacao.ilike.%$radRef%')
              .order('criado_em', ascending: false)
              .limit(limiteRestante);
          for (final map in resRad) {
            final nota = NotaSAP.fromMap(map);
            candidatosMap.putIfAbsent(nota.id, () => nota);
          }
        } catch (e) {
          debugPrint('[NotaSapSimilaridadeService] Erro Consulta 3.1 (Prefixo8): $e');
        }
      } else if (subSigla != null && subSigla.isNotEmpty) {
        try {
          final limiteRestante = 50 - candidatosMap.length;
          final resRadLocal = await _supabase
              .from('notas_sap')
              .select()
              .eq('local', subSigla)
              .or('sala.ilike.%$radRef%,descricao.ilike.%$radRef%,campo_ordenacao.ilike.%$radRef%')
              .order('criado_em', ascending: false)
              .limit(limiteRestante);
          for (final map in resRadLocal) {
            final nota = NotaSAP.fromMap(map);
            candidatosMap.putIfAbsent(nota.id, () => nota);
          }
        } catch (e) {
          debugPrint('[NotaSapSimilaridadeService] Erro Consulta 3.1 (Local): $e');
        }
      }

      // Fallback: busca por sala MAS sempre restrita à mesma instalação
      if (candidatosMap.length < 40 && (prefixo8 != null || subSigla != null)) {
        try {
          final limiteRestante = 50 - candidatosMap.length;
          var qSalaDireta = _supabase.from('notas_sap').select().ilike('sala', '%$radRef%');
          if (prefixo8 != null && prefixo8.isNotEmpty) {
            qSalaDireta = qSalaDireta.ilike('local_instalacao', '$prefixo8%');
          } else if (subSigla != null && subSigla.isNotEmpty) {
            qSalaDireta = qSalaDireta.eq('local', subSigla);
          }
          final resSalaDireta = await qSalaDireta.order('criado_em', ascending: false).limit(limiteRestante);
          for (final map in resSalaDireta) {
            final nota = NotaSAP.fromMap(map);
            candidatosMap.putIfAbsent(nota.id, () => nota);
          }
        } catch (e) {
          debugPrint('[NotaSapSimilaridadeService] Erro Consulta 3.1 (Sala Direta): $e');
        }
      }
    }

    // Consulta 4: Mesma Sala / Vão (se informado) - sempre restrita à mesma instalação
    final salaRef = ref.sala?.trim();
    if (salaRef != null && salaRef.isNotEmpty && candidatosMap.length < 40 && (prefixo8 != null || subSigla != null)) {
      try {
        final limiteRestante = 50 - candidatosMap.length;
        var qSala = _supabase.from('notas_sap').select().eq('sala', salaRef);
        if (prefixo8 != null && prefixo8.isNotEmpty) {
          qSala = qSala.ilike('local_instalacao', '$prefixo8%');
        } else if (subSigla != null && subSigla.isNotEmpty) {
          qSala = qSala.ilike('local_instalacao', '%$subSigla%');
        }
        final resSala = await qSala.order('criado_em', ascending: false).limit(limiteRestante);
        for (final map in resSala) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap.putIfAbsent(nota.id, () => nota);
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 4 (Sala): $e');
      }
    }

    // Consulta 5: Termos de avaria na Mesma Subestação
    final tokensAvaria = extrairTokensTecnicos(ref.descricao);
    if (tokensAvaria.isNotEmpty && subRef != null && subRef.isNotEmpty && candidatosMap.length < 40) {
      try {
        final termoPrincipal = tokensAvaria.first;
        final limiteRestante = 50 - candidatosMap.length;
        final resTermo = await _supabase
            .from('notas_sap')
            .select()
            .ilike('local_instalacao', '$subRef%')
            .ilike('descricao', '%$termoPrincipal%')
            .order('criado_em', ascending: false)
            .limit(limiteRestante);
        for (final map in resTermo) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap.putIfAbsent(nota.id, () => nota);
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 5 (Avaria): $e');
      }
    }

    // Consulta 6: Centro de Trabalho com subestação (Fallback controlado)
    if (candidatosMap.length < 30 && ct != null && ct.isNotEmpty) {
      try {
        final limiteRestante = 50 - candidatosMap.length;
        var query = _supabase.from('notas_sap').select().eq('centro_trabalho_responsavel', ct);
        if (subRef != null && subRef.isNotEmpty) {
          query = query.ilike('local_instalacao', '$subRef%');
        }
        final resCt = await query.order('criado_em', ascending: false).limit(limiteRestante);
        for (final map in resCt) {
          final nota = NotaSAP.fromMap(map);
          candidatosMap.putIfAbsent(nota.id, () => nota);
        }
      } catch (e) {
        debugPrint('[NotaSapSimilaridadeService] Erro Consulta 6 (CT): $e');
      }
    }

    // FILTRO MANDATÓRIO FINAL: Garante estritamente a mesma instalação/subestação pelos 8 primeiros caracteres
    return candidatosMap.values.where((cand) {
      if (cand.id == ref.id || cand.nota == ref.nota) return false;
      return saoMesmaInstalacao8(notaReferencia: ref, notaCandidata: cand);
    }).toList();
  }

  Future<Map<String, List<TarefaHistoricaResumo>>> _carregarTarefasVinculadas(
      List<String> notaIds) async {
    final mapa = <String, List<TarefaHistoricaResumo>>{};
    if (notaIds.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id, task_id, tasks(id, tarefa, status, horas_executadas, horas_previstas, executores, data_inicio, data_fim)')
          .inFilter('nota_sap_id', notaIds);

      for (final item in res) {
        final notaId = item['nota_sap_id']?.toString();
        final taskData = item['tasks'] as Map<String, dynamic>?;
        if (notaId != null && taskData != null) {
          final executoresList = <String>[];
          final rawExec = taskData['executores'];
          if (rawExec is List) {
            executoresList.addAll(rawExec.map((e) => e.toString()));
          }

          final resumo = TarefaHistoricaResumo(
            id: taskData['id']?.toString() ?? '',
            tarefaNome: taskData['tarefa']?.toString(),
            status: taskData['status']?.toString() ?? '',
            totalExecutores: executoresList.length,
            executores: executoresList,
            horasExecutadas: taskData['horas_executadas'] != null
                ? (taskData['horas_executadas'] as num).toDouble()
                : null,
            horasPrevistas: taskData['horas_previstas'] != null
                ? (taskData['horas_previstas'] as num).toDouble()
                : null,
            dataInicio: taskData['data_inicio'] != null
                ? DateTime.tryParse(taskData['data_inicio'].toString())
                : null,
            dataFim: taskData['data_fim'] != null
                ? DateTime.tryParse(taskData['data_fim'].toString())
                : null,
          );
          mapa.putIfAbsent(notaId, () => []).add(resumo);
        }
      }
    } catch (_) {}
    return mapa;
  }

  Future<Map<String, NotaSapAnalise>> _carregarAnalises(List<String> notaIds) async {
    final mapa = <String, NotaSapAnalise>{};
    if (notaIds.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('notas_sap_analises')
          .select()
          .inFilter('nota_sap_id', notaIds);

      for (final map in res) {
        final analise = NotaSapAnalise.fromMap(map);
        mapa[analise.notaSapId] = analise;
      }
    } catch (_) {}
    return mapa;
  }

  Future<Map<String, List<NotaSapMaterial>>> _carregarMateriais(
      List<String> notaIds) async {
    final mapa = <String, List<NotaSapMaterial>>{};
    if (notaIds.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('notas_sap_analise_materiais')
          .select()
          .inFilter('nota_sap_id', notaIds);

      for (final map in res) {
        final mat = NotaSapMaterial.fromMap(map);
        mapa.putIfAbsent(mat.notaSapId, () => []).add(mat);
      }
    } catch (_) {}
    return mapa;
  }

  Future<Map<String, int>> _contarAnexos(List<String> notaIds) async {
    final mapa = <String, int>{};
    if (notaIds.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('notas_sap_anexos')
          .select('nota_sap_id')
          .inFilter('nota_sap_id', notaIds);

      for (final item in res) {
        final id = item['nota_sap_id']?.toString();
        if (id != null) {
          mapa[id] = (mapa[id] ?? 0) + 1;
        }
      }
    } catch (_) {}
    return mapa;
  }

  Future<Map<String, double>> _carregarHorasSap(List<NotaSAP> notas) async {
    final mapa = <String, double>{};
    final ordens = notas
        .map((n) => n.ordem?.trim())
        .where((o) => o != null && o.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (ordens.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('horas_sap')
          .select('ordem, trabalho_real')
          .inFilter('ordem', ordens);

      for (final item in res) {
        final ordem = item['ordem']?.toString();
        final horas = item['trabalho_real'] != null
            ? (item['trabalho_real'] as num).toDouble()
            : 0.0;
        if (ordem != null) {
          mapa[ordem] = (mapa[ordem] ?? 0.0) + horas;
        }
      }
    } catch (_) {}
    return mapa;
  }
}

class _CacheEntry {
  final ResultadoSimilaridadeNotaSap resultado;
  final DateTime timestamp;

  _CacheEntry(this.resultado, this.timestamp);
}

class _MaterialAcc {
  final String? codigoSap;
  final String descricao;
  final String unidade;
  int quantidadeOcorrencias = 0;

  _MaterialAcc({
    this.codigoSap,
    required this.descricao,
    required this.unidade,
  });
}
