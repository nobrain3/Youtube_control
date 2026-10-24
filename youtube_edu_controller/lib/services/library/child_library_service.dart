import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/child_library.dart';
import '../firestore/child_library_repository.dart';
import '../storage/local_storage_service.dart';
import '../../utils/app_logger.dart';

/// 아이별 좋아요·싫어요와 담은 채널 관리 (#104).
///
/// 앱은 아이 폰에서 쓰지만 로그인은 보호자 계정이다. 아이 화면에는 아이가
/// 좋아요한 영상·아이가 담은 채널만 보이도록 보호자 YouTube 계정 대신 앱 안에 저장한다.
///
/// - **로컬 우선**: 기기에 먼저 저장하고 화면은 로컬 값을 읽는다. 로그인하지 않아도 동작한다.
/// - **클라우드 반영**: 로그인 상태면 변경을 Firestore에도 올린다. 실패해도 로컬 값은 유지한다.
/// - **로그인 시 병합**: [syncOnSignIn]에서 로컬과 클라우드를 합친다 (같은 영상은 최근 평가 우선).
class ChildLibraryService {
  ChildLibraryService({
    ChildLibraryRepository? repository,
    LocalStorageService? storage,
    String? Function()? currentUid,
  })  : _repositoryOverride = repository,
        _storage = storage ?? LocalStorageService(),
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  static ChildLibraryService? _shared;

  /// 앱 전역에서 쓰는 인스턴스.
  static ChildLibraryService get shared => _shared ??= ChildLibraryService();

  final ChildLibraryRepository? _repositoryOverride;
  ChildLibraryRepository? _repositoryInstance;
  final LocalStorageService _storage;
  final String? Function() _currentUid;

  // 테스트가 아닌 경우 Firestore는 실제로 쓸 때 만든다 (Firebase 초기화 전 생성 대비).
  ChildLibraryRepository get _repository =>
      _repositoryOverride ?? (_repositoryInstance ??= ChildLibraryRepository());

  Map<String, RatedVideo> _ratingsCache() {
    final result = <String, RatedVideo>{};
    for (final json in _storage.getChildRatings()) {
      final video = RatedVideo.fromJson(json);
      if (video != null) result[video.videoId] = video;
    }
    return result;
  }

  Map<String, SavedChannel> _channelsCache() {
    final result = <String, SavedChannel>{};
    for (final json in _storage.getChildChannels()) {
      final channel = SavedChannel.fromJson(json);
      if (channel != null) result[channel.channelId] = channel;
    }
    return result;
  }

  Future<void> _saveRatings(Map<String, RatedVideo> ratings) =>
      _storage.setChildRatings([for (final v in ratings.values) v.toJson()]);

  Future<void> _saveChannels(Map<String, SavedChannel> channels) =>
      _storage.setChildChannels([for (final c in channels.values) c.toJson()]);

  /// 로그인한 보호자와 현재 아이. 둘 중 하나라도 없으면 클라우드에 올리지 않는다.
  ({String uid, String childId})? get _cloudTarget {
    final uid = _currentUid();
    final childId = _storage.getActiveChildId();
    if (uid == null || childId == null) return null;
    return (uid: uid, childId: childId);
  }

