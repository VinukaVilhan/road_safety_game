import 'package:flutter/material.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/assistant_button.dart';
import '../../models/driving/game_level.dart';
import 'junctions_category_screen.dart';
import 'level_selection_screen.dart';
import 'driving_tutorial_screen.dart';

class DrivingTopicSelectionScreen extends StatefulWidget {
  const DrivingTopicSelectionScreen({super.key});

  @override
  State<DrivingTopicSelectionScreen> createState() => _DrivingTopicSelectionScreenState();
}

class _DrivingTopicSelectionScreenState extends State<DrivingTopicSelectionScreen> {
  // Cache font styles to avoid recreating them on every build
  late final TextStyle _headerStyle;
  late final TextStyle _topicTitleStyle;
  late final TextStyle _topicDescriptionStyle;
  late final TextStyle _dialogTitleStyle;
  late final TextStyle _dialogBodyStyle;
  late final TextStyle _dialogButtonStyle;

  static bool _isUnderDevelopmentTopic(DrivingTopic topic) {
    /// [Practice]: controls tutorial module (Driving test → CONTROLS), not in-game HUD.
    /// [Parking]: practical parking scenarios not ready yet.
    /// [RoadSigns]: practical road-sign levels not ready yet.
    return topic == DrivingTopic.Practice ||
        topic == DrivingTopic.Parking ||
        topic == DrivingTopic.RoadSigns;
  }

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
    _topicTitleStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _topicDescriptionStyle = AppFonts.pixelifySans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
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
  }

  // All available driving topics
  final List<DrivingTopic> topics = [
    DrivingTopic.Practice,
    DrivingTopic.Junctions,
    DrivingTopic.RoadMarkings,
    DrivingTopic.RoadSigns,
    DrivingTopic.EmergencySituations,
    DrivingTopic.WeatherConditions,
    DrivingTopic.Parking,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: const AssistantButton(
        heroTag: 'assistant_driving_topics',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Driving test — choose topic',
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
                  Text(
                    'DRIVING TEST',
                    style: _headerStyle,
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),

            // Topic Grid - Optimized for performance
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  cacheExtent: 200,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                    childAspectRatio: 0.70, // Slightly taller to accommodate more text
                  ),
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    final topic = topics[index];
                    final underDevelopment = _isUnderDevelopmentTopic(topic);
                    return RepaintBoundary(
                      child: _buildTopicCard(
                        topic,
                        underDevelopment: underDevelopment,
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

  Widget _buildTopicCard(
    DrivingTopic topic, {
    required bool underDevelopment,
  }) {
    final isUnlocked = !underDevelopment;
    return GestureDetector(
      onTap: () => _selectTopic(topic),
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
            if (!isUnlocked)
              Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HatchingPainter(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        topic.icon,
                        size: 36,
                        color: isUnlocked
                            ? SwissTheme.textPrimary
                            : SwissTheme.textSecondary.withOpacity(0.5),
                      ),
                      if (!isUnlocked)
                        Icon(
                          Icons.lock_outline,
                          color: SwissTheme.textPrimary,
                          size: 28,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topic.displayName,
                        style: _topicTitleStyle.copyWith(
                          color: isUnlocked
                              ? SwissTheme.textPrimary
                              : SwissTheme.textSecondary.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic.description,
                        style: _topicDescriptionStyle.copyWith(
                          color: isUnlocked
                              ? SwissTheme.textSecondary
                              : SwissTheme.textSecondary.withOpacity(0.4),
                        ),
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.clip,
                      ),
                      if (underDevelopment) ...[
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
          ],
        ),
      ),
    );
  }

  void _showUnderDevelopmentTopicDialog(DrivingTopic topic) {
    showDialog<void>(
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
                  'MODULE LOCKED',
                  style: _dialogTitleStyle,
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  '"${topic.displayName}" is under development.',
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

  void _selectTopic(DrivingTopic topic) {
    UiSoundService().playMenuTap();
    if (_isUnderDevelopmentTopic(topic)) {
      _showUnderDevelopmentTopicDialog(topic);
      return;
    }
    if (topic == DrivingTopic.Junctions) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JunctionsCategoryScreen(),
        ),
      );
      return;
    }
    if (topic == DrivingTopic.Practice) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DrivingTutorialScreen(),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LevelSelectionScreen(topic: topic),
      ),
    );
  }
}
