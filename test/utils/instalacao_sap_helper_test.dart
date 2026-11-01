import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/utils/instalacao_sap_helper.dart';

void main() {
  group('InstalacaoSapHelper - Testes de Unidade', () {
    test('Extração de chave canônica para Subestações (SE)', () {
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-S-SCTU-RB4T02-4CT1-DJ01'),
        equals('H-S-SCTU'),
      );
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-S-STSA-DT1E01-1CR1-S601'),
        equals('H-S-STSA'),
      );
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-S-SIRE-RB4T02'),
        equals('H-S-SIRE'),
      );
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-S-SBNO'),
        equals('H-S-SBNO'),
      );
    });

    test('Extração de chave canônica para Linhas de Transmissão (LT)', () {
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-L-SMTDSBNO-RB4F04-4LT1'),
        equals('H-L-SMTDSBNO'),
      );
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-L-SPDDSTSD-RB5C08-5LT1'),
        equals('H-L-SPDDSTSD'),
      );
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-L-SAQDSBNB-RB4C07-4LT1'),
        equals('H-L-SAQDSBNB'),
      );
    });

    test('Extração de chave canônica para Usinas e outros prefixos', () {
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('H-U-HUSQ-VTDR01-CO03'),
        equals('H-U-HUSQ'),
      );
    });

    test('Tratamento de formatos curtos, nulos, vazios e inesperados', () {
      expect(InstalacaoSapHelper.extrairChaveInstalacao(null), isNull);
      expect(InstalacaoSapHelper.extrairChaveInstalacao(''), isNull);
      expect(InstalacaoSapHelper.extrairChaveInstalacao('   '), isNull);
      expect(InstalacaoSapHelper.extrairChaveInstalacao('AB'), isNull);
      expect(InstalacaoSapHelper.extrairChaveInstalacao('H-S'), equals('H-S'));
      // Fallback por comprimento
      expect(
        InstalacaoSapHelper.extrairChaveInstalacao('SUBESTACAO123'),
        equals('SUBESTAC'),
      );
    });

    test('Comparação saoMesmaInstalacao', () {
      expect(
        InstalacaoSapHelper.saoMesmaInstalacao(
          'H-S-SCTU-RB4T02-4CT1-DJ01',
          'H-S-SCTU-RB4T01-1CT1-TR01',
        ),
        isTrue,
      );
      expect(
        InstalacaoSapHelper.saoMesmaInstalacao(
          'H-S-SCTU-RB4T02-4CT1-DJ01',
          'H-S-STSA-DT1E01-1CR1-S601',
        ),
        isFalse,
      );
      expect(
        InstalacaoSapHelper.saoMesmaInstalacao(
          'H-L-SMTDSBNO-RB4F04-4LT1',
          'H-L-SMTDSBNO-RB4F02-2LT1',
        ),
        isTrue,
      );
      expect(
        InstalacaoSapHelper.saoMesmaInstalacao(null, 'H-S-SCTU'),
        isFalse,
      );
    });

    test('Blacklist de salas e validação de Critério B', () {
      // Válidas
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('14T2'), isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('34F3-5'), isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('101/2'), isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('080/1.I'), isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('FT.04T1'), isTrue);

      // Inválidas pela blacklist
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB(null), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB(''), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('   '), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('-'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('--'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('GERAL'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('geral'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('GERAL.'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('N/A'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('NA'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('NÃO APLICÁVEL'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('NAO APLICAVEL'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('SEM SALA'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('DIVERSOS'), isFalse);
    });
  });
}
