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
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background gearbox image
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 140,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800], // Fallback color
                borderRadius: BorderRadius.circular(15),
              ),
              child: Image.asset(
                'assets/images/Gearbox.PNG', // Your gearbox image
                width: 140,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback UI if image fails to load
                  return _buildFallbackGearbox();
                },
              ),
            ),
          ),
          
          // Gear position overlays
          _buildGearPositionOverlays(),
          
          // Current gear indicator (gear stick position)
          _buildGearStickIndicator(),
          
          // Gear label display
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getGearColor(),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  'GEAR: ${gears[currentGear]}',
                  style: TextStyle(
                    color: _getGearColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
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
          left: 25,
          top: 50,
          label: 'R',
        ),
        
        // First Gear (1) - Top Right
        _buildGearHotspot(
          gear: 1, // 1st gear position
          left: 85,
          top: 50,
          label: '1',
        ),
        
        // Second Gear (2) - Below 1st
        _buildGearHotspot(
          gear: 2,
          left: 85,
          top: 80,
          label: '2',
        ),
        
        // Third Gear (3) - Center Left
        _buildGearHotspot(
          gear: 3,
          left: 45,
          top: 95,
          label: '3',
        ),
        
        // Fourth Gear (4) - Center Right
        _buildGearHotspot(
          gear: 4,
          left: 85,
          top: 110,
          label: '4',
        ),
        
        // Fifth Gear (5) - Bottom Right
        _buildGearHotspot(
          gear: 5,
          left: 85,
          top: 140,
          label: '5',
        ),
        
        // Park (P) - Bottom Center
        _buildGearHotspot(
          gear: 0, // P position
          left: 55,
          top: 160,
          label: 'P',
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
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: isSelected ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGearStickIndicator() {
    // Calculate gear stick position based on current gear
    final gearPosition = _getGearStickPosition();
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: gearPosition.dx - 8, // Center the stick
      top: gearPosition.dy - 15, // Position above the hotspot
      child: Container(
        width: 16,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[600]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getGearColor(),
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  // Helper method to get gear stick position based on current gear
  Offset _getGearStickPosition() {
    switch (currentGear) {
      case 0: return const Offset(55 + 16, 160 + 16); // Park
      case 1: return const Offset(85 + 16, 50 + 16);  // 1st
      case 2: return const Offset(85 + 16, 80 + 16);  // 2nd
      case 3: return const Offset(45 + 16, 95 + 16);  // 3rd
      case 4: return const Offset(85 + 16, 110 + 16); // 4th
      case 5: return const Offset(85 + 16, 140 + 16); // 5th
      case 6: return const Offset(25 + 16, 50 + 16);  // Reverse
      default: return const Offset(55 + 16, 160 + 16); // Default to Park
    }
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
  Widget _buildFallbackGearbox() {
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
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
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