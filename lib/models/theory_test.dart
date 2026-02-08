import 'package:flutter/material.dart';

/// Model for MCQ theory tests
class TheoryTest {
  final String id; // Unique identifier: "road_signs_basics_01"
  final String categoryId; // Which category this test belongs to
  final int testNumber; // Display number within category
  final String name;
  final String description;
  final TestDifficulty difficulty;
  final bool isUnlocked;
  final List<String> unlockRequirementIds; // IDs of tests that must be completed first
  final int questionCount; // Number of questions in this test

  TheoryTest({
    required this.id,
    required this.categoryId,
    required this.testNumber,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.isUnlocked,
    this.unlockRequirementIds = const [],
    this.questionCount = 10, // Default to 10 questions
  });
}

enum TestDifficulty { Easy, Medium, Hard }

/// Theory test categories
enum TheoryTestCategoryType {
  RoadSigns,
  BestPractices,
  TrafficRules,
  Parking,
  VehicleControl,
  SafetyProcedures,
}

extension TheoryTestCategoryTypeExtension on TheoryTestCategoryType {
  String get id {
    switch (this) {
      case TheoryTestCategoryType.RoadSigns:
        return 'road_signs';
      case TheoryTestCategoryType.BestPractices:
        return 'best_practices';
      case TheoryTestCategoryType.TrafficRules:
        return 'traffic_rules';
      case TheoryTestCategoryType.Parking:
        return 'parking';
      case TheoryTestCategoryType.VehicleControl:
        return 'vehicle_control';
      case TheoryTestCategoryType.SafetyProcedures:
        return 'safety_procedures';
    }
  }

  String get displayName {
    switch (this) {
      case TheoryTestCategoryType.RoadSigns:
        return 'ROAD SIGNS';
      case TheoryTestCategoryType.BestPractices:
        return 'BEST PRACTICES';
      case TheoryTestCategoryType.TrafficRules:
        return 'TRAFFIC RULES';
      case TheoryTestCategoryType.Parking:
        return 'PARKING';
      case TheoryTestCategoryType.VehicleControl:
        return 'VEHICLE CONTROL';
      case TheoryTestCategoryType.SafetyProcedures:
        return 'SAFETY PROCEDURES';
    }
  }
}
