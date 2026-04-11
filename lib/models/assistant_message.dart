enum AssistantMessageRole { user, assistant }

/// One turn in the assistant chat transcript.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.at,
    this.hasUserImage = false,
  });

  final AssistantMessageRole role;
  final String text;
  final DateTime at;

  /// User message included a road-sign / scene photo sent to the model.
  final bool hasUserImage;

  AssistantMessage copyWith({
    AssistantMessageRole? role,
    String? text,
    DateTime? at,
    bool? hasUserImage,
  }) {
    return AssistantMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      at: at ?? this.at,
      hasUserImage: hasUserImage ?? this.hasUserImage,
    );
  }
}
