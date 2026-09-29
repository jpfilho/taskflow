import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/executor.dart';
import '../models/divisao.dart';
import '../models/segmento.dart';
import '../models/empresa.dart';
import '../models/funcao.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import '../services/empresa_service.dart';
import '../services/funcao_service.dart';

class ExecutorFormDialog extends StatefulWidget {
  final Executor? executor;

  const ExecutorFormDialog({
    super.key,
    this.executor,
  });

  @override
  State<ExecutorFormDialog> createState() => _ExecutorFormDialogState();
}

class _ExecutorFormDialogState extends State<ExecutorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _nomeCompletoController;
  late TextEditingController _matriculaController;
  late TextEditingController _loginController;
  late TextEditingController _ramalController;
  late TextEditingController _telefoneController;
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();
  final EmpresaService _empresaService = EmpresaService();
  final FuncaoService _funcaoService = FuncaoService();
  List<Divisao> _divisoes = [];
  List<Segmento> _segmentos = [];
  List<Empresa> _empresas = [];
  List<Funcao> _funcoes = [];
  Divisao? _selectedDivisao;
  Set<String> _selectedSegmentoIds = {};
  Empresa? _selectedEmpresa;
  Funcao? _selectedFuncao;
  bool _ativo = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.executor?.nome ?? '',
    );
    _nomeCompletoController = TextEditingController(
      text: widget.executor?.nomeCompleto ?? '',
    );
    _matriculaController = TextEditingController(
      text: widget.executor?.matricula ?? '',
    );
    _loginController = TextEditingController(
      text: widget.executor?.login ?? '',
    );
    _ramalController = TextEditingController(
      text: widget.executor?.ramal ?? '',
    );
    _telefoneController = TextEditingController(
      text: widget.executor?.telefone ?? '',
    );
    _ativo = widget.executor?.ativo ?? true;
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    try {
      final results = await Future.wait([
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
        _empresaService.getAllEmpresas(),
        _funcaoService.getAllFuncoes(),
      ]);

      if (mounted) {
        final divisoes = results[0] as List<Divisao>;
        final segmentos = results[1] as List<Segmento>;
        final empresas = results[2] as List<Empresa>;
        final funcoes = results[3] as List<Funcao>;

        setState(() {
          _divisoes = divisoes;
          _segmentos = segmentos;
          _empresas = empresas;
          _funcoes = funcoes;

          if (widget.executor?.divisaoId != null) {
            _selectedDivisao = divisoes.cast<Divisao?>().firstWhere(
              (d) => d?.id == widget.executor!.divisaoId,
              orElse: () => null,
            );
          }

          if (widget.executor?.empresaId != null) {
            _selectedEmpresa = empresas.cast<Empresa?>().firstWhere(
              (e) => e?.id == widget.executor!.empresaId,
              orElse: () => null,
            );
          }

          if (widget.executor?.funcaoId != null) {
            _selectedFuncao = funcoes.cast<Funcao?>().firstWhere(
              (f) => f?.id == widget.executor!.funcaoId,
              orElse: () => null,
            );
          }

          if (widget.executor != null && widget.executor!.segmentoIds.isNotEmpty) {
            _selectedSegmentoIds = widget.executor!.segmentoIds.toSet();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeCompletoController.dispose();
    _matriculaController.dispose();
    _loginController.dispose();
    _ramalController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final executor = Executor(
        id: widget.executor?.id ?? '',
        nome: _nomeController.text.trim(),
        nomeCompleto: _nomeCompletoController.text.trim().isEmpty
            ? null
            : _nomeCompletoController.text.trim(),
        matricula: _matriculaController.text.trim().isEmpty
            ? null
            : _matriculaController.text.trim(),
        login: _loginController.text.trim().isEmpty
            ? null
            : _loginController.text.trim(),
        ramal: _ramalController.text.trim().isEmpty
            ? null
            : _ramalController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        empresaId: _selectedEmpresa?.id,
        funcaoId: _selectedFuncao?.id,
        divisaoId: _selectedDivisao?.id,
        segmentoIds: _selectedSegmentoIds.toList(),
        segmentos: _segmentos
            .where((s) => _selectedSegmentoIds.contains(s.id))
            .map((s) => s.segmento)
            .toList(),
        ativo: _ativo,
      );

      Navigator.of(context).pop(executor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.executor != null;
    final spacing = context.tfSpacing;
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return TFFormDialog(
      title: isEditing ? 'Editar Executor' : 'Novo Executor',
      subtitle: 'Cadastro e manutenção de colaboradores operacionais.',
      saveLabel: isEditing ? 'Salvar Alterações' : 'Criar Executor',
      isSaving: _isSaving,
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TFTextField(
              controller: _nomeController,
              label: 'Nome Operacional',
              hint: 'Ex: Carlos Silva',
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _nomeCompletoController,
              label: 'Nome Completo',
              hint: 'Nome civil completo do colaborador',
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _matriculaController,
              label: 'Matrícula',
              hint: 'Ex: 123456',
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _loginController,
              label: 'Login de Rede / Usuário',
              hint: 'Ex: csilva',
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _ramalController,
              label: 'Ramal',
              hint: 'Ex: 4022',
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: spacing.md),
            TFTextField(
              controller: _telefoneController,
              label: 'Telefone / Celular',
              hint: 'Ex: (11) 98765-4321',
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Empresa?>(
              label: 'Empresa',
              value: _selectedEmpresa,
              items: [null, ..._empresas],
              displayText: (empresa) => empresa?.empresa ?? 'Nenhuma',
              onChanged: (value) => setState(() => _selectedEmpresa = value),
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Funcao?>(
              label: 'Função',
              value: _selectedFuncao,
              items: [null, ..._funcoes],
              displayText: (funcao) => funcao?.funcao ?? 'Nenhuma',
              onChanged: (value) => setState(() => _selectedFuncao = value),
            ),
            SizedBox(height: spacing.md),
            TFDropdown<Divisao?>(
              label: 'Divisão',
              value: _selectedDivisao,
              items: [null, ..._divisoes],
              displayText: (divisao) => divisao?.divisao ?? 'Nenhuma',
              onChanged: (value) => setState(() => _selectedDivisao = value),
            ),
            SizedBox(height: spacing.md),
            TFCard(
              child: Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.symmetric(horizontal: spacing.sm),
                  title: Text(
                    'Segmentos de Atuação',
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _selectedSegmentoIds.isEmpty
                        ? 'Nenhum segmento selecionado'
                        : '${_selectedSegmentoIds.length} segmento(s) vinculado(s)',
                    style: typography.bodySmall.copyWith(
                      color: _selectedSegmentoIds.isEmpty
                          ? colors.textSecondary
                          : colors.primary,
                    ),
                  ),
                  children: [
                    ..._segmentos.map((segmento) {
                      final isSelected = _selectedSegmentoIds.contains(segmento.id);
                      return CheckboxListTile(
                        title: Text(
                          segmento.segmento,
                          style: typography.bodyMedium,
                        ),
                        value: isSelected,
                        activeColor: colors.primary,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSegmentoIds.add(segmento.id);
                            } else {
                              _selectedSegmentoIds.remove(segmento.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),
            TFSwitch(
              value: _ativo,
              label: 'Executor Ativo',
              description: 'Desative caso o executor esteja desligado ou afastado',
              onChanged: (val) => setState(() => _ativo = val),
            ),
          ],
        ),
      ),
    );
  }
}
