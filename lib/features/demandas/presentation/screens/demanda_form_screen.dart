import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_dropdown.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../../../models/executor.dart';
import '../../../../models/local.dart';
import '../../../../services/executor_service.dart';
import '../../../../services/local_service.dart';
import '../../data/models/demanda_anexo_model.dart';
import '../../data/models/demanda_model.dart';
import '../../data/services/demanda_service.dart';

class DemandaFormScreen extends StatefulWidget {
  final Demanda? demandaExistente;

  const DemandaFormScreen({super.key, this.demandaExistente});

  @override
  State<DemandaFormScreen> createState() => _DemandaFormScreenState();
}

class _DemandaFormScreenState extends State<DemandaFormScreen> {
  final DemandaService _demandaService = DemandaService();
  final LocalService _localService = LocalService();
  final ExecutorService _executorService = ExecutorService();

  final _formKey = GlobalKey<FormState>();

  // Controladores e estado dos campos
  String? _origem;
  String? _local;
  late final TextEditingController _salaController;
  late final TextEditingController _demandaController;
  late final TextEditingController _notaController;
  late final TextEditingController _ordemController;
  late final TextEditingController _siController;
  late final TextEditingController _atController;
  String? _responsavel;
  DateTime? _prazo;
  String _status = 'Aberta';
  String _prioridade = 'Normal';
  late final TextEditingController _observacoesController;

  bool _isSaving = false;

  // Listas de dados auxiliares do sistema
  List<Local> _locaisDoSistema = [];
  List<Executor> _executoresDoSistema = [];

  // Listas de arquivos selecionados temporariamente para upload após salvar
  final List<PlatformFile> _novosAnexosAntes = [];
  final List<PlatformFile> _novosAnexosDepois = [];
  final List<PlatformFile> _novosAnexosGerais = [];

  // Anexos existentes (em modo de edição)
  List<DemandaAnexo> _anexosExistentes = [];

  final List<String> _origens = [
    'Inspeção',
    'Reunião',
    'Operação',
    'Manutenção',
    'Segurança',
    'Auditoria',
    'Cliente interno',
    'Emergência',
    'Outro',
  ];

  final List<String> _statusOpcoes = [
    'Aberta',
    'Em análise',
    'Programada',
    'Em execução',
    'Aguardando terceiros',
    'Aguardando material',
    'Concluída',
    'Cancelada',
    'Suspensa',
  ];

  final List<String> _prioridadesOpcoes = [
    'Baixa',
    'Normal',
    'Alta',
    'Crítica',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.demandaExistente;
    _origem = d?.origem;
    _local = d?.local;
    _salaController = TextEditingController(text: d?.sala ?? '');
    _demandaController = TextEditingController(text: d?.demanda ?? '');
    _notaController = TextEditingController(text: d?.nota ?? '');
    _ordemController = TextEditingController(text: d?.ordem ?? '');
    _siController = TextEditingController(text: d?.si ?? '');
    _atController = TextEditingController(text: d?.at ?? '');
    _responsavel = d?.responsavel;
    _prazo = d?.prazo;
    _status = d?.status ?? 'Aberta';
    _prioridade = d?.prioridade ?? 'Normal';
    _observacoesController = TextEditingController(text: d?.observacoes ?? '');

    _carregarDropdownsEPrefills();
  }

