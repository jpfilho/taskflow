import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../models/nota_sap_anotacao.dart';
import '../../services/auth_service_simples.dart';
import '../../services/nota_sap_analise_service.dart';
import 'nota_anexo_viewer_dialog.dart';
import 'nota_anexo_annotation_editor.dart';
import 'nota_workspace_historico_anexos_section.dart';

/// Filtro de tipo de anexo na barra de controle
enum _FiltroTipoAnexo {
  todos('Todos'),
  relevantes('★ Relevantes'),
  naAnalise('📎 Na Análise'),
  anotados('✏ Anotados'),
  imagens('Imagens'),
  pdfs('PDFs'),
  videos('Vídeos'),
  documentos('Docs'),
  planilhas('Planilhas'),
  audios('Áudios'),
  outros('Outros');

  final String label;
  const _FiltroTipoAnexo(this.label);
}

/// Modo de apresentação visual dos anexos
enum _ModoExibicao {
  cards,
  lista,
}

/// Opções de agrupamento dos anexos
enum _ModoAgrupamento {
  nenhum('Sem agrupamento'),
  porRelevancia('Por Relevância'),
  porTipo('Por Tipo de Arquivo'),
  porOrigem('Por Origem (SAP / TaskFlow)');

  final String label;
  const _ModoAgrupamento(this.label);
}

/// Opções de ordenação dos anexos
enum _OrdenacaoAnexo {
  maisRecente('Mais recentes'),
  maisAntigo('Mais antigos'),
  nomeAZ('Nome (A-Z)'),
  maiorTamanho('Maior tamanho');

  final String label;
  const _OrdenacaoAnexo(this.label);
}

/// Aba aprimorada de Anexos e Evidências Técnicas da Nota SAP (Fase 1 + Fase 2: Inspeção e Galeria)
class NotaWorkspaceAttachmentsTab extends StatefulWidget {
  final String notaSapId;
  final NotaSapAnaliseService service;
  final NotaSAP? nota;
  final void Function(NotaSAP notaHistorica)? onAbrirNotaHistorica;

  const NotaWorkspaceAttachmentsTab({
    super.key,
    required this.notaSapId,
    required this.service,
    this.nota,
    this.onAbrirNotaHistorica,
  });

  @override
  State<NotaWorkspaceAttachmentsTab> createState() =>
      _NotaWorkspaceAttachmentsTabState();
}

