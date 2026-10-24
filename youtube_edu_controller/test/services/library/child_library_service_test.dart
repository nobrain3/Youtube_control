import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtime/models/child_library.dart';
import 'package:qtime/services/firestore/child_library_repository.dart';
import 'package:qtime/services/library/child_library_service.dart';
import 'package:qtime/services/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChildLibraryService (#104)', () {
    late FakeFirebaseFirestore firestore;
    late ChildLibraryRepository repository;
    late LocalStorageService storage;
    String? uid;
    late ChildLibraryService library;

    const childId = 'child-1';
    const videoA = 'aaaaaaaaaaa';
    const videoB = 'bbbbbbbbbbb';
    final channelA = 'UC${'a' * 22}';
    final channelB = 'UC${'b' * 22}';

    CollectionReference<Map<String, dynamic>> ratingsRef() => firestore
        .collection('users')
        .doc('guardian-1')
        .collection('children')
        .doc(childId)
        .collection('ratings');

    CollectionReference<Map<String, dynamic>> channelsRef() => firestore
        .collection('users')
        .doc('guardian-1')
        .collection('children')
        .doc(childId)
        .collection('channels');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      firestore = FakeFirebaseFirestore();
      repository = ChildLibraryRepository(firestore: firestore);
      uid = null;
      library = ChildLibraryService(
        repository: repository,
        storage: storage,
        currentUid: () => uid,
      );
    });

    group('signed out (local only)', () {
      test('stores and toggles ratings locally', () async {
        await library.setRating(
            videoId: videoA, rating: VideoRating.like, channelId: channelA);
        expect(library.ratingOf(videoA), VideoRating.like);

        await library.setRating(videoId: videoA, rating: VideoRating.dislike);
        expect(library.ratingOf(videoA), VideoRating.dislike);

        await library.setRating(videoId: videoA, rating: null);
        expect(library.ratingOf(videoA), isNull);
        expect((await ratingsRef().get()).docs, isEmpty);
      });

      test('ignores invalid video and channel IDs', () async {
        await library.setRating(videoId: 'bad', rating: VideoRating.like);
        await library.addChannel('not-a-channel');
        expect(library.ratings, isEmpty);
        expect(library.channels, isEmpty);
      });

      test('adds and removes channels without duplicates', () async {
        await library.addChannel(channelA);
        await library.addChannel(channelA);
        expect(library.channels.map((c) => c.channelId), [channelA]);
        expect(library.isChannelSaved(channelA), isTrue);

        await library.removeChannel(channelA);
        expect(library.isChannelSaved(channelA), isFalse);
      });

      test('recommendation channels = saved channels + liked videos only',
          () async {
        await library.addChannel(channelA);
        await library.setRating(
            videoId: videoA, rating: VideoRating.like, channelId: channelB);
        await library.setRating(
            videoId: videoB,
            rating: VideoRating.dislike,
            channelId: 'UC${'c' * 22}');
        expect(library.recommendationChannelIds().toSet(), {channelA, channelB});
      });
    });

    group('signed in', () {
      setUp(() async {
        uid = 'guardian-1';
        await storage.setActiveChildId(childId);
      });

      test('pushes rating changes to the cloud', () async {
        await library.setRating(
            videoId: videoA, rating: VideoRating.like, channelId: channelA);
        final doc = await ratingsRef().doc(videoA).get();
        expect(doc.data()?['rating'], 'like');
        expect(doc.data()?['channelId'], channelA);

        await library.setRating(videoId: videoA, rating: null);
        expect((await ratingsRef().doc(videoA).get()).exists, isFalse);
      });

      test('pushes channel changes with source to the cloud', () async {
        await library.addChannel(channelA, source: ChannelSource.guardian);
        expect((await channelsRef().doc(channelA).get()).data()?['source'],
            'guardian');

        await library.removeChannel(channelA);
        expect((await channelsRef().doc(channelA).get()).exists, isFalse);
      });
    });

    group('syncOnSignIn', () {
      test('merges local and cloud data in both directions', () async {
        // 로그인 전에 아이가 쓴 기록
        await library.setRating(
            videoId: videoA, rating: VideoRating.like, channelId: channelA);
        await library.addChannel(channelA);

        // 다른 기기에서 이미 올라가 있던 기록
        await ratingsRef().doc(videoB).set({
          'rating': 'dislike',
          'channelId': '',
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
        await channelsRef().doc(channelB).set({
          'source': 'guardian',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

        await library.syncOnSignIn(uid: 'guardian-1', childId: childId);

        expect(library.ratingOf(videoA), VideoRating.like);
        expect(library.ratingOf(videoB), VideoRating.dislike);
        expect(library.channels.map((c) => c.channelId).toSet(),
            {channelA, channelB});
        expect((await ratingsRef().doc(videoA).get()).exists, isTrue);
        expect((await channelsRef().doc(channelA).get()).exists, isTrue);
      });

      test('keeps the more recent rating when both sides rated a video',
          () async {
        await ratingsRef().doc(videoA).set({
          'rating': 'dislike',
          'channelId': '',
          'updatedAt': Timestamp.fromDate(DateTime(2020, 1, 1)),
        });
        await library.setRating(videoId: videoA, rating: VideoRating.like);

        await library.syncOnSignIn(uid: 'guardian-1', childId: childId);

        expect(library.ratingOf(videoA), VideoRating.like);
        expect((await ratingsRef().doc(videoA).get()).data()?['rating'], 'like');
      });
    });
  });
}