  @override
  void dispose() {
    _salaController.dispose();
    _demandaController.dispose();
    _notaController.dispose();
    _ordemController.dispose();
    _siController.dispose();
    _atController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarDropdownsEPrefills() async {
    try {
      final results = await Future.wait([
        _localService.getAllLocais(),
        _executorService.getAllExecutores(),
      ]);

      if (mounted) {
        setState(() {
          _locaisDoSistema = results[0] as List<Local>;
          _executoresDoSistema = results[1] as List<Executor>;
        });
      }

      if (widget.demandaExistente != null) {
        try {
          final anexos = await _demandaService.listarAnexos(widget.demandaExistente!.id);
          if (mounted) {
            setState(() {
              _anexosExistentes = anexos;
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _selecionarArquivos(String tipo) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (tipo == 'antes') {
            _novosAnexosAntes.addAll(result.files);
          } else if (tipo == 'depois') {
            _novosAnexosDepois.addAll(result.files);
          } else {
            _novosAnexosGerais.addAll(result.files);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivos: $e')),
        );
      }
    }
  }

  void _removerNovoAnexo(PlatformFile file, String tipo) {
    setState(() {
      if (tipo == 'antes') {
        _novosAnexosAntes.remove(file);
      } else if (tipo == 'depois') {
        _novosAnexosDepois.remove(file);
      } else {
        _novosAnexosGerais.remove(file);
      }
    });
  }

  Future<void> _excluirAnexoExistente(DemandaAnexo anexo) async {
    final confirmar = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir evidência/anexo',
      message: 'Deseja realmente excluir permanentemente "${anexo.fileName}"?',
      confirmLabel: 'Excluir',
      cancelLabel: 'Cancelar',
      isDestructive: true,
    );

    if (confirmar == true) {
      setState(() => _isSaving = true);
      try {
        await _demandaService.excluirAnexo(anexo);
        final anexos = await _demandaService.listarAnexos(widget.demandaExistente!.id);
        if (mounted) {
          setState(() {
            _anexosExistentes = anexos;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anexo excluído com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir anexo: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_prazo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe a data limite (prazo).')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final d = Demanda(
        id: widget.demandaExistente?.id ?? '',
        origem: _origem!,
        local: _local!,
        sala: _salaController.text.trim().isEmpty ? null : _salaController.text.trim(),
        demanda: _demandaController.text.trim(),
        nota: _notaController.text.trim().isEmpty ? null : _notaController.text.trim(),
        ordem: _ordemController.text.trim().isEmpty ? null : _ordemController.text.trim(),
        si: _siController.text.trim().isEmpty ? null : _siController.text.trim(),
        at: _atController.text.trim().isEmpty ? null : _atController.text.trim(),
        responsavel: _responsavel!,
        prazo: _prazo!,
        status: _status,
        prioridade: _prioridade,
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      );

      Demanda demandaSalva;
      if (widget.demandaExistente == null) {
        demandaSalva = await _demandaService.criarDemanda(d);
      } else {
        demandaSalva = await _demandaService.atualizarDemanda(d, versaoAnterior: widget.demandaExistente);
      }

      await _uploadNovosAnexos(demandaSalva.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demanda salva com sucesso!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar demanda: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _uploadNovosAnexos(String demandaId) async {
    Future<void> uploadGrupo(List<PlatformFile> lista, String tipo) async {
      for (final file in lista) {
        if (file.bytes != null) {
          await _demandaService.uploadAnexo(
            demandaId: demandaId,
            tipo: tipo,
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: file.extension,
          );
        }
      }
    }

    await uploadGrupo(_novosAnexosAntes, 'evidencia_antes');
    await uploadGrupo(_novosAnexosDepois, 'evidencia_depois');
    await uploadGrupo(_novosAnexosGerais, 'anexo_geral');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final isDesktop = TFBreakpoints.isDesktop(context);

    // Lista de locais
    final List<String> localOptions = _locaisDoSistema.isNotEmpty
        ? _locaisDoSistema.map((l) => l.local).toList()
        : [_local ?? 'Principal'];
    if (_local != null && !localOptions.contains(_local)) {
      localOptions.insert(0, _local!);
    }

    // Lista de executores
    final List<String> executorOptions = _executoresDoSistema.isNotEmpty
        ? _executoresDoSistema.map((e) => e.nome).toList()
        : [_responsavel ?? 'Geral'];
    if (_responsavel != null && !executorOptions.contains(_responsavel)) {
      executorOptions.insert(0, _responsavel!);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Page Header Oficial TFDS
            TFPageHeader(
              title: widget.demandaExistente == null ? 'Nova Demanda' : 'Editar Demanda',
              subtitle: 'Preencha as informações da demanda e evidências operacionais.',
              leading: TFIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Voltar',
                onPressed: () => Navigator.pop(context),
              ),
              primaryAction: TFButton(
                label: 'Salvar Demanda',
                leadingIcon: TFIcons.save,
                loading: _isSaving,
                onPressed: _salvar,
              ),
            ),

            Expanded(
              child: _isSaving
                  ? const Center(
                      child: TFLoading(message: 'Salvando demanda e enviando evidências...'),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(spacing.md),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Bloco de Dados Principais
                            TFCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dados da Demanda',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.xxs),
                                  Text(
                                    'Identificação, localidade, responsabilidade e prazos',
                                    style: typography.caption.copyWith(color: colors.textSecondary),
                                  ),
                                  SizedBox(height: spacing.md),
                                  Wrap(
                                    spacing: spacing.md,
                                    runSpacing: spacing.md,
                                    children: [
                                      // Origem
                                      SizedBox(
                                        width: isDesktop ? 260 : double.infinity,
                                        child: TFDropdown<String>(
                                          label: 'Origem',
                                          isRequired: true,
                                          items: _origens,
                                          value: _origem,
                                          displayText: (val) => val,
                                          hint: 'Selecione a origem',
                                          onChanged: (val) => setState(() => _origem = val),
                                          validator: (val) => val == null ? 'Campo obrigatório' : null,
                                        ),
                                      ),

                                      // Local
                                      SizedBox(
                                        width: isDesktop ? 260 : double.infinity,
                                        child: TFDropdown<String>(
                                          label: 'Local',
                                          isRequired: true,
                                          items: localOptions,
                                          value: _local,
                                          displayText: (val) => val,
                                          hint: 'Selecione o local',
                                          onChanged: (val) => setState(() => _local = val),
                                          validator: (val) => val == null ? 'Campo obrigatório' : null,
                                        ),
                                      ),

                                      // Sala
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFTextField(
                                          label: 'Sala / Sublocal',
                                          controller: _salaController,
                                          hint: 'Ex: Sala 04',
                                        ),
                                      ),

                                      // Responsável
                                      SizedBox(
                                        width: isDesktop ? 260 : double.infinity,
                                        child: TFDropdown<String>(
                                          label: 'Responsável',
                                          isRequired: true,
                                          items: executorOptions,
                                          value: _responsavel,
                                          displayText: (val) => val,
                                          hint: 'Selecione o responsável',
                                          onChanged: (val) => setState(() => _responsavel = val),
                                          validator: (val) => val == null ? 'Campo obrigatório' : null,
                                        ),
                                      ),

                                      // Prazo (Date Selector integrado)
                                      SizedBox(
                                        width: isDesktop ? 200 : double.infinity,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Prazo Limite *',
                                              style: typography.labelSmall.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: spacing.xs),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: _prazo ?? DateTime.now(),
                                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                                );
                                                if (picked != null) {
                                                  setState(() => _prazo = picked);
                                                }
                                              },
                                              borderRadius: TFRadius.borderRadiusSm,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: spacing.md,
                                                  vertical: spacing.sm + 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.surface,
                                                  borderRadius: TFRadius.borderRadiusSm,
                                                  border: Border.all(
                                                    color: _prazo == null && _isSaving
                                                        ? colors.danger
                                                        : colors.borderDefault,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(TFIcons.calendar, size: 16, color: colors.textSecondary),
                                                    SizedBox(width: spacing.xs),
                                                    Expanded(
                                                      child: Text(
                                                        _prazo == null
                                                            ? 'Selecionar data'
                                                            : "${_prazo!.day.toString().padLeft(2, '0')}/${_prazo!.month.toString().padLeft(2, '0')}/${_prazo!.year}",
                                                        style: typography.bodyMedium.copyWith(
                                                          color: _prazo == null ? colors.textDisabled : colors.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Status
                                      SizedBox(
                                        width: isDesktop ? 200 : double.infinity,
                                        child: TFDropdown<String>(
                                          label: 'Status',
                                          isRequired: true,
                                          items: _statusOpcoes,
                                          value: _status,
                                          displayText: (val) => val,
                                          onChanged: (val) => setState(() => _status = val ?? 'Aberta'),
                                        ),
                                      ),

                                      // Prioridade
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFDropdown<String>(
                                          label: 'Prioridade',
                                          isRequired: true,
                                          items: _prioridadesOpcoes,
                                          value: _prioridade,
                                          displayText: (val) => val,
                                          onChanged: (val) => setState(() => _prioridade = val ?? 'Normal'),
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: spacing.md),

                                  // Descrição da Demanda
                                  TFTextField(
                                    label: 'Demanda (Descrição da Atividade)',
                                    required: true,
                                    controller: _demandaController,
                                    hint: 'Descreva detalhadamente o escopo e o que precisa ser executado...',
                                    maxLines: 4,
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Campo obrigatório' : null,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.md),

                            // 2. Bloco de Integração SAP
                            TFCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Associações SAP (Opcional)',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.xxs),
                                  Text(
                                    'Vínculo com notas, ordens, solicitações e autorizações',
                                    style: typography.caption.copyWith(color: colors.textSecondary),
                                  ),
                                  SizedBox(height: spacing.md),
                                  Wrap(
                                    spacing: spacing.md,
                                    runSpacing: spacing.md,
                                    children: [
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFTextField(
                                          label: 'Nota SAP',
                                          controller: _notaController,
                                          hint: 'Ex: 100234567',
                                        ),
                                      ),
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFTextField(
                                          label: 'Ordem SAP',
                                          controller: _ordemController,
                                          hint: 'Ex: 400123456',
                                        ),
                                      ),
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFTextField(
                                          label: 'SI',
                                          controller: _siController,
                                          hint: '00000000/00A',
                                          inputFormatters: [_SIMaskTextInputFormatter()],
                                        ),
                                      ),
                                      SizedBox(
                                        width: isDesktop ? 180 : double.infinity,
                                        child: TFTextField(
                                          label: 'AT',
                                          controller: _atController,
                                          hint: 'Ex: AT-01',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.md),

                            // 3. Observações
                            TFCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Observações Adicionais',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.sm),
                                  TFTextField(
                                    controller: _observacoesController,
                                    hint: 'Comentários adicionais, orientações técnicas ou notas gerais...',
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.md),

                            // 4. Evidências & Anexos
                            TFCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Evidências & Anexos',
                                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                                  ),
                                  SizedBox(height: spacing.xxs),
                                  Text(
                                    'Fotos antes/depois da execução e arquivos técnicos de suporte',
                                    style: typography.caption.copyWith(color: colors.textSecondary),
                                  ),
                                  SizedBox(height: spacing.md),
                                  _buildSecaoAnexos('antes', 'Evidências ANTES (Situação inicial)', _novosAnexosAntes),
                                  Divider(color: colors.borderDefault, height: spacing.lg),
                                  _buildSecaoAnexos('depois', 'Evidências DEPOIS (Pós-execução)', _novosAnexosDepois),
                                  Divider(color: colors.borderDefault, height: spacing.lg),
                                  _buildSecaoAnexos('geral', 'Documentos / Anexos Gerais', _novosAnexosGerais),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.xl),

                            // Botão Salvar inferior
                            TFButton(
                              label: 'SALVAR DEMANDA',
                              leadingIcon: TFIcons.save,
                              size: TFButtonSize.large,
                              loading: _isSaving,
                              fullWidth: true,
                              onPressed: _salvar,
                            ),
                            SizedBox(height: spacing.lg),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoAnexos(String tipo, String titulo, List<PlatformFile> novosAnexos) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    final existentes = _anexosExistentes
        .where((a) => a.tipo == (tipo == 'antes' ? 'evidencia_antes' : tipo == 'depois' ? 'evidencia_depois' : 'anexo_geral'))
        .toList();

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
            TFButton(
              label: 'Anexar',
              leadingIcon: TFIcons.add,
              variant: TFButtonVariant.secondary,
              size: TFButtonSize.small,
              onPressed: () => _selecionarArquivos(tipo),
            ),
          ],
        ),

        if (existentes.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          Text(
            'Arquivos salvos:',
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.xxs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: existentes.map((anexo) {
              final isImage = anexo.fileName.endsWith('.jpg') || anexo.fileName.endsWith('.png') || anexo.fileName.endsWith('.webp');
              return Chip(
                backgroundColor: colors.surfaceSecondary,
                side: BorderSide(color: colors.borderDefault),
                avatar: isImage && anexo.fileUrl != null
                    ? ClipRRect(
                        borderRadius: TFRadius.borderRadiusXs,
                        child: Image.network(anexo.fileUrl!, width: 20, height: 20, fit: BoxFit.cover),
                      )
                    : Icon(Icons.insert_drive_file_outlined, size: 16, color: colors.primary),
                label: Text(
                  anexo.fileName,
                  style: typography.caption.copyWith(color: colors.textPrimary),
                ),
                deleteIcon: const Icon(TFIcons.close, size: 14),
                onDeleted: () => _excluirAnexoExistente(anexo),
              );
            }).toList(),
          ),
        ],

        if (novosAnexos.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          Text(
            'Novos selecionados (serão enviados ao salvar):',
            style: typography.caption.copyWith(color: colors.info, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: spacing.xxs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: novosAnexos.map((file) {
              final isImage = file.name.endsWith('.jpg') || file.name.endsWith('.png') || file.name.endsWith('.webp');
              return Chip(
                backgroundColor: colors.infoBackground,
                side: BorderSide(color: colors.info.withValues(alpha: 0.4)),
                avatar: file.bytes != null && isImage
                    ? ClipRRect(
                        borderRadius: TFRadius.borderRadiusXs,
                        child: Image.memory(file.bytes!, width: 20, height: 20, fit: BoxFit.cover),
                      )
                    : Icon(Icons.insert_drive_file_outlined, size: 16, color: colors.info),
                label: Text(
                  file.name,
                  style: typography.caption.copyWith(color: colors.textPrimary),
                ),
                deleteIcon: const Icon(TFIcons.close, size: 14),
                onDeleted: () => _removerNovoAnexo(file, tipo),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _SIMaskTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.toUpperCase();
    String newText = '';
    text = text.replaceAll(RegExp(r'[^0-9A-Z]'), '');

    int index = 0;
    for (int i = 0; i < text.length; i++) {
      if (index < 8) {
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 8) {
        newText += '/';
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 9) {
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 10) {
        if (RegExp(r'[A-Z]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      }
    }

    if (newText.length > 12) {
      newText = newText.substring(0, 12);
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
