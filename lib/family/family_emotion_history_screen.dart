import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class FamilyEmotionDetailsModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? initialDate;
  final VoidCallback? onRefresh;

  const FamilyEmotionDetailsModal({
    super.key,
    required this.userData,
    this.initialDate,
    this.onRefresh,
  });

  static void show(BuildContext context, Map<String, dynamic> userData, {String? date, VoidCallback? onRefresh}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FamilyEmotionDetailsModal(
        userData: userData,
        initialDate: date,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<FamilyEmotionDetailsModal> createState() => _FamilyEmotionDetailsModalState();
}

class _FamilyEmotionDetailsModalState extends State<FamilyEmotionDetailsModal> {
  bool _isAllView = false;
  late DateTime _selectedDate;
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate != null 
        ? DateTime.parse(widget.initialDate!) 
        : DateTime.now();
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
        
        // Filter by date if needed
        if (!_isAllView) {
          final targetDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
          allLogs = allLogs.where((log) {
            String created = log['createdAt'] ?? '';
            return created.startsWith(targetDate);
          }).toList();
        }
        
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

  void _nextDate() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _isAllView = false;
    });
    _fetchLogs();
  }

  void _prevDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _isAllView = false;
    });
    _fetchLogs();
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF13C2C2), // Cyan for Emotion Diary
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchLogs();
    }
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
          _buildToggleButtons(),
          if (!_isAllView) _buildDateNavigation(),
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

  Widget _buildToggleButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isAllView) {
                  setState(() {
                    _isAllView = false;
                    _fetchLogs();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isAllView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_isAllView ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Center(
                  child: Text(
                    '일자별',
                    style: TextStyle(
                      color: !_isAllView ? Colors.black : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isAllView) {
                  setState(() {
                    _isAllView = true;
                    _fetchLogs();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isAllView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isAllView ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Center(
                  child: Text(
                    '전체',
                    style: TextStyle(
                      color: _isAllView ? Colors.black : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _prevDate,
            icon: const Icon(Icons.chevron_left, color: Colors.grey, size: 28),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _showDatePicker,
            child: Text(
              DateFormat('yyyy/MM/dd').format(_selectedDate),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F1F1F),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: _nextDate,
            icon: const Icon(Icons.chevron_right, color: Colors.grey, size: 28),
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
      MaterialPageRoute(builder: (_) => _EmotionItemDetailScreen(log: log))
    );
  }
}

class _EmotionItemDetailScreen extends StatelessWidget {
   final dynamic log;
   const _EmotionItemDetailScreen({Key? key, required this.log}) : super(key: key);

   String _getAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('data:image')) return path;
    if (path.startsWith('http')) return path;
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
      final List<dynamic> imageUrls = log['imageUrls'] ?? [];

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          title: const Text('감정일기 상세'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               if (imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _getAbsoluteUrl(imageUrls[index]),
                              width: MediaQuery.of(context).size.width * 0.8,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
               ],
               
               _buildSection('상황', log['situation']),
               
               const SizedBox(height: 24),
               const Text('감정 점수', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 12),
               Wrap(
                 spacing: 8, runSpacing: 8,
                 children: [
                   if (log['angerScore'] != null) _buildDetailScore('분노', log['angerScore'], const Color(0xFFFF4D4F)),
                   if (log['anxietyScore'] != null) _buildDetailScore('불안', log['anxietyScore'], const Color(0xFF722ED1)),
                   if (log['depressionScore'] != null) _buildDetailScore('우울', log['depressionScore'], const Color(0xFF1890FF)),
                   if (log['hasteScore'] != null) _buildDetailScore('조급함', log['hasteScore'], const Color(0xFFFA8C16)),
                 ],
               ),
               
               const SizedBox(height: 24),
               _buildSection('자동적 사고', log['thought']),
               _buildSection('반박하기', log['rebuttal']),
               _buildSection('상황 종료 후 나의 감정', log['aftermath']), // Question 5
            ],
          ),
        ),
      );
   }

   Widget _buildDetailScore(String label, dynamic score, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('$score점', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      );
   }

   Widget _buildSection(String title, String? content) {
      if (content == null || content.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Text(content, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF424242))),
          ),
        ],
      );
   }
}
