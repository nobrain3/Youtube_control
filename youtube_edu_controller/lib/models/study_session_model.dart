class StudySession {
  final String id;
  final String userId;
  final String videoId;
  final String videoTitle;
  final String? subject;
  final int? currentVideoPosition;
  final Duration? watchedDuration;
  final DateTime startTime;
  final DateTime? endTime;
  final int questionsAnswered;
  final int correctAnswers;
  final int pointsEarned;

  StudySession({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.videoTitle,
    this.subject,
    this.currentVideoPosition,
    this.watchedDuration,
    required this.startTime,
    this.endTime,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.pointsEarned,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'],
      userId: json['userId'],
      videoId: json['videoId'],
      videoTitle: json['videoTitle'],
      subject: json['subject'],
      currentVideoPosition: json['currentVideoPosition'],
      watchedDuration: json['watchedDuration'] != null
          ? Duration(milliseconds: json['watchedDuration'])
          : null,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      questionsAnswered: json['questionsAnswered'],
      correctAnswers: json['correctAnswers'],
      pointsEarned: json['pointsEarned'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'subject': subject,
      'currentVideoPosition': currentVideoPosition,
      'watchedDuration': watchedDuration?.inMilliseconds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'pointsEarned': pointsEarned,
    };
  }

  StudySession copyWith({
    String? id,
    String? userId,
    String? videoId,
    String? videoTitle,
    String? subject,
    int? currentVideoPosition,
    Duration? watchedDuration,
    DateTime? startTime,
    DateTime? endTime,
    int? questionsAnswered,
    int? correctAnswers,
    int? pointsEarned,
  }) {
    return StudySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      videoTitle: videoTitle ?? this.videoTitle,
      subject: subject ?? this.subject,
      currentVideoPosition: currentVideoPosition ?? this.currentVideoPosition,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }

  double get accuracy {
    if (questionsAnswered == 0) return 0.0;
    return correctAnswers / questionsAnswered;
  }

  Duration? get sessionDuration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
}