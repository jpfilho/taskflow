import 'package:flutter/foundation.dart';
import 'prompt_version.dart';

@immutable
class AiAssistantConfig {
  final String id;
  final String name;
  final String description;
  final String role;
  final String objective;
  final String toneOfVoice;
  final String businessRules;
  final String avoidRules;
  final String context;
  final String systemPrompt;
  final String modelProvider;
  final String modelName;
  final double temperature;
  final int maxTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PromptVersion> versions;

  const AiAssistantConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.role,
    required this.objective,
    required this.toneOfVoice,
    required this.businessRules,
    required this.avoidRules,
    required this.context,
    required this.systemPrompt,
    required this.modelProvider,
    required this.modelName,
    required this.temperature,
    required this.maxTokens,
    required this.createdAt,
    required this.updatedAt,
    required this.versions,
  });

  AiAssistantConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? role,
    String? objective,
    String? toneOfVoice,
    String? businessRules,
    String? avoidRules,
    String? context,
    String? systemPrompt,
    String? modelProvider,
    String? modelName,
    double? temperature,
    int? maxTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PromptVersion>? versions,
  }) {
    return AiAssistantConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      role: role ?? this.role,
      objective: objective ?? this.objective,
      toneOfVoice: toneOfVoice ?? this.toneOfVoice,
      businessRules: businessRules ?? this.businessRules,
      avoidRules: avoidRules ?? this.avoidRules,
      context: context ?? this.context,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelProvider: modelProvider ?? this.modelProvider,
      modelName: modelName ?? this.modelName,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      versions: versions ?? this.versions,
    );
  }

  factory AiAssistantConfig.fromJson(Map<String, dynamic> json) {
    var versionsJson = json['versions'] as List? ?? [];
    List<PromptVersion> versionsList = versionsJson
        .map((v) => PromptVersion.fromJson(v as Map<String, dynamic>))
        .toList();

    return AiAssistantConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      role: json['role'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      toneOfVoice: json['toneOfVoice'] as String? ?? '',
      businessRules: json['businessRules'] as String? ?? '',
      avoidRules: json['avoidRules'] as String? ?? '',
      context: json['context'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      modelProvider: json['modelProvider'] as String? ?? 'nvidia',
      modelName: json['modelName'] as String? ?? 'qwen/qwen3.5-122b-a10b',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.3,
      maxTokens: json['maxTokens'] as int? ?? 2048,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      versions: versionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'role': role,
      'objective': objective,
      'toneOfVoice': toneOfVoice,
      'businessRules': businessRules,
      'avoidRules': avoidRules,
      'context': context,
      'systemPrompt': systemPrompt,
      'modelProvider': modelProvider,
      'modelName': modelName,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'versions': versions.map((v) => v.toJson()).toList(),
    };
  }
}
