import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'activity_item_detail_screen.dart';

class ActivityDetailsModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String activityType; // 'WALK', 'GRATITUDE', 'IMPULSE', 'POSITIVE_SELF'
  final String? initialDate;
  final VoidCallback? onRefresh; // 갱신 콜백 추가

  const ActivityDetailsModal({
    super.key,
    required this.userData,
    required this.activityType,
    this.initialDate,
    this.onRefresh,
  });

  static void show(BuildContext context, Map<String, dynamic> userData, String type, {String? date, VoidCallback? onRefresh}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityDetailsModal(
        userData: userData,
        activityType: type,
        initialDate: date,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<ActivityDetailsModal> createState() => _ActivityDetailsModalState();
}

class _ActivityDetailsModalState extends State<ActivityDetailsModal> {
  bool _isAllView = false;
  late DateTime _selectedDate;
  List<dynamic> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate != null 
        ? DateTime.parse(widget.initialDate!) 
        : DateTime.now();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _isAllView ? null : DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await ApiService.getActivities(
        uid: widget.userData['uid'],
        date: dateStr,
        type: widget.activityType,
      );

      if (response['success']) {
        setState(() {
          _activities = response['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('data:image')) return path;
    if (path.startsWith('http')) return path;
    
    // 기본 베이스 URL
    const String effectiveBaseUrl = 'http://192.168.0.75:8900/api';
    
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
    _fetchActivities();
  }

  void _prevDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _isAllView = false;
    });
    _fetchActivities();
  }

  String _getActivityTitle() {
    switch (widget.activityType) {
      case 'WALK': return '일상 기록';
      case 'GRATITUDE': return '감사 일기';
      case 'IMPULSE': return '충동 일지';
      case 'POSITIVE_SELF': return '희망 리코딩';
      default: return '기록 상세';
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
            child: widget.activityType == 'ALL' && _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _activities.isEmpty 
                        ? _buildEmptyState()
                        : _buildActivityList(),
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
              Text(_getActivityTitle(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    _fetchActivities();
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
                    _fetchActivities();
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
              primary: Color(0xFF5C72EB),
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
      _fetchActivities();
    }
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

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(dynamic activity) {
    final List<dynamic> imageUrls = activity['imageUrls'] ?? [];
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityItemDetailScreen(
              activity: activity,
              userData: widget.userData,
            ),
          ),
        );
        if (result == true) {
          _fetchActivities();
          if (widget.onRefresh != null) widget.onRefresh!(); // 외부 화면(Home, Calendar 등) 갱신 트리거
        }
      },
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
                      if (activity['category'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            activity['category'],
                            style: const TextStyle(color: Color(0xFFFF851B), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (activity['score'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '강도: ${activity['score']}',
                            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (activity['activityType'] != 'POSITIVE_SELF')
                        Text(activity['title'] ?? '제목 없음', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (activity['activityType'] != 'WALK' && activity['activityType'] != 'POSITIVE_SELF')
                  Text(
                    activity['startTime'] != null ? '${activity['startTime'].substring(0, 5)}' : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
            Text(activity['content'] ?? '', 
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(activity['date'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
}
