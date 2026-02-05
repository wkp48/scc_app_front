
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../daily_checklist_modal.dart';

class ChecklistCollectionCard extends StatefulWidget {
  final Map<String, double> scores;
  final List<Map<String, dynamic>> details;
  final Map<String, dynamic>? userData; // Added for modify
  final VoidCallback? onEditSuccess; // Added for modify
  final String title;
  final bool hideEditButton; // [Added] 수정 버튼 숨김 여부
  final bool hideLeftBorder; // [Added] 왼쪽 테두리 숨김 여부
  final String? statusText; // [Added] Backend provided status
  final String? feedback; // [Added] Backend provided feedback
  final bool hideFeedback; // [Added] 피드백 섹션 숨김 여부
  final Widget? bottomWidget; // [Added] 하단에 추가할 위젯

  const ChecklistCollectionCard({
    Key? key,
    required this.scores,
    required this.details,
    this.userData,
    this.onEditSuccess,
    this.title = '오늘의 마음 점검',
    this.hideEditButton = false,
    this.hideLeftBorder = false,
    this.statusText,
    this.feedback,
    this.hideFeedback = false,
    this.bottomWidget, // [Added]
  }) : super(key: key);

  @override
  State<ChecklistCollectionCard> createState() => _ChecklistCollectionCardState();
}

class _ChecklistCollectionCardState extends State<ChecklistCollectionCard> {
  bool _isExpanded = false;
  bool _isFeedbackExpanded = false; // [Added] Feedback expansion state

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _openModifyModal() async {
    // Parse initial answers from details
    final Map<int, double> initialAnswers = {};
    for (var item in widget.details) {
      if (item['id'] != null && item['score'] != null) {
        // detail['score'] is the raw user input (0-10)
        initialAnswers[item['id'] as int] = (item['score'] as num).toDouble();
      }
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyChecklistModal(
        userData: widget.userData!, 
        initialAnswers: initialAnswers,
      ),
    );

    if (result == true) {
      if (widget.onEditSuccess != null) widget.onEditSuccess!();
    }
  }


