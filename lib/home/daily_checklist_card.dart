import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import 'daily_checklist_modal.dart';
import 'widgets/checklist_collection_card.dart';
import 'widgets/recovery_trend_card.dart'; // [Added]

class DailyChecklistCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback? onChecklistCompleted;
  final String? targetDate; // YYYY-MM-DD
  final String? customTitle; // [Added] 커스텀 타이틀 지원
  final bool forceResultOnly; // [Added] 결과만 보기 모드 (작성 불가)
  final bool hideIfSubmitted; // [Added] 제출 완료 시 숨김 모드
  final bool hideFeedback; // [Added] 피드백 숨김 모드
  final bool showRecoveryTrend; // [Added] 회복 추이 그래프 표시 여부
  final String checklistType; // [Added] default 'PATIENT'
  final bool hideLeftBorder; // [Added]
  final bool hideExpandButton; // [Added]

  const DailyChecklistCard({
    Key? key,
    required this.userData,
    this.onChecklistCompleted,
    this.targetDate,
    this.customTitle,
    this.forceResultOnly = false,
    this.hideIfSubmitted = false,
    this.hideFeedback = false,
    this.showRecoveryTrend = false,
    this.checklistType = 'PATIENT', // Default
    this.hideLeftBorder = false, // Default
    this.hideExpandButton = false, // Default
  }) : super(key: key);

  @override
  State<DailyChecklistCard> createState() => DailyChecklistCardState();
}

class DailyChecklistCardState extends State<DailyChecklistCard> {
  bool _isLoading = true;
  bool _isSubmitted = false;

