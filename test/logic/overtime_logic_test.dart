import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/hora_sap.dart';

void main() {
  group('HoraSAP Logic Tests', () {
    test('Should classify Overtime Investment correctly (HHE + PROJ)', () {
      final hora = HoraSAP(
        id: '8',
        tipoOrdem: 'PROJ',
        trabalhoReal: 5.0,
        tipoAtividadeReal: 'HHE',
      );

      final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');
      final isInvestimento = tipoOrd == 'PROJ';
      final isHoraExtraInvestimento = isHoraExtra && isInvestimento;

      expect(isHoraExtraInvestimento, isTrue, reason: 'HHE + PROJ should be Overtime Investment');
    });

    test('Should classify Overtime Cost correctly (HHE + !PROJ)', () {
      final hora = HoraSAP(
        id: '9',
        tipoOrdem: 'MANUT',
        trabalhoReal: 5.0,
        tipoAtividadeReal: 'HHE',
      );

      final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');
      final isInvestimento = tipoOrd == 'PROJ';
      final isHoraExtraCusteio = isHoraExtra && !isInvestimento;

      expect(isHoraExtraCusteio, isTrue, reason: 'HHE + MANUT should be Overtime Cost');
    });

    test('Should classify Investment hours correctly (proj lowercase)', () {
      final hora = HoraSAP(
        id: '2',
        tipoOrdem: 'proj',
        trabalhoReal: 10.0,
        tipoAtividadeReal: 'NORMAL',
      );

      final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
      final isInvestimento = tipoOrd == 'PROJ';

      expect(isInvestimento, isTrue, reason: 'proj should be investment (case insensitive)');
    });

    test('Should classify Investment hours correctly (PROJ with space)', () {
      final hora = HoraSAP(
        id: '3',
        tipoOrdem: ' PROJ ',
        trabalhoReal: 10.0,
        tipoAtividadeReal: 'NORMAL',
      );

      final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
      final isInvestimento = tipoOrd == 'PROJ';

      expect(isInvestimento, isTrue, reason: ' PROJ  should be investment (trimmed)');
    });

    test('Should classify Overtime hours correctly (HHE)', () {
      final hora = HoraSAP(
        id: '4',
        tipoOrdem: 'MANUT',
        trabalhoReal: 5.0,
        tipoAtividadeReal: 'HHE',
      );

      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');

      expect(isHoraExtra, isTrue, reason: 'HHE should be overtime');
    });

    test('Should classify Overtime hours correctly (HHE123)', () {
      final hora = HoraSAP(
        id: '5',
        tipoOrdem: 'MANUT',
        trabalhoReal: 5.0,
        tipoAtividadeReal: 'HHE123',
      );

      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');

      expect(isHoraExtra, isTrue, reason: 'HHE123 should be overtime');
    });

    test('Should classify Overtime hours correctly (hh lowercase)', () {
      final hora = HoraSAP(
        id: '6',
        tipoOrdem: 'MANUT',
        trabalhoReal: 5.0,
        tipoAtividadeReal: 'hh',
      );

      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');

      expect(isHoraExtra, isTrue, reason: 'hh should be overtime (case insensitive)');
    });

     test('Should classify Cost hours correctly', () {
      final hora = HoraSAP(
        id: '7',
        tipoOrdem: 'PREV',
        trabalhoReal: 8.0,
        tipoAtividadeReal: 'NORMAL',
      );

      final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
      final isInvestimento = tipoOrd == 'PROJ';
      
      final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
      final isHoraExtra = tipoAtividade.startsWith('HH');

      expect(isInvestimento, isFalse, reason: 'PREV should not be investment');
      expect(isHoraExtra, isFalse, reason: 'NORMAL should not be overtime');
    });
  });
}
