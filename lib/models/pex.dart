import 'dart:convert';

class PEX {
  final String? id;
  final String taskId;
  
  // Cabeçalho
  final String? numeroPex;
  final String? si;
  final int? revisaoPex;
  final DateTime? dataElaboracao;
  
  // 1. IDENTIFICAÇÃO DA INTERVENÇÃO
  final String? responsavelNome;
  final String? responsavelIdSap;
  final String? responsavelContato;
  final String? substitutoNome;
  final String? substitutoIdSap;
  final String? substitutoContato;
  final String? fiscalTecnicoNome;
  final String? fiscalTecnicoIdSap;
  final String? fiscalTecnicoContato;
  final String? coordenadorNome;
  final String? coordenadorIdSap;
  final String? coordenadorContato;
  final String? tecnicoSegNome;
  final String? tecnicoSegIdSap;
  final String? tecnicoSegContato;
  
  // Período
  final DateTime? dataInicio;
  final String? horaInicio; // HH:mm
  final DateTime? dataFim;
  final String? horaFim; // HH:mm
  final bool? periodicidade;
  final bool? continuo;
  
  // Instalação e Equipamentos
  final String? instalacao;
  final String? equipamentos;
  
  // Resumo da Atividade
  final String? resumoAtividade;
  
  // Configuração
  final String? configuracaoRecebimento;
  final String? configuracaoDurante;
  final String? configuracaoDevolucao;
  
  // Aterramento
  final String? aterramentoDescricao;
  final int? aterramentoTotalUnidades;
  
  // Informações adicionais
  final String? informacoesAdicionais;
  
  // Distâncias de Segurança (JSON)
  final String? distanciasSeguranca; // JSON
  
  // 2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO (JSON)
  final String? dadosPlanejamento; // JSON
  
  // 3. RECURSOS / FERRAMENTAS / MATERIAIS (JSON)
  final String? recursosEpi; // JSON
  final String? recursosEpc; // JSON
  final String? recursosTransporte; // JSON
  final String? recursosMaterialConsumo; // JSON
  final String? recursosFerramentas; // JSON
  final String? recursosComunicacao; // JSON
  final String? recursosDocumentacao; // JSON
  final String? recursosInstrumentos; // JSON
  
  // 4. DETALHAMENTO DA INTERVENÇÃO (JSON)
  final String? detalhamentoIntervencao; // JSON
  
  // 5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS (JSON)
  final String? recursosHumanos; // JSON
  
  // Nível de risco
  final String? nivelRisco;
  
  // Aprovação
  final String? aprovador;
  final DateTime? dataAprovacao;
  
  // Status
  final String status;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PEX({
    this.id,
    required this.taskId,
    this.numeroPex,
    this.si,
    this.revisaoPex,
    this.dataElaboracao,
    this.responsavelNome,
    this.responsavelIdSap,
    this.responsavelContato,
    this.substitutoNome,
    this.substitutoIdSap,
    this.substitutoContato,
    this.fiscalTecnicoNome,
    this.fiscalTecnicoIdSap,
    this.fiscalTecnicoContato,
    this.coordenadorNome,
    this.coordenadorIdSap,
    this.coordenadorContato,
    this.tecnicoSegNome,
    this.tecnicoSegIdSap,
    this.tecnicoSegContato,
    this.dataInicio,
    this.horaInicio,
    this.dataFim,
    this.horaFim,
    this.periodicidade,
    this.continuo,
    this.instalacao,
    this.equipamentos,
    this.resumoAtividade,
    this.configuracaoRecebimento,
    this.configuracaoDurante,
    this.configuracaoDevolucao,
    this.aterramentoDescricao,
    this.aterramentoTotalUnidades,
    this.informacoesAdicionais,
    this.distanciasSeguranca,
    this.dadosPlanejamento,
    this.recursosEpi,
    this.recursosEpc,
    this.recursosTransporte,
    this.recursosMaterialConsumo,
    this.recursosFerramentas,
    this.recursosComunicacao,
    this.recursosDocumentacao,
    this.recursosInstrumentos,
    this.detalhamentoIntervencao,
    this.recursosHumanos,
    this.nivelRisco,
    this.aprovador,
    this.dataAprovacao,
    this.status = 'rascunho',
    this.createdAt,
    this.updatedAt,
  });

