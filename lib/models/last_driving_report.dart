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
  final int timeSpentMs;
  final DateTime recordedAt;
  final String? failureMessage;
  final bool roadCrossingLayout;

  const LastDrivingReport({
    required this.levelId,
    required this.levelName,
    required this.passed,
    required this.score,
    required this.correctMoves,
    required this.mistakes,
    required this.timeSpentMs,
    required this.recordedAt,
    this.failureMessage,
    required this.roadCrossingLayout,
  });

  static bool isRoadCrossingMap(String? mapAsset) =>
      (mapAsset ?? '').toLowerCase().contains('road-crossing');

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'levelName': levelName,
        'passed': passed,
        'score': score,
        'correctMoves': correctMoves,
        'mistakes': mistakes,
        'timeSpentMs': timeSpentMs,
        'recordedAtIso': recordedAt.toIso8601String(),
        if (failureMessage != null && failureMessage!.isNotEmpty) 'failureMessage': failureMessage,
        'roadCrossingLayout': roadCrossingLayout,
      };

  factory LastDrivingReport.fromJson(Map<String, dynamic> json) {
    return LastDrivingReport(
      levelId: json['levelId'] as String? ?? '',
      levelName: json['levelName'] as String? ?? 'Unknown level',
      passed: json['passed'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctMoves: (json['correctMoves'] as num?)?.toInt() ?? 0,
      mistakes: (json['mistakes'] as num?)?.toInt() ?? 0,
      timeSpentMs: (json['timeSpentMs'] as num?)?.toInt() ?? 0,
      recordedAt: DateTime.tryParse(json['recordedAtIso'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      failureMessage: json['failureMessage'] as String?,
      roadCrossingLayout: json['roadCrossingLayout'] as bool? ?? false,
    );
  }
}
