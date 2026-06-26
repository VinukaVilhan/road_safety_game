import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/driving/game_level.dart';
import '../../services/content/driving_levels_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../theme/landscape_layout.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import 'level_selection_screen.dart';

/// Under Emergency Situations: open from "Emergency Vehicles", then pick Ambulance (etc.).
class EmergencyVehiclesCategoryScreen extends StatefulWidget {
  const EmergencyVehiclesCategoryScreen({super.key});

  @override
  State<EmergencyVehiclesCategoryScreen> createState() =>
      _EmergencyVehiclesCategoryScreenState();
}

class _EmergencyVehiclesCategoryScreenState
    extends State<EmergencyVehiclesCategoryScreen> {
  late final TextStyle _headerStyle;
  late final TextStyle _titleStyle;
  late final TextStyle _descStyle;

  @override
  void initState() {
    super.initState();
    _headerStyle = AppFonts.pixelifySans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: SwissTheme.textPrimary,
    );
    _titleStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _descStyle = AppFonts.pixelifySans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrowseScreenHeader(
              title: 'EMERGENCY VEHICLES',
              titleStyle: _headerStyle,
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_emergency_vehicles_categories',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Emergency vehicles — choose scenario',
                drivingTopic: DrivingTopic.EmergencySituations,
                levelIdsForReportDigest: DrivingLevelsService
                    .getEmergencySituationsLevelsForModule(
                  DrivingLevelsService.emergencyModuleVehicles,
                )
                    .map((e) => e.id)
                    .toList(),
                includeFullRoadSignCatalog: true,
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: Padding(
                padding: LandscapeLayout.bodyPadding(context),
                child: GridView.builder(
                  cacheExtent: 200,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  gridDelegate: LandscapeLayout.selectionGridDelegate(context),
                  itemCount: 1,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _ambulanceCard(),
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

  Widget _ambulanceCard() {
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LevelSelectionScreen(
              topic: DrivingTopic.EmergencySituations,
              emergencySituationsModuleId: DrivingLevelsService.emergencyModuleVehicles,
              headerTitleOverride: 'EMERGENCY VEHICLES',
            ),
          ),
        );
      },
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
              const Icon(
                Icons.local_hospital_outlined,
                size: 36,
                color: SwissTheme.textPrimary,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AMBULANCE',
                    style: _titleStyle.copyWith(color: SwissTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yield when an ambulance approaches with sirens; clear the lane safely.',
                    style: _descStyle.copyWith(color: SwissTheme.textSecondary),
                    softWrap: true,
                    maxLines: null,
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
}
