part of '../realistic_car_game.dart';

/// True if this object layer should supply axis-aligned collision rectangles.
bool _isTiledCollisionObjectLayer(ObjectGroup layer) {
  final nameNorm = layer.name.replaceAll(' ', '_').toLowerCase();
  if (nameNorm == 'obstacles_layer') return true;
  final cls = layer.class_?.trim().toLowerCase();
  return cls == 'collision_box';
}

double? _readNumericPropertyAsDouble(CustomProperties properties, String name) {
  try {
    final intValue = properties.getValue<int>(name);
    if (intValue != null) return intValue.toDouble();
  } catch (_) {
    // Property exists but is not int; fall through to double read.
  }
  try {
    return properties.getValue<double>(name);
  } catch (_) {
    return null;
  }
}

/// TMX may use `max_speed` or `speed_limit` on the object or parent layer.
double? _readZoneSpeedLimit(CustomProperties objProps, CustomProperties layerProps) {
  return _readNumericPropertyAsDouble(objProps, 'max_speed') ??
      _readNumericPropertyAsDouble(objProps, 'speed_limit') ??
      _readNumericPropertyAsDouble(layerProps, 'max_speed') ??
      _readNumericPropertyAsDouble(layerProps, 'speed_limit');
}

void _collectObjectGroupsRecursive(List<Layer> layers, List<ObjectGroup> out) {
  for (final layer in layers) {
    if (layer is ObjectGroup) {
      out.add(layer);
    } else if (layer is Group) {
      _collectObjectGroupsRecursive(layer.layers, out);
    }
  }
}

/// Axis-aligned bounds of a Tiled rectangle object, including [TiledObject.rotation] in degrees.
Rect _aabbForTiledObjectRect(TiledObject obj) {
  if (obj.rotation == 0 || obj.rotation % 360 == 0) {
    return Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);
  }
  final rad = obj.rotation * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  double rx(double lx, double ly) => lx * c - ly * s;
  double ry(double lx, double ly) => lx * s + ly * c;
  final corners = <Offset>[
    Offset(rx(0, 0) + obj.x, ry(0, 0) + obj.y),
    Offset(rx(obj.width, 0) + obj.x, ry(obj.width, 0) + obj.y),
    Offset(rx(obj.width, obj.height) + obj.x, ry(obj.width, obj.height) + obj.y),
    Offset(rx(0, obj.height) + obj.x, ry(0, obj.height) + obj.y),
  ];
  var minX = corners.first.dx;
  var maxX = corners.first.dx;
  var minY = corners.first.dy;
  var maxY = corners.first.dy;
  for (final p in corners.skip(1)) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Rect? _checkpointRectFromTiledObject(TiledObject obj) {
  if (!obj.visible) return null;
  if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) return null;
  if (obj.width <= 0 || obj.height <= 0) return null;
  return _aabbForTiledObjectRect(obj);
}

/// Tiled: rotation in degrees clockwise around ([ox], [oy]) (pixel space, Y down).
Offset _tiledRotateLocal(double lx, double ly, double rotationDeg) {
  if (rotationDeg == 0) return Offset(lx, ly);
  final rad = rotationDeg * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  final rx = lx * c + ly * s;
  final ry = lx * s + ly * c;
  return Offset(rx, ry);
}

Path? _midTurnHitPathFromObject(TiledObject obj) {
  if (!obj.visible) return null;

  if (obj.isPolygon && obj.polygon.length >= 3) {
    final pts = <Offset>[];
    for (final p in obj.polygon) {
      final r = _tiledRotateLocal(p.x, p.y, obj.rotation);
      pts.add(Offset(obj.x + r.dx, obj.y + r.dy));
    }
    return Path()..addPolygon(pts, true);
  }

  if (obj.isRectangle && obj.width > 0 && obj.height > 0) {
    final w = obj.width;
    final h = obj.height;
    final corners = [
      Offset(0, 0),
      Offset(w, 0),
      Offset(w, h),
      Offset(0, h),
    ];
    final pts = corners
        .map((c) {
          final r = _tiledRotateLocal(c.dx, c.dy, obj.rotation);
          return Offset(obj.x + r.dx, obj.y + r.dy);
        })
        .toList();
    return Path()..addPolygon(pts, true);
  }

  return null;
}

