import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_library.dart';

/// 아이별 좋아요·싫어요와 담은 채널의 Firestore 접근 계층 (#104).
///
/// 데이터 구조:
/// ```
/// users/{uid}/children/{childId}/ratings/{videoId}    좋아요·싫어요
/// users/{uid}/children/{childId}/channels/{channelId} 담은 채널
/// ```
class ChildLibraryRepository {
  ChildLibraryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _childRef(
          String uid, String childId) =>
      _db.collection('users').doc(uid).collection('children').doc(childId);

  CollectionReference<Map<String, dynamic>> _ratingsRef(
          String uid, String childId) =>
      _childRef(uid, childId).collection('ratings');

  CollectionReference<Map<String, dynamic>> _channelsRef(
          String uid, String childId) =>
      _childRef(uid, childId).collection('channels');

  Future<List<RatedVideo>> getRatings(String uid, String childId) async {
    final query = await _ratingsRef(uid, childId).get();
    final result = <RatedVideo>[];
    for (final doc in query.docs) {
      final data = doc.data();
      final rating = VideoRating.fromName(data['rating'] as String?);
      if (rating == null) continue;
      result.add(RatedVideo(
        videoId: doc.id,
        rating: rating,
        channelId: data['channelId'] as String? ?? '',
        updatedAt: _toDate(data['updatedAt']),
      ));
    }
    return result;
  }

  Future<void> setRating(String uid, String childId, RatedVideo video) {
    return _ratingsRef(uid, childId).doc(video.videoId).set({
      'rating': video.rating.name,
      'channelId': video.channelId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRating(String uid, String childId, String videoId) {
    return _ratingsRef(uid, childId).doc(videoId).delete();
  }

  Future<List<SavedChannel>> getChannels(String uid, String childId) async {
    final query = await _channelsRef(uid, childId).get();
    return [
      for (final doc in query.docs)
        SavedChannel(
          channelId: doc.id,
          source: ChannelSource.fromName(doc.data()['source'] as String?),
          addedAt: _toDate(doc.data()['createdAt']),
        ),
    ];
  }

  Future<void> addChannel(String uid, String childId, SavedChannel channel) {
    return _channelsRef(uid, childId).doc(channel.channelId).set({
      'source': channel.source.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChannel(String uid, String childId, String channelId) {
    return _channelsRef(uid, childId).doc(channelId).delete();
  }

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
