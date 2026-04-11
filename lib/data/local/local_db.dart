import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_schemas.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Isar? _isar;

  Isar get isar {
    final value = _isar;
    if (value == null) {
      throw StateError('LocalDb not initialized. Call LocalDb.instance.initialize() first.');
    }
    return value;
  }

  Future<void> initialize() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        LocalLevelProgressSchema,
        LocalTheoryTestProgressSchema,
        LocalTheoryAttemptSchema,
        LocalRoadSignsModuleProgressSchema,
        LocalUserSettingSchema,
        SyncOutboxItemSchema,
      ],
      directory: dir.path,
      name: 'road_safety_local_db',
    );
  }

  Future<void> close() async {
    final db = _isar;
    if (db == null) return;
    await db.close();
    _isar = null;
  }
}
