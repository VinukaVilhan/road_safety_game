import '../models/theory_test.dart';

/// Service to provide MCQ theory tests organized by category
class TheoryTestsService {
  /// Get all tests for a specific category
  static List<TheoryTest> getTestsForCategory(String categoryId) {
    switch (categoryId) {
      case 'road_signs':
        // Road signs use hierarchical curriculum JSON + dedicated screens.
        return const [];
      case 'best_practices':
        return _bestPracticesTests;
      case 'traffic_rules':
        return _trafficRulesTests;
      case 'parking':
        return _parkingTests;
      case 'vehicle_control':
        return _vehicleControlTests;
      case 'safety_procedures':
        return _safetyProceduresTests;
      default:
        return [];
    }
  }

  /// Get all tests (across all categories)
  static List<TheoryTest> getAllTests() {
    return [
      ..._bestPracticesTests,
      ..._trafficRulesTests,
      ..._parkingTests,
      ..._vehicleControlTests,
      ..._safetyProceduresTests,
    ];
  }

  /// Check if a test is unlocked based on completed test IDs
  static bool isTestUnlocked(TheoryTest test, Set<String> completedTestIds) {
    if (test.unlockRequirementIds.isEmpty) {
      return test.isUnlocked; // If no requirements, use default unlock status
    }
    // Check if all requirements are completed
    return test.unlockRequirementIds.every((reqId) => completedTestIds.contains(reqId));
  }

  // ========== BEST PRACTICES TESTS ==========
  static final List<TheoryTest> _bestPracticesTests = [
    TheoryTest(
      id: "best_practices_basics",
      categoryId: "best_practices",
      testNumber: 1,
      name: "Essential Driving Rules",
      description: "Fundamental safe driving practices",
      difficulty: TestDifficulty.Easy,
      isUnlocked: true,
      unlockRequirementIds: [],
      questionCount: 10,
    ),
    TheoryTest(
      id: "best_practices_safety",
      categoryId: "best_practices",
      testNumber: 2,
      name: "Safety Tips & Habits",
      description: "Defensive driving and safety habits",
      difficulty: TestDifficulty.Medium,
      isUnlocked: false,
      unlockRequirementIds: ["best_practices_basics"],
      questionCount: 15,
    ),
    TheoryTest(
      id: "best_practices_advanced",
      categoryId: "best_practices",
      testNumber: 3,
      name: "Advanced Best Practices",
      description: "Professional driving techniques and etiquette",
      difficulty: TestDifficulty.Hard,
      isUnlocked: false,
      unlockRequirementIds: ["best_practices_safety"],
      questionCount: 20,
    ),
  ];

  // ========== TRAFFIC RULES TESTS ==========
  static final List<TheoryTest> _trafficRulesTests = [
    TheoryTest(
      id: "traffic_rules_basics",
      categoryId: "traffic_rules",
      testNumber: 1,
      name: "Basic Traffic Laws",
      description: "Fundamental Sri Lankan traffic regulations",
      difficulty: TestDifficulty.Easy,
      isUnlocked: true,
      unlockRequirementIds: [],
      questionCount: 10,
    ),
    TheoryTest(
      id: "traffic_rules_licensing",
      categoryId: "traffic_rules",
      testNumber: 2,
      name: "Licensing & Documents",
      description: "License requirements and vehicle documents",
      difficulty: TestDifficulty.Easy,
      isUnlocked: false,
      unlockRequirementIds: ["traffic_rules_basics"],
      questionCount: 10,
    ),
    TheoryTest(
      id: "traffic_rules_penalties",
      categoryId: "traffic_rules",
      testNumber: 3,
      name: "Traffic Violations & Penalties",
      description: "Understanding fines, demerits, and legal consequences",
      difficulty: TestDifficulty.Medium,
      isUnlocked: false,
      unlockRequirementIds: ["traffic_rules_licensing"],
      questionCount: 15,
    ),
    TheoryTest(
      id: "traffic_rules_advanced",
      categoryId: "traffic_rules",
      testNumber: 4,
      name: "Complex Regulations",
      description: "Advanced traffic law scenarios",
      difficulty: TestDifficulty.Hard,
      isUnlocked: false,
      unlockRequirementIds: ["traffic_rules_penalties"],
      questionCount: 20,
    ),
  ];

