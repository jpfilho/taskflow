import 'package:flutter/material.dart';
import '../../domain/models/llm_model_config.dart';

class ModelSelector extends StatelessWidget {
  final String selectedModelName;
  final ValueChanged<String> onModelChanged;

  const ModelSelector({
    super.key,
    required this.selectedModelName,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modelo LLM (NVIDIA)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: dark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? Colors.grey[800]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedModelName,
              isExpanded: true,
              dropdownColor: dark ? Colors.grey[950] : Colors.white,
              icon: Icon(
                Icons.arrow_drop_down,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
              items: availableNvidiaModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model.name,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        model.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  onModelChanged(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
