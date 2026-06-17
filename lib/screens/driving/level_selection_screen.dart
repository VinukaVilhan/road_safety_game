import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../models/driving/game_level.dart';
import '../../services/content/driving_levels_service.dart';
import '../../services/progress/level_progress_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/progress/last_driving_report_service.dart';
import '../../widgets/last_driving_report_dialog.dart';
import 'game_screen.dart';
import 'emergency_vehicles_category_screen.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../widgets/assistant_button.dart';

class LevelSelectionScreen extends StatefulWidget {
  final DrivingTopic? topic; // Optional: if null, shows all levels (backward compatible)

  /// When set with [topic] == [DrivingTopic.Junctions], only levels in this module are listed
  /// (T-junctions, cross junctions, or roundabouts).
  final String? junctionsModuleId;

  /// When set with [topic] == [DrivingTopic.RoadMarkings], only levels in this module are listed
  /// (lane lines or other markings).
  final String? roadMarkingsModuleId;

  /// When set with [topic] == [DrivingTopic.EmergencySituations], only levels in this module are listed
  /// (e.g. ambulance under Emergency Vehicles).
  final String? emergencySituationsModuleId;

  /// Screen title (e.g. "T-JUNCTIONS") when showing a junctions submodule.
  final String? headerTitleOverride;

  const LevelSelectionScreen({
    super.key,
    this.topic,
    this.junctionsModuleId,
    this.roadMarkingsModuleId,
    this.emergencySituationsModuleId,
    this.headerTitleOverride,
  });

  @override
  LevelSelectionScreenState createState() => LevelSelectionScreenState();
}

class LevelSelectionScreenState extends State<LevelSelectionScreen> {
  static const Set<String> _underDevelopmentRoadMarkingsLevelIds = {
    'markings_stop_yield', // Level 03
    'markings_bus_lanes', // Level 05 — bus lanes & special zones
    'markings_complex', // Level 06
  };

  static const Set<String> _underDevelopmentEmergencySituationsLevelIds = {
    'emergency_braking',
    'emergency_breakdown',
    'emergency_weather',
  };

  // Cache font styles to avoid recreating them on every build
  late final TextStyle _headerStyle;
  late final TextStyle _levelNumberStyle;
  late final TextStyle _levelTitleStyle;
  late final TextStyle _dialogTitleStyle;
  late final TextStyle _dialogBodyStyle;
  late final TextStyle _dialogButtonStyle;

  // Track completed levels from Firebase.
  Set<String> completedLevelIds = {};

  /// Levels with a saved "last run" summary (document icon on card).
  Set<String> _levelIdsWithReport = {};

