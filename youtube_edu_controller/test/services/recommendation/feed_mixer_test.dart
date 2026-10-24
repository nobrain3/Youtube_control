import 'package:flutter_test/flutter_test.dart';
import 'package:qtime/services/api/youtube_service.dart';
import 'package:qtime/services/recommendation/feed_mixer.dart';

YouTubeVideo video(String id, String channel) => YouTubeVideo(
      id: id,
      title: id,
      channelId: channel,
      channelTitle: channel,
      thumbnailUrl: '',
      description: '',
      publishedAt: DateTime(2026),
    );

List<String> ids(List<YouTubeVideo> videos) => [for (final v in videos) v.id];
List<String> channels(List<YouTubeVideo> videos) =>
    [for (final v in videos) v.channelId];

void main() {
  group('FeedMixer (#104, #78)', () {
    test('interleaveByChannel rotates channels and keeps per-channel order', () {
      final result = FeedMixer.interleaveByChannel([
        video('a1', 'A'),
        video('a2', 'A'),
        video('a3', 'A'),
        video('b1', 'B'),
        video('c1', 'C'),
      ]);
      expect(ids(result), ['a1', 'b1', 'c1', 'a2', 'a3']);
    });

    test('avoidConsecutiveChannels pulls a different channel forward', () {
      final result = FeedMixer.avoidConsecutiveChannels([
        video('a1', 'A'),
        video('a2', 'A'),
        video('b1', 'B'),
      ]);
      expect(channels(result), ['A', 'B', 'A']);
    });

    test('avoidConsecutiveChannels leaves the list when only one channel remains',
        () {
      final result = FeedMixer.avoidConsecutiveChannels([
        video('a1', 'A'),
        video('a2', 'A'),
      ]);
      expect(ids(result), ['a1', 'a2']);
    });

    test('mixes discovery at roughly the given ratio, spread out', () {
      final primary = [for (var i = 0; i < 20; i++) video('p$i', 'P${i % 4}')];
      final discovery = [for (var i = 0; i < 20; i++) video('d$i', 'D${i % 4}')];

      final result = FeedMixer.mix(
        primary: primary,
        discovery: discovery,
        maxResults: 10,
        discoveryRatio: 0.3,
      );

      expect(result, hasLength(10));
      final discoveryIndexes = [
        for (var i = 0; i < result.length; i++)
          if (result[i].id.startsWith('d')) i,
      ];
      expect(discoveryIndexes, hasLength(3));
      expect(result.first.id, startsWith('p'));
      // 발견용 영상이 끝에 몰리지 않고 퍼져 있다
      expect(discoveryIndexes.first, lessThan(5));
    });

    test('fills from discovery when the child has few channel videos', () {
      final result = FeedMixer.mix(
        primary: [video('p1', 'P')],
        discovery: [for (var i = 0; i < 10; i++) video('d$i', 'D$i')],
        maxResults: 5,
      );
      expect(result, hasLength(5));
      expect(ids(result), contains('p1'));
    });

    test('removes duplicates and disliked videos', () {
      final result = FeedMixer.mix(
        primary: [video('x', 'A'), video('y', 'B'), video('x', 'A')],
        discovery: [video('y', 'B'), video('z', 'C')],
        maxResults: 10,
        excludedVideoIds: {'z'},
      );
      expect(ids(result)..sort(), ['x', 'y']);
    });

    test('no two consecutive videos share a channel when avoidable', () {
      final primary = [
        for (var i = 0; i < 6; i++) video('a$i', 'A'),
        video('b0', 'B'),
        video('b1', 'B'),
      ];
      final discovery = [video('d0', 'D'), video('d1', 'E'), video('d2', 'F')];

      final result = FeedMixer.mix(
        primary: primary,
        discovery: discovery,
        maxResults: 10,
      );
      final chs = channels(result);
      var consecutive = 0;
      for (var i = 1; i < chs.length; i++) {
        if (chs[i] == chs[i - 1]) consecutive++;
      }
      // 채널 A가 6개라 완전히 피할 수는 없어도, 다른 채널이 있는 동안은 붙지 않는다
      expect(consecutive, lessThanOrEqualTo(1));
    });
  });
}
