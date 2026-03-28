import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:youtube_edu_controller/services/ai/question_generator_service.dart';
import 'package:youtube_edu_controller/models/question_model.dart';

void main() {
  group('QuestionGeneratorService', () {
    late QuestionGeneratorService service;

    setUp(() {
      // Load test env so AppConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY'
      // This ensures we use the local question bank, not real AI
      dotenv.testLoad(fileInput: '''
YOUTUBE_API_KEY=TEST_KEY
OPENAI_API_KEY=YOUR_OPENAI_API_KEY
''');
      // Create a fresh instance for each test by resetting singleton state
      service = QuestionGeneratorService();
      service.resetSession();
    });

    group('generateQuestion from bank', () {
      test('should return a Mathematics question', () async {
        final q = await service.generateQuestion(
          subject: 'Mathematics',
          grade: 1,
        );

        expect(q.subject, 'Mathematics');
        expect(q.questionType, QuestionType.multipleChoice);
        expect(q.options, isNotEmpty);
        expect(q.correctAnswer, isNotEmpty);
        expect(q.explanation, isNotEmpty);
      });

      test('should return a Korean question', () async {
        final q = await service.generateQuestion(
          subject: 'Korean',
          grade: 1,
        );

        expect(q.subject, 'Korean');
        expect(q.options, isNotEmpty);
      });

      test('should return an English question', () async {
        final q = await service.generateQuestion(
          subject: 'English',
          grade: 1,
        );

        expect(q.subject, 'English');
      });

      test('should return a Science question', () async {
        final q = await service.generateQuestion(
          subject: 'Science',
          grade: 1,
        );

        expect(q.subject, 'Science');
      });

      test('should fallback to default question for unknown subject', () async {
        final q = await service.generateQuestion(
          subject: 'UnknownSubject',
          grade: 1,
        );

        // Falls back to Mathematics bank or default question
        expect(q, isNotNull);
        expect(q.options, isNotEmpty);
      });

      test('should use closest grade when exact grade unavailable', () async {
        final q = await service.generateQuestion(
          subject: 'Mathematics',
          grade: 5, // No grade 5 in bank, should use closest
        );

        expect(q, isNotNull);
        expect(q.subject, 'Mathematics');
      });

      test('should set difficulty from parameter', () async {
        final q = await service.generateQuestion(
          subject: 'Mathematics',
          grade: 1,
          difficulty: 3,
        );

        expect(q.difficulty, 3);
      });

      test('should default difficulty to 2 when not specified', () async {
        final q = await service.generateQuestion(
          subject: 'Mathematics',
          grade: 1,
        );

        expect(q.difficulty, 2);
      });
    });

    group('generateMultipleQuestions', () {
      test('should return the requested count of questions', () async {
        final questions = await service.generateMultipleQuestions(
          subject: 'Mathematics',
          grade: 1,
          count: 3,
        );

        expect(questions, hasLength(3));
        for (final q in questions) {
          expect(q.subject, 'Mathematics');
        }
      });

      test('should return empty list for count 0', () async {
        final questions = await service.generateMultipleQuestions(
          subject: 'Mathematics',
          grade: 1,
          count: 0,
        );

        expect(questions, isEmpty);
      });
    });

    group('resetSession', () {
      test('should allow previously seen questions again', () async {
        // Generate questions until duplicates would occur
        for (int i = 0; i < 5; i++) {
          await service.generateQuestion(
            subject: 'Mathematics',
            grade: 1,
          );
        }

        service.resetSession();

        // Should still work after reset
        final q = await service.generateQuestion(
          subject: 'Mathematics',
          grade: 1,
        );
        expect(q, isNotNull);
      });
    });
  });
}
