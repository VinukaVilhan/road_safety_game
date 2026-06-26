import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import 'road_signs_modules_screen.dart';

/// Lists control-sign subcategories (restrictive, boundary, etc.).
class RoadSignsSubgroupsScreen extends StatelessWidget {
  final RoadSignsGroup group;

  const RoadSignsSubgroupsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final subs = List<RoadSignsSubgroup>.from(group.subgroups)
      ..sort((a, b) => a.order.compareTo(b.order));
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrowseScreenHeader(
              title: group.title.toUpperCase(),
              titleStyle: AppFonts.pixelifySans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: SwissTheme.textPrimary,
              ),
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_road_signs_subgroups',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Road signs — ${group.title}',
                includeFullRoadSignCatalog: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                group.description,
                style: SwissTheme.monospacedText.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: subs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final sg = subs[i];
                  return _SubgroupTile(
                    title: sg.title,
                    description: sg.description,
                    onTap: () {
                      UiSoundService().playMenuTap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoadSignsModulesScreen(
                            group: group,
                            subgroup: sg,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubgroupTile extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SubgroupTile({
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwissTheme.backgroundWhite,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: SwissTheme.borderBlack, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppFonts.pixelifySans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SwissTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: SwissTheme.monospacedText.copyWith(fontSize: 11, color: SwissTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
