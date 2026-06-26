part of '../driving_game.dart';

extension JunctionBoxZones on RealisticCarGameBase {
  bool _carRectOverlapsJunctionBoxTiles(Rect carWorldRect) {
    final mask = _junctionBoxTileMask;
    final mw = _junctionBoxMaskWidthTiles;
    final mh = _junctionBoxMaskHeightTiles;
    if (mask == null || mw == null || mh == null) return false;

    final tw = RealisticCarGameBase._junctionBoxTileWorldSize;
    var tx0 = (carWorldRect.left / tw).floor();
    var tx1 = (carWorldRect.right / tw).ceil() - 1;
    var ty0 = (carWorldRect.top / tw).floor();
    var ty1 = (carWorldRect.bottom / tw).ceil() - 1;
    tx0 = math.max(0, math.min(mw - 1, tx0));
    tx1 = math.max(0, math.min(mw - 1, tx1));
    ty0 = math.max(0, math.min(mh - 1, ty0));
    ty1 = math.max(0, math.min(mh - 1, ty1));

    for (var ty = ty0; ty <= ty1; ty++) {
      final row = ty * mw;
      for (var tx = tx0; tx <= tx1; tx++) {
        final idx = row + tx;
        if (idx >= 0 && idx < mask.length && mask[idx]) return true;
      }
    }
    return false;
  }

  void _updateJunctionBoxStopFail(double dt) {
    if (!drivingRulesEnabled) return;
    if (_testFinished || car == null || _junctionBoxTileMask == null) return;

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    final inBox = _carRectOverlapsJunctionBoxTiles(carRect);
    if (!inBox) {
      _junctionBoxStoppedElapsedSec = 0.0;
      return;
    }

    if (car!.isInPark) {
      _failStoppedInJunctionBox(
        'Do not stop or park in the junction box — wait behind the line until you can clear the junction.',
      );
      return;
    }

    final speed = car!.velocity.length;
    if (speed < RealisticCarGameBase._junctionBoxStoppedSpeedThreshold) {
      _junctionBoxStoppedElapsedSec += dt;
      if (_junctionBoxStoppedElapsedSec >= RealisticCarGameBase._junctionBoxStoppedSecondsToFail) {
        _failStoppedInJunctionBox(
          'Do not stop in the junction box. Keep moving or wait behind the line until the way is clear.',
        );
      }
    } else {
      _junctionBoxStoppedElapsedSec = 0.0;
    }
  }
}
