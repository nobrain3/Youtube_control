import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/player/youtube_player_widget.dart';
import '../../services/api/youtube_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/timer/learning_timer_service.dart';

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
  YouTubeVideoDetails? _videoDetails;
  bool _isLoading = true;
  final GlobalKey<ConsumerState<YouTubePlayerWidget>> _playerKey = GlobalKey();

  // 좋아요/싫어요 상태
  String _userRating = 'none'; // 'like', 'dislike', 'none'
  bool _isRatingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVideoDetails();
    _loadUserRating();
    Future(() => _loadTimerInterval());
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

      // 시청 기록 저장
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
      // 시청 기록 저장 실패는 사용자에게 표시하지 않음
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
      final newRating = _userRating == 'like' ? 'none' : 'like';
      await YouTubeService().rateVideo(widget.videoId, newRating);

      setState(() {
        _userRating = newRating;
        _isRatingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRating == 'like' ? '좋아요를 눌렀습니다!' : '좋아요를 취소했습니다'),
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
      final newRating = _userRating == 'dislike' ? 'none' : 'dislike';
      await YouTubeService().rateVideo(widget.videoId, newRating);

      setState(() {
        _userRating = newRating;
        _isRatingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRating == 'dislike' ? '싫어요를 눌렀습니다!' : '싫어요를 취소했습니다'),
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
    ref.read(learningTimerProvider.notifier).stopSession();
    super.dispose();
  }

  void _showStudyPopup() {
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
              // 나중에를 선택해도 타이머는 계속 진행
              ref.read(learningTimerProvider.notifier).completeBreak();
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              // 먼저 브레이크 완료 처리하여 isBreakTime을 false로 만듦
              ref.read(learningTimerProvider.notifier).completeBreak();
              Navigator.of(context).pop();
              _navigateToQuestion();
            },
            child: const Text('문제 풀기'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToQuestion() async {
    // 타이머 일시정지
    ref.read(learningTimerProvider.notifier).pauseSession();

    await context.push('/question', extra: {
      'videoId': widget.videoId,
      'videoTitle': widget.videoTitle,
      'currentTime': 0,
      'watchedDuration': 0,
    });

    // 퀴즈에서 돌아왔을 때 영상 자동 재생 (재생 시 타이머가 자동으로 시작됨)
    if (mounted) {
      ref.read(learningTimerProvider.notifier).completeBreak();
      // 영상 재생 - YouTube 플레이어의 play() 메서드 호출
      _playVideo();
    }
  }

  void _playVideo() {
    try {
      final playerState = _playerKey.currentState;
      if (playerState != null && playerState.mounted) {
        // YouTubePlayerWidget의 play() 메서드 호출
        (playerState as dynamic).play();
      }
    } catch (e) {
      debugPrint('Failed to play video: $e');
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
          _showStudyPopup();
        }
      },
    );

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // YouTube Player
                  YouTubePlayerWidget(
                    key: _playerKey,
                    videoId: widget.videoId,
                    videoTitle: widget.videoTitle,
                  ),

                  SizedBox(height: 24.h),

                  // Study Timer Info
                  _buildStudyTimerInfo(),

                  SizedBox(height: 24.h),

                  // Video Info
                  if (_videoDetails != null) _buildVideoInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildStudyTimerInfo() {
    final timerState = ref.watch(learningTimerProvider);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                '학습 타이머',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '현재 세션: ${_formatDuration(timerState.currentSession)}',
            style: TextStyle(fontSize: 14.sp),
          ),
          Text(
            '다음 문제까지: ${_formatDuration(timerState.timeUntilBreak)}',
            style: TextStyle(fontSize: 14.sp),
          ),
        ],
      ),
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
            SizedBox(width: 16.w),
            _buildLikeDislikeButtons(),
          ],
        ),
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
                  '${_videoDetails!.likeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
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
}