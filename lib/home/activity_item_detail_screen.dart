import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'activity_record_modal.dart';

class ActivityItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activity;
  final Map<String, dynamic> userData;

  const ActivityItemDetailScreen({
    super.key,
    required this.activity,
    required this.userData,
  });

  @override
  State<ActivityItemDetailScreen> createState() => _ActivityItemDetailScreenState();
}

class _ActivityItemDetailScreenState extends State<ActivityItemDetailScreen> {
  late Map<String, dynamic> currentActivity;
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    currentActivity = widget.activity;
    _audioPlayer = AudioPlayer();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getAbsoluteUrl(String path, String baseUrl) {
    return ApiService.getAbsoluteUrl(baseUrl, path);
  }

  String _getActivityTitle() {
    switch (currentActivity['activityType']) {
      case 'WALK': return '일상 기록';
      case 'GRATITUDE': return '감사 일기';
      case 'IMPULSE': return '충동 일지';
      case 'POSITIVE_SELF': return '희망 리코딩';
      default: return '기록 상세';
    }
  }

  IconData _getActivityIcon() {
    switch (currentActivity['activityType']) {
      case 'WALK': return Icons.wb_sunny_outlined;
      case 'GRATITUDE': return Icons.favorite_border;
      case 'IMPULSE': return Icons.flash_on;
      case 'POSITIVE_SELF': return Icons.auto_awesome;
      default: return Icons.notes;
    }
  }

  Color _getActivityColor() {
    switch (currentActivity['activityType']) {
      case 'WALK': return const Color(0xFF52C41A);
      case 'GRATITUDE': return const Color(0xFFFF851B);
      case 'IMPULSE': return const Color(0xFFFF4D4F);
      case 'POSITIVE_SELF': return const Color(0xFF722ED1);
      default: return const Color(0xFF5C72EB);
    }
  }

  Future<void> _deleteActivity() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('정말로 이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final response = await ApiService.deleteActivity(currentActivity['id']);
      if (response['success'] && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> imageUrls = currentActivity['imageUrls'] ?? [];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF434343)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _getActivityTitle(),
          style: const TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D4F)),
            onPressed: _deleteActivity,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 상단 카드 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _getActivityColor().withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getActivityIcon(), color: _getActivityColor(), size: 32),
                  ),
                  if (currentActivity['activityType'] != 'POSITIVE_SELF') ...[
                    Text(
                      currentActivity['title'] ?? '제목 없음',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (currentActivity['category'] != null || currentActivity['score'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (currentActivity['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              currentActivity['category'],
                              style: const TextStyle(color: Color(0xFFFF851B), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (currentActivity['category'] != null && currentActivity['score'] != null)
                          const SizedBox(width: 8),
                        if (currentActivity['score'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '충동 강도: ${currentActivity['score']}',
                              style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (currentActivity['activityType'] != 'WALK' && currentActivity['activityType'] != 'POSITIVE_SELF') ...[
                    const SizedBox(height: 8),
                    Text(
                      '작성 시간: ${currentActivity['startTime']?.substring(0, 5) ?? "-"}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 음성 녹음 섹션 (있는 경우)
            if (currentActivity['voiceFilePath'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 16, color: const Color(0xFFFF4D4F)),
                        const SizedBox(width: 8),
                        const Text('음성 녹음', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              if (_isPlaying) {
                                await _audioPlayer.pause();
                              } else {
                                final baseUrl = await ApiService.baseUrl;
                                final url = '$baseUrl/activities/images/${currentActivity['voiceFilePath']}';
                                await _audioPlayer.play(UrlSource(url));
                              }
                            },
                            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, 
                              color: const Color(0xFFFF4D4F), size: 36),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('녹음된 오디오', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(_isPlaying ? '재생 중...' : '준비됨', 
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 이미지 섹션 (있는 경우)
            if (imageUrls.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 16, color: const Color(0xFF36D1DC)),
                        const SizedBox(width: 8),
                        const Text('사진', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: FutureBuilder<String>(
                        future: ApiService.baseUrl,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) => Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          }
                          final baseUrl = snapshot.data!;
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _getAbsoluteUrl(imageUrls[index], baseUrl),
                                  fit: BoxFit.cover,
                                  headers: {'X-User-Uid': widget.userData['uid'] ?? ''},
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 상세 내용 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: const Color(0xFF5C72EB)),
                      const SizedBox(width: 8),
                      const Text('상세 내용', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('활동 일자', currentActivity['date']),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF5F5F5)),
                  const SizedBox(height: 16),
                  
                  if (currentActivity['activityType'] == 'GRATITUDE') ...[
                    _buildGratitudeField('1. 누구에게 감사했나요?', currentActivity['gratitudeTo']),
                    const SizedBox(height: 20),
                    _buildGratitudeField('2. 어떤 상황이었나요?', currentActivity['gratitudeSituation']),
                    const SizedBox(height: 20),
                    _buildGratitudeField('3. 어떤 감정을 느꼈나요?', currentActivity['gratitudeEmotion']),
                  ] else if (currentActivity['activityType'] == 'IMPULSE') ...[
                    _buildGratitudeField('1. 어떤 상황이었나요?', currentActivity['impulseSituation']),
                    const SizedBox(height: 20),
                    _buildGratitudeField('2. 어떤 생각이 들었나요?', currentActivity['impulseThought']),
                    const SizedBox(height: 20),
                    _buildGratitudeField('3. 충동을 물리치는데 도움이 된 것은?', currentActivity['impulseHelpful']),
                    const SizedBox(height: 20),
                    _buildGratitudeField('4. 충동이 지난 후의 감정은?', currentActivity['impulseAfter']),
                  ] else ...[
                    const Text('내용', style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        currentActivity['content'] ?? '내용이 없습니다.',
                        style: const TextStyle(fontSize: 15, color: Color(0xFF434343), height: 1.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ActivityRecordModal.show(
                    context, 
                    widget.userData, 
                    currentActivity['activityType'],
                    initialActivity: currentActivity,
                    onSaved: () {
                      // 수정 완료 시 상세 화면 닫고 목록 새로고침
                      Navigator.pop(context, true);
                    },
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('수정'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F1F1F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGratitudeField(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value ?? '내용이 없습니다.',
            style: const TextStyle(fontSize: 15, color: Color(0xFF434343), height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
        ),
      ],
    );
  }
}
