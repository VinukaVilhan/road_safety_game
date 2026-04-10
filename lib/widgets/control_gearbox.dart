import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ControlGearboxWidget extends StatelessWidget {
  final int currentGear;
  final List<String> gears;
  final ValueChanged<int> onGearSelected;

  const ControlGearboxWidget({
    super.key,
    required this.currentGear,
    required this.gears,
    required this.onGearSelected,
  });

  static const double _frameWidth = 140.0;
  static const double _frameHeight = 200.0;
  static const double _hotspotSize = 30.0;

  int get _reverseGearIndex {
    final idx = gears.lastIndexOf('R');
    if (idx >= 0) return idx;
    return gears.isNotEmpty ? gears.length - 1 : 0;
  }

  String _safeGearLabel(int index, {String fallback = '-'}) {
    if (index < 0 || index >= gears.length) return fallback;
    return gears[index];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _frameWidth,
      height: _frameHeight,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/images/rescaled/gearbox_cubic.png',
              width: _frameWidth,
              height: _frameHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackGearbox(context);
              },
            ),
          ),
          _buildGearPositionOverlays(),
        ],
      ),
    );
  }

  Widget _buildGearPositionOverlays() {
    // Same column/row logic style as the original widget, tuned for this control gearbox.
    final leftCol = _frameWidth * 0.24; // ~34
    final midCol = _frameWidth * 0.50; // 70
    final rightCol = _frameWidth * 0.96; // ~106
    final topRow = _frameHeight * 0.33; // 66
    final bottomRow = _frameHeight * 0.22; // 124

    return Stack(
      children: [
        _buildGearHotspot(
          gear: _reverseGearIndex,
          centerX: leftCol,
          centerY: topRow,
          label: _safeGearLabel(_reverseGearIndex, fallback: 'R'),
        ),
        _buildGearHotspot(
          gear: 1,
          centerX: midCol,
          centerY: topRow,
          label: _safeGearLabel(1, fallback: '1'),
        ),
        _buildGearHotspot(
          gear: 2,
          centerX: rightCol,
          centerY: topRow,
          label: _safeGearLabel(2, fallback: '2'),
        ),
        _buildGearHotspot(
          gear: 3,
          centerX: leftCol,
          centerY: bottomRow,
          label: _safeGearLabel(3, fallback: '3'),
        ),
        _buildGearHotspot(
          gear: 4,
          centerX: midCol,
          centerY: bottomRow,
          label: _safeGearLabel(4, fallback: '4'),
        ),
        _buildGearHotspot(
          gear: 0,
          centerX: rightCol,
          centerY: bottomRow,
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
    final isSelected = currentGear == gear;
    return Positioned(
      left: centerX - (_hotspotSize / 2),
      top: centerY - (_hotspotSize / 2),
      child: GestureDetector(
        onTap: () {
          onGearSelected(gear);
          HapticFeedback.lightImpact();
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          scale: isSelected ? 1.07 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _hotspotSize,
            height: _hotspotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? _getSelectedGearColor().withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.3),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey[400]!,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected
                          ? _getSelectedGearColor()
                          : Colors.black)
                      .withValues(alpha: 0.35),
                  blurRadius: isSelected ? 8 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                  offset: isSelected ? Offset.zero : const Offset(0, 2),
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
                          color: Colors.white,
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

  Color _getSelectedGearColor() {
    if (currentGear == _reverseGearIndex) return Colors.red;
    switch (currentGear) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFallbackGearbox(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: _frameWidth,
      height: _frameHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[800]!, Colors.grey[900]!],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[600]!, width: 2),
      ),
      child: Center(
        child: Text(
          'GEARBOX',
          style: theme.labelMedium!.copyWith(
            color: Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
