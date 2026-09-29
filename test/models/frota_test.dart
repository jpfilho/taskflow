import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/frota.dart';

void main() {
  group('Frota Model - Propriedade', () {
    test('Deve instanciar com default PROPRIO quando não informado', () {
      final frota = Frota(
        id: '123',
        nome: 'Hilux 01',
        tipoVeiculo: 'PICKUP',
        placa: 'ABC1234',
      );

      expect(frota.propriedade, equals(Frota.PROPRIO));
      expect(Frota.getPropriedadeLabel(frota.propriedade), equals('Próprio'));
    });

    test('Deve desserializar fromMap corretamente com propriedade PROPRIO, LOCADO e TERCEIRO', () {
      final mapLocado = {
        'id': '1',
        'nome': 'Caminhão 01',
        'tipo_veiculo': 'CAMINHAO',
        'placa': 'DEF5678',
        'propriedade': 'LOCADO',
      };
      final frotaLocado = Frota.fromMap(mapLocado);
      expect(frotaLocado.propriedade, equals('LOCADO'));
      expect(Frota.getPropriedadeLabel(frotaLocado.propriedade), equals('Locado'));

      final mapTerceiro = {
        'id': '2',
        'nome': 'Munck 01',
        'tipo_veiculo': 'MUNCK',
        'placa': 'GHI9012',
        'propriedade': 'TERCEIRO',
      };
      final frotaTerceiro = Frota.fromMap(mapTerceiro);
      expect(frotaTerceiro.propriedade, equals('TERCEIRO'));
      expect(Frota.getPropriedadeLabel(frotaTerceiro.propriedade), equals('Terceiro'));

      // Fallback para nulo
      final mapSemPropriedade = {
        'id': '3',
        'nome': 'Carro 01',
        'tipo_veiculo': 'CARRO_LEVE',
        'placa': 'JKL3456',
      };
      final frotaFallback = Frota.fromMap(mapSemPropriedade);
      expect(frotaFallback.propriedade, equals('PROPRIO'));
      expect(Frota.getPropriedadeLabel(frotaFallback.propriedade), equals('Próprio'));
    });

    test('toMap deve conter o campo propriedade em uppercase', () {
      final frota = Frota(
        id: '123',
        nome: 'Hilux 01',
        tipoVeiculo: 'PICKUP',
        placa: 'ABC1234',
        propriedade: 'locado',
      );

      final map = frota.toMap();
      expect(map['propriedade'], equals('LOCADO'));
    });

    test('copyWith deve atualizar a propriedade corretamente', () {
      final frota = Frota(
        id: '123',
        nome: 'Hilux 01',
        tipoVeiculo: 'PICKUP',
        placa: 'ABC1234',
        propriedade: Frota.PROPRIO,
      );

      final atualizada = frota.copyWith(propriedade: Frota.TERCEIRO);
      expect(atualizada.propriedade, equals(Frota.TERCEIRO));
      expect(Frota.getPropriedadeLabel(atualizada.propriedade), equals('Terceiro'));
    });
  });
}
