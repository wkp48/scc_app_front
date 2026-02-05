import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../home/video_player_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class FamilyTrainingDetailScreen extends StatefulWidget {
  final String title;
  final List<String> descriptions;
  final String category;

  const FamilyTrainingDetailScreen({
    super.key,
    required this.title,
    required this.descriptions,
    required this.category,
  });

  @override
  State<FamilyTrainingDetailScreen> createState() => _FamilyTrainingDetailScreenState();
}

class _FamilyTrainingDetailScreenState extends State<FamilyTrainingDetailScreen> {
  bool _isLoading = true;
  bool _isExpanded = false;
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final response = await ApiService.getHelpfulVideos(category: widget.category);
    if (mounted) {
      setState(() {
        if (response['success']) {
          _videos = response['data'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which descriptions to show
    final displayDescriptions = _isExpanded ? widget.descriptions : [widget.descriptions.first];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.descriptions.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final String desc = entry.value;
                    
                    // 만약 접혀있는 상태고 첫 번째 문단이 아니라면 표시하지 않음
                    if (!_isExpanded && idx > 0) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5C72EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: desc,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: Color(0xFF424242),
                                    ),
                                  ),
                                  // '더보기': 펼쳐지지 않았을 때 첫 번째 문단 끝에 표시
                                  if (!_isExpanded && idx == 0 && widget.descriptions.length > 1)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isExpanded = true),
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Text(
                                            '+더보기',
                                            style: TextStyle(
                                              color: Color(0xFF5C72EB),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // '접기': 펼쳐진 상태일 때 마지막 문단 끝에 표시
                                  if (_isExpanded && idx == widget.descriptions.length - 1 && widget.descriptions.length > 1)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isExpanded = false),
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Text(
                                            '접기',
                                            style: TextStyle(
                                              color: Color(0xFF5C72EB),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Video Section Header
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                '관련 영상',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Video List
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _videos.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(
                          child: Text(
                            '등록된 영상이 없습니다.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: _videos.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          return _buildVideoCard(video);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(dynamic video) {
    final String url = video['url'] ?? '';
    String? thumbnailUrl;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(video: video),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (thumbnailUrl != null)
                    Image.network(
                      thumbnailUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildEmptyThumbnail(),
                    )
                  else
                    _buildEmptyThumbnail(),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Color(0xFF5C72EB), size: 28),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '제목 없음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  if (video['description'] != null && video['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      video['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyThumbnail() {
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFFF0F2F5),
      child: const Icon(Icons.video_library_outlined, color: Color(0xFFD9D9D9), size: 48),
    );
  }
}
