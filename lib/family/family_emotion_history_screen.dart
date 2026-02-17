import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'family_emotion_detail_screen.dart';

class FamilyEmotionDetailsModal extends StatefulWidget {
  final Map<String, dynamic> userData;

  final VoidCallback? onRefresh;

  const FamilyEmotionDetailsModal({
    super.key,
    required this.userData,
    this.onRefresh,
  });

  static void show(BuildContext context, Map<String, dynamic> userData, {VoidCallback? onRefresh}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FamilyEmotionDetailsModal(
        userData: userData,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<FamilyEmotionDetailsModal> createState() => _FamilyEmotionDetailsModalState();
}

class _FamilyEmotionDetailsModalState extends State<FamilyEmotionDetailsModal> {

  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    // ApiService.getAnxietyLogs currently returns ALL logs. 
    // We might need to filter client-side if API doesn't support date param for anxiety logs yet.
    // Based on previous view, getAnxietyLogs uses /anxiety-log/{uid} which likely returns list.
    final response = await ApiService.getAnxietyLogs(uid);

    if (mounted) {
      if (response['success'] == true) {
        List<dynamic> allLogs = response['data'] ?? [];
        
        // Sort DESC
        allLogs.sort((a, b) {
           final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
           final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
           return db.compareTo(da);
        });

        setState(() {
          _logs = allLogs;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('data:image')) return path;
    if (path.startsWith('http')) return path;
    
    // Base URL matching ActivityDetailsModal logic (adjust if needed for real dev env)
    const String effectiveBaseUrl = 'http://115.20.138.8:8900/api'; 
    
    String url;
    if (path.startsWith('/api')) {
      url = effectiveBaseUrl.substring(0, effectiveBaseUrl.length - 4) + path;
    } else if (!path.startsWith('/')) {
      url = '$effectiveBaseUrl/$path';
    } else {
      url = '$effectiveBaseUrl$path';
    }
    return Uri.encodeFull(url);
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
           Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty 
                    ? _buildEmptyState()
                    : _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('감정일기 상세', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildLogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        return _buildLogCard((_logs[index]));
      },
    );
  }
  
  Widget _buildLogCard(dynamic log) {
    final List<dynamic> imageUrls = log['imageUrls'] ?? [];
    final String situation = log['situation'] ?? '';
    final String content = log['thought'] ?? ''; // Display thought as content preview
    final String dateStr = log['createdAt'] ?? '';
    final DateTime? created = DateTime.tryParse(dateStr);
    
    // Emotion tags simple summary
    List<Widget> chips = [];
    if (log['angerScore'] != null) chips.add(_buildScoreBadge('분노', log['angerScore'], const Color(0xFFFF4D4F)));
    if (log['anxietyScore'] != null) chips.add(_buildScoreBadge('불안', log['anxietyScore'], const Color(0xFF722ED1)));
    if (log['depressionScore'] != null) chips.add(_buildScoreBadge('우울', log['depressionScore'], const Color(0xFF1890FF)));
    if (log['hasteScore'] != null) chips.add(_buildScoreBadge('조급함', log['hasteScore'], const Color(0xFFFA8C16)));

    return GestureDetector(
      onTap: () => _showItemDetail(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: const Color(0xFFE6FFFB),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: const Text('감정일기', style: TextStyle(color: Color(0xFF13C2C2), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(situation, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  created != null ? DateFormat('HH:mm').format(created) : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (chips.isNotEmpty) ...[
               Wrap(spacing: 4, runSpacing: 4, children: chips),
               const SizedBox(height: 12),
            ],

            if (imageUrls.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, idx) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(_getAbsoluteUrl(imageUrls[idx])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            Text(
              '생각: $content', 
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                   created != null ? DateFormat('yyyy-MM-dd').format(created) : dateStr, 
                   style: const TextStyle(fontSize: 11, color: Colors.grey)
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notes, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('작성된 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, dynamic score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label $score',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showItemDetail(dynamic log) {
    // Reusing the inner detail view I created earlier, 
    // but maybe I should just define it inline or keep using the class.
    // I will use _EmotionItemDetailScreen (similar to ActivityItemDetailScreen)
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => FamilyEmotionDetailScreen(log: log))
    );
  }
}


