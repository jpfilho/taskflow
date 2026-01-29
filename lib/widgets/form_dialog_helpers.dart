import 'package:flutter/material.dart';

/// Widget para campo de texto com label flutuante
class FloatingLabelTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final TextCapitalization? textCapitalization;

  const FloatingLabelTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.isDark,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines,
    this.textCapitalization,
  });

  @override
  State<FloatingLabelTextField> createState() => _FloatingLabelTextFieldState();
}

class _FloatingLabelTextFieldState extends State<FloatingLabelTextField> {
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
        maxLines: widget.maxLines,
        textCapitalization: widget.textCapitalization ?? TextCapitalization.none,
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

/// Widget para dropdown com label flutuante
class FloatingLabelDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final bool isLoading;
  final String Function(T) displayText;
  final void Function(T?) onChanged;
  final bool isDark;
  final String? Function(T?)? validator;

  const FloatingLabelDropdown({
    super.key,
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
              value: value,
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
                filled: true,
                fillColor: Colors.transparent,
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
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        Icons.expand_more,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                      ),
              ),
              items: isLoading
                  ? []
                  : items.map((item) {
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          displayText(item),
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1e293b),
                          ),
                        ),
                      );
                    }).toList(),
              onChanged: isLoading ? null : (T? newValue) {
                onChanged(newValue);
                field.didChange(newValue);
              },
              validator: validator,
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
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

/// Widget para seletor de cor
class ColorPickerField extends StatelessWidget {
  final String label;
  final Color color;
  final String colorHex;
  final bool isDark;
  final VoidCallback onTap;
  final IconData icon;
  final String? Function(String?)? validator;

  const ColorPickerField({
    super.key,
    required this.label,
    required this.color,
    required this.colorHex,
    required this.isDark,
    required this.onTap,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3b82f6),
              ),
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              colorHex,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget base para Dialog moderno
class ModernFormDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final VoidCallback? onSave;
  final String saveButtonText;
  final bool isDark;

  const ModernFormDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    required this.onSave,
    required this.saveButtonText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: content,
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
                    onPressed: onSave,
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
                      saveButtonText,
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
