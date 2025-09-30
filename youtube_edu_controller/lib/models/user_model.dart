class User {
  final String id;
  final String username;
  final String email;
  final DateTime birthDate;
  final int grade;
  final List<String> preferredSubjects;
  final List<String> weakSubjects;
  final int currentLevel;
  final int totalPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.birthDate,
    required this.grade,
    required this.preferredSubjects,
    required this.weakSubjects,
    required this.currentLevel,
    required this.totalPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      birthDate: DateTime.parse(json['birthDate']),
      grade: json['grade'],
      preferredSubjects: List<String>.from(json['preferredSubjects']),
      weakSubjects: List<String>.from(json['weakSubjects']),
      currentLevel: json['currentLevel'],
      totalPoints: json['totalPoints'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'birthDate': birthDate.toIso8601String(),
      'grade': grade,
      'preferredSubjects': preferredSubjects,
      'weakSubjects': weakSubjects,
      'currentLevel': currentLevel,
      'totalPoints': totalPoints,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}