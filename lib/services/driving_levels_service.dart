import '../models/game_level.dart';

/// Service to provide driving levels organized by topic
class DrivingLevelsService {
  /// Get all levels for a specific topic
  static List<GameLevel> getLevelsForTopic(DrivingTopic topic) {
    switch (topic) {
      case DrivingTopic.Junctions:
        return _junctionsLevels;
      case DrivingTopic.RoadMarkings:
        return _roadMarkingsLevels;
      case DrivingTopic.RoadSigns:
        return _roadSignsLevels;
      case DrivingTopic.EmergencySituations:
        return _emergencySituationsLevels;
      case DrivingTopic.Parking:
        return _parkingLevels;
    }
  }

  /// Get all levels (across all topics)
  static List<GameLevel> getAllLevels() {
    return [
      ..._junctionsLevels,
      ..._roadMarkingsLevels,
      ..._roadSignsLevels,
      ..._emergencySituationsLevels,
      ..._parkingLevels,
    ];
  }

  /// Progress / grouping for levels under [DrivingTopic.Junctions].
  static const String junctionModuleTJunction = 't_junction';
  static const String junctionModuleCross = 'cross_junction';
  static const String junctionModuleRoundabout = 'roundabout';

  /// Progress / grouping for levels under [DrivingTopic.RoadMarkings].
  static const String roadMarkingsModuleLaneLines = 'lane_lines';
  static const String roadMarkingsModuleOther = 'other_markings';

  /// Levels in one junctions submodule (T-junctions, cross, or roundabout).
  static List<GameLevel> getJunctionsLevelsForModule(String moduleId) {
    final list =
        _junctionsLevels.where((l) => l.moduleId == moduleId).toList();
    list.sort((a, b) => a.topicLevel.compareTo(b.topicLevel));
    return list;
  }

  /// Levels in one road markings submodule (lane lines, or other markings).
  static List<GameLevel> getRoadMarkingsLevelsForModule(String moduleId) {
    final list =
        _roadMarkingsLevels.where((l) => l.moduleId == moduleId).toList();
    list.sort((a, b) => a.topicLevel.compareTo(b.topicLevel));
    return list;
  }

  /// Check if a level is unlocked based on completed level IDs
  static bool isLevelUnlocked(GameLevel level, Set<String> completedLevelIds) {
    if (level.unlockRequirementIds.isEmpty) {
      return level.isUnlocked; // If no requirements, use default unlock status
    }
    // Check if all requirements are completed
    return level.unlockRequirementIds.every((reqId) => completedLevelIds.contains(reqId));
  }

  // ========== JUNCTIONS LEVELS ==========
  static final List<GameLevel> _junctionsLevels = [
    GameLevel(
      id: "junctions_t_left",
      number: 1,
      name: "Left Turn",
      description: "Approach and complete a safe left turn at a T-junction",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: true, // First level is always unlocked
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleTJunction,
      topicLevel: 1,
      unlockRequirementIds: [],
      mapAsset: 'T-junction-left.tmx',
      scenarioId: 't_junction_left',
    ),
    GameLevel(
      id: "junctions_t_right",
      number: 2,
      name: "Right Turn",
      description: "Approach and complete a safe right turn at a T-junction",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: false,
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleTJunction,
      topicLevel: 2,
      unlockRequirementIds: ["junctions_t_left"],
      mapAsset: 'T-junction-right.tmx',
      scenarioId: 't_junction_right',
    ),
    GameLevel(
      id: "junctions_cross_basics",
      number: 3,
      name: "Cross Junction Basics",
      description: "Four-way crossings without traffic lights",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleCross,
      topicLevel: 3,
      unlockRequirementIds: ["junctions_t_right"],
    ),
    GameLevel(
      id: "junctions_roundabout_basics",
      number: 4,
      name: "Roundabout Basics",
      description: "Single-lane roundabouts",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleRoundabout,
      topicLevel: 4,
      unlockRequirementIds: ["junctions_t_right"],
    ),
    GameLevel(
      id: "junctions_cross_advanced",
      number: 5,
      name: "Cross Junction Advanced",
      description: "Traffic lights and busy four-way crossings",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleCross,
      topicLevel: 5,
      unlockRequirementIds: ["junctions_cross_basics"],
    ),
    GameLevel(
      id: "junctions_roundabout_complex",
      number: 6,
      name: "Roundabout Complex",
      description: "Multi-lane roundabouts with multiple exits",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.Junctions,
      moduleId: junctionModuleRoundabout,
      topicLevel: 6,
      unlockRequirementIds: ["junctions_roundabout_basics"],
    ),
  ];

  // ========== ROAD MARKINGS LEVELS ==========
  static final List<GameLevel> _roadMarkingsLevels = [
    GameLevel(
      id: "markings_solid",
      number: 1,
      name: "Solid lines",
      description: "Drive with solid lane and center markings",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: true,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleLaneLines,
      topicLevel: 1,
      unlockRequirementIds: [],
      mapAsset: 'lane-markings-solid.tmx',
      scenarioId: 'markings_solid',
    ),
    GameLevel(
      id: "markings_dashed",
      number: 2,
      name: "Dashed lines",
      description: "Drive with dashed lane and center markings",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: false,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleLaneLines,
      topicLevel: 2,
      unlockRequirementIds: ["markings_solid"],
      mapAsset: 'lane-markings-dashed.tmx',
      scenarioId: 'markings_dashed',
    ),
    GameLevel(
      id: "markings_stop_yield",
      number: 3,
      name: "Stop & Yield Lines",
      description: "Understanding stop and yield markings",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: false,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleOther,
      topicLevel: 3,
      unlockRequirementIds: ["markings_dashed"],
    ),
    GameLevel(
      id: "markings_zebra",
      number: 4,
      name: "Zebra Crossings",
      description: "Pedestrian crossings and right of way",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleOther,
      topicLevel: 4,
      unlockRequirementIds: ["markings_stop_yield"],
    ),
    GameLevel(
      id: "markings_bus_lanes",
      number: 5,
      name: "Bus Lanes & Special Zones",
      description: "Restricted lanes and special markings",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleOther,
      topicLevel: 5,
      unlockRequirementIds: ["markings_zebra"],
    ),
    GameLevel(
      id: "markings_complex",
      number: 6,
      name: "Complex Intersections",
      description: "Multiple marking types in complex scenarios",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.RoadMarkings,
      moduleId: roadMarkingsModuleOther,
      topicLevel: 6,
      unlockRequirementIds: ["markings_bus_lanes"],
    ),
  ];

