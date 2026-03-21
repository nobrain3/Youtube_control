import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../auth/google_auth_service.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  final Dio _dio = Dio();

  // 인메모리 캐시
  final Map<String, _CacheEntry> _cache = {};

  // 캐시에서 데이터 조회 (만료되지 않은 경우)
  T? _getFromCache<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      print('DEBUG: 캐시 히트 - $key');
      return entry.data as T;
    }
    if (entry != null && entry.isExpired) {
      _cache.remove(key);
    }
    return null;
  }

  // 캐시에 데이터 저장
  void _setCache(String key, dynamic data, Duration ttl) {
    _cache[key] = _CacheEntry(
      data: data,
      expiry: DateTime.now().add(ttl),
    );
  }

  // 채널 ID 목록에서 uploads 플레이리스트 ID 조회 (1 unit)
  Future<Map<String, String>> _getUploadsPlaylistIds(List<String> channelIds) async {
    final cacheKey = 'uploads_${channelIds.join(',')}';
    final cached = _getFromCache<Map<String, String>>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/channels',
        queryParameters: {
          'part': 'contentDetails',
          'id': channelIds.join(','),
          'key': AppConfig.youtubeApiKey,
        },
      );

      final List<dynamic> items = response.data['items'] ?? [];
      final result = <String, String>{};
      for (final item in items) {
        final channelId = item['id'] as String;
        final uploadsId = item['contentDetails']?['relatedPlaylists']?['uploads'] as String?;
        if (uploadsId != null) {
          result[channelId] = uploadsId;
        }
      }

      print('DEBUG: channels.list 호출 - ${channelIds.length}개 채널 → ${result.length}개 uploads ID (1 unit)');
      _setCache(cacheKey, result, const Duration(minutes: 10));
      return result;
    } catch (e) {
      print('Error in _getUploadsPlaylistIds: $e');
      return {};
    }
  }

  // playlistItems에서 비디오 목록 조회 (1 unit per call)
  Future<List<Map<String, dynamic>>> _getPlaylistItems(String playlistId, {int maxResults = 5}) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/playlistItems',
        queryParameters: {
          'part': 'snippet',
          'playlistId': playlistId,
          'maxResults': maxResults,
          'key': AppConfig.youtubeApiKey,
        },
      );

      return List<Map<String, dynamic>>.from(response.data['items'] ?? []);
    } catch (e) {
      print('Error in _getPlaylistItems for $playlistId: $e');
      return [];
    }
  }

  // 비디오 ID 목록으로 상세 정보 조회 (1 unit, 최대 50개)
  Future<List<Map<String, dynamic>>> _getVideosByIds(List<String> videoIds, {String part = 'snippet,contentDetails'}) async {
    if (videoIds.isEmpty) return [];

    // 50개씩 배치 처리
    final List<Map<String, dynamic>> allItems = [];
    for (int i = 0; i < videoIds.length; i += 50) {
      final batch = videoIds.skip(i).take(50).toList();
      try {
        final response = await _dio.get(
          'https://www.googleapis.com/youtube/v3/videos',
          queryParameters: {
            'part': part,
            'id': batch.join(','),
            'key': AppConfig.youtubeApiKey,
          },
        );
        allItems.addAll(List<Map<String, dynamic>>.from(response.data['items'] ?? []));
      } catch (e) {
        print('Error in _getVideosByIds batch: $e');
      }
    }
    return allItems;
  }

  Future<List<YouTubeVideo>> searchVideos(String query, {int maxResults = 20, bool excludeShorts = true}) async {
    try {
      final queryParams = {
        'part': 'snippet',
        'q': excludeShorts ? '$query -shorts -short' : query,
        'type': 'video',
        'maxResults': maxResults,
        'key': AppConfig.youtubeApiKey,
        'safeSearch': 'strict',
        'videoEmbeddable': 'true',
      };

      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: queryParams,
      );

      final List<dynamic> items = response.data['items'] ?? [];
      return items.map((item) => YouTubeVideo.fromJson(item)).toList();
    } catch (e) {
      print('Error in searchVideos: $e');
      throw Exception('동영상 검색에 실패했습니다: ${e.toString()}');
    }
  }

  Future<YouTubeSearchResult> getPopularVideos({
    int maxResults = 20,
    String regionCode = 'KR',
    String? pageToken,
    bool excludeShorts = true,
  }) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        print('DEBUG: YouTube API 키가 비어있습니다');
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      print('DEBUG: API 키 확인됨 (마지막 4자리: ${AppConfig.youtubeApiKey.substring(AppConfig.youtubeApiKey.length - 4)})');

      final queryParams = {
        'part': 'snippet,contentDetails',
        'chart': 'mostPopular',
        'maxResults': excludeShorts ? maxResults * 2 : maxResults,
        'regionCode': regionCode,
        'key': AppConfig.youtubeApiKey,
      };

      if (pageToken != null) {
        queryParams['pageToken'] = pageToken;
      }

      print('DEBUG: API 요청 시작 - URL: https://www.googleapis.com/youtube/v3/videos');
      print('DEBUG: 요청 파라미터: $queryParams');

      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: queryParams,
      );

      final List<dynamic> items = response.data['items'];
      List<YouTubeVideo> videos = items.map((item) => YouTubeVideo.fromVideoJson(item)).toList();

      // Shorts 제외 (60초 이하 영상 필터링)
      if (excludeShorts) {
        videos = videos.where((video) {
          final item = items.firstWhere((item) => item['id'] == video.id);
          final duration = item['contentDetails']['duration'] as String;
          final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
          return parsedDuration.inSeconds > 60;
        }).toList();
        videos = videos.take(maxResults).toList();
      }

      final nextPageToken = response.data['nextPageToken'] as String?;

      return YouTubeSearchResult(
        videos: videos,
        nextPageToken: nextPageToken,
      );
    } catch (e) {
      print('Error in getPopularVideos: $e');
      if (e is DioException) {
        print('DEBUG: DioException 상세 정보:');
        print('  - statusCode: ${e.response?.statusCode}');
        print('  - statusMessage: ${e.response?.statusMessage}');
        print('  - data: ${e.response?.data}');
        print('  - requestOptions: ${e.requestOptions.uri}');

        // API 키 관련 오류 처리
        if (e.response?.statusCode == 400) {
          final errorData = e.response?.data;
          if (errorData != null && errorData['error'] != null) {
            final errorMessage = errorData['error']['message'] ?? '';
            if (errorMessage.contains('API key expired')) {
              throw Exception('YouTube API 키가 만료되었습니다. Google Cloud Console에서 새로운 키를 생성해주세요.');
            } else if (errorMessage.contains('API key not valid')) {
              throw Exception('YouTube API 키가 유효하지 않습니다. API 키를 다시 확인해주세요.');
            } else if (errorMessage.contains('quotaExceeded')) {
              throw Exception('YouTube API 할당량이 초과되었습니다. 잠시 후 다시 시도해주세요.');
            }
          }
        }
      }
      throw Exception('인기 영상을 불러오는데 실패했습니다: ${e.toString()}');
    }
  }

  Future<List<YouTubeVideo>> getShorts({int maxResults = 20}) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      // 캐시 확인
      final cacheKey = 'shorts_popular_$maxResults';
      final cached = _getFromCache<List<YouTubeVideo>>(cacheKey);
      if (cached != null) return cached;

      // videos.list로 인기 영상 조회 후 duration 필터 (1 unit)
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'chart': 'mostPopular',
          'regionCode': 'KR',
          'maxResults': 50,
          'key': AppConfig.youtubeApiKey,
        },
      );

      final List<dynamic> items = response.data['items'] ?? [];
      final shorts = <YouTubeVideo>[];

      for (final item in items) {
        final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
        final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
        if (parsedDuration.inSeconds <= 60 && parsedDuration.inSeconds > 0) {
          shorts.add(YouTubeVideo.fromVideoJson(item));
        }
      }

      final result = shorts.take(maxResults).toList();
      print('DEBUG: getShorts - videos.list로 ${items.length}개 중 ${result.length}개 Shorts 필터링 (1 unit)');

      _setCache(cacheKey, result, const Duration(minutes: 5));
      return result;
    } catch (e) {
      print('Error in getShorts: $e');
      throw Exception('Shorts를 불러오는데 실패했습니다: ${e.toString()}');
    }
  }

  // 개인화된 Shorts 가져오기
  Future<List<YouTubeVideo>> getPersonalizedShorts({int maxResults = 20}) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      final accessToken = await GoogleAuthService().getAccessToken();

      // 로그인하지 않았거나 토큰이 없으면 일반 Shorts 반환
      if (accessToken == null) {
        print('No access token - using general shorts');
        return getShorts(maxResults: maxResults);
      }

      // 1. 사용자의 구독 채널 가져오기
      final channelIds = await _getUserSubscriptionChannelIds(accessToken);
      print('Found ${channelIds.length} subscribed channels for Shorts');

      if (channelIds.isEmpty) {
        // 구독 채널이 없으면 일반 Shorts 반환
        print('No subscriptions - using general shorts');
        return getShorts(maxResults: maxResults);
      }

      // 2. 구독 채널의 Shorts 가져오기
      final shorts = await _getShortsFromChannels(channelIds, maxResults);
      print('Retrieved ${shorts.length} personalized shorts');

      // 구독 채널에서 Shorts를 가져오지 못하면 일반 Shorts로 fallback
      if (shorts.isEmpty) {
        print('No shorts from subscriptions - using general shorts');
        return getShorts(maxResults: maxResults);
      }

      return shorts;
    } catch (e) {
      // 오류 발생 시 일반 Shorts로 폴백
      print('Error in personalized shorts: $e');
      return getShorts(maxResults: maxResults);
    }
  }

  // 특정 채널들의 Shorts 가져오기 (최적화: playlistItems 사용)
  Future<List<YouTubeVideo>> _getShortsFromChannels(
    List<String> channelIds,
    int maxResults,
  ) async {
    try {
      // 채널 ID를 랜덤하게 섞어서 다양성 확보
      final shuffledChannels = List<String>.from(channelIds)..shuffle();
      final selectedChannels = shuffledChannels.take(10).toList();

      // 1. uploads 플레이리스트 ID 조회 (1 unit)
      final uploadsMap = await _getUploadsPlaylistIds(selectedChannels);
      if (uploadsMap.isEmpty) return [];

      // 2. 각 채널의 최신 영상 조회 (채널당 1 unit)
      final List<String> allVideoIds = [];
      for (final channelId in selectedChannels) {
        final uploadsId = uploadsMap[channelId];
        if (uploadsId == null) continue;

        final items = await _getPlaylistItems(uploadsId, maxResults: 5);
        for (final item in items) {
          final videoId = item['snippet']?['resourceId']?['videoId'] as String?;
          if (videoId != null) {
            allVideoIds.add(videoId);
          }
        }
      }

      if (allVideoIds.isEmpty) return [];

      // 3. 비디오 상세 정보 조회 + duration 필터 (1 unit per 50)
      final videoDetails = await _getVideosByIds(allVideoIds);

      final shorts = <YouTubeVideo>[];
      for (final item in videoDetails) {
        final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
        final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
        // 60초 이하만 Shorts로 분류
        if (parsedDuration.inSeconds <= 60 && parsedDuration.inSeconds > 0) {
          shorts.add(YouTubeVideo.fromVideoJson(item));
        }
      }

      print('DEBUG: _getShortsFromChannels - ${allVideoIds.length}개 중 ${shorts.length}개 Shorts 필터링 (~${selectedChannels.length + 2} units)');

      // 날짜순으로 정렬 (최신순)
      shorts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // maxResults 개수만큼 잘라내기
      return shorts.take(maxResults).toList();
    } catch (e) {
      print('Error in _getShortsFromChannels: $e');
      throw Exception('Failed to get shorts from channels: $e');
    }
  }

  Future<YouTubeVideoDetails> getVideoDetails(String videoId) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
          'key': AppConfig.youtubeApiKey,
        },
      );

      final List<dynamic> items = response.data['items'] ?? [];
      if (items.isEmpty) {
        throw Exception('동영상을 찾을 수 없습니다');
      }

      return YouTubeVideoDetails.fromJson(items.first);
    } catch (e) {
      print('Error in getVideoDetails: $e');
      throw Exception('동영상 정보를 불러오는데 실패했습니다: ${e.toString()}');
    }
  }

  String getVideoIdFromUrl(String url) {
    final regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  /// 동영상 좋아요/싫어요 등록
  /// [rating]: 'like', 'dislike', 'none' (평가 취소)
  Future<void> rateVideo(String videoId, String rating) async {
    try {
      final accessToken = await GoogleAuthService().getAccessToken();

      if (accessToken == null) {
        throw Exception('로그인이 필요합니다');
      }

      await _dio.post(
        'https://www.googleapis.com/youtube/v3/videos/rate',
        queryParameters: {
          'id': videoId,
          'rating': rating,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to rate video: $e');
    }
  }

  /// 현재 사용자의 동영상 평가 상태 조회
  /// 반환값: 'like', 'dislike', 'none'
  Future<String> getVideoRating(String videoId) async {
    try {
      final accessToken = await GoogleAuthService().getAccessToken();

      if (accessToken == null) {
        return 'none';
      }

      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos/getRating',
        queryParameters: {
          'id': videoId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final List<dynamic> items = response.data['items'] ?? [];
      if (items.isEmpty) {
        return 'none';
      }

      return items.first['rating'] ?? 'none';
    } catch (e) {
      return 'none';
    }
  }

  // 개인화된 추천 영상 가져오기
  Future<YouTubeSearchResult> getPersonalizedRecommendations({
    int maxResults = 20,
    String? pageToken,
    bool excludeShorts = true,
  }) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      final accessToken = await GoogleAuthService().getAccessToken();

      // 로그인하지 않았거나 토큰이 없으면 인기 영상 반환
      if (accessToken == null) {
        print('No access token - using popular videos');
        return getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
      }

      // 1. 사용자의 구독 채널 가져오기
      final channelIds = await _getUserSubscriptionChannelIds(accessToken);
      print('Found ${channelIds.length} subscribed channels');

      if (channelIds.isEmpty) {
        // 구독 채널이 없으면 인기 영상 반환
        print('No subscriptions - using popular videos');
        return getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
      }

      // 2. 구독 채널의 최신 영상 가져오기
      final videos = await _getVideosFromChannels(channelIds, maxResults, pageToken);
      print('Retrieved ${videos.videos.length} personalized videos');

      // 구독 채널에서 영상을 가져오지 못하면 인기 영상으로 fallback
      if (videos.videos.isEmpty) {
        print('No videos from subscriptions - using popular videos');
        return getPopularVideos(maxResults: maxResults, pageToken: pageToken);
      }

      return videos;
    } catch (e) {
      // 오류 발생 시 인기 영상으로 폴백
      print('Error in personalized recommendations: $e');
      return getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
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

  // 특정 채널들의 최신 영상 가져오기 (최적화: playlistItems 사용)
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

      // 1. uploads 플레이리스트 ID 조회 (1 unit)
      final uploadsMap = await _getUploadsPlaylistIds(selectedChannels);
      if (uploadsMap.isEmpty) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }

      // 2. 각 채널의 최신 영상 조회 (채널당 1 unit)
      final List<String> allVideoIds = [];
      for (final channelId in selectedChannels) {
        final uploadsId = uploadsMap[channelId];
        if (uploadsId == null) continue;

        final items = await _getPlaylistItems(uploadsId, maxResults: 5);
        for (final item in items) {
          final videoId = item['snippet']?['resourceId']?['videoId'] as String?;
          if (videoId != null) {
            allVideoIds.add(videoId);
          }
        }
      }

      if (allVideoIds.isEmpty) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }

      // 3. 비디오 상세 정보 조회 + duration 필터 (1 unit per 50)
      final videoDetails = await _getVideosByIds(allVideoIds);

      List<YouTubeVideo> allVideos = [];
      for (final item in videoDetails) {
        final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
        final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
        // 60초 초과만 일반 영상으로 분류 (Shorts 제외)
        if (parsedDuration.inSeconds > 60) {
          allVideos.add(YouTubeVideo.fromVideoJson(item));
        }
      }

      print('DEBUG: _getVideosFromChannels - ${allVideoIds.length}개 중 ${allVideos.length}개 일반 영상 필터링 (~${selectedChannels.length + 2} units)');

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
      id: json['id'] is String ? json['id'] : json['id'].toString(),
      title: snippet['title'],
      channelTitle: snippet['channelTitle'],
      thumbnailUrl: snippet['thumbnails']['medium']['url'],
      description: snippet['description'],
      publishedAt: DateTime.parse(snippet['publishedAt']),
    );
  }

  factory YouTubeVideo.fromPlaylistItemJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return YouTubeVideo(
      id: snippet['resourceId']['videoId'],
      title: snippet['title'],
      channelTitle: snippet['channelTitle'] ?? snippet['videoOwnerChannelTitle'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['medium']?['url'] ?? snippet['thumbnails']?['default']?['url'] ?? '',
      description: snippet['description'] ?? '',
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
