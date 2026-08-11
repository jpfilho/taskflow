import '../utils/date_parser.dart';

class ProjetoMembro {
  final String id;
  final String projetoId;
  final String usuarioId;
  final String papel;
  final bool podeVisualizar;
  final bool podeEditar;
  final bool podePlanejar;
  final bool podeAprovar;
  final bool podeEncerrar;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String syncStatus;

  ProjetoMembro({
    required this.id,
    required this.projetoId,
    required this.usuarioId,
    required this.papel,
    this.podeVisualizar = true,
    this.podeEditar = false,
    this.podePlanejar = false,
    this.podeAprovar = false,
    this.podeEncerrar = false,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projeto_id': projetoId,
      'usuario_id': usuarioId,
      'papel': papel,
      'pode_visualizar': podeVisualizar ? 1 : 0,
      'pode_editar': podeEditar ? 1 : 0,
      'pode_planejar': podePlanejar ? 1 : 0,
      'pode_aprovar': podeAprovar ? 1 : 0,
      'pode_encerrar': podeEncerrar ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoMembro.fromMap(Map<String, dynamic> map) {
    return ProjetoMembro(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      usuarioId: map['usuario_id'] ?? '',
      papel: map['papel'] ?? '',
      podeVisualizar: map['pode_visualizar'] == 1 || map['pode_visualizar'] == true,
      podeEditar: map['pode_editar'] == 1 || map['pode_editar'] == true,
      podePlanejar: map['pode_planejar'] == 1 || map['pode_planejar'] == true,
      podeAprovar: map['pode_aprovar'] == 1 || map['pode_aprovar'] == true,
      podeEncerrar: map['pode_encerrar'] == 1 || map['pode_encerrar'] == true,
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
