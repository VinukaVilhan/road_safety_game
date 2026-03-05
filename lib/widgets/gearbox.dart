import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Container(
      width: 120,
      height: 180,
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
                'assets/images/rescaled/gearbox_cubic.png',
                width: 140,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to load gearbox image: assets/images/rescaled/gearbox_cubic.png');
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

  Widget _buildGearPositionOverlays() {
    return Stack(
      children: [
        // Reverse (R) - Top Left
        _buildGearHotspot(
          gear: 6, // R position in array
          left: 15,
          top: 51,
          label: gears[6],
        ),
        
        // First Gear (1) - Top Right
        _buildGearHotspot(
          gear: 1, // 1st gear position
          left: 46,
          top: 51,
          label: gears[1],
        ),
        
        // Second Gear (2) - Below 1st
        _buildGearHotspot(
          gear: 2,
          left: 77,
          top: 51,
          label: gears[2],
        ),
        
        // Third Gear (3) - Center Left
        _buildGearHotspot(
          gear: 3,
          left: 15,
          top: 100,
          label: gears[3],
        ),
        
        // Fourth Gear (4) - Center Right
        _buildGearHotspot(
          gear: 4,
          left: 46,
          top: 100,
          label: gears[4],
        ),
        
        // Park (P) - Bottom Center
        _buildGearHotspot(
          gear: 0, // P position
          left: 77,
          top: 100,
          label: gears[0],
        ),
      ],
    );
  }

  Widget _buildGearHotspot({
    required int gear,
    required double left,
    required double top,
    required String label,
  }) {
    final bool isSelected = currentGear == gear;
    
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _selectGear(gear),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: isSelected ? 32 : 28,
          height: isSelected ? 32 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected 
              ? _getGearColor().withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.3),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.grey[400]!,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: _getGearColor().withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : [
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
                  style: (isSelected ? theme.titleSmall : theme.labelMedium)!.copyWith(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }


  // Helper method to get gear-specific colors
  Color _getGearColor() {
    switch (currentGear) {
      case 0: return Colors.orange;    // Park
      case 6: return Colors.red;       // Reverse
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