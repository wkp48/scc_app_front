import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class FamilyGrowthChecklistModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String date; // YYYY-MM-DD
  final Map<String, dynamic>? savedScores;

  const FamilyGrowthChecklistModal({
    Key? key,
    required this.userData,
    required this.date,
    this.savedScores,
  }) : super(key: key);

  @override
  State<FamilyGrowthChecklistModal> createState() => _FamilyGrowthChecklistModalState();
}

class _FamilyGrowthChecklistModalState extends State<FamilyGrowthChecklistModal> {
  final Map<int, double> _answers = {};
  bool _isSubmitting = false;
  int _selectedGraphTab = 0; // 0: 가족 역할, 1: 개인 회복

  // Question Definitions
  final List<Map<String, dynamic>> _questions = [
    // --- 가족 역할 (Family Role) ---
    {
      'id': 1,
      'category': '가족 역할',
      'subcategory': '재정관리',
      'question': '센터에서 배운 재정관리 방법은 얼마나 실천하고 계신가요?',
      'reverse': false,
    },
    {
      'id': 2,
      'category': '가족 역할',
      'subcategory': '통제욕구',
      'question': '도박중독 당사자의 행동 하나하나를 바꾸고 싶다는 생각은 어느 정도였나요?',
      'reverse': true, // 역채점
    },
    {
      'id': 3,
      'category': '가족 역할',
      'subcategory': '건강한 대화',
      'question': '도박중독 당사자를 비난하거나 의심하지 않는 건강한 방식의 대화는 어느 정도 실천하고 계신가요?',
      'reverse': false,
    },
    {
      'id': 4,
      'category': '가족 역할',
      'subcategory': '건강한 피드백',
      'question': '도박중독 당사자의 변화 노력에 대해 긍정적 피드백을 제공하기 위한 노력은 어느 정도였나요?',
      'reverse': false,
    },
    // --- 개인 회복 (Personal Recovery) ---
    {
      'id': 5,
      'category': '개인 회복',
      'subcategory': '신체지표',
      'question': '건강에 도움이 되는 신체활동은 충분하다고 느끼셨나요?',
      'reverse': false,
    },
    {
      'id': 6,
      'category': '개인 회복',
      'subcategory': '대인관계 지표',
      'question': '다른 사람과 이야기를 나누거나 함께하는 시간은 충분하다고 느끼셨나요?',
      'reverse': false,
    },
    {
      'id': 7,
      'category': '개인 회복',
      'subcategory': '정서지표',
      'question': '작은 일에도 예민하거나 화나는 느낌은 어느 정도였나요?',
      'reverse': true, // 역채점
    },
    {
      'id': 8,
      'category': '개인 회복',
      'subcategory': '사고지표',
      'question': '현재 상황에서 벗어나고 싶다는 생각을 얼마나 하셨나요?',
      'reverse': true, // 역채점
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize answers
    for (var q in _questions) {
      final int id = q['id'];
      final String subcat = q['subcategory'];
      
      if (widget.savedScores != null && widget.savedScores!.containsKey(subcat)) {
        double val = (widget.savedScores![subcat] as num).toDouble();
        // Un-reverse if needed for slider
        if (q['reverse'] == true) {
           val = 11 - val;
        }
        _answers[id] = val;
      } else {
        _answers[id] = 5.0; // Default middle value
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final uid = widget.userData['uid'] ?? widget.userData['userid'];
      
      // Map subcategory to score for API
      Map<String, int> apiScores = {};
      
      // We need to collect scores by subcategory
      for (var q in _questions) {
         int id = q['id'];
         double rawScore = _answers[id]!;
         bool isReverse = q['reverse'];
         double finalScore = isReverse ? (11 - rawScore) : rawScore;
         
         String subcat = q['subcategory'];
         // Map to keys expected by ApiService
         // Note: ApiService expects these exact keys in the Map
         apiScores[subcat] = finalScore.toInt();
      }

      await ApiService.saveFamilyGrowthChecklist(uid, widget.date, apiScores);
      // Calculate subcategory scores for graph
      Map<String, double> resultScores = {};
      for (var q in _questions) {
         int id = q['id'];
         double rawScore = _answers[id]!;
         bool isReverse = q['reverse'];
         double finalScore = isReverse ? (11 - rawScore) : rawScore;
         
         resultScores[q['subcategory']] = finalScore;
      }

      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      if (mounted) {
        ToastUtils.show(context, '저장되었습니다.');
        Navigator.of(context).pop(resultScores); // Return the Map
      }
    } catch (e) {
      ToastUtils.show(context, '저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF5C72EB), // Primary Color
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.checklist_rtl_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '나의 성장 점검',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '오늘 하루 나의 상태를 점검해보세요 (1~10점)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                     // Tab Selector
                     Container(
                       margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                       decoration: BoxDecoration(
                         color: const Color(0xFFF5F5F5),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       padding: const EdgeInsets.all(4),
                       child: Row(
                         children: [
                           _buildTabButton('가족 역할', 0),
                           _buildTabButton('개인 회복', 1),
                         ],
                       ),
                     ),
                     // Graph
                     _buildRadarChart(),
                     
                     const Padding(
                       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                       child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                     ),

                    ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 32),
                      itemBuilder: (context, index) => _buildQuestionItem(_questions[index]),
                    ),
                  ],
                ),
              ),
            ),

