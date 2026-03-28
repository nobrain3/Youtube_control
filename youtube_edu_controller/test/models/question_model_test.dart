import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_edu_controller/models/question_model.dart';

void main() {
  group('Question', () {
    late Question sampleQuestion;

    setUp(() {
      sampleQuestion = Question(
        id: 'q1',
        subject: 'Mathematics',
        grade: 3,
        difficulty: 2,
        questionText: '5 + 7 = ?',
        questionType: QuestionType.multipleChoice,
        options: ['10', '11', '12', '13'],
        correctAnswer: '12',
        explanation: '5 + 7 = 12입니다.',
        hint: '손가락을 사용해보세요.',
        createdBy: 'System',
      );
    });

    group('fromJson / toJson round-trip', () {
      test('should serialize and deserialize correctly', () {
        final json = sampleQuestion.toJson();
        final restored = Question.fromJson(json);

        expect(restored.id, sampleQuestion.id);
        expect(restored.subject, sampleQuestion.subject);
        expect(restored.grade, sampleQuestion.grade);
        expect(restored.difficulty, sampleQuestion.difficulty);
        expect(restored.questionText, sampleQuestion.questionText);
        expect(restored.questionType, sampleQuestion.questionType);
        expect(restored.options, sampleQuestion.options);
        expect(restored.correctAnswer, sampleQuestion.correctAnswer);
        expect(restored.explanation, sampleQuestion.explanation);
        expect(restored.hint, sampleQuestion.hint);
        expect(restored.createdBy, sampleQuestion.createdBy);
      });

      test('should handle null hint', () {
        final q = Question(
          id: 'q2',
          subject: 'Korean',
          grade: 1,
          difficulty: 1,
          questionText: '다음 중 명사는?',
          questionType: QuestionType.shortAnswer,
          options: ['책', '예쁘다'],
          correctAnswer: '책',
          explanation: '책은 명사입니다.',
          createdBy: 'AI',
        );

        final json = q.toJson();
        expect(json['hint'], isNull);

        final restored = Question.fromJson(json);
        expect(restored.hint, isNull);
      });
    });

    group('QuestionType enum conversion', () {
      test('should convert multipleChoice correctly', () {
        final json = sampleQuestion.toJson();
        expect(json['questionType'], 'multipleChoice');

        final restored = Question.fromJson(json);
        expect(restored.questionType, QuestionType.multipleChoice);
      });

      test('should convert shortAnswer correctly', () {
        final q = Question(
          id: 'q3',
          subject: 'English',
          grade: 5,
          difficulty: 3,
          questionText: 'Translate: 사과',
          questionType: QuestionType.shortAnswer,
          options: [],
          correctAnswer: 'apple',
          explanation: 'apple은 사과입니다.',
          createdBy: 'AI',
        );

        final json = q.toJson();
        expect(json['questionType'], 'shortAnswer');

        final restored = Question.fromJson(json);
        expect(restored.questionType, QuestionType.shortAnswer);
      });

      test('should convert trueOrFalse correctly', () {
        final q = Question(
          id: 'q4',
          subject: 'Science',
          grade: 4,
          difficulty: 1,
          questionText: '물은 100도에서 끓는다',
          questionType: QuestionType.trueOrFalse,
          options: ['참', '거짓'],
          correctAnswer: '참',
          explanation: '물은 100도에서 끓습니다.',
          createdBy: 'System',
        );

        final json = q.toJson();
        expect(json['questionType'], 'trueOrFalse');

        final restored = Question.fromJson(json);
        expect(restored.questionType, QuestionType.trueOrFalse);
      });
    });

    group('toJson structure', () {
      test('should include all required fields', () {
        final json = sampleQuestion.toJson();

        expect(json, containsPair('id', 'q1'));
        expect(json, containsPair('subject', 'Mathematics'));
        expect(json, containsPair('grade', 3));
        expect(json, containsPair('difficulty', 2));
        expect(json, containsPair('questionText', '5 + 7 = ?'));
        expect(json, containsPair('correctAnswer', '12'));
        expect(json, containsPair('createdBy', 'System'));
        expect(json['options'], isList);
        expect(json['options'], hasLength(4));
      });
    });
  });
}
