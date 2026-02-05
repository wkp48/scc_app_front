import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class RecoveryTrendCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isEmbedded; // [Added] Embedded mode flag

  const RecoveryTrendCard({
    Key? key, 
    required this.userData,
    this.isEmbedded = false, // Default false
  }) : super(key: key);

  @override
  State<RecoveryTrendCard> createState() => _RecoveryTrendCardState();
}

class _RecoveryTrendCardState extends State<RecoveryTrendCard> {
  bool _isExpanded = true; // [Modified] Default expanded
  bool _isLoading = false;
  List<Map<String, dynamic>> _historyData = [];
  
  // Color Palette specifically designed for distinction
  final Map<String, Color> _categoryColors = {
    '신체 지표': const Color(0xFF5C72EB), // Blue
    '정서 지표': const Color(0xFF4CAF50), // Green
    '사고 지표': const Color(0xFFFF9800), // Orange
    '대인관계 지표': const Color(0xFF9C27B0), // Purple
  };

  @override
  void initState() {
    super.initState();
    // Default collapsed, load data when expanded or pre-load? 
    // Let's pre-load to be ready
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    
    // Fetch 14 days history
    final result = await ApiService.getChecklistHistory(uid, days: 14);
    
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
    // If embedded, remove Container decoration
    if (widget.isEmbedded) {
      return Column(
        children: _buildContent(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: _buildContent(),
      ),
    );
  }

  List<Widget> _buildContent() {
    return [
          // Header / Toggle Button
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            // [Modified] Radius based on embedded status
            borderRadius: widget.isEmbedded ? BorderRadius.circular(16) : BorderRadius.circular(24),
            child: Padding(
              // [Modified] Padding based on embedded status
              padding: widget.isEmbedded 
                  ? const EdgeInsets.symmetric(vertical: 16, horizontal: 0) 
                  : const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
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
                        const Text(
                          '나의 회복 변화 그래프 보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                     ],
                   ),
                   Icon(
                     _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                     color: Colors.grey,
                   ),
                ],
              ),
            ),
          ),
          
          // Expanded Content
          if (_isExpanded)
            Padding(
              // [Modified] Padding based on embedded status
              padding: widget.isEmbedded 
                  ? const EdgeInsets.only(bottom: 16) 
                  : const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _historyData.isEmpty || _historyData.length < 2
                      ? const SizedBox(
                          height: 100,
                          child: Center(
                            child: Text('데이터가 충분하지 않습니다.\n최소 2일 이상의 기록이 필요합니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildLegend(),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 250,
                              child: LineChart(
                                _buildChartData(),
                              ),
                            ),
                          ],
                        ),
            ),
    ];
  }
  
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _categoryColors.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.key.replaceAll(' 지표', ''), 
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555), fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }

  LineChartData _buildChartData() {
    // Process Data
    // X-axis: Index 0 to N-1
    // Y-axis: Score 0 to 10
    
    final categories = _categoryColors.keys.toList();
    List<LineChartBarData> lineBarsData = [];

    for (String category in categories) {
      List<FlSpot> spots = [];
      for (int i = 0; i < _historyData.length; i++) {
        final dayData = _historyData[i];
        // [Modified] Safer map casting
        final scores = dayData['scores'] as Map?;
        
        if (scores != null) {
          if (scores.containsKey(category)) {
             // Handle both int and double
             try {
               double score = (scores[category] as num).toDouble();
               spots.add(FlSpot(i.toDouble(), score));
             } catch (e) {
               // print('Error parsing score for $category at index $i: $e');
             }
          } else {
             // Try fuzzy match
             String shortKey = category.split(' ')[0];
             if (scores.containsKey(shortKey)) {
                try {
                   double score = (scores[shortKey] as num).toDouble();
                   spots.add(FlSpot(i.toDouble(), score));
                } catch (e) {}
             }
          }
        }
      }
      //나의 회복 변화 그래프 직선 곡선
      if (spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true, // [Modified] Straight lines
          color: _categoryColors[category],
          barWidth: 3, // Increased width
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true), // Enable dots to verify data points
          belowBarData: BarAreaData(show: false),
        ));
      }
    }

     return LineChartData(
      lineBarsData: lineBarsData, // [Fix] Add this missing parameter!
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 2, // 0, 2, 4, 6, 8, 10
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Color(0xFFEEEEEE),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Color(0xFFEEEEEE),
            strokeWidth: 1,
          );
        },
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
              if (index >= 0 && index < _historyData.length) {
                
                 if (_historyData.length > 7 && index % 3 != 0 && index != _historyData.length - 1) {
                   return const SizedBox.shrink();
                 }
                 
                 final dateStr = _historyData[index]['date'] as String; // YYYY-MM-DD
                 try {
                   final date = DateTime.parse(dateStr);
                   return SideTitleWidget(
                     meta: meta, 
                     child: Text(
                       '${date.month}/${date.day}',
                       style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                     ), 
                   );
                 } catch (e) {
                   return const SizedBox.shrink();
                 }
              }
              return const SizedBox.shrink();
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
                style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
              );
            },
            reservedSize: 20,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: _historyData.isEmpty ? 0 : (_historyData.length - 1).toDouble(), // [Fix] Safety check
      minY: 0,
      maxY: 10,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final flSpot = barSpot;
              // Find category index? No directly mapped.
              // We need to know which line corresponds to which category.
              // LineChartBarData color matches _categoryColors.
              
              // Simple workaround: Just show value
              return LineTooltipItem(
                '${flSpot.y}',
                const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
