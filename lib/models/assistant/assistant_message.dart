enum AssistantMessageRole { user, assistant }

/// One turn in the assistant chat transcript.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.at,
    this.hasUserImage = false,
    this.userModelText,
  });

  final AssistantMessageRole role;
  final String text;
  final DateTime at;

  /// User message included a road-sign / scene photo sent to the model.
  final bool hasUserImage;

  /// Text sent to Gemini for this user turn when it differs from [text] (e.g. image-only sends).
  final String? userModelText;

  AssistantMessage copyWith({
    AssistantMessageRole? role,
    String? text,
    DateTime? at,
    bool? hasUserImage,
    String? userModelText,
  }) {
    return AssistantMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      at: at ?? this.at,
      hasUserImage: hasUserImage ?? this.hasUserImage,
      userModelText: userModelText ?? this.userModelText,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        'hasUserImage': hasUserImage,
        if (userModelText != null) 'userModelText': userModelText,
      };

  static AssistantMessage fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String? ?? 'assistant';
    final role = AssistantMessageRole.values.firstWhere(
      (e) => e.name == roleName,
      orElse: () => AssistantMessageRole.assistant,
    );
    return AssistantMessage(
      role: role,
      text: json['text'] as String? ?? '',
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      hasUserImage: json['hasUserImage'] as bool? ?? false,
      userModelText: json['userModelText'] as String?,
    );
  }
}
