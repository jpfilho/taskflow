import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../data/models/demanda_model.dart';
import '../../data/models/demanda_anexo_model.dart';
import '../../data/models/demanda_historico_model.dart';
import '../../data/services/demanda_service.dart';
import '../widgets/demanda_prazo_helper.dart';
import 'demanda_form_screen.dart';

class DemandaDetailScreen extends StatefulWidget {
  final String demandaId;

  const DemandaDetailScreen({super.key, required this.demandaId});

  @override
  State<DemandaDetailScreen> createState() => _DemandaDetailScreenState();
}

class _DemandaDetailScreenState extends State<DemandaDetailScreen> {
  final DemandaService _demandaService = DemandaService();

  Demanda? _demanda;
  List<DemandaAnexo> _anexos = [];
  List<DemandaHistorico> _historico = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _erroMsg = '';

  @override
  void initState() {
    super.initState();
    _carregarDetalhes();
  }

  Future<void> _carregarDetalhes() async {
    setState(() {
      _isLoading = true;
      _erroMsg = '';
    });

    try {
      final listaDemandas = await _demandaService.listarDemandas(limit: 1000);
      final demanda = listaDemandas.firstWhere((element) => element.id == widget.demandaId);
      final anexos = await _demandaService.listarAnexos(widget.demandaId);
      final hist = await _demandaService.listarHistorico(widget.demandaId);

      setState(() {
        _demanda = demanda;
        _anexos = anexos;
        _historico = hist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _erroMsg = 'Erro ao carregar detalhes da demanda: $e';
        _isLoading = false;
      });
    }
  }

