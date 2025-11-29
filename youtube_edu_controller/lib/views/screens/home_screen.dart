import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../services/api/youtube_service.dart';
import '../../services/storage/local_storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  List<YouTubeVideo> _searchResults = [];
  List<YouTubeVideo> _recommendedVideos = [];
  bool _isSearching = false;
  bool _isLoadingRecommended = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendedVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendedVideos() async {
    setState(() {
      _isLoadingRecommended = true;
    });

    try {
      final videos = await YouTubeService().getPopularVideos(maxResults: 10);
      setState(() {
        _recommendedVideos = videos;
        _isLoadingRecommended = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRecommended = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('영상 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _searchVideos(String query) async {
    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      final results = await YouTubeService().searchVideos(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _playVideo(YouTubeVideo video) {
    context.push(
      '/player/${video.id}?title=${Uri.encodeComponent(video.title)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.red, size: 28.sp),
            SizedBox(width: 4.w),
            Text(
              'YouTube',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () {
              context.push('/home/profile');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildSearchTab(),
          _buildHistoryTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '탐색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: '보관함',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecommendedVideos(),
        ],
      ),
    );
  }


  Widget _buildRecommendedVideos() {
    if (_isLoadingRecommended) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.h),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_recommendedVideos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.h),
          child: Text(
            '추천 영상을 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recommendedVideos.length,
      itemBuilder: (context, index) {
        final video = _recommendedVideos[index];
        return InkWell(
          onTap: () => _playVideo(video),
          child: _buildRecommendedVideoItem(video),
        );
      },
    );
  }

  Widget _buildRecommendedVideoItem(YouTubeVideo video) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              video.thumbnailUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.play_circle_outline, size: 50),
                );
              },
            ),
          ),
          // 영상 정보
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 채널 아바타
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.account_circle, size: 36.r, color: Colors.grey[600]),
                ),
                SizedBox(width: 12.w),
                // 제목 및 채널 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        video.channelTitle,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 더보기 버튼
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.black),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // 검색 바
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: '검색',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: Colors.black),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults.clear();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _searchVideos(value);
              }
            },
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        // 검색 결과
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64.sp, color: Colors.grey[400]),
                          SizedBox(height: 16.h),
                          Text(
                            '검색어를 입력하세요',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final video = _searchResults[index];
                        return _buildSearchResultItem(video);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final history = LocalStorageService().getWatchHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            '보관함',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Text(
                    '시청 기록이 없습니다',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final video = history[index];
                    return _buildHistoryItem(
                      video['title'] ?? 'Unknown Title',
                      video['channelTitle'] ?? 'Unknown Channel',
                      video['thumbnailUrl'] ?? 'https://via.placeholder.com/200x120',
                      video['videoId'] ?? '',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(String title, String channel, String thumbnail, String videoId) {
    return InkWell(
      onTap: () {
        if (videoId.isNotEmpty) {
          context.push('/player/$videoId?title=${Uri.encodeComponent(title)}');
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                thumbnail,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.play_circle_outline, size: 50),
                  );
                },
              ),
            ),
            // 영상 정보
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 채널 아바타
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.account_circle, size: 36.r, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 12.w),
                  // 제목 및 채널 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          channel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 더보기 버튼
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchResultItem(YouTubeVideo video) {
    return InkWell(
      onTap: () => _playVideo(video),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                video.thumbnailUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.play_circle_outline, size: 50),
                  );
                },
              ),
            ),
            // 영상 정보
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 채널 아바타
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.account_circle, size: 36.r, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 12.w),
                  // 제목 및 채널 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          video.channelTitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 더보기 버튼
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}