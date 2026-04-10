import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../models/game_level.dart';
import 'junctions_category_screen.dart';
import 'level_selection_screen.dart';
import 'road_markings_category_screen.dart';
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
    
    // Defer orientation change to avoid blocking UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
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

  // All available driving topics
  final List<DrivingTopic> topics = [
    DrivingTopic.Practice,
    DrivingTopic.Junctions,
    DrivingTopic.RoadMarkings,
    DrivingTopic.RoadSigns,
    DrivingTopic.EmergencySituations,
    DrivingTopic.Parking,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
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
                    onPressed: () => Navigator.pop(context),
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
                    return RepaintBoundary(
                      child: _buildTopicCard(topic),
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

  Widget _buildTopicCard(DrivingTopic topic) {
    return GestureDetector(
      onTap: () => _selectTopic(topic),
      child: Container(
        decoration: BoxDecoration(
          color: SwissTheme.backgroundWhite,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section: Icon
              Icon(
                topic.icon,
                size: 36,
                color: SwissTheme.textPrimary,
              ),
              
              const Spacer(),
              
              // Bottom section: Title and description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topic.displayName,
                    style: _topicTitleStyle.copyWith(
                      color: SwissTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.description,
                    style: _topicDescriptionStyle.copyWith(
                      color: SwissTheme.textSecondary,
                    ),
                    softWrap: true,
                    maxLines: null, // Allow unlimited lines
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTopic(DrivingTopic topic) {
    if (topic == DrivingTopic.Junctions) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JunctionsCategoryScreen(),
        ),
      );
      return;
    }
    if (topic == DrivingTopic.RoadMarkings) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RoadMarkingsCategoryScreen(),
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
