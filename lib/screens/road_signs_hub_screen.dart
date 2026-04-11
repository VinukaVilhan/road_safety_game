import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_launch_context.dart';
import '../models/road_signs_curriculum.dart';
import '../services/road_signs_curriculum_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';
import 'road_signs_modules_screen.dart';
import 'road_signs_subgroups_screen.dart';

/// Top level: Warning signs vs Control signs (with subcategories).
class RoadSignsHubScreen extends StatefulWidget {
  const RoadSignsHubScreen({super.key});

  @override
  State<RoadSignsHubScreen> createState() => _RoadSignsHubScreenState();
}

class _RoadSignsHubScreenState extends State<RoadSignsHubScreen> {
  RoadSignsCurriculum? _curriculum;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await RoadSignsCurriculumService.instance.loadCurriculum();
      if (!mounted) return;
      setState(() {
        _curriculum = c;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        heroTag: 'assistant_road_signs_hub',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Road signs — categories',
          includeFullRoadSignCatalog: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 24, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_sharp, color: SwissTheme.textPrimary, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ROAD SIGNS',
                      style: AppFonts.pixelifySans(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: SwissTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Pick a category, then open study or MCQ modules inside each track.',
                style: SwissTheme.monospacedText.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load road signs curriculum.\n$_loadError',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
          ),
        ),
      );
    }
    final c = _curriculum;
    if (c == null) {
      return const Center(child: CircularProgressIndicator(color: SwissTheme.textPrimary));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: c.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = c.groups[i];
        return _GroupCard(
          group: g,
          onTap: () {
            UiSoundService().playMenuTap();
            if (g.hasSubgroups) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoadSignsSubgroupsScreen(group: g)),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoadSignsModulesScreen(group: g)),
              );
            }
          },
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final RoadSignsGroup group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = group.hasSubgroups
        ? '${group.subgroups.length} subcategories'
        : '${group.modules.length} modules';
    return Material(
      color: SwissTheme.backgroundWhite,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            border: Border.all(color: SwissTheme.borderBlack, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                group.hasSubgroups ? Icons.account_tree_outlined : Icons.warning_amber_outlined,
                size: 36,
                color: SwissTheme.textPrimary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title.toUpperCase(),
                      style: AppFonts.pixelifySans(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SwissTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.description,
                      style: SwissTheme.monospacedText.copyWith(fontSize: 11, color: SwissTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: SwissTheme.monospacedText.copyWith(fontSize: 10, color: SwissTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SwissTheme.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