            // Footer (Button)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C72EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          '제출하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(Map<String, dynamic> question) {
    final int id = question['id'];
    final String text = question['question'];
    // final String subcategory = question['subcategory']; // Not used in UI anymore
    // final bool isReverse = question['reverse']; // Not used in UI anymore

    final double currentScore = _answers[id] ?? 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F1F1F),
            height: 1.4,
          ),
        ),
        
        const SizedBox(height: 16),
        Row(
          children: [
             Text('1', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
             Expanded(
               child: SliderTheme(
                 data: SliderTheme.of(context).copyWith(
                   activeTrackColor: const Color(0xFF5C72EB),
                   inactiveTrackColor: const Color(0xFFE0E0E0),
                   thumbColor: const Color(0xFF5C72EB),
                   overlayColor: const Color(0xFF5C72EB).withOpacity(0.1),
                   trackHeight: 4,
                   thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                   overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                   valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                   valueIndicatorColor: const Color(0xFF5C72EB),
                   valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                 ),
                 child: Slider(
                   value: currentScore,
                   min: 1, 
                   max: 10,
                   divisions: 9, 
                   label: currentScore.round().toString(),
                   onChanged: (value) {
                     setState(() {
                       _answers[id] = value;
                     });
                   },
                 ),
               ),
             ),
             Text('10', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Center(
          child: Text(
            '${currentScore.round()}점',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C72EB),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String text, int index) {
      final bool isSelected = _selectedGraphTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedGraphTab = index;
            });
          },
          child: Container(
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
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF5C72EB) : const Color(0xFF888888),
              ),
            ),
          ),
       ),
      );
  }

  Widget _buildRadarChart() {
    List<Map<String, dynamic>> targetQuestions;
    if (_selectedGraphTab == 0) {
       // IDs 1-4
       targetQuestions = _questions.where((q) => [1,2,3,4].contains(q['id'])).toList();
    } else {
       // IDs 5-8
       targetQuestions = _questions.where((q) => [5,6,7,8].contains(q['id'])).toList();
    }

    // Prepare values
    final List<double> values = targetQuestions.map((q) {
        int id = q['id'];
        double raw = _answers[id] ?? 5.0;
        bool reverse = q['reverse'] ?? false;
        return reverse ? (11 - raw) : raw;
    }).toList();
    
    // Labels
    final List<String> labels = targetQuestions.map((q) => q['subcategory'] as String).toList();
    const Color primaryColor = Color(0xFF5C72EB); 

    Widget buildLabel(String labelText, double val, Alignment alignment) {
       return Align(
           alignment: alignment,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 labelText,
                  style: const TextStyle(
                     color: Color(0xFF555555),
                     fontSize: 12,
                     fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
               ),
               Text(
                 '${val.toInt()}점',
                 style: const TextStyle(
                     color: primaryColor,
                     fontSize: 11,
                     fontWeight: FontWeight.bold,
                 ),
               ),
             ],
           )
       );
    }

    return SizedBox(
     height: 250,
     child: Stack(
       children: [
           Padding(
               padding: const EdgeInsets.all(40.0),
               child: RadarChart(
                   RadarChartData(
                   radarShape: RadarShape.polygon,
                   dataSets: [
                       RadarDataSet(
                       fillColor: Colors.transparent,
                       borderColor: Colors.transparent,
                       entryRadius: 0,
                       dataEntries: List.generate(4, (index) => const RadarEntry(value: 10)),
                       borderWidth: 0,
                       ),
                       RadarDataSet(
                       fillColor: primaryColor.withOpacity(0.2),
                       borderColor: primaryColor, 
                       entryRadius: 3,
                       dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
                       borderWidth: 2,
                       ),
                   ],
                   radarBackgroundColor: Colors.transparent,
                   borderData: FlBorderData(show: false),
                   radarBorderData: const BorderSide(color: Colors.transparent),
                   titlePositionPercentageOffset: 0.1,
                   getTitle: (index, angle) {
                       return const RadarChartTitle(text: "");
                   },
                   tickCount: 3,
                   ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                   tickBorderData: const BorderSide(color: Color(0xFFE0E0E0)),
                   gridBorderData: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                   ),
               ),
           ),
           if (labels.length >= 4) ...[
             buildLabel(labels[0], values[0], Alignment.topCenter),
             buildLabel(labels[1], values[1], Alignment.centerRight),
             buildLabel(labels[2], values[2], Alignment.bottomCenter),
             buildLabel(labels[3], values[3], Alignment.centerLeft),
           ]
       ],
     ),
   );
 }
}
