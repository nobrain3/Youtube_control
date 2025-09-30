enum QuestionType { multipleChoice, shortAnswer, trueOrFalse }

class Question {
  final String id;
  final String subject;
  final int grade;
  final int difficulty;
  final String questionText;
  final QuestionType questionType;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String createdBy;

  Question({
    required this.id,
    required this.subject,
    required this.grade,
    required this.difficulty,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.createdBy,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      subject: json['subject'],
      grade: json['grade'],
      difficulty: json['difficulty'],
      questionText: json['questionText'],
      questionType: QuestionType.values.firstWhere(
        (type) => type.toString().split('.').last == json['questionType'],
      ),
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'],
      explanation: json['explanation'],
      createdBy: json['createdBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'grade': grade,
      'difficulty': difficulty,
      'questionText': questionText,
      'questionType': questionType.toString().split('.').last,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'createdBy': createdBy,
    };
  }
}