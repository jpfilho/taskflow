import 'package:flutter/material.dart';
import '../models/divisao.dart';
import '../models/regional.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/segmento_service.dart';
import '../services/divisao_service.dart';
import '../config/supabase_config.dart';

class DivisaoFormDialog extends StatefulWidget {
  final Divisao? divisao;

  const DivisaoFormDialog({
    super.key,
    this.divisao,
  });

  @override
  State<DivisaoFormDialog> createState() => _DivisaoFormDialogState();
}

class _DivisaoFormDialogState extends State<DivisaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _divisaoController;
  final RegionalService _regionalService = RegionalService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Regional> _regionais = [];
  List<Segmento> _segmentos = [];
  Regional? _selectedRegional;
  List<String> _selectedSegmentoIds = [];
  bool _isLoadingRegionais = true;
  bool _isLoadingSegmentos = true;
  final Map<String, TextEditingController> _telegramChatIdControllers = {};

  @override
  void initState() {
    super.initState();
    _divisaoController = TextEditingController(
      text: widget.divisao?.divisao ?? '',
    );
    
    _loadRegionais();
    _loadSegmentos().then((_) {
      if (widget.divisao != null) {
        _loadTelegramChatIds();
      }
    }).catchError((e) {
      print('Erro ao carregar segmentos: $e');
    });
  }
  
  Future<void> _loadTelegramChatIds() async {
    if (widget.divisao == null || widget.divisao!.segmentoIds.isEmpty) {
      return;
    }
    
    try {
      final supabase = SupabaseConfig.client;
      final divisaoId = widget.divisao!.id;
      
      final divisaoCompleta = await DivisaoService().getDivisaoById(divisaoId);
      if (divisaoCompleta == null) {
        return;
      }
      
      for (var segmentoId in widget.divisao!.segmentoIds) {
        final comunidade = await supabase
            .from('comunidades')
            .select('id')
            .eq('regional_id', divisaoCompleta.regionalId)
            .eq('divisao_id', divisaoId)
            .eq('segmento_id', segmentoId)
            .maybeSingle();
        
        if (comunidade != null && comunidade['id'] != null) {
          final telegramCommunity = await supabase
              .from('telegram_communities')
              .select('telegram_chat_id')
              .eq('community_id', comunidade['id'])
              .maybeSingle();
          
          if (telegramCommunity != null && telegramCommunity['telegram_chat_id'] != null) {
            final chatId = telegramCommunity['telegram_chat_id'].toString();
            if (!_telegramChatIdControllers.containsKey(segmentoId)) {
              _telegramChatIdControllers[segmentoId] = TextEditingController();
            }
            _telegramChatIdControllers[segmentoId]!.text = chatId;
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar Chat IDs do Telegram: $e');
    }
  }
  
  TextEditingController _getChatIdController(String segmentoId) {
    if (!_telegramChatIdControllers.containsKey(segmentoId)) {
      _telegramChatIdControllers[segmentoId] = TextEditingController();
    }
    return _telegramChatIdControllers[segmentoId]!;
  }

  @override
  void dispose() {
    _divisaoController.dispose();
    for (var controller in _telegramChatIdControllers.values) {
      controller.dispose();
    }
    _telegramChatIdControllers.clear();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoadingRegionais = true;
    });

    try {
      final regionais = await _regionalService.getAllRegionais();
      
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

        if (widget.divisao != null && widget.divisao!.regionalId.isNotEmpty) {
          try {
            _selectedRegional = regionais.firstWhere(
              (r) => r.id == widget.divisao!.regionalId,
            );
          } catch (e) {
            _selectedRegional = regionais.isNotEmpty ? regionais.first : null;
          }
        } else if (regionais.isNotEmpty) {
          _selectedRegional = regionais.first;
        }
      });
    } catch (e) {
      print('Erro ao carregar regionais: $e');
      setState(() {
        _isLoadingRegionais = false;
      });
    }
  }

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoadingSegmentos = true;
    });

    try {
      final segmentos = await _segmentoService.getAllSegmentos();
      
      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;

        if (widget.divisao != null && widget.divisao!.segmentoIds.isNotEmpty) {
          _selectedSegmentoIds = List<String>.from(widget.divisao!.segmentoIds);
        }
      });
    } catch (e) {
      print('Erro ao carregar segmentos: $e');
      setState(() {
        _isLoadingSegmentos = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedRegional == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma regional'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedSegmentoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos um segmento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final segmentosNomes = _segmentos
        .where((s) => _selectedSegmentoIds.contains(s.id))
        .map((s) => s.segmento)
        .toList();

    final divisao = Divisao(
      id: widget.divisao?.id ?? '',
      divisao: _divisaoController.text.trim(),
      regionalId: _selectedRegional!.id,
      regional: _selectedRegional!.regional,
      segmentoIds: _selectedSegmentoIds,
      segmentos: segmentosNomes,
      createdAt: widget.divisao?.createdAt,
      updatedAt: DateTime.now(),
    );

    final telegramChatIds = <String, String>{};
    for (var segmentoId in _selectedSegmentoIds) {
      final controller = _telegramChatIdControllers[segmentoId];
      if (controller != null) {
        var chatId = controller.text.trim();
        if (chatId.isNotEmpty) {
          chatId = chatId.replaceAll(RegExp(r'[^0-9-]'), '');
          
          if (chatId.isNotEmpty && chatId.startsWith('-') && chatId.length >= 10) {
            telegramChatIds[segmentoId] = chatId;
          }
        }
      }
    }
    
    Navigator.of(context).pop({
      'divisao': divisao,
      'telegram_chat_ids': telegramChatIds.isEmpty ? null : telegramChatIds,
    });
  }

  String _getRegionalDisplayText(Regional regional) {
    return '${regional.regional} - ${regional.divisao} - ${regional.empresa}';
  }

  String _getChatIdHelperText(String segmentoNome) {
    final regionalNome = _selectedRegional?.regional ?? 'Regional';
    final divisaoNome = widget.divisao?.divisao ?? 'Divisão';
    return 'ID do grupo Telegram para $regionalNome - $divisaoNome - $segmentoNome';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.divisao != null;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar Divisão' : 'Nova Divisão',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atualize as informações da divisão e seus segmentos correspondentes.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Divisão e Regional
                      Column(
                        children: [
                          // Campo Divisão
                          _FloatingLabelTextField(
                            label: 'Divisão *',
                            controller: _divisaoController,
                            isDark: isDark,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Campo obrigatório';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Dropdown Regional
                          _FloatingLabelDropdown<Regional>(
                            label: 'Regional *',
                            value: _selectedRegional,
                            items: _regionais,
                            isLoading: _isLoadingRegionais,
                            displayText: (regional) => _getRegionalDisplayText(regional),
                            onChanged: (value) {
                              setState(() {
                                _selectedRegional = value;
                              });
                            },
                            isDark: isDark,
                            validator: (value) {
                              if (value == null) {
                                return 'Selecione uma regional';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Segmentos
                      Text(
                        'Segmentos *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1e293b).withOpacity(0.5) : const Color(0xFFf8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFe2e8f0),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: _isLoadingSegmentos
                            ? const Center(child: CircularProgressIndicator())
                            : _segmentos.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Nenhum segmento disponível',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: _segmentos.map((segmento) {
                                      final isSelected = _selectedSegmentoIds.contains(segmento.id);
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedSegmentoIds.remove(segmento.id);
                                              _telegramChatIdControllers[segmento.id]?.dispose();
                                              _telegramChatIdControllers.remove(segmento.id);
                                            } else {
                                              _selectedSegmentoIds.add(segmento.id);
                                              if (!_telegramChatIdControllers.containsKey(segmento.id)) {
                                                _telegramChatIdControllers[segmento.id] = TextEditingController();
                                              }
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  segmento.segmento,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isSelected
                                                        ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                                                        : (isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
                                                  ),
                                                ),
                                              ),
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedSegmentoIds.add(segmento.id);
                                                      if (!_telegramChatIdControllers.containsKey(segmento.id)) {
                                                        _telegramChatIdControllers[segmento.id] = TextEditingController();
                                                      }
                                                    } else {
                                                      _selectedSegmentoIds.remove(segmento.id);
                                                      _telegramChatIdControllers[segmento.id]?.dispose();
                                                      _telegramChatIdControllers.remove(segmento.id);
                                                    }
                                                  });
                                                },
                                                activeColor: const Color(0xFF3b82f6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ),
                      
                      // Chat IDs do Telegram
                      if (_selectedSegmentoIds.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.send,
                                    size: 20,
                                    color: const Color(0xFF0ea5e9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CHAT ID DO TELEGRAM POR SEGMENTO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ..._selectedSegmentoIds.map((segmentoId) {
                                final segmento = _segmentos.firstWhere((s) => s.id == segmentoId);
                                final controller = _getChatIdController(segmentoId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _FloatingLabelTextField(
                                        label: 'Chat ID para ${segmento.segmento} (opcional)',
                                        controller: controller,
                                        isDark: isDark,
                                        prefixIcon: Icons.alternate_email,
                                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return null;
                                          }
                                          
                                          final chatId = value.trim();
                                          
                                          if (!RegExp(r'^-?\d+$').hasMatch(chatId)) {
                                            return 'Chat ID deve conter apenas números e sinal negativo';
                                          }
                                          
                                          if (!chatId.startsWith('-')) {
                                            return 'Chat ID deve ser um número negativo';
                                          }
                                          
                                          if (chatId.length < 10) {
                                            return 'Chat ID muito curto (mínimo 10 caracteres)';
                                          }
                                          
                                          try {
                                            final num = int.parse(chatId);
                                            if (num >= 0) {
                                              return 'Chat ID deve ser negativo para grupos';
                                            }
                                          } catch (e) {
                                            return 'Chat ID deve ser um número válido';
                                          }
                                          
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          _getChatIdHelperText(segmento.segmento),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? const Color(0xFF64748b) : const Color(0xFF94a3b8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer com botões
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Salvar Alterações' : 'Criar Divisão',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
}

// Widget para campo de texto com label flutuante
class _FloatingLabelTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FloatingLabelTextField({
    required this.label,
    required this.controller,
    required this.isDark,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_FloatingLabelTextField> createState() => _FloatingLabelTextFieldState();
}

class _FloatingLabelTextFieldState extends State<_FloatingLabelTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    final shouldFloat = _isFocused || hasValue;

    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      child: TextFormField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: TextStyle(
          color: widget.isDark ? Colors.white : const Color(0xFF1e293b),
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: shouldFloat
                ? const Color(0xFF3b82f6)
                : (widget.isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
            fontSize: shouldFloat ? 12 : 16,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF3b82f6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelAlignment: FloatingLabelAlignment.start,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: widget.isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                )
              : null,
          filled: true,
          fillColor: widget.prefixIcon != null
              ? (widget.isDark ? const Color(0xFF0f172a).withOpacity(0.3) : const Color(0xFFf8fafc).withOpacity(0.5))
              : Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF3b82f6),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.prefixIcon != null ? 40 : 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// Widget para dropdown com label flutuante
class _FloatingLabelDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final bool isLoading;
  final String Function(T) displayText;
  final void Function(T?) onChanged;
  final bool isDark;
  final String? Function(T?)? validator;

  const _FloatingLabelDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.isLoading,
    required this.displayText,
    required this.onChanged,
    required this.isDark,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final shouldFloat = value != null || isLoading;

    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<T>(
              initialValue: value,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: shouldFloat
                      ? const Color(0xFF3b82f6)
                      : (isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b)),
                  fontSize: shouldFloat ? 12 : 16,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF3b82f6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelAlignment: FloatingLabelAlignment.start,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF3b82f6),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.red,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: Icon(
                  Icons.expand_more,
                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1e293b),
              ),
              isExpanded: true,
              items: isLoading
                  ? null
                  : items.map((item) {
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          displayText(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
              onChanged: isLoading
                  ? null
                  : (T? newValue) {
                      onChanged(newValue);
                      field.didChange(newValue);
                    },
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
