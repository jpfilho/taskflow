import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_analise.dart';
import '../models/task.dart';
import '../services/nota_sap_analise_service.dart';
import '../utils/clipboard_helper.dart';
import '../utils/responsive.dart';
import 'nota_analise_workspace.dart';
import 'nota_workspace/nota_anexo_viewer_dialog.dart';

/// Modal moderno exibido ao clicar na coluna de Notas SAP na tela de Atividades.
/// Apresenta as notas SAP vinculadas à tarefa, suas miniaturas de anexos (com zoom)
/// e link/ação direta para o Formulário de Análise Técnica.
class NotasSapVinculadasDialog extends StatefulWidget {
  final List<NotaSAP> notas;
  final Task task;
  final NotaSapAnaliseService? analiseService;

  const NotasSapVinculadasDialog({
    super.key,
    required this.notas,
    required this.task,
    this.analiseService,
  });

  /// Exibe o diálogo de notas vinculadas na tela atual.
  static Future<void> mostrar(
    BuildContext context, {
    required List<NotaSAP> notas,
    required Task task,
    NotaSapAnaliseService? analiseService,
  }) {
    return showDialog(
      context: context,
      builder: (context) => NotasSapVinculadasDialog(
        notas: notas,
        task: task,
        analiseService: analiseService,
      ),
    );
  }

  @override
  State<NotasSapVinculadasDialog> createState() => _NotasSapVinculadasDialogState();
}

class _NotasSapVinculadasDialogState extends State<NotasSapVinculadasDialog> {
  late final NotaSapAnaliseService _analiseService;
  bool _carregandoAnexos = true;
  Map<String, List<NotaSapAnexo>> _anexosPorNota = {};

  @override
  void initState() {
    super.initState();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();
    _carregarAnexos();
  }

