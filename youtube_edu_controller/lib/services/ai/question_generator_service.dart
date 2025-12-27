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
          'explanation': '25가 가장 큰 수입니다. 숫자를 비교할 때는 10의 자리와 1의 자리를 차례로 비교해보세요.',
          'hint': '각 숫자를 크기 순서대로 나열해보세요.',
        },
        {
          'question': '5 + 7 = ?',
          'options': ['10', '11', '12', '13'],
          'correctAnswer': '12',
          'explanation': '5 + 7 = 12입니다. 5에 7을 더하면 12가 됩니다.',
          'hint': '손가락을 사용해서 5개에 7개를 더 세어보세요.',
        },
      ],
      2: [
        {
          'question': '12 × 3 = ?',
          'options': ['36', '35', '37', '38'],
          'correctAnswer': '36',
          'explanation': '12 × 3 = 36입니다. 12를 3번 더하면 12 + 12 + 12 = 36입니다.',
          'hint': '12를 3번 더하는 것과 같습니다.',
        },
      ],
    },
    'Korean': {
      1: [
        {
          'question': '다음 중 명사가 아닌 것은?',
          'options': ['책', '예쁘다', '학교', '나무'],
          'correctAnswer': '예쁘다',
          'explanation': '예쁘다는 형용사입니다. 명사는 사물의 이름을 나타내는 말이에요.',
          'hint': '사물의 이름이 아니라 사물의 상태를 설명하는 말은 무엇일까요?',
        },
      ],
    },
    'English': {
      1: [
        {
          'question': 'What is the past tense of "go"?',
          'options': ['went', 'goed', 'gone', 'going'],
          'correctAnswer': 'went',
          'explanation': 'The past tense of "go" is "went". "Go"는 불규칙 동사이기 때문에 "goed"가 아니라 "went"로 변합니다.',
          'hint': '"Go"는 불규칙 동사입니다. "-ed"를 붙이지 않아요.',
        },
      ],
    },
    'Science': {
      1: [
        {
          'question': '물이 얼면 무엇이 되나요?',
          'options': ['수증기', '얼음', '구름', '안개'],
          'correctAnswer': '얼음',
          'explanation': '물이 0도 이하에서 얼면 얼음이 됩니다. 물이 차가워지면 고체 상태가 되는 것이죠.',
          'hint': '겨울에 물이 차가워지면 단단해지는 것은 무엇일까요?',
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
      final systemPrompt = _buildSystemPrompt(subject, grade, difficulty);
      final userPrompt = _buildUserPrompt(subject, grade, difficulty);

      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.openaiApiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.7,
          'max_tokens': 800,
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
        hint: data['hint'],
        createdBy: 'AI',
      );
    } catch (e) {
      throw Exception('Failed to generate AI question: $e');
    }
  }

  String _buildSystemPrompt(String subject, int grade, int? difficulty) {
    final gradeLevel = _getGradeLevel(grade);
    final difficultyLevel = _getDifficultyName(difficulty ?? 2);

    return '''당신은 한국 학생들을 위한 교육 문제 생성 전문가입니다.

역할: $subject 과목의 $gradeLevel 학년 수준에 맞는 객관식 문제를 생성합니다.

지침:
1. 한국 교육과정에 맞는 내용으로 문제를 만듭니다
2. 학생의 학년과 나이에 적절한 언어와 어휘를 사용합니다
3. $difficultyLevel 난이도에 맞게 문제를 조정합니다
4. 정답은 명확하고, 오답 보기는 그럴듯하게 만듭니다
5. 해설은 학생이 이해하기 쉽게 자세히 설명합니다
6. 힌트는 정답을 직접 알려주지 않으면서 학생이 스스로 생각할 수 있도록 유도합니다

응답 형식 (반드시 JSON으로만 응답):
{
  "question": "문제 내용 (한국어)",
  "options": ["선택지1", "선택지2", "선택지3", "선택지4"],
  "correctAnswer": "정답 (options 중 하나와 정확히 일치)",
  "explanation": "왜 이것이 정답인지 자세한 설명 (2-3문장)",
  "hint": "학생이 스스로 답을 찾을 수 있도록 돕는 힌트 (1-2문장)"
}''';
  }

  String _buildUserPrompt(String subject, int grade, int? difficulty) {
    final subjectGuide = _getSubjectGuide(subject, grade);
    final difficultyGuide = _getDifficultyGuide(difficulty ?? 2);

    return '''$subject 과목의 문제를 1개 생성해주세요.

과목별 가이드:
$subjectGuide

난이도 가이드:
$difficultyGuide

주의사항:
- 문제는 교육적이고 학생에게 유익해야 합니다
- 모든 내용은 한국어로 작성해주세요
- JSON 형식을 정확히 지켜주세요''';
  }

  String _getGradeLevel(int grade) {
    if (grade <= 6) return '초등학교 $grade';
    if (grade <= 9) return '중학교 ${grade - 6}';
    return '고등학교 ${grade - 9}';
  }

  String _getDifficultyName(int difficulty) {
    switch (difficulty) {
      case 1: return '쉬운';
      case 2: return '보통';
      case 3: return '어려운';
      default: return '보통';
    }
  }

  String _getSubjectGuide(String subject, int grade) {
    switch (subject) {
      case 'Mathematics':
        if (grade <= 3) {
          return '- 덧셈, 뺄셈, 간단한 곱셈 등 기초 연산\n- 도형의 기본 개념\n- 시계 읽기, 길이 재기 등';
        } else if (grade <= 6) {
          return '- 사칙연산, 분수, 소수\n- 평면도형과 입체도형\n- 비율, 백분율\n- 간단한 방정식';
        } else if (grade <= 9) {
          return '- 일차방정식, 연립방정식\n- 함수와 그래프\n- 기하학 (삼각형, 원)\n- 확률과 통계';
        } else {
          return '- 이차함수, 다항식\n- 삼각함수, 지수/로그\n- 미분과 적분 기초\n- 수열과 극한';
        }

      case 'Korean':
        if (grade <= 3) {
          return '- 한글 자음, 모음\n- 기본 어휘\n- 짧은 문장 읽기\n- 동화 이해하기';
        } else if (grade <= 6) {
          return '- 맞춤법, 띄어쓰기\n- 품사 (명사, 동사, 형용사)\n- 문장 성분\n- 동시, 이야기 이해';
        } else if (grade <= 9) {
          return '- 문법 (문장 구조, 품사)\n- 문학 작품 감상\n- 비문학 독해\n- 글쓰기 원리';
        } else {
          return '- 고전문학, 현대문학\n- 문법의 심화 개념\n- 논리적 글쓰기\n- 비판적 읽기';
        }

      case 'English':
        if (grade <= 3) {
          return '- 알파벳, 기본 단어\n- 간단한 인사말\n- 색깔, 숫자, 동물 등\n- 기초 회화 표현';
        } else if (grade <= 6) {
          return '- 기본 문법 (be동사, 일반동사)\n- 시제 (현재, 과거, 미래)\n- 일상 어휘 확장\n- 짧은 대화문';
        } else if (grade <= 9) {
          return '- 문법 (현재완료, 수동태, 부정사)\n- 독해 (짧은 지문)\n- 기본 작문\n- 일상 회화';
        } else {
          return '- 고급 문법\n- 긴 지문 독해\n- 에세이 작문\n- 영어 문학 기초';
        }

      case 'Science':
        if (grade <= 3) {
          return '- 동물과 식물\n- 계절과 날씨\n- 물질의 상태 (고체, 액체, 기체)\n- 자석, 빛';
        } else if (grade <= 6) {
          return '- 생물의 구조와 기능\n- 물질의 성질과 변화\n- 지구와 우주\n- 에너지 (전기, 자석)';
        } else if (grade <= 9) {
          return '- 생명과학 (세포, 유전)\n- 물리 (힘, 운동, 에너지)\n- 화학 (원소, 화합물, 반응)\n- 지구과학 (지구, 우주)';
        } else {
          return '- 고급 생명과학 (DNA, 진화)\n- 고급 물리 (역학, 전자기)\n- 고급 화학 (화학 반응식, 몰)\n- 천문학';
        }

      case 'Social Studies':
        if (grade <= 6) {
          return '- 우리 동네, 우리 지역\n- 지도 보기\n- 기본 경제 개념 (생산, 소비)\n- 사회 규칙과 법';
        } else if (grade <= 9) {
          return '- 한국 지리\n- 경제 (시장, 무역)\n- 정치 (민주주의, 정부)\n- 사회 문제';
        } else {
          return '- 세계 지리\n- 경제 원리 (수요공급)\n- 정치 제도\n- 글로벌 이슈';
        }

      case 'History':
        if (grade <= 6) {
          return '- 우리나라의 역사 (고조선, 삼국시대)\n- 역사적 인물\n- 문화유산';
        } else if (grade <= 9) {
          return '- 한국사 (통일신라~조선)\n- 독립운동\n- 근현대사';
        } else {
          return '- 한국사 심화\n- 세계사\n- 역사적 사건 분석';
        }

      default:
        return '- 학년 수준에 맞는 기본 개념\n- 실생활과 연결된 내용\n- 교육 과정에 맞는 주제';
    }
  }

  String _getDifficultyGuide(int difficulty) {
    switch (difficulty) {
      case 1:
        return '''쉬운 난이도:
- 기본 개념을 직접적으로 묻는 문제
- 단순 암기나 이해만으로 풀 수 있음
- 정답이 명확하고 오답이 쉽게 구별됨
- 예: "다음 중 OO은 무엇인가요?"''';

      case 2:
        return '''보통 난이도:
- 개념을 이해하고 적용해야 하는 문제
- 약간의 사고력이 필요함
- 오답이 그럴듯하지만 신중히 생각하면 정답 찾을 수 있음
- 예: "다음 상황에서 OO은?"''';

      case 3:
        return '''어려운 난이도:
- 여러 개념을 종합해야 하는 문제
- 분석력과 추론 능력이 필요함
- 오답도 논리적이어서 신중한 판단 필요
- 예: "다음 중 OO의 원리를 가장 잘 설명한 것은?"''';

      default:
        return _getDifficultyGuide(2);
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
      hint: questionData['hint'],
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
      hint: '자신감을 가지고 답해보세요!',
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