  factory PEX.fromMap(Map<String, dynamic> map) {
    return PEX(
      id: map['id'] as String?,
      taskId: map['task_id'] as String,
      numeroPex: map['numero_pex'] as String?,
      si: map['si'] as String?,
      revisaoPex: map['revisao_pex'] as int?,
      dataElaboracao: map['data_elaboracao'] != null
          ? DateTime.parse(map['data_elaboracao'] as String)
          : null,
      responsavelNome: map['responsavel_nome'] as String?,
      responsavelIdSap: map['responsavel_id_sap'] as String?,
      responsavelContato: map['responsavel_contato'] as String?,
      substitutoNome: map['substituto_nome'] as String?,
      substitutoIdSap: map['substituto_id_sap'] as String?,
      substitutoContato: map['substituto_contato'] as String?,
      fiscalTecnicoNome: map['fiscal_tecnico_nome'] as String?,
      fiscalTecnicoIdSap: map['fiscal_tecnico_id_sap'] as String?,
      fiscalTecnicoContato: map['fiscal_tecnico_contato'] as String?,
      coordenadorNome: map['coordenador_nome'] as String?,
      coordenadorIdSap: map['coordenador_id_sap'] as String?,
      coordenadorContato: map['coordenador_contato'] as String?,
      tecnicoSegNome: map['tecnico_seg_nome'] as String?,
      tecnicoSegIdSap: map['tecnico_seg_id_sap'] as String?,
      tecnicoSegContato: map['tecnico_seg_contato'] as String?,
      dataInicio: map['data_inicio'] != null
          ? DateTime.parse(map['data_inicio'] as String)
          : null,
      horaInicio: map['hora_inicio'] as String?,
      dataFim: map['data_fim'] != null
          ? DateTime.parse(map['data_fim'] as String)
          : null,
      horaFim: map['hora_fim'] as String?,
      periodicidade: map['periodicidade'] as bool?,
      continuo: map['continuo'] as bool?,
      instalacao: map['instalacao'] as String?,
      equipamentos: map['equipamentos'] as String?,
      resumoAtividade: map['resumo_atividade'] as String?,
      configuracaoRecebimento: map['configuracao_recebimento'] as String?,
      configuracaoDurante: map['configuracao_durante'] as String?,
      configuracaoDevolucao: map['configuracao_devolucao'] as String?,
      aterramentoDescricao: map['aterramento_descricao'] as String?,
      aterramentoTotalUnidades: map['aterramento_total_unidades'] as int?,
      informacoesAdicionais: map['informacoes_adicionais'] as String?,
      distanciasSeguranca: map['distancias_seguranca'] as String?,
      dadosPlanejamento: map['dados_planejamento'] as String?,
      recursosEpi: map['recursos_epi'] as String?,
      recursosEpc: map['recursos_epc'] as String?,
      recursosTransporte: map['recursos_transporte'] as String?,
      recursosMaterialConsumo: map['recursos_material_consumo'] as String?,
      recursosFerramentas: map['recursos_ferramentas'] as String?,
      recursosComunicacao: map['recursos_comunicacao'] as String?,
      recursosDocumentacao: map['recursos_documentacao'] as String?,
      recursosInstrumentos: map['recursos_instrumentos'] as String?,
      detalhamentoIntervencao: map['detalhamento_intervencao'] as String?,
      recursosHumanos: map['recursos_humanos'] as String?,
      nivelRisco: map['nivel_risco'] as String?,
      aprovador: map['aprovador'] as String?,
      dataAprovacao: map['data_aprovacao'] != null
          ? DateTime.parse(map['data_aprovacao'] as String)
          : null,
      status: map['status'] as String? ?? 'rascunho',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'numero_pex': numeroPex,
      'si': si,
      'revisao_pex': revisaoPex,
      'data_elaboracao': dataElaboracao != null 
          ? '${dataElaboracao!.year}-${dataElaboracao!.month.toString().padLeft(2, '0')}-${dataElaboracao!.day.toString().padLeft(2, '0')}'
          : null,
      'responsavel_nome': responsavelNome,
      'responsavel_id_sap': responsavelIdSap,
      'responsavel_contato': responsavelContato,
      'substituto_nome': substitutoNome,
      'substituto_id_sap': substitutoIdSap,
      'substituto_contato': substitutoContato,
      'fiscal_tecnico_nome': fiscalTecnicoNome,
      'fiscal_tecnico_id_sap': fiscalTecnicoIdSap,
      'fiscal_tecnico_contato': fiscalTecnicoContato,
      'coordenador_nome': coordenadorNome,
      'coordenador_id_sap': coordenadorIdSap,
      'coordenador_contato': coordenadorContato,
      'tecnico_seg_nome': tecnicoSegNome,
      'tecnico_seg_id_sap': tecnicoSegIdSap,
      'tecnico_seg_contato': tecnicoSegContato,
      'data_inicio': dataInicio != null 
          ? '${dataInicio!.year}-${dataInicio!.month.toString().padLeft(2, '0')}-${dataInicio!.day.toString().padLeft(2, '0')}'
          : null,
      'hora_inicio': horaInicio,
      'data_fim': dataFim != null 
          ? '${dataFim!.year}-${dataFim!.month.toString().padLeft(2, '0')}-${dataFim!.day.toString().padLeft(2, '0')}'
          : null,
      'hora_fim': horaFim,
      'periodicidade': periodicidade,
      'continuo': continuo,
      'instalacao': instalacao,
      'equipamentos': equipamentos,
      'resumo_atividade': resumoAtividade,
      'configuracao_recebimento': configuracaoRecebimento,
      'configuracao_durante': configuracaoDurante,
      'configuracao_devolucao': configuracaoDevolucao,
      'aterramento_descricao': aterramentoDescricao,
      'aterramento_total_unidades': aterramentoTotalUnidades,
      'informacoes_adicionais': informacoesAdicionais,
      'distancias_seguranca': distanciasSeguranca,
      'dados_planejamento': dadosPlanejamento,
      'recursos_epi': recursosEpi,
      'recursos_epc': recursosEpc,
      'recursos_transporte': recursosTransporte,
      'recursos_material_consumo': recursosMaterialConsumo,
      'recursos_ferramentas': recursosFerramentas,
      'recursos_comunicacao': recursosComunicacao,
      'recursos_documentacao': recursosDocumentacao,
      'recursos_instrumentos': recursosInstrumentos,
      'detalhamento_intervencao': detalhamentoIntervencao,
      'recursos_humanos': recursosHumanos,
      'nivel_risco': nivelRisco,
      'aprovador': aprovador,
      'data_aprovacao': dataAprovacao != null 
          ? '${dataAprovacao!.year}-${dataAprovacao!.month.toString().padLeft(2, '0')}-${dataAprovacao!.day.toString().padLeft(2, '0')}'
          : null,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper methods para trabalhar com JSON
  List<Map<String, dynamic>>? getRecursosEpiList() {
    if (recursosEpi == null || recursosEpi!.isEmpty) return null;
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(recursosEpi!));
    } catch (e) {
      return null;
    }
  }

