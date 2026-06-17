part of '../driving_game.dart';

/// Tries bundled ambulance art (same folder convention as [BlackCar.png]), then a fallback sprite.
Future<Sprite> _loadAmbulanceSpriteForLevel() async {
  const candidates = <String>[
    'Ambulance - v1.png',
    'Ambulance.png',
  ];
  for (final name in candidates) {
    try {
      return await Sprite.load(name);
    } catch (_) {}
  }
  return _proceduralAmbulanceSprite();
}

/// UK-style ambulance marker when no PNG asset loads.
Future<Sprite> _proceduralAmbulanceSprite() async {
  const w = 48;
  const h = 80;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(6, 14, 36, 50),
    const Radius.circular(7),
  );
  canvas.drawRRect(body, Paint()..color = const Color(0xFFF2F2F2));
  canvas.drawRect(
    Rect.fromLTWH(6, 32, 36, 10),
    Paint()..color = const Color(0xFFD32F2F),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 6, 16, 12),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFF1565C0),
  );
  canvas.drawCircle(
    const Offset(24, 12),
    3,
    Paint()..color = const Color(0xFFFFEB3B),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  return Sprite(image);
}

/// First marker in `Ambulance_Spawn` (decoration; uses Tiled object rotation if set).
/// [sirenVolume] comes from the layer's `sirenVolume` custom property (default 0.8).
({Vector2 position, double angle, double sirenVolume})? _readAmbulanceSpawnConfig(
  Iterable<ObjectGroup> groups,
) {
  for (final layer in groups) {
    final t = _tiledLayerTag(layer);
    if (!(t.contains('ambulance') && t.contains('spawn'))) continue;
    var sirenVol = 0.8;
    final sv = _readNumericPropertyAsDouble(layer.properties, 'sirenVolume');
    if (sv != null) {
      sirenVol = sv.clamp(0.0, 1.0);
    }
    for (final obj in layer.objects) {
      if (!obj.visible) continue;
      final spawnX = obj.isPoint ? obj.x : obj.x + (obj.width / 2);
      final spawnY = obj.isPoint ? obj.y : obj.y + (obj.height / 2);
      final angle = -math.pi / 2 + obj.rotation * math.pi / 180;
      return (position: Vector2(spawnX, spawnY), angle: angle, sirenVolume: sirenVol);
    }
  }
  return null;
}

/// [ambulance-reaction.tmx]: `Safe_Zone_Left` / `Safe_Zone_Right` + optional [Success_Layer].
void _collectEmergencyScenarioRects(
  Iterable<ObjectGroup> groups, {
  required List<Rect> outLeft,
  required List<Rect> outRight,
  required List<Rect> outSuccess,
}) {
  outLeft.clear();
  outRight.clear();
  outSuccess.clear();
  for (final layer in groups) {
    final tag = _tiledLayerTag(layer);
    final cls = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase();
    String? kind;
    if (tag == 'safe_zone_left' || cls == 'safe_zone_left') {
      kind = 'left';
    } else if (tag == 'safe_zone_right' || cls == 'safe_zone_right') {
      kind = 'right';
    } else if (tag == 'success_layer' || cls == 'success_layer') {
      kind = 'success';
    } else if (tag.contains('success_layer') || cls.contains('success_layer')) {
      kind = 'success';
    } else if (tag.contains('safe_zone') && tag.contains('left')) {
      kind = 'left';
    } else if (tag.contains('safe_zone') && tag.contains('right')) {
      kind = 'right';
    } else {
      continue;
    }
    final List<Rect> target = switch (kind) {
      'left' => outLeft,
      'right' => outRight,
      _ => outSuccess,
    };
    for (final obj in layer.objects) {
      final aabb = _worldAabbForTiledRectangleObject(obj);
      if (aabb == null) continue;
      target.add(aabb);
    }
  }
}

/// Axis-aligned rectangles from object layers named/classed like `Siren_Layer` / `Siren_Triggers`.
void _collectSirenTriggerRects(
  Iterable<ObjectGroup> groups,
  List<Rect> out,
) {
  out.clear();
  for (final layer in groups) {
    final tag = _tiledLayerTag(layer);
    final layerClass = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase();
    final isSiren = tag.contains('siren') || layerClass.contains('siren');
    if (!isSiren) continue;
    for (final obj in layer.objects) {
      if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
      if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) continue;
      if (obj.rotation != 0) continue;
      out.add(Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
    }
  }
}
