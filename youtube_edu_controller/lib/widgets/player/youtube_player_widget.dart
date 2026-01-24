import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../services/timer/learning_timer_service.dart';

class YouTubePlayerWidget extends ConsumerStatefulWidget {
  final String videoId;
  final String videoTitle;
  final VoidCallback? onTimeUpdate;
  final Function(Duration)? onPositionChanged;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onBreakTriggered;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.videoTitle,
    this.onTimeUpdate,
    this.onPositionChanged,
    this.onVideoEnd,
    this.onBreakTriggered,
  });

  @override
  ConsumerState<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends ConsumerState<YouTubePlayerWidget> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _wasPlayingBeforeBreak = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
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
      widget.onVideoEnd?.call();
    }

    if (_controller.value.playerState == PlayerState.playing) {
      final timerState = ref.read(learningTimerProvider);
      // 타이머 상태에 따라 명확하게 처리
      if (!timerState.isActive) {
        // 타이머가 멈춰있으면 항상 새로 시작
        ref.read(learningTimerProvider.notifier).startSession();
      }
      // 이미 활성화되어 있으면 아무것도 하지 않음 (계속 실행 중)
    } else if (_controller.value.playerState == PlayerState.paused) {
      ref.read(learningTimerProvider.notifier).pauseSession();
    }

    if (widget.onPositionChanged != null) {
      final position = _controller.value.position;
      widget.onPositionChanged!(position);
    }

    widget.onTimeUpdate?.call();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    super.dispose();
  }

  void play() {
    if (_isPlayerReady) {
      _controller.play();
    }
  }

  void pause() {
    if (_isPlayerReady) {
      _controller.pause();
    }
  }

  void seekTo(Duration position) {
    if (_isPlayerReady) {
      _controller.seekTo(position);
    }
  }

  Duration get currentPosition => _controller.value.position;
  Duration get totalDuration => _controller.metadata.duration;
  bool get isPlaying => _controller.value.playerState == PlayerState.playing;
  bool get isPaused => _controller.value.playerState == PlayerState.paused;

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(learningTimerProvider);

    ref.listen<LearningTimerState>(learningTimerProvider, (previous, next) {
      if (next.isBreakTime && !previous!.isBreakTime) {
        _wasPlayingBeforeBreak = isPlaying;
        if (isPlaying) {
          pause();
        }
        widget.onBreakTriggered?.call();
      }
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200.h,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: YoutubePlayer(
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
          ),
        ),
        if (_isPlayerReady) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: _buildTimerDisplay(timerState),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: _buildCustomControls(),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                final currentPos = _controller.value.position;
                final newPos = currentPos - const Duration(seconds: 10);
                _controller.seekTo(newPos);
              },
              icon: const Icon(Icons.replay_10),
              iconSize: 32.sp,
            ),
            SizedBox(width: 16.w),
            IconButton(
              onPressed: () {
                if (isPlaying) {
                  pause();
                } else {
                  play();
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
                final currentPos = _controller.value.position;
                final newPos = currentPos + const Duration(seconds: 10);
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
                  value: currentPosition.inSeconds.toDouble(),
                  max: totalDuration.inSeconds.toDouble(),
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

  Widget _buildTimerDisplay(LearningTimerState timerState) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: timerState.isBreakTime
            ? Colors.orange.withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: timerState.isBreakTime
              ? Colors.orange
              : Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '학습 시간',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                _formatDuration(timerState.currentSession),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timerState.isBreakTime ? '휴식 시간!' : '다음 문제까지',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: timerState.isBreakTime
                      ? Colors.orange
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                timerState.isBreakTime
                    ? '문제 풀이 중'
                    : _formatDuration(timerState.timeUntilBreak),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: timerState.isBreakTime
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Icon(
            timerState.isBreakTime
                ? Icons.quiz
                : (timerState.isActive ? Icons.timer : Icons.timer_off),
            color: timerState.isBreakTime
                ? Colors.orange
                : Theme.of(context).colorScheme.primary,
            size: 24.sp,
          ),
        ],
      ),
    );
  }

  void resumeAfterBreak() {
    ref.read(learningTimerProvider.notifier).completeBreak();
    if (_wasPlayingBeforeBreak) {
      play();
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
}