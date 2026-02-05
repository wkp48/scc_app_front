import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'anxiety_score_screen.dart';

class AnxietyHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AnxietyHistoryScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<AnxietyHistoryScreen> createState() => _AnxietyHistoryScreenState();
}

class _AnxietyHistoryScreenState extends State<AnxietyHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    final response = await ApiService.getAnxietyLogs(uid);

    if (mounted) {
      setState(() {
        if (response['success'] == true) {
          _logs = response['data'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  void _goToWriteScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnxietyScoreScreen(userData: widget.userData),
      ),
    );
    if (result == true) {
      // Refresh list if saved
      setState(() => _isLoading = true);
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('감정일기 기록'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _goToWriteScreen,
            child: const Text('작성하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        '아직 기록된 내용이 없습니다.\n작성하기 버튼을 눌러 기록을 시작해보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final String date = (log['createdAt'] ?? '').toString().split('T')[0];
                    final String situation = log['situation'] ?? '';
                    
                    // Build emotion tags
                    List<Widget> emotionChips = [];
                    if (log['angerScore'] != null) emotionChips.add(_buildScoreBadge('분노', log['angerScore'], const Color(0xFFFF4D4F)));
                    if (log['anxietyScore'] != null) emotionChips.add(_buildScoreBadge('불안', log['anxietyScore'], const Color(0xFF722ED1)));
                    if (log['depressionScore'] != null) emotionChips.add(_buildScoreBadge('우울', log['depressionScore'], const Color(0xFF1890FF)));
                    if (log['hasteScore'] != null) emotionChips.add(_buildScoreBadge('조급함', log['hasteScore'], const Color(0xFFFA8C16)));

                    return GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnxietyScoreScreen(userData: widget.userData, initialData: log),
                          ),
                        );
                        if (result == true) {
                          setState(() => _isLoading = true);
                          _fetchLogs();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  date,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                ),
                                // Render chips if any, otherwise showing simple text or empty
                                if (emotionChips.isNotEmpty)
                                  Wrap(spacing: 4, children: emotionChips)
                                else
                                  const SizedBox(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              situation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (log['thought'] != null)
                               Text(
                                '생각: ${log['thought']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildScoreBadge(String label, dynamic score, Color color) {
    double s = 0;
    if (score != null) {
      s = double.tryParse(score.toString()) ?? 0;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label ${s.round()}',
        style: TextStyle(
          color: color, 
          fontSize: 11, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
}
