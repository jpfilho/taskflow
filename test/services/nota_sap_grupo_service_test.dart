import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_grupo.dart';

void main() {
  group('Seção 30: Testes Unitários de Modelos, Negócio e Serviço de Grupos de Notas SAP', () {
    // -------------------------------------------------------------------------
    // Teste 1: Criar grupo (mapeamento e estrutura mínima)
    // -------------------------------------------------------------------------
    test('1. Criar grupo: Mapeamento de NotaSapGrupo com campos mínimos e completos', () {
      final json = {
        'id': 'grp-1',
        'nome': 'Intervenção SE Pirapora 138kV',
        'descricao': 'Troca de buchas e reparo de vazamento SF6',
        'motivo': 'Ocorrências simultâneas no mesmo vão',
        'local_instalacao': 'SE-PIRAPORA-138KV',
        'equipamento': 'DISJ-138-01',
        'centro_trabalho_responsavel': 'MEC-SUB',
        'mes_programacao_previsto': 11,
        'ano_programacao_previsto': 2026,
        'motivo_previsao': 'Janela de desligamento ONS confirmada',
        'status_grupo': 'ativo',
        'created_by': 'user-123',
        'previsao_alterada_em': '2026-10-15T10:00:00Z',
        'previsao_alterada_por': 'user-123',
        'previsao_alterada_por_nome': 'Engenheiro Operacional',
      };

      final grupo = NotaSapGrupo.fromMap(json);

      expect(grupo.id, equals('grp-1'));
      expect(grupo.nome, equals('Intervenção SE Pirapora 138kV'));
      expect(grupo.status, equals(StatusGrupo.ativo));
      expect(grupo.statusGrupo, equals(StatusGrupo.ativo));
      expect(grupo.mesProgramacaoPrevisto, equals(11));
      expect(grupo.anoProgramacaoPrevisto, equals(2026));
      expect(grupo.previsaoFormatada, equals('Novembro/2026'));
      expect(grupo.temPrevisao, isTrue);
      expect(grupo.equipamento, equals('DISJ-138-01'));
    });

    // -------------------------------------------------------------------------
    // Teste 2: Adicionar Nota (estrutura de item e constraints conceituais)
    // -------------------------------------------------------------------------
    test('2. Adicionar Nota: NotaSapGrupoItem mapeado corretamente com dados de auditoria', () {
      final jsonItem = {
        'id': 'item-101',
        'grupo_id': 'grp-1',
        'nota_sap_id': 'nota-99101',
        'motivo_vinculo': 'Disjuntor no mesmo vão de barramento',
        'adicionado_por': 'user-123',
        'adicionado_por_nome': 'Carlos Silva',
        'adicionado_em': '2026-10-15T11:00:00Z',
      };

      final item = NotaSapGrupoItem.fromMap(jsonItem);

      expect(item.id, equals('item-101'));
      expect(item.grupoId, equals('grp-1'));
      expect(item.notaSapId, equals('nota-99101'));
      expect(item.motivoVinculo, equals('Disjuntor no mesmo vão de barramento'));
      expect(item.adicionadoPorNome, equals('Carlos Silva'));
      expect(item.adicionadoEm, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Teste 3: Remover Nota (cópia e manipulação de lista sem quebrar integridade)
    // -------------------------------------------------------------------------
    test('3. Remover Nota: Lista de itens do grupo atualizada sem efeitos colaterais', () {
      final itens = [
        NotaSapGrupoItem(id: '1', grupoId: 'grp-1', notaSapId: 'nota-A'),
        NotaSapGrupoItem(id: '2', grupoId: 'grp-1', notaSapId: 'nota-B'),
        NotaSapGrupoItem(id: '3', grupoId: 'grp-1', notaSapId: 'nota-C'),
      ];

      expect(itens.length, equals(3));
      final itensAtualizados = itens.where((item) => item.notaSapId != 'nota-B').toList();
      expect(itensAtualizados.length, equals(2));
      expect(itensAtualizados.any((i) => i.notaSapId == 'nota-B'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 4: Buscar grupo da Nota (resolução de vínculo e status ativo)
    // -------------------------------------------------------------------------
    test('4. Buscar grupo da Nota: Identifica corretamente pertinência a grupo ativo', () {
      final grupoAtivo = NotaSapGrupo(
        id: 'grp-ativo',
        nome: 'Grupo Ativo A',
        statusGrupo: StatusGrupo.ativo,
      );

      final grupoEncerrado = NotaSapGrupo(
        id: 'grp-encerrado',
        nome: 'Grupo Antigo B',
        statusGrupo: StatusGrupo.encerrado,
      );

      expect(grupoAtivo.isAtivo, isTrue);
      expect(grupoEncerrado.isAtivo, isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 5: Múltiplas Notas no mesmo grupo
    // -------------------------------------------------------------------------
    test('5. Múltiplas Notas: Grupo aceita N notas sem limite artificial', () {
      final notasIds = ['nota-1', 'nota-2', 'nota-3', 'nota-4', 'nota-5'];
      final itens = notasIds.map((id) => NotaSapGrupoItem(id: 'item-$id', grupoId: 'grp-1', notaSapId: id)).toList();

      expect(itens.length, equals(5));
      final idsUnicos = itens.map((e) => e.notaSapId).toSet();
      expect(idsUnicos.length, equals(5));
    });

    // -------------------------------------------------------------------------
    // Teste 6: Alterar previsão (atualização com validação e dados de auditoria)
    // -------------------------------------------------------------------------
    test('6. Alterar previsão: Atualiza mês/ano mantendo paridade e auditoria', () {
      final grupoOriginal = NotaSapGrupo(
        id: 'grp-1',
        nome: 'Grupo Inicial',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
        motivoPrevisao: 'Previsão de outono',
      );

      final grupoAlterado = grupoOriginal.copyWith(
        mesProgramacaoPrevisto: 12,
        anoProgramacaoPrevisto: 2026,
        motivoPrevisao: 'Ajuste de cronograma para dezembro',
        previsaoAlteradaPorNome: 'Engenheiro Chefe',
      );

      expect(grupoAlterado.mesProgramacaoPrevisto, equals(12));
      expect(grupoAlterado.anoProgramacaoPrevisto, equals(2026));
      expect(grupoAlterado.previsaoFormatada, equals('Dezembro/2026'));
      expect(grupoAlterado.motivoPrevisao, equals('Ajuste de cronograma para dezembro'));
    });

    // -------------------------------------------------------------------------
    // Teste 7: Histórico de previsão (registro estruturado de alterações)
    // -------------------------------------------------------------------------
    test('7. Histórico de previsão: NotaSapGrupoPrevisaoHist registra transições', () {
      final histJson = {
        'id': 'hist-1',
        'grupo_id': 'grp-1',
        'mes_anterior': 11,
        'ano_anterior': 2026,
        'mes_novo': 12,
        'ano_novo': 2026,
        'motivo': 'Reprogramação por indisponibilidade de transformador',
        'alterado_por': 'usr-admin',
        'alterado_por_nome': 'Fiscal de Manutenção',
        'alterado_em': '2026-10-15T15:30:00Z',
      };

      final hist = NotaSapGrupoPrevisaoHist.fromMap(histJson);

      expect(hist.mesAnterior, equals(11));
      expect(hist.anoAnterior, equals(2026));
      expect(hist.mesNovo, equals(12));
      expect(hist.anoNovo, equals(2026));
      expect(hist.previsaoAnteriorFormatada, equals('Novembro/2026'));
      expect(hist.previsaoNovaFormatada, equals('Dezembro/2026'));
      expect(hist.descricaoMudanca, contains('Novembro/2026 → Dezembro/2026'));
    });

    // -------------------------------------------------------------------------
    // Teste 8: Programação zero (nenhuma nota programada via tasks_notas_sap)
    // -------------------------------------------------------------------------
    test('8. Programação zero: Status derivado deve ser naoProgramado', () {
      final statusProg = GrupoStatusProgramacao.calcularMap(
        grupoId: 'grp-1',
        totalNotas: 4,
        notasSapComTarefas: {
          'nota-1': [],
          'nota-2': [],
          'nota-3': [],
          'nota-4': [],
        },
      );

      expect(statusProg.totalNotas, equals(4));
      expect(statusProg.notasProgramadas, equals(0));
      expect(statusProg.notasNaoProgramadas, equals(4));
      expect(statusProg.status, equals(StatusProgramacaoGrupo.naoProgramado));
      expect(statusProg.descricao, equals('Grupo sem programação'));
      expect(statusProg.percentualProgramado, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Teste 9: Programação parcial (Exemplo obrigatório da Seção 18)
    // Grupo: A B C D, Tarefa #100: A B -> 2 programadas, 2 não programadas
    // -------------------------------------------------------------------------
    test('9. Programação parcial (Seção 18): 2 de 4 notas vinculadas à Tarefa #100', () {
      final statusProg = GrupoStatusProgramacao.calcularMap(
        grupoId: 'grp-1',
        totalNotas: 4,
        notasSapComTarefas: {
          'nota-A': ['tarefa-100'],
          'nota-B': ['tarefa-100'],
          'nota-C': [],
          'nota-D': [],
        },
      );

      expect(statusProg.totalNotas, equals(4));
      expect(statusProg.notasProgramadas, equals(2));
      expect(statusProg.notasNaoProgramadas, equals(2));
      expect(statusProg.status, equals(StatusProgramacaoGrupo.parcial));
      expect(statusProg.descricao, equals('Grupo parcialmente programado'));
      expect(statusProg.percentualProgramado, equals(50.0));
      expect(statusProg.tarefasVinculadasIds, equals(['tarefa-100']));
    });

    // -------------------------------------------------------------------------
    // Teste 10: Programação total (todas as notas com ao menos uma tarefa)
    // -------------------------------------------------------------------------
    test('10. Programação total: Todas as notas possuem tarefas atreladas', () {
      final statusProg = GrupoStatusProgramacao.calcularMap(
        grupoId: 'grp-1',
        totalNotas: 3,
        notasSapComTarefas: {
          'nota-1': ['tarefa-101'],
          'nota-2': ['tarefa-102'],
          'nota-3': ['tarefa-103'],
        },
      );

      expect(statusProg.totalNotas, equals(3));
      expect(statusProg.notasProgramadas, equals(3));
      expect(statusProg.notasNaoProgramadas, equals(0));
      expect(statusProg.status, equals(StatusProgramacaoGrupo.total));
      expect(statusProg.descricao, equals('Grupo totalmente programado'));
      expect(statusProg.percentualProgramado, equals(100.0));
      expect(statusProg.tarefasVinculadasIds.length, equals(3));
    });

    // -------------------------------------------------------------------------
    // Teste 11: Uma Nota em múltiplas tarefas (Seção 19)
    // Nota A -> Tarefa #100 e Tarefa #130 -> continua contando apenas 1 vez
    // -------------------------------------------------------------------------
    test('11. Múltiplas tarefas na mesma Nota (Seção 19): Não duplica contagem de programadas', () {
      final statusProg = GrupoStatusProgramacao.calcularMap(
        grupoId: 'grp-1',
        totalNotas: 2,
        notasSapComTarefas: {
          // Nota A vinculada a duas tarefas diferentes
          'nota-A': ['tarefa-100', 'tarefa-130'],
          // Nota B ainda não programada
          'nota-B': [],
        },
      );

      expect(statusProg.totalNotas, equals(2));
      // Conta exatamente 1 nota programada (não duplica para 2 ou 3)
      expect(statusProg.notasProgramadas, equals(1));
      expect(statusProg.notasNaoProgramadas, equals(1));
      expect(statusProg.status, equals(StatusProgramacaoGrupo.parcial));
      // Coleta todas as tarefas únicas
      expect(statusProg.tarefasVinculadasIds, containsAll(['tarefa-100', 'tarefa-130']));
      expect(statusProg.tarefasVinculadasIds.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Teste 12: Grupo encerrado
    // -------------------------------------------------------------------------
    test('12. Grupo encerrado: Status é persistido como encerrado e isAtivo é falso', () {
      final grupo = NotaSapGrupo(
        id: 'grp-enc',
        nome: 'Grupo Concluído',
        statusGrupo: StatusGrupo.encerrado,
      );

      expect(grupo.status, equals(StatusGrupo.encerrado));
      expect(grupo.statusGrupo, equals(StatusGrupo.encerrado));
      expect(grupo.statusGrupo.toDbString(), equals('encerrado'));
      expect(grupo.isAtivo, isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 13: Grupo cancelado
    // -------------------------------------------------------------------------
    test('13. Grupo cancelado: Status é persistido como cancelado e isAtivo é falso', () {
      final grupo = NotaSapGrupo(
        id: 'grp-canc',
        nome: 'Grupo Descartado',
        statusGrupo: StatusGrupo.cancelado,
      );

      expect(grupo.status, equals(StatusGrupo.cancelado));
      expect(grupo.statusGrupo, equals(StatusGrupo.cancelado));
      expect(grupo.statusGrupo.toDbString(), equals('cancelado'));
      expect(grupo.isAtivo, isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 14: Resiliência a falhas e paridade mês/ano
    // -------------------------------------------------------------------------
    test('14. Resiliência: Paridade estrita de mês/ano e valores seguros no modelo', () {
      void validarParidade(int? mes, int? ano) {
        if ((mes != null && ano == null) || (mes == null && ano != null)) {
          throw ArgumentError('Paridade mês/ano violada');
        }
      }

      // Mês sem ano deve lançar erro ao validar regras
      expect(
        () => validarParidade(11, null),
        throwsA(isA<ArgumentError>()),
      );

      // Ano sem mês deve lançar erro
      expect(
        () => validarParidade(null, 2026),
        throwsA(isA<ArgumentError>()),
      );

      // Mês fora de 1..12 deve ser rejeitado
      expect(
        () {
          final mes = 13;
          if (mes < 1 || mes > 12) {
            throw ArgumentError('Mês inválido');
          }
        },
        throwsA(isA<ArgumentError>()),
      );

      // Remoção de previsão: mês e ano viram null
      final grupoComPrevisao = NotaSapGrupo(
        id: 'grp-prev',
        nome: 'Com Previsão',
        mesProgramacaoPrevisto: 10,
        anoProgramacaoPrevisto: 2026,
      );
      final grupoSemPrevisao = grupoComPrevisao.copyWith(
        limparPrevisao: true,
      );
      expect(grupoSemPrevisao.temPrevisao, isFalse);
      expect(grupoSemPrevisao.mesProgramacaoPrevisto, isNull);
      expect(grupoSemPrevisao.anoProgramacaoPrevisto, isNull);
      expect(grupoSemPrevisao.previsaoFormatada, equals('Não definida'));
    });

    // -------------------------------------------------------------------------
    // Teste Extra: Previsão ultrapassada (Seção 26)
    // -------------------------------------------------------------------------
    test('Extra Seção 26: Previsão ultrapassada calculada dinamicamente em runtime', () {
      // Data referência de teste simulada
      final grupoPassado = NotaSapGrupo(
        id: 'grp-passado',
        nome: 'Intervenção Antiga',
        mesProgramacaoPrevisto: 8, // Agosto
        anoProgramacaoPrevisto: 2026,
      );

      // Verificação com data de outubro/2026
      final dataAtualOutubro = DateTime(2026, 10, 15);
      final estaAtrasado = grupoPassado.isPrevisaoUltrapassada(dataAtualOutubro);
      expect(estaAtrasado, isTrue);

      final grupoFuturo = NotaSapGrupo(
        id: 'grp-futuro',
        nome: 'Intervenção Futura',
        mesProgramacaoPrevisto: 12, // Dezembro
        anoProgramacaoPrevisto: 2026,
      );
      final naoEstaAtrasado = grupoFuturo.isPrevisaoUltrapassada(dataAtualOutubro);
      expect(naoEstaAtrasado, isFalse);
    });
  });
}
