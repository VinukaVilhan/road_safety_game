/// One driving-rule penalty with optional screenshot (local path and/or remote URL).
class PenaltyRecord {
  final String description;
  final String? screenshotPath;
  final String? screenshotUrl;

  const PenaltyRecord({
    required this.description,
    this.screenshotPath,
    this.screenshotUrl,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        if (screenshotPath != null && screenshotPath!.isNotEmpty)
          'screenshotPath': screenshotPath,
        if (screenshotUrl != null && screenshotUrl!.isNotEmpty)
          'screenshotUrl': screenshotUrl,
      };

  static String? _optionalPath(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  factory PenaltyRecord.fromJson(Map<String, dynamic> json) {
    return PenaltyRecord(
      description: (json['description'] as String?)?.trim() ?? '',
      screenshotPath: _optionalPath(json['screenshotPath']),
      screenshotUrl: _optionalPath(json['screenshotUrl']),
    );
  }
}

/// Ambulance-level metrics captured at end of attempt ([emergency_ambulance] scenario).
class AmbulanceAttemptSnapshot {
  final bool mapHasCp1;
  final bool mapHasCp2;
  final bool mapHasCpf;
  final bool cp1Cleared;
  final bool cp2Cleared;
  final bool pullOverCompleted;
  /// `true` = left safe zone, `false` = right, `null` if pull-over was never completed.
  final bool? yieldLeftSide;
  final double elapsedSecs;
  final double levelTimeoutSecs;
  final double cp1TimeLimitSecs;
  final double cp2TimeLimitSecs;
  final bool ambulanceRouteCompleted;
  /// [AmbulanceState] name, or `none` if no ambulance entity existed at summary time.
  final String ambulanceAiState;

  const AmbulanceAttemptSnapshot({
    required this.mapHasCp1,
    required this.mapHasCp2,
    required this.mapHasCpf,
    required this.cp1Cleared,
    required this.cp2Cleared,
    required this.pullOverCompleted,
    required this.yieldLeftSide,
    required this.elapsedSecs,
    required this.levelTimeoutSecs,
    required this.cp1TimeLimitSecs,
    required this.cp2TimeLimitSecs,
    required this.ambulanceRouteCompleted,
    required this.ambulanceAiState,
  });

  Map<String, dynamic> toJson() => {
        'mapHasCp1': mapHasCp1,
        'mapHasCp2': mapHasCp2,
        'mapHasCpf': mapHasCpf,
        'cp1Cleared': cp1Cleared,
        'cp2Cleared': cp2Cleared,
        'pullOverCompleted': pullOverCompleted,
        if (yieldLeftSide != null) 'yieldLeftSide': yieldLeftSide,
        'elapsedSecs': elapsedSecs,
        'levelTimeoutSecs': levelTimeoutSecs,
        'cp1TimeLimitSecs': cp1TimeLimitSecs,
        'cp2TimeLimitSecs': cp2TimeLimitSecs,
        'ambulanceRouteCompleted': ambulanceRouteCompleted,
        'ambulanceAiState': ambulanceAiState,
      };

  static bool _bool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  static double _double(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    return fallback;
  }

  factory AmbulanceAttemptSnapshot.fromJson(Map<String, dynamic> json) {
    final yl = json['yieldLeftSide'];
    return AmbulanceAttemptSnapshot(
      mapHasCp1: _bool(json['mapHasCp1']),
      mapHasCp2: _bool(json['mapHasCp2']),
      mapHasCpf: _bool(json['mapHasCpf']),
      cp1Cleared: _bool(json['cp1Cleared']),
      cp2Cleared: _bool(json['cp2Cleared']),
      pullOverCompleted: _bool(json['pullOverCompleted']),
      yieldLeftSide: yl is bool ? yl : null,
      elapsedSecs: _double(json['elapsedSecs']),
      levelTimeoutSecs: _double(json['levelTimeoutSecs'], fallback: 180),
      cp1TimeLimitSecs: _double(json['cp1TimeLimitSecs']),
      cp2TimeLimitSecs: _double(json['cp2TimeLimitSecs']),
      ambulanceRouteCompleted: _bool(json['ambulanceRouteCompleted']),
      ambulanceAiState: (json['ambulanceAiState'] as String?)?.trim().isNotEmpty == true
          ? (json['ambulanceAiState'] as String).trim()
          : 'unknown',
    );
  }
}

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
  /// Penalties with per-event screenshots (e.g. dashed-lines signalling).
  final List<PenaltyRecord> penaltyRecords;
  /// Present for [emergency_ambulance] practical attempts.
  final AmbulanceAttemptSnapshot? ambulance;

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
    this.penaltyRecords = const [],
    this.ambulance,
  });

  static bool isRoadCrossingMap(String? mapAsset) =>
      (mapAsset ?? '').toLowerCase().contains('road_crossing');

  static String? _optionalNonEmptyPath(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _stringListFromJson(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static List<PenaltyRecord> _penaltyRecordsFromJson(dynamic v) {
    if (v is! List) return const [];
    final out = <PenaltyRecord>[];
    for (final e in v) {
      if (e is Map) {
        try {
          out.add(PenaltyRecord.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return out;
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
        if (penaltyRecords.isNotEmpty)
          'penaltyRecords': penaltyRecords.map((e) => e.toJson()).toList(),
        if (ambulance != null) 'ambulance': ambulance!.toJson(),
      };

  factory LastDrivingReport.fromJson(Map<String, dynamic> json) {
    final details = _stringListFromJson(json['mistakeDetails']);
    final mistakeCount = (json['mistakes'] as num?)?.toInt() ?? 0;
    AmbulanceAttemptSnapshot? amb;
    final ambRaw = json['ambulance'];
    if (ambRaw is Map) {
      try {
        amb = AmbulanceAttemptSnapshot.fromJson(Map<String, dynamic>.from(ambRaw));
      } catch (_) {}
    }

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
      penaltyRecords: _penaltyRecordsFromJson(json['penaltyRecords']),
      ambulance: amb,
    );
  }
}
