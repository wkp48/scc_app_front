import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../home/activity_record_modal.dart';
import '../home/activity_details_modal.dart';
import '../family/training/anxiety_history_screen.dart'; // Import for Emotion Diary
import '../utils/toast_utils.dart';

import 'package:intl/intl.dart';
import 'dart:math' as math;


import 'resolution_history_modal.dart';
import 'alarm_screen.dart';

class SelfDevelopmentScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? dashboardData;
  final VoidCallback? onRefresh; // 갱신 콜백 추가

  const SelfDevelopmentScreen({
    super.key, 
    required this.userData,
    this.dashboardData,
    this.onRefresh,
  });

  @override
  State<SelfDevelopmentScreen> createState() => _SelfDevelopmentScreenState();
}

class _SelfDevelopmentScreenState extends State<SelfDevelopmentScreen> {
  bool _isLoading = false;


  List<dynamic> _rewardPlans = [];
  String _currentResolution = ''; // Local state for immediate update

  // 자기보상 태그 관련 상태
  final Map<int, String> _milestoneTags = {
    100: '100일',
    200: '200일',
    300: '300일',
    365: '1주년',
    400: '400일',
    500: '500일',
    600: '600일',
    730: '2주년',
  };
  int? _selectedMilestoneDays;
  bool _isEditingReward = false;
  final TextEditingController _rewardContentController = TextEditingController();

  @override
  void dispose() {
    _rewardContentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentResolution = widget.dashboardData?['resolutionText'] ?? '나의 다짐을 적어보세요';

    _fetchRewardPlans();
  }

