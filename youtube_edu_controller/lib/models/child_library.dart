/// 아이별 좋아요·싫어요와 담은 채널 (#104).
///
/// 보호자 YouTube 계정이 아니라 앱 안에 아이별로 저장한다.
/// YouTube API 데이터 정책에 맞춰 영상·채널 ID와 평가만 저장하고,
/// 제목·썸네일 같은 메타데이터는 필요할 때 API로 다시 조회한다.
library;

enum VideoRating {
  like,
  dislike;

  static VideoRating? fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// 채널을 담은 주체. 아이가 재생 화면에서 담았는지, 보호자가 가져왔는지.
enum ChannelSource {
  child,
  guardian;

  static ChannelSource fromName(String? name) {
    return name == guardian.name ? guardian : child;
  }
}

class RatedVideo {
  const RatedVideo({
    required this.videoId,
    required this.rating,
    required this.channelId,
    required this.updatedAt,
  });

  final String videoId;
  final VideoRating rating;

  /// 추천에 활용하기 위한 영상의 채널 ID. 모르면 빈 문자열.
  final String channelId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'rating': rating.name,
        'channelId': channelId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static RatedVideo? fromJson(Map<String, dynamic> json) {
    final rating = VideoRating.fromName(json['rating'] as String?);
    final videoId = json['videoId'] as String?;
    if (rating == null || videoId == null) return null;
    return RatedVideo(
      videoId: videoId,
      rating: rating,
      channelId: json['channelId'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SavedChannel {
  const SavedChannel({
    required this.channelId,
    required this.source,
    required this.addedAt,
  });

  final String channelId;
  final ChannelSource source;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'source': source.name,
        'addedAt': addedAt.toIso8601String(),
      };

  static SavedChannel? fromJson(Map<String, dynamic> json) {
    final channelId = json['channelId'] as String?;
    if (channelId == null) return null;
    return SavedChannel(
      channelId: channelId,
      source: ChannelSource.fromName(json['source'] as String?),
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// YouTube ID 형식 검사. Firestore 문서 ID로 쓰므로 보안 규칙과 같은 형식만 허용한다.
class YouTubeIds {
  static final _video = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static final _channel = RegExp(r'^UC[A-Za-z0-9_-]{22}$');

  static bool isVideoId(String id) => _video.hasMatch(id);
  static bool isChannelId(String id) => _channel.hasMatch(id);
}
