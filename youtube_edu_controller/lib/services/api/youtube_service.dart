import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../auth/google_auth_service.dart';

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

  Future<YouTubeSearchResult> getPopularVideos({
    int maxResults = 20,
    String regionCode = 'KR',
    String? pageToken,
  }) async {
    try {
      final queryParams = {
        'part': 'snippet',
        'chart': 'mostPopular',
        'maxResults': maxResults,
        'regionCode': regionCode,
        'key': AppConfig.youtubeApiKey,
      };

      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }

      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: queryParams,
      );

      final List<dynamic> items = response.data['items'];
      final videos = items.map((item) => YouTubeVideo.fromVideoJson(item)).toList();
      final nextPageToken = response.data['nextPageToken'] as String?;

      return YouTubeSearchResult(
        videos: videos,
        nextPageToken: nextPageToken,
      );
    } catch (e) {
      throw Exception('Failed to get popular videos: $e');
    }
  }

  Future<List<YouTubeVideo>> getShorts({int maxResults = 20}) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: {
          'part': 'snippet',
          'q': 'shorts',
          'type': 'video',
          'videoDuration': 'short',
          'maxResults': maxResults,
          'key': AppConfig.youtubeApiKey,
          'safeSearch': 'strict',
          'videoEmbeddable': 'true',
          'order': 'date',
        },
      );

      final List<dynamic> items = response.data['items'];
      return items.map((item) => YouTubeVideo.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get shorts: $e');
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

  // 개인화된 추천 영상 가져오기
  Future<YouTubeSearchResult> getPersonalizedRecommendations({
    int maxResults = 20,
    String? pageToken,
  }) async {
    try {
      final accessToken = await GoogleAuthService().getAccessToken();

      // 로그인하지 않았거나 토큰이 없으면 인기 영상 반환
      if (accessToken == null) {
        print('No access token - using popular videos');
        return getPopularVideos(maxResults: maxResults, pageToken: pageToken);
      }

      // 1. 사용자의 구독 채널 가져오기
      final channelIds = await _getUserSubscriptionChannelIds(accessToken);
      print('Found ${channelIds.length} subscribed channels');

      if (channelIds.isEmpty) {
        // 구독 채널이 없으면 인기 영상 반환
        print('No subscriptions - using popular videos');
        return getPopularVideos(maxResults: maxResults, pageToken: pageToken);
      }

      // 2. 구독 채널의 최신 영상 가져오기
      final videos = await _getVideosFromChannels(channelIds, maxResults, pageToken);
      print('Retrieved ${videos.videos.length} personalized videos');

      return videos;
    } catch (e) {
      // 오류 발생 시 인기 영상으로 폴백
      print('Error in personalized recommendations: $e');
      return getPopularVideos(maxResults: maxResults, pageToken: pageToken);
    }
  }

  // 사용자의 구독 채널 ID 목록 가져오기
  Future<List<String>> _getUserSubscriptionChannelIds(String accessToken) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/subscriptions',
        queryParameters: {
          'part': 'snippet',
          'mine': 'true',
          'maxResults': 50,
          'key': AppConfig.youtubeApiKey,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final List<dynamic> items = response.data['items'] ?? [];
      return items
          .map((item) => item['snippet']['resourceId']['channelId'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // 특정 채널들의 최신 영상 가져오기
  Future<YouTubeSearchResult> _getVideosFromChannels(
    List<String> channelIds,
    int maxResults,
    String? pageToken,
  ) async {
    try {
      // 채널 ID를 랜덤하게 섞어서 다양성 확보
      final shuffledChannels = List<String>.from(channelIds)..shuffle();

      // 페이지네이션: pageToken에 따라 다른 채널 세트 선택
      final int offset = pageToken != null ? int.tryParse(pageToken) ?? 0 : 0;
      final int channelsPerPage = 5;
      final startIndex = offset * channelsPerPage;

      // 채널이 부족하면 처음부터 다시 시작 (순환)
      final availableChannels = shuffledChannels.length;
      final selectedChannels = <String>[];

      for (int i = 0; i < channelsPerPage && selectedChannels.length < channelsPerPage; i++) {
        final index = (startIndex + i) % availableChannels;
        if (index < availableChannels) {
          selectedChannels.add(shuffledChannels[index]);
        }
      }

      List<YouTubeVideo> allVideos = [];

      // 각 채널마다 최신 영상 가져오기
      for (final channelId in selectedChannels) {
        try {
          final response = await _dio.get(
            'https://www.googleapis.com/youtube/v3/search',
            queryParameters: {
              'part': 'snippet',
              'channelId': channelId,
              'type': 'video',
              'maxResults': 5, // 각 채널에서 5개씩
              'order': 'date',
              'videoEmbeddable': 'true',
              'key': AppConfig.youtubeApiKey,
            },
          );

          final List<dynamic> items = response.data['items'] ?? [];
          final videos = items.map((item) => YouTubeVideo.fromJson(item)).toList();
          allVideos.addAll(videos);
        } catch (e) {
          // 개별 채널 오류는 무시하고 계속 진행
          print('Error fetching from channel $channelId: $e');
          continue;
        }
      }

      // 날짜순으로 정렬 (최신순)
      allVideos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // maxResults 개수만큼 잘라내기
      final resultVideos = allVideos.take(maxResults).toList();

      // 다음 페이지 토큰 생성 (채널이 충분히 있으면)
      final hasMoreChannels = (offset + 1) * channelsPerPage < availableChannels;
      final nextToken = hasMoreChannels ? '${offset + 1}' : null;

      return YouTubeSearchResult(
        videos: resultVideos,
        nextPageToken: nextToken,
      );
    } catch (e) {
      print('Error in _getVideosFromChannels: $e');
      throw Exception('Failed to get videos from channels: $e');
    }
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

class YouTubeSearchResult {
  final List<YouTubeVideo> videos;
  final String? nextPageToken;

  YouTubeSearchResult({
    required this.videos,
    this.nextPageToken,
  });
}