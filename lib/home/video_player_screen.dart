import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/api_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late String url;
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  bool _isYoutube = false;
  bool _isLocalFile = false;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    url = widget.video['url'] ?? '';
    _initPlayer();
  }

  void _initPlayer() async {
    if (url.isEmpty) {
      setState(() => _error = true);
      return;
    }

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYoutube = true;
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
        setState(() => _initialized = true);
      } else {
        setState(() => _error = true);
      }
    } else {
      // 일반 영상 파일 (서버 업로드 포함)
      _isLocalFile = true;
      String fullUrl = url;
      if (url.startsWith('/api/')) {
        final baseUrl = await ApiService.baseUrl;
        fullUrl = baseUrl.replaceAll('/api', '') + url;
      }

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      try {
        await _videoPlayerController!.initialize();
        setState(() => _initialized = true);
        _videoPlayerController!.play();
      } catch (e) {
        print('Video initialization error: $e');
        setState(() => _error = true);
      }
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _buildPlayer(),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_error) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 48),
          SizedBox(height: 16),
          Text('영상을 재생할 수 없습니다.', style: TextStyle(color: Colors.white)),
        ],
      );
    }

    if (!_initialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (_isYoutube && _youtubeController != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
      );
    }

    if (_isLocalFile && _videoPlayerController != null) {
      return AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoPlayerController!),
            VideoProgressIndicator(_videoPlayerController!, allowScrubbing: true),
            GestureDetector(
              onTap: () {
                setState(() {
                  _videoPlayerController!.value.isPlaying
                      ? _videoPlayerController!.pause()
                      : _videoPlayerController!.play();
                });
              },
              child: Center(
                child: Icon(
                  _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white.withOpacity(0.7),
                  size: 64,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