  @override
  void initState() {
    super.initState();
    
    // Cache font styles once during initialization
    _headerStyle = AppFonts.pixelifySans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: SwissTheme.textPrimary,
    );
    _levelNumberStyle = AppFonts.pixelifySans(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: -1.0,
    );
    _levelTitleStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
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
      color: SwissTheme.accentBlue,
    );
    
    // Defer orientation change to avoid blocking UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });

    _loadCompletedLevels();
    unawaited(_refreshSavedDrivingReports());
  }

  @override
  void dispose() {
    // Allow all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // Get levels based on topic (or all levels if topic is null)
  List<GameLevel> get levels {
    if (widget.topic == null) {
      return [];
    }
    if (widget.junctionsModuleId != null &&
        widget.junctionsModuleId!.trim().isNotEmpty) {
      return DrivingLevelsService.getJunctionsLevelsForModule(
        widget.junctionsModuleId!.trim(),
      );
    }
    if (widget.topic == DrivingTopic.RoadMarkings &&
        widget.roadMarkingsModuleId != null &&
        widget.roadMarkingsModuleId!.trim().isNotEmpty) {
      return DrivingLevelsService.getRoadMarkingsLevelsForModule(
        widget.roadMarkingsModuleId!.trim(),
      );
    }
    if (widget.topic == DrivingTopic.EmergencySituations &&
        widget.emergencySituationsModuleId != null &&
        widget.emergencySituationsModuleId!.trim().isNotEmpty) {
      return DrivingLevelsService.getEmergencySituationsLevelsForModule(
        widget.emergencySituationsModuleId!.trim(),
      );
    }
    var list = DrivingLevelsService.getLevelsForTopic(widget.topic!);
    if (widget.topic == DrivingTopic.EmergencySituations) {
      list = list
          .where(
            (l) => l.moduleId != DrivingLevelsService.emergencyModuleVehicles,
          )
          .toList();
    }
    return list;
  }

  bool _isUnderDevelopmentLevel(GameLevel level) {
    if (level.topic == DrivingTopic.Parking ||
        level.topic == DrivingTopic.RoadSigns) {
      return true;
    }
    if (level.topic == DrivingTopic.RoadMarkings &&
        _underDevelopmentRoadMarkingsLevelIds.contains(level.id)) {
      return true;
    }
    if (level.topic == DrivingTopic.EmergencySituations &&
        _underDevelopmentEmergencySituationsLevelIds.contains(level.id)) {
      return true;
    }
    return false;
  }

  /// Big number on level cards: 01, 02 within a junctions submodule; otherwise [GameLevel.topicLevel].
  int displayLevelNumber(GameLevel level) {
    if (widget.junctionsModuleId != null &&
        widget.junctionsModuleId!.trim().isNotEmpty) {
      final i = levels.indexOf(level);
      return i >= 0 ? i + 1 : level.topicLevel;
    }
    if (widget.topic == DrivingTopic.RoadMarkings &&
        widget.roadMarkingsModuleId != null &&
        widget.roadMarkingsModuleId!.trim().isNotEmpty) {
      final i = levels.indexOf(level);
      return i >= 0 ? i + 1 : level.topicLevel;
    }
    if (widget.topic == DrivingTopic.EmergencySituations &&
        widget.emergencySituationsModuleId != null &&
        widget.emergencySituationsModuleId!.trim().isNotEmpty) {
      final i = levels.indexOf(level);
      return i >= 0 ? i + 1 : level.topicLevel;
    }
    return level.topicLevel;
  }

  // Get header title
  String get headerTitle {
    final override = widget.headerTitleOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    if (widget.topic != null) {
      return widget.topic!.displayName;
    }
    return 'SELECT LEVEL';
  }

  @override
  Widget build(BuildContext context) {
    final levelIds = levels.map((e) => e.id).toList();
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        heroTag: 'assistant_level_select',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Level list — $headerTitle',
          drivingTopic: widget.topic,
          levelIdsForReportDigest: levelIds,
          includeFullRoadSignCatalog: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_sharp,
                      color: SwissTheme.textPrimary,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: _headerStyle,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            
            // Level Grid - Optimized for performance
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: levels.isEmpty
                    ? Center(
                        child: Text(
                          'No levels available',
                          style: AppFonts.pixelifySans(
                            fontSize: 14,
                            color: SwissTheme.textSecondary,
                          ),
                        ),
                      )
                    : GridView.builder(
                        cacheExtent: 200,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                          childAspectRatio: 0.70, // Slightly taller to accommodate more text
                        ),
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          final level = levels[index];
                          final isUnderDevelopment = _isUnderDevelopmentLevel(level);
                          // Check unlock status based on completed levels
                          final isUnlocked = !isUnderDevelopment &&
                              DrivingLevelsService.isLevelUnlocked(
                                level,
                                completedLevelIds,
                              );
                          return RepaintBoundary(
                            child: _buildLevelCard(
                              level,
                              isUnlocked,
                              underDevelopment: isUnderDevelopment,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    GameLevel level,
    bool isUnlocked, {
    bool underDevelopment = false,
  }) {
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        if (isUnlocked) {
          _startGame(level);
        } else {
          _showLockedLevelDialog(level);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? SwissTheme.backgroundWhite : SwissTheme.backgroundLightGrey,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Locked overlay pattern
            if (!isUnlocked)
              Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HatchingPainter(),
                ),
              ),
            
            // Card content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Level number and difficulty indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Giant level number (top left) - use topicLevel instead of number
                      Text(
                        displayLevelNumber(level).toString().padLeft(2, '0'),
                        style: _levelNumberStyle.copyWith(
                          color: isUnlocked 
                            ? SwissTheme.textSecondary.withOpacity(0.5)
                            : SwissTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      
                      // Difficulty circle (top right) - only for unlocked levels
                      if (isUnlocked)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(level.difficulty),
                            shape: BoxShape.circle,
                          ),
                        ),
                      
                      // Lock icon (center) - only for locked levels
                      if (!isUnlocked)
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.lock_outline,
                              color: SwissTheme.textPrimary,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Title and description (bottom left)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        level.name.toUpperCase(),
                        style: _levelTitleStyle.copyWith(
                          color: isUnlocked 
                            ? SwissTheme.textPrimary
                            : SwissTheme.textSecondary.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Description (smaller text)
                      Text(
                        level.description,
                        style: SwissTheme.monospacedText.copyWith(
                          fontSize: 10,
                          color: isUnlocked
                            ? SwissTheme.textSecondary
                            : SwissTheme.textSecondary.withOpacity(0.4),
                        ),
                        softWrap: true,
                        maxLines: null, // Allow unlimited lines
                        overflow: TextOverflow.clip,
                      ),
                      if (underDevelopment && !isUnlocked) ...[
                        const SizedBox(height: 6),
                        Text(
                          'UNDER DEVELOPMENT',
                          style: AppFonts.pixelifySans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: SwissTheme.accentOrange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_levelIdsWithReport.contains(level.id))
              Positioned(
                top: 4,
                right: 4,
                child: _lastRunDocButton(level),
              ),
          ],
        ),
      ),
    );
  }

  Widget _lastRunDocButton(GameLevel level) {
    return Tooltip(
      message: 'Last run summary',
      child: Material(
        color: SwissTheme.backgroundWhite,
        shape: const CircleBorder(
          side: BorderSide(color: SwissTheme.borderBlack, width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            UiSoundService().playMenuTap();
            final report = await LastDrivingReportService.instance.loadReportForLevel(level.id);
            if (!mounted || report == null) return;
            showLastDrivingReportDialog(context, report);
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.description_outlined,
              size: 18,
              color: SwissTheme.accentBlue,
            ),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(LevelDifficulty difficulty) {
    switch (difficulty) {
      case LevelDifficulty.Easy:
        return SwissTheme.accentGreen;
      case LevelDifficulty.Medium:
        return SwissTheme.accentOrange;
      case LevelDifficulty.Hard:
        return SwissTheme.accentRed;
      case LevelDifficulty.Extreme:
        return SwissTheme.accentRed;
    }
  }

  Future<void> _loadCompletedLevels() async {
    try {
      final ids = await LevelProgressService.getCompletedLevelIds();
      if (!mounted) return;
      setState(() {
        completedLevelIds = ids;
      });
    } catch (_) {
      // Keep UI usable even if progress fetch fails.
    }
  }

  Future<void> _refreshSavedDrivingReports() async {
    try {
      await LastDrivingReportService.instance.mergeRemoteSummariesIfSignedIn();
      final ids = await LastDrivingReportService.instance.levelIdsWithSavedReports();
      if (!mounted) return;
      setState(() => _levelIdsWithReport = ids);
    } catch (_) {
      if (mounted) setState(() => _levelIdsWithReport = {});
    }
  }

  Future<void> _startGame(GameLevel level) async {
    final map = level.mapAsset?.trim();
    if (widget.topic == DrivingTopic.EmergencySituations &&
        level.id == 'emergency_vehicles' &&
        (map == null || map.isEmpty)) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const EmergencyVehiclesCategoryScreen(),
        ),
      );
      await _loadCompletedLevels();
      await _refreshSavedDrivingReports();
      return;
    }

    // Use MaterialPageRoute for better performance
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(level: level),
      ),
    );

    if (!mounted) return;

    if (result is String && result.isNotEmpty) {
      setState(() {
        completedLevelIds.add(result);
      });
    }

    await _loadCompletedLevels();
    await _refreshSavedDrivingReports();
    unawaited(LevelProgressService.uploadLocalCompletedLevelsToFirestore());
  }

  void _showLockedLevelDialog(GameLevel level) {
    String unlockMessage = 'Complete the previous levels to unlock "${level.name}".';

    if (_isUnderDevelopmentLevel(level)) {
      unlockMessage = '"${level.name}" is under development.';
    } else if (level.unlockRequirementIds.isNotEmpty) {
      // Resolve names from the full topic so cross-module prerequisites still show correctly.
      final pool = widget.topic != null
          ? DrivingLevelsService.getLevelsForTopic(widget.topic!)
          : levels;
      final requiredLevels = pool
          .where((l) => level.unlockRequirementIds.contains(l.id))
          .map((l) => l.name)
          .toList();
      
      if (requiredLevels.isNotEmpty) {
        unlockMessage = 'Complete "${requiredLevels.join('" and "')}" to unlock this level.';
      }
    }

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
                  'LEVEL LOCKED',
                  style: _dialogTitleStyle,
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  unlockMessage,
                  style: _dialogBodyStyle,
                ),
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: SwissTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'OK',
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
  }
}

/// Custom painter for hatching pattern on locked levels
class HatchingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SwissTheme.textSecondary.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw diagonal hatching lines
    const spacing = 8.0;
    final diagonalLength = (size.width + size.height);
    
    for (double i = -diagonalLength; i < diagonalLength; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
