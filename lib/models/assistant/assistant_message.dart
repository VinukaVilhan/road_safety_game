enum AssistantMessageRole { user, assistant }

/// One turn in the assistant chat transcript.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.at,
    this.hasUserImage = false,
    this.userModelText,
    this.userImageBase64,
    this.userImageMimeType,
  });

  final AssistantMessageRole role;
  final String text;
  final DateTime at;

  /// User message included a road-sign / scene photo sent to the model.
  final bool hasUserImage;

  /// Text sent to Gemini for this user turn when it differs from [text] (e.g. image-only sends).
  final String? userModelText;

  /// PNG/JPEG bytes for in-chat preview (base64), optional for legacy rows.
  final String? userImageBase64;

  final String? userImageMimeType;

  AssistantMessage copyWith({
    AssistantMessageRole? role,
    String? text,
    DateTime? at,
    bool? hasUserImage,
    String? userModelText,
    String? userImageBase64,
    String? userImageMimeType,
  }) {
    return AssistantMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      at: at ?? this.at,
      hasUserImage: hasUserImage ?? this.hasUserImage,
      userModelText: userModelText ?? this.userModelText,
      userImageBase64: userImageBase64 ?? this.userImageBase64,
      userImageMimeType: userImageMimeType ?? this.userImageMimeType,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        'hasUserImage': hasUserImage,
        if (userModelText != null) 'userModelText': userModelText,
        if (userImageBase64 != null) 'userImageBase64': userImageBase64,
        if (userImageMimeType != null) 'userImageMimeType': userImageMimeType,
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
      userImageBase64: json['userImageBase64'] as String?,
      userImageMimeType: json['userImageMimeType'] as String?,
    );
  }
}