  Map<String, dynamic> _getStatus(double average) {
    // [Modified] Use Backend Status if available
    if (widget.statusText != null && widget.statusText!.isNotEmpty) {
       switch(widget.statusText) {
         case '안정유지 상태':
           return {'text': '안정유지 상태', 'color': const Color(0xFF4CAF50), 'icon': Icons.sentiment_satisfied_rounded};
         case '회복노력 상태':
           return {'text': '회복노력 상태', 'color': const Color(0xFF2196F3), 'icon': Icons.sentiment_neutral_rounded}; // Blue for Effort
         case '주의 상태':
           return {'text': '주의 상태', 'color': const Color(0xFFFF9800), 'icon': Icons.warning_rounded};
         case '위험 상태':
           return {'text': '위험 상태', 'color': const Color(0xFFF44336), 'icon': Icons.error_rounded};
         default:
           // Fallback default
       }
    }

    if (average >= 7.6) {
      return {
        'text': '좋음', 
        'color': const Color(0xFF52C41A), 
        'icon': Icons.sentiment_very_satisfied_rounded
      };
    } else if (average >= 5.1) {
      return {
        'text': '중간', 
        'color': const Color(0xFFFAAD14), 
        'icon': Icons.sentiment_satisfied_rounded
      };
    } else if (average >= 2.6) {
      return {
        'text': '주의', 
        'color': const Color(0xFFFF4D4F), 
        'icon': Icons.sentiment_dissatisfied_rounded
      };
    } else {
      return {
        'text': '나쁨', 
        'color': const Color(0xFFD32F2F), 
        'icon': Icons.sentiment_very_dissatisfied_rounded
      };
    }
  }


  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C72EB); // Indigo
    
    // Calculate Average
    double average = 0;
    if (widget.scores.isNotEmpty) {
      double sum = widget.scores.values.fold(0, (p, c) => p + c);
      average = sum / widget.scores.length;
    }
    
    final status = _getStatus(average);
    final statusColor = status['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: widget.hideLeftBorder 
            ? null 
            : const Border(left: BorderSide(color: primaryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section (Always visible)
          GestureDetector(
            onTap: _toggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // [수정하기] 버튼
                          if (widget.userData != null && !widget.hideEditButton) 
                            InkWell(
                              onTap: _openModifyModal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.transparent,
                                ),
                                child: const Text(
                                  '수정하기',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),

                          // "상세내역" Badge - Toggles expansion
                          GestureDetector(
                            onTap: _toggleExpand,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: _isExpanded ? primaryColor.withOpacity(0.1) : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _isExpanded ? '접기' : '보러가기', 
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: _isExpanded ? primaryColor : Colors.grey, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: _isExpanded ? primaryColor : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Dynamic Status Row
                      Row(
                        children: [
                          Icon(status['icon'], color: statusColor, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            status['text'],
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${average.toStringAsFixed(1)}점)',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),


          
          // Expanded Section
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity), // Collapsed state
            secondChild: Column(
              children: [
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 24),
                
                // Graph
                _buildGraph(),
                
                const SizedBox(height: 24),
                  
                // [Added] Feedback Section (Expandable)
                if (!widget.hideFeedback && widget.feedback != null && widget.feedback!.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final parts = widget.feedback!.split('\n\n');
                      final firstLine = parts.isNotEmpty ? parts[0] : '';
                      final body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';

                      // Title is the Status Name (e.g. "위험 상태")
                      // Subtitle is the first line of feedback (e.g. "회복을 방해하는...")
                      String displayTitle = status['text'] ?? '';
                      String displaySubtitle = firstLine;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _isFeedbackExpanded = !_isFeedbackExpanded;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: status['color'].withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _isFeedbackExpanded 
                                    ? status['color'].withOpacity(0.3) 
                                    : Colors.transparent
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: status['color'].withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.psychology_rounded,
                                      color: status['color'],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Title Group
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "종합 피드백",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9E9E9E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          displayTitle,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: status['color'],
                                          ),
                                        ),
                                        if (displaySubtitle.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            displaySubtitle,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF212121), // Changed to black
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Arrow
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Icon(
                                      _isFeedbackExpanded 
                                        ? Icons.keyboard_arrow_up_rounded 
                                        : Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Expanded Content
                              if (_isFeedbackExpanded && body.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Divider(height: 1, color: Color(0x1A000000)),
                                const SizedBox(height: 20),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Color(0xFF424242),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 32),
                ],

                // Detailed Feedback Section
                if (!widget.hideFeedback && widget.scores != null) ...[
                   _buildDetailedFeedback(),
                   const SizedBox(height: 24),
                ],
                
                // Details List removed as per request
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
          
          if (widget.bottomWidget != null) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            widget.bottomWidget!,
          ],
        ],
      ),
    );
  }

  // State for detailed category selection
  String _selectedDetailCategory = '신체 지표';

  final Map<String, Map<String, String>> _detailFeedbacks = {
    '신체 지표': {
      '위험': '몸이 매우 무겁고 지쳐계신 듯 해요~ 수면 및 신체활동 부족은 전반적인 에너지 저하와 감정 조절에 영향을 미칠 수 있습니다. 안정적인 회복을 위해 짧은 산책과 적당한 수면시간 확보를 위한 노력이 필요합니다.',
      '주의': '신체 리듬을 찾으려는 노력이 생각보다 쉽지 않게 느껴질 수 있습니다. 신체적 활력은 회복에 매우 중요한 요소라는 걸 기억하고 숙면할 수 있는 환경을 조성하고, 조금씩 신체활동 시간을 늘려나가면 어떨까요?',
      '회복 노력': '안정적인 수면과 신체활동을 위한 노력이 지속되고 있습니다. 이러한 노력은 스트레스와 충동에 대한 대처 능력을 높이는 데 도움이 됩니다. 안정유지 상태 도달을 위해 조금만 더 노력해 주세요~',
      '안정유지': '건강한 수면과 신체활동을 실천하고 계시는군요! 꾸준한 자기관리는 회복에도 긍정적 영향을 미치고 있다는 사실을 잊지 말고 지금처럼 자기 돌봄을 소중히 이어가 주세요~',
    },
    '정서 지표': {
      '위험': '오늘 많이 지치고 힘든 하루였군요! 금단증상으로 인해 작은 일에도 예민하게 반응하거나, 답답함과 무료함을 느낄 수 있습니다. 감정을 억누르기보다 잠시 내 감정을 들여다보면 어떨까요?',
      '주의': '감정이 다소 불안정하거나 표현이 과했을 수 있어요. 스스로에게 ‘그럴 수 있지, 괜찮아’라고 말해주세요. 회복은 감정을 잘 다루는 연습에서 시작됩니다. 잠시 나만의 시간을 가져보면 어떨까요?',
      '회복 노력': '감정을 자각하고 다루는 방식이 조금씩 자리 잡는 모습이에요. 불편한 감정이 있어도 흔들리지 않고 나를 지키려는 태도는 회복의 핵심입니다. 오늘 하루, 내 감정을 존중하고 돌보려 한 자신을 칭찬해 주세요.',
      '안정유지': '정서적으로 안정된 오늘을 보내고 계시는군요. 평온한 마음으로 회복을 더 깊이 들여다 볼 수 있는 기회가 될 것 같아요. 지금처럼 감정의 흐름에 귀 기울이며 자기돌봄을 지속해 주세요!',
    },
    '사고 지표': {
      '위험': '현실적 고통에서 벗어나고 싶다는 강렬한 생각은 도박 충동으로 이어질 수 있는 위험신호로 볼 수 있습니다. 조급한 생각들이 오히려 회복을 더디게 한다는 사실을 기억해 주세요~ 차분하게 호흡하는 것만으로도 일상 활동에 집중하는 데 도움이 됩니다. 지금 바로 실천해 보면 어떨까요?',
      '주의': '집중이 잘 안되거나 현실 회피적인 생각을 종종 할 수 있어요. 이런 생각을 차분하게 종이에 적어본다면, 자신의 생각이 행동에 미치는 영향에 대해 이해하는 데 도움이 될 수 있습니다. 지금 바로 실천해 보면 어떨까요?',
      '회복 노력': '일상생활에 어느 정도 집중이 가능하고, 회피적 사고도 이전보다 많이 개선되고 있습니다. 자기 생각을 잘 인식하고 조절해 보려는 노력은 안정적인 회복의 밑거름이 된다는 사실을 기억해 주세요~ 지금처럼 일상의 작은 실천을 지속해 주세요~',
      '안정유지': '일상 활동에 대한 집중력과 사고 조절 능력이 안정적으로 유지되고 있습니다. 이런 마음의 중심 잡기가 지속되어 내적 자기통제력이 잘 작동할 수 있도록 자신만의 좋은 습관을 꾸준히 이어가 주세요!',
    },
    '대인관계 지표': {
      '위험': '대인관계에서 불편함이나 단절감을 강하게 느끼셨던 하루였을 수 있어요. 관계가 고립되었을 때, 도박 행동으로 이어지기도 합니다. 내 상황을 마음 터놓고 대화할 수 있는 안전한 대상이나 상담사와 연락해보면 어떨까요? 늘 혼자가 아니라는 사실을 기억해 주세요.',
      '주의': '대인관계에서 다소 긴장감이나 거리감을 느끼셨을 수 있어요. 회복 과정에서 관계에 대한 불안이나 방어적인 마음은 매우 자연스러운 반응입니다. 가까운 사람과 짧은 인사나 메시지로 소통을 시도해 보는 것도 좋은 시작이 될 수 있어요.',
      '회복 노력': '다른 사람과 소통하고 관계를 유지하려는 노력이 보입니다. 관계에서의 어려움을 인식하면서도 피하지 않고 마주하려는 태도는 큰 용기입니다. 이런 노력이 쌓여 자신이 원하는 관계 회복으로 이어질 거에요!',
      '안정유지': '대인관계에서 따뜻한 소통이나 편안함을 느끼고 계시네요. 이러한 긍정적인 경험은 정서 안정뿐 아니라 회복 동기 유지에도 도움을 줍니다. 지금처럼 나를 지지해주는 사람들과의 연결을 잘 이어가 주세요!',
    },
  };

  Widget _buildDetailedFeedback() {
    final categories = ['신체 지표', '정서 지표', '사고 지표', '대인관계 지표'];
    
    // Get score for selected category
    // widget.scores values are Averages (0-10). Total score is Average * 2 (0-20).
    double averageScore = 0;
    if (widget.scores != null && widget.scores!.containsKey(_selectedDetailCategory)) {
        // Handle both int and double just in case
        averageScore = (widget.scores![_selectedDetailCategory] as num).toDouble();
    }
    int totalScore = (averageScore * 2).round();

    // Determine Status
    String statusKey = '위험';
    Color statusColor = const Color(0xffFF5252);
    String scoreText = '(7점 이하)';

    if (totalScore >= 17) {
      statusKey = '안정유지';
      statusColor = const Color(0xff4CAF50);
      scoreText = '(17~20점)';
    } else if (totalScore >= 13) {
      statusKey = '회복 노력';
      statusColor = const Color(0xff2196F3);
      scoreText = '(13~16점)';
    } else if (totalScore >= 8) {
      statusKey = '주의';
      statusColor = const Color(0xffFF9800);
      scoreText = '(8~12점)';
    } else {
      statusKey = '위험';
      statusColor = const Color(0xffFF5252);
      scoreText = '(7점 이하)';
    }
    
    // Get Feedback Text
    String feedbackText = _detailFeedbacks[_selectedDetailCategory]?[statusKey] ?? '피드백 정보를 불러올 수 없습니다.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
            "영역별 상세 피드백",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
            ),
            ),
            const SizedBox(height: 16),
            
            // Category Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedDetailCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDetailCategory = cat;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF5C72EB) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF5C72EB) : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Content Card
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
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
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(
                                    _selectedDetailCategory,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                    ),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                        '$statusKey 상태',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            "총 $totalScore점",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                            ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                            feedbackText,
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Color(0xFF424242),
                            ),
                        ),
                    ],
                ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraph() {
     // Categories should match the backend
    final List<String> categories = ['신체', '대인관계', '사고', '정서'];
    
    // Safety check for empty scores
    if (widget.scores.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('데이터가 없습니다.')));
    }

    final List<double> values = [
      widget.scores['신체 지표'] ?? 0.0,
      widget.scores['대인관계 지표'] ?? 0.0,
      widget.scores['사고 지표'] ?? 0.0,
      widget.scores['정서 지표'] ?? 0.0,
    ];
    
    // Indigo Theme Color
    const Color primaryColor = Color(0xFF5C72EB); 

    Widget buildLabel(String categoryName, Alignment alignment) {
        final fullCategoryName = '$categoryName 지표';
        // [Modified] hideFeedback이 true이면 선택 효과를 표시하지 않음
        final isSelected = !widget.hideFeedback && _selectedDetailCategory == fullCategoryName;
        
        double averageScore = 0;
        if (widget.scores != null && widget.scores!.containsKey(fullCategoryName)) {
            averageScore = (widget.scores![fullCategoryName] as num).toDouble();
        }
        int totalScore = (averageScore * 2).round();
        
        String status = '위험';
        Color statusColor = const Color(0xffFF5252);

        if (totalScore >= 17) {
            status = '안정유지';
            statusColor = const Color(0xff4CAF50);
        } else if (totalScore >= 13) {
            status = '회복노력'; 
            statusColor = const Color(0xff2196F3);
        } else if (totalScore >= 8) {
            status = '주의';
            statusColor = const Color(0xffFF9800);
        } else {
            status = '위험';
            statusColor = const Color(0xffFF5252);
        }

        return Align(
            alignment: alignment,
            child: Container(
                decoration: isSelected ? BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    border: Border.all(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                        BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                        )
                    ]
                ) : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                        children: [
                            TextSpan(
                                text: '$categoryName\n',
                                style: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                ),
                            ),
                            TextSpan(
                                text: '($status)',
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    return SizedBox(
      height: 300,
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
                        dataEntries: List.generate(categories.length, (index) => const RadarEntry(value: 10)),
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
            // Manual Labels matching standard fl_chart order (Top, Right, Bottom, Left)
            buildLabel(categories[0], Alignment.topCenter),
            buildLabel(categories[1], Alignment.centerRight),
            buildLabel(categories[2], Alignment.bottomCenter),
            buildLabel(categories[3], Alignment.centerLeft),
        ],
      ),
    );
  }
}
