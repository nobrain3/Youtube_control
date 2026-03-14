import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
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
  bool _hasPlaybackError = false;

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

    // 재생 에러 감지 (Error 150: 외부 앱 재생 차단)
    if (_controller.value.hasError && !_hasPlaybackError) {
      setState(() {
        _hasPlaybackError = true;
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
          child: _hasPlaybackError
              ? _buildErrorWidget()
              : ClipRRect(
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

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200.h,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 48.sp,
              ),
              SizedBox(height: 16.h),
              Text(
                '이 동영상은 외부 앱에서\n재생할 수 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '동영상 소유자가 YouTube 앱에서만\n재생하도록 설정했습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () async {
                  final url = 'https://www.youtube.com/watch?v=${widget.videoId}';
                  try {
                    final uri = Uri.parse(url);
                    await url_launcher.launchUrl(
                      uri,
                      mode: url_launcher.LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    debugPrint('Failed to open YouTube: $e');
                  }
                },
                icon: Icon(Icons.open_in_new, size: 18.sp),
                label: const Text('YouTube에서 열기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}