  Color _obterCorStatus(String status) {
    switch (status) {
      case 'Aberta':
        return Colors.blue;
      case 'Em análise':
        return Colors.purple;
      case 'Programada':
        return Colors.cyan;
      case 'Em execução':
        return Colors.orange;
      case 'Aguardando terceiros':
      case 'Aguardando material':
        return Colors.amber;
      case 'Concluída':
        return Colors.green;
      case 'Cancelada':
      case 'Suspensa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _concluirRapido() async {
    if (_demanda == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir demanda'),
        content: const Text('Confirmar a conclusão desta demanda operacional?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Concluir', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        final atualizada = _demanda!.copyWith(
          status: 'Concluída',
          dataConclusao: DateTime.now(),
        );
        await _demandaService.atualizarDemanda(atualizada, versaoAnterior: _demanda);
        await _carregarDetalhes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demanda concluída com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao concluir demanda: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelarDemanda() async {
    if (_demanda == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar demanda'),
        content: const Text('Deseja realmente cancelar esta demanda operacional?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar Demanda', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        final atualizada = _demanda!.copyWith(status: 'Cancelada');
        await _demandaService.atualizarDemanda(atualizada, versaoAnterior: _demanda);
        await _carregarDetalhes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demanda cancelada com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar demanda: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadRapidoAnexo(String tipo) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploading = true);

      await _demandaService.uploadAnexo(
        demandaId: widget.demandaId,
        tipo: tipo == 'antes'
            ? 'evidencia_antes'
            : tipo == 'depois'
                ? 'evidencia_depois'
                : 'anexo_geral',
        fileName: file.name,
        bytes: file.bytes!,
        mimeType: file.extension,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidência anexada com sucesso!')),
      );
      await _carregarDetalhes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao anexar arquivo: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _excluirAnexo(DemandaAnexo anexo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir anexo'),
        content: Text('Excluir permanentemente "${anexo.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _demandaService.excluirAnexo(anexo);
        await _carregarDetalhes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anexo removido!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao excluir anexo: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _abrirUrlAnexo(DemandaAnexo anexo) async {
    if (anexo.fileUrl == null) return;
    try {
      final uri = Uri.parse(anexo.fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a URL do arquivo')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir anexo: $e')),
      );
    }
  }

  void _exibirImagemCheia(DemandaAnexo anexo) {
    if (anexo.fileUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(anexo.fileUrl!, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_erroMsg.isNotEmpty || _demanda == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Demanda')),
        body: Center(child: Text(_erroMsg.isNotEmpty ? _erroMsg : 'Demanda não encontrada.')),
      );
    }

    final d = _demanda!;
    final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
    final corPrazo = DemandaPrazoHelper.obterCorSituacao(situacao);
    final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, d.prazo);

    final antesAnexos = _anexos.where((a) => a.tipo == 'evidencia_antes').toList();
    final depoisAnexos = _anexos.where((a) => a.tipo == 'evidencia_depois').toList();
    final geraisAnexos = _anexos.where((a) => a.tipo == 'anexo_geral').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Demanda'),
        actions: [
          IconButton(
            tooltip: 'Editar Demanda',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DemandaFormScreen(demandaExistente: d),
                ),
              );
              if (result == true) {
                _carregarDetalhes();
              }
            },
          ),
          if (d.status != 'Concluída' && d.status != 'Cancelada') ...[
            IconButton(
              tooltip: 'Concluir Demanda',
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              onPressed: _concluirRapido,
            ),
            IconButton(
              tooltip: 'Cancelar Demanda',
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: _cancelarDemanda,
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status e Prazo superiores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _obterCorStatus(d.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.status.toUpperCase(),
                    style: TextStyle(
                      color: _obterCorStatus(d.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: corPrazo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    textoPrazo,
                    style: TextStyle(
                      color: corPrazo,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Demanda Principal
            Text(
              d.demanda,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Detalhes em Grid
            _buildGridDetalhes(d),
            const SizedBox(height: 20),

            // Observações adicionais
            if (d.observacoes != null && d.observacoes!.isNotEmpty) ...[
              const Text('Observações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(d.observacoes!),
              ),
              const SizedBox(height: 24),
            ],

            // Seção de Evidências Antes e Depois
            const Text('Evidências & Documentos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            _buildGaleriaEvidencias('antes', 'Evidências ANTES', antesAnexos),
            const SizedBox(height: 16),
            _buildGaleriaEvidencias('depois', 'Evidências DEPOIS', depoisAnexos),
            const SizedBox(height: 16),
            _buildDocumentosGerais(geraisAnexos),

            const SizedBox(height: 24),
            
            // Linha do tempo (Histórico)
            const Text('Histórico / Acompanhamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            _buildLinhaDoTempo(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDetalhes(Demanda d) {
    Widget itemDetalhe(String label, String valor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final col1 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemDetalhe('Origem', d.origem),
            itemDetalhe('Local', d.local),
            itemDetalhe('Sala', d.sala?.isNotEmpty == true ? d.sala! : '-'),
            itemDetalhe('Responsável', d.responsavel),
          ],
        );
        final col2 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemDetalhe('Prioridade', d.prioridade),
            itemDetalhe('Nota SAP', d.nota?.isNotEmpty == true ? d.nota! : '-'),
            itemDetalhe('Ordem SAP', d.ordem?.isNotEmpty == true ? d.ordem! : '-'),
            itemDetalhe('SI', d.si?.isNotEmpty == true ? d.si! : '-'),
          ],
        );
        final col3 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemDetalhe('AT', d.at?.isNotEmpty == true ? d.at! : '-'),
            itemDetalhe('Data de Abertura', d.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(d.createdAt!) : '-'),
            itemDetalhe('Prazo Limite', DateFormat('dd/MM/yyyy').format(d.prazo)),
            itemDetalhe('Data de Conclusão', d.dataConclusao != null ? DateFormat('dd/MM/yyyy HH:mm').format(d.dataConclusao!) : '-'),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [col1, col2, col3],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: col1),
                    const SizedBox(width: 16),
                    Expanded(child: col2),
                    const SizedBox(width: 16),
                    Expanded(child: col3),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGaleriaEvidencias(String tipo, String titulo, List<DemandaAnexo> fotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_isUploading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton.icon(
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: const Text('Adicionar foto', style: TextStyle(fontSize: 12)),
                onPressed: () => _uploadRapidoAnexo(tipo),
              ),
          ],
        ),
        if (fotos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Nenhuma evidência anexada.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              itemBuilder: (context, index) {
                final anexo = fotos[index];
                final isImage = anexo.fileName.endsWith('.jpg') || anexo.fileName.endsWith('.png') || anexo.fileName.endsWith('.webp');

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (isImage) {
                            _exibirImagemCheia(anexo);
                          } else {
                            _abrirUrlAnexo(anexo);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: isImage && anexo.fileUrl != null
                              ? Image.network(anexo.fileUrl!, width: 120, height: 120, fit: BoxFit.cover)
                              : const Center(child: Icon(Icons.insert_drive_file, size: 40, color: Colors.grey)),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.red.withOpacity(0.8),
                          child: IconButton(
                            icon: const Icon(Icons.delete, size: 12, color: Colors.white),
                            onPressed: () => _excluirAnexo(anexo),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentosGerais(List<DemandaAnexo> documentos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Documentos Gerais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (!_isUploading)
              TextButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Anexar arquivo', style: TextStyle(fontSize: 12)),
                onPressed: () => _uploadRapidoAnexo('geral'),
              ),
          ],
        ),
        if (documentos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Nenhum documento anexado.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final doc = documentos[index];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                title: Text(doc.fileName, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  '${(doc.fileSize ?? 0) ~/ 1024} KB • ${doc.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt!) : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20, color: Colors.blue),
                      onPressed: () => _abrirUrlAnexo(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _excluirAnexo(doc),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLinhaDoTempo() {
    if (_historico.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Text('Nenhum registro de histórico.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historico.length,
      itemBuilder: (context, index) {
        final h = _historico[index];
        final dataStr = h.createdAt != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(h.createdAt!)
            : '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, size: 12, color: Colors.blue),
                if (index != _historico.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dataStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      h.observacao ?? 'Alteração realizada',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (h.campo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Modificado: ${h.campo} (${h.valorAnterior} ➔ ${h.valorNovo})',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
