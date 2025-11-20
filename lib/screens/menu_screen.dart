import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/swiss_theme.dart';
import 'test_selection_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Force portrait orientation for menu
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut, // Documentary feel, no elastic
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Allow all orientations when leaving menu
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section (Top 40%)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Typographic Logo
                      Text(
                        'ROAD\nRULES',
                        style: GoogleFonts.inter(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          height: 0.9, // Tight line height
                          letterSpacing: -1.0,
                          color: SwissTheme.textPrimary,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Thick horizontal red line
                      Container(
                        width: double.infinity,
                        height: 5,
                        color: SwissTheme.accentRed,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Menu Actions Section (Bottom 60%)
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      
                      // Menu Item 01 - PLAY
                      _buildMenuButton(
                        '01',
                        'PLAY',
                        () => _startGame(context),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Menu Item 02 - OPTIONS
                      _buildMenuButton(
                        '02',
                        'OPTIONS',
                        () => _showOptions(context),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Menu Item 03 - QUIT
                      _buildMenuButton(
                        '03',
                        'QUIT',
                        () => _quitGame(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(String number, String text, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.zero, // Sharp corners
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Row(
            children: [
              Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: SwissTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: SwissTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TestSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: SwissTheme.backgroundWhite,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: SwissTheme.borderBlack, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPTIONS',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                
                // Sound Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SOUND',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: SwissTheme.textPrimary,
                      ),
                    ),
                    Switch(
                      value: true,
                      activeColor: SwissTheme.accentRed,
                      onChanged: (bool value) {
                        // Handle sound toggle
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Vibration Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VIBRATION',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: SwissTheme.textPrimary,
                      ),
                    ),
                    Switch(
                      value: true,
                      activeColor: SwissTheme.accentRed,
                      onChanged: (bool value) {
                        // Handle vibration toggle
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                
                // Close Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SwissTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'CLOSE',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SwissTheme.accentRed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _quitGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: SwissTheme.backgroundWhite,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: SwissTheme.borderBlack, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUIT GAME',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  'Are you sure you want to quit?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: SwissTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: SwissTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        SystemNavigator.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: SwissTheme.accentRed,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'QUIT',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SwissTheme.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
