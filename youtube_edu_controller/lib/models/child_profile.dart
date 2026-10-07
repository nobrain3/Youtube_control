import 'package:cloud_firestore/cloud_firestore.dart';

/// 보호자 계정 아래에 속한 아이 프로필과 학습 설정 (#99).
///
/// Firestore 경로: `users/{uid}/children/{childId}`
class ChildProfile {
  final String id;
  final String name;
  final int grade;
  final int studyIntervalMinutes;
  final int quizQuestionCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.grade,
    required this.studyIntervalMinutes,
    required this.quizQuestionCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ChildProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final settings = data['settings'] as Map<String, dynamic>? ?? {};
    return ChildProfile(
      id: doc.id,
      name: data['name'] as String? ?? '',
      grade: (data['grade'] as num?)?.toInt() ?? 3,
      studyIntervalMinutes:
          (settings['studyIntervalMinutes'] as num?)?.toInt() ?? 15,
      quizQuestionCount: (settings['quizQuestionCount'] as num?)?.toInt() ?? 3,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
