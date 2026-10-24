import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../services/api/youtube_service.dart';
import '../../models/child_library.dart';
import '../../services/library/child_library_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/timer/learning_timer_service.dart';
import '../../services/ai/question_generator_service.dart';
import '../../models/question_model.dart';
import '../../utils/app_logger.dart';

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

  /// 한 번의 타이머 만료로 출제되는 문제 묶음 (#73).
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;

  String? _selectedAnswer;
  bool _isAnswered = false;
  bool _isQuestionLoading = false;
  Timer? _autoReturnTimer;

  /// 현재 표시 중인 문제. 묶음이 비었거나 끝났으면 null.
  Question? get _currentQuestion =>
      (_currentQuestionIndex >= 0 && _currentQuestionIndex < _questions.length)
          ? _questions[_currentQuestionIndex]
          : null;

  /// 현재 문제 뒤에 남은 문제가 있는지.
  bool get _hasNextQuestion => _currentQuestionIndex < _questions.length - 1;

  // 아이의 좋아요/싫어요·채널 담기 상태 (#104). 보호자 YouTube 계정이 아니라 앱 안에 저장한다.
  final ChildLibraryService _library = ChildLibraryService.shared;
  VideoRating? _userRating;
  bool _isChannelSaved = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoDetails();
    _userRating = _library.ratingOf(widget.videoId);
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

    // 재생/일시정지 상태 변경 시 UI 갱신 (커스텀 컨트롤 버튼 토글)
    if (mounted) {
      setState(() {});
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
        _isChannelSaved = _library.isChannelSaved(videoDetails.channelId);
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
      logDebug('Failed to save watch history: $e');
    }
  }

  /// 좋아요/싫어요를 누른다. 같은 버튼을 다시 누르면 취소한다.
  Future<void> _toggleRating(VideoRating rating) async {
    final newRating = _userRating == rating ? null : rating;
    setState(() {
      _userRating = newRating;
    });
    await _library.setRating(
      videoId: widget.videoId,
      rating: newRating,
      channelId: _videoDetails?.channelId ?? '',
    );
    if (!mounted) return;
    final message = switch (newRating) {
      VideoRating.like => '👍 좋아요! 비슷한 영상을 더 보여줄게요',
      VideoRating.dislike => '👎 싫어요',
      null => rating == VideoRating.like ? '좋아요 취소' : '싫어요 취소',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  /// 이 영상의 채널을 아이 채널 목록에 담거나 뺀다.
  Future<void> _toggleChannel() async {
    final channelId = _videoDetails?.channelId ?? '';
    if (channelId.isEmpty) return;
    final save = !_isChannelSaved;
    setState(() {
      _isChannelSaved = save;
    });
    if (save) {
      await _library.addChannel(channelId);
    } else {
      await _library.removeChannel(channelId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(save ? '📺 채널을 담았어요. 홈에서 새 영상을 볼 수 있어요' : '채널을 뺐어요'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
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
      _questions = [];
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _isAnswered = false;
    });

    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final storage = LocalStorageService();
      final userGrade = storage.getUserGrade();
      final questionCount = storage.getQuizQuestionCount();

      final questions = await QuestionGeneratorService().generateMultipleQuestions(
        subject: 'general',
        grade: userGrade,
        count: questionCount,
      );

      if (mounted) {
        setState(() {
          _questions = questions;
          _currentQuestionIndex = 0;
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

  /// 다음 문제로 넘어간다. 남은 문제가 없으면 영상으로 복귀한다.
  void _goToNextQuestion() {
    _autoReturnTimer?.cancel();

    if (!_hasNextQuestion) {
      _hideQuestionOverlay();
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _isAnswered = false;
    });
  }

  void _hideQuestionOverlay() {
    _autoReturnTimer?.cancel();
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

                          // Custom Controls
                          if (_isPlayerReady)
                            _buildCustomControls(),

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

  Widget _buildCustomControls() {
    final isPlaying = _controller.value.playerState == PlayerState.playing;
    final currentPosition = _controller.value.position;
    final totalDuration = _controller.metadata.duration;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                final newPos = currentPosition - const Duration(seconds: 10);
                _controller.seekTo(newPos);
              },
              icon: const Icon(Icons.replay_10),
              iconSize: 32.sp,
            ),
            SizedBox(width: 16.w),
            IconButton(
              onPressed: () {
                if (isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 48.sp,
              ),
            ),
            SizedBox(width: 16.w),
            IconButton(
              onPressed: () {
                final newPos = currentPosition + const Duration(seconds: 10);
                _controller.seekTo(newPos);
              },
              icon: const Icon(Icons.forward_10),
              iconSize: 32.sp,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Text(
                _formatDuration(currentPosition),
                style: TextStyle(fontSize: 12.sp),
              ),
              Expanded(
                child: Slider(
                  value: currentPosition.inSeconds.toDouble().clamp(0, totalDuration.inSeconds.toDouble()),
                  max: totalDuration.inSeconds > 0 ? totalDuration.inSeconds.toDouble() : 1,
                  onChanged: (value) {
                    _controller.seekTo(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: TextStyle(fontSize: 12.sp),
              ),
            ],
          ),
        ),
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
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final isLiked = _userRating == VideoRating.like;
    final isDisliked = _userRating == VideoRating.dislike;
    final canSaveChannel = (_videoDetails?.channelId ?? '').isNotEmpty;

    return Row(
      children: [
        // 좋아요 버튼 (YouTube 전체 좋아요 수 표시, 아이 평가는 앱에만 저장)
        _RatingChip(
          onTap: () => _toggleRating(VideoRating.like),
          selected: isLiked,
          color: primary,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 18.sp,
                color: isLiked ? primary : textColor,
              ),
              SizedBox(width: 4.w),
              Text(
                _videoDetails!.likeCount.toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},'),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
                  color: isLiked ? primary : textColor,
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 8.w),

        // 싫어요 버튼
        _RatingChip(
          onTap: () => _toggleRating(VideoRating.dislike),
          selected: isDisliked,
          color: Colors.red,
          child: Icon(
            isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
            size: 18.sp,
            color: isDisliked ? Colors.red : textColor,
          ),
        ),

        SizedBox(width: 8.w),

        // 채널 담기 버튼
        if (canSaveChannel)
          _RatingChip(
            onTap: _toggleChannel,
            selected: _isChannelSaved,
            color: primary,
            child: Row(
              children: [
                Icon(
                  _isChannelSaved
                      ? Icons.playlist_add_check
                      : Icons.playlist_add,
                  size: 18.sp,
                  color: _isChannelSaved ? primary : textColor,
                ),
                SizedBox(width: 4.w),
                Text(
                  _isChannelSaved ? '담은 채널' : '채널 담기',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight:
                        _isChannelSaved ? FontWeight.w600 : FontWeight.normal,
                    color: _isChannelSaved ? primary : textColor,
                  ),
                ),
              ],
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
            Row(
              children: [
                Text(
                  '학습 문제 📚',
                  style: TextStyle(
                    fontSize: (20 * scaleFactor).sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                // 문제가 2개 이상일 때만 진행률 표시 (#73)
                if (_questions.length > 1) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${_currentQuestionIndex + 1}/${_questions.length}',
                      style: TextStyle(
                        fontSize: (13 * scaleFactor).sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
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

        // 진행률 바 (문제가 2개 이상일 때)
        if (_questions.length > 1) ...[
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              minHeight: 6.h,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ],
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToNextQuestion,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                // 남은 문제가 있으면 다음 문제로, 없으면 영상 복귀 (#73)
                _hasNextQuestion
                    ? '다음 문제 (${_currentQuestionIndex + 2}/${_questions.length})'
                    : '영상으로 돌아가기',
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
      // 정답이면 1.5초 후 다음 문제로 진행 (마지막 문제면 영상 복귀)
      if (_selectedAnswer == _currentQuestion!.correctAnswer) {
        _autoReturnTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) _goToNextQuestion();
        });
      }
    }
  }
}

/// 좋아요·싫어요·채널 담기에 쓰는 둥근 토글 버튼.
class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.onTap,
    required this.selected,
    required this.color,
    required this.child,
  });

  final VoidCallback onTap;
  final bool selected;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
