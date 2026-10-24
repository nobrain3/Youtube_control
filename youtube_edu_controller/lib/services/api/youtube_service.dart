import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../auth/google_auth_service.dart';
import '../../models/child_library.dart';
import '../library/child_library_service.dart';
import '../recommendation/feed_mixer.dart';
import '../../utils/app_logger.dart';

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
      logDebug('DEBUG: 캐시 히트 - $key');
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

      logDebug('DEBUG: channels.list 호출 - ${channelIds.length}개 채널 → ${result.length}개 uploads ID (1 unit)');
      _setCache(cacheKey, result, const Duration(minutes: 10));
      return result;
    } catch (e) {
      logDebug('Error in _getUploadsPlaylistIds: $e');
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
      logDebug('Error in _getPlaylistItems for $playlistId: $e');
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
        logDebug('Error in _getVideosByIds batch: $e');
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
      logDebug('Error in searchVideos: $e');
      throw Exception('동영상 검색에 실패했습니다: ${redactSecrets(e.toString())}');
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
        logDebug('DEBUG: YouTube API 키가 비어있습니다');
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

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
      logDebug('Error in getPopularVideos: $e');
      if (e is DioException) {
        logDebug('DEBUG: DioException 상세 정보:');
        logDebug('  - statusCode: ${e.response?.statusCode}');
        logDebug('  - statusMessage: ${e.response?.statusMessage}');
        logDebug('  - data: ${e.response?.data}');
        logDebug('  - path: ${e.requestOptions.path}');

        // API 오류 처리
        final statusCode = e.response?.statusCode;
        final errorData = e.response?.data;
        if (errorData != null && errorData['error'] != null) {
          final errorMessage = errorData['error']['message'] ?? '';
          final errors = errorData['error']['errors'] as List? ?? [];
          final reason = errors.isNotEmpty ? (errors[0]['reason'] ?? '') : '';

          if (reason == 'quotaExceeded' || errorMessage.contains('quota')) {
            throw Exception('할당량이 초과되었습니다. YouTube API 일일 할당량이 소진되어 내일 자정(태평양 시간) 이후 초기화됩니다.');
          } else if (statusCode == 400) {
            if (errorMessage.contains('API key expired')) {
              throw Exception('YouTube API 키가 만료되었습니다. Google Cloud Console에서 새로운 키를 생성해주세요.');
            } else if (errorMessage.contains('API key not valid')) {
              throw Exception('YouTube API 키가 유효하지 않습니다. API 키를 다시 확인해주세요.');
            }
          }
        }
      }
      throw Exception('인기 영상을 불러오는데 실패했습니다: ${redactSecrets(e.toString())}');
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
      logDebug('DEBUG: getShorts - videos.list로 ${items.length}개 중 ${result.length}개 Shorts 필터링 (1 unit)');

      _setCache(cacheKey, result, const Duration(minutes: 5));
      return result;
    } catch (e) {
      logDebug('Error in getShorts: $e');
      throw Exception('Shorts를 불러오는데 실패했습니다: ${redactSecrets(e.toString())}');
    }
  }

  // 개인화된 Shorts 가져오기
  Future<List<YouTubeVideo>> getPersonalizedShorts({int maxResults = 20}) async {
    try {
      // API 키 검증
      if (AppConfig.youtubeApiKey.isEmpty) {
        throw Exception('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.');
      }

      // 1. 아이가 담은 채널 + 좋아요한 영상의 채널 (#104)
      final channelIds = ChildLibraryService.shared.recommendationChannelIds();
      logDebug('Found ${channelIds.length} child channels for Shorts');

      if (channelIds.isEmpty) {
        // 아이 채널이 없으면 일반 Shorts 반환
        return await getShorts(maxResults: maxResults);
      }

      // 2. 아이 채널의 Shorts 가져오기
      final shorts = await _getShortsFromChannels(channelIds, maxResults);
      logDebug('Retrieved ${shorts.length} personalized shorts');

      // 구독 채널에서 Shorts를 가져오지 못하면 일반 Shorts로 fallback
      if (shorts.isEmpty) {
        logDebug('No shorts from child channels - using general shorts');
        return await getShorts(maxResults: maxResults);
      }

      return shorts;
    } catch (e) {
      // 오류 발생 시 일반 Shorts로 폴백
      logDebug('Error in personalized shorts: $e');
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

      // 2. 각 채널의 최신 영상 조회 (채널당 1 unit). 채널이 적으면 채널당 더 가져오고,
      //    같은 영상은 한 번만 넣는다 (#104)
      final perChannel =
          ((maxResults * 2) / selectedChannels.length).ceil().clamp(5, 50);
      final allVideoIds = <String>{};
      for (final channelId in selectedChannels) {
        final uploadsId = uploadsMap[channelId];
        if (uploadsId == null) continue;

        final items = await _getPlaylistItems(uploadsId, maxResults: perChannel);
        for (final item in items) {
          final videoId = item['snippet']?['resourceId']?['videoId'] as String?;
          if (videoId != null) {
            allVideoIds.add(videoId);
          }
        }
      }

      if (allVideoIds.isEmpty) return [];

      // 3. 비디오 상세 정보 조회 + duration 필터 (1 unit per 50)
      final videoDetails = await _getVideosByIds(allVideoIds.toList());

      final shorts = <YouTubeVideo>[];
      for (final item in videoDetails) {
        final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
        final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
        // 60초 이하만 Shorts로 분류
        if (parsedDuration.inSeconds <= 60 && parsedDuration.inSeconds > 0) {
          shorts.add(YouTubeVideo.fromVideoJson(item));
        }
      }

      logDebug('DEBUG: _getShortsFromChannels - ${allVideoIds.length}개 중 ${shorts.length}개 Shorts 필터링 (~${selectedChannels.length + 2} units)');

      // 날짜순으로 정렬 (최신순)
      shorts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // maxResults 개수만큼 잘라내기
      return shorts.take(maxResults).toList();
    } catch (e) {
      logDebug('Error in _getShortsFromChannels: $e');
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
      logDebug('Error in getVideoDetails: $e');
      throw Exception('동영상 정보를 불러오는데 실패했습니다: ${redactSecrets(e.toString())}');
    }
  }

  String getVideoIdFromUrl(String url) {
    final regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  /// 홈 추천 피드 최대 페이지 수 (무한 스크롤 상한).
  static const int _maxFeedPages = 5;

  /// 홈 추천 영상 (#104).
  ///
  /// 아이 채널(담은 채널 + 좋아요한 영상의 채널)의 최신 영상을 중심으로 약 30%는
  /// 발견용 영상(같은 분야 인기 영상, 크리에이터가 추천한 채널)을 섞는다.
  /// 같은 채널이 연달아 나오지 않게 배치하고(#78), 아이가 싫어요한 영상은 뺀다.
  /// 아이 채널이 없으면 인기 영상을 보여준다.
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

      final library = ChildLibraryService.shared;
      final channelIds = library.recommendationChannelIds();
      logDebug('Found ${channelIds.length} child channels');

      if (channelIds.isEmpty) {
        // 아이 채널이 없으면 인기 영상 반환
        return await getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
      }

      final page = int.tryParse(pageToken ?? '') ?? 0;
      if (page >= _maxFeedPages) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }

      // 1. 아이 채널의 최신 영상
      YouTubeSearchResult childResult;
      try {
        childResult = await _getVideosFromChannels(channelIds, maxResults, pageToken);
      } catch (e) {
        logDebug('Error in child channel videos: $e');
        childResult = YouTubeSearchResult(videos: [], nextPageToken: null);
      }

      // 2. 발견용 영상 (실패해도 아이 채널 영상만으로 진행)
      List<YouTubeVideo> discovery;
      try {
        discovery = await _getDiscoveryVideos(
          childChannelIds: channelIds.toSet(),
          seeds: childResult.videos,
          page: page,
        );
      } catch (e) {
        logDebug('Error in discovery videos: $e');
        discovery = [];
      }

      final disliked = {
        for (final v in library.ratings)
          if (v.rating == VideoRating.dislike) v.videoId,
      };
      final mixed = FeedMixer.mix(
        primary: childResult.videos,
        discovery: discovery,
        maxResults: maxResults,
        excludedVideoIds: disliked,
      );
      logDebug('DEBUG: 홈 피드 page $page - 아이 채널 ${childResult.videos.length}개 + 발견 ${discovery.length}개 → ${mixed.length}개');

      if (mixed.isEmpty && page == 0) {
        return await getPopularVideos(maxResults: maxResults, excludeShorts: excludeShorts);
      }

      final hasMore = page + 1 < _maxFeedPages && mixed.isNotEmpty;
      return YouTubeSearchResult(
        videos: mixed,
        nextPageToken: hasMore ? '${page + 1}' : null,
      );
    } catch (e) {
      // 오류 발생 시 인기 영상으로 폴백 (첫 페이지만)
      logDebug('Error in personalized recommendations: $e');
      if (pageToken != null) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }
      try {
        return await getPopularVideos(maxResults: maxResults, excludeShorts: excludeShorts);
      } catch (fallbackError) {
        logDebug('Fallback to popular videos also failed: $fallbackError');
        // 모든 방법이 실패하면 빈 결과 반환 (에러를 throw하지 않음)
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }
    }
  }

  /// 발견용 영상 (#104). YouTube는 "비슷한 영상" API를 제공하지 않으므로
  /// 아이가 보는 영상의 분야와 크리에이터가 추천한 채널로 근사한다.
  Future<List<YouTubeVideo>> _getDiscoveryVideos({
    required Set<String> childChannelIds,
    required List<YouTubeVideo> seeds,
    required int page,
  }) async {
    final result = <YouTubeVideo>[];

    // 1. 같은 분야 인기 영상 (분야당 1 unit, 30분 캐시). 상위 2개 분야에서 페이지마다 4개씩.
    //    여행(19) 등 일부 분야는 인기 차트가 없어(404) 비어 있을 수 있다.
    final categories = await _topCategories(seeds);
    var categoryPopularFound = false;
    for (final categoryId in categories.take(3)) {
      final popular = await _getCategoryPopular(categoryId);
      if (popular.isEmpty) continue;
      categoryPopularFound = true;
      result.addAll(popular.skip(page * 4).take(4));
    }
    // 분야 인기 영상을 하나도 못 찾으면 교육(27) 분야, 그것도 없으면 전체 인기 영상으로 대신한다
    if (!categoryPopularFound) {
      for (final fallback in const [_educationCategoryId, '']) {
        final popular = await _getCategoryPopular(fallback);
        if (popular.isEmpty) continue;
        result.addAll(popular.skip(page * 6).take(6));
        break;
      }
    }

    // 2. 크리에이터가 채널 페이지에 걸어둔 추천 채널 (채널당 1 unit, 6시간 캐시).
    //    페이지마다 다른 추천 채널 2개의 최신 영상 3개씩.
    final featured = (await _getFeaturedChannels(childChannelIds.take(3).toList()))
        .where((id) => !childChannelIds.contains(id))
        .toList();
    final picked = featured.skip(page * 2).take(2).toList();
    if (picked.isNotEmpty) {
      result.addAll(await _getLatestLongVideos(picked, perChannel: 3));
    }
    return result;
  }

  /// 아이 채널 영상과 좋아요한 영상에서 많이 나온 분야(categoryId) 순.
  Future<List<String>> _topCategories(List<YouTubeVideo> seeds) async {
    final counts = <String, int>{};
    void count(String categoryId) {
      if (categoryId.isEmpty) return;
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    for (final video in seeds) {
      count(video.categoryId);
    }

    // 최근 좋아요한 영상 20개의 분야 (1 unit, 30분 캐시)
    final liked = ChildLibraryService.shared.ratings
        .where((v) => v.rating == VideoRating.like)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final likedIds = [for (final v in liked.take(20)) v.videoId];
    if (likedIds.isNotEmpty) {
      final cacheKey = 'liked_categories_${likedIds.join(',')}';
      var likedCategories = _getFromCache<List<String>>(cacheKey);
      if (likedCategories == null) {
        final items = await _getVideosByIds(likedIds, part: 'snippet');
        likedCategories = [
          for (final item in items) item['snippet']?['categoryId'] as String? ?? '',
        ];
        _setCache(cacheKey, likedCategories, const Duration(minutes: 30));
      }
      // 아이가 직접 좋아요한 신호는 가중치 2배
      for (final categoryId in likedCategories) {
        count(categoryId);
        count(categoryId);
      }
    }

    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted;
  }

  /// YouTube 분야 ID: 교육
  static const String _educationCategoryId = '27';

  /// 분야별 한국 인기 영상 (Shorts 제외, 1 unit, 30분 캐시). [categoryId]가 빈 값이면 전체.
  /// 인기 차트를 지원하지 않는 분야는 빈 목록.
  Future<List<YouTubeVideo>> _getCategoryPopular(String categoryId) async {
    final cacheKey = 'category_popular_$categoryId';
    final cached = _getFromCache<List<YouTubeVideo>>(cacheKey);
    if (cached != null) return cached;

    var result = <YouTubeVideo>[];
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/videos',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'chart': 'mostPopular',
          'regionCode': 'KR',
          if (categoryId.isNotEmpty) 'videoCategoryId': categoryId,
          'maxResults': 30,
          'key': AppConfig.youtubeApiKey,
        },
      );
      final List<dynamic> items = response.data['items'] ?? [];
      result = [
        for (final item in items)
          if (YouTubeVideoDetails._parseDuration(
                      item['contentDetails']?['duration'] as String? ?? 'PT0S')
                  .inSeconds >
              60)
            YouTubeVideo.fromVideoJson(item),
      ];
    } catch (e) {
      logDebug('DEBUG: 분야 $categoryId 인기 영상 조회 실패 (지원하지 않는 분야일 수 있음): $e');
    }
    _setCache(cacheKey, result, const Duration(minutes: 30));
    return result;
  }

  /// 채널 페이지의 "추천 채널" 섹션에 있는 채널 ID (채널당 1 unit, 6시간 캐시).
  Future<List<String>> _getFeaturedChannels(List<String> channelIds) async {
    final result = <String>[];
    for (final channelId in channelIds) {
      final cacheKey = 'featured_$channelId';
      var featured = _getFromCache<List<String>>(cacheKey);
      if (featured == null) {
        featured = [];
        try {
          final response = await _dio.get(
            'https://www.googleapis.com/youtube/v3/channelSections',
            queryParameters: {
              'part': 'contentDetails',
              'channelId': channelId,
              'key': AppConfig.youtubeApiKey,
            },
          );
          final List<dynamic> items = response.data['items'] ?? [];
          for (final item in items) {
            final List<dynamic> channels =
                item['contentDetails']?['channels'] ?? [];
            featured.addAll(channels.whereType<String>());
          }
        } catch (e) {
          logDebug('DEBUG: 추천 채널 조회 실패 ($channelId): $e');
        }
        _setCache(cacheKey, featured, const Duration(hours: 6));
      }
      for (final id in featured) {
        if (!result.contains(id)) result.add(id);
      }
    }
    return result;
  }

  /// 채널별 최신 일반 영상(Shorts 제외) [perChannel]개씩.
  Future<List<YouTubeVideo>> _getLatestLongVideos(
    List<String> channelIds, {
    required int perChannel,
  }) async {
    final uploadsMap = await _getUploadsPlaylistIds(channelIds);
    final videoIds = <String>{};
    for (final channelId in channelIds) {
      final uploadsId = uploadsMap[channelId];
      if (uploadsId == null) continue;
      // Shorts가 섞여 있을 수 있어 2배를 가져와 거른다
      final items = await _getPlaylistItems(uploadsId, maxResults: perChannel * 2);
      for (final item in items) {
        final videoId = item['snippet']?['resourceId']?['videoId'] as String?;
        if (videoId != null) videoIds.add(videoId);
      }
    }
    if (videoIds.isEmpty) return [];

    final details = await _getVideosByIds(videoIds.toList());
    final perChannelCount = <String, int>{};
    final result = <YouTubeVideo>[];
    for (final item in details) {
      final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
      if (YouTubeVideoDetails._parseDuration(duration).inSeconds <= 60) continue;
      final video = YouTubeVideo.fromVideoJson(item);
      final count = perChannelCount[video.channelId] ?? 0;
      if (count >= perChannel) continue;
      perChannelCount[video.channelId] = count + 1;
      result.add(video);
    }
    return result;
  }

  /// 홈 추천 피드의 채널 순서 (페이지 간 유지).
  List<String>? _feedChannelOrder;

  static bool _sameMembers(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// OAuth 토큰이 필요한 요청 (#103). 기기에 캐시된 토큰이 폐기돼 401이 나면
  /// 캐시를 지우고 새 토큰으로 한 번 다시 보낸다.
  Future<Response<dynamic>> _withTokenRetry(
    String accessToken,
    YouTubePermission permission,
    Future<Response<dynamic>> Function(String token) send,
  ) async {
    try {
      return await send(accessToken);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      final fresh =
          await GoogleAuthService().refreshAccessToken(permission: permission);
      if (fresh == null || fresh == accessToken) rethrow;
      return send(fresh);
    }
  }

  /// 보호자 YouTube 구독 채널 목록 (#104). 보호자가 골라서 아이 채널로 가져올 때만 쓴다.
  /// [YouTubePermission.subscriptions] 권한이 없으면 예외.
  Future<List<YouTubeChannelInfo>> getGuardianSubscriptions({int maxPages = 4}) async {
    final accessToken = await GoogleAuthService()
        .getAccessToken(permission: YouTubePermission.subscriptions);
    if (accessToken == null) {
      throw Exception('YouTube 구독 목록 권한이 없습니다');
    }

    final result = <YouTubeChannelInfo>[];
    String? pageToken;
    for (var page = 0; page < maxPages; page++) {
      final response = await _withTokenRetry(
        accessToken,
        YouTubePermission.subscriptions,
        (token) => _dio.get(
          'https://www.googleapis.com/youtube/v3/subscriptions',
          queryParameters: {
            'part': 'snippet',
            'mine': 'true',
            'maxResults': 50,
            'order': 'alphabetical',
            if (pageToken != null) 'pageToken': pageToken,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
            },
          ),
        ),
      );
      final List<dynamic> items = response.data['items'] ?? [];
      for (final item in items) {
        final snippet = item['snippet'];
        final channelId = snippet?['resourceId']?['channelId'] as String?;
        if (channelId == null) continue;
        result.add(YouTubeChannelInfo(
          id: channelId,
          title: snippet['title'] ?? '',
          thumbnailUrl: snippet['thumbnails']?['default']?['url'] ?? '',
        ));
      }
      pageToken = response.data['nextPageToken'] as String?;
      if (pageToken == null) break;
    }
    return result;
  }

  /// 채널 이름·썸네일 조회 (50개당 1 unit). 저장은 ID만 하고 표시할 때 조회한다 (#104).
  Future<List<YouTubeChannelInfo>> getChannelsInfo(List<String> channelIds) async {
    final result = <YouTubeChannelInfo>[];
    for (var i = 0; i < channelIds.length; i += 50) {
      final batch = channelIds.sublist(i, (i + 50).clamp(0, channelIds.length));
      final response = await _dio.get(
        'https://www.googleapis.com/youtube/v3/channels',
        queryParameters: {
          'part': 'snippet',
          'id': batch.join(','),
          'maxResults': 50,
          'key': AppConfig.youtubeApiKey,
        },
      );
      final List<dynamic> items = response.data['items'] ?? [];
      for (final item in items) {
        final snippet = item['snippet'];
        result.add(YouTubeChannelInfo(
          id: item['id'] as String,
          title: snippet?['title'] ?? '',
          thumbnailUrl: snippet?['thumbnails']?['default']?['url'] ?? '',
        ));
      }
    }
    return result;
  }

  // 특정 채널들의 최신 영상 가져오기 (최적화: playlistItems 사용)
  Future<YouTubeSearchResult> _getVideosFromChannels(
    List<String> channelIds,
    int maxResults,
    String? pageToken,
  ) async {
    try {
      // 채널 순서는 첫 페이지(새로고침)마다 섞고, 다음 페이지에서는 같은 순서를 유지해
      // 페이지끼리 같은 채널이 겹치지 않게 한다
      final distinctChannels = channelIds.toSet().toList();
      if (pageToken == null ||
          _feedChannelOrder == null ||
          !_sameMembers(_feedChannelOrder!, distinctChannels)) {
        _feedChannelOrder = distinctChannels..shuffle();
      }
      final shuffledChannels = _feedChannelOrder!;

      // 페이지네이션: pageToken에 따라 다음 채널 묶음 선택 (중복 없이, 순환하지 않음)
      final int offset = pageToken != null ? int.tryParse(pageToken) ?? 0 : 0;
      final int channelsPerPage = 5;
      final startIndex = offset * channelsPerPage;
      final availableChannels = shuffledChannels.length;
      if (startIndex >= availableChannels) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }
      final selectedChannels = shuffledChannels.sublist(
        startIndex,
        (startIndex + channelsPerPage).clamp(0, availableChannels),
      );

      // 채널이 적으면 채널당 영상을 더 가져와 피드를 채운다
      // (Shorts가 섞여 있어 걸러지므로 목표의 2배를 요청)
      final perChannel =
          ((maxResults * 2) / selectedChannels.length).ceil().clamp(5, 50);

      // 1. uploads 플레이리스트 ID 조회 (1 unit)
      final uploadsMap = await _getUploadsPlaylistIds(selectedChannels);
      if (uploadsMap.isEmpty) {
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }

      // 2. 각 채널의 최신 영상 조회 (채널당 1 unit). 같은 영상은 한 번만.
      final allVideoIds = <String>{};
      for (final channelId in selectedChannels) {
        final uploadsId = uploadsMap[channelId];
        if (uploadsId == null) continue;

        final items = await _getPlaylistItems(uploadsId, maxResults: perChannel);
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
      final videoDetails = await _getVideosByIds(allVideoIds.toList());

      List<YouTubeVideo> allVideos = [];
      for (final item in videoDetails) {
        final duration = item['contentDetails']?['duration'] as String? ?? 'PT0S';
        final parsedDuration = YouTubeVideoDetails._parseDuration(duration);
        // 60초 초과만 일반 영상으로 분류 (Shorts 제외)
        if (parsedDuration.inSeconds > 60) {
          allVideos.add(YouTubeVideo.fromVideoJson(item));
        }
      }

      logDebug('DEBUG: _getVideosFromChannels - ${allVideoIds.length}개 중 ${allVideos.length}개 일반 영상 필터링 (~${selectedChannels.length + 2} units)');

      // 채널마다 최신순으로 정렬한 뒤 채널을 돌아가며 섞는다 (#78)
      allVideos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final resultVideos =
          FeedMixer.interleaveByChannel(allVideos).take(maxResults).toList();

      // 다음 페이지 토큰 생성 (채널이 충분히 있으면)
      final hasMoreChannels = (offset + 1) * channelsPerPage < availableChannels;
      final nextToken = hasMoreChannels ? '${offset + 1}' : null;

      return YouTubeSearchResult(
        videos: resultVideos,
        nextPageToken: nextToken,
      );
    } catch (e) {
      logDebug('Error in _getVideosFromChannels: $e');
      throw Exception('Failed to get videos from channels: $e');
    }
  }
}

class YouTubeVideo {
  final String id;
  final String title;
  final String channelId;

  /// YouTube 분야 ID (videos.list 응답에만 있음). 발견용 추천에 쓴다 (#104).
  final String categoryId;
  final String channelTitle;
  final String thumbnailUrl;
  final String description;
  final DateTime publishedAt;

  YouTubeVideo({
    required this.id,
    required this.title,
    this.channelId = '',
    this.categoryId = '',
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
      channelId: snippet['channelId'] ?? '',
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
      channelId: snippet['channelId'] ?? '',
      categoryId: snippet['categoryId'] ?? '',
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
  final String channelId;
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
    this.channelId = '',
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
      channelId: snippet['channelId'] ?? '',
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

/// 채널 표시 정보. 화면 표시용으로만 쓰고 저장하지 않는다 (#104).
class YouTubeChannelInfo {
  final String id;
  final String title;
  final String thumbnailUrl;

  const YouTubeChannelInfo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
  });
}
