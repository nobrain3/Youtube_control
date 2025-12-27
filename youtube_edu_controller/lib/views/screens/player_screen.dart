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

  @override
  void initState() {
    super.initState();
    _loadVideoDetails();
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

    // 퀴즈에서 돌아왔을 때 타이머 재시작
    if (mounted) {
      ref.read(learningTimerProvider.notifier).completeBreak();
      ref.read(learningTimerProvider.notifier).startSession();
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
    final timerState = ref.watch(learningTimerProvider);

    // 학습 브레이크 타임인 경우 팝업 표시
    if (timerState.isBreakTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStudyPopup();
      });
    }

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
            Icon(
              Icons.thumb_up,
              size: 16.sp,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            SizedBox(width: 4.w),
            Text(
              '${_videoDetails!.likeCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
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