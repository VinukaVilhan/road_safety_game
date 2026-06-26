part of '../driving_game.dart';

/// Loads a TMX asset once and attaches it to the world at the origin.
Future<TiledComponent> _loadTiledMapComponent(
  String tmxPath, {
  double tileSize = 16,
}) async {
  final component = await TiledComponent.load(
    tmxPath,
    Vector2.all(tileSize),
  );
  component.position = Vector2.zero();
  component.priority = 0;
  return component;
}

List<ObjectGroup> _objectGroupsFromTiledMap(TiledMap map) {
  final out = <ObjectGroup>[];
  _collectObjectGroupsRecursive(map.layers, out);
  return out;
}

({double width, double height}) _mapPixelSize(
  TiledMap map, {
  double tileSize = 16,
}) {
  return (width: map.width * tileSize, height: map.height * tileSize);
}
