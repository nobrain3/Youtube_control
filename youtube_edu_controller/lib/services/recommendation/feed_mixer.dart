import '../api/youtube_service.dart';

/// 홈 추천 피드를 섞는 규칙 (#104, #78).
///
/// - 아이 채널 영상(primary)을 중심에 두고 발견용 영상(discovery)을 일정 비율로 고르게 끼워 넣는다.
/// - 한쪽이 모자라면 다른 쪽으로 채운다.
/// - 같은 영상, 아이가 싫어요한 영상은 빼고, 같은 채널 영상이 연달아 오지 않게 배치한다.
///
/// API 호출 없이 순수하게 동작하므로 단위 테스트로 검증한다.
class FeedMixer {
  const FeedMixer._();

  static List<YouTubeVideo> mix({
    required List<YouTubeVideo> primary,
    required List<YouTubeVideo> discovery,
    required int maxResults,
    double discoveryRatio = 0.3,
    Set<String> excludedVideoIds = const {},
  }) {
    final seen = <String>{...excludedVideoIds};
    List<YouTubeVideo> unique(List<YouTubeVideo> videos) =>
        [for (final v in videos) if (seen.add(v.id)) v];

    final primaryPool = interleaveByChannel(unique(primary));
    final discoveryPool = interleaveByChannel(unique(discovery));

    // 목표 개수. 한쪽이 모자라면 다른 쪽으로 채운다.
    var discoveryCount =
        (maxResults * discoveryRatio).round().clamp(0, discoveryPool.length);
    final primaryCount =
        (maxResults - discoveryCount).clamp(0, primaryPool.length);
    discoveryCount =
        (maxResults - primaryCount).clamp(0, discoveryPool.length);

    final total = primaryCount + discoveryCount;
    final result = <YouTubeVideo>[];
    var p = 0;
    var d = 0;
    for (var i = 0; i < total; i++) {
      // 지금까지 넣은 발견용 비율이 목표보다 낮으면 발견용을 넣는다 (첫 칸은 아이 채널)
      final wantDiscovery = d < discoveryCount &&
          (p >= primaryCount || (i > 0 && d * total < discoveryCount * i));
      if (wantDiscovery) {
        result.add(discoveryPool[d++]);
      } else {
        result.add(primaryPool[p++]);
      }
    }
    return avoidConsecutiveChannels(result);
  }

  /// 채널별로 묶은 뒤 돌아가며 하나씩 꺼낸다 (#78). 각 채널 안의 순서는 유지한다.
  static List<YouTubeVideo> interleaveByChannel(List<YouTubeVideo> videos) {
    final groups = <String, List<YouTubeVideo>>{};
    for (final video in videos) {
      groups.putIfAbsent(_channelKey(video), () => []).add(video);
    }
    final queues = groups.values.toList();
    final result = <YouTubeVideo>[];
    for (var round = 0; result.length < videos.length; round++) {
      for (final queue in queues) {
        if (round < queue.length) result.add(queue[round]);
      }
    }
    return result;
  }

  /// 같은 채널이 연달아 오면 뒤에서 다른 채널 영상을 찾아 앞으로 당긴다.
  /// 대신할 영상이 없으면(남은 영상이 모두 같은 채널) 그대로 둔다.
  static List<YouTubeVideo> avoidConsecutiveChannels(List<YouTubeVideo> videos) {
    final result = List<YouTubeVideo>.from(videos);
    for (var i = 1; i < result.length; i++) {
      final previous = _channelKey(result[i - 1]);
      if (_channelKey(result[i]) != previous) continue;
      final swapIndex = result.indexWhere(
        (v) => _channelKey(v) != previous,
        i + 1,
      );
      if (swapIndex == -1) break;
      result.insert(i, result.removeAt(swapIndex));
    }
    return result;
  }

  // 채널을 모르는 영상은 서로 다른 채널로 취급한다
  static String _channelKey(YouTubeVideo video) =>
      video.channelId.isNotEmpty ? video.channelId : 'video:${video.id}';
}
