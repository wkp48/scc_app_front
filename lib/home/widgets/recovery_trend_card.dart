import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  bool _isExpanded = true;
  bool _isLoading = true; // Start true
  List<Map<String, dynamic>> _historyData = [];
  
  // Family Group State
  String _selectedFamilyGroup = 'ROLE'; // 'ROLE' (가족 역할) or 'RECOVERY' (개인 회복)

  // Full Color Palette
  final Map<String, Color> _allCategoryColors = {
    '신체 지표': const Color(0xFF5C72EB), // Blue
    '정서 지표': const Color(0xFF4CAF50), // Green
    '사고 지표': const Color(0xFFFF9800), // Orange
    '대인관계 지표': const Color(0xFF9C27B0), // Purple
    // Family Categories
    '재정관리': const Color(0xFF795548), // Brown
    '통제욕구': const Color(0xFFE91E63), // Pink
    '건강한 대화': const Color(0xFF00BCD4), // Cyan
    '건강한 피드백': const Color(0xFF607D8B), // Blue Grey
  };

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    // History endpoint returns last N days. Default 7.
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
      return const SizedBox(
        height: 100, 
        child: Center(child: CircularProgressIndicator())
      );
    }

    if (_historyData.isEmpty) {
       return Container(
         padding: const EdgeInsets.symmetric(vertical: 24),
         alignment: Alignment.center,
         child: const Text('최근 기록이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
       );
    }

    return Container(
      padding: EdgeInsets.all(widget.isEmbedded ? 0 : 20),
      decoration: widget.isEmbedded ? null : BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEmbedded) ...[
             const Text(
              '회복 변화 추이', // Title might need update if it's not trend anymore, but "Growth Status" contextually fits
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],
          
          if (widget.isEmbedded) const SizedBox(height: 16),

          // Family Group Toggle
          if (widget.checklistType == 'FAMILY') ...[
            _buildFamilyGroupToggle(),
            const SizedBox(height: 32),
          ],
          
          // Radar Chart
          SizedBox(
            height: 300,
            child: RadarChart(
              _buildRadarChartData(),
              swapAnimationDuration: const Duration(milliseconds: 400),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyGroupToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildAreaCard(
            '가족 역할', 
            'ROLE', 
            Icons.family_restroom_rounded,
            const Color(0xFF5C72EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAreaCard(
            '개인 회복', 
            'RECOVERY', 
            Icons.self_improvement_rounded,
            const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaCard(String label, String value, IconData icon, Color color) {
    final isSelected = _selectedFamilyGroup == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFamilyGroup = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              color: isSelected ? Colors.white : color, 
              size: 32
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _currentCategories {
    if (widget.checklistType == 'FAMILY') {
      return _selectedFamilyGroup == 'ROLE' 
        ? ['재정관리', '통제욕구', '건강한 대화', '건강한 피드백']
        : ['신체 지표', '정서 지표', '사고 지표', '대인관계 지표'];
    }
    return ['신체 지표', '정서 지표', '사고 지표', '대인관계 지표'];
  }

  Map<String, double> _getLatestScores() {
    if (_historyData.isEmpty) return {};
    final latest = _historyData.last; 
    final scores = latest['scores'] as Map;
    final Map<String, double> result = {};
    
    scores.forEach((key, value) {
        if (value is num) result[key.toString()] = value.toDouble();
    });
    return result;
  }

  String _getStatusText(double score) {
    if (score < 3) return '위험';
    if (score < 6) return '주의';
    if (score < 8) return '중간'; 
    return '좋음';
  }
  
  Color _getStatusColor(double score) {
     if (score < 3) return const Color(0xFFFF4D4F); // Red
     if (score < 6) return const Color(0xFFFFA940); // Orange
     if (score < 8) return const Color(0xFF36CFC9); // Cyan/Green
     return const Color(0xFF5C72EB); // Blue
  }

  RadarChartData _buildRadarChartData() {
     final latestScores = _getLatestScores();
     final categories = _currentCategories; 
     
     // Which categories to highlight/show based on selection
     final List<String> roleCategories = ['재정관리', '통제욕구', '건강한 대화', '건강한 피드백'];
     final List<String> recoveryCategories = ['신체 지표', '정서 지표', '사고 지표', '대인관계 지표'];
     
     final selectedSet = _selectedFamilyGroup == 'ROLE' ? roleCategories : recoveryCategories;

     return RadarChartData(
       radarTouchData: RadarTouchData(enabled: false),
       tickCount: 1,
       ticksTextStyle: const TextStyle(color: Colors.transparent),
       gridBorderData: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
       titlePositionPercentageOffset: 0.25, 
       titleTextStyle: const TextStyle(color: Color(0xFF333333), fontSize: 11, fontWeight: FontWeight.bold),
       getTitle: (index, angle) {
          if (index >= categories.length) return const RadarChartTitle(text: '');
          final category = categories[index];
          String label = category.replaceAll(' 지표', '').replaceAll('건강한 ', '');
          if (label == '대인관계') label = '대인';

          double score = 0;
          if (latestScores.containsKey(category)) {
             score = latestScores[category]!;
          } else {
             String shortKey = category.split(' ')[0];
             if (latestScores.containsKey(shortKey)) {
                 score = latestScores[shortKey]!;
             }
          }
          
          final status = _getStatusText(score);
          // Return the title with status
          return RadarChartTitle(
            text: '$label\n($status)',
            positionPercentageOffset: 0.1,
          );
       },
       dataSets: [
         RadarDataSet(
           fillColor: (_selectedFamilyGroup == 'ROLE' ? const Color(0xFF5C72EB) : const Color(0xFF4CAF50)).withOpacity(0.2),
           borderColor: _selectedFamilyGroup == 'ROLE' ? const Color(0xFF5C72EB) : const Color(0xFF4CAF50),
           entryRadius: 3,
           borderWidth: 2,
           dataEntries: categories.map((category) {
              // Only provide data if the category is in the selected set
              if (!selectedSet.contains(category)) {
                 return const RadarEntry(value: 0);
              }
              
              double score = 0;
              if (latestScores.containsKey(category)) {
                 score = latestScores[category]!;
              } else {
                 String shortKey = category.split(' ')[0];
                 if (latestScores.containsKey(shortKey)) {
                     score = latestScores[shortKey]!;
                 }
              }
              return RadarEntry(value: score);
           }).toList(),
         ),
         // Max Scale Reference
         RadarDataSet(
           fillColor: Colors.transparent,
           borderColor: Colors.transparent,
           entryRadius: 0,
           dataEntries: categories.map((_) => const RadarEntry(value: 10)).toList(),
         )
       ],
     );
  }
}
