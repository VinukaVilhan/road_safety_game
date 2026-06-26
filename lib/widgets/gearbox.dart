import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/media_assets.dart';

class GearboxWidget extends StatelessWidget {
  final int currentGear;
  final List<String> gears;
  final Function(int) onGearSelected;

  const GearboxWidget({
    super.key,
    required this.currentGear,
    required this.gears,
    required this.onGearSelected,
  });

  @override
  Widget build(BuildContext context) {
    const frameWidth = 140.0;
    const frameHeight = 200.0;
    return Container(
      width: frameWidth,
      height: frameHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          // Background gearbox image
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                MediaAssets.gearboxCubicRescaled,
                width: frameWidth,
                height: frameHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to load gearbox image: ${MediaAssets.gearboxCubicRescaled}');
                  debugPrint('Error: $error');
                  return _buildFallbackGearbox(context);
                },
              ),
            ),
          ),
          
          // Gear position overlays
          _buildGearPositionOverlays(),
        ],
      ),
    );
  }

  int get _reverseGearIndex {
    final idx = gears.lastIndexOf('R');
    if (idx >= 0) return idx;
    return gears.isNotEmpty ? gears.length - 1 : 0;
  }

  String _safeGearLabel(int index, {String fallback = '-'}) {
    if (index < 0 || index >= gears.length) return fallback;
    return gears[index];
  }

  Widget _buildGearPositionOverlays() {
    // Pixel-based hotspots for the 140x200 gearbox frame.
    // Tune these values directly if your image art/placement changes.
    const double globalOffsetX = 0;
    const double globalOffsetY = 0;

    // Optional per-gear micro adjustments in pixels.
    const double nudgeRx = 0;
    const double nudgeRy = 0;
    const double nudge1x = 0;
    const double nudge1y = 0;
    const double nudge2x = 0;
    const double nudge2y = 0;
    const double nudge3x = 0;
    const double nudge3y = 0;
    const double nudge4x = 0;
    const double nudge4y = 0;
    const double nudgePx = 0;
    const double nudgePy = 0;

    const double rX = 34;
    const double rY = 72;
    const double g1X = 70;
    const double g1Y = 72;
    const double g2X = 106;
    const double g2Y = 72;
    const double g3X = 34;
    const double g3Y = 130;
    const double g4X = 70;
    const double g4Y = 130;
    const double pX = 106;
    const double pY = 130;

    return Stack(
      children: [
        // Reverse (R) - Top Left
        _buildGearHotspot(
          gear: _reverseGearIndex,
          centerX: rX + globalOffsetX + nudgeRx,
          centerY: rY + globalOffsetY + nudgeRy,
          label: _safeGearLabel(_reverseGearIndex, fallback: 'R'),
        ),
        
        // First Gear (1) - Top middle
        _buildGearHotspot(
          gear: 1, // 1st gear position
          centerX: g1X + globalOffsetX + nudge1x,
          centerY: g1Y + globalOffsetY + nudge1y,
          label: _safeGearLabel(1, fallback: '1'),
        ),
        
        // Second Gear (2) - Top right
        _buildGearHotspot(
          gear: 2,
          centerX: g2X + globalOffsetX + nudge2x,
          centerY: g2Y + globalOffsetY + nudge2y,
          label: _safeGearLabel(2, fallback: '2'),
        ),
        
        // Third Gear (3) - Bottom left
        _buildGearHotspot(
          gear: 3,
          centerX: g3X + globalOffsetX + nudge3x,
          centerY: g3Y + globalOffsetY + nudge3y,
          label: _safeGearLabel(3, fallback: '3'),
        ),
        
        // Fourth Gear (4) - Bottom middle
        _buildGearHotspot(
          gear: 4,
          centerX: g4X + globalOffsetX + nudge4x,
          centerY: g4Y + globalOffsetY + nudge4y,
          label: _safeGearLabel(4, fallback: '4'),
        ),
        
        // Park (P) - Bottom right
        _buildGearHotspot(
          gear: 0, // P position
          centerX: pX + globalOffsetX + nudgePx,
          centerY: pY + globalOffsetY + nudgePy,
          label: _safeGearLabel(0, fallback: 'P'),
        ),
      ],
    );
  }

  Widget _buildGearHotspot({
    required int gear,
    required double centerX,
    required double centerY,
    required String label,
  }) {
    final bool isSelected = currentGear == gear;
    const hotspotSize = 30.0;
    
    return Positioned(
      left: centerX - (hotspotSize / 2),
      top: centerY - (hotspotSize / 2),
      child: GestureDetector(
        onTap: () => _selectGear(gear),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          scale: isSelected ? 1.07 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: hotspotSize,
            height: hotspotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? _getGearColor().withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.3),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey[400]!,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _getGearColor().withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context).textTheme;
                  return Text(
                    label,
                    style: (isSelected ? theme.titleSmall : theme.labelMedium)!
                        .copyWith(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.bold,
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }


  // Helper method to get gear-specific colors
  Color _getGearColor() {
    if (currentGear == _reverseGearIndex) return Colors.red; // Reverse
    switch (currentGear) {
      case 0: return Colors.orange;    // Park
      case 1: return Colors.green;     // 1st gear
      case 2: return Colors.lightGreen; // 2nd gear
      case 3: return Colors.blue;      // 3rd gear
      case 4: return Colors.purple;    // 4th gear
      case 5: return Colors.cyan;      // 5th gear
      default: return Colors.grey;
    }
  }

  // Fallback gearbox UI when image fails to load
  Widget _buildFallbackGearbox(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[600]!, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings,
            color: Colors.grey[400],
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'GEARBOX',
            style: theme.labelMedium!.copyWith(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Method to handle gear selection
  void _selectGear(int gearIndex) {
    onGearSelected(gearIndex);
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
  }
}