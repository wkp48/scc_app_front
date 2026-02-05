import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import 'diagnosis_detail_screen.dart';
import 'diagnosis_survey_screen.dart';

class DiagnosisHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DiagnosisHistoryScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<DiagnosisHistoryScreen> createState() => _DiagnosisHistoryScreenState();
}

class _DiagnosisHistoryScreenState extends State<DiagnosisHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  bool _diagnosisAdded = false; // 진단 추가 여부 추적

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final response = await ApiService.getDiagnosisHistory(widget.userData['uid']);
    if (response['success'] == true) {
      if (mounted) {
        setState(() {
          _history = response['data'];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        ToastUtils.show(context, response['message'] ?? '데이터를 불러오는데 실패했습니다.');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.pop(context, _diagnosisAdded);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('회복 노력 히스토리', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _diagnosisAdded),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_task, color: Color(0xFF52C41A)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiagnosisSurveyScreen(userData: widget.userData),
                  ),
                );
                if (result == true) {
                  _diagnosisAdded = true;
                  _fetchHistory();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildChartSection(),
                        _buildHistoryList(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('진단 기록이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiagnosisSurveyScreen(userData: widget.userData),
                ),
              );
              if (result == true) {
                _diagnosisAdded = true;
                _fetchHistory();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52C41A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text('첫 자가진단 시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (_history.length < 2) {
      return Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text('그래프를 표시하려면 2개 이상의 진단 기록이 필요합니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    // 데이터를 차트 형식으로 변환
    List<FlSpot> spots = [];
    for (int i = 0; i < _history.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_history[i]['totalScore'] as num).toDouble()));
    }

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.fromLTRB(16, 32, 32, 16),
      height: 300,
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
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < 0 || index >= _history.length || _history.length > 7 && index % (_history.length ~/ 4) != 0) {
                    return const SizedBox.shrink();
                  }
                  DateTime date = DateTime.parse(_history[index]['createdAt']);
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_history.length - 1).toDouble(),
          minY: 0,
          maxY: 40, // 진단지 만점 기준 (조절 가능)
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF52C41A),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF52C41A),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [const Color(0xFF52C41A).withOpacity(0.2), const Color(0xFF52C41A).withOpacity(0)],
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

  Widget _buildHistoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        // 최근 것부터 보여줌
        final record = _history[_history.length - 1 - index];
        DateTime date = DateTime.parse(record['createdAt']);
        int score = record['totalScore'] ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DiagnosisDetailScreen(record: record),
              ),
            );
          },
          child: Container(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy년 MM월 dd일 HH:mm').format(date),
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('자가진단 결과 (상세보기)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: score >= 27 ? const Color(0xFFFFF1F0) : const Color(0xFFF6FFED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score점',
                    style: TextStyle(
                      color: score >= 27 ? const Color(0xFFFF4D4F) : const Color(0xFF52C41A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
