import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'video_player_screen.dart';

class EducationDetailScreen extends StatefulWidget {
  final String title;
  final String? summary; // [Added] Summary text for toggle
  final List<String> descriptionPoints;
  final String videoCategory;
  final List<dynamic> allVideos;

  const EducationDetailScreen({
    super.key,
    required this.title,
    this.summary,
    required this.descriptionPoints,
    required this.videoCategory,
    required this.allVideos,
  });

  @override
  State<EducationDetailScreen> createState() => _EducationDetailScreenState();
}

class _EducationDetailScreenState extends State<EducationDetailScreen> {
  bool _isExpanded = false; // [Added] Toggle state

  @override
  void initState() {
    super.initState();
    // If no summary is provided, always show description points
    if (widget.summary == null || widget.summary!.isEmpty) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> relatedVideos = widget.allVideos.where((video) {
        final String? cat = video['category'];
        if (cat != null && cat.isNotEmpty) {
            return cat == widget.videoCategory;
        }
       
        final String title = (video['title'] ?? '').toString();
        if (widget.videoCategory == 'UNDERSTANDING' && title.contains('도박')) return true;
        if (widget.videoCategory == 'IMPULSE' && (title.contains('충동') || title.contains('호흡'))) return true;
        if (widget.videoCategory == 'COMMUNICATION' && title.contains('대화')) return true;
        
        return false;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description Section
            GestureDetector(
              onTap: () {
                if (!_isExpanded) {
                  setState(() => _isExpanded = true);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isExpanded && widget.summary != null) ...[
                      // Summary Mode
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.summary!,
                              style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '+ 더보기',
                            style: TextStyle(
                              color: Color(0xFF5C72EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Detailed Mode (Points)
                      ...widget.descriptionPoints.map((point) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 6, color: Color(0xFF5C72EB)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      // Optionally add a "Show Less" or just keep it expanded
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Video Section Header
            const Text(
              '관련 영상',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (relatedVideos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '관련된 영상이 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(), // Scroll handled by SingleChildScrollView
                shrinkWrap: true,
                itemCount: relatedVideos.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final video = relatedVideos[index];
                  return _buildVideoCard(context, video);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, dynamic video) {
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (thumbnailUrl != null)
                    Image.network(
                      thumbnailUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180, 
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.video_library, color: Colors.grey)),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                      ]
                    ),
                    child: const Icon(Icons.play_arrow, color: Color(0xFF5C72EB), size: 30),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video['description'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
