import '../models/task.dart';

class MockData {
  static List<Task> getTasks() {
    final now = DateTime.now();
    final year = now.year;
    final month = 12; // Dezembro
    
    return [
      // Row 1 - ANDA (Amarelo)
      Task(
        id: '',
        status: 'ANDA',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['BEA'],
        tipo: 'PMP',
        ordem: '43002079173',
        tarefa: 'MANUTENÇÃO PREVENTIVA ANUAL GGE 400G1 E 400G2',
        executor: 'ADNAEL, DANIEL, ERIALDO, LUIS CARLOS',
        frota: 'L200 SERV AUX',
        coordenador: 'LUIS CARLOS',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 16),
        dataFim: DateTime(year, month, 19),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 16),
            dataFim: DateTime(year, month, 19),
            label: 'BEA',
            tipo: 'BEA',
          ),
        ],
      ),
      
      // Row 2 - CONC (Verde) - Férias
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'FERIAS',
        ordem: '-NA-',
        tarefa: 'Férias',
        executor: 'JOAO PEDRO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 1),
        dataFim: DateTime(year, month, 5),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 1),
            dataFim: DateTime(year, month, 5),
            label: 'FER',
            tipo: 'FER',
          ),
        ],
      ),
      
      // Row 3 - CONC (Verde) - Compensação
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'COMPENSACAO',
        ordem: 'N/A',
        tarefa: 'COMPENSAÇÃO DE HORAS',
        executor: 'JORGE',
        frota: '-N/A-',
        coordenador: 'VILARINDO',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 6),
        dataFim: DateTime(year, month, 6),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 6),
            dataFim: DateTime(year, month, 6),
            label: 'COMP',
            tipo: 'COMP',
          ),
        ],
      ),
      
      // Row 4 - CONC (Verde) - Treinamento
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'TREINAMENTO',
        ordem: 'N/A',
        tarefa: 'Treinamento Siemens',
        executor: 'MARK, WELLIGTON',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 6),
        dataFim: DateTime(year, month, 6),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 6),
            dataFim: DateTime(year, month, 6),
            label: 'TRN',
            tipo: 'TRN',
          ),
        ],
      ),
      
      // Row 5 - CONC (Verde) - Compensação
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'COMPENSACAO',
        ordem: 'N/A',
        tarefa: 'Compensação',
        executor: 'HELIO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 7),
        dataFim: DateTime(year, month, 7),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 7),
            dataFim: DateTime(year, month, 7),
            label: 'COMP',
            tipo: 'COMP',
          ),
        ],
      ),
      
      // Row 6 - CONC (Verde) - Correção Vazamento
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['BSL'],
        tipo: 'CORRECAO',
        ordem: 'N/A',
        tarefa: 'Correção Vazamento Óleo',
        executor: 'CARLOS, ARNALDO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 8),
        dataFim: DateTime(year, month, 11),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 8),
            dataFim: DateTime(year, month, 9),
            label: 'BSL',
            tipo: 'BSL',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 10),
            dataFim: DateTime(year, month, 10),
            label: 'APO',
            tipo: 'APO',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 11),
            dataFim: DateTime(year, month, 11),
            label: 'BSL',
            tipo: 'BSL',
          ),
        ],
      ),
      
      // Row 7 - CONC (Verde) - Compensação 08 Dias
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'COMPENSACAO',
        ordem: 'N/A',
        tarefa: 'Compensação 08 Dias',
        executor: 'JOAO PEDRO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 12),
        dataFim: DateTime(year, month, 12),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 12),
            dataFim: DateTime(year, month, 12),
            label: 'COMP',
            tipo: 'COMP',
          ),
        ],
      ),
      
      // Row 8 - CONC (Verde) - Treinamento Disjuntor
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'TREINAMENTO',
        ordem: 'N/A',
        tarefa: 'Treinamento Disjuntor Siemens',
        executor: 'MARK, WELLIGTON, HELIO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 12),
        dataFim: DateTime(year, month, 17),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 12),
            dataFim: DateTime(year, month, 13),
            label: 'TRN',
            tipo: 'TRN',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 16),
            dataFim: DateTime(year, month, 17),
            label: 'TRN',
            tipo: 'TRN',
          ),
        ],
      ),
      
      // Row 9 - CONC (Verde) - Treinamento Novos Geradores
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'TREINAMENTO',
        ordem: 'N/A',
        tarefa: 'Treinamento Novos Geradores',
        executor: 'MARK, WELLIGTON, HELIO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 12),
        dataFim: DateTime(year, month, 17),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 12),
            dataFim: DateTime(year, month, 13),
            label: 'TRN',
            tipo: 'TRN',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 16),
            dataFim: DateTime(year, month, 17),
            label: 'TRN',
            tipo: 'TRN',
          ),
        ],
      ),
      
      // Row 10 - ANDA (Amarelo) - Férias
      Task(
        id: '',
        status: 'ANDA',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'FERIAS',
        ordem: '-NA-',
        tarefa: 'Férias',
        executor: 'GEORGE',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 13),
        dataFim: DateTime(year, month, 19),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 13),
            dataFim: DateTime(year, month, 19),
            label: 'FER',
            tipo: 'FER',
          ),
        ],
      ),
      
      // Row 11 - CONC (Verde) - Treinamento disjuntor 69 kV
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'TREINAMENTO',
        ordem: 'N/A',
        tarefa: 'Treinamento disjuntor 69 kV',
        executor: 'MARK, WELLIGTON, HELIO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 16),
        dataFim: DateTime(year, month, 20),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 16),
            dataFim: DateTime(year, month, 17),
            label: 'TRN',
            tipo: 'TRN',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 19),
            dataFim: DateTime(year, month, 20),
            label: 'TRN',
            tipo: 'TRN',
          ),
        ],
      ),
      
      // Row 12 - CONC (Verde) - Folga
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'COMPENSACAO',
        ordem: 'N/A',
        tarefa: 'Folga',
        executor: 'JOAO PEDRO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 18),
        dataFim: DateTime(year, month, 18),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 18),
            dataFim: DateTime(year, month, 18),
            label: 'COMP',
            tipo: 'COMP',
          ),
        ],
      ),
      
      // Row 13 - CONC (Verde) - Ida ao dentista
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'ADMIN',
        ordem: 'N/A',
        tarefa: 'Ida ao dentista',
        executor: 'HELIO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 19),
        dataFim: DateTime(year, month, 19),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 19),
            dataFim: DateTime(year, month, 19),
            label: 'ADM',
            tipo: 'ADM',
          ),
        ],
      ),
      
      // Row 14 - CONC (Verde) - Folga
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'COMPENSACAO',
        ordem: 'N/A',
        tarefa: 'Folga',
        executor: 'JORGE',
        frota: '-N/A-',
        coordenador: 'VILARINDO',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 20),
        dataFim: DateTime(year, month, 20),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 20),
            dataFim: DateTime(year, month, 20),
            label: 'COMP',
            tipo: 'COMP',
          ),
        ],
      ),
      
      // Row 15 - CONC (Verde) - Descarregar caminhão
      Task(
        id: '',
        status: 'CONC',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'OUTROS',
        ordem: 'N/A',
        tarefa: 'Descarregar caminhão',
        executor: 'CARLOS, ARNALDO',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 20),
        dataFim: DateTime(year, month, 24),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 20),
            dataFim: DateTime(year, month, 21),
            label: 'OUT',
            tipo: 'OUT',
          ),
          GanttSegment(
            dataInicio: DateTime(year, month, 23),
            dataFim: DateTime(year, month, 24),
            label: 'OUT',
            tipo: 'OUT',
          ),
        ],
      ),
      
      // Row 16 - ANDA (Amarelo) - Férias
      Task(
        id: '',
        status: 'ANDA',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'FERIAS',
        ordem: '-NA-',
        tarefa: 'Férias',
        executor: 'LUIS CARLOS',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 23),
        dataFim: DateTime(year, month, 27),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 23),
            dataFim: DateTime(year, month, 27),
            label: 'FER',
            tipo: 'FER',
          ),
        ],
      ),
      
      // Row 17 - PROG (Azul) - Treinamento PEMT
      Task(
        id: '',
        status: 'PROG',
        regional: 'TERESINA',
        divisao: 'OOTFA.C.SE',
        locais: ['OOTFA.C'],
        tipo: 'TREINAMENTO',
        ordem: 'N/A',
        tarefa: 'Treinamento PEMT - NR18',
        executor: 'MARK, WELLIGTON, HELIO, JOAO PEDRO, ADNAEL, ARNALDO, CARLOS',
        frota: '-N/A-',
        coordenador: 'PEREIRA',
        si: '-N/A-',
        dataInicio: DateTime(year, month, 26),
        dataFim: DateTime(year, month, 30),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime(year, month, 26),
            dataFim: DateTime(year, month, 30),
            label: 'TRN',
            tipo: 'TRN',
          ),
        ],
      ),
    ];
  }
}