class _NotaWorkspaceAttachmentsTabState
    extends State<NotaWorkspaceAttachmentsTab> {
  List<NotaSapAnexo> _anexos = [];
  List<NotaSapAnexo> get _imagensAtuais =>
      _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.imagem).toList();
  bool _isLoading = true;
  bool _isUploading = false;
  String? _uploadStatusText;
  String? _erro;

  // Estados de filtros, busca e visualização (Fase 1)
  _FiltroTipoAnexo _filtroTipo = _FiltroTipoAnexo.todos;
  String? _filtroOrigem; // null (todos), 'SAP', 'TASKFLOW', 'MANUAL'
  _ModoExibicao _modoExibicao = _ModoExibicao.cards;
  _ModoAgrupamento _modoAgrupamento = _ModoAgrupamento.porRelevancia;
  _OrdenacaoAnexo _ordenacao = _OrdenacaoAnexo.maisRecente;

  // Estados de inspeção técnica rápida (Fase 2)
  bool _mostrarPainelLateral = true;
  NotaSapAnexo? _anexoSelecionado;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  // Mapeamento em lote do uso dos anexos na análise técnica (Fase 4 - Anti N+1)
  Map<String, List<NotaTipoVinculoEvidencia>> _usosNaAnalise = {};

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() {
        _termoBusca = _buscaController.text.trim().toLowerCase();
      });
    });
    _carregarAnexos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarAnexos() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final futures = await Future.wait([
        widget.service.listarAnexos(widget.notaSapId),
        widget.service.buscarUsoDosAnexos(widget.notaSapId),
      ]);

      final list = futures[0] as List<NotaSapAnexo>;
      final usos = futures[1] as Map<String, List<NotaTipoVinculoEvidencia>>;

      if (mounted) {
        setState(() {
          _anexos = list;
          _usosNaAnalise = usos;
          _isLoading = false;
          if (_anexoSelecionado != null) {
            final match = list.where((a) => a.id == _anexoSelecionado!.id).toList();
            _anexoSelecionado = match.isNotEmpty ? match.first : (list.isNotEmpty ? list.first : null);
          } else if (list.isNotEmpty) {
            _anexoSelecionado = list.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar os anexos: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  // ---------------------------------------------------------------------------
  // UPLOAD
  // ---------------------------------------------------------------------------
  Future<void> _iniciarUpload(BuildContext context) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _mostrarOpcoesUploadMobile();
    } else {
      _selecionarArquivosDesktopWeb();
    }
  }

  void _mostrarOpcoesUploadMobile() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tirar Foto (Câmera)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _capturarFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _capturarFoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_outlined),
                title: const Text('Selecionar Documento / Arquivo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _selecionarArquivosDesktopWeb();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _capturarFoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        String? userId;
        String? userName;
        try {
          final auth = AuthServiceSimples();
          userId = auth.currentUser?.id;
          userName = auth.getUserName() ?? auth.currentUser?.email;
        } catch (_) {}

        setState(() {
          _isUploading = true;
          _uploadStatusText = 'Enviando foto...';
        });

        await widget.service.uploadAnexoFromBytes(
          notaSapId: widget.notaSapId,
          bytes: bytes,
          nomeArquivo: photo.name.isNotEmpty
              ? photo.name
              : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
          usuarioId: userId,
          usuarioNome: userName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto enviada com sucesso!')),
          );
        }
        _carregarAnexos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  Future<void> _selecionarArquivosDesktopWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        String? userId;
        String? userName;
        try {
          final auth = AuthServiceSimples();
          userId = auth.currentUser?.id;
          userName = auth.getUserName() ?? auth.currentUser?.email;
        } catch (_) {}

        setState(() {
          _isUploading = true;
          _uploadStatusText = 'Enviando ${result.files.length} arquivo(s)...';
        });

        int sucessos = 0;
        for (final file in result.files) {
          Uint8List? bytes = file.bytes;
          if (bytes == null && file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            await widget.service.uploadAnexoFromBytes(
              notaSapId: widget.notaSapId,
              bytes: bytes,
              nomeArquivo: file.name,
              usuarioId: userId,
              usuarioNome: userName,
            );
            sucessos++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$sucessos anexo(s) enviado(s) com sucesso!'),
            ),
          );
        }
        _carregarAnexos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar/enviar anexos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // VISUALIZAÇÃO EM TELA CHEIA (FASE 2: VIEWER TÉCNICO E GALERIA INTERATIVA)
  // ---------------------------------------------------------------------------
  Future<void> _visualizarOuAbrirAnexo(NotaSapAnexo anexo) async {
    final listaAtual = _processarAnexos();
    final index = listaAtual.indexWhere((a) => a.id == anexo.id);
    final indiceValido = index != -1 ? index : 0;

    String contextoLabel;
    if (_termoBusca.isNotEmpty) {
      contextoLabel = 'Busca: "$_termoBusca"';
    } else if (_filtroTipo != _FiltroTipoAnexo.todos) {
      contextoLabel = _filtroTipo.label;
    } else if (_filtroOrigem != null) {
      contextoLabel = 'Origem $_filtroOrigem';
    } else {
      contextoLabel = 'Todas as Evidências';
    }

    await NotaAnexoViewerDialog.abrir(
      context: context,
      anexos: listaAtual,
      indiceInicial: indiceValido,
      contextoFiltro: contextoLabel,
      service: widget.service,
      notaAtual: widget.nota,
      anexosAtuais: _imagensAtuais,
      onRelevanciaAlternada: (anexoAlterado, relevante) {
        setState(() {
          final idx = _anexos.indexWhere((a) => a.id == anexoAlterado.id);
          if (idx != -1) {
            _anexos[idx] = anexoAlterado;
          }
          if (_anexoSelecionado?.id == anexoAlterado.id) {
            _anexoSelecionado = anexoAlterado;
          }
        });
      },
    );
  }

  Future<void> _alternarRelevancia(NotaSapAnexo anexo) async {
    if (anexo.id == null) return;
    final novoStatus = !anexo.relevanteAnalise;

    setState(() {
      final index = _anexos.indexWhere((a) => a.id == anexo.id);
      if (index != -1) {
        _anexos[index] = anexo.copyWith(relevanteAnalise: novoStatus);
      }
      if (_anexoSelecionado?.id == anexo.id) {
        _anexoSelecionado = _anexoSelecionado!.copyWith(relevanteAnalise: novoStatus);
      }
    });

    try {
      await widget.service.alternarRelevanteParaAnalise(
        anexoId: anexo.id!,
        notaSapId: widget.notaSapId,
        relevante: novoStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(novoStatus
                ? '★ Marcado como Evidência Técnica Relevante!'
                : 'Removido dos destaques de evidências.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Rollback
      setState(() {
        final index = _anexos.indexWhere((a) => a.id == anexo.id);
        if (index != -1) {
          _anexos[index] = anexo.copyWith(relevanteAnalise: !novoStatus);
        }
        if (_anexoSelecionado?.id == anexo.id) {
          _anexoSelecionado = _anexoSelecionado!.copyWith(relevanteAnalise: !novoStatus);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar evidência: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copiarLink(NotaSapAnexo anexo) async {
    try {
      final url = await widget.service.obterUrlAssinada(anexo);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link assinado copiado para a área de transferência!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao copiar link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(NotaSapAnexo anexo) async {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    Map<String, dynamic> vinculados = {'anotacoes': 0, 'derivadas': 0, 'analise': 0, 'secoes': <String>[]};
    if (anexo.id != null && anexo.isOriginal) {
      try {
        vinculados = await widget.service
            .obterContagemEvidenciasVinculadas(anexo.id!);
      } catch (_) {}
    }

    final qtdAnotacoes = (vinculados['anotacoes'] as int?) ?? 0;
    final qtdDerivadas = (vinculados['derivadas'] as int?) ?? 0;
    final qtdAnalise = (vinculados['analise'] as int?) ?? 0;
    final secoesUso = (vinculados['secoes'] as List?)?.cast<String>() ?? <String>[];

    if (!mounted) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Excluir Anexo',
            style: typography.sectionTitle.copyWith(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja realmente excluir "${anexo.nomeExibicao}"?',
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            if (qtdAnalise > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade600),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.link_off,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Esta evidência é utilizada na Análise Técnica ($qtdAnalise vínculo(s)):',
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: secoesUso.map((s) {
                              final tipo = NotaTipoVinculoEvidencia.fromValor(s);
                              final label = tipo?.label ?? s;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade800.withAlpha(60),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '• $label',
                                  style: const TextStyle(fontSize: 11.0, color: Colors.white),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A exclusão removerá esses vínculos automaticamente da análise.',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (qtdAnotacoes > 0 || qtdDerivadas > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atenção: Este anexo possui $qtdAnotacoes versão(ões) de anotação e $qtdDerivadas imagem(ns) derivada(s) gerada(s). Todas serão removidas permanentemente do Storage.',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      try {
        await widget.service.excluirAnexo(anexo);
        _carregarAnexos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anexo removido com sucesso'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir anexo: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FILTRAGEM E ORDENAÇÃO
  // ---------------------------------------------------------------------------
  List<NotaSapAnexo> _processarAnexos() {
    var lista = List<NotaSapAnexo>.from(_anexos);

    // 1. Filtro de Tipo
    switch (_filtroTipo) {
      case _FiltroTipoAnexo.todos:
        break;
      case _FiltroTipoAnexo.relevantes:
        lista = lista.where((a) => a.relevanteAnalise).toList();
        break;
      case _FiltroTipoAnexo.naAnalise:
        lista = lista.where((a) => a.id != null && _usosNaAnalise.containsKey(a.id) && _usosNaAnalise[a.id]!.isNotEmpty).toList();
        break;
      case _FiltroTipoAnexo.anotados:
        lista = lista.where((a) => a.possuiAnotacao).toList();
        break;
      case _FiltroTipoAnexo.imagens:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.imagem).toList();
        break;
      case _FiltroTipoAnexo.pdfs:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.pdf).toList();
        break;
      case _FiltroTipoAnexo.videos:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.video).toList();
        break;
      case _FiltroTipoAnexo.documentos:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.documento).toList();
        break;
      case _FiltroTipoAnexo.planilhas:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.planilha).toList();
        break;
      case _FiltroTipoAnexo.audios:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.audio).toList();
        break;
      case _FiltroTipoAnexo.outros:
        lista = lista.where((a) => a.tipoArquivo == NotaAnexoTipo.outro).toList();
        break;
    }

    // 2. Filtro de Origem
    if (_filtroOrigem != null) {
      lista = lista
          .where((a) => a.origem.toUpperCase() == _filtroOrigem!.toUpperCase())
          .toList();
    }

    // 3. Busca Textual
    if (_termoBusca.isNotEmpty) {
      lista = lista.where((a) {
        final nome = a.nomeArquivo.toLowerCase();
        final original = (a.nomeOriginal ?? '').toLowerCase();
        final leg = (a.legenda ?? '').toLowerCase();
        final docId = (a.sapDocumentId ?? '').toLowerCase();
        return nome.contains(_termoBusca) ||
            original.contains(_termoBusca) ||
            leg.contains(_termoBusca) ||
            docId.contains(_termoBusca);
      }).toList();
    }

    // 4. Ordenação
    switch (_ordenacao) {
      case _OrdenacaoAnexo.maisRecente:
        lista.sort((a, b) {
          final da = a.createdAt ?? a.importadoEm ?? DateTime(1970);
          final db = b.createdAt ?? b.importadoEm ?? DateTime(1970);
          return db.compareTo(da);
        });
        break;
      case _OrdenacaoAnexo.maisAntigo:
        lista.sort((a, b) {
          final da = a.createdAt ?? a.importadoEm ?? DateTime(1970);
          final db = b.createdAt ?? b.importadoEm ?? DateTime(1970);
          return da.compareTo(db);
        });
        break;
      case _OrdenacaoAnexo.nomeAZ:
        lista.sort((a, b) => a.nomeExibicao.toLowerCase().compareTo(b.nomeExibicao.toLowerCase()));
        break;
      case _OrdenacaoAnexo.maiorTamanho:
        lista.sort((a, b) => b.tamanhoBytes.compareTo(a.tamanhoBytes));
        break;
    }

    return lista;
  }

  // ---------------------------------------------------------------------------
  // BUILD PRINCIPAL
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final anexosFiltrados = _processarAnexos();

    // Se o anexo selecionado foi excluído ou filtrado para fora, atualiza o selecionado
    if (_anexoSelecionado != null &&
        !anexosFiltrados.any((a) => a.id == _anexoSelecionado!.id)) {
      _anexoSelecionado = anexosFiltrados.isNotEmpty ? anexosFiltrados.first : null;
    } else if (_anexoSelecionado == null && anexosFiltrados.isNotEmpty) {
      _anexoSelecionado = anexosFiltrados.first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool podeExibirSplit = constraints.maxWidth >= 900;
        final bool isDesktopSplit = podeExibirSplit && _mostrarPainelLateral;

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho-Resumo de Evidências (Dashboard & Contadores por tipo)
              _buildCabecalhoResumo(colors, typography, spacing),

              SizedBox(height: spacing.md),

              // 2. Barra de Controle: Busca, Filtros, Modo, Agrupamento e Split View
              _buildBarraControle(colors, typography, spacing, constraints.maxWidth),

              SizedBox(height: spacing.md),

              // 3. Conteúdo Principal (Loading, Erro, Vazio ou Split Layout)
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_erro != null)
                _buildErrorState(colors, spacing)
              else if (_anexos.isEmpty)
                if (isDesktopSplit)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _buildEmptyState(colors, typography, spacing),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 9,
                        child: widget.nota != null
                            ? NotaWorkspaceHistoricoAnexosSection(
                                nota: widget.nota!,
                                anexosAtuais: _imagensAtuais,
                                analiseService: widget.service,
                                onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                                onEvidenciasAlteradas: _carregarAnexos,
                                customMargin: EdgeInsets.zero,
                              )
                            : _buildPainelInspecaoLateral(colors, typography, spacing),
                      ),
                    ],
                  )
                else ...[
                  _buildEmptyState(colors, typography, spacing),
                  if (widget.nota != null)
                    if (constraints.maxWidth < 900)
                      _buildBotaoHistoricoMobile(colors, typography, spacing)
                    else
                      NotaWorkspaceHistoricoAnexosSection(
                        nota: widget.nota!,
                        anexosAtuais: _imagensAtuais,
                        analiseService: widget.service,
                        onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                        onEvidenciasAlteradas: _carregarAnexos,
                      ),
                ]
              else if (anexosFiltrados.isEmpty)
                if (isDesktopSplit)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _buildEmptyFilterState(colors, typography),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 9,
                        child: widget.nota != null
                            ? NotaWorkspaceHistoricoAnexosSection(
                                nota: widget.nota!,
                                anexosAtuais: _imagensAtuais,
                                analiseService: widget.service,
                                onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                                onEvidenciasAlteradas: _carregarAnexos,
                                customMargin: EdgeInsets.zero,
                              )
                            : _buildPainelInspecaoLateral(colors, typography, spacing),
                      ),
                    ],
                  )
                else ...[
                  _buildEmptyFilterState(colors, typography),
                  if (widget.nota != null)
                    if (constraints.maxWidth < 900)
                      _buildBotaoHistoricoMobile(colors, typography, spacing)
                    else
                      NotaWorkspaceHistoricoAnexosSection(
                        nota: widget.nota!,
                        anexosAtuais: _imagensAtuais,
                        analiseService: widget.service,
                        onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                        onEvidenciasAlteradas: _carregarAnexos,
                      ),
                ]
              else if (isDesktopSplit)
                // Layout Dividido (Split View no Desktop): Anexos da Nota SAP à esquerda (55%), Histórico de Anexos à direita (45%)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna Esquerda: Lista / Grade de Evidências da Nota SAP (~55%)
                    Expanded(
                      flex: 11,
                      child: _buildSecoesOuLista(anexosFiltrados, colors, typography, spacing),
                    ),
                    const SizedBox(width: 16),
                    // Coluna Direita: Histórico de Anexos (~45%) ou Inspeção Rápida
                    Expanded(
                      flex: 9,
                      child: widget.nota != null
                          ? NotaWorkspaceHistoricoAnexosSection(
                              nota: widget.nota!,
                              anexosAtuais: _imagensAtuais,
                              analiseService: widget.service,
                              onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                              onEvidenciasAlteradas: _carregarAnexos,
                              customMargin: EdgeInsets.zero,
                            )
                          : _buildPainelInspecaoLateral(colors, typography, spacing),
                    ),
                  ],
                )
              else ...[
                // Layout Padrão em Largura Total (Mobile / Tablet ou Histórico Lateral Desativado)
                _buildSecoesOuLista(anexosFiltrados, colors, typography, spacing),

                // Seção Contextual: Botão Mobile ou Histórico Completo
                if (widget.nota != null)
                  if (constraints.maxWidth < 900)
                    _buildBotaoHistoricoMobile(colors, typography, spacing)
                  else
                    NotaWorkspaceHistoricoAnexosSection(
                      nota: widget.nota!,
                      anexosAtuais: _imagensAtuais,
                      analiseService: widget.service,
                      onAbrirNotaHistorica: widget.onAbrirNotaHistorica,
                      onEvidenciasAlteradas: _carregarAnexos,
                    ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BOTÃO DE HISTÓRICO INTEGRADO PARA TELAS MENORES / MOBILE (< 900px)
  // ---------------------------------------------------------------------------
  Widget _buildBotaoHistoricoMobile(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (widget.nota == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: spacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(TFRadius.r12),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) => Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: NotaWorkspaceHistoricoAnexosSection(
                          nota: widget.nota!,
                          anexosAtuais: _imagensAtuais,
                          analiseService: widget.service,
                          onAbrirNotaHistorica: (notaHist) {
                            Navigator.of(ctx).pop();
                            widget.onAbrirNotaHistorica?.call(notaHist);
                          },
                          onEvidenciasAlteradas: _carregarAnexos,
                          customMargin: EdgeInsets.all(spacing.sm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(TFRadius.r12),
            border: Border.all(color: colors.primary.withAlpha(80)),
          ),
          child: Row(
            children: [
              Icon(Icons.history_edu, color: colors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico de Anexos',
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Consultar notas anteriores e álbuns de campo',
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. CABEÇALHO-RESUMO DE EVIDÊNCIAS
  // ---------------------------------------------------------------------------
  Widget _buildCabecalhoResumo(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final total = _anexos.length;
    final totalRelevantes = _anexos.where((a) => a.relevanteAnalise).length;
    final totalNaAnalise = _anexos
        .where((a) => a.id != null && _usosNaAnalise.containsKey(a.id) && _usosNaAnalise[a.id]!.isNotEmpty)
        .length;
    final totalImagens =
        _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.imagem).length;
    final totalPdfsDocs = _anexos
        .where((a) =>
            a.tipoArquivo == NotaAnexoTipo.pdf ||
            a.tipoArquivo == NotaAnexoTipo.documento ||
            a.tipoArquivo == NotaAnexoTipo.planilha)
        .length;
    final totalSap = _anexos.where((a) => a.origem.toUpperCase() == 'SAP').length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Linha de Título + Botão de Upload
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                ),
                child: Icon(Icons.photo_library_outlined,
                    color: colors.primary, size: 24),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Workspace de Evidências Técnicas',
                          style: typography.sectionTitle.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        if (totalRelevantes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star,
                                    size: 13, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalRelevantes evidência(s) crítica(s)',
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Documentação visual e técnica para apoio a diagnóstico, escopo, segurança e materiais da Nota SAP.',
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryForeground,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.sm,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                  ),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text('Novo Anexo'),
                onPressed: _isUploading ? null : () => _iniciarUpload(context),
              ),
            ],
          ),

          if (_isUploading) ...[
            SizedBox(height: spacing.md),
            Container(
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: colors.primary.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    _uploadStatusText ?? 'Enviando arquivo ao Storage...',
                    style: typography.bodyMedium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: spacing.md),

          // Cards Métricos Clicáveis (Agregação por tipo e relevância)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricCard(
                    title: 'Total Geral',
                    value: '$total',
                    icon: Icons.folder_outlined,
                    color: colors.textPrimary,
                    ativo: _filtroTipo == _FiltroTipoAnexo.todos && _filtroOrigem == null,
                    onTap: () {
                      setState(() {
                        _filtroTipo = _FiltroTipoAnexo.todos;
                        _filtroOrigem = null;
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                  _buildMetricCard(
                    title: '★ Relevantes',
                    value: '$totalRelevantes',
                    icon: Icons.star,
                    color: Colors.amber.shade800,
                    ativo: _filtroTipo == _FiltroTipoAnexo.relevantes,
                    onTap: () {
                      setState(() {
                        _filtroTipo = _FiltroTipoAnexo.relevantes;
                        _filtroOrigem = null;
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                  _buildMetricCard(
                    title: '📎 Na Análise',
                    value: '$totalNaAnalise',
                    icon: Icons.attach_file,
                    color: Colors.purple.shade700,
                    ativo: _filtroTipo == _FiltroTipoAnexo.naAnalise,
                    onTap: () {
                      setState(() {
                        _filtroTipo = _FiltroTipoAnexo.naAnalise;
                        _filtroOrigem = null;
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                  _buildMetricCard(
                    title: 'Imagens / Fotos',
                    value: '$totalImagens',
                    icon: Icons.image_outlined,
                    color: Colors.blue.shade700,
                    ativo: _filtroTipo == _FiltroTipoAnexo.imagens,
                    onTap: () {
                      setState(() {
                        _filtroTipo = _FiltroTipoAnexo.imagens;
                        _filtroOrigem = null;
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                  _buildMetricCard(
                    title: 'Laudos & PDFs',
                    value: '$totalPdfsDocs',
                    icon: Icons.picture_as_pdf_outlined,
                    color: Colors.red.shade700,
                    ativo: _filtroTipo == _FiltroTipoAnexo.pdfs,
                    onTap: () {
                      setState(() {
                        _filtroTipo = _FiltroTipoAnexo.pdfs;
                        _filtroOrigem = null;
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                  _buildMetricCard(
                    title: 'Origem SAP',
                    value: '$totalSap',
                    icon: Icons.sync,
                    color: Colors.teal.shade700,
                    ativo: _filtroOrigem == 'SAP',
                    onTap: () {
                      setState(() {
                        _filtroOrigem = _filtroOrigem == 'SAP' ? null : 'SAP';
                      });
                    },
                    width: isWide ? 130 : (constraints.maxWidth - 24) / 2,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool ativo,
    required VoidCallback onTap,
    required double width,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? color.withAlpha(25) : Colors.grey.withAlpha(12),
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: ativo ? color : Colors.grey.withAlpha(50),
            width: ativo ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
                      color: ativo ? color : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. BARRA DE CONTROLE: BUSCA, FILTROS, MODO E AGRUPAMENTO
  // ---------------------------------------------------------------------------
  Widget _buildBarraControle(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
    double screenWidth,
  ) {
    final bool podeExibirSplit = screenWidth >= 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Linha 1: Campo de Busca + Controles de Visualização, Agrupamento e Painel
        Row(
          children: [
            // Campo de Busca
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _buscaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, evidência técnica, ID SAP ou legenda...',
                    hintStyle: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _termoBusca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _buscaController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TFRadius.r8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    filled: true,
                    fillColor: colors.surface,
                  ),
                  style: const TextStyle(fontSize: 13.0),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Alternador de Modo de Exibição (Cards vs Lista)
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TFRadius.r8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.grid_view_outlined,
                        size: 18,
                        color: _modoExibicao == _ModoExibicao.cards
                            ? colors.primary
                            : colors.textSecondary),
                    tooltip: 'Modo Cards (Grade)',
                    onPressed: () {
                      setState(() => _modoExibicao = _ModoExibicao.cards);
                    },
                  ),
                  Container(width: 1, height: 20, color: colors.borderSubtle),
                  IconButton(
                    icon: Icon(Icons.view_list_outlined,
                        size: 20,
                        color: _modoExibicao == _ModoExibicao.lista
                            ? colors.primary
                            : colors.textSecondary),
                    tooltip: 'Modo Lista Detalhada',
                    onPressed: () {
                      setState(() => _modoExibicao = _ModoExibicao.lista);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Menu de Agrupamento
            PopupMenuButton<_ModoAgrupamento>(
              tooltip: 'Agrupar evidências',
              initialValue: _modoAgrupamento,
              onSelected: (val) {
                setState(() => _modoAgrupamento = val);
              },
              itemBuilder: (ctx) => _ModoAgrupamento.values.map((ag) {
                return PopupMenuItem(
                  value: ag,
                  child: Row(
                    children: [
                      Icon(
                        _modoAgrupamento == ag
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: _modoAgrupamento == ag
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(ag.label, style: const TextStyle(fontSize: 12.0)),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(Icons.layers_outlined, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _modoAgrupamento.label,
                      style: TextStyle(fontSize: 11.0, color: colors.textPrimary),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Menu de Ordenação
            PopupMenuButton<_OrdenacaoAnexo>(
              tooltip: 'Ordenar',
              initialValue: _ordenacao,
              onSelected: (val) {
                setState(() => _ordenacao = val);
              },
              itemBuilder: (ctx) => _OrdenacaoAnexo.values.map((ord) {
                return PopupMenuItem(
                  value: ord,
                  child: Row(
                    children: [
                      Icon(
                        _ordenacao == ord
                            ? Icons.check
                            : Icons.sort,
                        size: 16,
                        color: _ordenacao == ord ? colors.primary : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Text(ord.label, style: const TextStyle(fontSize: 12.0)),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _ordenacao.label,
                      style: TextStyle(fontSize: 11.0, color: colors.textPrimary),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botão Alternar Histórico Visual Lateral (Desktop)
            if (podeExibirSplit)
              IconButton(
                icon: Icon(
                  _mostrarPainelLateral
                      ? Icons.vertical_split
                      : Icons.vertical_split_outlined,
                  size: 20,
                  color: _mostrarPainelLateral ? colors.primary : colors.textSecondary,
                ),
                tooltip: _mostrarPainelLateral
                    ? 'Ocultar Histórico de Anexos Lateral'
                    : 'Exibir Histórico de Anexos ao Lado',
                onPressed: () {
                  setState(() => _mostrarPainelLateral = !_mostrarPainelLateral);
                },
              ),

            // Botão Recarregar
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Recarregar anexos do servidor',
              onPressed: _carregarAnexos,
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Linha 2: Chips de Filtro Ricos por Tipo & Origem
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._FiltroTipoAnexo.values.map((filtro) {
                final qtd = _contarPorFiltro(filtro);
                if (filtro != _FiltroTipoAnexo.todos && qtd == 0) {
                  return const SizedBox.shrink();
                }
                return _buildFilterChip(
                  label: '${filtro.label} ($qtd)',
                  selecionado: _filtroTipo == filtro,
                  color: filtro == _FiltroTipoAnexo.relevantes
                      ? Colors.amber.shade800
                      : null,
                  onSelected: (sel) {
                    setState(() {
                      _filtroTipo = sel ? filtro : _FiltroTipoAnexo.todos;
                    });
                  },
                );
              }),
              const SizedBox(width: 8),
              Container(width: 1, height: 22, color: colors.borderSubtle),
              const SizedBox(width: 8),
              // Filtro rápido de Origem
              _buildFilterChip(
                label: 'Origem SAP',
                selecionado: _filtroOrigem == 'SAP',
                color: Colors.blue.shade800,
                onSelected: (sel) {
                  setState(() => _filtroOrigem = sel ? 'SAP' : null);
                },
              ),
              _buildFilterChip(
                label: 'TaskFlow / Manual',
                selecionado: _filtroOrigem == 'TASKFLOW',
                color: Colors.teal.shade800,
                onSelected: (sel) {
                  setState(() => _filtroOrigem = sel ? 'TASKFLOW' : null);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _contarPorFiltro(_FiltroTipoAnexo filtro) {
    switch (filtro) {
      case _FiltroTipoAnexo.todos:
        return _anexos.length;
      case _FiltroTipoAnexo.relevantes:
        return _anexos.where((a) => a.relevanteAnalise).length;
      case _FiltroTipoAnexo.naAnalise:
        return _anexos.where((a) => a.id != null && _usosNaAnalise.containsKey(a.id) && _usosNaAnalise[a.id]!.isNotEmpty).length;
      case _FiltroTipoAnexo.anotados:
        return _anexos.where((a) => a.possuiAnotacao).length;
      case _FiltroTipoAnexo.imagens:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.imagem).length;
      case _FiltroTipoAnexo.pdfs:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.pdf).length;
      case _FiltroTipoAnexo.videos:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.video).length;
      case _FiltroTipoAnexo.documentos:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.documento).length;
      case _FiltroTipoAnexo.planilhas:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.planilha).length;
      case _FiltroTipoAnexo.audios:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.audio).length;
      case _FiltroTipoAnexo.outros:
        return _anexos.where((a) => a.tipoArquivo == NotaAnexoTipo.outro).length;
    }
  }

  Widget _buildFilterChip({
    required String label,
    required bool selecionado,
    Color? color,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selecionado,
        onSelected: onSelected,
        labelStyle: TextStyle(
          fontSize: 11.0,
          fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
          color: selecionado
              ? Colors.white
              : (color ?? Theme.of(context).textTheme.bodyMedium?.color),
        ),
        selectedColor: color ?? Theme.of(context).colorScheme.primary,
        checkmarkColor: Colors.white,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. APRESENTAÇÃO COM SUPORTE A SEÇÕES / AGRUPAMENTO
  // ---------------------------------------------------------------------------
  Widget _buildSecoesOuLista(
    List<NotaSapAnexo> lista,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_modoAgrupamento == _ModoAgrupamento.nenhum) {
      return _renderConteudo(lista, colors, typography, spacing);
    }

    // Agrupamento por Relevância
    if (_modoAgrupamento == _ModoAgrupamento.porRelevancia) {
      final relevantes = lista.where((a) => a.relevanteAnalise).toList();
      final outros = lista.where((a) => !a.relevanteAnalise).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (relevantes.isNotEmpty) ...[
            _buildSecaoHeader(
              titulo: '★ Evidências Técnicas Relevantes',
              subtitulo: 'Anexos marcados como indispensáveis para diagnóstico e parecer técnico',
              total: relevantes.length,
              destaque: true,
              colors: colors,
            ),
            const SizedBox(height: 10),
            _renderConteudo(relevantes, colors, typography, spacing),
            const SizedBox(height: 24),
          ],
          if (outros.isNotEmpty) ...[
            _buildSecaoHeader(
              titulo: 'Outros Anexos e Evidências Gerais',
              subtitulo: 'Demais arquivos anexados do SAP ou inseridos no TaskFlow',
              total: outros.length,
              destaque: false,
              colors: colors,
            ),
            const SizedBox(height: 10),
            _renderConteudo(outros, colors, typography, spacing),
          ],
        ],
      );
    }

    // Agrupamento por Tipo
    if (_modoAgrupamento == _ModoAgrupamento.porTipo) {
      final Map<NotaAnexoTipo, List<NotaSapAnexo>> grupos = {};
      for (final anexo in lista) {
        grupos.putIfAbsent(anexo.tipoArquivo, () => []).add(anexo);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: grupos.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSecaoHeader(
                  titulo: entry.key.label,
                  total: entry.value.length,
                  destaque: entry.key == NotaAnexoTipo.imagem,
                  colors: colors,
                ),
                const SizedBox(height: 10),
                _renderConteudo(entry.value, colors, typography, spacing),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Agrupamento por Origem
    if (_modoAgrupamento == _ModoAgrupamento.porOrigem) {
      final sap = lista.where((a) => a.origem.toUpperCase() == 'SAP').toList();
      final taskflow = lista.where((a) => a.origem.toUpperCase() != 'SAP').toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sap.isNotEmpty) ...[
            _buildSecaoHeader(
              titulo: 'Origem SAP (GOS / BDS / Módulo)',
              subtitulo: 'Arquivos sincronizados diretamente do ambiente SAP da distribuidora',
              total: sap.length,
              destaque: false,
              colors: colors,
            ),
            const SizedBox(height: 10),
            _renderConteudo(sap, colors, typography, spacing),
            const SizedBox(height: 24),
          ],
          if (taskflow.isNotEmpty) ...[
            _buildSecaoHeader(
              titulo: 'Origem TaskFlow / Uploads Manuais',
              subtitulo: 'Fotos tiradas em campo ou documentos inseridos pela equipe',
              total: taskflow.length,
              destaque: false,
              colors: colors,
            ),
            const SizedBox(height: 10),
            _renderConteudo(taskflow, colors, typography, spacing),
          ],
        ],
      );
    }

    return _renderConteudo(lista, colors, typography, spacing);
  }

  Widget _buildSecaoHeader({
    required String titulo,
    String? subtitulo,
    required int total,
    required bool destaque,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: destaque ? Colors.amber.withAlpha(20) : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(
          color: destaque ? Colors.amber.shade300 : colors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$titulo ($total)',
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: destaque ? Colors.amber.shade900 : colors.textPrimary,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 11.0,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderConteudo(
    List<NotaSapAnexo> lista,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_modoExibicao == _ModoExibicao.cards) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 1100
              ? 4
              : (constraints.maxWidth >= 750
                  ? 3
                  : (constraints.maxWidth >= 480 ? 2 : 1));

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 220,
            ),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              return _buildAnexoCard(lista[index], colors, typography);
            },
          );
        },
      );
    } else {
      // Modo Lista Detalhada
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildAnexoListItem(lista[index], colors, typography);
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 4. MODO CARDS (FOTO EM FOCO OCUPANDO O ESPAÇO COMPLETO)
  // ---------------------------------------------------------------------------
  Widget _buildAnexoCard(
    NotaSapAnexo anexo,
    dynamic colors,
    dynamic typography,
  ) {
    final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;
    final ehEvidencia = anexo.relevanteAnalise;
    final ehSelecionado = _anexoSelecionado?.id == anexo.id;

    Color borderColor;
    double borderWidth;
    if (ehSelecionado) {
      borderColor = colors.primary;
      borderWidth = 2.5;
    } else if (ehEvidencia) {
      borderColor = Colors.amber.shade500;
      borderWidth = 2.0;
    } else {
      borderColor = colors.borderSubtle;
      borderWidth = 1.0;
    }

    // --- CARD PARA IMAGENS: FOTO OCUPA O ESPAÇO COMPLETO ---
    if (ehImagem) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(TFRadius.r12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: ehSelecionado
                  ? colors.primary.withAlpha(50)
                  : (ehEvidencia
                      ? Colors.amber.withAlpha(45)
                      : Colors.black.withAlpha(12)),
              blurRadius: ehSelecionado || ehEvidencia ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. A Foto ocupando 100% do espaço
            FutureBuilder<String>(
              future: widget.service.obterUrlAssinada(anexo),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: colors.surfaceSecondary,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                      ),
                    ),
                  );
                }
                return Container(
                  color: colors.surfaceSecondary,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),

            // 2. Área de toque da Foto (Clique simples abre diretamente no visualizador)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _anexoSelecionado = anexo);
                    _visualizarOuAbrirAnexo(anexo);
                  },
                  onDoubleTap: () => _visualizarOuAbrirAnexo(anexo),
                ),
              ),
            ),

            // 3. Gradiente Superior (com IgnorePointer para não bloquear toques)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 64,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

                // 3. Barra Superior (Origem + Anotação à esquerda; Estrela + Menu à direita)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _buildOrigemBadge(anexo.origem),
                      if (anexo.possuiAnotacao) ...[
                        const SizedBox(width: 4),
                        _buildAnotadoBadge(anexo.versaoAnotacao),
                      ],
                      const Spacer(),
                      // Botão de Relevância (Estrela)
                      Tooltip(
                        message: ehEvidencia
                            ? 'Evidência relevante (clique para remover destaque)'
                            : 'Marcar como evidência técnica relevante',
                        child: Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => _alternarRelevancia(anexo),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(
                                ehEvidencia ? Icons.star : Icons.star_border,
                                color: ehEvidencia
                                    ? Colors.amber.shade400
                                    : Colors.white.withValues(alpha: 0.85),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Menu de Opções
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'excluir') {
                              _confirmarExclusao(anexo);
                            } else if (val == 'copiar_link') {
                              _copiarLink(anexo);
                            } else if (val == 'abrir') {
                              _visualizarOuAbrirAnexo(anexo);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'abrir',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Visualizar / Galeria', style: TextStyle(fontSize: 12.0)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'copiar_link',
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16),
                                  SizedBox(width: 8),
                                  Text('Copiar Link Assinado', style: TextStyle(fontSize: 12.0)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Excluir', style: TextStyle(fontSize: 12.0, color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Gradiente Inferior (com nome e ações compactas)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nome do Arquivo
                          Tooltip(
                            message: anexo.nomeExibicao,
                            child: Text(
                              anexo.nomeExibicao,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Rodapé: Tamanho + Ações compactas
                          Row(
                            children: [
                              Text(
                                anexo.tamanhoFormatado,
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              // Botão Usar / Gerenciar na Análise (Ícone circular com Tooltip)
                              if (anexo.isOriginal) ...[
                                Tooltip(
                                  message: (anexo.id != null &&
                                          _usosNaAnalise.containsKey(anexo.id) &&
                                          _usosNaAnalise[anexo.id]!.isNotEmpty)
                                      ? 'Vinculado à Análise (${_usosNaAnalise[anexo.id]!.length} seção/seções)'
                                      : 'Usar na Análise Técnica',
                                  child: Material(
                                    color: (anexo.id != null &&
                                            _usosNaAnalise.containsKey(anexo.id) &&
                                            _usosNaAnalise[anexo.id]!.isNotEmpty)
                                        ? Colors.purple.shade700
                                        : Colors.black45,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () => _gerenciarVinculoAnalise(anexo),
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(Icons.hub_outlined, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              // Botão Visualizar / Zoom (Ícone circular com Tooltip)
                              Tooltip(
                                message: 'Visualizar / Galeria',
                                child: Material(
                                  color: Colors.black45,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _visualizarOuAbrirAnexo(anexo),
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(Icons.fullscreen, size: 15, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
    }

    // --- CARD PARA DOCUMENTOS (PDF, PLANILHA, ETC.) ---
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: ehSelecionado
                ? colors.primary.withAlpha(40)
                : (ehEvidencia
                    ? Colors.amber.withAlpha(35)
                    : Colors.black.withAlpha(10)),
            blurRadius: ehSelecionado || ehEvidencia ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Badges, Estrela, Menu
          Row(
            children: [
              _buildOrigemBadge(anexo.origem),
              const SizedBox(width: 5),
              _buildTipoBadge(anexo.tipoArquivo),
              const Spacer(),
              Tooltip(
                message: ehEvidencia
                    ? 'Evidência relevante (clique para remover destaque)'
                    : 'Marcar como evidência técnica relevante',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _alternarRelevancia(anexo),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        ehEvidencia ? Icons.star : Icons.star_border,
                        color: ehEvidencia
                            ? Colors.amber.shade700
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'excluir') {
                    _confirmarExclusao(anexo);
                  } else if (val == 'copiar_link') {
                    _copiarLink(anexo);
                  } else if (val == 'abrir') {
                    _visualizarOuAbrirAnexo(anexo);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'abrir',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Abrir', style: TextStyle(fontSize: 12.0)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copiar_link',
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 16),
                        SizedBox(width: 8),
                        Text('Copiar Link Assinado', style: TextStyle(fontSize: 12.0)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(fontSize: 12.0, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Centro: Ícone grande do tipo de documento
          Expanded(
            child: InkWell(
              onTap: () => _visualizarOuAbrirAnexo(anexo),
              borderRadius: BorderRadius.circular(TFRadius.r8),
              child: Center(
                child: _obterIconePorTipo(anexo.tipoArquivo),
              ),
            ),
          ),

          // Nome do Arquivo
          Tooltip(
            message: anexo.nomeExibicao,
            child: Text(
              anexo.nomeExibicao,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),

          // Rodapé: Tamanho + Botão Abrir
          Row(
            children: [
              Expanded(
                child: Text(
                  '${anexo.tamanhoFormatado} • ${_formatDate(anexo.createdAt ?? anexo.importadoEm)}',
                  style: TextStyle(fontSize: 10.0, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: 26,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _visualizarOuAbrirAnexo(anexo),
                  child: Text(
                    anexo.tipoArquivo == NotaAnexoTipo.pdf ? 'Abrir PDF' : 'Abrir',
                    style: const TextStyle(fontSize: 11.0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. MODO LISTA DETALHADA
  // ---------------------------------------------------------------------------
  Widget _buildAnexoListItem(
    NotaSapAnexo anexo,
    dynamic colors,
    dynamic typography,
  ) {
    final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;
    final ehEvidencia = anexo.relevanteAnalise;
    final ehSelecionado = _anexoSelecionado?.id == anexo.id;

    Color borderColor;
    double borderWidth;
    if (ehSelecionado) {
      borderColor = colors.primary;
      borderWidth = 1.8;
    } else if (ehEvidencia) {
      borderColor = Colors.amber.shade400;
      borderWidth = 1.5;
    } else {
      borderColor = colors.borderSubtle;
      borderWidth = 1.0;
    }

    return InkWell(
      onTap: () {
        setState(() => _anexoSelecionado = anexo);
        _visualizarOuAbrirAnexo(anexo);
      },
      onDoubleTap: () => _visualizarOuAbrirAnexo(anexo),
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Container(
        decoration: BoxDecoration(
          color: ehSelecionado ? colors.primary.withAlpha(12) : colors.surface,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Miniatura compacta 44x44
            GestureDetector(
              onTap: () => _visualizarOuAbrirAnexo(anexo),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 44,
                  height: 44,
                  color: colors.surfaceSecondary,
                  child: ehImagem
                      ? FutureBuilder<String>(
                          future: widget.service.obterUrlAssinada(anexo),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.network(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 20),
                              );
                            }
                            return const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              ),
                            );
                          },
                        )
                      : Center(child: _obterIconePorTipo(anexo.tipoArquivo, size: 22)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Informações Centrais
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildOrigemBadge(anexo.origem),
                      const SizedBox(width: 6),
                      _buildTipoBadge(anexo.tipoArquivo),
                      if (anexo.possuiAnotacao) ...[
                        const SizedBox(width: 6),
                        _buildAnotadoBadge(anexo.versaoAnotacao),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          anexo.nomeExibicao,
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (anexo.legenda != null && anexo.legenda!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      anexo.legenda!.trim(),
                      style: TextStyle(
                        fontSize: 11.0,
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${anexo.tamanhoFormatado} • ${_formatDate(anexo.createdAt ?? anexo.importadoEm)} • ID: ${anexo.sapDocumentId ?? (anexo.id != null ? (anexo.id!.length >= 8 ? anexo.id!.substring(0, 8) : anexo.id!) : "-")}',
                          style: TextStyle(fontSize: 10.0, color: colors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (anexo.id != null && _usosNaAnalise.containsKey(anexo.id)) ...[
                        const SizedBox(width: 8),
                        _buildSecoesVinculadasBadges(_usosNaAnalise[anexo.id]!),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Botão Usar na Análise (Modo Lista)
            if (anexo.isOriginal)
              IconButton(
                icon: Icon(
                  Icons.hub_outlined,
                  size: 20,
                  color: (anexo.id != null && _usosNaAnalise.containsKey(anexo.id) && _usosNaAnalise[anexo.id]!.isNotEmpty)
                      ? Colors.purple.shade700
                      : colors.textSecondary,
                ),
                tooltip: (anexo.id != null && _usosNaAnalise.containsKey(anexo.id) && _usosNaAnalise[anexo.id]!.isNotEmpty)
                    ? 'Na Análise (${_usosNaAnalise[anexo.id]!.map((s) => s.labelCurto).join(", ")})'
                    : 'Usar na Análise Técnica',
                onPressed: () => _gerenciarVinculoAnalise(anexo),
              ),

            // Botão Estrela de Relevância
            IconButton(
              icon: Icon(
                ehEvidencia ? Icons.star : Icons.star_border,
                color: ehEvidencia ? Colors.amber.shade700 : Colors.grey.shade400,
                size: 22,
              ),
              tooltip: ehEvidencia ? 'Evidência relevante' : 'Marcar evidência',
              onPressed: () => _alternarRelevancia(anexo),
            ),

            // Botão de Abertura / Visualização
            IconButton(
              icon: Icon(
                ehImagem ? Icons.zoom_in : Icons.open_in_new,
                size: 20,
                color: colors.primary,
              ),
              tooltip: 'Visualizar em Tela Cheia',
              onPressed: () => _visualizarOuAbrirAnexo(anexo),
            ),

            // Mais Opções
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
              onSelected: (val) {
                if (val == 'copiar_link') {
                  _copiarLink(anexo);
                } else if (val == 'excluir') {
                  _confirmarExclusao(anexo);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'copiar_link',
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16),
                      SizedBox(width: 8),
                      Text('Copiar Link', style: TextStyle(fontSize: 12.0)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'excluir',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(fontSize: 12.0, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. PAINEL DE INSPEÇÃO TÉCNICA RÁPIDA (DESKTOP SPLIT VIEW)
  // ---------------------------------------------------------------------------
  // ignore: unused_element
  Widget _buildPainelInspecaoLateral(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final anexo = _anexoSelecionado;
    if (anexo == null) {
      return Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(TFRadius.r12),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: colors.textSecondary.withAlpha(120)),
              const SizedBox(height: 8),
              Text(
                'Selecione uma evidência à esquerda para inspecionar rapidamente',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final ehImagem = anexo.tipoArquivo == NotaAnexoTipo.imagem;
    final ehEvidencia = anexo.relevanteAnalise;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(
          color: ehEvidencia ? Colors.amber.shade400 : colors.borderSubtle,
          width: ehEvidencia ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header do Painel Lateral
          Row(
            children: [
              Icon(Icons.manage_search, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Inspeção Técnica Rápida',
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Ocultar Painel Lateral',
                onPressed: () => setState(() => _mostrarPainelLateral = false),
              ),
            ],
          ),
          const Divider(height: 16),

          // Preview da Imagem ou Mídia Técnica
          GestureDetector(
            onTap: () => _visualizarOuAbrirAnexo(anexo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TFRadius.r8),
              child: Container(
                height: 230,
                color: colors.surfaceSecondary,
                child: ehImagem
                    ? FutureBuilder<String>(
                        future: widget.service.obterUrlAssinada(anexo),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, size: 36),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fullscreen, size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Tela Cheia', style: TextStyle(color: Colors.white, fontSize: 11.0)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _obterIconePorTipo(anexo.tipoArquivo, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              anexo.tipoArquivo.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Título e Badges
          Row(
            children: [
              _buildOrigemBadge(anexo.origem),
              const SizedBox(width: 6),
              _buildTipoBadge(anexo.tipoArquivo),
              const Spacer(),
              if (ehEvidencia)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'EVIDÊNCIA TÉCNICA',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            anexo.nomeExibicao,
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),

          if (anexo.legenda != null && anexo.legenda!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                anexo.legenda!.trim(),
                style: typography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Tabela de Detalhes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _buildDetalheLinha('Tamanho', anexo.tamanhoFormatado, colors),
                _buildDetalheLinha('Data', _formatDate(anexo.createdAt ?? anexo.importadoEm), colors),
                if (anexo.sapDocumentId != null)
                  _buildDetalheLinha('ID Documento SAP', anexo.sapDocumentId!, colors),
                if (anexo.sha256 != null)
                  _buildDetalheLinha('Hash SHA256', '${anexo.sha256!.substring(0, math.min(12, anexo.sha256!.length))}...', colors),
                _buildDetalheLinha('Bucket Storage', anexo.bucketNome, colors),
              ],
            ),
          ),

          if (anexo.tipoArquivo == NotaAnexoTipo.imagem) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: anexo.possuiAnotacao
                      ? Colors.teal.shade700
                      : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(
                  anexo.possuiAnotacao
                      ? 'Editar Anotação (v${anexo.versaoAnotacao})'
                      : 'Anotar Imagem',
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _abrirEditorAnotacaoDireto(anexo),
              ),
            ),
          ],

          if (anexo.isOriginal) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_outlined, size: 14, color: Colors.purple.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Usado na Análise Técnica:',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _gerenciarVinculoAnalise(anexo),
                        child: Text(
                          (anexo.id != null && _usosNaAnalise.containsKey(anexo.id) && _usosNaAnalise[anexo.id]!.isNotEmpty)
                              ? 'Gerenciar'
                              : 'Vincular',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  (anexo.id != null && _usosNaAnalise.containsKey(anexo.id) && _usosNaAnalise[anexo.id]!.isNotEmpty)
                      ? _buildSecoesVinculadasBadges(_usosNaAnalise[anexo.id]!)
                      : Text(
                          'Nenhuma seção associada a esta evidência.',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Botões de Ação Rápida
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ehEvidencia ? Colors.amber.shade700 : colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: Icon(ehEvidencia ? Icons.star : Icons.star_border, size: 16),
                  label: Text(
                    ehEvidencia ? 'Evidência Relevante' : 'Marcar Relevante',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                  onPressed: () => _alternarRelevancia(anexo),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Galeria', style: TextStyle(fontSize: 12.0)),
                onPressed: () => _visualizarOuAbrirAnexo(anexo),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.link, size: 18),
                tooltip: 'Copiar link assinado',
                onPressed: () => _copiarLink(anexo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalheLinha(String label, String valor, dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.0, color: colors.textSecondary)),
          Text(valor, style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS VISUAIS: ÍCONES E BADGES
  // ---------------------------------------------------------------------------
  Widget _obterIconePorTipo(NotaAnexoTipo tipo, {double size = 28}) {
    switch (tipo) {
      case NotaAnexoTipo.imagem:
        return Icon(Icons.image, color: Colors.blue.shade600, size: size);
      case NotaAnexoTipo.pdf:
        return Icon(Icons.picture_as_pdf, color: Colors.red.shade600, size: size);
      case NotaAnexoTipo.video:
        return Icon(Icons.video_library, color: Colors.purple.shade600, size: size);
      case NotaAnexoTipo.documento:
        return Icon(Icons.description, color: Colors.indigo.shade600, size: size);
      case NotaAnexoTipo.planilha:
        return Icon(Icons.table_chart, color: Colors.green.shade600, size: size);
      case NotaAnexoTipo.audio:
        return Icon(Icons.audio_file, color: Colors.orange.shade600, size: size);
      case NotaAnexoTipo.outro:
        return Icon(Icons.insert_drive_file, color: Colors.blueGrey.shade600, size: size);
    }
  }

  Widget _buildOrigemBadge(String origem) {
    Color bg;
    Color fg;
    final norm = origem.toUpperCase();

    switch (norm) {
      case 'SAP':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'TASKFLOW':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        norm,
        style: TextStyle(
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildAnotadoBadge(int versao) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.teal.shade300, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 12, color: Colors.teal.shade800),
          const SizedBox(width: 2),
          Text(
            'v$versao',
            style: TextStyle(
              fontSize: 9.0,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecoesVinculadasBadges(List<NotaTipoVinculoEvidencia> secoes) {
    if (secoes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: secoes.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.purple.shade300, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark, size: 10, color: Colors.purple.shade800),
              const SizedBox(width: 2),
              Text(
                s.labelCurto,
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Abre diálogo ou BottomSheet para vincular evidência à Análise Técnica
  Future<void> _gerenciarVinculoAnalise(NotaSapAnexo anexo) async {
    if (anexo.id == null) return;

    if (anexo.isDerivado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A evidência deve referenciar o anexo original.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _DialogGerenciarVinculoAnalise(
          notaSapId: widget.notaSapId,
          anexo: anexo,
          service: widget.service,
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: _DialogGerenciarVinculoAnalise(
              notaSapId: widget.notaSapId,
              anexo: anexo,
              service: widget.service,
            ),
          ),
        ),
      );
    }

    if (mounted) {
      _carregarAnexos();
    }
  }

  Future<void> _abrirEditorAnotacaoDireto(NotaSapAnexo anexo) async {
    try {
      final url = await widget.service.obterUrlAssinada(anexo);
      if (!mounted) return;

      final salvo = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (ctx) => NotaAnexoAnnotationEditor(
            anexo: anexo,
            imageUrl: url,
            service: widget.service,
          ),
        ),
      );

      if (salvo == true && mounted) {
        _carregarAnexos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir editor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTipoBadge(NotaAnexoTipo tipo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        tipo.label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.0,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADOS VAZIOS E ERRO
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 52, color: colors.textSecondary.withAlpha(120)),
          SizedBox(height: spacing.md),
          Text(
            'Nenhuma evidência ou anexo cadastrado nesta Nota SAP',
            style: typography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            'Utilize o botão "Novo Anexo" acima para subir fotos, croquis ou laudos,\nou execute a extração automática de anexos no SAP.',
            style: typography.caption.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(
    dynamic colors,
    dynamic typography,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined,
              size: 40, color: colors.textSecondary.withAlpha(120)),
          const SizedBox(height: 10),
          Text(
            'Nenhuma evidência encontrada com os filtros ou busca informados.',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _filtroTipo = _FiltroTipoAnexo.todos;
                _filtroOrigem = null;
                _buscaController.clear();
              });
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Limpar todos os filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(dynamic colors, dynamic spacing) {
    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            _erro!,
            style: TextStyle(color: Colors.red.shade800),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.md),
          OutlinedButton(
            onPressed: _carregarAnexos,
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo / BottomSheet completo para gerenciar vínculos do anexo com a Análise Técnica (Fase 4)
class _DialogGerenciarVinculoAnalise extends StatefulWidget {
  final String notaSapId;
  final NotaSapAnexo anexo;
  final NotaSapAnaliseService service;

  const _DialogGerenciarVinculoAnalise({
    required this.notaSapId,
    required this.anexo,
    required this.service,
  });

  @override
  State<_DialogGerenciarVinculoAnalise> createState() =>
      _DialogGerenciarVinculoAnaliseState();
}

class _DialogGerenciarVinculoAnaliseState
    extends State<_DialogGerenciarVinculoAnalise> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _erro;

  // Estado das seções selecionadas: tipo -> {selecionado: bool, versao: int?, obsController: TextEditingController}
  final Map<NotaTipoVinculoEvidencia, bool> _secoesSelecionadas = {};
  final Map<NotaTipoVinculoEvidencia, TextEditingController> _obsControllers = {};
  final Map<NotaTipoVinculoEvidencia, int?> _versoesPorSecao = {};

  // Modo de seleção de versão para imagem com anotação: 'original', 'recente', 'historica'
  int? _versaoMaisRecente;
  List<int> _versoesDisponiveis = [];

  // Vínculos existentes previamente salvos
  final Map<NotaTipoVinculoEvidencia, NotaSapAnaliseEvidencia> _vinculosExistentes = {};

  @override
  void initState() {
    super.initState();
    for (final tipo in NotaTipoVinculoEvidencia.values) {
      _secoesSelecionadas[tipo] = false;
      _obsControllers[tipo] = TextEditingController();
      _versoesPorSecao[tipo] = null;
    }
    _carregarDados();
  }

  @override
  void dispose() {
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final anexoId = widget.anexo.id!;

      final futures = await Future.wait([
        widget.service.listarEvidenciasDaNota(widget.notaSapId),
        widget.anexo.tipoArquivo == NotaAnexoTipo.imagem
            ? widget.service.obterHistoricoAnotacoes(anexoId)
            : Future.value(<NotaSapAnotacao>[]),
      ]);

      final todasEvidencias = futures[0] as List<NotaSapAnaliseEvidencia>;
      final historico = futures[1] as List<NotaSapAnotacao>;

      _versoesDisponiveis = historico.map((h) => h.versao).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      _versaoMaisRecente = _versoesDisponiveis.isNotEmpty ? _versoesDisponiveis.first : null;

      final evidenciasDesteAnexo =
          todasEvidencias.where((e) => e.anexoId == anexoId).toList();

      for (final ev in evidenciasDesteAnexo) {
        _vinculosExistentes[ev.tipoVinculo] = ev;
        _secoesSelecionadas[ev.tipoVinculo] = true;
        _obsControllers[ev.tipoVinculo]?.text = ev.observacao ?? '';
        _versoesPorSecao[ev.tipoVinculo] = ev.anotacaoVersao;
      }

      // Para seções que ainda não têm vínculo, define como padrão a versão mais recente se houver anotação
      for (final tipo in NotaTipoVinculoEvidencia.values) {
        if (!_vinculosExistentes.containsKey(tipo)) {
          _versoesPorSecao[tipo] = _versaoMaisRecente;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar dados do vínculo: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _isSaving = true;
      _erro = null;
    });

    try {
      final anexoId = widget.anexo.id!;

      // Descobre usuário autenticado se disponível
      String? userId;
      String? userName;
      try {
        final auth = AuthServiceSimples();
        userId = auth.currentUser?.id;
        userName = auth.getUserName() ?? auth.currentUser?.email;
      } catch (_) {}

      // Processa cada seção
      for (final tipo in NotaTipoVinculoEvidencia.values) {
        final selecionado = _secoesSelecionadas[tipo] == true;
        final jaExistia = _vinculosExistentes.containsKey(tipo);

        if (selecionado) {
          final versao = _versoesPorSecao[tipo];
          final obs = _obsControllers[tipo]?.text.trim();

          await widget.service.vincularEvidencia(
            notaSapId: widget.notaSapId,
            anexoId: anexoId,
            tipoVinculo: tipo,
            anotacaoVersao: versao,
            observacao: obs,
            criadoPor: userId,
            criadoPorNome: userName,
          );
        } else if (jaExistia) {
          // Desvincular se foi desmarcado
          await widget.service.desvincularEvidencia(
            notaSapId: widget.notaSapId,
            anexoId: anexoId,
            tipoVinculo: tipo,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vínculos com a Análise Técnica salvos com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao salvar vínculos: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final ehImagem = widget.anexo.tipoArquivo == NotaAnexoTipo.imagem;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.hub_outlined, color: Colors.purple.shade800, size: 22),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular à Análise Técnica',
                        style: typography.sectionTitle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          fontSize: 15.0,
                        ),
                      ),
                      Text(
                        widget.anexo.nomeExibicao,
                        style: typography.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erro != null)
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Text(
                _erro!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selecione as seções técnicas que esta evidência sustenta. Cada seção pode ter uma observação específica.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.md),

                    // Lista de Seções com Checkbox + Campo de Versão + Observação
                    ...NotaTipoVinculoEvidencia.values.map((tipo) {
                      final marcado = _secoesSelecionadas[tipo] == true;
                      final versaoAtual = _versoesPorSecao[tipo];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: marcado ? colors.surface : colors.surfaceSecondary.withAlpha(80),
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          border: Border.all(
                            color: marcado ? Colors.purple.shade300 : colors.borderSubtle,
                            width: marcado ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CheckboxListTile(
                              value: marcado,
                              activeColor: Colors.purple.shade700,
                              dense: true,
                              title: Text(
                                tipo.label,
                                style: TextStyle(
                                  fontWeight: marcado ? FontWeight.bold : FontWeight.w500,
                                  color: marcado ? colors.textPrimary : colors.textSecondary,
                                  fontSize: 13.0,
                                ),
                              ),
                              subtitle: Text(
                                _descricaoSecao(tipo),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: colors.textSecondary,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _secoesSelecionadas[tipo] = val ?? false;
                                });
                              },
                            ),
                            if (marcado) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 12),

                                    // Seletor de versão (se imagem com anotações)
                                    if (ehImagem && _versoesDisponiveis.isNotEmpty) ...[
                                      Text(
                                        'Versão da Evidência para ${tipo.labelCurto}:',
                                        style: typography.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          ChoiceChip(
                                            label: const Text('Original'),
                                            selected: versaoAtual == null,
                                            onSelected: (sel) {
                                              if (sel) {
                                                setState(() => _versoesPorSecao[tipo] = null);
                                              }
                                            },
                                          ),
                                          if (_versaoMaisRecente != null)
                                            ChoiceChip(
                                              label: Text('Anotada v$_versaoMaisRecente (Mais recente)'),
                                              selected: versaoAtual == _versaoMaisRecente,
                                              onSelected: (sel) {
                                                if (sel) {
                                                  setState(() => _versoesPorSecao[tipo] = _versaoMaisRecente);
                                                }
                                              },
                                            ),
                                          ..._versoesDisponiveis
                                              .where((v) => v != _versaoMaisRecente)
                                              .map((v) => ChoiceChip(
                                                    label: Text('v$v'),
                                                    selected: versaoAtual == v,
                                                    onSelected: (sel) {
                                                      if (sel) {
                                                        setState(() => _versoesPorSecao[tipo] = v);
                                                      }
                                                    },
                                                  )),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Campo de Observação contextual
                                    Text(
                                      'Observação / Justificativa (opcional):',
                                      style: typography.caption.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _obsControllers[tipo],
                                      maxLines: 2,
                                      style: const TextStyle(fontSize: 12.0),
                                      decoration: InputDecoration(
                                        hintText: 'Ex: Justifica necessidade de cabo ou peça...',
                                        hintStyle: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: colors.borderSubtle),
                                        ),
                                        filled: true,
                                        fillColor: colors.surfaceSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Footer com botões de Salvar e Cancelar
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
                ),
                SizedBox(width: spacing.md),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Salvar Vínculos'),
                  onPressed: _isSaving ? null : _salvar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _descricaoSecao(NotaTipoVinculoEvidencia tipo) {
    switch (tipo) {
      case NotaTipoVinculoEvidencia.diagnostico:
        return 'Sustenta causas do defeito e laudo preliminar';
      case NotaTipoVinculoEvidencia.escopo:
        return 'Documenta os passos do serviço e croqui';
      case NotaTipoVinculoEvidencia.materiais:
        return 'Comprova aplicação e necessidade de insumos';
      case NotaTipoVinculoEvidencia.seguranca:
        return 'Registra riscos, proximidade com redes e EPI/EPC';
      case NotaTipoVinculoEvidencia.desligamento:
        return 'Justifica necessidade de desenergização / PV';
      case NotaTipoVinculoEvidencia.acesso:
        return 'Mostra vias de acesso, condições de terreno e logística';
      case NotaTipoVinculoEvidencia.outro:
        return 'Evidência técnica complementar';
    }
  }
}
