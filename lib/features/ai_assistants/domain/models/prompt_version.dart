import 'package:flutter/foundation.dart';

@immutable
class PromptVersion {
  final String id;
  final String prompt;
  final String changeNote;
  final DateTime createdAt;

  const PromptVersion({
    required this.id,
    required this.prompt,
    required this.changeNote,
    required this.createdAt,
  });

  PromptVersion copyWith({
    String? id,
    String? prompt,
    String? changeNote,
    DateTime? createdAt,
  }) {
    return PromptVersion(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      changeNote: changeNote ?? this.changeNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PromptVersion.fromJson(Map<String, dynamic> json) {
    return PromptVersion(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      changeNote: json['changeNote'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'changeNote': changeNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptVersion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          prompt == other.prompt &&
          changeNote == other.changeNote &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^ prompt.hashCode ^ changeNote.hashCode ^ createdAt.hashCode;
}
