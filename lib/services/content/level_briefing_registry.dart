import '../../models/driving/game_level.dart';
import '../../models/driving/level_briefing.dart';

/// Resolves pre-level briefing slides for practical driving levels.
///
/// Lookup order: [GameLevel.id] override → [GameLevel.scenarioId] → default
/// (name + description) for rules-enabled levels with a map.
class LevelBriefingRegistry {
  LevelBriefingRegistry._();

  static const Map<String, LevelBriefing> _byLevelId = {
    'markings_junction_box': LevelBriefing(
      headline: 'Junction Box — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body:
              'Cross this junction using the hatched junction box correctly — '
              'enter only when you can clear it without stopping inside.',
        ),
        LevelBriefingSlide(
          title: 'Zones',
          body:
              'Yellow approach → turn through the junction → green finish. '
              'Use the coloured zones in order.',
        ),
        LevelBriefingSlide(
          title: 'Junction box rule',
          body:
              'Do not stop inside the hatched box. Enter only when your exit is clear. '
              'Red fail zones end the level immediately.',
        ),
      ],
    ),
  };

  static const Map<String, LevelBriefing> _byScenarioId = {
    't_junction_left': LevelBriefing(
      headline: 'Left Turn — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body: 'Approach and complete a safe left turn at this T-junction.',
        ),
        LevelBriefingSlide(
          title: 'Zones',
          body:
              'Yellow approach → purple mid-turn check → green finish. '
              'Complete each step in order.',
        ),
        LevelBriefingSlide(
          title: 'Signals & fails',
          body:
              'Turn on your left indicator before the turn. '
              'Entering a red wrong-turn or oncoming-traffic zone ends the level.',
        ),
      ],
    ),
    't_junction_right': LevelBriefing(
      headline: 'Right Turn — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body: 'Approach and complete a safe right turn at this T-junction.',
        ),
        LevelBriefingSlide(
          title: 'Zones',
          body:
              'Yellow approach → purple mid-turn check → green finish. '
              'Complete each step in order.',
        ),
        LevelBriefingSlide(
          title: 'Signals & fails',
          body:
              'Turn on your right indicator before the turn. '
              'Entering a red wrong-turn or oncoming-traffic zone ends the level.',
        ),
      ],
    ),
    'cross_junction_basics': LevelBriefing(
      headline: 'Cross Junction — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body: 'Drive through this four-way crossing without traffic lights.',
        ),
        LevelBriefingSlide(
          title: 'Zones',
          body:
              'Yellow approach → turn zone → green finish. '
              'Signal correctly for the path you take.',
        ),
        LevelBriefingSlide(
          title: 'Stay safe',
          body:
              'Keep to a safe speed in the approach zone. '
              'Red fail zones end the level immediately.',
        ),
      ],
    ),
    'markings_solid': LevelBriefing(
      headline: 'Solid Lines — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body: 'Drive along lanes marked with solid centre and lane lines.',
        ),
        LevelBriefingSlide(
          title: 'Stay in lane',
          body:
              'Do not cross solid lines. Stay inside your lane through the course.',
        ),
        LevelBriefingSlide(
          title: 'Finish',
          body:
              'Complete the route and reach the green finish zone. '
              'Wrong-layer penalties apply if you leave the correct lane.',
        ),
      ],
    ),
    'markings_dashed': LevelBriefing(
      headline: 'Dashed Lines — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body: 'Drive along lanes marked with dashed centre and lane lines.',
        ),
        LevelBriefingSlide(
          title: 'Lane changes',
          body:
              'Dashed lines allow lane changes when safe. '
              'Stay in the correct lane unless the route requires a change.',
        ),
        LevelBriefingSlide(
          title: 'Finish',
          body:
              'Reach the green finish zone. '
              'Crossing into a wrong lane records a penalty.',
        ),
      ],
    ),
    'markings_stop_yield': LevelBriefing(
      headline: 'Stop & Yield Lines — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body:
              'Practice stopping before the crossing and yielding correctly.',
        ),
        LevelBriefingSlide(
          title: 'Approach',
          body:
              'Enter the yellow approach zone at a safe speed — '
              'slow to 60 or below.',
        ),
        LevelBriefingSlide(
          title: 'Stop in the grey zone',
          body:
              'Stop fully in gear inside the grey zig-zag zone. '
              'Do not use Park (P).',
        ),
        LevelBriefingSlide(
          title: 'Wrong turn',
          body:
              'Do not drive past the stop line into the red wrong-turn zone — '
              'that fails the level immediately.',
        ),
      ],
    ),
    'markings_zebra_crossing': LevelBriefing(
      headline: 'Zebra Crossing — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'School-zone crossing',
          body:
              'You are driving through a busy school-zone crossing. '
              'A pedestrian may step onto the zebra at any moment.',
        ),
        LevelBriefingSlide(
          title: 'Approach & wait',
          body:
              'Slow down and enter the approach zone safely. '
              'Stop fully in gear (no Park) and wait in the grey zig-zag zone.',
        ),
        LevelBriefingSlide(
          title: 'Cross & finish',
          body:
              'Cross straight ahead through the zebra — do not continue past the stop line. '
              'Finish in the green zone.',
        ),
        LevelBriefingSlide(
          title: 'Instant fail',
          body:
              'Entering the red wrong-turn area ends the level immediately.',
        ),
      ],
    ),
    'emergency_weather': LevelBriefing(
      headline: 'Adverse Weather — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Heavy rain',
          body:
              'Rain has reduced grip and visibility on this cross junction.',
        ),
        LevelBriefingSlide(
          title: 'Slow down',
          body:
              'Wet roads need much longer stopping distances. '
              'Keep below a safe speed for the conditions (about 72 km/h equivalent).',
        ),
        LevelBriefingSlide(
          title: 'Steer smoothly',
          body:
              'Sharp turns can make the car slide. '
              'Complete the junction using the normal approach, turn, and finish zones.',
        ),
      ],
    ),
    'emergency_ambulance': LevelBriefing(
      headline: 'Ambulance — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Sirens on the way',
          body:
              'An ambulance can appear while you drive. '
              'Slow down and be ready to yield safely.',
        ),
        LevelBriefingSlide(
          title: 'Hit the early checkpoints',
          body: 'Reach Checkpoint 1 and Checkpoint 2 within the time limits.',
        ),
        LevelBriefingSlide(
          title: 'Signals and side',
          body:
              'Left safe strip: left indicator only. '
              'Right strip: right indicator only.',
        ),
        LevelBriefingSlide(
          title: 'Three steps to yield',
          body:
              'After Checkpoint 2, in order:\n'
              '1) Overlap the matching safe zone with the correct signal on (you may still be moving).\n'
              '2) Bring both wheels on that side fully inside the zone.\n'
              '3) Shift to Park (P). The ambulance will only pass after all three are done.',
        ),
        LevelBriefingSlide(
          title: 'When to pull over',
          body:
              'After you clear Checkpoint 2, finish your pull-over before you cross the final gate (CPF).',
        ),
        LevelBriefingSlide(
          title: 'While it passes',
          body:
              'Stay slow and yielded. The ambulance will pass you and follow its route.',
        ),
        LevelBriefingSlide(
          title: 'How you pass',
          body:
              'You complete the level when the ambulance reaches the success area and you remain correctly stopped and yielded.',
        ),
      ],
    ),
  };

  /// Returns a briefing when the level should show one; otherwise null.
  static LevelBriefing? resolve(GameLevel level) {
    if (!level.enableDrivingRules) return null;
    final map = level.mapAsset?.trim();
    if (map == null || map.isEmpty) return null;

    final byId = _byLevelId[level.id];
    if (byId != null) return byId;

    final scenario = level.scenarioId?.trim();
    if (scenario != null && scenario.isNotEmpty) {
      final byScenario = _byScenarioId[scenario];
      if (byScenario != null) return byScenario;
    }

    return _defaultBriefing(level);
  }

  static LevelBriefing _defaultBriefing(GameLevel level) {
    return LevelBriefing(
      headline: '${level.name} — briefing',
      slides: [
        LevelBriefingSlide(
          title: 'Your mission',
          body:
              '${level.description}\n\n'
              'Follow the coloured zones on the map and the examiner checklist.',
        ),
      ],
    );
  }
}
