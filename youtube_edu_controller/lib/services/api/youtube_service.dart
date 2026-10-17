import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../auth/google_auth_service.dart';
import '../library/child_library_service.dart';

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

      // 1. 아이가 담은 채널 + 좋아요한 영상의 채널 (#104)
      final channelIds = ChildLibraryService.shared.recommendationChannelIds();
      print('Found ${channelIds.length} child channels for Shorts');

      if (channelIds.isEmpty) {
        // 아이 채널이 없으면 일반 Shorts 반환
        return await getShorts(maxResults: maxResults);
      }

      // 2. 아이 채널의 Shorts 가져오기
      final shorts = await _getShortsFromChannels(channelIds, maxResults);
      print('Retrieved ${shorts.length} personalized shorts');

      // 구독 채널에서 Shorts를 가져오지 못하면 일반 Shorts로 fallback
      if (shorts.isEmpty) {
        print('No shorts from child channels - using general shorts');
        return await getShorts(maxResults: maxResults);
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

      // 1. 아이가 담은 채널 + 좋아요한 영상의 채널 (#104)
      final channelIds = ChildLibraryService.shared.recommendationChannelIds();
      print('Found ${channelIds.length} child channels');

      if (channelIds.isEmpty) {
        // 아이 채널이 없으면 인기 영상 반환
        return await getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
      }

      // 2. 아이 채널의 최신 영상 가져오기
      final videos = await _getVideosFromChannels(channelIds, maxResults, pageToken);
      print('Retrieved ${videos.videos.length} personalized videos');

      // 구독 채널에서 영상을 가져오지 못하면 인기 영상으로 fallback
      if (videos.videos.isEmpty) {
        print('No videos from child channels - using popular videos');
        return await getPopularVideos(maxResults: maxResults, pageToken: pageToken);
      }

      return videos;
    } catch (e) {
      // 오류 발생 시 인기 영상으로 폴백
      print('Error in personalized recommendations: $e');
      try {
        return await getPopularVideos(maxResults: maxResults, pageToken: pageToken, excludeShorts: excludeShorts);
      } catch (fallbackError) {
        print('Fallback to popular videos also failed: $fallbackError');
        // 모든 방법이 실패하면 빈 결과 반환 (에러를 throw하지 않음)
        return YouTubeSearchResult(videos: [], nextPageToken: null);
      }
    }
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
  final String channelId;
  final String channelTitle;
  final String thumbnailUrl;
  final String description;
  final DateTime publishedAt;

  YouTubeVideo({
    required this.id,
    required this.title,
    this.channelId = '',
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
