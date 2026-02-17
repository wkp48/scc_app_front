import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class RecoveryTrendCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isEmbedded; // [Added]
  final String checklistType; // [Added] 'PATIENT' or 'FAMILY'

  const RecoveryTrendCard({
    Key? key, 
    required this.userData,
    this.isEmbedded = false,
    this.checklistType = 'PATIENT', // Default
  }) : super(key: key);

  @override
  State<RecoveryTrendCard> createState() => _RecoveryTrendCardState();
}

class _RecoveryTrendCardState extends State<RecoveryTrendCard> {
  bool _isExpanded = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyData = [];
  
  // Family Group State
  String _selectedFamilyGroup = 'ROLE'; // 'ROLE' or 'RECOVERY'

  // Colors matching the photo dots
  final Map<String, Color> _categoryColors = {
    // Personal Recovery (RECOVERY)
    '신체지표': const Color(0xFF5C72EB),
    '신체 지표': const Color(0xFF5C72EB),
    '정서지표': const Color(0xFF4CAF50),
    '정서 지표': const Color(0xFF4CAF50),
    '사고지표': const Color(0xFFFF9800),
    '사고 지표': const Color(0xFFFF9800),
    '사고': const Color(0xFFFF9800),
    '대인관계지표': const Color(0xFF9C27B0),
    '대인관계 지표': const Color(0xFF9C27B0),
    '대인': const Color(0xFF9C27B0),
    // Family Roles (ROLE)
    '재정관리': const Color(0xFF795548),
    '통제욕구': const Color(0xFFE91E63),
    '건강한대화': const Color(0xFF00BCD4),
    '건강한피드백': const Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didUpdateWidget(RecoveryTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData['uid'] != oldWidget.userData['uid']) {
      _fetchHistory();
    }
  }

  // Public method to refresh data
  void refresh() => _fetchHistory();

  Future<void> _fetchHistory() async {
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    final result = await ApiService.getChecklistHistory(uid, days: 7);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _historyData = List<Map<String, dynamic>>.from(result['data']);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }

    if (_historyData.isEmpty) {
       return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (!widget.isEmbedded)
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart_rounded, color: Color(0xFF5C72EB), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '나의 회복 변화 그래프 보기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) _buildLineChartSection(),
      ],
    );
  }

  Widget _buildLineChartSection() {
    final List<String> currentCategories = _getCurrentCategories();
    
    return Column(
      children: [
        // Family Group Toggle (Only for Family Type)
        if (widget.checklistType == 'FAMILY') ...[
          _buildFamilyGroupToggle(),
          const SizedBox(height: 24),
        ],

        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: currentCategories.map((cat) {
              String label = cat.replaceAll('지표', '').replaceAll('건강한 ', '').trim();
              if (label == '대인관계') label = '대인';
              return MapEntry(label, _categoryColors[cat] ?? Colors.grey);
            }).fold<Map<String, Color>>({}, (map, entry) {
              map[entry.key] = entry.value;
              return map;
            }).entries.map((e) => _buildLegendDot(e.key, e.value)).toList(),
          ),
        ),
        // Chart
        SizedBox(
          height: 240,
          child: LineChart(
            _buildLineChartData(currentCategories),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFamilyGroupToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleButton('가족 역할', 'ROLE'),
          _buildToggleButton('개인 회복', 'RECOVERY'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, String value) {
    final isSelected = _selectedFamilyGroup == value;
    final color = value == 'ROLE' ? const Color(0xFF5C72EB) : const Color(0xFF4CAF50);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFamilyGroup = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : const Color(0xFF999999),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getCurrentCategories() {
    if (widget.checklistType == 'FAMILY') {
      return _selectedFamilyGroup == 'ROLE' 
        ? ['재정관리', '통제욕구', '건강한대화', '건강한피드백']
        : ['신체지표', '정서지표', '사고지표', '대인관계지표'];
    }
    // Return simple keys, matching will be handled flexibly
    return ['신체지표', '정서지표', '사고지표', '대인관계지표'];
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  LineChartData _buildLineChartData(List<String> categories) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 2,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF0F0F0), strokeWidth: 1),
        getDrawingVerticalLine: (value) => FlLine(color: const Color(0xFFF0F0F0), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index < 0 || index >= _historyData.length) return const SizedBox.shrink();
              
              if (index != 0 && index != _historyData.length - 1 && index != (_historyData.length ~/ 2)) {
                return const SizedBox.shrink();
              }

              final dateStr = _historyData[index]['date'] as String;
              final date = DateTime.parse(dateStr);
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${date.month}/${date.day}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              );
            },
            reservedSize: 28,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (_historyData.length - 1).toDouble(),
      minY: 0,
      maxY: widget.checklistType == 'PATIENT' ? 10 : 11,
      lineBarsData: categories.map((cat) {
        return LineChartBarData(
          show: true,
          spots: List.generate(_historyData.length, (i) {
            final Map scores = _historyData[i]['scores'] ?? {};
            double score = 0;
            
            // Very aggressive matching
            dynamic raw;
            String search = cat.replaceAll('지표', '').replaceAll(' ', '').trim();
            
            // Try exact, then space inserted, then suffix added
            raw = scores[cat] ?? 
                  scores[cat.replaceAll('지표', ' 지표')] ??
                  scores[search] ??
                  scores['$search 지표'] ??
                  scores['${search}지표'];

            // Substring fallback
            if (raw == null) {
              for (var key in scores.keys) {
                if (key.toString().replaceAll(' ', '').contains(search)) {
                  raw = scores[key];
                  break;
                }
              }
            }

            if (raw != null) score = (raw as num).toDouble();
            return FlSpot(i.toDouble(), score);
          }),
          isCurved: true,
          color: _categoryColors[cat] ?? _categoryColors[cat.replaceAll('지표', ' 지표')] ?? Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: barData.color ?? Colors.blue,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
    );
  }
}
