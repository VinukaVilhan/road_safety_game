import '../../models/theory/mcq_question.dart';

/// Text-only MCQ pools for theory categories (best practices, traffic rules, …).
class TheoryQuestionsService {
  static List<McqQuestion> getQuestionsForTest(String testId, {int? count}) {
    final all = _getAllQuestions();
    final forTest = all.where((q) => _testIdToQuestionIds[testId]?.contains(q.id) ?? false).toList();
    if (forTest.isEmpty) return [];
    if (count != null && forTest.length > count) {
      return forTest.take(count).toList();
    }
    return forTest;
  }

  static List<McqQuestion> allQuestionsForAssistant() => _getAllQuestions();

  static List<McqQuestion> _getAllQuestions() {
    return [
      // --- Best practices ---
      const McqQuestion(
        id: 'bp_seatbelt',
        questionText: 'When should you fasten your seatbelt?',
        options: [
          'Only on motorways',
          'Before moving off, every journey',
          'Only when police are nearby',
          'After reaching 30 km/h',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'bp_following',
        questionText: 'Why keep a safe following distance?',
        options: [
          'To annoy other drivers',
          'So you can stop in time if the vehicle ahead brakes',
          'To save fuel only',
          'Because it is illegal to see the car ahead',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'bp_mirrors',
        questionText: 'Before changing lane, you should:',
        options: [
          'Signal only — mirrors are optional',
          'Check mirrors and blind spots, then signal if clear',
          'Honk and move immediately',
          'Speed up to pass quickly',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'bp_phone',
        questionText: 'Using a handheld mobile phone while driving is dangerous because it:',
        options: [
          'Improves reaction time',
          'Distracts you from the road and traffic',
          'Is required for navigation',
          'Only matters at night',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'bp_pedestrians',
        questionText: 'Near a pedestrian crossing you should:',
        options: [
          'Speed up to clear it',
          'Be ready to slow or stop for people crossing',
          'Assume pedestrians will wait',
          'Use full beam headlights',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'bp_night',
        questionText: 'At night you should use dipped headlights so that you:',
        options: [
          'Can see and be seen without dazzling others',
          'Warn pedestrians to move off the road',
          'Park on the pavement',
          'Ignore speed limits',
        ],
        correctIndex: 0,
      ),
      // --- Traffic rules ---
      const McqQuestion(
        id: 'tr_licence',
        questionText: 'When driving on a public road you must:',
        options: [
          'Hold a valid licence for that vehicle class',
          'Only carry a photocopy at home',
          'Drive without documents if insured',
          'Use a learner plate forever',
        ],
        correctIndex: 0,
      ),
      const McqQuestion(
        id: 'tr_documents',
        questionText: 'Which documents should normally be available when driving?',
        options: [
          'Only a school ID',
          'Valid licence, insurance, and revenue licence where required',
          'No documents if the car is new',
          'Passport only',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'tr_speed',
        questionText: 'A posted speed limit means:',
        options: [
          'You must always drive at exactly that speed',
          'You must not exceed that limit; drive slower if conditions are poor',
          'It applies only to lorries',
          'It is optional at night',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'tr_oneway',
        questionText: 'On a one-way street you must:',
        options: [
          'Drive in either direction if quiet',
          'Travel only in the direction shown by signs or markings',
          'Reverse if the road is empty',
          'Park across both lanes',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'tr_school',
        questionText: 'Near a school zone you should:',
        options: [
          'Drive faster to pass quickly',
          'Reduce speed and watch for children',
          'Sound the horn continuously',
          'Overtake waiting buses',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'tr_penalty',
        questionText: 'Traffic offences may result in:',
        options: [
          'Free fuel vouchers',
          'Fines, licence action, or other legal penalties',
          'Automatic pass on your next test',
          'No consequences if you apologise',
        ],
        correctIndex: 1,
      ),
      // --- Parking ---
      const McqQuestion(
        id: 'pk_prohibited',
        questionText: 'You must NOT park:',
        options: [
          'In a marked bay facing the kerb',
          'On a pedestrian crossing or blocking a junction',
          'In a car park with a ticket',
          'On your own driveway',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'pk_parallel',
        questionText: 'When parallel parking you should:',
        options: [
          'Leave the car sticking far into the road',
          'Park close to the kerb within the bay or space',
          'Park on the wrong side facing traffic',
          'Leave the engine running unattended',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'pk_bus_stop',
        questionText: 'Parking at or near a bus stop is usually:',
        options: [
          'Encouraged for short waits',
          'Restricted because it blocks passengers and buses',
          'Allowed if hazard lights are on',
          'Required for taxis only',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'pk_disabled',
        questionText: 'A bay marked for disabled parking is for:',
        options: [
          'Any driver in a hurry',
          'Vehicles displaying valid disabled permits only',
          'Loading goods only',
          'Motorcycles only',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'pk_hill',
        questionText: 'When parking on a hill you should:',
        options: [
          'Leave the car in neutral without the handbrake',
          'Apply the handbrake and turn wheels appropriately toward the kerb',
          'Leave the door open',
          'Park in the traffic lane',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'pk_signs',
        questionText: 'A “No parking” sign means:',
        options: [
          'You may park for five minutes',
          'You must not park in that area during the times shown (if any)',
          'Parking is free',
          'Only buses may stop',
        ],
        correctIndex: 1,
      ),
      // --- Vehicle control ---
      const McqQuestion(
        id: 'vc_steering',
        questionText: 'Good steering technique includes:',
        options: [
          'Looking only at the dashboard',
          'Smooth inputs and looking where you want to go',
          'One hand off the wheel at all times',
          'Turning the wheel only when stopped',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'vc_braking',
        questionText: 'Progressive braking means:',
        options: [
          'Stamp on the pedal at the last second',
          'Brake early and increase pressure smoothly',
          'Use the handbrake instead of the foot brake',
          'Brake only with the engine off',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'vc_gear',
        questionText: 'In a manual car, you should select a gear that:',
        options: [
          'Keeps the engine screaming at all times',
          'Matches your speed and the road situation',
          'Is always highest gear in town',
          'Is always first gear on highways',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'vc_blind_spot',
        questionText: 'Mirrors may not show a cyclist in your:',
        options: [
          'Boot',
          'Blind spot — check over your shoulder before moving',
          'Fuel tank',
          'Rear-view mirror only area',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'vc_reverse',
        questionText: 'When reversing you should:',
        options: [
          'Rely only on the horn',
          'Move slowly and look mainly through the rear window and mirrors',
          'Reverse quickly to save time',
          'Keep eyes on the radio',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'vc_start',
        questionText: 'Before pulling away you should:',
        options: [
          'Signal, observe, and move off only when safe',
          'Pull away without looking',
          'Use full beam in daylight',
          'Rev the engine in neutral for one minute',
        ],
        correctIndex: 0,
      ),
      // --- Safety procedures ---
      const McqQuestion(
        id: 'sp_hazard',
        questionText: 'Hazard warning lights should be used when:',
        options: [
          'Parking legally in a bay',
          'Your vehicle is stopped and may be a danger to others',
          'Driving through green lights',
          'Overtaking on a solid line',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'sp_triangle',
        questionText: 'A warning triangle is placed behind your car to:',
        options: [
          'Decorate the boot',
          'Warn approaching traffic that there is a hazard ahead',
          'Replace the spare tyre',
          'Signal a right turn',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'sp_breakdown',
        questionText: 'If you break down on a busy road you should:',
        options: [
          'Stand in the live lane to direct traffic',
          'Get passengers to safety and move the car off the road if possible',
          'Leave children in the car on the motorway',
          'Repair the engine in the traffic lane',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'sp_accident',
        questionText: 'After a minor accident with no injuries you should:',
        options: [
          'Drive away without stopping',
          'Stop, exchange details, and report to police if required',
          'Argue in the middle of the junction',
          'Hide your licence',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'sp_rain',
        questionText: 'In heavy rain you should:',
        options: [
          'Drive faster to leave the rain',
          'Slow down, increase following distance, and use wipers and lights as needed',
          'Disable your lights',
          'Follow large vehicles closely for shelter',
        ],
        correctIndex: 1,
      ),
      const McqQuestion(
        id: 'sp_emergency',
        questionText: 'If someone is seriously injured you should:',
        options: [
          'Move them unless they are in immediate danger from fire or traffic',
          'Call emergency services and give accurate location details',
          'Leave the scene to avoid paperwork',
          'Offer food and drink before calling help',
        ],
        correctIndex: 1,
      ),
    ];
  }

  static const Map<String, Set<String>> _testIdToQuestionIds = {
    'best_practices_mcq': {
      'bp_seatbelt',
      'bp_following',
      'bp_mirrors',
      'bp_phone',
      'bp_pedestrians',
      'bp_night',
    },
    'traffic_rules_mcq': {
      'tr_licence',
      'tr_documents',
      'tr_speed',
      'tr_oneway',
      'tr_school',
      'tr_penalty',
    },
    'parking_mcq': {
      'pk_prohibited',
      'pk_parallel',
      'pk_bus_stop',
      'pk_disabled',
      'pk_hill',
      'pk_signs',
    },
    'vehicle_control_mcq': {
      'vc_steering',
      'vc_braking',
      'vc_gear',
      'vc_blind_spot',
      'vc_reverse',
      'vc_start',
    },
    'safety_procedures_mcq': {
      'sp_hazard',
      'sp_triangle',
      'sp_breakdown',
      'sp_accident',
      'sp_rain',
      'sp_emergency',
    },
  };
}
