// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/services/nota_sap_similaridade_service.dart';

void main() {
  test('Avaliação dos 15 Casos Reais com o Motor de Similaridade', () async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (_) {}

    final service = NotaSapSimilaridadeService();

    // -------------------------------------------------------------
    // GRUPO 1: 5 BONS MATCHES (Mesmo equipamento + Mesma falha)
    // -------------------------------------------------------------
    print('\n======================================================');
    print('GRUPO 1: 5 BONS MATCHES (Mesmo Ativo + Falha Semelhante)');
    print('======================================================');

    // Caso 1: Equipamento 11341209 (CCD: 12T2 - Baixa pressão SF6)
    final notaRef1 = NotaSAP(
      id: '11599101',
      nota: '11599101',
      equipamento: '11341209',
      localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01',
      centroTrabalhoResponsavel: 'MNOM.PAF',
      descricao: 'CCD: 12T2 - BAIXA PRESSÃO SF6',
      tipo: 'NM',
      statusSistema: 'MSPR ORDA',
    );
    final notaCand1 = NotaSAP(
      id: '11565867',
      nota: '11565867',
      equipamento: '11341209',
      localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01',
      centroTrabalhoResponsavel: 'MNOM.PAF',
      descricao: 'CCD: 12T2 - BAIXA PRESSÃO SF6',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim1 = service.avaliarSimilaridade(notaReferencia: notaRef1, notaCandidata: notaCand1);
    print('\nCASO 1:');
    print('Ref: ${notaRef1.nota} ("${notaRef1.descricao}") vs Cand: ${notaCand1.nota} ("${notaCand1.descricao}")');
    print('Score: ${sim1.scoreTotal} pts | Faixa: ${sim1.faixa.label} | Classificação: ${sim1.classificacao.name}');
    print('Evidências: ${sim1.evidencias.explicacoes.join(', ')}');

    // Caso 2: Equipamento 11340679 (CTU: 14T2 - Baixa pressão SF6)
    final notaRef2 = NotaSAP(
      id: '11599351',
      nota: '11599351',
      equipamento: '11340679',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      centroTrabalhoResponsavel: 'MNSE.CMD',
      descricao: 'CTU:14T2 - BAIXA PRESSÃO SF6 1º GRAU',
      tipo: 'NM',
      statusSistema: 'MSPR ORDA',
    );
    final notaCand2 = NotaSAP(
      id: '11473356',
      nota: '11473356',
      equipamento: '11340679',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      centroTrabalhoResponsavel: 'MNSE.CMD',
      descricao: 'CTU:14T2-BAIXA PRESSÃO SF6',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim2 = service.avaliarSimilaridade(notaReferencia: notaRef2, notaCandidata: notaCand2);
    print('\nCASO 2:');
    print('Ref: ${notaRef2.nota} ("${notaRef2.descricao}") vs Cand: ${notaCand2.nota} ("${notaCand2.descricao}")');
    print('Score: ${sim2.scoreTotal} pts | Faixa: ${sim2.faixa.label} | Classificação: ${sim2.classificacao.name}');
    print('Evidências: ${sim2.evidencias.explicacoes.join(', ')}');

    // Caso 3: Equipamento 11336666 (PAF: 34F3-5 Resistência Mecânica / Comando Elétrico)
    final notaRef3 = NotaSAP(
      id: '11409815',
      nota: '11409815',
      equipamento: '11336666',
      localInstalacao: 'H-S-SPAF-RB4F03-4EL1-S501',
      centroTrabalhoResponsavel: 'MNSE.PAF',
      descricao: 'PAF: 34F3-5  - RESISTÊNCIA MECÂNICA',
      tipo: 'NM',
      statusSistema: 'MSPR ORDA',
    );
    final notaCand3 = NotaSAP(
      id: '11270560',
      nota: '11270560',
      equipamento: '11336666',
      localInstalacao: 'H-S-SPAF-RB4F03-4EL1-S501',
      centroTrabalhoResponsavel: 'MNSE.PAF',
      descricao: 'PAF: 34F3-5- RESISTÊNCIA MECÂNICA',
      tipo: 'NM',
      statusSistema: 'MSPR ORDA',
    );
    final sim3 = service.avaliarSimilaridade(notaReferencia: notaRef3, notaCandidata: notaCand3);
    print('\nCASO 3:');
    print('Ref: ${notaRef3.nota} ("${notaRef3.descricao}") vs Cand: ${notaCand3.nota} ("${notaCand3.descricao}")');
    print('Score: ${sim3.scoreTotal} pts | Faixa: ${sim3.faixa.label} | Classificação: ${sim3.classificacao.name}');
    print('Evidências: ${sim3.evidencias.explicacoes.join(', ')}');

    // Caso 4: Equipamento 11451642 (USB:01G1 Mancal de Escora Temp Alta)
    final notaRef4 = NotaSAP(
      id: '11599058',
      nota: '11599058',
      equipamento: '11451642',
      localInstalacao: 'H-U-HUSB-CE1G01-MCL1-MC01',
      centroTrabalhoResponsavel: 'MNEL.USB',
      descricao: 'USB:01G1 TEMP. SEGMENTOS MES.',
      tipo: 'NM',
      statusSistema: 'MSPR',
    );
    final notaCand4 = NotaSAP(
      id: '11578789',
      nota: '11578789',
      equipamento: '11451642',
      localInstalacao: 'H-U-HUSB-CE1G01-MCL1-MC01',
      centroTrabalhoResponsavel: 'MNEL.USB',
      descricao: 'USB:01G1:MES - Falha Temp Seg In18 Ex11',
      tipo: 'NM',
      statusSistema: 'MSPR',
    );
    final sim4 = service.avaliarSimilaridade(notaReferencia: notaRef4, notaCandidata: notaCand4);
    print('\nCASO 4:');
    print('Ref: ${notaRef4.nota} ("${notaRef4.descricao}") vs Cand: ${notaCand4.nota} ("${notaCand4.descricao}")');
    print('Score: ${sim4.scoreTotal} pts | Faixa: ${sim4.faixa.label} | Classificação: ${sim4.classificacao.name}');
    print('Evidências: ${sim4.evidencias.explicacoes.join(', ')}');

    // Caso 5: Equipamento 11341209 (Ressuprimento de Gás SF6 12T2)
    final notaRef5 = NotaSAP(
      id: '11344587',
      nota: '11344587',
      equipamento: '11341209',
      localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01',
      centroTrabalhoResponsavel: 'MNOM.PAF',
      descricao: 'Ressuprimento de gás SF6 12T2',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final notaCand5 = NotaSAP(
      id: '11284117',
      nota: '11284117',
      equipamento: '11341209',
      localInstalacao: 'H-S-SCCD-RB4T02-2CT1-DJ01',
      centroTrabalhoResponsavel: 'MNOM.PAF',
      descricao: 'Ressuprimento de gás SF6 12T2',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim5 = service.avaliarSimilaridade(notaReferencia: notaRef5, notaCandidata: notaCand5);
    print('\nCASO 5:');
    print('Ref: ${notaRef5.nota} ("${notaRef5.descricao}") vs Cand: ${notaCand5.nota} ("${notaCand5.descricao}")');
    print('Score: ${sim5.scoreTotal} pts | Faixa: ${sim5.faixa.label} | Classificação: ${sim5.classificacao.name}');
    print('Evidências: ${sim5.evidencias.explicacoes.join(', ')}');

    // -------------------------------------------------------------
    // GRUPO 2: 5 CASOS DE HISTÓRICO DO MESMO ATIVO (Falhas distintas)
    // -------------------------------------------------------------
    print('\n======================================================');
    print('GRUPO 2: 5 CASOS DE HISTÓRICO DO MESMO ATIVO');
    print('======================================================');

    // Caso 6: Equipamento 11340679 (Baixa pressão SF6 vs Vazamento de óleo)
    final notaCand6 = NotaSAP(
      id: '11117247',
      nota: '11117247',
      equipamento: '11340679',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      centroTrabalhoResponsavel: 'MNSE.CMD',
      descricao: 'DOSSC- Vazamento de óleo do 14T2',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim6 = service.avaliarSimilaridade(notaReferencia: notaRef2, notaCandidata: notaCand6);
    print('\nCASO 6:');
    print('Ref: ${notaRef2.nota} ("${notaRef2.descricao}") vs Cand: ${notaCand6.nota} ("${notaCand6.descricao}")');
    print('Score: ${sim6.scoreTotal} pts | Faixa: ${sim6.faixa.label} | Classificação: ${sim6.classificacao.name}');
    print('Evidências: ${sim6.evidencias.explicacoes.join(', ')}');

    // Caso 7: Equipamento 11340679 (Baixa pressão SF6 vs Eletroduto fiação exposta)
    final notaCand7 = NotaSAP(
      id: '11028691',
      nota: '11028691',
      equipamento: '11340679',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      centroTrabalhoResponsavel: 'MNSE.CMD',
      descricao: 'DOSSC - Eletroduto Fiação Exposta',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim7 = service.avaliarSimilaridade(notaReferencia: notaRef2, notaCandidata: notaCand7);
    print('\nCASO 7:');
    print('Ref: ${notaRef2.nota} ("${notaRef2.descricao}") vs Cand: ${notaCand7.nota} ("${notaCand7.descricao}")');
    print('Score: ${sim7.scoreTotal} pts | Faixa: ${sim7.faixa.label} | Classificação: ${sim7.classificacao.name}');
    print('Evidências: ${sim7.evidencias.explicacoes.join(', ')}');

    // Caso 8: Equipamento 11461839 (Falha de mouse vs Religamento automático)
    final notaRef8 = NotaSAP(
      id: '11598846',
      nota: '11598846',
      equipamento: '11461839',
      localInstalacao: 'H-S-SPAF-RBMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNPT.PAF',
      descricao: 'SE PAF - SAGE SE PAF - FALHA MOUSE',
      tipo: 'NM',
      statusSistema: 'MSPN',
    );
    final notaCand8 = NotaSAP(
      id: '11563529',
      nota: '11563529',
      equipamento: '11461839',
      localInstalacao: 'H-S-SPAF-RBMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNPT.PAF',
      descricao: 'PAF: 04S7 - RELIGAMENTO AUTOMÁTICO.',
      tipo: 'NM',
      statusSistema: 'MSPR',
    );
    final sim8 = service.avaliarSimilaridade(notaReferencia: notaRef8, notaCandidata: notaCand8);
    print('\nCASO 8:');
    print('Ref: ${notaRef8.nota} ("${notaRef8.descricao}") vs Cand: ${notaCand8.nota} ("${notaCand8.descricao}")');
    print('Score: ${sim8.scoreTotal} pts | Faixa: ${sim8.faixa.label} | Classificação: ${sim8.classificacao.name}');
    print('Evidências: ${sim8.evidencias.explicacoes.join(', ')}');

    // Caso 9: Equipamento 12590493 (Setpoint Inválido vs Atualização Sage)
    final notaRef9 = NotaSAP(
      id: '11599317',
      nota: '11599317',
      equipamento: '12590493',
      localInstalacao: 'H-S-SGPX-IGMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNEL.USB',
      descricao: 'GPX: SETPOINT CONTROLE DE POTÊ. INVÁLIDO',
      tipo: 'NM',
      statusSistema: 'MSPN',
    );
    final notaCand9 = NotaSAP(
      id: '11428489',
      nota: '11428489',
      equipamento: '12590493',
      localInstalacao: 'H-S-SGPX-IGMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNPT.SOB',
      descricao: 'Atualização Sage23-18 SICCP',
      tipo: 'NP',
      statusSistema: 'MSPR ORDA',
    );
    final sim9 = service.avaliarSimilaridade(notaReferencia: notaRef9, notaCandidata: notaCand9);
    print('\nCASO 9:');
    print('Ref: ${notaRef9.nota} ("${notaRef9.descricao}") vs Cand: ${notaCand9.nota} ("${notaCand9.descricao}")');
    print('Score: ${sim9.scoreTotal} pts | Faixa: ${sim9.faixa.label} | Classificação: ${sim9.classificacao.name}');
    print('Evidências: ${sim9.evidencias.explicacoes.join(', ')}');

    // Caso 10: Equipamento 11336666 (Resistência Mecânica vs Sem comando SAGE)
    final notaCand10 = NotaSAP(
      id: '10704341',
      nota: '10704341',
      equipamento: '11336666',
      localInstalacao: 'H-S-SPAF-RB4F03-4EL1-S501',
      centroTrabalhoResponsavel: 'MNSE.PAF',
      descricao: '34F3-5 sem comando pelo SAGE',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim10 = service.avaliarSimilaridade(notaReferencia: notaRef3, notaCandidata: notaCand10);
    print('\nCASO 10:');
    print('Ref: ${notaRef3.nota} ("${notaRef3.descricao}") vs Cand: ${notaCand10.nota} ("${notaCand10.descricao}")');
    print('Score: ${sim10.scoreTotal} pts | Faixa: ${sim10.faixa.label} | Classificação: ${sim10.classificacao.name}');
    print('Evidências: ${sim10.evidencias.explicacoes.join(', ')}');

    // -------------------------------------------------------------
    // GRUPO 3: 5 CASOS REJEITADOS (Ativos diferentes / Sem relação)
    // -------------------------------------------------------------
    print('\n======================================================');
    print('GRUPO 3: 5 CASOS REJEITADOS (Descarte / Falso Positivo Evitado)');
    print('======================================================');

    // Caso 11: Mesma falha textual ("Baixa pressão SF6"), mas ativos e subestações totalmente distintos
    // CCD 12T2 (SE CCD) vs CTU 14T2 (SE CTU)
    final sim11 = service.avaliarSimilaridade(notaReferencia: notaRef1, notaCandidata: notaRef2);
    print('\nCASO 11 (Mesma falha SF6 em ativos e locais diferentes):');
    print('Ref: ${notaRef1.nota} (CCD 12T2) vs Cand: ${notaRef2.nota} (CTU 14T2)');
    print('Score: ${sim11.scoreTotal} pts | Faixa: ${sim11.faixa.label}');
    print('Evidências: ${sim11.evidencias.explicacoes.join(', ')}');

    // Caso 12: Mesma subestação (PAF), mas ativos completamente distintos (Disjuntor 34F3-5 vs Servidor SAGE)
    final sim12 = service.avaliarSimilaridade(notaReferencia: notaRef3, notaCandidata: notaRef8);
    print('\nCASO 12 (Mesma subestação PAF, ativos distintos 11336666 vs 11461839):');
    print('Ref: ${notaRef3.nota} (Disjuntor) vs Cand: ${notaRef8.nota} (Mouse SAGE)');
    print('Score: ${sim12.scoreTotal} pts | Faixa: ${sim12.faixa.label}');
    print('Evidências: ${sim12.evidencias.explicacoes.join(', ')}');

    // Caso 13: Usinas hidrelétricas distintas (USB vs UXG)
    final notaUXG = NotaSAP(
      id: '10726959',
      nota: '10726959',
      equipamento: '99999999',
      localInstalacao: 'H-U-HUXG-VTDR01-CO03-CO01',
      centroTrabalhoResponsavel: 'MNEL.UXG',
      descricao: 'NÃO ACEITOU COMANDO DE FECHAMENTO',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim13 = service.avaliarSimilaridade(notaReferencia: notaRef4, notaCandidata: notaUXG);
    print('\nCASO 13 (Usinas distintas USB vs UXG):');
    print('Ref: ${notaRef4.nota} (USB) vs Cand: ${notaUXG.nota} (UXG)');
    print('Score: ${sim13.scoreTotal} pts | Faixa: ${sim13.faixa.label}');
    print('Evidências: ${sim13.evidencias.explicacoes.join(', ')}');

    // Caso 14: Mesma palavra-chave genérica "TEMPERATURA", mas ativos distintos (Mancal USB vs Transformador CTU)
    final notaTempOutro = NotaSAP(
      id: '10000001',
      nota: '10000001',
      equipamento: '88888888',
      localInstalacao: 'H-S-SCTU-TR01',
      centroTrabalhoResponsavel: 'MNOM.CTU',
      descricao: 'TEMPERATURA ELEVADA NO ENROLAMENTO',
      tipo: 'NM',
      statusSistema: 'MSEN',
    );
    final sim14 = service.avaliarSimilaridade(notaReferencia: notaRef4, notaCandidata: notaTempOutro);
    print('\nCASO 14 (Termo genérico "temperatura" em ativos distintos):');
    print('Ref: ${notaRef4.nota} vs Cand: ${notaTempOutro.nota}');
    print('Score: ${sim14.scoreTotal} pts | Faixa: ${sim14.faixa.label}');
    print('Evidências: ${sim14.evidencias.explicacoes.join(', ')}');

    // Caso 15: Sem nenhum vínculo (equipamento diferente, local diferente, texto sem sobreposição)
    final notaDesconexa = NotaSAP(
      id: '10000002',
      nota: '10000002',
      equipamento: '77777777',
      localInstalacao: 'H-L-LT500-T100',
      centroTrabalhoResponsavel: 'MNLT.REC',
      descricao: 'INSPECAO VISUAL DE CABO PARA-RAIOS EM LT',
      tipo: 'NP',
      statusSistema: 'MSEN',
    );
    final sim15 = service.avaliarSimilaridade(notaReferencia: notaRef1, notaCandidata: notaDesconexa);
    print('\nCASO 15 (Totalmente desconexo - Linha de transmissão vs Disjuntor):');
    print('Ref: ${notaRef1.nota} vs Cand: ${notaDesconexa.nota}');
    print('Score: ${sim15.scoreTotal} pts | Faixa: ${sim15.faixa.label}');
    print('Evidências: ${sim15.evidencias.explicacoes.isEmpty ? "Nenhuma evidência coincidente" : sim15.evidencias.explicacoes.join(', ')}');

    // -------------------------------------------------------------
    // GRUPO 4: CASOS LIMÍTROFES REAIS DE FRONTEIRA (30–39, 40–54, 55–79)
    // -------------------------------------------------------------
    print('\n======================================================');
    print('GRUPO 4: CASOS LIMÍTROFES REAIS DE FRONTEIRA');
    print('======================================================');

    // Caso 16 (Fronteira 30–39): Mesmo local de instalação, sem equipamento, similaridade textual parcial
    final notaCand16 = NotaSAP(
      id: '11521808',
      nota: '11521808',
      localInstalacao: 'H-S-SGPX-IGMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNPT.SOB',
      descricao: 'GPX - Setpoint MW sem aceitar comandos.',
      tipo: 'NM',
      statusSistema: 'MSPR ORDA',
    );
    final sim16 = service.avaliarSimilaridade(notaReferencia: notaRef9, notaCandidata: notaCand16);
    print('\nCASO 16 (Fronteira 30–39: Score 32.0 pts):');
    print('Ref: ${notaRef9.nota} ("${notaRef9.descricao}") vs Cand: ${notaCand16.nota} ("${notaCand16.descricao}")');
    print('Score: ${sim16.scoreTotal} pts | Faixa: ${sim16.faixa.label}');
    print('Evidências: ${sim16.evidencias.explicacoes.join(', ')}');

    // Caso 17 (Fronteira 40–54): Mesmo local de instalação + mesmo CT + similaridade textual parcial
    final notaRef17 = NotaSAP(
      id: '11599220',
      nota: '11599220',
      localInstalacao: 'H-L-L230-MLG-01',
      centroTrabalhoResponsavel: 'MNLT.MLG',
      descricao: 'VEGETACÃO ALTA PERIGOSA',
      tipo: 'NM',
      statusSistema: 'MSPR',
    );
    final notaCand17 = NotaSAP(
      id: '11456992',
      nota: '11456992',
      localInstalacao: 'H-L-L230-MLG-01',
      centroTrabalhoResponsavel: 'MNLT.MLG',
      descricao: 'VEGETACAO RISCO DE APROXIMACAO 11/1',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim17 = service.avaliarSimilaridade(notaReferencia: notaRef17, notaCandidata: notaCand17);
    print('\nCASO 17 (Fronteira 40–54: Score 40.0 pts):');
    print('Ref: ${notaRef17.nota} ("${notaRef17.descricao}") vs Cand: ${notaCand17.nota} ("${notaCand17.descricao}")');
    print('Score: ${sim17.scoreTotal} pts | Faixa: ${sim17.faixa.label}');
    print('Evidências: ${sim17.evidencias.explicacoes.join(', ')}');

    // Caso 18 (Fronteira 55–79): Mesmo equipamento + mesmo local + similaridade textual parcial
    final notaCand18 = NotaSAP(
      id: '11494854',
      nota: '11494854',
      equipamento: '12590493',
      localInstalacao: 'H-S-SGPX-IGMG01-SPAT-SP01-AUT',
      centroTrabalhoResponsavel: 'MNPT.SOB',
      descricao: 'GPX - MELHORIA COMANDO SET POINT POTENCI',
      tipo: 'NM',
      statusSistema: 'MSEN ORDA',
    );
    final sim18 = service.avaliarSimilaridade(notaReferencia: notaRef9, notaCandidata: notaCand18);
    print('\nCASO 18 (Fronteira 55–79: Score 66.0 pts):');
    print('Ref: ${notaRef9.nota} ("${notaRef9.descricao}") vs Cand: ${notaCand18.nota} ("${notaCand18.descricao}")');
    print('Score: ${sim18.scoreTotal} pts | Faixa: ${sim18.faixa.label}');
    print('Evidências: ${sim18.evidencias.explicacoes.join(', ')}');
  });
}
