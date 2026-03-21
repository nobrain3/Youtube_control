import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../services/api/youtube_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/timer/learning_timer_service.dart';
import '../../services/ai/question_generator_service.dart';
import '../../models/question_model.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String videoTitle;

  const PlayerScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late YoutubePlayerController _controller;
  YouTubeVideoDetails? _videoDetails;
  bool _isLoading = true;
  bool _isPlayerReady = false;
  bool _showQuestionOverlay = false;
  Question? _currentQuestion;
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool _isQuestionLoading = false;

  // 좋아요/싫어요 상태
  String _userRating = 'none'; // 'like', 'dislike', 'none'
  bool _isRatingLoading = false;
  int? _localLikeCount; // 로컬 좋아요 수 (사용자 액션 반영)

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoDetails();
    _loadUserRating();
    Future(() => _loadTimerInterval());
  }

  void _initializePlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    );

    _controller.addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (_controller.value.isReady && !_isPlayerReady) {
      setState(() {
        _isPlayerReady = true;
      });
    }

    if (_controller.value.playerState == PlayerState.ended) {
      ref.read(learningTimerProvider.notifier).stopSession();
    }

    if (_controller.value.playerState == PlayerState.playing) {
      final timerState = ref.read(learningTimerProvider);
      if (!timerState.isActive) {
        ref.read(learningTimerProvider.notifier).startSession();
      }
    } else if (_controller.value.playerState == PlayerState.paused) {
      ref.read(learningTimerProvider.notifier).pauseSession();
    }
  }

  void _loadTimerInterval() {
    final interval = LocalStorageService().getStudyInterval();
    ref.read(learningTimerProvider.notifier).setInterval(interval);
  }

  Future<void> _loadVideoDetails() async {
    try {
      final videoDetails = await YouTubeService().getVideoDetails(widget.videoId);
      setState(() {
        _videoDetails = videoDetails;
        _isLoading = false;
      });

      await _saveToWatchHistory(videoDetails);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동영상 정보를 불러올 수 없습니다: $e')),
        );
      }
    }
  }

  Future<void> _saveToWatchHistory(YouTubeVideoDetails videoDetails) async {
    try {
      await LocalStorageService().addToWatchHistory({
        'videoId': widget.videoId,
        'title': videoDetails.title,
        'channelTitle': videoDetails.channelTitle,
        'thumbnailUrl': videoDetails.thumbnailUrl,
        'description': videoDetails.description,
      });
    } catch (e) {
      debugPrint('Failed to save watch history: $e');
    }
  }

  Future<void> _loadUserRating() async {
    try {
      final rating = await YouTubeService().getVideoRating(widget.videoId);
      setState(() {
        _userRating = rating;
      });
    } catch (e) {
      debugPrint('Failed to load user rating: $e');
    }
  }

  Future<void> _handleLike() async {
    setState(() {
      _isRatingLoading = true;
    });

    try {
      final previousRating = _userRating;
      final newRating = _userRating == 'like' ? 'none' : 'like';
      await YouTubeService().rateVideo(widget.videoId, newRating);

      setState(() {
        _userRating = newRating;
        _isRatingLoading = false;

        // 로컬 좋아요 수 업데이트
        if (_localLikeCount == null) {
          _localLikeCount = _videoDetails?.likeCount ?? 0;
        }

        if (newRating == 'like') {
          // 좋아요 누름
          if (previousRating == 'dislike') {
            _localLikeCount = _localLikeCount! + 1; // 싫어요 → 좋아요
          } else {
            _localLikeCount = _localLikeCount! + 1; // 미평가 → 좋아요
          }
        } else {
          // 좋아요 취소
          _localLikeCount = _localLikeCount! - 1;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRating == 'like' ? '👍 좋아요!' : '좋아요 취소'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRatingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('로그인')
              ? '로그인이 필요합니다'
              : '평가에 실패했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleDislike() async {
    setState(() {
      _isRatingLoading = true;
    });

    try {
      final previousRating = _userRating;
      final newRating = _userRating == 'dislike' ? 'none' : 'dislike';
      await YouTubeService().rateVideo(widget.videoId, newRating);

      setState(() {
        _userRating = newRating;
        _isRatingLoading = false;

        // 로컬 좋아요 수 업데이트 (싫어요를 누르면 좋아요가 취소될 수 있음)
        if (_localLikeCount == null) {
          _localLikeCount = _videoDetails?.likeCount ?? 0;
        }

        if (newRating == 'dislike') {
          // 싫어요 누름
          if (previousRating == 'like') {
            _localLikeCount = _localLikeCount! - 1; // 좋아요 → 싫어요
          }
        } else {
          // 싫어요 취소
          if (previousRating == 'dislike') {
            // 싫어요만 취소 (좋아요 수 변화 없음)
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRating == 'dislike' ? '👎 싫어요' : '싫어요 취소'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRatingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('로그인')
              ? '로그인이 필요합니다'
              : '평가에 실패했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    ref.read(learningTimerProvider.notifier).stopSession();
    super.dispose();
  }

  void _showStudyPopup() {
    // 전체화면 모드 확인
    if (_controller.value.isFullScreen) {
      // 전체화면일 때는 바로 오버레이 표시
      _displayQuestionOverlay();
    } else {
      // 일반 모드일 때는 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('학습 시간이에요! 📚'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('잠시 동영상을 멈추고 문제를 풀어볼까요?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(learningTimerProvider.notifier).completeBreak();
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _displayQuestionOverlay();
              },
              child: const Text('문제 풀기'),
            ),
          ],
        ),
      );
    }
  }

  void _displayQuestionOverlay() {
    ref.read(learningTimerProvider.notifier).pauseSession();
    _controller.pause();

    setState(() {
      _showQuestionOverlay = true;
      _isQuestionLoading = true;
      _currentQuestion = null;
      _selectedAnswer = null;
      _isAnswered = false;
    });

    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    try {
      final userGrade = LocalStorageService().getUserGrade();

      final question = await QuestionGeneratorService().generateQuestion(
        subject: 'general',
        grade: userGrade,
      );

      if (mounted) {
        setState(() {
          _currentQuestion = question;
          _isQuestionLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isQuestionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문제를 생성할 수 없습니다: $e')),
        );
        _hideQuestionOverlay();
      }
    }
  }

  void _hideQuestionOverlay() {
    setState(() {
      _showQuestionOverlay = false;
    });

    if (mounted) {
      ref.read(learningTimerProvider.notifier).completeBreak();
      _controller.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 학습 브레이크 타임 변경 감지하여 팝업 표시 (한 번만)
    ref.listen<LearningTimerState>(
      learningTimerProvider,
      (previous, next) {
        if (next.isBreakTime && (previous == null || !previous.isBreakTime)) {
          _controller.pause();
          _showStudyPopup();
        }
      },
    );

    return Stack(
      children: [
        YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
        topActions: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.videoTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
        onReady: () {
          setState(() {
            _isPlayerReady = true;
          });
        },
      ),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.videoTitle.isNotEmpty ? widget.videoTitle : '동영상 재생',
              style: TextStyle(fontSize: 16.sp),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  _showSettingsDialog();
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main content
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // YouTube Player
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: player,
                            ),
                          ),

                          SizedBox(height: 24.h),

                          // Video Info
                          if (_videoDetails != null) _buildVideoInfo(),
                        ],
                      ),
                    ),

              // Question overlay for normal mode
              if (_showQuestionOverlay && !_controller.value.isFullScreen)
                _buildQuestionOverlay(),
            ],
          ),
        );
      },
    ),
        // Global question overlay for fullscreen mode
        if (_showQuestionOverlay && _controller.value.isFullScreen)
          _buildQuestionOverlay(),
      ],
    );
  }

  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _videoDetails!.title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _videoDetails!.channelTitle,
          style: TextStyle(
            fontSize: 14.sp,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(
              Icons.visibility,
              size: 16.sp,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            SizedBox(width: 4.w),
            Text(
              '${_videoDetails!.viewCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}회',
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        _buildLikeDislikeButtons(),
        SizedBox(height: 16.h),
        Text(
          '설명',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _videoDetails!.description,
          style: TextStyle(fontSize: 14.sp),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLikeDislikeButtons() {
    return Row(
      children: [
        // 좋아요 버튼
        InkWell(
          onTap: _isRatingLoading ? null : _handleLike,
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _userRating == 'like'
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _userRating == 'like'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _userRating == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18.sp,
                  color: _userRating == 'like'
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${(_localLikeCount ?? _videoDetails!.likeCount).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: _userRating == 'like' ? FontWeight.w600 : FontWeight.normal,
                    color: _userRating == 'like'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 8.w),

        // 싫어요 버튼
        InkWell(
          onTap: _isRatingLoading ? null : _handleDislike,
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _userRating == 'dislike'
                  ? Colors.red.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _userRating == 'dislike'
                    ? Colors.red
                    : Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Icon(
              _userRating == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
              size: 18.sp,
              color: _userRating == 'dislike'
                  ? Colors.red
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),

        if (_isRatingLoading)
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: SizedBox(
              width: 16.w,
              height: 16.h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('문제 출제 간격'),
              subtitle: const Text('15초'),
              trailing: const Icon(Icons.edit),
              onTap: () {
                // TODO: 간격 설정 다이얼로그
              },
            ),
            ListTile(
              title: const Text('문제 난이도'),
              subtitle: const Text('자동'),
              trailing: const Icon(Icons.edit),
              onTap: () {
                // TODO: 난이도 설정 다이얼로그
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionOverlay() {
    final bool isFullscreen = _controller.value.isFullScreen;
    final double scaleFactor = isFullscreen ? 0.7 : 1.0; // 전체화면에서 텍스트 크기 30% 감소

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * (isFullscreen ? 0.7 : 0.9),
                constraints: BoxConstraints(
                  maxWidth: isFullscreen ? 500 : 600,
                  maxHeight: MediaQuery.of(context).size.height * (isFullscreen ? 0.7 : 0.8),
                ),
                padding: EdgeInsets.all(isFullscreen ? 16.w : 24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: _isQuestionLoading
                      ? _buildLoadingContent(scaleFactor)
                      : _currentQuestion != null
                          ? _buildQuestionContent(scaleFactor)
                          : _buildErrorContent(scaleFactor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent([double scaleFactor = 1.0]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16.h),
        Text(
          '문제를 생성하고 있습니다...',
          style: TextStyle(fontSize: (16 * scaleFactor).sp),
        ),
      ],
    );
  }

  Widget _buildQuestionContent([double scaleFactor = 1.0]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '학습 문제 📚',
              style: TextStyle(
                fontSize: (20 * scaleFactor).sp,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            IconButton(
              onPressed: _hideQuestionOverlay,
              icon: Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.withOpacity(0.2),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // Question
        Text(
          _currentQuestion!.questionText,
          style: TextStyle(
            fontSize: (18 * scaleFactor).sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 20.h),

        // Options
        ...List.generate(_currentQuestion!.options.length, (index) {
          final option = _currentQuestion!.options[index];
          final isSelected = _selectedAnswer == option;
          final isCorrect = _isAnswered && option == _currentQuestion!.correctAnswer;
          final isWrong = _isAnswered && isSelected && option != _currentQuestion!.correctAnswer;

          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            child: InkWell(
              onTap: _isAnswered ? null : () => _selectAnswer(option),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.1)
                      : isWrong
                          ? Colors.red.withOpacity(0.1)
                          : isSelected
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.transparent,
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : isWrong
                            ? Colors.red
                            : isSelected
                                ? Colors.blue
                                : Colors.grey.withOpacity(0.3),
                    width: isSelected || isCorrect || isWrong ? 2 : 1,
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
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                        border: Border.all(
                          color: isCorrect
                              ? Colors.green
                              : isWrong
                                  ? Colors.red
                                  : isSelected
                                      ? Colors.blue
                                      : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: isSelected || isCorrect
                          ? Icon(
                              isCorrect ? Icons.check : Icons.check,
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
                          fontSize: (16 * scaleFactor).sp,
                          fontWeight: isSelected || isCorrect || isWrong
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCorrect
                              ? Colors.green
                              : isWrong
                                  ? Colors.red
                                  : isSelected
                                      ? Colors.blue
                                      : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        SizedBox(height: 20.h),

        // Submit Button
        if (!_isAnswered)
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAnswer != null ? _submitAnswer : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                _selectedAnswer == null ? '답을 선택해주세요' : '정답 확인',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ),

        // Result and Continue Button
        if (_isAnswered) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: _selectedAnswer == _currentQuestion!.correctAnswer
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Icon(
                  _selectedAnswer == _currentQuestion!.correctAnswer
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _selectedAnswer == _currentQuestion!.correctAnswer
                      ? Colors.green
                      : Colors.red,
                  size: 32.sp,
                ),
                SizedBox(height: 8.h),
                Text(
                  _selectedAnswer == _currentQuestion!.correctAnswer
                      ? '정답입니다! 🎉'
                      : '오답입니다. 다음에 다시 도전해보세요!',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: _selectedAnswer == _currentQuestion!.correctAnswer
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                if (_currentQuestion!.explanation.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    _currentQuestion!.explanation,
                    style: TextStyle(fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _hideQuestionOverlay,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                '영상으로 돌아가기',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContent([double scaleFactor = 1.0]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          color: Colors.red,
          size: (48 * scaleFactor).sp,
        ),
        SizedBox(height: 16.h),
        Text(
          '문제를 불러올 수 없습니다',
          style: TextStyle(
            fontSize: (18 * scaleFactor).sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: _hideQuestionOverlay,
          child: Text('영상으로 돌아가기'),
        ),
      ],
    );
  }

  void _selectAnswer(String answer) {
    if (!_isAnswered) {
      setState(() {
        _selectedAnswer = answer;
      });
    }
  }

  void _submitAnswer() {
    if (_selectedAnswer != null && !_isAnswered) {
      setState(() {
        _isAnswered = true;
      });
    }
  }
}
