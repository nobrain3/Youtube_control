import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../../models/question_model.dart';

class QuestionGeneratorService {
  static final QuestionGeneratorService _instance = QuestionGeneratorService._internal();
  factory QuestionGeneratorService() => _instance;
  QuestionGeneratorService._internal();

  final Dio _dio = Dio();
  final Random _random = Random();

  // 임시로 하드코딩된 문제들 (실제로는 AI API 사용)
  final Map<String, Map<int, List<Map<String, dynamic>>>> _questionBank = {
    'Mathematics': {
      1: [
        {
          'question': '다음 중 가장 큰 수는?',
          'options': ['15', '20', '10', '25'],
          'correctAnswer': '25',
          'explanation': '25가 가장 큰 수입니다.',
        },
        {
          'question': '5 + 7 = ?',
          'options': ['10', '11', '12', '13'],
          'correctAnswer': '12',
          'explanation': '5 + 7 = 12입니다.',
        },
      ],
      2: [
        {
          'question': '12 × 3 = ?',
          'options': ['36', '35', '37', '38'],
          'correctAnswer': '36',
          'explanation': '12 × 3 = 36입니다.',
        },
      ],
    },
    'Korean': {
      1: [
        {
          'question': '다음 중 명사가 아닌 것은?',
          'options': ['책', '예쁘다', '학교', '나무'],
          'correctAnswer': '예쁘다',
          'explanation': '예쁘다는 형용사입니다.',
        },
      ],
    },
    'English': {
      1: [
        {
          'question': 'What is the past tense of "go"?',
          'options': ['went', 'goed', 'gone', 'going'],
          'correctAnswer': 'went',
          'explanation': 'The past tense of "go" is "went".',
        },
      ],
    },
    'Science': {
      1: [
        {
          'question': '물이 얼면 무엇이 되나요?',
          'options': ['수증기', '얼음', '구름', '안개'],
          'correctAnswer': '얼음',
          'explanation': '물이 0도 이하에서 얼면 얼음이 됩니다.',
        },
      ],
    },
  };

  Future<Question> generateQuestion({
    required String subject,
    required int grade,
    int? difficulty,
  }) async {
    try {
      // 실제 환경에서는 OpenAI API 호출
      if (AppConfig.openaiApiKey != 'YOUR_OPENAI_API_KEY') {
        return await _generateQuestionWithAI(subject, grade, difficulty);
      }

      // 개발 환경: 하드코딩된 문제 사용
      return _generateQuestionFromBank(subject, grade, difficulty);
    } catch (e) {
      // 오류 발생 시 기본 문제 반환
      return _generateQuestionFromBank(subject, grade, difficulty);
    }
  }

  Future<Question> _generateQuestionWithAI(
    String subject,
    int grade,
    int? difficulty,
  ) async {
    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.openaiApiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an educational question generator for students. '
                  'Generate questions appropriate for grade $grade in $subject. '
                  'Return the response in JSON format with fields: '
                  'question, options (array of 4 options), correctAnswer, explanation. '
                  'Make questions educational and age-appropriate.',
            },
            {
              'role': 'user',
              'content': 'Generate a ${difficulty ?? 'medium'} difficulty multiple choice question '
                  'for grade $grade $subject. The question should be in Korean.',
            },
          ],
          'temperature': 0.7,
          'max_tokens': 500,
          'response_format': {'type': 'json_object'},
        },
      );

      final data = json.decode(response.data['choices'][0]['message']['content']);

      return Question(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        subject: subject,
        grade: grade,
        difficulty: difficulty ?? 2,
        questionText: data['question'],
        questionType: QuestionType.multipleChoice,
        options: List<String>.from(data['options']),
        correctAnswer: data['correctAnswer'],
        explanation: data['explanation'],
        createdBy: 'AI',
      );
    } catch (e) {
      throw Exception('Failed to generate AI question: $e');
    }
  }

  Question _generateQuestionFromBank(
    String subject,
    int grade,
    int? difficulty,
  ) {
    // 과목별 문제 가져오기
    final subjectQuestions = _questionBank[subject] ?? _questionBank['Mathematics'];

    // 학년별 문제 가져오기 (없으면 가장 가까운 학년)
    final gradeLevel = _findClosestGrade(subjectQuestions!.keys.toList(), grade);
    final questions = subjectQuestions[gradeLevel] ?? [];

    if (questions.isEmpty) {
      // 문제가 없으면 기본 문제 생성
      return _createDefaultQuestion(subject, grade, difficulty);
    }

    // 랜덤으로 문제 선택
    final questionData = questions[_random.nextInt(questions.length)];

    return Question(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: subject,
      grade: grade,
      difficulty: difficulty ?? 2,
      questionText: questionData['question'],
      questionType: QuestionType.multipleChoice,
      options: List<String>.from(questionData['options']),
      correctAnswer: questionData['correctAnswer'],
      explanation: questionData['explanation'],
      createdBy: 'System',
    );
  }

  int _findClosestGrade(List<int> availableGrades, int targetGrade) {
    if (availableGrades.isEmpty) return 1;
    if (availableGrades.contains(targetGrade)) return targetGrade;

    availableGrades.sort();

    // 가장 가까운 학년 찾기
    int closest = availableGrades[0];
    int minDiff = (targetGrade - closest).abs();

    for (int grade in availableGrades) {
      int diff = (targetGrade - grade).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = grade;
      }
    }

    return closest;
  }

  Question _createDefaultQuestion(String subject, int grade, int? difficulty) {
    return Question(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: subject,
      grade: grade,
      difficulty: difficulty ?? 2,
      questionText: '오늘 공부한 내용을 잘 이해했나요?',
      questionType: QuestionType.multipleChoice,
      options: ['매우 그렇다', '그렇다', '보통이다', '아니다'],
      correctAnswer: '매우 그렇다',
      explanation: '열심히 공부하는 것이 중요해요!',
      createdBy: 'System',
    );
  }

  Future<List<Question>> generateMultipleQuestions({
    required String subject,
    required int grade,
    required int count,
    int? difficulty,
  }) async {
    List<Question> questions = [];

    for (int i = 0; i < count; i++) {
      try {
        final question = await generateQuestion(
          subject: subject,
          grade: grade,
          difficulty: difficulty,
        );
        questions.add(question);
      } catch (e) {
        // 오류 발생 시 기본 문제 추가
        questions.add(_createDefaultQuestion(subject, grade, difficulty));
      }
    }

    return questions;
  }
}