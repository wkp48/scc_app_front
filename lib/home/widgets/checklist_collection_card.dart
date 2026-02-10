
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
  final String checklistType; // [Added] 'PATIENT' or 'FAMILY'

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
    this.bottomWidget,
    this.checklistType = 'PATIENT',
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
        checklistType: widget.checklistType,
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

                      const SizedBox(height: 12),
                      // [Modified] 3-Segment Status Bar instead of text/points
                      Builder(
                        builder: (context) {
                          int statusIndex = 0; // 0: 주의, 1: 성장노력, 2: 안정유지
                          
                          if (widget.checklistType == 'FAMILY') {
                            final List<String> groupCategories = _selectedFamilyGroup == 'ROLE' 
                                ? ['재정관리', '통제욕구', '건강한대화', '건강한피드백']
                                : ['신체지표', '정서지표', '사고지표', '대인관계지표'];
                            
                            double total = 0;
                            double minScore = 10.0;
                            for (var cat in groupCategories) {
                              double s = widget.scores[cat] ?? 0.0;
                              total += s;
                              if (s < minScore) minScore = s;
                            }

                            if (total >= 34 && minScore >= 8.0) statusIndex = 2;
                            else if (total >= 24 && minScore >= 5.0) statusIndex = 1;
                            else statusIndex = 0;
                          } else {
                            // Patient logic
                            if (average >= 7.6) statusIndex = 2;
                            else if (average >= 5.1) statusIndex = 1;
                            else statusIndex = 0;
                          }

                          // Colors matching the request
                          final List<Color> statusColors = [
                            const Color(0xFFFF9800), // 주의: Orange
                            const Color(0xFF2196F3), // 성장 노력: Blue
                            const Color(0xFF4CAF50), // 안정 유지: Green
                          ];
                          final List<String> statusLabels = ['주의', '성장 노력', '안정 유지'];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Segmented Bar
                              Row(
                                children: List.generate(3, (index) {
                                  final isActive = index == statusIndex;
                                  return Expanded(
                                    child: Container(
                                      height: 6,
                                      margin: EdgeInsets.only(
                                        right: index < 2 ? 4 : 0,
                                        left: index > 0 ? 4 : 0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive ? statusColors[index] : const Color(0xFFEEEEEE),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              // Labels
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(3, (index) {
                                  final isActive = index == statusIndex;
                                  return Text(
                                    statusLabels[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      color: isActive ? statusColors[index] : const Color(0xFF9E9E9E),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          );
                        }
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
                      String displayTitle = status['text'] ?? '';
                      String displaySubtitle = '';
                      String body = '';
                      Color sColor = status['color'];

                      if (widget.checklistType == 'FAMILY') {
                        final List<String> groupCategories = _selectedFamilyGroup == 'ROLE' 
                            ? ['재정관리', '통제욕구', '건강한대화', '건강한피드백']
                            : ['신체지표', '정서지표', '사고지표', '대인관계지표'];
                        
                        double total = 0;
                        double minScore = 10.0;
                        for (var cat in groupCategories) {
                          double s = widget.scores[cat] ?? 0.0;
                          total += s;
                          if (s < minScore) minScore = s;
                        }

                        String statusKey = '주의';
                        if (total >= 34 && minScore >= 8.0) {
                          statusKey = '안정유지';
                          sColor = const Color(0xff4CAF50);
                        } else if (total >= 24 && minScore >= 5.0) {
                          statusKey = '성장 노력';
                          sColor = const Color(0xff2196F3);
                        } else {
                          statusKey = '주의';
                          sColor = const Color(0xFFFF9800);
                        }

                        final familyInfo = _familyFeedbacks[_selectedFamilyGroup]?[statusKey];
                        displayTitle = familyInfo?['title'] ?? statusKey;
                        body = familyInfo?['feedback'] ?? '';
                      } else {
                        final parts = (widget.feedback ?? '').split('\n\n');
                        displaySubtitle = parts.isNotEmpty ? parts[0] : '';
                        body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
                      }

                      if (body.isEmpty && displaySubtitle.isEmpty) return const SizedBox.shrink();

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
                            color: sColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _isFeedbackExpanded 
                                    ? sColor.withOpacity(0.3) 
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
                                          color: sColor.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.psychology_rounded,
                                      color: sColor,
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
                                            color: sColor,
                                          ),
                                        ),
                                        if (displaySubtitle.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            displaySubtitle,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF212121), 
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
  String _selectedDetailCategory = '신체지표';

  final Map<String, Map<String, String>> _detailFeedbacks = {
    '신체지표': {
      '주의': '지금은 몸보다 마음이 더 지쳐 있을 수 있어요. 하지만 단 10분의 산책만으로도 내 감정과 생각이 훨씬 부드러워질 수 있습니다. 지금 이 자리에서 움직여 보는 것부터 시작해 보세요.',
      '성장 노력': '조금씩 몸을 움직여 보려는 시도가 있으셨군요! 중요한 건 자주 하는 것보다 ‘잊지 않고 나를 돌아보는 습관’을 만드는 거예요. 한 번의 실천이 나를 회복의 길로 다시 데려옵니다.',
      '안정유지': '지금은 몸을 돌보는 일상의 규칙이 자리를 잡아가고 있어요. 회복은 마음만이 아니라 몸에서부터 시작된다는 것을 기억하고, 이 흐름을 잘 이어나가 주세요.',
    },
    '정서지표': {
      '주의': '지금은 감정이 쌓여서 쉽게 무기력해지거나 분노가 앞설 수 있어요. 감정을 억누르기보다, 잠깐 멈추고 나의 마음을 들여다보는 시간이 필요합니다. 호흡부터 천천히 시작해보세요. 감정을 다룰 수 있다는 믿음이 회복의 시작이에요.',
      '성장 노력': '감정을 억누르지 않고, 천천히 들여다보려는 시도를 잘 이어가고 계세요. 완벽하지 않아도 괜찮아요. 중요한 건 내가 감정을 다룰 수 있다는 ‘경험’을 조금씩 쌓아가는 것입니다.',
      '안정유지': '감정을 건강하게 바라보고, 조절하고, 흘려보내는 힘이 잘 자리 잡아가고 있어요. 이 회복된 감정 리듬이 내 삶뿐만 아니라 가족 전체를 지켜주는 보호막이 됩니다. 지금의 마음 돌봄을 소중히 이어가 주세요.',
    },
    '사고지표': {
      '주의': '지금은 부정적인 생각이 마음을 지배할 수 있는 시기입니다. 그 생각이 ‘사실인지’ 아니면 ‘감정에 따른 해석인지’ 구분해보는 연습부터 시작해보세요. 생각은 감정처럼 흘러가고, 우리는 그것을 관찰할 수 있어요.',
      '성장 노력': '지금은 생각의 자동 반응에서 벗어나려는 중요한 시점입니다. 완벽히 바꾸려 하지 않아도 괜찮아요. 다르게 바라보려는 태도만으로도 사고의 흐름은 달라질 수 있습니다. ‘이건 내 생각일 뿐’이라는 문장을 기억해보세요.',
      '안정유지': '지금은 생각에 휘둘리기보다 스스로 선택하는 힘이 커진 상태입니다. 사고의 균형은 감정의 균형으로, 결국 관계의 균형으로 이어집니다. 지금처럼 나의 생각을 들여다보고, 조율하는 힘을 잘 이어가 주세요.',
    },
    '대인관계지표': {
      '주의': '지금은 너무 힘이들어, 관계를 피하거나 닫아둘 수 있어요. 그러나 회복은 연결 속에서 이루어 집니다. 작은 안부 인사, 짧은 전화 한 통이 회복의 문을 여는 시작이 될 수 있어요.',
      '성장 노력': '이제 관계를 조금씩 회복하려는 시도가 시작되고 있어요. 완벽한 관계보다, ‘그냥 함께하는 시간’ 자체가 큰 의미입니다. 너무 많은 걸 기대하기보다 ‘연결감’ 자체를 느끼는 데 집중해보세요.',
      '안정유지': '지금은 관계 속에서 나를 지키면서도 따뜻하게 연결되어 있으시군요! 혼자가 아니라는 경험은 회복을 지탱하는 큰 자원이 됩니다. 지금의 관계 흐름을 소중히 지켜가 주세요.',
    },
    // Family Categories Placeholders (Need specific texts later)
    '재정관리':{
      '주의': '지금은 재정 지원을 반복하기 쉬운 시기지만, 이는 회복에 도움이 되기보다 도박을 지속시킬 수 있습니다. 회복은 고통을 대신 해주는 것이 아니라, 당사자가 스스로 마주할 수 있도록 돕는 과정입니다. 조금 힘들더라도 재정관리 원칙을 세우고 지켜주세요.',
      '성장 노력': '돈을 직접 주는 건 피하지만 여전히 감정에 따라 흔들릴 수 있는 단계입니다. 지금은 도박자가 책임감을 가질 수 있도록 재정 경계를 연습해 나가야 할 시기이며, ‘돈’이 강한 갈망을 자극할 수 있다는 점을 기억해 주세요.',
      '안정유지': '재정관리를 잘 유지하고 계시군요! 감정에 흔들리지 않고 재정 원칙을 지키며, 회복자에게 경제적 자립의 방향을 잘 전달하고 있습니다.',
    },
    '통제욕구':{
      '주의': '도박중독 당사자를 통제하고 싶은 마음이 여전히 크게 느껴지실 수 있어요. 그럴수록 내 불안이 통제 욕구로 이어진다는 점을 기억해 주세요. 통제하거나 감시하는 것은 가족의 몫이 아닙니다. ',
      '성장 노력': '지금은 관계를 회복하고자 시도하는 변화의 과정입니다. ‘지켜보기’와 ‘개입하기’의 균형을 잡는 연습이 필요해요. 감정을 조절하고, 회복자의 책임을 존중하며 함께 걸어가는 법을 익혀보세요.',
      '안정유지': '회복의 기반이 안정된 상태예요. 중독자와의 신뢰 관계를 유지하며, 감정에 휘둘리지 않고 건강한 거리두기를 실천하고 계십니다. 지금처럼 ‘내 감정도 돌보며, 상대를 존중하는 태도’를 지속해 주세요.',
    },
    '건강한대화':{
       '주의': '지금은 대화를 통해 회복을 돕기보다, 감정이 앞서며 관계가 단절될 수 있는 시기입니다. 대화는 ‘설득’이나 ‘통제’가 아닌, 서로를 이해하기 위한 연결 통로입니다. 나의 감정부터 알아차리는 연습을 시작해 보세요.',
       '성장 노력': '지금은 건강한 대화를 연습해 나가는 시기로, 완벽하지 않아도 괜찮습니다. 중요한 건 말을 많이 하기보다 진심으로 들어주는 태도이며, 실수해도 감정을 함께 다루려는 노력이 회복에 큰 도움이 됩니다.',
       '안정유지': '지금은 서로를 존중하며 편안하게 대화할 수 있는 단계로, 따뜻한 소통이 회복자의 신뢰를 더 깊게 만들어줍니다. 이 흐름을 잘 이어가 주세요.',
    },
    '건강한피드백':{
       '주의': '지금은 도박자의 노력이 눈에 잘 들어오지 않을 수 있습니다. 그러나 작은 변화라도 ‘지켜봐주고, 알아봐주는 사람’이 있다는 느낌이 회복의 큰 힘이 됩니다. 결과보다 과정을 살펴보는 시선을 조금씩 연습해 보세요.',
       '성장 노력': '회복자의 변화에 관심을 갖고 반응하려는 연습이 시작되셨군요! 완벽하지 않아도 괜찮아요. 진심 어린 인정은 말 한마디로도 충분합니다. 지금의 시도 자체가 매우 의미 있습니다.',
       '안정유지': '회복자의 변화에 진심으로 반응하며 신뢰를 쌓아가는 과정이 자리잡아 가고 있습니다. 지금의 따뜻한 응원이 계속 이어질 수 있도록 자신도 함께 돌봐야 한다는 사실을 잊지 마세요.',
    },
  };

  final Map<String, Map<String, Map<String, String>>> _familyFeedbacks = {
    'ROLE': {
      '주의': {
        'title': '주의 상태 (23점 이하)',
        'feedback': '지금은 중독자와의 관계에서 많이 지치고, 혼란스러운 감정이 반복될 수 있어요. 내가 뭘 해도 바뀌지 않는다는 무력감이나 과도한 책임감이 교차할 수 있습니다. 이럴수록 중요한 건, 중독자를 바꾸겠다라는 생각보다 내가 변화 할 수 있는 부분을 찾아 실천해 나가는 겁니다. 낙담하지 마시고 할 수 있는 것을 시작해 주세요.'
      },
      '성장 노력': {
        'title': '성장 노력 상태 (24~33점)',
        'feedback': '가족 안에서 건강한 역할을 회복하려는 노력과 변화가 조금씩 시작되고 있어요. 때때로 중독자를 통제하고 싶은 마음이 올라울 수 있지만, 그럴 때마다 자신을 돌아보려는 태도 자체가 회복에 큰 힘이 됩니다. 지금처럼 건강한 피드백과 감정 조절 연습을 이어간다면, 서로 간의 관계도 한결 더 편안하고 따뜻하게 변화될 수 있어요.'
      },
      '안정유지': {
        'title': '안정유지 상태 (34~40점)',
        'feedback': '중독자의 회복 과정에 과도하게 휘둘리지 않고, 스스로 건강한 거리와 태도를 잘 유지하고 계시네요. 지지와 회복에 도움이 되는 피드백도 따뜻하게 전달할 수 있는 능력이 자리잡아가고 있어요. 지금처럼 가족으로서의 경계, 표현, 돌봄의 균형을 잘 이어가 주세요.'
      },
    },
    'RECOVERY': {
      '주의': {
        'title': '주의 상태 (23점 이하)',
        'feedback': '몸도 마음도 지쳐 있고, 혼자 버텨야 한다는 고립감과 긴장이 쌓였을 수 있어요. 감정이 예민하거나 부정적인 생각이 반복되면, 자기 돌봄보다 중독자의 문제에 다시 매몰될 위험이 커집니다. 지금은 내 감정부터 살피고, 일상의 흐름을 회복하는 것이 가장 중요합니다.'
      },
      '성장 노력': {
        'title': '성장 노력 상태 (24~33점)',
        'feedback': '감정이나 생각을 알아차리고 조절해보려는 노력과 꾸준한 일상 실천이 조금씩 자리 잡아 가고 있어요. 산책이나 누군가와 대화를 시도하는 등 일상의 회복을 위한 꾸준한 노력이 내 삶을 변화시킬 수 있는 밑거름이 됩니다. 아직 마음이 흔들릴 때도 있지만, 내 삶을 되찾으려는 회복의 힘이 서서히 자라나고 있는 중이에요.'
      },
      '안정유지': {
        'title': '안정유지 상태 (34~40점)',
        'feedback': '지금의 흐름 속에서 스스로를 잘 돌보고, 감정을 조절하며, 관계도 안정적으로 이어가 계시네요. 회복은 중독자의 상태와 무관하게, \'내 삶의 균형\'을 지켜가는 힘에서 시작됩니다. 지금처럼 나에게 맞는 돌봄과 건강한 관계 맺기를 꾸준히 이어가 주세요. 그 리듬이 곧 회복의 기반이 되어 줄 거예요.'
      },
    }
  };

  Widget _buildDetailedFeedback() {
    final List<String> roleCategories = ['재정관리', '통제욕구', '건강한대화', '건강한피드백'];
    final List<String> recoveryCategories = ['신체지표', '정서지표', '사고지표', '대인관계지표'];
    
    List<String> categories;
    Color activeColor;

    if (widget.checklistType == 'FAMILY') {
      if (_selectedFamilyGroup == 'ROLE') {
        categories = roleCategories;
        activeColor = const Color(0xFF5C72EB); // Indigo for ROLE
      } else {
        categories = recoveryCategories;
        activeColor = const Color(0xFF4CAF50); // Green for RECOVERY
      }
    } else {
      categories = recoveryCategories;
      activeColor = const Color(0xFF5C72EB); // Indigo Default
    }
    
    // Ensure displayCategory is valid for the current category set
    String displayCategory = _selectedDetailCategory;
    if (!categories.contains(displayCategory)) {
      displayCategory = categories[0];
    }

    // widget.scores values are Averages (0-10). Total score is Average * 2 (0-20).
    double averageScore = 0;
    if (widget.scores != null && widget.scores!.containsKey(displayCategory)) {
        averageScore = (widget.scores![displayCategory] as num).toDouble();
    }
    int totalScore;
    String statusKey = '위험';
    Color statusColor = const Color(0xffFF5252);

    if (widget.checklistType == 'FAMILY') {
      totalScore = averageScore.round();
      if (totalScore >= 8) {
        statusKey = '안정유지';
        statusColor = const Color(0xff4CAF50);
      } else if (totalScore >= 5) {
        statusKey = '성장 노력';
        statusColor = const Color(0xff2196F3);
      } else {
        statusKey = '주의';
        statusColor = const Color(0xffFF9800);
      }
    } else {
      // Patient: 2 questions per category, max 20
      totalScore = (averageScore * 2).round();
      if (totalScore >= 17) {
        statusKey = '안정유지';
        statusColor = const Color(0xff4CAF50);
      } else if (totalScore >= 13) {
        statusKey = '회복 노력';
        statusColor = const Color(0xff2196F3);
      } else if (totalScore >= 8) {
        statusKey = '주의';
        statusColor = const Color(0xffFF9800);
      } else {
        statusKey = '위험';
        statusColor = const Color(0xffFF5252);
      }
    }
    
    // Get Feedback Text
    String feedbackText = _detailFeedbacks[displayCategory]?[statusKey] ?? '피드백 정보를 불러올 수 없습니다.';

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
                  final isSelected = displayCategory == cat;
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
                          color: isSelected ? activeColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? activeColor : Colors.grey[300]!,
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
                                    displayCategory,
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

  // State for family group selection
  String _selectedFamilyGroup = 'ROLE'; // 'ROLE' or 'RECOVERY'

  Widget _buildFamilyGroupToggle(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
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
      ),
    );
  }

  Widget _buildAreaCard(String label, String value, IconData icon, Color color) {
    final isSelected = _selectedFamilyGroup == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFamilyGroup = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
              size: 24
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraph() {
     // Categories should match the backend
    List<String> categories;
    List<String> displayCategories; // For graph labels (shortened)
    List<Alignment> alignments;

    final List<String> roleCategories = ['재정관리', '통제욕구', '건강한대화', '건강한피드백'];
    final List<String> recoveryCategories = ['신체지표', '정서지표', '사고지표', '대인관계지표'];

    if (widget.checklistType == 'FAMILY') {
        categories = _selectedFamilyGroup == 'ROLE' ? roleCategories : recoveryCategories;
        displayCategories = categories.map((c) {
           String label = c.replaceAll('지표', '').replaceAll('건강한', '');
           if (label == '대인관계') label = '대인';
           return label;
        }).toList();
        alignments = [
            Alignment.topCenter,
            Alignment.centerRight,
            Alignment.bottomCenter,
            Alignment.centerLeft,
        ];
    } else {
        categories = ['신체 지표', '대인관계 지표', '사고 지표', '정서 지표'];
        displayCategories = ['신체', '대인', '사고', '정서'];
        alignments = [
            Alignment.topCenter,
            Alignment.centerRight,
            Alignment.bottomCenter,
            Alignment.centerLeft,
        ];
    }
    
    // Safety check for empty scores
    if (widget.scores.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('데이터가 없습니다.')));
    }

    // Values for the selected 4 categories
    final List<double> values = categories.map((cat) => widget.scores[cat] ?? 0.0).toList();
    
    // Indigo Theme Color
    const Color primaryColor = Color(0xFF5C72EB); 

    Widget buildLabel(int index) {
        final categoryName = displayCategories[index];
        final alignment = alignments[index];
        final fullCategoryName = categories[index]; // Use full name for equality check
        
        // All axis labels in the 4-axis view should be visible
        const bool isSelectedGroup = true;

        final isSelectedDetail = !widget.hideFeedback && _selectedDetailCategory == fullCategoryName;
        
        double averageScore = widget.scores[fullCategoryName] ?? 0.0;
        int totalScore;
        String status = '위험';
        Color statusColor = const Color(0xffFF5252);

        if (widget.checklistType == 'FAMILY') {
          totalScore = averageScore.round();
          if (totalScore >= 8) {
            status = '안정유지';
            statusColor = const Color(0xff4CAF50);
          } else if (totalScore >= 5) {
            status = '성장 노력'; 
            statusColor = const Color(0xff2196F3);
          } else {
            status = '주의';
            statusColor = const Color(0xffFF9800);
          }
        } else {
          totalScore = (averageScore * 2).round();
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
        }

        return Align(
            alignment: alignment,
            child: Container(
                  decoration: isSelectedDetail ? BoxDecoration(
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
                              if (isSelectedGroup)
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

    return Column(
      children: [
        if (widget.checklistType == 'FAMILY') _buildFamilyGroupToggle(primaryColor),
        SizedBox(
          height: 320,
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
            // Manual Labels
            ...List.generate(categories.length, (index) => buildLabel(index)),
          ],
        ),
      ),
    ],
  );
}
}
