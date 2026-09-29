import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/demanda_anexo_model.dart';
import '../../data/models/demanda_historico_model.dart';
import '../../data/models/demanda_model.dart';
import '../../data/services/demanda_service.dart';
import '../widgets/demanda_prazo_helper.dart';
import '../widgets/demanda_status_mapper.dart';
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

      if (mounted) {
        setState(() {
          _demanda = demanda;
          _anexos = anexos;
          _historico = hist;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroMsg = 'Erro ao carregar detalhes da demanda: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _concluirRapido() async {
    if (_demanda == null) return;

    final confirmar = await TFModalDialog.confirm(
      context: context,
      title: 'Concluir demanda',
      message: 'Confirmar a conclusão desta demanda operacional?',
      confirmLabel: 'Concluir',
      cancelLabel: 'Cancelar',
      isDestructive: false,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demanda concluída com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao concluir demanda: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _cancelarDemanda() async {
    if (_demanda == null) return;

    final confirmar = await TFModalDialog.confirm(
      context: context,
      title: 'Cancelar demanda',
      message: 'Deseja realmente cancelar esta demanda operacional?',
      confirmLabel: 'Cancelar Demanda',
      cancelLabel: 'Voltar',
      isDestructive: true,
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        final atualizada = _demanda!.copyWith(status: 'Cancelada');
        await _demandaService.atualizarDemanda(atualizada, versaoAnterior: _demanda);
        await _carregarDetalhes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demanda cancelada com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar demanda: $e')),
          );
          setState(() => _isLoading = false);
        }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidência anexada com sucesso!')),
        );
      }
      await _carregarDetalhes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao anexar arquivo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _excluirAnexo(DemandaAnexo anexo) async {
    final confirmar = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir anexo',
      message: 'Excluir permanentemente o anexo "${anexo.fileName}"?',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        await _demandaService.excluirAnexo(anexo);
        await _carregarDetalhes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anexo removido com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir anexo: $e')),
          );
          setState(() => _isLoading = false);
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir a URL do arquivo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir anexo: $e')),
        );
      }
    }
  }

  void _exibirImagemCheia(DemandaAnexo anexo) {
    if (anexo.fileUrl == null) return;
    final colors = context.tfColors;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: TFRadius.borderRadiusMd,
                child: Image.network(anexo.fileUrl!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: colors.surface.withValues(alpha: 0.85),
                child: IconButton(
                  icon: Icon(TFIcons.close, color: colors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: TFLoading(message: 'Carregando detalhes da demanda...')),
      );
    }

    if (_erroMsg.isNotEmpty || _demanda == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              TFPageHeader(
                title: 'Detalhes da Demanda',
                leading: TFIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: TFEmptyState(
                    title: 'Demanda não encontrada',
                    description: _erroMsg.isNotEmpty ? _erroMsg : 'Não foi possível carregar os detalhes desta demanda.',
                    icon: TFIcons.warning,
                    action: TFButton(
                      label: 'Voltar',
                      leadingIcon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final d = _demanda!;
    final situacao = DemandaPrazoHelper.obterSituacao(d.prazo, d.status);
    final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, d.prazo);
    final severityPrazo = DemandaPrazoHelper.obterSeverity(situacao);
    final severityStatus = DemandaStatusMapper.mapSeverity(d.status);

    final antesAnexos = _anexos.where((a) => a.tipo == 'evidencia_antes').toList();
    final depoisAnexos = _anexos.where((a) => a.tipo == 'evidencia_depois').toList();
    final geraisAnexos = _anexos.where((a) => a.tipo == 'anexo_geral').toList();

    final isAtiva = d.status != 'Concluída' && d.status != 'Cancelada';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Page Header Oficial TFDS com Ações
            TFPageHeader(
              title: 'Detalhes da Demanda',
              subtitle: 'Identificação #${d.id.length > 8 ? d.id.substring(0, 8) : d.id}',
              leading: TFIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Voltar',
                onPressed: () => Navigator.pop(context, true),
              ),
              primaryAction: TFButton(
                label: 'Editar',
                leadingIcon: TFIcons.edit,
                variant: TFButtonVariant.secondary,
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
              secondaryActions: isAtiva
                  ? [
                      TFButton(
                        label: 'Concluir',
                        leadingIcon: TFIcons.save,
                        variant: TFButtonVariant.primary,
                        onPressed: _concluirRapido,
                      ),
                      TFButton(
                        label: 'Cancelar',
                        leadingIcon: TFIcons.close,
                        variant: TFButtonVariant.danger,
                        onPressed: _cancelarDemanda,
                      ),
                    ]
                  : null,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de Status e Prazo Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TFStatusBadge(
                          label: d.status.toUpperCase(),
                          severity: severityStatus,
                        ),
                        TFStatusBadge(
                          label: textoPrazo,
                          severity: severityPrazo,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.md),

                    // Título e Descrição Principal da Demanda
                    TFCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descrição da Demanda',
                            style: typography.caption.copyWith(color: colors.textSecondary),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            d.demanda,
                            style: typography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.md),

                    // Grid de Detalhes e Metadados
                    _buildGridDetalhes(d),
                    SizedBox(height: spacing.md),

                    // Observações (se houver)
                    if (d.observacoes != null && d.observacoes!.trim().isNotEmpty) ...[
                      TFCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observações',
                              style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                            ),
                            SizedBox(height: spacing.sm),
                            Text(
                              d.observacoes!,
                              style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.md),
                    ],

                    // Evidências e Documentos
                    TFCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evidências & Documentos',
                            style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                          ),
                          SizedBox(height: spacing.xxs),
                          Text(
                            'Galeria visual antes/depois e documentação anexada',
                            style: typography.caption.copyWith(color: colors.textSecondary),
                          ),
                          SizedBox(height: spacing.md),
                          _buildGaleriaEvidencias('antes', 'Evidências ANTES (Situação inicial)', antesAnexos),
                          Divider(color: colors.borderDefault, height: spacing.lg),
                          _buildGaleriaEvidencias('depois', 'Evidências DEPOIS (Pós-execução)', depoisAnexos),
                          Divider(color: colors.borderDefault, height: spacing.lg),
                          _buildDocumentosGerais(geraisAnexos),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.md),

                    // Linha do tempo / Histórico
                    TFCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico & Acompanhamento',
                            style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                          ),
                          SizedBox(height: spacing.xxs),
                          Text(
                            'Trilha de auditoria e registros de alterações',
                            style: typography.caption.copyWith(color: colors.textSecondary),
                          ),
                          SizedBox(height: spacing.md),
                          _buildLinhaDoTempo(),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDetalhes(Demanda d) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    Widget itemDetalhe(String label, String valor, {Color? valorColor, bool isBold = false}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.xxs),
            Text(
              valor,
              style: typography.bodyMedium.copyWith(
                color: valorColor ?? colors.textPrimary,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < TFBreakpoints.sm;

        final col1 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemDetalhe('Origem', d.origem),
            itemDetalhe('Local', d.local),
            itemDetalhe('Sala / Sublocal', d.sala?.isNotEmpty == true ? d.sala! : '-'),
            itemDetalhe('Responsável', d.responsavel),
          ],
        );

        final col2 = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemDetalhe(
              'Prioridade',
              d.prioridade,
              valorColor: d.prioridade == 'Crítica' ? colors.danger : null,
              isBold: d.prioridade == 'Crítica',
            ),
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

        return TFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informações e Metadados',
                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.md),
              isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [col1, col2, col3],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: col1),
                        SizedBox(width: spacing.md),
                        Expanded(child: col2),
                        SizedBox(width: spacing.md),
                        Expanded(child: col3),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGaleriaEvidencias(String tipo, String titulo, List<DemandaAnexo> fotos) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: typography.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            if (_isUploading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
              )
            else
              TFButton(
                label: 'Adicionar foto',
                leadingIcon: TFIcons.add,
                variant: TFButtonVariant.secondary,
                size: TFButtonSize.small,
                onPressed: () => _uploadRapidoAnexo(tipo),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (fotos.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Text(
              'Nenhuma evidência anexada.',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              separatorBuilder: (_, __) => SizedBox(width: spacing.sm),
              itemBuilder: (context, index) {
                final anexo = fotos[index];
                final isImage = anexo.fileName.endsWith('.jpg') || anexo.fileName.endsWith('.png') || anexo.fileName.endsWith('.webp');

                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    borderRadius: TFRadius.borderRadiusSm,
                    border: Border.all(color: colors.borderDefault),
                    color: colors.surfaceSecondary,
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
                          borderRadius: TFRadius.borderRadiusSm,
                          child: isImage && anexo.fileUrl != null
                              ? Image.network(anexo.fileUrl!, width: 110, height: 110, fit: BoxFit.cover)
                              : Center(child: Icon(Icons.insert_drive_file_outlined, size: 36, color: colors.primary)),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: colors.danger.withValues(alpha: 0.9),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(TFIcons.close, size: 12, color: Colors.white),
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
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documentos e Anexos Gerais',
              style: typography.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            if (!_isUploading)
              TFButton(
                label: 'Anexar arquivo',
                leadingIcon: TFIcons.add,
                variant: TFButtonVariant.secondary,
                size: TFButtonSize.small,
                onPressed: () => _uploadRapidoAnexo('geral'),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (documentos.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Text(
              'Nenhum documento anexado.',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documentos.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
            itemBuilder: (context, index) {
              final doc = documentos[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                decoration: BoxDecoration(
                  borderRadius: TFRadius.borderRadiusSm,
                  border: Border.all(color: colors.borderDefault),
                  color: colors.surfaceSecondary,
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined, color: colors.primary, size: 20),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.fileName,
                            style: typography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${(doc.fileSize ?? 0) ~/ 1024} KB • ${doc.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt!) : ''}',
                            style: typography.caption.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TFIconButton(
                      icon: Icons.open_in_new_rounded,
                      tooltip: 'Abrir Arquivo',
                      onPressed: () => _abrirUrlAnexo(doc),
                    ),
                    TFIconButton(
                      icon: TFIcons.delete,
                      tooltip: 'Excluir Anexo',
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
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_historico.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs),
        child: Text(
          'Nenhum registro de histórico.',
          style: typography.caption.copyWith(color: colors.textSecondary),
        ),
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (index != _historico.length - 1)
                  Container(
                    width: 2,
                    height: 48,
                    color: colors.borderDefault,
                  ),
              ],
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dataStr,
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: spacing.xxs),
                    Text(
                      h.observacao ?? 'Alteração realizada',
                      style: typography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (h.campo != null) ...[
                      SizedBox(height: spacing.xxs),
                      Text(
                        'Modificado: ${h.campo} (${h.valorAnterior ?? '-'} ➔ ${h.valorNovo ?? '-'})',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
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
