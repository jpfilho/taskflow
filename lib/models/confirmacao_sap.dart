class ConfirmacaoSap {
  final String confirmacao;
  final String? tipo;
  final String? ordem;
  final String? textoBreve;
  final String? operacao;
  final String? subOperacao;
  final String? textoBreveOperacao;
  final String? centroTrabalho;
  final String? criadoPor;
  final String? localInstalacao;
  final String? denominacaoLocal;
  final String? equipamento;
  final String? nota;
  final String? ordemPrincipal;
  final String? centroCusto;
  final String? sala;
  final String? statusUsuario;
  final String? statusSistema;
  final DateTime? inicioBase;
  final DateTime? fimBase;
  final DateTime? inicioProgramado;
  final DateTime? fimProgramado;
  final String? tam;
  final String? pepCabecalho;
  final String? elementoPep;
  final String? centroLucro;
  final String? statusUsuarioOperacao;
  final double? trabalhoPrevisto;
  final double? totalReal;
  final double? trabalhoReal;
  final String? tipoSalario;
  final int? numeroPessoas;
  final String? txd;
  final String? centroFinanceiro;
  final String? vinculoOddOdi;
  final double? valorCusto;
  final String? ultimaOrdem;
  final DateTime? dataConfirmacao;
  final DateTime? dataConclusao;
  final String? codigoAt;
  final String? codigoSi;
  final String? codigoPt;
  final String? numeroNotaOperacao;
  final String? ri;
  final String? rf;
  final DateTime? restricaoInicio;
  final String? resHorIn;
  final DateTime? fimRestricao;
  final String? resHoraF;
  final String? textoJunta;
  final String? cliente;
  final String? recebedor;
  final double? totalPlanejado;
  final double? trabalho;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  ConfirmacaoSap({
    required this.confirmacao,
    this.tipo,
    this.ordem,
    this.textoBreve,
    this.operacao,
    this.subOperacao,
    this.textoBreveOperacao,
    this.centroTrabalho,
    this.criadoPor,
    this.localInstalacao,
    this.denominacaoLocal,
    this.equipamento,
    this.nota,
    this.ordemPrincipal,
    this.centroCusto,
    this.sala,
    this.statusUsuario,
    this.statusSistema,
    this.inicioBase,
    this.fimBase,
    this.inicioProgramado,
    this.fimProgramado,
    this.tam,
    this.pepCabecalho,
    this.elementoPep,
    this.centroLucro,
    this.statusUsuarioOperacao,
    this.trabalhoPrevisto,
    this.totalReal,
    this.trabalhoReal,
    this.tipoSalario,
    this.numeroPessoas,
    this.txd,
    this.centroFinanceiro,
    this.vinculoOddOdi,
    this.valorCusto,
    this.ultimaOrdem,
    this.dataConfirmacao,
    this.dataConclusao,
    this.codigoAt,
    this.codigoSi,
    this.codigoPt,
    this.numeroNotaOperacao,
    this.ri,
    this.rf,
    this.restricaoInicio,
    this.resHorIn,
    this.fimRestricao,
    this.resHoraF,
    this.textoJunta,
    this.cliente,
    this.recebedor,
    this.totalPlanejado,
    this.trabalho,
    this.criadoEm,
    this.atualizadoEm,
  });

  factory ConfirmacaoSap.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return ConfirmacaoSap(
      confirmacao: map['confirmacao']?.toString() ?? '',
      tipo: map['tipo'],
      ordem: map['ordem'],
      textoBreve: map['texto_breve'],
      operacao: map['operacao'],
      subOperacao: map['sub_operacao'],
      textoBreveOperacao: map['texto_breve_operacao'],
      centroTrabalho: map['centro_trabalho'],
      criadoPor: map['criado_por'],
      localInstalacao: map['local_instalacao'],
      denominacaoLocal: map['denominacao_local'],
      equipamento: map['equipamento'],
      nota: map['nota'],
      ordemPrincipal: map['ordem_principal'],
      centroCusto: map['centro_custo'],
      sala: map['sala'],
      statusUsuario: map['status_usuario'],
      statusSistema: map['status_sistema'],
      inicioBase: parseDate(map['inicio_base']),
      fimBase: parseDate(map['fim_base']),
      inicioProgramado: parseDate(map['inicio_programado']),
      fimProgramado: parseDate(map['fim_programado']),
      tam: map['tam'],
      pepCabecalho: map['pep_cabecalho'],
      elementoPep: map['elemento_pep'],
      centroLucro: map['centro_lucro'],
      statusUsuarioOperacao: map['status_usuario_operacao'],
      trabalhoPrevisto: parseDouble(map['trabalho_previsto']),
      totalReal: parseDouble(map['total_real']),
      trabalhoReal: parseDouble(map['trabalho_real']),
      tipoSalario: map['tipo_salario'],
      numeroPessoas: map['numero_pessoas'],
      txd: map['txd'],
      centroFinanceiro: map['centro_financeiro'],
      vinculoOddOdi: map['vinculo_odd_odi'],
      valorCusto: parseDouble(map['valor_custo']),
      ultimaOrdem: map['ultima_ordem'],
      dataConfirmacao: parseDate(map['data_confirmacao']),
      dataConclusao: parseDate(map['data_conclusao']),
      codigoAt: map['codigo_at'],
      codigoSi: map['codigo_si'],
      codigoPt: map['codigo_pt'],
      numeroNotaOperacao: map['numero_nota_operacao'],
      ri: map['ri'],
      rf: map['rf'],
      restricaoInicio: parseDate(map['restricao_inicio']),
      resHorIn: map['res_hor_in'],
      fimRestricao: parseDate(map['fim_restricao']),
      resHoraF: map['res_hora_f'],
      textoJunta: map['texto_junta'],
      cliente: map['cliente'],
      recebedor: map['recebedor'],
      totalPlanejado: parseDouble(map['total_planejado']),
      trabalho: parseDouble(map['trabalho']),
      criadoEm: parseDate(map['criado_em']),
      atualizadoEm: parseDate(map['atualizado_em']),
    );
  }

  Map<String, dynamic> toMap() {
    String? formatDate(DateTime? date) {
      if (date == null) return null;
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }

    return {
      'confirmacao': confirmacao,
      'tipo': tipo,
      'ordem': ordem,
      'texto_breve': textoBreve,
      'operacao': operacao,
      'sub_operacao': subOperacao,
      'texto_breve_operacao': textoBreveOperacao,
      'centro_trabalho': centroTrabalho,
      'criado_por': criadoPor,
      'local_instalacao': localInstalacao,
      'denominacao_local': denominacaoLocal,
      'equipamento': equipamento,
      'nota': nota,
      'ordem_principal': ordemPrincipal,
      'centro_custo': centroCusto,
      'sala': sala,
      'status_usuario': statusUsuario,
      'status_sistema': statusSistema,
      'inicio_base': formatDate(inicioBase),
      'fim_base': formatDate(fimBase),
      'inicio_programado': formatDate(inicioProgramado),
      'fim_programado': formatDate(fimProgramado),
      'tam': tam,
      'pep_cabecalho': pepCabecalho,
      'elemento_pep': elementoPep,
      'centro_lucro': centroLucro,
      'status_usuario_operacao': statusUsuarioOperacao,
      'trabalho_previsto': trabalhoPrevisto,
      'total_real': totalReal,
      'trabalho_real': trabalhoReal,
      'tipo_salario': tipoSalario,
      'numero_pessoas': numeroPessoas,
      'txd': txd,
      'centro_financeiro': centroFinanceiro,
      'vinculo_odd_odi': vinculoOddOdi,
      'valor_custo': valorCusto,
      'ultima_ordem': ultimaOrdem,
      'data_confirmacao': formatDate(dataConfirmacao),
      'data_conclusao': formatDate(dataConclusao),
      'codigo_at': codigoAt,
      'codigo_si': codigoSi,
      'codigo_pt': codigoPt,
      'numero_nota_operacao': numeroNotaOperacao,
      'ri': ri,
      'rf': rf,
      'restricao_inicio': formatDate(restricaoInicio),
      'res_hor_in': resHorIn,
      'fim_restricao': formatDate(fimRestricao),
      'res_hora_f': resHoraF,
      'texto_junta': textoJunta,
      'cliente': cliente,
      'recebedor': recebedor,
      'total_planejado': totalPlanejado,
      'trabalho': trabalho,
    };
  }
}