  Future<void> _pushToCloud(
    String label,
    Future<void> Function(String uid, String childId) write,
  ) async {
    final target = _cloudTarget;
    if (target == null) return;
    try {
      await write(target.uid, target.childId);
    } catch (e) {
      // 로컬에는 이미 저장됐다. Firestore는 오프라인 쓰기를 큐에 담았다가 재전송한다.
      logDebug('아이 라이브러리 클라우드 반영 실패 ($label): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 좋아요·싫어요
  // ---------------------------------------------------------------------------

  VideoRating? ratingOf(String videoId) => _ratingsCache()[videoId]?.rating;

  /// 평가를 저장한다. [rating]이 null이면 평가를 취소한다.
  Future<void> setRating({
    required String videoId,
    required VideoRating? rating,
    String channelId = '',
  }) async {
    if (!YouTubeIds.isVideoId(videoId)) return;
    final ratings = _ratingsCache();
    if (rating == null) {
      ratings.remove(videoId);
      await _saveRatings(ratings);
      await _pushToCloud('평가 취소',
          (uid, childId) => _repository.deleteRating(uid, childId, videoId));
      return;
    }
    final video = RatedVideo(
      videoId: videoId,
      rating: rating,
      channelId: YouTubeIds.isChannelId(channelId) ? channelId : '',
      updatedAt: DateTime.now(),
    );
    ratings[videoId] = video;
    await _saveRatings(ratings);
    await _pushToCloud(
        '평가', (uid, childId) => _repository.setRating(uid, childId, video));
  }

  List<RatedVideo> get ratings => _ratingsCache().values.toList();

  // ---------------------------------------------------------------------------
  // 담은 채널
  // ---------------------------------------------------------------------------

  List<SavedChannel> get channels {
    final list = _channelsCache().values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  bool isChannelSaved(String channelId) =>
      _channelsCache().containsKey(channelId);

  Future<void> addChannel(
    String channelId, {
    ChannelSource source = ChannelSource.child,
  }) async {
    if (!YouTubeIds.isChannelId(channelId)) return;
    final channels = _channelsCache();
    if (channels.containsKey(channelId)) return;
    final channel = SavedChannel(
      channelId: channelId,
      source: source,
      addedAt: DateTime.now(),
    );
    channels[channelId] = channel;
    await _saveChannels(channels);
    await _pushToCloud(
        '채널 담기', (uid, childId) => _repository.addChannel(uid, childId, channel));
  }

  Future<void> removeChannel(String channelId) async {
    final channels = _channelsCache();
    if (channels.remove(channelId) == null) return;
    await _saveChannels(channels);
    await _pushToCloud('채널 빼기',
        (uid, childId) => _repository.deleteChannel(uid, childId, channelId));
  }

  /// 홈 추천에 쓸 채널: 담은 채널 + 좋아요한 영상의 채널. 싫어요만 받은 채널은 제외.
  List<String> recommendationChannelIds() {
    final result = <String>{for (final c in _channelsCache().keys) c};
    for (final video in _ratingsCache().values) {
      if (video.rating == VideoRating.like && video.channelId.isNotEmpty) {
        result.add(video.channelId);
      }
    }
    return result.toList();
  }

  // ---------------------------------------------------------------------------
  // 로그인 동기화
  // ---------------------------------------------------------------------------

  /// 로그인 직후 로컬과 클라우드를 합친다.
  ///
  /// - 클라우드에만 있는 항목은 내려받는다.
  /// - 로컬에만 있는 항목(로그인 전 사용)은 올린다.
  /// - 같은 영상의 평가가 다르면 더 최근 것을 따른다.
  Future<void> syncOnSignIn({
    required String uid,
    required String childId,
  }) async {
    final localRatings = _ratingsCache();
    final cloudRatings = {
      for (final v in await _repository.getRatings(uid, childId)) v.videoId: v,
    };
    final mergedRatings = {...cloudRatings};
    for (final local in localRatings.values) {
      final cloud = cloudRatings[local.videoId];
      if (cloud == null || local.updatedAt.isAfter(cloud.updatedAt)) {
        mergedRatings[local.videoId] = local;
        if (cloud == null || cloud.rating != local.rating) {
          await _repository.setRating(uid, childId, local);
        }
      }
    }
    await _saveRatings(mergedRatings);

    final localChannels = _channelsCache();
    final cloudChannels = {
      for (final c in await _repository.getChannels(uid, childId)) c.channelId: c,
    };
    final mergedChannels = {...cloudChannels};
    for (final local in localChannels.values) {
      if (!cloudChannels.containsKey(local.channelId)) {
        mergedChannels[local.channelId] = local;
        await _repository.addChannel(uid, childId, local);
      }
    }
    await _saveChannels(mergedChannels);
  }
}
