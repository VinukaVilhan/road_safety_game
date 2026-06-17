import '../../models/theory/mcq_question.dart';

/// Provides MCQ questions for road sign theory tests.
/// Questions reference assets in assets/roadsigns/ (see download script in scripts/).
class RoadSignsQuestionsService {
  /// Get questions for a given test ID. Returns a subset of size [count] if test specifies questionCount.
  static List<McqQuestion> getQuestionsForTest(String testId, {int? count}) {
    final all = _getAllRoadSignQuestions();
    final forTest = all.where((q) => _testIdToQuestionIds[testId]?.contains(q.id) ?? false).toList();
    if (forTest.isEmpty) {
      final roadSignsPools = _testIdToQuestionIds.keys;
      if (roadSignsPools.contains(testId)) {
        final take = count ?? 10;
        return all.take(take).toList();
      }
      return all.take(count ?? 10).toList();
    }
    final list = forTest.toList();
    if (count != null && list.length > count) {
      return list.take(count).toList();
    }
    return list;
  }

  static const String _assetPath = 'assets/roadsigns';

  /// All bundled road-sign MCQs (for AI assistant / reference text).
  static List<McqQuestion> allQuestionsForAssistant() => _getAllRoadSignQuestions();

  static List<McqQuestion> _getAllRoadSignQuestions() {
    return [
      // --- Warning signs ---
      McqQuestion(
        id: 'rs_stop',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/stop.png',
        options: ['Stop and give way to traffic', 'Slow down', 'No entry', 'One way'],
        correctIndex: 0,
      ),
      McqQuestion(
        id: 'rs_give_way',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/give_way.png',
        options: ['Stop here', 'Give way to traffic on the main road', 'No parking', 'Speed limit'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_slippery',
        questionText: 'What does this sign indicate?',
        imageAssetPath: '$_assetPath/slippery_road.png',
        options: ['Road under repair', 'Slippery road ahead', 'Steep hill', 'Falling rocks'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_children',
        questionText: 'What should you do when you see this sign?',
        imageAssetPath: '$_assetPath/children_crossing.png',
        options: ['Increase speed', 'Reduce speed and watch for children', 'Honk continuously', 'Park here'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_cattle',
        questionText: 'This sign warns you of:',
        imageAssetPath: '$_assetPath/cattle.png',
        options: ['Zoo ahead', 'Farm produce sale', 'Animals on the road', 'No animals allowed'],
        correctIndex: 2,
      ),
      McqQuestion(
        id: 'rs_curve_left',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/curve_left.png',
        options: ['Turn left only', 'Sharp curve to the left ahead', 'Roundabout', 'Merge left'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_curve_right',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/curve_right.png',
        options: ['Turn right only', 'Sharp curve to the right ahead', 'No right turn', 'Keep right'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_road_works',
        questionText: 'This sign indicates:',
        imageAssetPath: '$_assetPath/road_works.png',
        options: ['Factory area', 'Road works ahead', 'Parking zone', 'School zone'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_pedestrian_crossing',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/pedestrian_crossing.png',
        options: ['No pedestrians', 'Pedestrian crossing ahead', 'Walking path only', 'Bus stop'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_level_crossing',
        questionText: 'This sign warns of:',
        imageAssetPath: '$_assetPath/level_crossing.png',
        options: ['Bridge ahead', 'Railway crossing ahead', 'Tunnel', 'Ferry crossing'],
        correctIndex: 1,
      ),
      // --- Regulatory signs ---
      McqQuestion(
        id: 'rs_no_entry',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/no_entry.png',
        options: ['No parking', 'No entry for vehicles', 'One way', 'Stop'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_speed_50',
        questionText: 'What is the maximum speed indicated by this sign?',
        imageAssetPath: '$_assetPath/speed_50.png',
        options: ['30 km/h', '50 km/h', '80 km/h', '100 km/h'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_no_parking',
        questionText: 'This sign means:',
        imageAssetPath: '$_assetPath/no_parking.png',
        options: ['Parking allowed', 'No parking', 'Parking for disabled only', 'Free parking'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_no_overtaking',
        questionText: 'What does this sign indicate?',
        imageAssetPath: '$_assetPath/no_overtaking.png',
        options: ['Overtake with care', 'No overtaking', 'Overtaking lane', 'Merge'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_keep_left',
        questionText: 'This sign means you must:',
        imageAssetPath: '$_assetPath/keep_left.png',
        options: ['Turn left', 'Keep to the left', 'Left lane only', 'No left turn'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_no_horn',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/no_horn.png',
        options: ['Honk to proceed', 'Horn compulsory', 'Horn prohibited (silence zone)', 'Sound horn'],
        correctIndex: 2,
      ),
      McqQuestion(
        id: 'rs_compulsory_left',
        questionText: 'This sign means:',
        imageAssetPath: '$_assetPath/compulsory_left.png',
        options: ['No left turn', 'Turn left only', 'Left lane ends', 'Merge left'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_compulsory_right',
        questionText: 'This sign means:',
        imageAssetPath: '$_assetPath/compulsory_right.png',
        options: ['No right turn', 'Turn right only', 'Right lane only', 'Keep right'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_no_left_turn',
        questionText: 'What does this sign mean?',
        imageAssetPath: '$_assetPath/no_left_turn.png',
        options: ['Turn left', 'No left turn', 'Left lane only', 'Merge left'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_no_right_turn',
        questionText: 'This sign means:',
        imageAssetPath: '$_assetPath/no_right_turn.png',
        options: ['Turn right', 'No right turn', 'Right lane only', 'Keep right'],
        correctIndex: 1,
      ),
      // --- Information / priority ---
      McqQuestion(
        id: 'rs_main_road',
        questionText: 'You see this sign. You are on:',
        imageAssetPath: '$_assetPath/main_road.png',
        options: ['A minor road', 'The main road; others give way', 'A one-way street', 'A dead end'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_roundabout',
        questionText: 'This sign indicates:',
        imageAssetPath: '$_assetPath/roundabout.png',
        options: ['No U-turn', 'Roundabout ahead', 'Circular road', 'Merge'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_hump',
        questionText: 'What does this sign warn you about?',
        imageAssetPath: '$_assetPath/hump.png',
        options: ['Steep hill', 'Speed bump or hump ahead', 'Dip in road', 'Bridge'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_narrow_road',
        questionText: 'This sign means:',
        imageAssetPath: '$_assetPath/narrow_road.png',
        options: ['Wide load', 'Road narrows ahead', 'Single lane', 'No entry'],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'rs_two_way',
        questionText: 'What does this sign indicate?',
        imageAssetPath: '$_assetPath/two_way_traffic.png',
        options: ['One way', 'Two-way traffic ahead', 'Divided highway', 'No passing'],
        correctIndex: 1,
      ),
      // --- Traffic lights and signals (text-only) ---
      McqQuestion(
        id: 'ts_red_steady',
        questionText: 'At a steady red traffic light, what must you do?',
        options: [
          'Stop behind the stop line and wait',
          'Slow down and go if nothing is coming',
          'Sound the horn and proceed',
          'Treat it as a give way only',
        ],
        correctIndex: 0,
      ),
      McqQuestion(
        id: 'ts_amber_after_green',
        questionText:
            'A steady amber light appears after green. Unless it would be unsafe to stop, you should:',
        options: [
          'Accelerate through before it turns red',
          'Stop at the stop line',
          'Ignore it if you are turning',
          'Always enter the junction',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_green',
        questionText: 'A steady green light means you may go:',
        options: [
          'Immediately at maximum speed',
          'Only if the way ahead is clear and you can do so safely',
          'Without checking for pedestrians',
          'Only on motorways',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_red_amber_together',
        questionText: 'Red and amber lights show together (just before green). You should:',
        options: [
          'Start moving straight away',
          'Prepare to go but remain stopped until green shows',
          'Treat it as a fault and ignore the lights',
          'Sound the horn and enter the junction',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_green_arrow_red_straight',
        questionText:
            'You have a green arrow for your lane, but the main lights are red for straight ahead. Generally you may:',
        options: [
          'Go straight ahead anyway',
          'Follow the direction of the green arrow when it is safe',
          'Wait for a green light for all directions',
          'Turn only if you use hazard lights',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_officer_vs_lights',
        questionText: 'A police officer directing traffic signals something different from the traffic lights. You should:',
        options: [
          'Follow the traffic lights',
          'Follow the officer’s directions',
          'Stop in the middle of the junction',
          'Follow what other drivers do',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_flashing_amber_crossing',
        questionText:
            'Flashing amber lights at a light-controlled pedestrian crossing usually mean you should:',
        options: [
          'Speed up to clear the crossing',
          'Give way to pedestrians on the crossing; approach with care',
          'Never stop under any circumstances',
          'Use full beam to warn pedestrians',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'ts_stop_line',
        questionText: 'Where should you normally stop for a red traffic signal?',
        options: [
          'Just past the stop line if you can see better',
          'Behind the stop line (or before the crossing / signal if there is no line)',
          'In the middle of the junction',
          'Only if other vehicles have stopped',
        ],
        correctIndex: 1,
      ),
      McqQuestion(
        id: 'cl_vertical_order',
        questionText: 'On a standard vertical traffic signal, which color is usually at the top?',
        options: ['Red', 'Green', 'Amber', 'Blue'],
        correctIndex: 0,
      ),
      McqQuestion(
        id: 'cl_amber_role',
        questionText: 'The steady amber (yellow) light after green mainly tells you to:',
        options: [
          'Speed up before it turns red',
          'Slow down and prepare to stop if you can do so safely',
          'Always reverse',
          'Ignore it if you are turning',
        ],
        correctIndex: 1,
      ),
    ];
  }

  /// Map curriculum MCQ pool id → question ids (see assets/config/road_signs_curriculum.json).
  static const Map<String, Set<String>> _testIdToQuestionIds = {
    'warning_signs_mcq': {
      'rs_slippery', 'rs_children', 'rs_cattle', 'rs_curve_left', 'rs_curve_right',
      'rs_road_works', 'rs_pedestrian_crossing', 'rs_level_crossing', 'rs_hump', 'rs_narrow_road',
    },
    'control_restrictive_mcq': {
      'rs_no_entry', 'rs_speed_50', 'rs_no_parking', 'rs_no_overtaking',
      'rs_no_horn', 'rs_no_left_turn', 'rs_no_right_turn',
    },
    'control_boundary_mcq': {
      'rs_two_way', 'rs_narrow_road', 'rs_speed_50', 'rs_hump', 'rs_pedestrian_crossing',
      'rs_level_crossing', 'rs_road_works', 'rs_slippery',
    },
    'control_additional_mcq': {
      'rs_no_parking', 'rs_no_horn', 'rs_no_overtaking', 'rs_road_works',
      'rs_no_left_turn', 'rs_no_right_turn', 'rs_no_entry', 'rs_speed_50',
    },
    'control_command_mcq': {
      'rs_keep_left', 'rs_compulsory_left', 'rs_compulsory_right',
    },
    'control_priority_mcq': {
      'rs_stop', 'rs_give_way', 'rs_main_road', 'rs_roundabout',
    },
    'traffic_signals_mcq': {
      'ts_red_steady',
      'ts_amber_after_green',
      'ts_green',
      'ts_red_amber_together',
      'ts_green_arrow_red_straight',
      'ts_officer_vs_lights',
      'ts_flashing_amber_crossing',
      'ts_stop_line',
    },
    'traffic_color_lights_mcq': {
      'ts_red_steady',
      'ts_amber_after_green',
      'ts_green',
      'ts_stop_line',
      'cl_vertical_order',
      'cl_amber_role',
    },
  };
}