  Map<String, double> _scores = {};
  List<Map<String, dynamic>> _details = [];
  String _status = ""; // [Added]
  String _feedback = ""; // [Added]

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  @override
  void didUpdateWidget(DailyChecklistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetDate != oldWidget.targetDate) {
      _fetchSummary();
    }
  }

  Future<void> _fetchSummary() async {
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    final result = await ApiService.getChecklistSummary(uid, date: widget.targetDate);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'];
          _isSubmitted = data['submitted'] ?? false;
          if (_isSubmitted) {
             if (data['scores'] != null) {
               final scoresMap = data['scores'] as Map<String, dynamic>;
               _scores = scoresMap.map((key, value) => MapEntry(key, (value is num) ? value.toDouble() : 0.0));
             }
             if (data['details'] != null) {
               _details = List<Map<String, dynamic>>.from(data['details']);
             }
             _status = data['status'] ?? "";
             _feedback = data['feedback'] ?? "";
          } else {
             _scores = {};
             _details = [];
             _status = "";
             _feedback = "";
          }
        }
      });
    }
  }

  String _getTitle() {
    if (widget.customTitle != null) return widget.customTitle!;
    if (widget.targetDate == null) return '오늘의 마음 상태';
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    
    if (widget.targetDate == todayStr) {
      return '오늘의 마음 상태';
    } else {
      try {
        final parts = widget.targetDate!.split('-');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return '$month월 $day일 마음 상태';
        }
      } catch (e) {
      }
      return '그날의 마음 상태';
    }
  }
  
  // Public method to refresh the card
  Future<void> refresh() => _fetchSummary();

  void _openChecklistModal() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyChecklistModal(
        userData: widget.userData,
        checklistType: widget.checklistType, // [Modified] Pass type
      ),
    );

    if (result == true) {
      if (widget.onChecklistCompleted != null) widget.onChecklistCompleted!();
      _fetchSummary();
    }
  }

  String _getSubtitle() {
    if (widget.targetDate == null) return '나의 마음을 점검해보세요';
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    
    if (widget.targetDate == todayStr) {
      return '나의 마음을 점검해보세요';
    }
    return '작성된 체크리스트가 없습니다.';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C72EB);

    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // [Added] 제출 완료 시 숨김 로직
    if (widget.hideIfSubmitted && _isSubmitted) {
      return const SizedBox.shrink();
    }

    // Internal content builder to avoid code duplication if possible, 
    // but structure is different for Submitted vs Not Submitted.
    // We need to inject graph at bottom of both cases if requested?
    // User requested "inside My Current Status".
    // If submitted -> ChecklistCollectionCard.
    // If not submitted -> Container with "Start Button".
    
    // ChecklistCollectionCard doesn't support children injection easily unless modified.
    // However, DailyChecklistCard returns EITHER ChecklistCollectionCard OR Container.
    // To embed, we might need to wrap the result in a Column and append the graph, 
    // OR modify ChecklistCollectionCard to accept a child.
    // Let's wrap in Container/Column style similar to how it looks now.
    
    // BUT, ChecklistCollectionCard has its own decoration.
    // If we put graph BELOW it, it's outside "My Current Status" visual card?
    // User said "inside".
    // If ChecklistCollectionCard is the card, we should modify it or wrap it.
    // Actually, `DailyChecklistCard` *IS* the card wrapper when not submitted.
    // When submitted, `ChecklistCollectionCard` *IS* the card.
    
    // Let's append the graph below the main content but inside the visual boundary?
    // `ChecklistCollectionCard` handles its own decoration. 
    // If we want it INSIDE, we must pass it into `ChecklistCollectionCard`.
    // OR we can make `DailyChecklistCard` render a unified Container and put content inside.
    // Given the constraints and existing code, let's wrap the output in a Column 
    // if we can't easily inject. 
    // Wait, `ChecklistCollectionCard` is a separate widget. 
    // Let's modify `ChecklistCollectionCard` to accept a `bottomWidget`.
    // Or simpler: Just put it below `ChecklistCollectionCard` with keeping visible separation or merging?
    // User said "design is same".
    
    // Actually, simply appending `RecoveryTrendCard(isEmbedded: true)` 
    // adjacent to the main content might be what "inside" implies structurally 
    // but visually it might look like two listed items if the first one has a border.
    
    // Let's assume the user wants it visually integrated. 
    // `ChecklistCollectionCard` has `Container` with `BoxDecoration`.
    // If we want to add something *inside* that container, we must modify `ChecklistCollectionCard`.
    
    // Modification: Pass `footer` widget to `ChecklistCollectionCard`.
    
    if (_isSubmitted) {
      return ChecklistCollectionCard(
          scores: _scores, 
          details: _details,
          userData: widget.userData,
          onEditSuccess: () {
            _fetchSummary();
            widget.onChecklistCompleted?.call();
          },
          title: _getTitle(),
          hideEditButton: widget.forceResultOnly, 
          hideLeftBorder: widget.hideLeftBorder || widget.forceResultOnly,
          statusText: _status,
          feedback: _feedback, 
          hideFeedback: widget.hideFeedback,
          hideExpandButton: widget.hideExpandButton,
          // Inject Graph here? ChecklistCollectionCard needs update.
          // Let's update ChecklistCollectionCard locally or pass a builder?
          // Adding a `bottomWidget` parameter to `ChecklistCollectionCard` seems best.
           bottomWidget: widget.showRecoveryTrend 
              ? RecoveryTrendCard(
                  userData: widget.userData, 
                  isEmbedded: true,
                  checklistType: widget.checklistType, // [Modified] Pass type
                )
              : null,
          checklistType: widget.checklistType, // [Modified] Pass type
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      if (!widget.forceResultOnly) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getSubtitle(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),

            if (_isToday() && !widget.forceResultOnly) ...[
              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildStartButton(primaryColor),
              ),
            ] else if (widget.forceResultOnly && !_isSubmitted) ...[
              const SizedBox(height: 24),
              const Text(
                '데이터가 없습니다.',
                 style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ] else ...[
               const SizedBox(height: 8),
            ],
            
            // [Added] Graph for Not Submitted State
            if (widget.showRecoveryTrend) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              RecoveryTrendCard(
                userData: widget.userData, 
                isEmbedded: true,
                checklistType: widget.checklistType, // [Modified] Pass type
              ),
            ]
          ],
        ),
      );
    }
  }
  
  bool _isToday() {
    if (widget.targetDate == null) return true;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    return widget.targetDate == todayStr;
  }

  Widget _buildStartButton(Color primaryColor) {
    return Column(
      children: [
        const Text(
          '아직 오늘의 체크리스트를\n작성하지 않으셨네요!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF555555),
            height: 1.5
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _openChecklistModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text('오늘의 체크리스트 작성하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