  // ========== ROAD SIGNS LEVELS ==========
  static final List<GameLevel> _roadSignsLevels = [
    GameLevel(
      id: "signs_warning",
      number: 1,
      name: "Warning Signs",
      description: "Basic warning signs (curves, school zones)",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: true,
      topic: DrivingTopic.RoadSigns,
      topicLevel: 1,
      unlockRequirementIds: [],
    ),
    GameLevel(
      id: "signs_regulatory",
      number: 2,
      name: "Regulatory Signs",
      description: "Speed limits, no parking, traffic rules",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: false,
      topic: DrivingTopic.RoadSigns,
      topicLevel: 2,
      unlockRequirementIds: ["signs_warning"],
    ),
    GameLevel(
      id: "signs_priority",
      number: 3,
      name: "Priority Signs",
      description: "Give way, stop, priority road signs",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.RoadSigns,
      topicLevel: 3,
      unlockRequirementIds: ["signs_warning"],
    ),
    GameLevel(
      id: "signs_information",
      number: 4,
      name: "Information Signs",
      description: "Direction signs, services, and guidance",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.RoadSigns,
      topicLevel: 4,
      unlockRequirementIds: ["signs_regulatory"],
    ),
    GameLevel(
      id: "signs_combined",
      number: 5,
      name: "Multiple Signs Combined",
      description: "Complex scenarios with multiple sign types",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.RoadSigns,
      topicLevel: 5,
      unlockRequirementIds: ["signs_priority", "signs_information"],
    ),
  ];

  // ========== EMERGENCY SITUATIONS LEVELS ==========
  static final List<GameLevel> _emergencySituationsLevels = [
    GameLevel(
      id: "emergency_braking",
      number: 1,
      name: "Emergency Braking",
      description: "Sudden stops and maintaining safe distances",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: true,
      topic: DrivingTopic.EmergencySituations,
      topicLevel: 1,
      unlockRequirementIds: [],
    ),
    GameLevel(
      id: "emergency_breakdown",
      number: 2,
      name: "Vehicle Breakdown",
      description: "Hazard lights, safe parking during breakdown",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.EmergencySituations,
      topicLevel: 2,
      unlockRequirementIds: ["emergency_braking"],
    ),
    GameLevel(
      id: "emergency_vehicles",
      number: 3,
      name: "Emergency Vehicles",
      description: "Yielding to ambulances, police, and fire trucks",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.EmergencySituations,
      topicLevel: 3,
      unlockRequirementIds: ["emergency_breakdown"],
    ),
    GameLevel(
      id: "emergency_weather",
      number: 4,
      name: "Adverse Weather",
      description: "Rain, reduced visibility, slippery conditions",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.EmergencySituations,
      topicLevel: 4,
      unlockRequirementIds: ["emergency_vehicles"],
    ),
  ];

  // ========== PARKING LEVELS ==========
  static final List<GameLevel> _parkingLevels = [
    GameLevel(
      id: "parking_parallel_basics",
      number: 1,
      name: "Parallel Parking Basics",
      description: "Simple parallel parking in easy spaces",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: true,
      topic: DrivingTopic.Parking,
      topicLevel: 1,
      unlockRequirementIds: [],
    ),
    GameLevel(
      id: "parking_perpendicular",
      number: 2,
      name: "Perpendicular Parking",
      description: "90-degree angle parking",
      difficulty: LevelDifficulty.Easy,
      isUnlocked: false,
      topic: DrivingTopic.Parking,
      topicLevel: 2,
      unlockRequirementIds: ["parking_parallel_basics"],
    ),
    GameLevel(
      id: "parking_parallel_advanced",
      number: 3,
      name: "Parallel Parking Advanced",
      description: "Tight spaces with traffic",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.Parking,
      topicLevel: 3,
      unlockRequirementIds: ["parking_parallel_basics"],
    ),
    GameLevel(
      id: "parking_angle",
      number: 4,
      name: "Angle Parking",
      description: "45-degree angle parking",
      difficulty: LevelDifficulty.Medium,
      isUnlocked: false,
      topic: DrivingTopic.Parking,
      topicLevel: 4,
      unlockRequirementIds: ["parking_perpendicular"],
    ),
    GameLevel(
      id: "parking_complex",
      number: 5,
      name: "Complex Parking Scenarios",
      description: "Slopes, restricted zones, tight spaces",
      difficulty: LevelDifficulty.Hard,
      isUnlocked: false,
      topic: DrivingTopic.Parking,
      topicLevel: 5,
      unlockRequirementIds: ["parking_parallel_advanced", "parking_angle"],
    ),
  ];
}
