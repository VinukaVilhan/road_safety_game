/// Serializable snapshot of the most recently finished practical driving attempt.
class LastDrivingReport {
  final String levelId;
  final String levelName;
  final bool passed;
  final int score;
  /// Checklist items satisfied (same rubric as the in-game result dialog).
  final int correctMoves;
  /// Checklist items missed (each failed row counts as one; bumps row fails if any bump).
  final int mistakes;
  /// Human-readable explanation for each failed rubric row (empty if none).
  final List<String> mistakeDetails;
  final int timeSpentMs;
  final DateTime recordedAt;
  final String? failureMessage;
  final bool roadCrossingLayout;
  /// Local filesystem path to a PNG captured at rule failure (null if none or passed).
  final String? screenshotPath;
  /// Remote image URL (e.g. Cloudinary) when upload succeeded (null otherwise).
  final String? screenshotUrl;

  const LastDrivingReport({
    required this.levelId,
    required this.levelName,
    required this.passed,
    required this.score,
    required this.correctMoves,
    required this.mistakes,
    this.mistakeDetails = const [],
    required this.timeSpentMs,
    required this.recordedAt,
    this.failureMessage,
    required this.roadCrossingLayout,
    this.screenshotPath,
    this.screenshotUrl,
  });

  static bool isRoadCrossingMap(String? mapAsset) =>
      (mapAsset ?? '').toLowerCase().contains('road-crossing');

  static String? _optionalNonEmptyPath(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _stringListFromJson(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'levelName': levelName,
        'passed': passed,
        'score': score,
        'correctMoves': correctMoves,
        'mistakes': mistakes,
        'mistakeDetails': mistakeDetails,
        'timeSpentMs': timeSpentMs,
        'recordedAtIso': recordedAt.toIso8601String(),
        if (failureMessage != null && failureMessage!.isNotEmpty) 'failureMessage': failureMessage,
        'roadCrossingLayout': roadCrossingLayout,
        if (screenshotPath != null && screenshotPath!.isNotEmpty) 'screenshotPath': screenshotPath,
        if (screenshotUrl != null && screenshotUrl!.isNotEmpty) 'screenshotUrl': screenshotUrl,
      };

  factory LastDrivingReport.fromJson(Map<String, dynamic> json) {
    final details = _stringListFromJson(json['mistakeDetails']);
    final mistakeCount = (json['mistakes'] as num?)?.toInt() ?? 0;
    return LastDrivingReport(
      levelId: json['levelId'] as String? ?? '',
      levelName: json['levelName'] as String? ?? 'Unknown level',
      passed: json['passed'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctMoves: (json['correctMoves'] as num?)?.toInt() ?? 0,
      mistakes: mistakeCount,
      mistakeDetails: details,
      timeSpentMs: (json['timeSpentMs'] as num?)?.toInt() ?? 0,
      recordedAt: DateTime.tryParse(json['recordedAtIso'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      failureMessage: json['failureMessage'] as String?,
      roadCrossingLayout: json['roadCrossingLayout'] as bool? ?? false,
      screenshotPath: _optionalNonEmptyPath(json['screenshotPath']),
      screenshotUrl: _optionalNonEmptyPath(json['screenshotUrl']),
    );
  }
}
