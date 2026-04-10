import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../services/level_progress_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../data/repositories/progress_repository.dart';
import '../services/image_preloader.dart';
import '../services/ui_sound_service.dart';
import 'test_selection_screen.dart';
import 'profile_screen.dart';
import 'driving_tutorial_screen.dart';
import 'music_folder_settings_screen.dart';

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Cache font styles to avoid recreating them on every build
  late final TextStyle _titleStyle;
  late final TextStyle _menuButtonNumberStyle;
  late final TextStyle _menuButtonTextStyle;
  late final TextStyle _dialogTitleStyle;
  late final TextStyle _dialogBodyStyle;
  late final TextStyle _dialogButtonStyle;
  late final TextStyle _dialogButtonSecondaryStyle;

  @override
  void initState() {
    super.initState();
    
    // Cache font styles once during initialization
    _titleStyle = AppFonts.pixelifySans(
      fontSize: 80,
      fontWeight: FontWeight.w900,
      height: 0.9,
      letterSpacing: -1.0,
      color: SwissTheme.textPrimary,
    );
    _menuButtonNumberStyle = AppFonts.pixelifySans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    _menuButtonTextStyle = AppFonts.pixelifySans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    _dialogTitleStyle = AppFonts.pixelifySans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    _dialogBodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
    );
    _dialogButtonStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.accentRed,
    );
    _dialogButtonSecondaryStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textSecondary,
    );
    
    // Defer orientation change to avoid blocking UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Preload images after first frame to avoid blocking UI
      if (mounted) {
        ImagePreloader.preloadImages(context);
      }

      // Push local level completions to Firestore (same schema as sync outbox).
      unawaited(LevelProgressService.uploadLocalCompletedLevelsToFirestore());
    });
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced for faster perceived performance
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
              // Header Section (Top 40%) - Wrap in RepaintBoundary for performance
              Expanded(
                flex: 4,
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Typographic Logo
                        Text(
                          'ROAD\nRULES',
                          style: _titleStyle,
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
              ),
              
              // Menu Actions Section (Bottom 60%) - Wrap in RepaintBoundary for performance
              Expanded(
                flex: 6,
                child: RepaintBoundary(
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
                        
                        _buildMenuButton(
                          '02',
                          'CONTROLS',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DrivingTutorialScreen(),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Menu Item 03 - OPTIONS
                        _buildMenuButton(
                          '03',
                          'OPTIONS',
                          () => _showOptions(context),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Menu Item 04 - PROFILE
                        _buildMenuButton(
                          '04',
                          'PROFILE',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Menu Item 05 - QUIT
                        _buildMenuButton(
                          '05',
                          'QUIT',
                          () => _quitGame(context),
                        ),
                      ],
                    ),
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
        onTap: () {
          UiSoundService().playMenuTap();
          onPressed();
        },
        borderRadius: BorderRadius.zero, // Sharp corners
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Row(
            children: [
              Text(
                number,
                style: _menuButtonNumberStyle,
              ),
              const SizedBox(width: 16),
              Text(
                text,
                style: _menuButtonTextStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context) {
    // Use MaterialPageRoute for better performance - it's optimized by Flutter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TestSelectionScreen(),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final uiSound = UiSoundService();
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  style: _dialogTitleStyle,
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
                      style: _dialogBodyStyle,
                    ),
                    Switch(
                      value: uiSound.soundEnabled,
                      activeColor: SwissTheme.accentRed,
                      onChanged: (bool value) {
                        uiSound.playMenuToggle(playSfxEvenWhenSoundOff: true);
                        setDialogState(() => uiSound.soundEnabled = value);
                        unawaited(ProgressRepository.instance.saveSetting(
                          settingKey: 'sound_enabled',
                          value: value.toString(),
                        ));
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
                      style: _dialogBodyStyle,
                    ),
                    Switch(
                      value: uiSound.vibrationEnabled,
                      activeColor: SwissTheme.accentRed,
                      onChanged: (bool value) {
                        uiSound.playMenuToggle(playSfxEvenWhenSoundOff: true);
                        setDialogState(() => uiSound.vibrationEnabled = value);
                        unawaited(ProgressRepository.instance.saveSetting(
                          settingKey: 'vibration_enabled',
                          value: value.toString(),
                        ));
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 8),

                InkWell(
                  onTap: () {
                    uiSound.playMenuTap();
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const MusicFolderSettingsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MUSIC FOLDER',
                          style: _dialogBodyStyle,
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: SwissTheme.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                
                // Close Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      uiSound.playMenuTap();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: SwissTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'CLOSE',
                      style: _dialogButtonStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  void _quitGame(BuildContext context) {
    final uiSound = UiSoundService();
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
                  style: _dialogTitleStyle,
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  'Are you sure you want to quit?',
                  style: _dialogBodyStyle,
                ),
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        uiSound.playMenuTap();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: SwissTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'CANCEL',
                        style: _dialogButtonSecondaryStyle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        uiSound.playMenuTap();
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
                        style: _dialogButtonStyle,
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
