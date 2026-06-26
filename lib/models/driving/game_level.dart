import 'package:flutter/material.dart';

// Data classes for level management
class GameLevel {
  final String id; // Unique identifier: "junctions_t_basics"
  final int number; // Display number (for ordering)
  final String name;
  final String description;
  final bool isUnlocked;
  
  // Topic-based organization
  final DrivingTopic topic;
  final String? moduleId; // Optional sub-module identifier (e.g. "t_junction")
  final int topicLevel; // Level within the topic (1, 2, 3...)
  final List<String> unlockRequirementIds; // IDs of levels that must be completed first
  /// Optional TMX map asset path (e.g. 'tiles/T-junction-left.tmx' or 'tiles/T-junction-right.tmx'). If null, default map is used.
  final String? mapAsset;
  /// Optional scenario key for map-specific objective behavior.
  final String? scenarioId;
  /// When false, the map still loads (spawn, collision, visuals) but TMX rule zones are ignored.
  final bool enableDrivingRules;

  GameLevel({
    required this.id,
    required this.number,
    required this.name,
    required this.description,
    required this.isUnlocked,
    required this.topic,
    this.moduleId,
    required this.topicLevel,
    this.unlockRequirementIds = const [],
    this.mapAsset,
    this.scenarioId,
    this.enableDrivingRules = true,
  });
  
  // You can add more properties like:
  // final String backgroundImage;
  // final double targetTime;
  // final int targetScore;
  // final List<String> obstacles;
  // final double roadSpeed;
  // final Color themeColor;
}

enum DrivingTopic {
  Junctions,
  RoadMarkings,
  RoadSigns,
  EmergencySituations,
  WeatherConditions,
  Parking,
  Practice,
}

extension GameLevelGameplay on GameLevel {
  bool get isMarkingsDashedLevel {
    if (scenarioId == 'emergency_ambulance') return false;
    final a = (mapAsset ?? '').toLowerCase();
    return a.contains('lane_markings_dashed') || scenarioId == 'markings_dashed';
  }

  bool get isRoadCrossingLevel =>
      (mapAsset ?? '').toLowerCase().contains('road_crossing');

  bool get isAdverseWeatherLevel => scenarioId == 'emergency_weather';
}

extension DrivingTopicExtension on DrivingTopic {
  String get displayName {
    switch (this) {
      case DrivingTopic.Junctions:
        return 'JUNCTIONS';
      case DrivingTopic.RoadMarkings:
        return 'ROAD MARKINGS';
      case DrivingTopic.RoadSigns:
        return 'ROAD SIGNS';
      case DrivingTopic.EmergencySituations:
        return 'EMERGENCY SITUATIONS';
      case DrivingTopic.WeatherConditions:
        return 'WEATHER CONDITIONS';
      case DrivingTopic.Parking:
        return 'PARKING';
      case DrivingTopic.Practice:
        return 'CONTROLS';
    }
  }
  
  String get description {
    switch (this) {
      case DrivingTopic.Junctions:
        return 'T-junctions, cross roads, and roundabouts';
      case DrivingTopic.RoadMarkings:
        return 'Master lane markings, crossings, and zones';
      case DrivingTopic.RoadSigns:
        return 'Understand warning, regulatory, and information signs';
      case DrivingTopic.EmergencySituations:
        return 'Handle braking, breakdowns, and emergencies';
      case DrivingTopic.WeatherConditions:
        return 'Drive safely in rain, fog, and poor visibility';
      case DrivingTopic.Parking:
        return 'Parallel, perpendicular, and angle parking';
      case DrivingTopic.Practice:
        return 'Steering, pedals, gears, and signals';
    }
  }
  
  IconData get icon {
    switch (this) {
      case DrivingTopic.Junctions:
        return Icons.turn_right;
      case DrivingTopic.RoadMarkings:
        return Icons.format_color_fill;
      case DrivingTopic.RoadSigns:
        return Icons.traffic;
      case DrivingTopic.EmergencySituations:
        return Icons.warning_amber_rounded;
      case DrivingTopic.WeatherConditions:
        return Icons.grain;
      case DrivingTopic.Parking:
        return Icons.local_parking;
      case DrivingTopic.Practice:
        return Icons.sports_motorsports;
    }
  }
}