  Future<void> _carregarAnexos() async {
    if (!mounted) return;
    setState(() => _carregandoAnexos = true);

    try {
      final ids = widget.notas.map((n) => n.id).toList();
      final mapa = await _analiseService.listarAnexosPorNotas(ids);
      if (mounted) {
        setState(() {
          _anexosPorNota = mapa;
          _carregandoAnexos = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carregandoAnexos = false);
      }
    }
  }

  Future<void> _abrirAnaliseTecnica(NotaSAP nota) async {
    await NotaAnaliseWorkspace.abrir(
      context,
      nota: nota,
      listaNotas: widget.notas,
      service: _analiseService,
    );

    // Ao retornar da análise, recarrega os anexos caso tenham sido adicionados ou editados
    if (mounted) {
      _carregarAnexos();
    }
  }

  void _abrirVisualizadorAnexo(NotaSAP nota, List<NotaSapAnexo> anexosDaNota, int index) {
    final anexo = anexosDaNota[index];
    if (anexo.tipoArquivo == NotaAnexoTipo.imagem) {
      NotaAnexoViewerDialog.abrir(
        context: context,
        anexos: anexosDaNota,
        indiceInicial: index,
        service: _analiseService,
        notaAtual: nota,
        contextoFiltro: 'Evidências da Nota ${nota.nota}',
      );
    } else {
      // Documento (PDF, DOCX, etc.)
      _analiseService.obterUrlAssinada(anexo).then((url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o anexo.')),
          );
        }
      }).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir anexo: $e')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isDesktop ? 860 : size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.88,
          maxWidth: 920,
        ),
        child: Column(
          children: [
            // Cabeçalho estilizado
            _buildHeader(context),

            // Lista de notas
            Expanded(
              child: widget.notas.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nenhuma nota SAP vinculada a esta tarefa.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.notas.length,
                      itemBuilder: (context, index) {
                        final nota = widget.notas[index];
                        final anexos = _anexosPorNota[nota.id] ?? const [];
                        return _buildCardNota(context, nota, anexos, isDesktop);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E3A5F), Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notas SAP Vinculadas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.notas.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tarefa: ${widget.task.tarefa}${widget.task.observacoes != null && widget.task.observacoes!.isNotEmpty ? " • ${widget.task.observacoes}" : ""}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardNota(
    BuildContext context,
    NotaSAP nota,
    List<NotaSapAnexo> anexos,
    bool isDesktop,
  ) {
    final statusColor = _getStatusUsuarioColor(nota.statusUsuario);
    final statusTextColor = _getStatusUsuarioTextColor(nota.statusUsuario);

    // Botões de Ação
    final botoesAcao = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F).withOpacity(0.09),
            foregroundColor: const Color(0xFF1E3A5F),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.2)),
            ),
          ),
          onPressed: () => _abrirAnaliseTecnica(nota),
          icon: const Icon(Icons.analytics_outlined, size: 16),
          label: const Text(
            'Análise Técnica',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.purple),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          tooltip: 'Visualizar dados SAP completos',
          onPressed: () => _mostrarDetalhesNotaCompleta(context, nota),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          tooltip: 'Copiar número da nota',
          onPressed: () => _copiarParaAreaTransferencia(
            context,
            nota.nota,
            'Nota copiada!',
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor,
                    radius: 18,
                    child: Text(
                      nota.tipo ?? '?',
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNotaDescricaoCol(nota),
                  ),
                  const SizedBox(width: 8),
                  botoesAcao,
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor,
                        radius: 18,
                        child: Text(
                          nota.tipo ?? '?',
                          style: TextStyle(
                            color: statusTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNotaDescricaoCol(nota),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  botoesAcao,
                ],
              ),

            const SizedBox(height: 10),

            // Tags: Status Sistema, Status Usuário, Sala, Prazo
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (nota.statusSistema != null && nota.statusSistema!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusSistemaColor(nota.statusSistema).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getStatusSistemaColor(nota.statusSistema).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      nota.statusSistema!,
                      style: TextStyle(
                        color: _getStatusSistemaColor(nota.statusSistema),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      nota.statusUsuario!,
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (nota.sala != null && nota.sala!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.room, size: 12, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Sala: ${nota.sala}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (nota.dataVencimento != null && nota.diasRestantes != null)
                  _buildPrazoBadgeNota(nota),
              ],
            ),

            // SEÇÃO DE ANEXOS E MINIATURAS
            const SizedBox(height: 12),
            _buildSecaoAnexos(context, nota, anexos),
          ],
        ),
      ),
    );
  }

  Widget _buildNotaDescricaoCol(NotaSAP nota) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            InkWell(
              onTap: () => _abrirAnaliseTecnica(nota),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nota ${nota.nota}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E3A5F),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new,
                      size: 13,
                      color: Color(0xFF1E3A5F),
                    ),
                  ],
                ),
              ),
            ),
            if (nota.equipamento != null && nota.equipamento!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  nota.equipamento!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (nota.descricao != null && nota.descricao!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            nota.descricao!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildSecaoAnexos(
    BuildContext context,
    NotaSAP nota,
    List<NotaSapAnexo> anexos,
  ) {
    if (_carregandoAnexos) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Carregando miniaturas de anexos...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (anexos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Nenhum anexo registrado nesta Nota SAP.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            InkWell(
              onTap: () => _abrirAnaliseTecnica(nota),
              child: Text(
                'Adicionar Anexo na Análise',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 15, color: Colors.blueGrey.shade700),
              const SizedBox(width: 6),
              Text(
                'Anexos / Evidências (${anexos.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• Clique na miniatura para ampliar',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: anexos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final anexo = anexos[index];
                return _buildMiniaturaItem(context, nota, anexo, anexos, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniaturaItem(
    BuildContext context,
    NotaSAP nota,
    NotaSapAnexo anexo,
    List<NotaSapAnexo> anexosDaNota,
    int index,
  ) {
    final isImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;

    return Tooltip(
      message: anexo.legenda?.isNotEmpty == true
          ? anexo.legenda!
          : anexo.nomeArquivo,
      child: InkWell(
        onTap: () => _abrirVisualizadorAnexo(nota, anexosDaNota, index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isImagem)
                FutureBuilder<String>(
                  future: _analiseService.obterUrlAssinada(anexo),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
                        ),
                      );
                    }
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 28,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anexo.nomeArquivo,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // Indicador de Anotações se houver
              if (anexo.versaoAnotacao > 0)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrazoBadgeNota(NotaSAP nota) {
    if (nota.dataVencimento == null || nota.diasRestantes == null) {
      return const SizedBox.shrink();
    }

    final diasRestantes = nota.diasRestantes!;
    final dataVencimento = nota.dataVencimento!;

    Color badgeColor;
    Color textColor;

    if (diasRestantes <= 0) {
      badgeColor = Colors.red.shade600;
      textColor = Colors.white;
    } else if (diasRestantes <= 3) {
      badgeColor = Colors.orange.shade700;
      textColor = Colors.white;
    } else if (diasRestantes <= 7) {
      badgeColor = Colors.amber.shade800;
      textColor = Colors.white;
    } else {
      badgeColor = Colors.green.shade600;
      textColor = Colors.white;
    }

    final prazoTexto = diasRestantes < 0
        ? 'Vencida há ${diasRestantes.abs()}d'
        : diasRestantes == 0
            ? 'Vence hoje'
            : '$diasRestantes dias restantes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            prazoTexto,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${_formatarData(dataVencimento)})',
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalhesNotaCompleta(BuildContext context, NotaSAP nota) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 680,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Detalhes da Nota SAP: ${nota.nota}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoRow('Tipo', nota.tipo),
                      _buildInfoRow('Descrição', nota.descricao),
                      _buildInfoRow('Detalhes', nota.detalhes),
                      _buildInfoRow('Status Sistema', nota.statusSistema),
                      _buildInfoRow('Status Usuário', nota.statusUsuario),
                      _buildInfoRow('Prioridade', nota.textPrioridade),
                      _buildInfoRow('Ordem', nota.ordem),
                      _buildInfoRow('Local de Instalação', nota.localInstalacao),
                      _buildInfoRow('Local', nota.local),
                      _buildInfoRow('Sala', nota.sala),
                      _buildInfoRow('Equipamento', nota.equipamento),
                      _buildInfoRow('Centro', nota.centro),
                      _buildInfoRow('Centro Trab. Resp.', nota.centroTrabalhoResponsavel),
                      _buildInfoRow('Executor', nota.denominacaoExecutor),
                      if (nota.criadoEm != null) _buildInfoRow('Criado em', _formatarData(nota.criadoEm!)),
                      if (nota.dataVencimento != null) _buildInfoRow('Vencimento', _formatarData(nota.dataVencimento!)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _abrirAnaliseTecnica(nota);
                      },
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Abrir Análise Técnica'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarParaAreaTransferencia(BuildContext context, String texto, String mensagem) async {
    await ClipboardHelper.copyAndNotify(
      context,
      texto,
      successMessage: mensagem,
      errorMessage: 'Não foi possível copiar o texto.',
      duration: const Duration(seconds: 1),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Color _getStatusUsuarioColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.grey;
    final status = statusUsuario.toUpperCase();
    if (status.contains('CONC')) return Colors.green.shade700;
    if (status.contains('CADU') || status.contains('CAIM')) return Colors.grey;
    if (status.contains('REGI')) return Colors.orange.shade800;
    if (status.contains('EMAM')) return Colors.amber.shade700;
    if (status.contains('ANLS')) return Colors.blue.shade700;
    return Colors.grey.shade600;
  }

  Color _getStatusUsuarioTextColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.white;
    if (statusUsuario.toUpperCase().contains('EMAM')) return Colors.black87;
    return Colors.white;
  }

  Color _getStatusSistemaColor(String? statusSistema) {
    if (statusSistema == null || statusSistema.isEmpty) return Colors.grey;
    final status = statusSistema.toUpperCase();
    if (status.contains('MSPR')) return Colors.orange.shade800;
    if (status.contains('MSPN')) return Colors.blue.shade700;
    if (status.contains('MECE') || status.contains('CONC')) return Colors.green.shade700;
    return const Color(0xFF1E3A5F);
  }
}
