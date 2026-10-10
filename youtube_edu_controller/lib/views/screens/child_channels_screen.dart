import 'package:flutter/material.dart';
import '../../models/child_library.dart';
import '../../services/api/youtube_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/library/child_library_service.dart';

/// 아이가 담은 채널 관리 (보호자용, #104).
///
/// 아이 홈 추천은 이 채널들과 아이가 좋아요한 영상의 채널로 만든다.
/// 보호자는 채널을 빼거나, 보호자 YouTube 구독에서 골라 넣을 수 있다.
class ChildChannelsScreen extends StatefulWidget {
  const ChildChannelsScreen({super.key});

  @override
  State<ChildChannelsScreen> createState() => _ChildChannelsScreenState();
}

class _ChildChannelsScreenState extends State<ChildChannelsScreen> {
  final ChildLibraryService _library = ChildLibraryService.shared;

  List<SavedChannel> _channels = [];
  Map<String, YouTubeChannelInfo> _info = {};
  bool _isLoading = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final channels = _library.channels;
    setState(() {
      _channels = channels;
      _isLoading = true;
    });
    try {
      final infos = await YouTubeService()
          .getChannelsInfo([for (final c in channels) c.channelId]);
      if (!mounted) return;
      setState(() {
        _info = {for (final i in infos) i.id: i};
      });
    } catch (e) {
      debugPrint('채널 정보 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _remove(SavedChannel channel) async {
    await _library.removeChannel(channel.channelId);
    if (!mounted) return;
    setState(() {
      _channels = _library.channels;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('채널을 뺐어요'),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            await _library.addChannel(channel.channelId, source: channel.source);
            if (mounted) setState(() => _channels = _library.channels);
          },
        ),
      ),
    );
  }

  /// 보호자 YouTube 구독 목록에서 골라 아이 채널로 넣는다.
  Future<void> _importFromGuardian() async {
    setState(() => _isImporting = true);
    try {
      final granted = await GoogleAuthService()
          .requestPermission(YouTubePermission.subscriptions);
      if (!granted) {
        _showMessage('YouTube 구독 목록 권한을 허용하지 않았습니다');
        return;
      }
      final subscriptions = await YouTubeService().getGuardianSubscriptions();
      if (!mounted) return;
      final candidates = subscriptions
          .where((s) => !_library.isChannelSaved(s.id))
          .toList();
      if (candidates.isEmpty) {
        _showMessage(subscriptions.isEmpty
            ? '구독한 채널이 없습니다'
            : '구독 채널이 모두 이미 담겨 있습니다');
        return;
      }
      final selected = await showModalBottomSheet<List<YouTubeChannelInfo>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _SubscriptionPicker(candidates: candidates),
      );
      if (selected == null || selected.isEmpty) return;
      for (final channel in selected) {
        await _library.addChannel(channel.id, source: ChannelSource.guardian);
      }
      if (!mounted) return;
      setState(() {
        _channels = _library.channels;
        _info = {..._info, for (final c in selected) c.id: c};
      });
      _showMessage('${selected.length}개 채널을 아이 목록에 넣었어요');
    } catch (e) {
      debugPrint('보호자 구독 가져오기 실패: $e');
      _showMessage('구독 목록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canImport = AuthService().isGoogleUser;
    return Scaffold(
      appBar: AppBar(title: const Text('아이가 담은 채널')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            '아이 홈에는 여기 담긴 채널과 아이가 좋아요한 영상의 채널로 추천 영상이 나옵니다. '
            '채널은 아이가 재생 화면에서 "채널 담기"로 추가할 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (canImport)
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _importFromGuardian,
              icon: _isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('보호자 YouTube 구독에서 골라 넣기'),
            ),
          const SizedBox(height: 12),
          if (_channels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('아직 담은 채널이 없어요')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final channel in _channels) ...[
                    _ChannelTile(
                      info: _info[channel.channelId],
                      channel: channel,
                      isLoading: _isLoading,
                      onRemove: () => _remove(channel),
                    ),
                    if (channel != _channels.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.info,
    required this.channel,
    required this.isLoading,
    required this.onRemove,
  });

  final YouTubeChannelInfo? info;
  final SavedChannel channel;
  final bool isLoading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final thumbnail = info?.thumbnailUrl ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: thumbnail.isNotEmpty ? NetworkImage(thumbnail) : null,
        child: thumbnail.isEmpty ? const Icon(Icons.tv) : null,
      ),
      title: Text(
        info?.title ?? (isLoading ? '불러오는 중…' : '알 수 없는 채널'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        channel.source == ChannelSource.guardian ? '보호자가 넣음' : '아이가 담음',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        tooltip: '빼기',
        onPressed: onRemove,
      ),
    );
  }
}

/// 보호자 구독 채널 중 아이 목록에 넣을 채널을 고르는 시트.
class _SubscriptionPicker extends StatefulWidget {
  const _SubscriptionPicker({required this.candidates});

  final List<YouTubeChannelInfo> candidates;

  @override
  State<_SubscriptionPicker> createState() => _SubscriptionPickerState();
}

class _SubscriptionPickerState extends State<_SubscriptionPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '아이에게 보여줄 채널을 고르세요',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: widget.candidates.length,
              itemBuilder: (context, index) {
                final channel = widget.candidates[index];
                return CheckboxListTile(
                  value: _selected.contains(channel.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(channel.id);
                    } else {
                      _selected.remove(channel.id);
                    }
                  }),
                  secondary: CircleAvatar(
                    backgroundImage: channel.thumbnailUrl.isNotEmpty
                        ? NetworkImage(channel.thumbnailUrl)
                        : null,
                  ),
                  title: Text(
                    channel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop([
                            for (final c in widget.candidates)
                              if (_selected.contains(c.id)) c,
                          ]),
                  child: Text('${_selected.length}개 넣기'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
