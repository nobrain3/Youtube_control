import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
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
  bool _isFullScreen = false;

  // Fallback player for Error 150
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _useFallbackPlayer = false;
  bool _isLoadingFallback = false;

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

  Future<void> _switchToFallbackPlayer() async {
    if (_useFallbackPlayer || _isLoadingFallback) return;

    setState(() {
      _isLoadingFallback = true;
    });

    try {
      debugPrint('Switching to fallback player for video: ${widget.videoId}');
      var yt = YoutubeExplode();

      // Get video stream manifest
      var manifest = await yt.videos.streamsClient.getManifest(widget.videoId);

      // Get muxed stream (contains both video and audio)
      // Note: Muxed streams are limited to 360p
      if (manifest.muxed.isEmpty) {
        throw Exception('No muxed streams available');
      }
      var streamInfo = manifest.muxed.last; // Get highest quality muxed stream

      // Initialize video player with direct stream URL
      _videoController = VideoPlayerController.networkUrl(streamInfo.url);
      await _videoController!.initialize();

      debugPrint('Fallback player initialized: ${streamInfo.qualityLabel}');

      // Initialize Chewie controller for better UI
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // Add listener for state changes
      _videoController!.addListener(_onVideoPlayerStateChange);

      setState(() {
        _useFallbackPlayer = true;
        _isPlayerReady = true;
        _hasPlaybackError = false;
        _isLoadingFallback = false;
      });

      yt.close();
    } catch (e) {
      debugPrint('Failed to load fallback player: $e');
      setState(() {
        _isLoadingFallback = false;
        _hasPlaybackError = true;
      });
    }
  }

  void _onVideoPlayerStateChange() {
    if (_videoController == null) return;

    final isPlaying = _videoController!.value.isPlaying;
    final timerState = ref.read(learningTimerProvider);

    if (isPlaying && !timerState.isActive) {
      ref.read(learningTimerProvider.notifier).startSession();
    } else if (!isPlaying && timerState.isActive) {
      ref.read(learningTimerProvider.notifier).pauseSession();
    }

    if (_videoController!.value.position >= _videoController!.value.duration) {
      ref.read(learningTimerProvider.notifier).stopSession();
      widget.onVideoEnd?.call();
    }

    widget.onPositionChanged?.call(_videoController!.value.position);
    widget.onTimeUpdate?.call();
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
      // Error 150 감지 시 자동으로 대체 플레이어로 전환
      _switchToFallbackPlayer();
    }

    // 전체화면 상태 변경 감지
    if (_controller.value.isFullScreen != _isFullScreen) {
      setState(() {
        _isFullScreen = _controller.value.isFullScreen;
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
    _videoController?.removeListener(_onVideoPlayerStateChange);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void play() {
    if (!_isPlayerReady) return;
    if (_useFallbackPlayer) {
      _videoController?.play();
    } else {
      _controller.play();
    }
  }

  void pause() {
    if (!_isPlayerReady) return;
    if (_useFallbackPlayer) {
      _videoController?.pause();
    } else {
      _controller.pause();
    }
  }

  void seekTo(Duration position) {
    if (!_isPlayerReady) return;
    if (_useFallbackPlayer) {
      _videoController?.seekTo(position);
    } else {
      _controller.seekTo(position);
    }
  }

  Duration get currentPosition {
    if (_useFallbackPlayer) {
      return _videoController?.value.position ?? Duration.zero;
    }
    return _controller.value.position;
  }

  Duration get totalDuration {
    if (_useFallbackPlayer) {
      return _videoController?.value.duration ?? Duration.zero;
    }
    return _controller.metadata.duration;
  }

  bool get isPlaying {
    if (_useFallbackPlayer) {
      return _videoController?.value.isPlaying ?? false;
    }
    return _controller.value.playerState == PlayerState.playing;
  }

  bool get isPaused {
    if (_useFallbackPlayer) {
      return !(_videoController?.value.isPlaying ?? false);
    }
    return _controller.value.playerState == PlayerState.paused;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LearningTimerState>(learningTimerProvider, (previous, next) {
      if (next.isBreakTime && !previous!.isBreakTime) {
        _wasPlayingBeforeBreak = isPlaying;
        if (isPlaying) {
          pause();
        }
        widget.onBreakTriggered?.call();
      }
    });

    // Fallback 플레이어 사용 시 YoutubePlayerBuilder 없이 직접 렌더링
    if (_useFallbackPlayer || _isLoadingFallback || (_hasPlaybackError && !_useFallbackPlayer && !_isLoadingFallback)) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 200.h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: _buildPlayerWidget(context),
          ),
          if (_isPlayerReady && !_useFallbackPlayer) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: _buildCustomControls(),
            ),
          ],
        ],
      );
    }

    // 기본 IFrame 플레이어: YoutubePlayerBuilder로 전체화면 지원
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        setState(() {
          _isFullScreen = true;
        });
      },
      onExitFullScreen: () {
        setState(() {
          _isFullScreen = false;
        });
      },
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
        // 전체화면일 때는 player만 반환
        if (_isFullScreen) {
          return player;
        }

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
                child: player,
              ),
            ),
            if (_isPlayerReady) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: _buildCustomControls(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPlayerWidget(BuildContext context) {
    // Show loading indicator while switching to fallback
    if (_isLoadingFallback) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 16.h),
            Text(
              '대체 플레이어 로딩 중...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    // Show fallback player (Chewie)
    if (_useFallbackPlayer && _chewieController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Chewie(controller: _chewieController!),
      );
    }

    // Show error widget if playback failed completely
    if (_hasPlaybackError && !_useFallbackPlayer && !_isLoadingFallback) {
      return _buildErrorWidget();
    }

    // Show default IFrame player
    return ClipRRect(
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
    );
  }

  Widget _buildCustomControls() {
    return Padding(
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
                '동영상 재생 실패',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '대체 플레이어로도\n재생할 수 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasPlaybackError = false;
                        _useFallbackPlayer = false;
                      });
                      _initializePlayer();
                    },
                    icon: Icon(Icons.refresh, size: 18.sp),
                    label: const Text('다시 시도'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8.w),
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
                    label: const Text('YouTube 열기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}