  @override
  void didUpdateWidget(SelfDevelopmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dashboardData?['resolutionText'] != oldWidget.dashboardData?['resolutionText']) {
      setState(() {
        _currentResolution = widget.dashboardData?['resolutionText'] ?? '나의 다짐을 적어보세요';
      });
    }
  }

  Future<void> _fetchRewardPlans() async {
    final response = await ApiService.getRewardPlans(widget.userData['uid']);
    if (mounted && response['success']) {
      setState(() {
        _rewardPlans = response['data'];
      });
      debugPrint('--- Fetched Reward Plans ---');
      for (var plan in _rewardPlans) {
        debugPrint('Plan: ${plan['targetDate']} -> ${plan['content']}');
      }
    }
  }





  Future<void> _togglePin(String activityType) async {
    final response = await ApiService.togglePinActivity(widget.userData['uid'], activityType);
    if (mounted) {
      if (response['success']) {
        final bool isPinned = response['isPinned'];
        ToastUtils.show(context, isPinned ? '홈 화면에 추가되었습니다' : '홈 화면에서 제거되었습니다');
        if (widget.onRefresh != null) widget.onRefresh!();
      } else {
        ToastUtils.show(context, '설정에 실패했습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 고정된 항목들 확인
    final List<dynamic> pinnedList = widget.dashboardData?['pinnedActivities'] ?? [];
    final Set<String> pinnedActivities = pinnedList.map((e) => e.toString()).toSet();

    return Stack(
      children: [
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {

              await _fetchRewardPlans();
              if (widget.onRefresh != null) widget.onRefresh!();
            },
            color: const Color(0xFFF8942E),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildResolutionCard(),
                  const SizedBox(height: 16),
                  

                  _buildDailyRecordCard(
                    id: 'GRATITUDE',
                    title: '감사 일기',
                    description: '오늘 감사한 일을 기록해보세요.',
                    icon: Icons.favorite_border,
                    iconColor: const Color(0xFFFF851B),
                    gradientColors: [const Color(0xFFFFF7E6), Colors.white],
                    buttonText: '작성하기',
                    isPinned: pinnedActivities.contains('GRATITUDE'),
                    onTap: () => ActivityRecordModal.show(context, widget.userData, 'GRATITUDE', onSaved: widget.onRefresh),
                  ),
                  const SizedBox(height: 16),
                  _buildDailyRecordCard(
                    id: 'WALK',
                    title: '일상 기록',
                    description: '나의 일상을 기록하며 마음을 정리해요.',
                    icon: Icons.wb_sunny_outlined,
                    iconColor: const Color(0xFF52C41A),
                    gradientColors: [const Color(0xFFF6FFED), Colors.white],
                    buttonText: '기록하기',
                    isPinned: pinnedActivities.contains('WALK'),
                    onTap: () => ActivityRecordModal.show(context, widget.userData, 'WALK', onSaved: widget.onRefresh),
                  ),
                  const SizedBox(height: 16),
                  _buildDailyRecordCard(
                    id: 'IMPULSE',
                    title: '충동 일지',
                    description: '충동이 들 때마다 기록을 남겨요.',
                    icon: Icons.flash_on,
                    iconColor: const Color(0xFFFF4D4F),
                    gradientColors: [const Color(0xFFFFF1F0), Colors.white],
                    buttonText: '작성하기',
                    isPinned: pinnedActivities.contains('IMPULSE'),
                    onTap: () => ActivityRecordModal.show(context, widget.userData, 'IMPULSE', onSaved: widget.onRefresh),
                  ),
                  const SizedBox(height: 16),
                  _buildDailyRecordCard(
                    id: 'POSITIVE_SELF',
                    title: '희망 리코딩',
                    description: '나를 위한 긍정의 한마디를 남겨보세요.',
                    icon: Icons.auto_awesome,
                    iconColor: const Color(0xFF722ED1),
                    gradientColors: [const Color(0xFFF9F0FF), Colors.white],
                    buttonText: '기록하기',
                    isPinned: pinnedActivities.contains('POSITIVE_SELF'),
                    onTap: () => ActivityRecordModal.show(context, widget.userData, 'POSITIVE_SELF', onSaved: widget.onRefresh),
                  ),

                  const SizedBox(height: 16),
                  
                  _buildDailyRecordCard(
                    id: 'EMOTION_DIARY',
                    title: '감정일기',
                    description: '오늘 하루 느꼈던 다양한 감정을\n기록하고 마음을 돌보는 시간',
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF13C2C2),
                    gradientColors: [const Color(0xFFE6FFFB), Colors.white], // Cyan for Emotion Diary
                    buttonText: '기록하기',
                    isPinned: false, // Emotion Diary might not support pinning yet or reuse logic
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => AnxietyHistoryScreen(userData: widget.userData)));
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  _buildAlarmCard(),
                  const SizedBox(height: 16),
                  _buildRewardPlanCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }



  Widget _buildResolutionCard() {
    final String resolution = _currentResolution;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C72EB), Color(0xFF7B91FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C72EB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '나의 다짐',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                   GestureDetector(
                    onTap: () => ResolutionHistoryModal.show(context, widget.userData),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.history, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            '히스토리',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditResolutionDialog(resolution),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$resolution"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditResolutionDialog(String currentResolution) {
    final TextEditingController controller = TextEditingController(text: currentResolution == '나의 다짐을 적어보세요' ? '' : currentResolution);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('나의 다짐 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '다짐을 입력해주세요',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ToastUtils.show(context, '다짐을 입력해주세요');
                return;
              }
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              final response = await ApiService.updateResolution(widget.userData['uid'], controller.text.trim());
              setState(() => _isLoading = false);
              
              if (response['success']) {
                ToastUtils.show(context, '다짐이 저장되었습니다');
                setState(() {
                  _currentResolution = controller.text.trim();
                });
                if (widget.onRefresh != null) widget.onRefresh!();
              } else {
                ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C72EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('저장하기'),
          ),
        ],
      ),
    );
  }

  DateTime _getResolutionDate() {
    // 1. 재시작일(Restart Date) 확인 - 있으면 마지막 재시작일을 기준일로 사용
    final List<dynamic>? restartDates = widget.dashboardData?['restartDates'];
    if (restartDates != null && restartDates.isNotEmpty) {
      try {
        final List<String> sortedDates = List<String>.from(restartDates.map((e) => e.toString()));
        sortedDates.sort(); // 오름차순 정렬 (가장 최근 날짜가 마지막)
        final lastRestart = sortedDates.last;
        final parsed = DateTime.tryParse(lastRestart);
        if (parsed != null) return parsed;
        return DateFormat('yyyy-MM-dd').parse(lastRestart);
      } catch (e) {
        debugPrint('Error parsing restart date: $e');
      }
    }

    // 2. 재시작일 없으면 기존 결심일(Resolution Date) 사용
    DateTime? startDate;
    final resDate = widget.dashboardData?['resolutionDate'];
    if (resDate != null) {
      final resDateStr = resDate.toString();
      if (resDateStr.contains('년')) {
        try {
          final dateParts = resDateStr.split(' ');
          if (dateParts.length >= 3) {
            final year = int.parse(dateParts[0].replaceAll('년', '').trim());
            final month = int.parse(dateParts[1].replaceAll('월', '').trim());
            final day = int.parse(dateParts[2].replaceAll('일', '').trim());
            startDate = DateTime(year, month, day);
          }
        } catch (e) {
          debugPrint('Error parsing resolution date (KR): $e');
        }
      } else {
        try {
          startDate = DateTime.tryParse(resDateStr);
        } catch (e) {
          debugPrint('Error parsing resolution date (ISO): $e');
        }
      }
    }
    
    final result = startDate ?? DateTime.now();
    // debugPrint('Resolved Base Date for Milestones: ${DateFormat('yyyy-MM-dd').format(result)}');
    return result;
  }

  Map<String, dynamic>? _getRewardPlanForDate(DateTime date, {int? milestoneDays}) {
    if (_rewardPlans.isEmpty) return null;
    
    // 1. 마일스톤 데이로 먼저 매칭 시도
    if (milestoneDays != null) {
      final plan = _rewardPlans.firstWhere(
        (p) => p['milestoneDays'] == milestoneDays,
        orElse: () => null,
      );
      if (plan != null) return plan;
    }

    // 2. 날짜 문자열로 매칭 시도 (하위 호환성)
    final String targetDateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      return _rewardPlans.firstWhere(
        (plan) => plan['targetDate'] == targetDateStr,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  void _onTagSelected(int days) {
    setState(() {
      if (_selectedMilestoneDays == days) {
        // 이미 선택된 태그를 다시 누르면 닫기 (선택 해제)
        _selectedMilestoneDays = null;
        _isEditingReward = false;
        _rewardContentController.clear();
      } else {
        _selectedMilestoneDays = days;
        final DateTime targetDate = _getResolutionDate().add(Duration(days: days));
        final existingPlan = _getRewardPlanForDate(targetDate, milestoneDays: days);

        if (existingPlan != null) {
          // 이미 내용이 있으면 읽기 모드
          _isEditingReward = false;
          _rewardContentController.text = existingPlan['content'] ?? '';
        } else {
          // 내용이 없으면 편집 모드 (입력창)
          _isEditingReward = true; 
          _rewardContentController.clear();
        }
      }
    });
  }

  Future<void> _saveRewardPlan() async {
    if (_selectedMilestoneDays == null) return;
    if (_rewardContentController.text.trim().isEmpty) {
      ToastUtils.show(context, '보상 내용을 입력해주세요');
      return;
    }

    final DateTime targetDate = _getResolutionDate().add(Duration(days: _selectedMilestoneDays!));
    final String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    setState(() => _isLoading = true);
    final response = await ApiService.saveRewardPlan(
      widget.userData['uid'], 
      dateStr, 
      _rewardContentController.text.trim(),
      milestoneDays: _selectedMilestoneDays,
    );
    
    if (response['success']) {
      await _fetchRewardPlans(); // 목록 갱신
      setState(() {
        _isLoading = false;
        _isEditingReward = false; // 저장 후 읽기 모드로 전환
      });
      ToastUtils.show(context, '저장되었습니다');
      if (widget.onRefresh != null) widget.onRefresh!();
    } else {
      setState(() => _isLoading = false);
      ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다');
    }
  }


  Widget _buildRewardPlanCard() {
    // 핀 고정 여부 확인
    final List<dynamic> pinnedList = widget.dashboardData?['pinnedActivities'] ?? [];
    final bool isPinned = pinnedList.contains('REWARD_PLAN');
    final DateTime resolutionDate = _getResolutionDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [const Color(0xFF1890FF).withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFF1890FF), size: 28),
                  // [Changed] 홈화면 추가 버튼 제거됨
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '자기보상 계획',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // 태그 목록 (Wrap)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _milestoneTags.entries.map((entry) {
                  final int days = entry.key;
                  final String label = entry.value;
                  final DateTime targetDate = resolutionDate.add(Duration(days: days));
                  final bool hasPlan = _getRewardPlanForDate(targetDate, milestoneDays: days) != null;
                  final bool isSelected = _selectedMilestoneDays == days;

                  // 배경색: 선택됨(파란색) > 내용있음(초록색) > 기본(회색)
                  Color bgColor;
                  Color textColor;
                  
                  if (isSelected) {
                    bgColor = const Color(0xFF1890FF);
                    textColor = Colors.white;
                  } else if (hasPlan) {
                    bgColor = const Color(0xFF52C41A); // 초록색 (내용 있음)
                    textColor = Colors.white;
                  } else {
                    bgColor = Colors.grey[100]!;
                    textColor = Colors.grey[600]!;
                  }

                  return GestureDetector(
                    onTap: () => _onTagSelected(days),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // 선택된 태그가 있을 때 입력/조회 영역 표시
              if (_selectedMilestoneDays != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_milestoneTags[_selectedMilestoneDays]} 보상',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            DateFormat('yyyy.MM.dd').format(resolutionDate.add(Duration(days: _selectedMilestoneDays!))),
                            style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (_isEditingReward)
                        // 편집 모드 (TextField)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _rewardContentController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: '나에게 줄 선물을 입력하세요',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                contentPadding: const EdgeInsets.all(12),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF1890FF)),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 수정 시 나타나는 부분 (읽기 전용 모드에서만 나타나던 수정 버튼을 여기로 옮기거나 보완 가능)
                                if (!_isEditingReward && _rewardContentController.text.isNotEmpty)
                                  const SizedBox()
                                else if (_isEditingReward)
                                  const SizedBox(),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _onTagSelected(_selectedMilestoneDays!); 
                                      },
                                      child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _saveRewardPlan,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1890FF),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: const Size(60, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading 
                                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('저장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                // (이전 로직과 맞지 않아 일단 기존 로직 유지하며 버튼만 위치 조정)
                              ],
                            ),
                          ],
                        )
                      else
                        // 읽기 전용 모드 (Text)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _rewardContentController.text,
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingReward = true;
                                });
                              },
                              child: Text(
                                '수정',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Colors.grey[600], 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '희망노트',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          '오늘 하루도 힘내세요',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }



  Widget _buildAlarmCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [const Color(0xFFFAAD14).withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAAD14).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: Color(0xFFFAAD14), size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('위험상황 알람 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('위험상황 알람을 설정해보세요.', style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlarmScreen(
                          userData: widget.userData,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAAD14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('확인하기', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRecordCard({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required String buttonText,
    required bool isPinned,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [iconColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  // [Changed] 상세내역 버튼을 헤더(우측 상단)로 이동
                  GestureDetector(
                    onTap: () => ActivityDetailsModal.show(context, widget.userData, id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('상세내역', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              
              // [Changed] 하단 버튼 영역에서 상세내역 버튼 제거 (헤더로 이동했으므로)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



