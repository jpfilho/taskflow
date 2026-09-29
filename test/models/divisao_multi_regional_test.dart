import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/divisao.dart';

void main() {
  group('Divisao Multi-Regional — Model & Compatibility Tests', () {
    test('Criação com múltiplas regionais preenche regionalIds e regionais', () {
      final divisao = Divisao(
        id: 'div-1',
        divisao: 'NEPTMC',
        regionalIds: ['reg-pe', 'reg-ba', 'reg-ce'],
        regionais: ['Pernambuco', 'Bahia', 'Ceará'],
        segmentoIds: ['seg-civil'],
        segmentos: ['Manutenção Civil'],
      );

      expect(divisao.id, 'div-1');
      expect(divisao.divisao, 'NEPTMC');
      expect(divisao.regionalIds, ['reg-pe', 'reg-ba', 'reg-ce']);
      expect(divisao.regionais, ['Pernambuco', 'Bahia', 'Ceará']);
      expect(divisao.regionalId, 'reg-pe'); // Legacy getter retorna a primeira ou primária
      expect(divisao.regional, 'Pernambuco');
    });

    test('Helper atuaNaRegional verifica pertinência corretamente', () {
      final divisao = Divisao(
        id: 'div-1',
        divisao: 'NEPTMC',
        regionalIds: ['reg-pe', 'reg-ba', 'reg-ce'],
        regionais: ['Pernambuco', 'Bahia', 'Ceará'],
      );

      expect(divisao.atuaNaRegional('reg-pe'), isTrue);
      expect(divisao.atuaNaRegional('reg-ba'), isTrue);
      expect(divisao.atuaNaRegional('reg-ce'), isTrue);
      expect(divisao.atuaNaRegional('reg-ma'), isFalse);
      expect(divisao.atuaNaRegional(null), isFalse);
      expect(divisao.atuaNaRegional(''), isFalse);
    });

    test('Compatibilidade: fromMap com estrutura N:N (divisoes_regionais)', () {
      final map = {
        'id': 'div-10',
        'divisao': 'Manutenção Geral',
        'divisoes_regionais': [
          {
            'regional_id': 'reg-1',
            'regionais': {'id': 'reg-1', 'regional': 'Regional Norte'}
          },
          {
            'regional_id': 'reg-2',
            'regionais': {'id': 'reg-2', 'regional': 'Regional Sul'}
          }
        ],
        'divisoes_segmentos': [
          {
            'segmento_id': 'seg-1',
            'segmentos': {'id': 'seg-1', 'segmento': 'Linhas'}
          }
        ]
      };

      final divisao = Divisao.fromMap(map);

      expect(divisao.id, 'div-10');
      expect(divisao.divisao, 'Manutenção Geral');
      expect(divisao.regionalIds, ['reg-1', 'reg-2']);
      expect(divisao.regionais, ['Regional Norte', 'Regional Sul']);
      expect(divisao.atuaNaRegional('reg-1'), isTrue);
      expect(divisao.atuaNaRegional('reg-2'), isTrue);
      expect(divisao.atuaNaRegional('reg-3'), isFalse);
    });

    test('Compatibilidade: fromMap com estrutura legada (regional_id único)', () {
      final mapLegacy = {
        'id': 'div-legacy',
        'divisao': 'Divisão Antiga',
        'regional_id': 'reg-leg-1',
        'regional': 'Regional Leste',
      };

      final divisao = Divisao.fromMap(mapLegacy);

      expect(divisao.id, 'div-legacy');
      expect(divisao.regionalId, 'reg-leg-1');
      expect(divisao.regional, 'Regional Leste');
      expect(divisao.regionalIds, ['reg-leg-1']);
      expect(divisao.regionais, ['Regional Leste']);
      expect(divisao.atuaNaRegional('reg-leg-1'), isTrue);
      expect(divisao.atuaNaRegional('reg-outro'), isFalse);
    });

    test('toMap() preserva dual-write com regional_id preenchido', () {
      final divisao = Divisao(
        id: 'div-2',
        divisao: 'Operação Especial',
        regionalIds: ['reg-a', 'reg-b'],
        regionais: ['Regional A', 'Regional B'],
      );

      final map = divisao.toMap();

      expect(map['id'], 'div-2');
      expect(map['divisao'], 'Operação Especial');
      expect(map['regional_id'], 'reg-a'); // Dual-write preenchido para compatibilidade
    });

    test('copyWith preserva e atualiza relacionamentos N:N', () {
      final original = Divisao(
        id: 'div-1',
        divisao: 'Original',
        regionalIds: ['reg-1'],
        regionais: ['Reg 1'],
      );

      final copy = original.copyWith(
        regionalIds: ['reg-1', 'reg-2'],
        regionais: ['Reg 1', 'Reg 2'],
      );

      expect(copy.regionalIds, ['reg-1', 'reg-2']);
      expect(copy.regionais, ['Reg 1', 'Reg 2']);
      expect(copy.atuaNaRegional('reg-2'), isTrue);
      expect(original.atuaNaRegional('reg-2'), isFalse);
    });
  });
}
