import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../models/question_model.dart';
import '../../models/study_session_model.dart';
import '../../services/ai/question_generator_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../config/app_config.dart';

class QuestionScreen extends StatefulWidget {
  final Map<String, dynamic> questionData;

  const QuestionScreen({
    super.key,
    required this.questionData,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with TickerProviderStateMixin {
  Question? _currentQuestion;
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool _isLoading = true;
  int _remainingAttempts = 3;
  bool _showExplanation = false;
  Timer? _autoReturnTimer;

  // 학습 세션 관련
  StudySession? _currentSession;
  int _totalQuestions = 1;
  int _correctAnswers = 0;

  late AnimationController _progressController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadQuestion();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _loadQuestion() async {
    try {
      // 기본값 설정
      final subject = _getRandomSubject();
      final grade = 3; // 기본 학년

      // 학습 세션 시작 (과목 정보와 함께)
      await _startStudySession(subject);

      final question = await QuestionGeneratorService().generateQuestion(
        subject: subject,
        grade: grade,
        difficulty: 2,
      );

      setState(() {
        _currentQuestion = question;
        _isLoading = false;
      });

      _progressController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문제를 불러올 수 없습니다: $e')),
        );
      }
    }
  }

  Future<void> _startStudySession(String subject) async {
    try {
      final storage = LocalStorageService();
      final user = storage.getCurrentUser();

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final videoData = widget.questionData;

      _currentSession = StudySession(
        id: sessionId,
        userId: user?.id ?? 'guest',
        videoId: videoData['videoId'] ?? '',
        videoTitle: videoData['videoTitle'] ?? '',
        subject: subject,
        startTime: DateTime.now(),
        questionsAnswered: 0,
        correctAnswers: 0,
        pointsEarned: 0,
        currentVideoPosition: videoData['currentTime'] ?? 0,
        watchedDuration: Duration(minutes: videoData['watchedDuration'] ?? 0),
      );
    } catch (e) {
      // 세션 생성 실패해도 문제 풀이는 진행
      print('Failed to start study session: $e');
    }
  }

  String _getRandomSubject() {
    final subjects = AppConfig.subjects;
    return subjects[DateTime.now().millisecondsSinceEpoch % subjects.length];
  }

  void _selectAnswer(String answer) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = answer;
    });

    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || _isAnswered) return;

    setState(() {
      _isAnswered = true;
    });

    _progressController.stop();

    final isCorrect = _selectedAnswer == _currentQuestion!.correctAnswer;

    // 결과 기록
    _recordAnswer(isCorrect);

    if (isCorrect) {
      _showCorrectAnswerDialog();
    } else {
      _remainingAttempts--;
      if (_remainingAttempts > 0) {
        _showIncorrectAnswerDialog();
      } else {
        _showFinalExplanationDialog();
      }
    }
  }

  void _recordAnswer(bool isCorrect) {
    if (_currentSession != null) {
      setState(() {
        _totalQuestions++;
        if (isCorrect) {
          _correctAnswers++;
          // 정답 시 포인트 부여 (남은 시도 횟수에 따라)
          final points = _remainingAttempts * 10; // 3번째 시도: 10점, 2번째: 20점, 1번째: 30점
          _currentSession = _currentSession!.copyWith(
            questionsAnswered: _totalQuestions,
            correctAnswers: _correctAnswers,
            pointsEarned: _currentSession!.pointsEarned + points,
          );
        } else {
          _currentSession = _currentSession!.copyWith(
            questionsAnswered: _totalQuestions,
            correctAnswers: _correctAnswers,
          );
        }
      });
    }
  }

  void _showCorrectAnswerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            const Text('정답이에요! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '훌륭해요! 계속 동영상을 시청해보세요.',
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _currentQuestion!.explanation,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _autoReturnTimer?.cancel();
              Navigator.of(dialogContext).pop();
              _returnToVideo();
            },
            child: const Text('계속 시청하기'),
          ),
        ],
      ),
    );
    // 1.5초 후 자동으로 다이얼로그 닫기 + 영상 복귀
    _autoReturnTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(); // 다이얼로그 닫기
        _returnToVideo();
      }
    });
  }

  void _showIncorrectAnswerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            const Text('다시 해보세요! 💪'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '아직 기회가 있어요! 다시 생각해보세요.',
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              '남은 기회: $_remainingAttempts번',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedAnswer = null;
                _isAnswered = false;
              });
            },
            child: const Text('다시 풀기'),
          ),
          if (_remainingAttempts == 1)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _showExplanation = true;
                });
              },
              child: const Text('힌트 보기'),
            ),
        ],
      ),
    );
  }

  void _showFinalExplanationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Colors.blue,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            const Text('해설을 확인해보세요 📚'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '정답: ${_currentQuestion!.correctAnswer}',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _currentQuestion!.explanation,
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToVideo();
            },
            child: const Text('동영상으로 돌아가기'),
          ),
        ],
      ),
    );
  }

  bool _sessionSaved = false;

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    _progressController.dispose();
    _bounceController.dispose();
    // dispose에서는 비동기 작업을 수행하지 않음
    // _saveStudySession()은 _returnToVideo()에서 이미 호출됨
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 문제'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _showSkipDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentQuestion == null
              ? _buildErrorState()
              : _buildQuestionContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            '문제를 불러올 수 없습니다',
            style: TextStyle(fontSize: 18.sp),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadQuestion,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // 진행 바
          _buildProgressBar(),
          SizedBox(height: 24.h),

          // 문제 정보
          _buildQuestionInfo(),
          SizedBox(height: 24.h),

          // 문제
          _buildQuestionText(),
          SizedBox(height: 32.h),

          // 힌트 (필요한 경우)
          if (_showExplanation) _buildHint(),

          // 선택지
          Expanded(child: _buildOptions()),

          // 제출 버튼
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '남은 시간',
              style: TextStyle(fontSize: 14.sp),
            ),
            Text(
              '남은 기회: $_remainingAttempts번',
              style: TextStyle(
                fontSize: 14.sp,
                color: _remainingAttempts == 1 ? Colors.red : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: 1.0 - _progressController.value,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _progressController.value > 0.7
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuestionInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.quiz,
            color: Theme.of(context).colorScheme.primary,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentQuestion!.subject,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '학년: ${_currentQuestion!.grade}학년',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionText() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _currentQuestion!.questionText,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHint() {
    if (_currentQuestion?.hint == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb,
            color: Colors.amber[700],
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '💡 힌트: ${_currentQuestion!.hint}',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.amber[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return ListView.builder(
      itemCount: _currentQuestion!.options.length,
      itemBuilder: (context, index) {
        final option = _currentQuestion!.options[index];
        final isSelected = _selectedAnswer == option;

        return AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? _bounceAnimation.value : 1.0,
              child: Container(
                margin: EdgeInsets.only(bottom: 12.h),
                child: InkWell(
                  onTap: () => _selectAnswer(option),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16.sp,
                                )
                              : null,
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 16.h, bottom: 16.h),
      child: ElevatedButton(
        onPressed: _selectedAnswer != null && !_isAnswered ? _submitAnswer : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          _selectedAnswer == null
              ? '답을 선택해주세요'
              : _isAnswered
                  ? '제출됨'
                  : '정답 확인',
          style: TextStyle(fontSize: 16.sp),
        ),
      ),
    );
  }

  void _showSkipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문제를 건너뛰시겠습니까?'),
        content: const Text('문제를 풀지 않고 동영상으로 돌아갈 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToVideo();
            },
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }

  Future<void> _returnToVideo() async {
    await _saveStudySession();
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _saveStudySession() async {
    if (_currentSession == null || _sessionSaved) return;
    _sessionSaved = true;

    try {
      final storage = LocalStorageService();

      // 세션 종료 시간 설정
      final endTime = DateTime.now();

      final finalSession = _currentSession!.copyWith(
        endTime: endTime,
      );

      await storage.saveStudySession(finalSession);

      // 시청 기록에 추가
      if (finalSession.videoId.isNotEmpty) {
        await storage.addToWatchHistory({
          'videoId': finalSession.videoId,
          'videoTitle': finalSession.videoTitle,
          'watchedDuration': finalSession.watchedDuration?.inMinutes ?? 0,
          'questionsAnswered': finalSession.questionsAnswered,
          'correctAnswers': finalSession.correctAnswers,
          'pointsEarned': finalSession.pointsEarned,
        });
      }
    } catch (e) {
      print('Failed to save study session: $e');
    }
  }

}