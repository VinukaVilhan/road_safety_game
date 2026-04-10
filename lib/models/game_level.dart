import 'package:flutter/material.dart';

// Data classes for level management
class GameLevel {
  final String id; // Unique identifier: "junctions_t_basics"
  final int number; // Display number (for ordering)
  final String name;
  final String description;
  final LevelDifficulty difficulty;
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

  GameLevel({
    required this.id,
    required this.number,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.isUnlocked,
    required this.topic,
    this.moduleId,
    required this.topicLevel,
    this.unlockRequirementIds = const [],
    this.mapAsset,
    this.scenarioId,
  });
  
  // You can add more properties like:
  // final String backgroundImage;
  // final double targetTime;
  // final int targetScore;
  // final List<String> obstacles;
  // final double roadSpeed;
  // final Color themeColor;
}

enum LevelDifficulty { Easy, Medium, Hard, Extreme }

enum DrivingTopic {
  Junctions,
  RoadMarkings,
  RoadSigns,
  EmergencySituations,
  Parking,
  Practice,
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
      case DrivingTopic.Parking:
        return 'Practice parallel, perpendicular, and angle parking';
      case DrivingTopic.Practice:
        return 'Learn what each control does';
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
      case DrivingTopic.Parking:
        return Icons.local_parking;
      case DrivingTopic.Practice:
        return Icons.sports_motorsports;
    }
  }
}
