/// Tracks which hands-on driving-control tutorials the user has finished.
///
/// Persisted as JSON via [TutorialProgressService] and `ProgressRepository`.
class TutorialProgress {
  final Set<DrivingTutorialLesson> completedLessons;

  const TutorialProgress({this.completedLessons = const {}});

  bool isComplete(DrivingTutorialLesson lesson) => completedLessons.contains(lesson);

  bool get isFullyComplete =>
      completedLessons.length == DrivingTutorialLesson.values.length;

  double get completionFraction {
    if (DrivingTutorialLesson.values.isEmpty) return 0;
    return completedLessons.length / DrivingTutorialLesson.values.length;
  }

  TutorialProgress copyWith({Set<DrivingTutorialLesson>? completedLessons}) {
    return TutorialProgress(
      completedLessons: completedLessons ?? this.completedLessons,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completedLessons.map((e) => e.name).toList(),
      };

  factory TutorialProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TutorialProgress();
    final raw = json['completed'];
    if (raw is! List) return const TutorialProgress();
    final set = <DrivingTutorialLesson>{};
    for (final item in raw) {
      if (item is! String) continue;
      final lesson = DrivingTutorialLesson.tryParse(item);
      if (lesson != null) set.add(lesson);
    }
    return TutorialProgress(completedLessons: set);
  }
}

enum DrivingTutorialLesson {
  gearbox,
  steering,
  turnSignals,
  pedals;

  String get title => switch (this) {
        DrivingTutorialLesson.gearbox => 'Gear lever',
        DrivingTutorialLesson.steering => 'Steering wheel',
        DrivingTutorialLesson.turnSignals => 'Turn signals',
        DrivingTutorialLesson.pedals => 'Accelerator & brake',
      };

  String get shortDescription => switch (this) {
        DrivingTutorialLesson.gearbox =>
          'Tap positions to change gear — Park stops the car; R is reverse; 1–5 drive forward.',
        DrivingTutorialLesson.steering =>
          'Drag the wheel sideways — the car follows while you drive.',
        DrivingTutorialLesson.turnSignals =>
          'Double-tap the road for left, triple-tap for right; tap again to cancel.',
        DrivingTutorialLesson.pedals =>
          'Hold the green pedal to speed up, red to slow down.',
      };

  static DrivingTutorialLesson? tryParse(String name) {
    for (final v in DrivingTutorialLesson.values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