  // ========== PARKING TESTS ==========
  static final List<TheoryTest> _parkingTests = [
    TheoryTest(
      id: "parking_basics",
      categoryId: "parking",
      testNumber: 1,
      name: "Parking Rules Basics",
      description: "Basic parking regulations and restrictions",
      difficulty: TestDifficulty.Easy,
      isUnlocked: true,
      unlockRequirementIds: [],
      questionCount: 10,
    ),
    TheoryTest(
      id: "parking_zones",
      categoryId: "parking",
      testNumber: 2,
      name: "Parking Zones & Types",
      description: "Designated zones, parallel, and angle parking",
      difficulty: TestDifficulty.Medium,
      isUnlocked: false,
      unlockRequirementIds: ["parking_basics"],
      questionCount: 15,
    ),
    TheoryTest(
      id: "parking_restrictions",
      categoryId: "parking",
      testNumber: 3,
      name: "Restrictions & Prohibitions",
      description: "No-parking areas and time-based restrictions",
      difficulty: TestDifficulty.Hard,
      isUnlocked: false,
      unlockRequirementIds: ["parking_zones"],
      questionCount: 15,
    ),
  ];

  // ========== VEHICLE CONTROL TESTS ==========
  static final List<TheoryTest> _vehicleControlTests = [
    TheoryTest(
      id: "vehicle_control_basics",
      categoryId: "vehicle_control",
      testNumber: 1,
      name: "Basic Vehicle Operations",
      description: "Steering, acceleration, and braking fundamentals",
      difficulty: TestDifficulty.Easy,
      isUnlocked: true,
      unlockRequirementIds: [],
      questionCount: 10,
    ),
    TheoryTest(
      id: "vehicle_control_gears",
      categoryId: "vehicle_control",
      testNumber: 2,
      name: "Gear Systems & Transmissions",
      description: "Manual and automatic gear operations",
      difficulty: TestDifficulty.Medium,
      isUnlocked: false,
      unlockRequirementIds: ["vehicle_control_basics"],
      questionCount: 15,
    ),
    TheoryTest(
      id: "vehicle_control_advanced",
      categoryId: "vehicle_control",
      testNumber: 3,
      name: "Advanced Control Techniques",
      description: "Complex maneuvers and vehicle handling",
      difficulty: TestDifficulty.Hard,
      isUnlocked: false,
      unlockRequirementIds: ["vehicle_control_gears"],
      questionCount: 20,
    ),
  ];

  // ========== SAFETY PROCEDURES TESTS ==========
  static final List<TheoryTest> _safetyProceduresTests = [
    TheoryTest(
      id: "safety_procedures_basics",
      categoryId: "safety_procedures",
      testNumber: 1,
      name: "Emergency Response Basics",
      description: "Basic emergency procedures and responses",
      difficulty: TestDifficulty.Easy,
      isUnlocked: true,
      unlockRequirementIds: [],
      questionCount: 10,
    ),
    TheoryTest(
      id: "safety_procedures_breakdown",
      categoryId: "safety_procedures",
      testNumber: 2,
      name: "Vehicle Breakdown & Accidents",
      description: "Handling breakdowns and accident procedures",
      difficulty: TestDifficulty.Medium,
      isUnlocked: false,
      unlockRequirementIds: ["safety_procedures_basics"],
      questionCount: 15,
    ),
    TheoryTest(
      id: "safety_procedures_weather",
      categoryId: "safety_procedures",
      testNumber: 3,
      name: "Adverse Weather & Conditions",
      description: "Driving in rain, fog, and hazardous conditions",
      difficulty: TestDifficulty.Hard,
      isUnlocked: false,
      unlockRequirementIds: ["safety_procedures_breakdown"],
      questionCount: 20,
    ),
  ];
}