  void setRecursosEpiList(List<Map<String, dynamic>>? list) {
    // Este método não modifica diretamente, mas pode ser usado no copyWith
  }

  PEX copyWith({
    String? id,
    String? taskId,
    String? numeroPex,
    String? si,
    int? revisaoPex,
    DateTime? dataElaboracao,
    String? responsavelNome,
    String? responsavelIdSap,
    String? responsavelContato,
    String? substitutoNome,
    String? substitutoIdSap,
    String? substitutoContato,
    String? fiscalTecnicoNome,
    String? fiscalTecnicoIdSap,
    String? fiscalTecnicoContato,
    String? coordenadorNome,
    String? coordenadorIdSap,
    String? coordenadorContato,
    String? tecnicoSegNome,
    String? tecnicoSegIdSap,
    String? tecnicoSegContato,
    DateTime? dataInicio,
    String? horaInicio,
    DateTime? dataFim,
    String? horaFim,
    bool? periodicidade,
    bool? continuo,
    String? instalacao,
    String? equipamentos,
    String? resumoAtividade,
    String? configuracaoRecebimento,
    String? configuracaoDurante,
    String? configuracaoDevolucao,
    String? aterramentoDescricao,
    int? aterramentoTotalUnidades,
    String? informacoesAdicionais,
    String? distanciasSeguranca,
    String? dadosPlanejamento,
    String? recursosEpi,
    String? recursosEpc,
    String? recursosTransporte,
    String? recursosMaterialConsumo,
    String? recursosFerramentas,
    String? recursosComunicacao,
    String? recursosDocumentacao,
    String? recursosInstrumentos,
    String? detalhamentoIntervencao,
    String? recursosHumanos,
    String? nivelRisco,
    String? aprovador,
    DateTime? dataAprovacao,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PEX(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      numeroPex: numeroPex ?? this.numeroPex,
      si: si ?? this.si,
      revisaoPex: revisaoPex ?? this.revisaoPex,
      dataElaboracao: dataElaboracao ?? this.dataElaboracao,
      responsavelNome: responsavelNome ?? this.responsavelNome,
      responsavelIdSap: responsavelIdSap ?? this.responsavelIdSap,
      responsavelContato: responsavelContato ?? this.responsavelContato,
      substitutoNome: substitutoNome ?? this.substitutoNome,
      substitutoIdSap: substitutoIdSap ?? this.substitutoIdSap,
      substitutoContato: substitutoContato ?? this.substitutoContato,
      fiscalTecnicoNome: fiscalTecnicoNome ?? this.fiscalTecnicoNome,
      fiscalTecnicoIdSap: fiscalTecnicoIdSap ?? this.fiscalTecnicoIdSap,
      fiscalTecnicoContato: fiscalTecnicoContato ?? this.fiscalTecnicoContato,
      coordenadorNome: coordenadorNome ?? this.coordenadorNome,
      coordenadorIdSap: coordenadorIdSap ?? this.coordenadorIdSap,
      coordenadorContato: coordenadorContato ?? this.coordenadorContato,
      tecnicoSegNome: tecnicoSegNome ?? this.tecnicoSegNome,
      tecnicoSegIdSap: tecnicoSegIdSap ?? this.tecnicoSegIdSap,
      tecnicoSegContato: tecnicoSegContato ?? this.tecnicoSegContato,
      dataInicio: dataInicio ?? this.dataInicio,
      horaInicio: horaInicio ?? this.horaInicio,
      dataFim: dataFim ?? this.dataFim,
      horaFim: horaFim ?? this.horaFim,
      periodicidade: periodicidade ?? this.periodicidade,
      continuo: continuo ?? this.continuo,
      instalacao: instalacao ?? this.instalacao,
      equipamentos: equipamentos ?? this.equipamentos,
      resumoAtividade: resumoAtividade ?? this.resumoAtividade,
      configuracaoRecebimento: configuracaoRecebimento ?? this.configuracaoRecebimento,
      configuracaoDurante: configuracaoDurante ?? this.configuracaoDurante,
      configuracaoDevolucao: configuracaoDevolucao ?? this.configuracaoDevolucao,
      aterramentoDescricao: aterramentoDescricao ?? this.aterramentoDescricao,
      aterramentoTotalUnidades: aterramentoTotalUnidades ?? this.aterramentoTotalUnidades,
      informacoesAdicionais: informacoesAdicionais ?? this.informacoesAdicionais,
      distanciasSeguranca: distanciasSeguranca ?? this.distanciasSeguranca,
      dadosPlanejamento: dadosPlanejamento ?? this.dadosPlanejamento,
      recursosEpi: recursosEpi ?? this.recursosEpi,
      recursosEpc: recursosEpc ?? this.recursosEpc,
      recursosTransporte: recursosTransporte ?? this.recursosTransporte,
      recursosMaterialConsumo: recursosMaterialConsumo ?? this.recursosMaterialConsumo,
      recursosFerramentas: recursosFerramentas ?? this.recursosFerramentas,
      recursosComunicacao: recursosComunicacao ?? this.recursosComunicacao,
      recursosDocumentacao: recursosDocumentacao ?? this.recursosDocumentacao,
      recursosInstrumentos: recursosInstrumentos ?? this.recursosInstrumentos,
      detalhamentoIntervencao: detalhamentoIntervencao ?? this.detalhamentoIntervencao,
      recursosHumanos: recursosHumanos ?? this.recursosHumanos,
      nivelRisco: nivelRisco ?? this.nivelRisco,
      aprovador: aprovador ?? this.aprovador,
      dataAprovacao: dataAprovacao ?? this.dataAprovacao,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
