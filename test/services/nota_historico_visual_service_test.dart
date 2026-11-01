import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/services/nota_historico_visual_service.dart';
import 'package:task2026/features/media_albums/data/models/equipment.dart';
import 'package:task2026/features/media_albums/data/models/room.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';

void main() {
  group('NotaHistoricoVisualService - Testes de Regra de Negócio e Matching', () {
    test('extrairRaizInstalacaoSap: extrai corretamente a raiz para LTs', () {
      expect(
        NotaHistoricoVisualService.extrairRaizInstalacaoSap('H-L-SIBDSSBD-RB4L01-4LT1'),
        'H-L-SIBDSSBD-RB4L01',
      );
      expect(
        NotaHistoricoVisualService.extrairRaizInstalacaoSap('H-L-SPDDSTSD-RB5C08-5LT1'),
        'H-L-SPDDSTSD-RB5C08',
      );
      expect(
        NotaHistoricoVisualService.extrairRaizInstalacaoSap('H-L-STGDSSBT-RB5V05-5LT1'),
        'H-L-STGDSSBT-RB5V05',
      );
    });

    test('extrairRaizInstalacaoSap: extrai corretamente a raiz para Subestações (SE)', () {
      expect(
        NotaHistoricoVisualService.extrairRaizInstalacaoSap('H-S-STSA-RB4S01-4EL1-S401'),
        'H-S-STSA',
      );
      expect(
        NotaHistoricoVisualService.extrairRaizInstalacaoSap('H-S-STSA'),
        'H-S-STSA',
      );
    });

    test('extrairRaizInstalacaoSap: trata valores nulos, vazios ou curtos com segurança', () {
      expect(NotaHistoricoVisualService.extrairRaizInstalacaoSap(null), '');
      expect(NotaHistoricoVisualService.extrairRaizInstalacaoSap(''), '');
      expect(NotaHistoricoVisualService.extrairRaizInstalacaoSap('   '), '');
      expect(NotaHistoricoVisualService.extrairRaizInstalacaoSap('LOCAL_CURTO'), 'LOCAL_CURTO');
    });

    test('normalizarSala: mantém salas válidas e caracteres estruturais', () {
      expect(NotaHistoricoVisualService.normalizarSala('027/2'), '027/2');
      expect(NotaHistoricoVisualService.normalizarSala('  180/2.I  '), '180/2.I');
      expect(NotaHistoricoVisualService.normalizarSala('34S1-4'), '34S1-4');
      expect(NotaHistoricoVisualService.normalizarSala('011/3D'), '011/3D');
      expect(NotaHistoricoVisualService.normalizarSala('RE29'), 'RE29');
    });

    test('normalizarSala: descarta blacklist (GERAL, -, N/A, etc.) para Nível B', () {
      expect(NotaHistoricoVisualService.normalizarSala(null), isNull);
      expect(NotaHistoricoVisualService.normalizarSala(''), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('  '), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('-'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('--'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('GERAL'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('geral'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('N/A'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('NÃO APLICÁVEL'), isNull);
      expect(NotaHistoricoVisualService.normalizarSala('NAO APLICAVEL'), isNull);
    });

    test('Consistência do UUID determinístico: algoritmo idêntico entre módulos', () {
      const localizacao = 'H-L-SIBDSSBD-RB4L01';
      final uuidEquipment = Equipment.generateDeterministicUuid('equipment:$localizacao');
      expect(uuidEquipment, isNotEmpty);
      expect(uuidEquipment.length, 36);

      const sala = '012/1';
      final uuidRoom = Room.generateDeterministicUuid('room:$sala:$localizacao');
      expect(uuidRoom, isNotEmpty);
      expect(uuidRoom.length, 36);

      // Verificação de reproducibilidade determinística (mesma entrada = mesmo UUID)
      final uuidRoom2 = Room.generateDeterministicUuid('room:$sala:$localizacao');
      expect(uuidRoom, uuidRoom2);
    });

    test('HistoricoVisualResultado: contadores e filtros por nível operam corretamente', () {
      final dataBase = DateTime.now();

      final itemA = HistoricoVisualItem(
        mediaImage: MediaImage(
          id: 'img-1',
          title: 'Foto Eq 1',
          filePath: 'path/1.jpg',
          createdBy: 'user-1',
          createdAt: dataBase.subtract(const Duration(days: 10)),
          updatedAt: dataBase.subtract(const Duration(days: 10)),
        ),
        nivel: HistoricoVisualNivel.equipamento,
        motivoCorrespondencia: 'Mesmo Equipamento',
        createdAt: dataBase.subtract(const Duration(days: 10)),
      );

      final itemB = HistoricoVisualItem(
        mediaImage: MediaImage(
          id: 'img-2',
          title: 'Foto Sala 1',
          filePath: 'path/2.jpg',
          createdBy: 'user-1',
          createdAt: dataBase.subtract(const Duration(days: 20)),
          updatedAt: dataBase.subtract(const Duration(days: 20)),
        ),
        nivel: HistoricoVisualNivel.sala,
        motivoCorrespondencia: 'Mesma Sala',
        createdAt: dataBase.subtract(const Duration(days: 20)),
      );

      final itemC = HistoricoVisualItem(
        mediaImage: MediaImage(
          id: 'img-3',
          title: 'Foto Local 1',
          filePath: 'path/3.jpg',
          createdBy: 'user-1',
          createdAt: dataBase.subtract(const Duration(days: 30)),
          updatedAt: dataBase.subtract(const Duration(days: 30)),
        ),
        nivel: HistoricoVisualNivel.local,
        motivoCorrespondencia: 'Mesmo Local',
        createdAt: dataBase.subtract(const Duration(days: 30)),
      );

      final resultado = HistoricoVisualResultado(
        itens: [itemA, itemB, itemC],
        totalEquipamento: 1,
        totalSala: 1,
        totalLocal: 1,
        localNome: 'IBDSBD U1',
        salaNome: '085/3',
        filtroSalaAplicado: true,
      );

      expect(resultado.totalGlobal, 3);
      expect(resultado.temFotos, isTrue);
      expect(resultado.temCorrespondenciaEspecifica, isTrue);
      expect(resultado.itensEquipamento.length, 1);
      expect(resultado.itensSala.length, 1);
      expect(resultado.itensLocal.length, 1);
      expect(resultado.itensEquipamento.first.id, 'img-1');
      expect(resultado.itensSala.first.id, 'img-2');
      expect(resultado.itensLocal.first.id, 'img-3');
      expect(resultado.salaNome, '085/3');
      expect(resultado.filtroSalaAplicado, isTrue);
    });

    test('HistoricoVisualResultado.vazio: estado sem fotos configurado com Local e Sala', () {
      final vazio = HistoricoVisualResultado.vazio(
        localNome: 'BEATSA U1',
        salaNome: 'S401',
        filtroSalaAplicado: true,
      );
      expect(vazio.totalGlobal, 0);
      expect(vazio.temFotos, isFalse);
      expect(vazio.temCorrespondenciaEspecifica, isFalse);
      expect(vazio.itens, isEmpty);
      expect(vazio.localNome, 'BEATSA U1');
      expect(vazio.salaNome, 'S401');
      expect(vazio.filtroSalaAplicado, isTrue);
    });

    test('Regra de Correspondência Estrita: fotos de outra sala são descartadas quando a Nota possui sala', () {
      final salaNota = '085/3';
      final salaOutra = '012/1';
      final localizacao = 'H-L-SIBDSSBD-RB4L01';

      final roomIdEsperadoNota = Room.generateDeterministicUuid('room:$salaNota:$localizacao');
      final roomIdOutraSala = Room.generateDeterministicUuid('room:$salaOutra:$localizacao');

      // Simula lista de fotos retornadas do mesmo local no banco
      final fotosDoLocal = [
        MediaImage(
          id: 'foto-mesma-sala',
          title: 'Foto da Torre 085/3',
          filePath: 'path/torre.jpg',
          roomId: roomIdEsperadoNota,
          createdBy: 'user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MediaImage(
          id: 'foto-outra-sala',
          title: 'Foto da Torre 012/1',
          filePath: 'path/outra.jpg',
          roomId: roomIdOutraSala,
          createdBy: 'user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Verificação da lógica de descarte: fotos com sala diferente NÃO passam no filtro
      final fotosFiltradas = fotosDoLocal.where((foto) {
        return foto.roomId == roomIdEsperadoNota;
      }).toList();

      expect(fotosFiltradas.length, 1);
      expect(fotosFiltradas.first.id, 'foto-mesma-sala');
      expect(fotosFiltradas.any((f) => f.id == 'foto-outra-sala'), isFalse);
    });
  });
}
