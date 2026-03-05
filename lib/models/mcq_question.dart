/// Model for a single MCQ (multiple choice question) in theory tests.
/// Supports optional image (asset path or URL) for road sign questions.
class McqQuestion {
  final String id;
  final String questionText;
  /// Asset path (e.g. assets/roadsigns/stop.png) or null if text-only.
  final String? imageAssetPath;
  /// Optional network image URL (e.g. for Wikimedia Commons) when asset not used.
  final String? imageUrl;
  final List<String> options;
  /// Index of the correct option (0-based).
  final int correctIndex;

  const McqQuestion({
    required this.id,
    required this.questionText,
    this.imageAssetPath,
    this.imageUrl,
    required this.options,
    required this.correctIndex,
  });

  bool get hasImage => (imageAssetPath != null && imageAssetPath!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
}
