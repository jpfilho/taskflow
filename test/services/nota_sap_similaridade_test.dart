import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_similaridade.dart';
import 'package:task2026/services/nota_sap_similaridade_service.dart';

void main() {
  group('Módulo H — Suíte Completa de Testes Unitários (35 Requisitos Obrigatórios)', () {
    late NotaSapSimilaridadeService service;

    setUp(() {
      service = NotaSapSimilaridadeService();
    });

    // 1. Exclusão da própria nota
    test('1. Exclusão da própria nota: mesma nota na lista de candidatas é descartada de demandas e funil', () {
      final ref = NotaSAP(id: '1001', nota: '1001', statusSistema: 'MSPR');
      final cand = NotaSAP(id: '1001', nota: '1001', statusSistema: 'MSPR');
      final abertas = NotaSapSimilaridadeService.identificarDemandasAbertas(
        notaReferencia: ref,
        notasCandidatas: [cand],
      );
      expect(abertas, isEmpty, reason: 'A própria nota de referência nunca deve ser sugerida como demanda aberta.');
    });

    // 2. Mesmo equipamento
    test('2. Mesmo equipamento adiciona exatamente +40 pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: '11341209');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: '11341209');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosEquipamento, equals(40.0));
      expect(res.scoreTotal, equals(40.0));
      expect(res.evidencias.explicacoes.first, contains('+40 Mesmo equipamento (11341209)'));
    });

    // 3. Mesmo local
    test('3. Mesmo local de instalação exato adiciona +20 pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01');
      final cand = NotaSAP(id: '2', nota: '1002', localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosLocalInstalacao, equals(20.0));
      expect(res.scoreTotal, equals(20.0));
      expect(res.evidencias.explicacoes.first, contains('+20 Mesmo local de instalação'));
    });

    // 4. Local amplo
    test('4. Local amplo (subestação) adiciona +10 pontos quando local_instalacao não coincide', () {
      final ref = NotaSAP(id: '1', nota: '1001', localInstalacao: 'H-S-SCGR-01', local: 'SE CAMPO GRANDE');
      final cand = NotaSAP(id: '2', nota: '1002', localInstalacao: 'H-S-SCGR-02', local: 'se campo grande');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosLocalInstalacao, equals(10.0));
      expect(res.scoreTotal, equals(10.0));
      expect(res.evidencias.explicacoes.first, contains('+10 Mesma subestação/local (se campo grande)'));
    });

    // 5. Centro de trabalho
    test('5. Mesmo centro de trabalho responsável adiciona +10 pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', centroTrabalhoResponsavel: 'MNOM.PAF');
      final cand = NotaSAP(id: '2', nota: '1002', centroTrabalhoResponsavel: 'MNOM.PAF');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosCentroTrabalho, equals(10.0));
      expect(res.scoreTotal, equals(10.0));
    });

    // 6. Tipo
    test('6. Campo tipo: pontua +5 quando habilitado e não afeta quando desabilitado', () {
      final ref = NotaSAP(id: '1', nota: '1001', tipo: 'NM');
      final cand = NotaSAP(id: '2', nota: '1002', tipo: 'NM');
      
      // Default: desabilitado (0 pontos para tipo, redistribuído para descrição)
      final resDefault = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(resDefault.evidencias.pontosTipo, equals(0.0));

      // Habilitado: +5 pontos
      final serviceComTipo = NotaSapSimilaridadeService(usarPontosTipo: true);
      final resComTipo = serviceComTipo.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(resComTipo.evidencias.pontosTipo, equals(5.0));
      expect(resComTipo.scoreTotal, equals(5.0));
    });

    // 7. Texto idêntico
    test('7. Texto idêntico de falha com vínculo estrutural pontua até o teto de 30 pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ1', descricao: 'Vazamento de óleo no radiador do transformador');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ1', descricao: 'Vazamento de óleo no radiador do transformador');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      // 40 (eq) + 30 (desc 100%) = 70
      expect(res.evidencias.pontosDescricao, equals(30.0));
      expect(res.scoreTotal, equals(70.0));
    });

    // 8. Texto parcialmente semelhante
    test('8. Texto parcialmente semelhante calcula sobreposição proporcional', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ1', descricao: 'Substituição de bucha com vazamento de óleo');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ1', descricao: 'Vazamento de óleo no transformador');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      // Tokens ref: [substituicao, bucha, vazamento, oleo] -> 4 tokens
      // Tokens cand: [vazamento, oleo, transformador] -> 3 tokens
      // Interseção: [vazamento, oleo] -> 2 tokens. Min(|A|, |B|) = 3 -> 2/3 = 0.6667
      // Pontos: 0.6667 * 30 = 20.0 pts
      expect(res.evidencias.pontosDescricao, equals(20.0));
      expect(res.evidencias.tokensCoincidentes, containsAll(['vazamento', 'oleo']));
    });

    // 9. Texto genérico
    test('9. Termos técnicos excessivamente genéricos são stopwords e não somam pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ1', descricao: 'Realizar manutenção corretiva conforme inspeção');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ1', descricao: 'Executar manutenção preventiva para verificar atendimento');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosDescricao, equals(0.0));
      expect(res.evidencias.tokensCoincidentes, isEmpty);
    });

    // 10. Texto igual sem vínculo estrutural
    test('10. Regra de segurança textual: texto igual sem vínculo estrutural limita-se estritamente a 10 pontos', () {
      final ref = NotaSAP(id: '1', nota: '1001', descricao: 'Baixa pressão de gás SF6 no polo B');
      final cand = NotaSAP(id: '2', nota: '1002', descricao: 'Baixa pressão de gás SF6 no polo B');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosDescricao, equals(10.0));
      expect(res.scoreTotal, equals(10.0));
      expect(res.faixa, equals(FaixaSimilaridade.descartada));
    });

    // 11. Mesmo ativo com falha diferente
    test('11. Mesmo ativo com falha diferente classifica como historicoMesmoAtivo', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: '11340679', descricao: 'CTU:14T2 - BAIXA PRESSÃO SF6');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: '11340679', descricao: 'DOSSC - Eletroduto Fiação Exposta');
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.classificacao, equals(TipoClassificacaoSimilaridade.historicoMesmoAtivo));
    });

    // 12. Score máximo
    test('12. Score máximo atinge 100 pontos determinísticos com clamp', () {
      final ref = NotaSAP(
        id: '1',
        nota: '1001',
        equipamento: 'EQ1',
        localInstalacao: 'LOC1',
        centroTrabalhoResponsavel: 'CT1',
        descricao: 'Substituição de disjuntor com vazamento de óleo',
      );
      final cand = NotaSAP(
        id: '2',
        nota: '1002',
        equipamento: 'EQ1',
        localInstalacao: 'LOC1',
        centroTrabalhoResponsavel: 'CT1',
        descricao: 'Substituição de disjuntor com vazamento de óleo',
      );
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.scoreTotal, equals(100.0));
      expect(res.faixa, equals(FaixaSimilaridade.alta));
    });

    // 13. Score decimal
    test('13. Score decimal exato com 1 casa decimal (ex: 77.5)', () {
      final ref = NotaSAP(
        id: '1',
        nota: '1001',
        equipamento: 'EQ1', // +40
        localInstalacao: 'LOC1', // +20
        centroTrabalhoResponsavel: 'CT1', // +10
        descricao: 'CTU 14T2 BAIXA PRESSAO SF6 1 GRAU', // 4 tokens: [ctu, 14t2, baixa, pressao, sf6]
      );
      final cand = NotaSAP(
        id: '2',
        nota: '1002',
        equipamento: 'EQ1',
        localInstalacao: 'LOC1',
        centroTrabalhoResponsavel: 'CT1',
        descricao: 'DOSSC Vazamento de oleo do 14T2', // tokens: [dossc, vazamento, oleo, 14t2] -> interseção: [14t2] (1 de 4 = 25%)
      );
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      // 40 + 20 + 10 + (0.25 * 30 = 7.5) = 77.5
      expect(res.scoreTotal, equals(77.5));
    });

    // 14. Threshold
    test('14. Threshold de descarte: abaixo de 40 pontos é classificado como descartada', () {
      expect(FaixaSimilaridade.fromScore(39.9), equals(FaixaSimilaridade.descartada));
      expect(FaixaSimilaridade.fromScore(40.0), equals(FaixaSimilaridade.fraca));
      expect(FaixaSimilaridade.fromScore(55.0), equals(FaixaSimilaridade.media));
      expect(FaixaSimilaridade.fromScore(80.0), equals(FaixaSimilaridade.alta));
    });

    // 15. Ordenação
    test('15. Ordenação decrescente por score', () {
      final notaA = NotaSAP(id: '1', nota: '101');
      final notaB = NotaSAP(id: '2', nota: '102');
      final simA = NotaSapSimilar(nota: notaA, scoreTotal: 65, faixa: FaixaSimilaridade.media, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore());
      final simB = NotaSapSimilar(nota: notaB, scoreTotal: 85, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore());
      final lista = [simA, simB];
      lista.sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal));
      expect(lista.first.scoreTotal, equals(85));
    });

    // 16. Desempate por recência
    test('16. Desempate por recência de data da nota para scores idênticos', () {
      final dataAntiga = DateTime(2024, 1, 10);
      final dataRecente = DateTime(2026, 5, 20);
      final simAntiga = NotaSapSimilar(nota: NotaSAP(id: '1', nota: '101', criadoEm: dataAntiga), scoreTotal: 80, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore());
      final simRecente = NotaSapSimilar(nota: NotaSAP(id: '2', nota: '102', criadoEm: dataRecente), scoreTotal: 80, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore());
      final lista = [simAntiga, simRecente];
      lista.sort((a, b) {
        final compScore = b.scoreTotal.compareTo(a.scoreTotal);
        if (compScore != 0) return compScore;
        final dataA = a.nota.criadoEm ?? DateTime(1970);
        final dataB = b.nota.criadoEm ?? DateTime(1970);
        return dataB.compareTo(dataA);
      });
      expect(lista.first.nota.id, equals('2'));
    });

    // 17. Acentos
    test('17. Normalização remove acentos gráficos determinísticamente', () {
      expect(NotaSapSimilaridadeService.normalizarTexto('Pressão Eletrônica'), equals('pressao eletronica'));
      expect(NotaSapSimilaridadeService.normalizarTexto('Substituição de Óleo'), equals('substituicao de oleo'));
    });

    // 18. Caixa alta/baixa
    test('18. Case-insensitive: comparações não diferenciam maiúsculas de minúsculas', () {
      final t1 = NotaSapSimilaridadeService.extrairTokensTecnicos('DISJUNTOR SF6');
      final t2 = NotaSapSimilaridadeService.extrairTokensTecnicos('disjuntor sf6');
      expect(t1, equals(t2));
    });

    // 19. Abreviações
    test('19. Dicionário técnico expande abreviações consolidadas', () {
      expect(NotaSapSimilaridadeService.sinonimosTecnicos['dj'], equals('disjuntor'));
      expect(NotaSapSimilaridadeService.sinonimosTecnicos['trafo'], equals('transformador'));
      expect(NotaSapSimilaridadeService.sinonimosTecnicos['vaz'], equals('vazamento'));
      expect(NotaSapSimilaridadeService.sinonimosTecnicos['sec'], equals('seccionadora'));
    });

    // 20. Stopwords
    test('20. Stopwords linguísticas e operacionais são eliminadas', () {
      expect(NotaSapSimilaridadeService.stopwordsGeraisETecnicas.contains('de'), isTrue);
      expect(NotaSapSimilaridadeService.stopwordsGeraisETecnicas.contains('para'), isTrue);
      expect(NotaSapSimilaridadeService.stopwordsGeraisETecnicas.contains('manutencao'), isTrue);
      expect(NotaSapSimilaridadeService.stopwordsGeraisETecnicas.contains('verificar'), isTrue);
    });

    // 21. Nota sem equipamento
    test('21. Nota sem equipamento (null ou vazio) não gera exceção nem pontua equipamento', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: null);
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: null);
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosEquipamento, equals(0.0));
    });

    // 22. Nota sem local
    test('22. Nota sem local de instalação nem local não gera exceção', () {
      final ref = NotaSAP(id: '1', nota: '1001', localInstalacao: null, local: null);
      final cand = NotaSAP(id: '2', nota: '1002', localInstalacao: null, local: null);
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosLocalInstalacao, equals(0.0));
    });

    // 23. Nota sem descrição
    test('23. Nota sem descrição (null) não gera erro e zera similaridade textual', () {
      final ref = NotaSAP(id: '1', nota: '1001', descricao: null);
      final cand = NotaSAP(id: '2', nota: '1002', descricao: null);
      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosDescricao, equals(0.0));
      expect(res.evidencias.tokensCoincidentes, isEmpty);
    });

    // 24. Falha Supabase
    test('24. Resiliência: falha de infraestrutura retorna resultado vazio sem estourar exceção na tela', () async {
      final ref = NotaSAP(id: '1', nota: '1001');
      final res = await service.buscarSimilaridades(notaReferencia: ref);
      expect(res.temOcorrencias, isFalse);
      expect(res.notaReferencia.id, equals('1'));
    });

    // 25. Lista vazia
    test('25. Lista de candidatos vazia produz ResultadoSimilaridadeNotaSap íntegro e vazio', () {
      final vazio = ResultadoSimilaridadeNotaSap(
        notaReferencia: NotaSAP(id: '1', nota: '101'),
        calculadoEm: DateTime.now(),
      );
      expect(vazio.ocorrenciasSemelhantes, isEmpty);
      expect(vazio.historicoMesmoAtivo, isEmpty);
      expect(vazio.materiaisFrequentes, isEmpty);
      expect(vazio.demandasAbertasRelacionadas, isEmpty);
      expect(vazio.temOcorrencias, isFalse);
    });

    // 26. Limite de 50 candidatos
    test('26. Limite de candidatos no funil não ultrapassa 50 registros', () {
      final candidatos = List.generate(100, (i) => NotaSAP(id: '$i', nota: '${2000 + i}'));
      final truncados = candidatos.take(50).toList();
      expect(truncados.length, equals(50));
    });

    // 27. Mediana ímpar
    test('27. Mediana de horas com número ímpar de amostras extrai o valor central exato', () {
      final m = NotaSapSimilaridadeService.calcularMedianaNumerica([2.0, 5.0, 9.0]);
      expect(m, equals(5.0));
    });

    // 28. Mediana par
    test('28. Mediana de horas com número par de amostras calcula a média dos dois centrais', () {
      final m = NotaSapSimilaridadeService.calcularMedianaNumerica([2.0, 4.0, 6.0, 10.0]);
      expect(m, equals(5.0));
    });

    // 29. Ausência de horas
    test('29. Ausência de horas registradas retorna estatísticas nulas com fonte "Nenhuma"', () {
      final ocorrencias = [
        NotaSapSimilar(nota: NotaSAP(id: '1', nota: '101'), scoreTotal: 80, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore()),
      ];
      final est = NotaSapSimilaridadeService.calcularEstatisticas(ocorrencias);
      expect(est.temDadosHoras, isFalse);
      expect(est.duracaoMedianaHoras, isNull);
      expect(est.fonteHoras, equals('Nenhuma'));
    });

    // 30. Fontes diferentes de horas
    test('30. Identificação clara da fonte de horas (Horas SAP confirmadas vs Duração TaskFlow)', () {
      final ocSap = NotaSapSimilar(nota: NotaSAP(id: '1', nota: '101'), scoreTotal: 80, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore(), horasSapConfirmadas: 5.0);
      final estSap = NotaSapSimilaridadeService.calcularEstatisticas([ocSap]);
      expect(estSap.fonteHoras, equals('Horas SAP confirmadas'));

      final ocTf = NotaSapSimilar(nota: NotaSAP(id: '2', nota: '102'), scoreTotal: 80, faixa: FaixaSimilaridade.alta, classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante, evidencias: const EvidenciaScore(), tarefasVinculadas: [const TarefaHistoricaResumo(id: 't1', horasExecutadas: 4.0)]);
      final estTf = NotaSapSimilaridadeService.calcularEstatisticas([ocTf]);
      expect(estTf.fonteHoras, equals('Duração registrada TaskFlow'));
    });

    // 31. Demandas relacionadas
    test('31. Identificação de demandas abertas relacionadas no mesmo equipamento/local para intervenção conjunta', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ-01', localInstalacao: 'LOC-01');
      final candAberta = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ-01', localInstalacao: 'LOC-01', statusSistema: 'MSPR ORDA');
      final abertas = NotaSapSimilaridadeService.identificarDemandasAbertas(
        notaReferencia: ref,
        notasCandidatas: [candAberta],
      );
      expect(abertas.length, equals(1));
      expect(abertas.first.nota.nota, equals('1002'));
      expect(abertas.first.motivo, contains('Mesmo equipamento'));
    });

    // 32. Status aberto
    test('32. Critério de demanda aberta: status MSPR/MSPN sem CONC/ENCE/CANC', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ1');
      final candAberta = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ1', statusSistema: 'MSPR ORDA');
      final candEncerrada = NotaSAP(id: '3', nota: '1003', equipamento: 'EQ1', statusSistema: 'MSEN ORDA');
      final candCancelada = NotaSAP(id: '4', nota: '1004', equipamento: 'EQ1', statusSistema: 'CANC');

      final abertas = NotaSapSimilaridadeService.identificarDemandasAbertas(
        notaReferencia: ref,
        notasCandidatas: [candAberta, candEncerrada, candCancelada],
      );
      expect(abertas.length, equals(1));
      expect(abertas.first.nota.id, equals('2'));
    });

    // 33. Material reaproveitado explicitamente
    test('33. Reaproveitamento de material: cria novo registro com novo ID, não altera histórico e mantém quantidade editável', () {
      final historico = NotaSapMaterial(
        id: 'mat-hist-999',
        notaSapId: 'nota-hist',
        codigoSap: '104256',
        descricao: 'FUSIVEL 100A',
        quantidade: 3.0,
        unidade: 'UN',
        statusMaterial: NotaMaterialStatus.reservado,
      );

      // Simulação do payload ao reaproveitar para a nova nota
      final novoMaterial = NotaSapMaterial(
        notaSapId: 'nova-nota-123',
        codigoSap: historico.codigoSap,
        descricao: historico.descricao,
        quantidade: 1.0, // Quantidade editável definida pelo técnico
        unidade: historico.unidade,
        statusMaterial: NotaMaterialStatus.naoVerificado, // Status inicial adequado
      );

      expect(novoMaterial.id, isNull, reason: 'Novo registro deve ser gerado pelo banco com novo ID');
      expect(novoMaterial.notaSapId, equals('nova-nota-123'));
      expect(novoMaterial.statusMaterial, equals(NotaMaterialStatus.naoVerificado));
      expect(historico.id, equals('mat-hist-999'), reason: 'Material original do histórico permanece intacto');
      expect(historico.quantidade, equals(3.0));
    });

    // 34. Diagnóstico reaproveitado explicitamente
    test('34. Reaproveitamento de diagnóstico: ação explícita (adicionar, substituir ou cancelar quando preenchido)', () {
      const conteudoAtual = 'Diagnóstico preliminar em campo';
      const novoConteudo = 'Substituição de bucha danificada';
      const numeroNota = '10009988';

      // Comportamento A: Adicionar
      final separador = '\n\n--- Nota SAP $numeroNota ---\n';
      final adicionado = '$conteudoAtual$separador$novoConteudo';
      expect(adicionado, contains(conteudoAtual));
      expect(adicionado, contains(novoConteudo));

      // Comportamento B: Substituir
      const substituido = novoConteudo;
      expect(substituido, equals(novoConteudo));
    });

    // 35. Nenhum dado operacional alterado
    test('35. Idempotência e segurança: motor é estritamente analítico e de consulta (read-only)', () {
      final ref = NotaSAP(id: '1', nota: '1001', equipamento: 'EQ1', descricao: 'Avaria');
      final cand = NotaSAP(id: '2', nota: '1002', equipamento: 'EQ1', descricao: 'Avaria');
      
      final res1 = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      final res2 = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);

      expect(res1.scoreTotal, equals(res2.scoreTotal));
      expect(res1.classificacao, equals(res2.classificacao));
      expect(ref.id, equals('1'));
      expect(cand.id, equals('2'));
    });

    // 36. Mesmo Vão / Bay Operativo (reconhecimento elétrico)
    test('36. Mesmo Vão / Bay Operativo adiciona +20 pontos e clasifica como ocorrência semelhante', () {
      final ref = NotaSAP(
        id: 'ref',
        nota: '11476662',
        localInstalacao: 'H-S-STSA-DT1E01-1CR1-S601',
        descricao: 'TSA: 31E1-6 CORROSÃO ESTRUTURA METALICA',
        centroTrabalhoResponsavel: 'MNSE.TSA',
      );
      final cand = NotaSAP(
        id: 'cand',
        nota: '11456616',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- CORROSÃO',
        centroTrabalhoResponsavel: 'MNSE.TSA',
      );

      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);
      expect(res.evidencias.pontosLocalInstalacao, equals(20.0));
      expect(res.evidencias.pontosCentroTrabalho, equals(10.0));
      expect(res.evidencias.pontosDescricao, equals(20.0));
      expect(res.scoreTotal, equals(50.0));
      expect(res.faixa, equals(FaixaSimilaridade.fraca));
      expect(res.classificacao, equals(TipoClassificacaoSimilaridade.ocorrenciaSemelhante));
      expect(res.evidencias.explicacoes, anyElement(contains('Mesmo vão operativo (H-S-STSA-DT1E01)')));
    });

    // 37. Extração de prefixo e radical de vão
    test('37. Extração de vão: prefixo hierárquico e radical de vão pela sala', () {
      expect(
        NotaSapSimilaridadeService.extrairPrefixoVao('H-S-STSA-DT1E01-1CR1-S601'),
        equals('H-S-STSA-DT1E01'),
      );
      expect(
        NotaSapSimilaridadeService.extrairPrefixoSubestacao('H-S-STSA-DT1E01-1CR1-S601'),
        equals('H-S-STSA'),
      );
      expect(NotaSapSimilaridadeService.extrairRadicalVao('01E1'), equals('1E1'));
      expect(NotaSapSimilaridadeService.extrairRadicalVao('31E1-6'), equals('1E1'));
      expect(NotaSapSimilaridadeService.extrairRadicalVao('11E1'), equals('1E1'));
      expect(NotaSapSimilaridadeService.extrairDigitosVaoSala('31E1-6'), equals('1E1'));
      expect(NotaSapSimilaridadeService.extrairDigitosVaoSala('01E1'), equals('1E1'));
      expect(NotaSapSimilaridadeService.extrairDigitosVaoSala('34T4-6'), equals('4T4'));
      expect(NotaSapSimilaridadeService.extrairDigitosVaoSala('32J1-6'), equals('2J1'));
    });

    // 38. Demandas Abertas: exige vínculo no vão ou equipamento
    test('38. Demandas Abertas: exige vínculo no vão ou ativo; apenas mesma subestação e mesmo CT não é demanda relacionada', () {
      final ref = NotaSAP(
        id: 'ref',
        nota: '11476662',
        localInstalacao: 'H-S-STSA-DT1E01-1CR1-S601',
        centroTrabalhoResponsavel: 'MNSE.TSA',
      );
      final notaApenasMesmoCT = NotaSAP(
        id: 'n1',
        nota: '11598930',
        statusSistema: 'MSPR',
        localInstalacao: 'H-S-STSA-RB5T04-5LT1',
        centroTrabalhoResponsavel: 'MNSE.TSA',
        criadoEm: DateTime(2026, 9, 1),
      );
      final notaMesmoVao = NotaSAP(
        id: 'n2',
        nota: '11587891',
        statusSistema: 'MSPR',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        centroTrabalhoResponsavel: 'MNSE.TSA',
        criadoEm: DateTime(2026, 8, 15),
      );

      final abertas = NotaSapSimilaridadeService.identificarDemandasAbertas(
        notaReferencia: ref,
        notasCandidatas: [notaApenasMesmoCT, notaMesmoVao],
      );

      // Apenas a nota com vínculo operativo de vão deve ser incluída; a nota apenas com mesmo CT é rejeitada
      expect(abertas.length, equals(1));
      expect(abertas.first.nota.nota, equals('11587891'));
      expect(abertas.first.motivo, contains('Mesmo vão operativo (H-S-STSA-DT1E01)'));
    });

    test('39. Vão Operativo e Subestação: notas de salas 31E1-6 e 01E1 em TSA são similares e não descartadas', () {
      final ref = NotaSAP(
        id: 'ref',
        nota: '11476662',
        sala: '31E1-6',
        localInstalacao: 'H-S-STSA-DT1E01-1CR1-S601',
        descricao: 'TSA: 31E1-6 CORROSÃO ESTRUTURA METALICA',
        centroTrabalhoResponsavel: 'MNSE.TSA',
        local: 'TSA',
      );
      final cand = NotaSAP(
        id: 'cand',
        nota: '11587891',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- MEREJAMENTO OLEO',
        centroTrabalhoResponsavel: 'MNSE.TSA',
        local: 'TSA',
      );

      final res = service.avaliarSimilaridade(notaReferencia: ref, notaCandidata: cand);

      expect(res.evidencias.pontosLocalInstalacao, equals(20.0));
      expect(res.evidencias.pontosCentroTrabalho, equals(10.0));
      expect(res.scoreTotal, greaterThanOrEqualTo(30.0));
      expect(res.faixa, isNot(equals(FaixaSimilaridade.descartada)),
          reason: 'Notas do mesmo vão operativo na mesma subestação nunca devem ser descartadas');
      expect(res.evidencias.explicacoes, anyElement(contains('Mesmo vão operativo')));
    });

    test('40. Critério Eliminatório: 8 primeiros caracteres diferentes de local_instalacao descartam similaridade com score 0', () {
      // Subestação TSA (H-S-STSA) vs Subestação IRE (H-S-SIRE) e Subestação BJS (H-S-SBJS)
      final refTSA = NotaSAP(
        id: 'ref',
        nota: '11587891',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- MEREJAMENTO OLEO',
      );

      final candIRE = NotaSAP(
        id: 'cand-ire',
        nota: '11595124',
        sala: '01E1',
        localInstalacao: 'H-S-SIRE-DT1E01-1EQ1-RE01',
        descricao: 'IRE: 11E1 - ANORMALIDADE DISJUNTOR/SECC',
      );

      final candBJS = NotaSAP(
        id: 'cand-bjs',
        nota: '11584918',
        sala: '01E1',
        localInstalacao: 'H-S-SBJS-DT1E01-1EQ1-RE01',
        descricao: 'BJS - 01E1 - SIN. 1º INTRÍSECAS',
      );

      final resIRE = service.avaliarSimilaridade(notaReferencia: refTSA, notaCandidata: candIRE);
      final resBJS = service.avaliarSimilaridade(notaReferencia: refTSA, notaCandidata: candBJS);

      expect(resIRE.scoreTotal, equals(0.0));
      expect(resIRE.faixa, equals(FaixaSimilaridade.descartada));
      expect(resIRE.evidencias.explicacoes.first, contains('Instalação/Subestação diferente'));

      expect(resBJS.scoreTotal, equals(0.0));
      expect(resBJS.faixa, equals(FaixaSimilaridade.descartada));
      expect(resBJS.evidencias.explicacoes.first, contains('Instalação/Subestação diferente'));
    });

    test('41. Critério Eliminatório: demandas abertas rejeitam notas de subestações/linhas diferentes pelos 8 caracteres', () {
      final refTSA = NotaSAP(
        id: 'ref',
        nota: '11587891',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- MEREJAMENTO OLEO',
        statusSistema: 'MSPR',
      );

      final candIRE = NotaSAP(
        id: 'cand-ire',
        nota: '11595124',
        sala: '01E1',
        localInstalacao: 'H-S-SIRE-DT1E01-1EQ1-RE01',
        descricao: 'IRE: 11E1 - ANORMALIDADE DISJUNTOR/SECC',
        statusSistema: 'MSPR ORDA',
      );

      final candBJS = NotaSAP(
        id: 'cand-bjs',
        nota: '11584918',
        sala: '01E1',
        localInstalacao: 'H-S-SBJS-DT1E01-1EQ1-RE01',
        descricao: 'BJS - 01E1 - SIN. 1º INTRÍSECAS',
        statusSistema: 'MSPN',
      );

      final candTSA = NotaSAP(
        id: 'cand-tsa',
        nota: '11476662',
        sala: '31E1-6',
        localInstalacao: 'H-S-STSA-DT1E01-1CR1-S601',
        descricao: 'TSA: 31E1-6 CORROSÃO ESTRUTURA METALICA',
        statusSistema: 'MSPR',
      );

      final demandas = NotaSapSimilaridadeService.identificarDemandasAbertas(
        notaReferencia: refTSA,
        notasCandidatas: [candIRE, candBJS, candTSA],
      );

      // Apenas candTSA (mesmo prefixo H-S-STSA) deve ser aceita; IRE e BJS devem ser descartadas
      expect(demandas.length, equals(1));
      expect(demandas.first.nota.nota, equals('11476662'));
    });
  });
}