/// Axis-aligned bounds for a Tiled rectangle object (handles [TiledObject.rotation]).
Rect? _worldAabbForTiledRectangleObject(TiledObject obj) {
  if (!obj.visible || obj.width <= 0 || obj.height <= 0) return null;
  if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) {
    return null;
  }
  final w = obj.width;
  final h = obj.height;
  final corners = [
    Offset(0, 0),
    Offset(w, 0),
    Offset(w, h),
    Offset(0, h),
  ];
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (final c in corners) {
    final r = _tiledRotateLocal(c.dx, c.dy, obj.rotation);
    final wx = obj.x + r.dx;
    final wy = obj.y + r.dy;
    minX = math.min(minX, wx);
    minY = math.min(minY, wy);
    maxX = math.max(maxX, wx);
    maxY = math.max(maxY, wy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

bool _isMidTurnValidationObject(TiledObject obj, ObjectGroup layer) {
  final ot = obj.type.trim().toLowerCase();
  if (ot == 'zone_midturn') return true;
  final lc = (layer.class_ ?? '').trim().toLowerCase();
  if (lc == 'zone_midturn') return true;
  final ln = layer.name.replaceAll(' ', '_').toLowerCase();
  if (ln.contains('junction_validation')) return true;
  return false;
}

/// Tile layer used to mark junction-box hatched area (UK: do not stop inside).
bool _isJunctionBoxTileLayer(TileLayer layer) {
  if (!layer.visible) return false;
  final cls = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase().trim();
  if (cls == 'zone_junctionbox' || cls.contains('junctionbox')) return true;
  final nm = layer.name.replaceAll(' ', '_').toLowerCase();
  return nm == 'junction_box' || nm.contains('junction_box');
}

String _tiledLayerTag(ObjectGroup layer) =>
    layer.name.replaceAll(' ', '_').toLowerCase();

/// Prefer `Player_Spawn` over other layers whose names contain "spawn" (e.g. ambulance marker).
Vector2? _pickPlayerSpawnFromObjectGroups(Iterable<ObjectGroup> groups) {
  Vector2? pickFromLayer(ObjectGroup layer) {
    final layerTag = _tiledLayerTag(layer);
    final layerClassTag = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase();
    final isSpawnLayer =
        layerTag.contains('spawn') || layerClassTag.contains('spawn');
    for (final obj in layer.objects) {
      final objectClassTag = obj.class_.replaceAll(' ', '_').toLowerCase();
      final objectTypeTag = obj.type.replaceAll(' ', '_').toLowerCase();
      final objectNameTag = obj.name.replaceAll(' ', '_').toLowerCase();
      final isSpawnObject = objectClassTag.contains('spawn') ||
          objectTypeTag.contains('spawn') ||
          objectNameTag.contains('spawn');
      if (!isSpawnLayer && !isSpawnObject) continue;
      final spawnX = obj.isPoint ? obj.x : obj.x + (obj.width / 2);
      final spawnY = obj.isPoint ? obj.y : obj.y + (obj.height / 2);
      return Vector2(spawnX, spawnY);
    }
    return null;
  }

  for (final layer in groups) {
    final t = _tiledLayerTag(layer);
    if (t.contains('player') && t.contains('spawn')) {
      final p = pickFromLayer(layer);
      if (p != null) {
        print(
          '[DEBUG] _pickPlayerSpawn - chose Player_Spawn-style layer "${layer.name}" '
          'class="${layer.class_ ?? ""}" at $p',
        );
        return p;
      }
    }
  }
  for (final layer in groups) {
    final t = _tiledLayerTag(layer);
    if (t.contains('ambulance') && t.contains('spawn')) continue;
    final p = pickFromLayer(layer);
    if (p != null) {
      print(
        '[DEBUG] _pickPlayerSpawn - chose generic spawn layer "${layer.name}" '
        'class="${layer.class_ ?? ""}" at $p',
      );
      return p;
    }
  }
  print('[DEBUG] _pickPlayerSpawn - no spawn object found in object groups');
  return null;
}
