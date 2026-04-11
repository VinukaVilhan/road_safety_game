import 'package:isar/isar.dart';

part 'isar_schemas.g.dart';

enum SyncOutboxStatus {
  pending,
  processing,
  failed,
  synced,
}

@collection
class LocalLevelProgress {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  @Index()
  late String uid;

  @Index()
  late String levelId;

  bool completed = true;
  DateTime updatedAt = DateTime.now().toUtc();
  bool synced = false;
  String? lastOpId;
}

@collection
class LocalTheoryTestProgress {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  @Index()
  late String uid;

  @Index()
  late String testId;

  int bestScore = 0;
  int attempts = 0;
  bool passed = false;
  DateTime updatedAt = DateTime.now().toUtc();
  bool synced = false;
  String? lastOpId;
}

/// Tracks non-MCQ road-signs curriculum modules (e.g. study completed).
/// MCQ outcomes remain in [LocalTheoryTestProgress] keyed by module id.
@collection
class LocalRoadSignsModuleProgress {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  @Index()
  late String uid;

  @Index()
  late String moduleId;

  /// True when the user finished the learn / non-MCQ flow for this module.
  bool contentViewed = false;

  DateTime updatedAt = DateTime.now().toUtc();
  bool synced = false;
  String? lastOpId;
}

@collection
class LocalTheoryAttempt {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String attemptId;

  @Index()
  late String uid;

  @Index()
  late String testId;

  int score = 0;
  int totalQuestions = 0;
  int correctCount = 0;
  DateTime createdAt = DateTime.now().toUtc();
  DateTime updatedAt = DateTime.now().toUtc();
  bool synced = false;
  String? lastOpId;
}

@collection
class LocalUserSetting {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  @Index()
  late String uid;

  late String settingKey;
  late String value;
  DateTime updatedAt = DateTime.now().toUtc();
  bool synced = false;
  String? lastOpId;
}

@collection
class SyncOutboxItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String opId;

  @Index()
  late String uid;

  @Index()
  late String entityType;

  @Index()
  late String entityId;

  late String payloadJson;
  DateTime createdAt = DateTime.now().toUtc();
  DateTime updatedAt = DateTime.now().toUtc();
  DateTime? nextRetryAt;
  int retryCount = 0;
  String? lastError;
  @enumerated
  SyncOutboxStatus status = SyncOutboxStatus.pending;
}
