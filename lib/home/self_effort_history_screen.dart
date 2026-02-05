import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class SelfEffortHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SelfEffortHistoryScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<SelfEffortHistoryScreen> createState() => _SelfEffortHistoryScreenState();
}

class _SelfEffortHistoryScreenState extends State<SelfEffortHistoryScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'total'; // 'total', 'GRATITUDE', 'WALK', 'IMPULSE', 'POSITIVE_SELF'
  Map<String, List<String>> _fullDataByDate = {};
  List<Map<String, dynamic>> _dailyCounts = [];
  Map<String, int> _totalCounts = {
    'GRATITUDE': 0,
    'WALK': 0,
    'IMPULSE': 0,
    'POSITIVE_SELF': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchActivityHistory();
  }

  Future<void> _fetchActivityHistory() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    
    // 현재 달과 이전 달 기록을 가져와서 최근 30일치 데이터를 구성
    final currentMonthResponse = await ApiService.getMonthlyActivitySummary(
      widget.userData['uid'], now.year, now.month);
    
    final prevMonthDate = DateTime(now.year, now.month - 1);
    final prevMonthResponse = await ApiService.getMonthlyActivitySummary(
      widget.userData['uid'], prevMonthDate.year, prevMonthDate.month);

    List<dynamic> combinedData = [];
    if (currentMonthResponse['success'] == true) {
      combinedData.addAll(currentMonthResponse['data']);
    }
    if (prevMonthResponse['success'] == true) {
      combinedData.addAll(prevMonthResponse['data']);
    }

    // 날짜별로 정렬 및 카운트 계산
    Map<String, List<String>> tempFullData = {};
    Map<String, int> totals = {
      'GRATITUDE': 0,
      'WALK': 0,
      'IMPULSE': 0,
      'POSITIVE_SELF': 0,
    };

    for (var entry in combinedData) {
      String date = entry['date'];
      List<String> types = List<String>.from(entry['types']);
      tempFullData[date] = types;
      
      for (var type in types) {
        if (totals.containsKey(type)) {
          totals[type] = (totals[type] ?? 0) + 1;
        }
      }
    }

    if (mounted) {
      setState(() {
        _fullDataByDate = tempFullData;
        _totalCounts = totals;
        _updateChartData(); // 데이터 로드 후 차트 데이터 계산
        _isLoading = false;
      });
    }
  }

  void _updateChartData() {
    final now = DateTime.now();
    List<Map<String, dynamic>> chartRows = [];
    
    for (int i = 13; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      final types = _fullDataByDate[dayStr] ?? [];
      
      int count = 0;
      if (_selectedFilter == 'total') {
        count = types.length;
      } else {
        count = types.where((t) => t == _selectedFilter).length;
      }

      chartRows.add({
        'date': day,
        'count': count,
      });
    }
    
    _dailyCounts = chartRows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('자가 노력 히스토리', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  _buildSummarySection(),
                  _buildFilterChips(),
                  _buildChartSection(),
                  _buildDetailsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'id': 'total', 'label': '전체', 'color': const Color(0xFF1890FF)},
      {'id': 'GRATITUDE', 'label': '감사일기', 'color': const Color(0xFFFF851B)},
      {'id': 'WALK', 'label': '일상기록', 'color': const Color(0xFF52C41A)},
      {'id': 'IMPULSE', 'label': '충동일지', 'color': const Color(0xFFFF4D4F)},
      {'id': 'POSITIVE_SELF', 'label': '긍정진술', 'color': const Color(0xFF722ED1)},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['id'];
          final color = filter['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter['id'] as String;
                    _updateChartData();
                  });
                }
              },
              selectedColor: color,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey[300]!,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('누적 실천 획수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleStat('감사일기', _totalCounts['GRATITUDE'] ?? 0, const Color(0xFFFF851B)),
              _buildSimpleStat('일상기록', _totalCounts['WALK'] ?? 0, const Color(0xFF52C41A)),
              _buildSimpleStat('충동일지', _totalCounts['IMPULSE'] ?? 0, const Color(0xFFFF4D4F)),
              _buildSimpleStat('긍정진술', _totalCounts['POSITIVE_SELF'] ?? 0, const Color(0xFF722ED1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildChartSection() {
    List<FlSpot> spots = [];
    double maxVal = 0;
    for (int i = 0; i < _dailyCounts.length; i++) {
      double val = (_dailyCounts[i]['count'] as int).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxVal) maxVal = val;
    }

    Color chartColor = const Color(0xFF1890FF);
    if (_selectedFilter == 'GRATITUDE') chartColor = const Color(0xFFFF851B);
    if (_selectedFilter == 'WALK') chartColor = const Color(0xFF52C41A);
    if (_selectedFilter == 'IMPULSE') chartColor = const Color(0xFFFF4D4F);
    if (_selectedFilter == 'POSITIVE_SELF') chartColor = const Color(0xFF722ED1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(16, 40, 32, 16),
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < 0 || index >= _dailyCounts.length) return const SizedBox.shrink();
                  DateTime date = _dailyCounts[index]['date'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 13,
          minY: 0,
          maxY: maxVal < 4 ? 4 : maxVal + 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: chartColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: chartColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [chartColor.withOpacity(0.2), chartColor.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsList() {
    final filteredRecords = _dailyCounts.where((d) => d['count'] > 0).toList().reversed.toList();
    
    String label = '전체 활동';
    Color color = const Color(0xFF1890FF);
    if (_selectedFilter == 'GRATITUDE') { label = '감사일기'; color = const Color(0xFFFF851B); }
    else if (_selectedFilter == 'WALK') { label = '일상기록'; color = const Color(0xFF52C41A); }
    else if (_selectedFilter == 'IMPULSE') { label = '충동일지'; color = const Color(0xFFFF4D4F); }
    else if (_selectedFilter == 'POSITIVE_SELF') { label = '긍정진술'; color = const Color(0xFF722ED1); }

    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text('최근 $label 기록', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (filteredRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('해당 기간 동안의 $label 기록이 없습니다.', style: const TextStyle(color: Colors.grey)),
              ),
            ),
          ...filteredRecords.map((d) {
            DateTime date = d['date'];
            int count = d['count'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('yyyy년 MM월 dd일').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$label $count건', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
