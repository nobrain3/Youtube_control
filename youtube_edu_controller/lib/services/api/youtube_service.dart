import 'package:dio/dio.dart';
import '../../config/app_config.dart';

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  final Dio _dio = Dio();

  Future<List<YouTubeVideo>> searchVideos(String query, {int maxResults = 20}) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'maxResults': maxResults,
          'key': AppConfig.youtubeApiKey,
          'safeSearch': 'strict',
          'videoEmbeddable': 'true',
        },
      );

      final List<dynamic> items = response.data['items'];
      return items.map((item) => YouTubeVideo.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to search videos: $e');
    }
  }

  Future<List<YouTubeVideo>> getPopularVideos({int maxResults = 20, String regionCode = 'KR'}) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'snippet',
          'chart': 'mostPopular',
          'maxResults': maxResults,
          'regionCode': regionCode,
          // videoCategoryId를 제거하여 모든 카테고리의 인기 동영상을 가져옵니다
          'key': AppConfig.youtubeApiKey,
        },
      );

      final List<dynamic> items = response.data['items'];
      return items.map((item) => YouTubeVideo.fromVideoJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get popular videos: $e');
    }
  }

  Future<YouTubeVideoDetails> getVideoDetails(String videoId) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
          'key': AppConfig.youtubeApiKey,
        },
      );

      final List<dynamic> items = response.data['items'];
      if (items.isEmpty) {
        throw Exception('Video not found');
      }

      return YouTubeVideoDetails.fromJson(items.first);
    } catch (e) {
      throw Exception('Failed to get video details: $e');
    }
  }

  String getVideoIdFromUrl(String url) {
    final regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }
}

class YouTubeVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String description;
  final DateTime publishedAt;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.description,
    required this.publishedAt,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return YouTubeVideo(
      id: json['id']['videoId'],
      title: snippet['title'],
      channelTitle: snippet['channelTitle'],
      thumbnailUrl: snippet['thumbnails']['medium']['url'],
      description: snippet['description'],
      publishedAt: DateTime.parse(snippet['publishedAt']),
    );
  }

  factory YouTubeVideo.fromVideoJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return YouTubeVideo(
      id: json['id'],
      title: snippet['title'],
      channelTitle: snippet['channelTitle'],
      thumbnailUrl: snippet['thumbnails']['medium']['url'],
      description: snippet['description'],
      publishedAt: DateTime.parse(snippet['publishedAt']),
    );
  }
}

class YouTubeVideoDetails {
  final String id;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String description;
  final Duration duration;
  final int viewCount;
  final int likeCount;
  final DateTime publishedAt;

  YouTubeVideoDetails({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.description,
    required this.duration,
    required this.viewCount,
    required this.likeCount,
    required this.publishedAt,
  });

  factory YouTubeVideoDetails.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final contentDetails = json['contentDetails'];
    final statistics = json['statistics'];

    return YouTubeVideoDetails(
      id: json['id'],
      title: snippet['title'],
      channelTitle: snippet['channelTitle'],
      thumbnailUrl: snippet['thumbnails']['medium']['url'],
      description: snippet['description'],
      duration: _parseDuration(contentDetails['duration']),
      viewCount: int.tryParse(statistics['viewCount'] ?? '0') ?? 0,
      likeCount: int.tryParse(statistics['likeCount'] ?? '0') ?? 0,
      publishedAt: DateTime.parse(snippet['publishedAt']),
    );
  }

  static Duration _parseDuration(String duration) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);

    if (match == null) return Duration.zero;

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}