import 'last_driving_report.dart';

/// Metadata for one persisted instructor transcript (see [InstructorChatSessionsService]).
class InstructorChatSession {
  const InstructorChatSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.reportJson,
    this.messageCount = 0,
  });

  static const String kindGeneral = 'general';
  static const String kindLevelReport = 'levelReport';

  final String id;
  final String title;
  final String kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? reportJson;
  final int messageCount;

  bool get isReport => kind == kindLevelReport;

  LastDrivingReport? get lastReport {
    final j = reportJson;
    if (j == null) return null;
    try {
      return LastDrivingReport.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {
      return null;
    }
  }

  factory InstructorChatSession.fromStorage(
    String id,
    Map<String, dynamic> json, {
    required int messageCount,
  }) {
    final kind = json['kind'] as String? ?? kindGeneral;
    Map<String, dynamic>? report;
    final rawReport = json['report'];
    if (rawReport is Map) {
      report = Map<String, dynamic>.from(rawReport);
    }
    return InstructorChatSession(
      id: id,
      title: json['title'] as String? ?? 'Chat',
      kind: kind,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      reportJson: report,
      messageCount: messageCount,
    );
  }
}
