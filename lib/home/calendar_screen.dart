import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../utils/toast_utils.dart';
import 'daily_checklist_card.dart';
import 'debt_details_modal.dart';
import 'package:kcgp_cb/services/api_service.dart'; // Added: Import ApiService
import 'activity_item_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onChecklistCompleted;

  const CalendarScreen({super.key, this.userData, this.onChecklistCompleted});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  final ScrollController _scrollController = ScrollController();
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isMilestoneExpanded = false; // [Added] 기념일 카드 확장 여부 상태
  List<dynamic> _attendanceData = [];
  Map<String, dynamic>? _debtData;
  List<dynamic> _selectedDayActivities = [];
  Map<String, List<String>> _activitySummary = {};
  bool _isLoading = true;
  bool _isExpanded = false; // 삼성 캘린더 스타일 확장을 위한 상태
  double _totalDebtAmount = 0;
  double _monthlyTotal = 0;
  String? _resolutionDateRaw; // YYYY-MM-DD format
  List<String> _restartDates = []; // YYYY-MM-DD list
  Map<String, dynamic> _rewardPlans = {}; // Date: {id, content, milestoneDays} map
  final List<int> _milestoneDays = [100, 200, 300, 365, 400, 500, 600, 730];
  
  // [Added] 그룹화 펼침 상태 관리
  Map<String, bool> _expandedGroups = {};
  Map<String, dynamic> _monthlyChecklistSummary = {}; // [Added] 월별 체크리스트 상태 모음
  int _refreshCount = 0; // [Added] Force children refresh

  DateTime _getResolutionDate() {
    // 1. 재시작일(Restart Date) 확인 - 있으면 마지막 재시작일을 기준일로 사용
    if (_restartDates.isNotEmpty) {
      try {
        final List<String> sortedDates = List<String>.from(_restartDates);
        sortedDates.sort(); // 오름차순 정렬
        final lastRestart = sortedDates.last;
        return DateFormat('yyyy-MM-dd').parse(lastRestart);
      } catch (e) {
        debugPrint('Error parsing restart date: $e');
      }
    }

    // 2. 재시작일 없으면 기존 결심일(Resolution Date) 사용
    if (_resolutionDateRaw != null) {
      try {
        return DateFormat('yyyy-MM-dd').parse(_resolutionDateRaw!);
      } catch (e) {
        debugPrint('Error parsing resolution date: $e');
      }
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOutCubic,
    );
    loadMonthlyAttendance(isInitial: true);
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    if (_expansionController.isCompleted) {
      _expansionController.reverse();
    } else {
      _expansionController.forward();
    }
  }
  Future<void> loadMonthlyAttendance({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    
    final results = await Future.wait([
      ApiService.getMonthlyAttendance(widget.userData!['uid'], _focusedDay.year, _focusedDay.month),
      ApiService.getDebtList(widget.userData!['uid']),
      ApiService.getActivities(uid: widget.userData!['uid'], date: dateStr),
      ApiService.getMonthlyActivitySummary(widget.userData!['uid'], _focusedDay.year, _focusedDay.month),
      ApiService.getHomeDashboard(widget.userData!['uid']),
      ApiService.getRewardPlans(widget.userData!['uid']),
      ApiService.getMonthlyChecklistSummary(widget.userData!['uid'], _focusedDay.year, _focusedDay.month),
    ]);

    final attendanceResult = results[0];
    final debtResult = results[1];
    final activitiesResult = results[2];
    final summaryResult = results[3];
    final dashboardResult = results[4];
    final rewardPlansResult = results[5];
    final checklistSummaryResult = results[6];

    if (mounted) {
      setState(() {
        if (attendanceResult['success']) {
          _attendanceData = attendanceResult['data'];
        }
        if (debtResult['success']) {
          _debtData = debtResult['data'];
          final List<dynamic> debts = _debtData?['debts'] ?? [];
          // 총 부채 금액은 원금의 합계로 계산 (상세 모달과 통일)
          _totalDebtAmount = debts.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0).toDouble());
          // 월 예상 납입금 합계 계산 (선택된 달 기준 실제 상환액)
          _monthlyTotal = debts.fold(0.0, (sum, item) => sum + _getMonthlyPayment(item, targetDate: _focusedDay));
        }
        if (activitiesResult['success']) {
          _selectedDayActivities = activitiesResult['data'];
          _expandedGroups.clear(); // [Added] 데이터 새로고침 시 펼침 상태 초기화
        }
        if (summaryResult['success']) {
          final List<dynamic> list = summaryResult['data'];
          _activitySummary = {
            for (var item in list) 
              item['date']: List<String>.from(item['types'])
          };
        }
        if (dashboardResult['success']) {
          // "2025년 12월 29일" -> "2025-12-29" 변환 시도
          final resDate = dashboardResult['data']['resolutionDate'];
          if (resDate != null && resDate.toString().contains('년')) {
            try {
              final dateParts = resDate.toString().split(' ');
              if (dateParts.length >= 3) {
                final year = dateParts[0].replaceAll('년', '').trim();
                final month = dateParts[1].replaceAll('월', '').trim().padLeft(2, '0');
                final day = dateParts[2].replaceAll('일', '').trim().padLeft(2, '0');
                _resolutionDateRaw = '$year-$month-$day';
                debugPrint('Parsed Resolution Date: $_resolutionDateRaw');
              }
            } catch (e) {
              debugPrint('Error parsing resolution date: $e');
              _resolutionDateRaw = null;
            }
          } else if (resDate != null && resDate.toString().contains('-')) {
            _resolutionDateRaw = resDate.toString(); // Already in YYYY-MM-DD
          }
          if (dashboardResult['data']['restartDates'] != null) {
            _restartDates = List<String>.from(dashboardResult['data']['restartDates']);
            _restartDates.sort((a, b) => a.compareTo(b)); // 오름차순 정렬
          }
        }
        if (rewardPlansResult['success']) {
          final List<dynamic> list = rewardPlansResult['data'];
          _rewardPlans = {
            for (var item in list) 
              item['targetDate']: item
          };
        }
        if (checklistSummaryResult['success']) {
           _monthlyChecklistSummary = checklistSummaryResult['data'] ?? {};
        }
        _refreshCount++; // Increment refresh count to trigger children re-fetch
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  double _getMonthlyPayment(Map<String, dynamic> debt, {DateTime? targetDate}) {
    try {
      final double principal = (debt['amount'] ?? 0).toDouble();
      final double remainingAmount = (debt['remainingAmount'] ?? 0).toDouble();
      final double annualRate = (debt['interestRate'] ?? 0).toDouble();
      int loanMonths = debt['loanPeriod'] ?? 0;
      final int graceMonths = debt['gracePeriod'] ?? 0;
      final String repaymentType = debt['repaymentType'] ?? '원리금균등상환';

      // 상환이 이미 완료된 경우 (잔액이 0) 계산 제외
      if (principal <= 0 || remainingAmount <= 0) return 0;

      // 대출 기간이 없는 기존 데이터를 위해 날짜 차이로 기간 계산
      if (loanMonths <= 0) {
        try {
          DateTime start = DateFormat('yyyy-MM-dd').parse(debt['debtDate']);
          DateTime end = DateFormat('yyyy-MM-dd').parse(debt['dueDate']);
          loanMonths = (end.year - start.year) * 12 + end.month - start.month;
        } catch (e) {
          loanMonths = 0;
        }
        if (loanMonths <= 0) loanMonths = 1; // 최소 1개월 보장
      }

      // 기준일 (채무 발생일)
      DateTime currentDate;
      String? dateStr = debt['debtDate'];
      try {
        if (dateStr != null && dateStr.contains('-')) {
          currentDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        } else if (dateStr != null && dateStr.contains('/')) {
          currentDate = DateFormat('yyyy/MM/dd').parse(dateStr);
        } else {
          currentDate = DateTime.now();
        }
      } catch (e) {
        currentDate = DateTime.now();
      }

      // 조회 날짜가 채무 발생 전이면 0원
      if (targetDate != null) {
        final startOfMonth = DateTime(currentDate.year, currentDate.month, 1);
        final targetOfMonth = DateTime(targetDate.year, targetDate.month, 1);
        if (targetOfMonth.isBefore(startOfMonth)) return 0;
      }

      final double dailyRate = (annualRate / 100) / 365;
      final int repaymentMonths = (loanMonths - graceMonths) > 0 ? (loanMonths - graceMonths) : loanMonths;
      
      double totalInterest = 0;
      double remainingPrincipal = principal;
      double monthlyPaymentFixed = 0; 
      
      if (repaymentType == '원리금균등상환') {
        double monthlyRate = (annualRate / 100) / 12;
        if (monthlyRate == 0) {
          monthlyPaymentFixed = principal / repaymentMonths;
        } else {
          monthlyPaymentFixed = principal * 
              (monthlyRate * math.pow(1 + monthlyRate, repaymentMonths)) / 
              (math.pow(1 + monthlyRate, repaymentMonths) - 1);
        }
      }

      // 개월별 시뮬레이션으로 총 이자 계산
      for (int i = 1; i <= loanMonths; i++) {
        DateTime nextMonth = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
        if (nextMonth.day != currentDate.day) {
          nextMonth = DateTime(currentDate.year, currentDate.month + 2, 0);
        }
        int daysInMonth = nextMonth.difference(currentDate).inDays;
        
        double interest = remainingPrincipal * dailyRate * daysInMonth;
        totalInterest += interest;
        
        double principalPaid = 0;
        if (i > graceMonths) {
          if (repaymentType == '원금균등상환') {
            principalPaid = principal / repaymentMonths;
          } else if (repaymentType == '원리금균등상환') {
            principalPaid = monthlyPaymentFixed - (remainingPrincipal * ((annualRate / 100) / 12));
          } else if (repaymentType == '원금만기일시상환') {
            principalPaid = (i == loanMonths) ? principal : 0;
          }
          if (i == loanMonths) principalPaid = remainingPrincipal;
        }

        double currentTotal = interest + principalPaid;

        // 타겟 날짜가 명시된 경우, 해당 월의 실제 납입금을 반환
        if (targetDate != null && 
            currentDate.year == targetDate.year && 
            currentDate.month == targetDate.month) {
          if (repaymentType == '원금만기일시상환' && i < loanMonths) {
            return 0;
          }
          return currentTotal;
        }

        remainingPrincipal -= (principalPaid > remainingPrincipal ? remainingPrincipal : principalPaid);
        currentDate = nextMonth;
      }

      // 타겟 날짜가 명시되었는데 기간 내에 없으면 상환 종료된 것이므로 0원
      if (targetDate != null) return 0;

      // 타겟 날짜가 없으면 평균값 반환 (Fallback)
      if (repaymentType == '원금만기일시상환') {
        return 0;
      } else if (repaymentType == '원금균등상환') {
        return (principal + totalInterest) / loanMonths;
      } else { // 원리금균등상환
        return monthlyPaymentFixed;
      }
    } catch (e) {
      return 0;
    }
  }

  Future<void> _loadDailyActivities(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final response = await ApiService.getActivities(
      uid: widget.userData!['uid'],
      date: dateStr,
    );

    if (mounted && response['success']) {
      setState(() {
        _selectedDayActivities = response['data'];
        _expandedGroups.clear(); // [Added] 날짜 변경 시 펼침 상태 초기화
      });
    }
  }

  String _getAttendanceStatus(DateTime day) {
    if (_attendanceData.isEmpty) return 'NONE';
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    try {
      final record = _attendanceData.firstWhere(
        (element) => element['date'] == dateStr,
        orElse: () => <String, dynamic>{},
      );
      return record.isNotEmpty ? record['status'] : 'NONE';
    } catch (e) {
      return 'NONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _attendanceData.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Hot Reload 대응: 애니메이션이 초기화되지 않은 경우 대비
    try {
      _expansionAnimation.value;
    } catch (e) {
      return const Scaffold(
        body: Center(child: Text('앱을 새로고침(Hot Restart) 해주세요.')),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: AnimatedBuilder(
        animation: _expansionAnimation,
        builder: (context, child) {
          final expansionValue = _expansionAnimation.value;
          final isExpanding = expansionValue > 0.001;

          return Listener(
            onPointerMove: (event) {
              final dy = event.delta.dy;
              // 1. 스크롤이 맨 위에 있고 아래로 당길 때 (확장 시도)
              if (_scrollController.hasClients && _scrollController.offset <= 0 && dy > 0 && expansionValue < 1.0) {
                _expansionController.value += dy / (screenHeight * 0.4);
              }
              // 2. 이미 어느정도 확장된 상태에서 위로 밀 때 (축소 시도)
              else if (expansionValue > 0 && dy < 0 && _scrollController.offset <= 0) {
                _expansionController.value += dy / (screenHeight * 0.4);
              }
            },
            onPointerUp: (event) {
              if (isExpanding) {
                if (_expansionController.value > 0.5) {
                  _expansionController.forward().then((_) => HapticFeedback.lightImpact());
                } else {
                  _expansionController.reverse().then((_) => HapticFeedback.lightImpact());
                }
              }
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              // 애니메이션 진행 중일 때만 스크롤을 막고, 그 외(0.0 또는 1.0)에는 스크롤 허용
              physics: (expansionValue > 0 && expansionValue < 1) 
                  ? const NeverScrollableScrollPhysics() 
                  : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Column(
                children: [
                  _buildHeader(),
                  
                  // 캘린더 영역 (확장 시 좌우 패딩 축소)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * (1.0 - expansionValue * 0.8)),
                    child: _buildCalendarCard(expansionValue),
                  ),
                  
                  // 드래그 핸들 (확장 유도)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),

                  // 하단 상세 내역 (통합 스크롤)
                  // 확장 중(expansionValue > 0.5)에는 상세 내역을 아예 빼버려 오버플로우 방지 및 성능 최적화
                  if (expansionValue < 0.5)
                    Opacity(
                      opacity: (1.0 - (expansionValue * 2)).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 30 * expansionValue),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // [Added] 날짜별 체크리스트 / 나의 현재 상태
                              DailyChecklistCard(
                                key: ValueKey(_refreshCount),
                                userData: widget.userData!,
                                targetDate: DateFormat('yyyy-MM-dd').format(_selectedDay),
                                customTitle: '나의 현재 상태',
                                forceResultOnly: false, // 작성 가능하도록 true -> false (DailyChecklistCard 내부 로직에 따름)
                                hideIfSubmitted: false, // 제출 후에도 결과 표시
                                onChecklistCompleted: () {
                                   _loadDailyActivities(_selectedDay);
                                   loadMonthlyAttendance(); 
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildDailyDetailHeader(),
                              const SizedBox(height: 16),
                              _buildDetailCards(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_focusedDay.year}년',
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.grey[600], 
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${_focusedDay.month}월',
                style: const TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF1F1F1F),
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
          _buildDDayBadge(),
          Row(
            children: [
              _buildHeaderNavButton(
                icon: Icons.chevron_left,
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  });
                  loadMonthlyAttendance();
                },
              ),
              const SizedBox(width: 4),
              _buildHeaderNavButton(
                icon: Icons.chevron_right,
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  });
                  loadMonthlyAttendance();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDDayBadge() {
    if (_resolutionDateRaw == null) return const SizedBox();

    String targetDateStr = _resolutionDateRaw!;
    String label = '단도박 시작일';
    
    // 재시작일이 있으면 마지막 재시작일을 기준일로 설정
    if (_restartDates.isNotEmpty) {
      targetDateStr = _restartDates.last; 
      label = '단도박 유지일';
    }

    int dDays = 0;
    try {
      final parts = targetDateStr.split('-');
      if (parts.length == 3) {
        final start = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // D-Day calc: (today - start) in days + 1 (1일차부터 시작)
        dDays = today.difference(start).inDays + 1;
      }
    } catch (_) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFADC6FF)),
      ),
      child: Column(
        children: [
          Text(
            label, 
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF2F54EB),
              fontWeight: FontWeight.w600,
            )
          ),
          Text(
            'D+${dDays}',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF2F54EB),
              fontWeight: FontWeight.bold,
              height: 1.2
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderNavButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.grey[700], size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildCalendarCard(double expansionValue) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * (1.0 - expansionValue * 0.7),
        vertical: 20 - (expansionValue * 8)
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWeekDays(),
          const SizedBox(height: 16),
          _buildDaysGrid(),
        ],
      ),
    );
  }

  Widget _buildWeekDays() {
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((day) {
        Color color = const Color(0xFF8C8C8C);
        if (day == '일') color = const Color(0xFFFF4D4F);
        if (day == '토') color = const Color(0xFF2F54EB);
        return Text(
          day,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final prevMonthLastDay = DateTime(_focusedDay.year, _focusedDay.month, 0);
    
    final daysInMonth = lastDayOfMonth.day;
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    
    List<Widget> dayWidgets = [];
    
    // Previous month padding
    for (int i = 0; i < firstDayOfWeek; i++) {
       dayWidgets.add(const SizedBox());
    }
    
    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDay = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isSelected = isSameDay(currentDay, _selectedDay);
      final status = _getAttendanceStatus(currentDay);
      final isToday = isSameDay(currentDay, DateTime.now());
      final isFuture = currentDay.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

      dayWidgets.add(
        GestureDetector(
          onTap: isFuture ? null : () {
            setState(() {
              _selectedDay = currentDay;
              _isMilestoneExpanded = false; // [Added] 날짜 변경 시 확장 상태 초기화
            });
            _loadDailyActivities(currentDay);
          },
          child: Container(
            alignment: Alignment.center,
            decoration: null, // 선택 시 나타나던 파란 원형 테두리 제거
            child: _buildDayContent(currentDay, status, currentDay.weekday % 7, isToday, isFuture, isSelected),
          ),
        ),
      );
    }

    final currentSpacing = 6.0 - (_expansionAnimation.value * 5.5); // 간격 더 축소
    
    // 7개씩 자르기 위해 리스트 생성
    List<List<Widget>> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      int end = (i + 7 < dayWidgets.length) ? i + 7 : dayWidgets.length;
      rows.add(dayWidgets.sublist(i, end));
    }

    return Column(
      children: rows.map((rowItems) {
        return Padding(
          padding: EdgeInsets.only(bottom: currentSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rowItems.map((item) => Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: currentSpacing / 2),
                  child: item,
                ),
              )),
              // 마지막 행이 7개가 안될 경우 빈 공간 채우기
              if (rowItems.length < 7)
                ...List.generate(7 - rowItems.length, (index) => const Expanded(child: SizedBox())),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayContent(DateTime dayDate, String status, int weekDay, bool isToday, bool isFuture, bool isSelected) {
    final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
    Color? bgColor;
    Color textColor = isFuture ? const Color(0xFFD9D9D9) : const Color(0xFF1F1F1F);
    
    // [Added] Checklist Background Color
    Color? checklistBgColor;
    if (!isFuture) {
      final summary = _monthlyChecklistSummary[dateStr];
      if (summary != null && summary['status'] != null) {
        final status = summary['status'];
        if (status == '좋음') checklistBgColor = const Color(0xFF52C41A);
        else if (status == '중간' || status == '보통') checklistBgColor = const Color(0xFFFAAD14);
        else if (status == '주의') checklistBgColor = const Color(0xFFFF4D4F);
        else if (status == '나쁨') checklistBgColor = const Color(0xFFD32F2F);
      }
    
      if (weekDay == 0) textColor = const Color(0xFFFF4D4F);
      if (weekDay == 6) textColor = const Color(0xFF2F54EB);

      if (status == 'SUCCESS') {
        bgColor = const Color(0xFF36CFC9);
        textColor = isSelected ? const Color(0xFF36CFC9) : Colors.white; 
      } else if (status == 'FAILURE') {
        bgColor = const Color(0xFFFF7875);
        textColor = isSelected ? const Color(0xFFFF7875) : Colors.white;
      } else if (status == 'MISSED') {
         bgColor = const Color(0xFFFFA940); 
         textColor = isSelected ? const Color(0xFFFFA940) : Colors.white;
      }
    }


    final activityTypes = _activitySummary[dateStr] ?? [];

    // 1. 최초 시작일 (Blue) 여부
    final isInitial = dateStr == _resolutionDateRaw;
    
    // 2. 재시작일 (Yellow) 여부: 서버에서 받아온 재시작일 목록에 포함되는지 확인
    final isRestart = _restartDates.contains(dateStr);

    return AnimatedScale(
      scale: isSelected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        // 유동적 높이를 보장하면서도, 데이터가 없을 때 너무 작아지지 않도록 최소 높이 설정
        constraints: BoxConstraints(
          minHeight: 75 + (_expansionAnimation.value * 35), // 75 -> 110 으로 유동적 조절
        ),
        padding: EdgeInsets.symmetric(
          vertical: 6, 
          horizontal: 3 * (1.0 - _expansionAnimation.value * 0.6) // 확장 시 내부 패딩 더 축소
        ),
        decoration: BoxDecoration(
          color: checklistBgColor != null 
              ? (isSelected ? checklistBgColor.withOpacity(0.3) : checklistBgColor.withOpacity(0.15))
              : (isSelected ? Colors.white : Colors.transparent),
          // 2번 제안: 이정표 아이콘 및 볼드 스타일 (그라데이션 제거/축소)
          border: (isInitial || isRestart) 
            ? Border.all(color: const Color(0xFFADC6FF), width: 2.0)
            : (bgColor != null 
                ? Border.all(color: bgColor.withOpacity(0.7), width: 2.0)
                : null),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF5C72EB).withOpacity(0.12),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 일자 위에 표시할 상태 텍스트 및 아이콘 (시작/재시작) - 오버플로우 방지를 위해 크기 축소
            if ((isInitial || isRestart))
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInitial ? Icons.flag : Icons.star,
                        size: 8,
                        color: const Color(0xFF2F54EB),
                      ),
                      const SizedBox(width: 0.5),
                      Text(
                        isInitial ? '시작' : '재시작 ${_restartDates.indexOf(dateStr) + 1}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2F54EB),
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // [Added] 기념일 숫자 표시 (일자 위)
            if (_isMilestoneDay(dayDate) && _rewardPlans.containsKey(dateStr))
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cake, // 아이콘 변경 가능
                        size: 8,
                        color: Color(0xFF722ED1),
                      ),
                      const SizedBox(width: 0.5),
                      Text(
                        _getMilestoneLabel(dayDate),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF722ED1), // 보라색
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              '${dayDate.day}',
              style: TextStyle(
                color: isSelected 
                    ? const Color(0xFF5C72EB) 
                    : ((bgColor != null && !isFuture) ? bgColor : textColor),
                fontSize: isSelected ? 16 : 14,
                fontWeight: (isSelected || isToday) ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            if (activityTypes.isNotEmpty || isInitial || isRestart || _rewardPlans.containsKey(dateStr) || (_isMilestoneDay(dayDate) && _rewardPlans.containsKey(dateStr)))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (_rewardPlans.containsKey(dateStr) && !isFuture)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          width: double.infinity,
                          height: 4 + (_expansionAnimation.value * 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D4F),
                            borderRadius: BorderRadius.circular(2 + (_expansionAnimation.value * 1)),
                          ),
                          alignment: Alignment.center,
                          child: _expansionAnimation.value > 0.7 
                            ? Opacity(
                                opacity: ((_expansionAnimation.value - 0.7) / 0.3).clamp(0.0, 1.0),
                                child: Text(
                                  '🎁 보상: ${_rewardPlans[dateStr]['content']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        ),
                    // [Removed] Restart label as per user request
                    /*
                    if ((isInitial || isRestart))
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          width: double.infinity,
                          height: 4 + (_expansionAnimation.value * 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F54EB),
                            borderRadius: BorderRadius.circular(2 + (_expansionAnimation.value * 1)),
                          ),
                          alignment: Alignment.center,
                          child: _expansionAnimation.value > 0.7 
                            ? Opacity(
                                opacity: ((_expansionAnimation.value - 0.7) / 0.3).clamp(0.0, 1.0),
                                child: Text(
                                  isInitial ? '단도박 시작일' : '단도박 재시작 ${_restartDates.indexOf(dateStr) + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        ),
                    */

                    if (!isFuture)
                      ...activityTypes.map((type) {
                        Color barColor = Colors.grey;
                        String title = "";
                        switch (type) {
                          case 'GRATITUDE': barColor = const Color(0xFFFF851B); title = "감사"; break;
                          case 'WALK': barColor = const Color(0xFF52C41A); title = "일상"; break;
                          case 'IMPULSE': barColor = const Color(0xFFFF4D4F); title = "충동"; break;
                          case 'POSITIVE_SELF': barColor = const Color(0xFF722ED1); title = "희망"; break;
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          width: double.infinity,
                          height: 4 + (_expansionAnimation.value * 12),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(2 + (_expansionAnimation.value * 1)),
                          ),
                          alignment: Alignment.center,
                          child: _expansionAnimation.value > 0.7 
                            ? Opacity(
                                opacity: ((_expansionAnimation.value - 0.7) / 0.3).clamp(0.0, 1.0),
                                child: Text(
                                  title, 
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ) 
                            : const SizedBox.shrink(),
                        );
                      }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDetailHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_selectedDay.month}월 ${_selectedDay.day}일 (${_getWeekDayStr(_selectedDay.weekday)})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
        ),
        TextButton.icon(
          onPressed: () => _showDebtDetailsModal(),
          icon: const Icon(Icons.list_alt, size: 16, color: Color(0xFF5C72EB)),
          label: const Text('채무/상환 내역', style: TextStyle(color: Color(0xFF5C72EB), fontSize: 13)),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF0F5FF),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCards() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 선택된 날이 오늘보다 미래인 경우에만 빈 화면 반환
    if (_selectedDay.year > today.year || 
       (_selectedDay.year == today.year && _selectedDay.month > today.month) ||
       (_selectedDay.year == today.year && _selectedDay.month == today.month && _selectedDay.day > today.day)) {
      return const SizedBox.shrink();
    }
 
    final status = _getAttendanceStatus(_selectedDay);
    final List<Widget> cards = [];

    // 1. 단도박 시작일/재시작일 카드 (해당일인 경우 표시)
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final isInitial = dateStr == _resolutionDateRaw;
    final isRestart = _restartDates.contains(dateStr);

    if (isInitial || isRestart) {
      final gradientColors = [const Color(0xFF5C72EB), const Color(0xFF2F54EB)]; // 파란색 통일
      final label = isInitial ? '단도박 시작일입니다' : '단도박 재시작 ${_restartDates.indexOf(dateStr) + 1}입니다';

      cards.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '응원합니다! 🎉',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ));
      cards.add(const SizedBox(height: 12));
    }

    // 2. 단도박 성공/실패 기록 카드 (항상 표시)
    cards.add(_buildAttendanceCard(status));

    // Daily Checklist Card (Inserted)
    // Daily Checklist Card (Inserted)
    if (widget.userData != null && (widget.userData!['userType'] == 'SUBJECT' || widget.userData!['userType'] == 'ADMIN')) {
       if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
       cards.add(DailyChecklistCard(
         key: ValueKey('checklist-$dateStr-$_refreshCount'), // Include refreshCount to force refresh
         userData: widget.userData!,
         targetDate: dateStr,
         hideIfSubmitted: true, // [Added] 캘린더에서는 완료된 경우 표시하지 않음 (User Request)
         onChecklistCompleted: () {
            loadMonthlyAttendance();
            widget.onChecklistCompleted?.call();
          },
       ));
    }



    // [Modified] 4. 기념일 축하 카드 & 5. 자기보상 계획 카드 (통합)
    if (_isMilestoneDay(_selectedDay)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(_buildMilestoneCard(_selectedDay));
    } else if (_rewardPlans.containsKey(dateStr)) {
       // 기념일 아닌 날 보상 계획만 있는 경우
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(_buildRewardPlanCard(_rewardPlans[dateStr]!));
    }
 

    // 3. 활동 기록 카드 (그룹화 적용)
    // 그룹화를 위해 데이터 전처리
    Map<String, List<dynamic>> groupedActivities = {};
    for (var activity in _selectedDayActivities) {
      final type = activity['activityType'] ?? 'UNKNOWN';
      groupedActivities.putIfAbsent(type, () => []).add(activity);
    }

    // 그룹화된 데이터 순회 (표시 순서: 감사일기 -> 일상기록 -> 충동일지 -> 희망 리코딩 -> 기타)
    final order = ['GRATITUDE', 'WALK', 'IMPULSE', 'POSITIVE_SELF'];
    
    // 순서에 있는 타입들 먼저 처리
    for (var type in order) {
      if (groupedActivities.containsKey(type)) {
        final List<dynamic> items = groupedActivities[type]!;
        _buildGroupedCards(cards, type, items);
        groupedActivities.remove(type);
      }
    }
    
    // 나머지 타입들 처리
    groupedActivities.forEach((type, items) {
      _buildGroupedCards(cards, type, items);
    });

    // 3. 오늘의 다짐 녹음 카드 (실제 데이터 연동 전까지는 숨김 처리 - 사용자의 요청)
    // if (hasVoiceRecord) {
    //   if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
    //   cards.add(_buildVoiceRecordCard());
    // }

    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[300], size: 48),
            const SizedBox(height: 16),
            Text(
              '기록이 없습니다.',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: cards,
    );
  }

  Widget _buildAttendanceCard(String status) {
    bool isNone = status == 'NONE';
    bool isSuccess = status == 'SUCCESS';
    bool isFailure = status == 'FAILURE';
    bool isMissed = status == 'MISSED';

    Color themeColor = isSuccess 
        ? const Color(0xFF36CFC9) 
        : (isFailure 
            ? const Color(0xFFFF4D4F) 
            : (isMissed ? const Color(0xFFFFA940) : Colors.grey));
    
    if (isNone) themeColor = const Color(0xFF5C72EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: themeColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : (isFailure ? Icons.cancel : (isMissed ? Icons.warning_amber_rounded : Icons.help_outline)),
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? '단도박 유지' : (isFailure ? '단도박 재발' : (isMissed ? '단도박 실수' : '단도박 기록 전')),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSuccess 
                        ? '약속을 잘 지키셨습니다!' 
                        : (isFailure 
                            ? '너무 자책하지말고 지금 바로 용기내어 다시 시작해 볼까요?' 
                            : (isMissed ? '작은 실수라도 가볍게 생각하지말고 치료과정을 점검해 주세요' : '오늘의 단도박 여부를 기록해주세요.')),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateAttendance('SUCCESS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? const Color(0xFF36CFC9) : Colors.white,
                    foregroundColor: isSuccess ? Colors.white : const Color(0xFF36CFC9),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFF36CFC9)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('유지', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateAttendance('MISSED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMissed ? const Color(0xFFFFA940) : Colors.white,
                    foregroundColor: isMissed ? Colors.white : const Color(0xFFFFA940),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFFA940)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('실수', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateAttendance('FAILURE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFailure ? const Color(0xFFFF4D4F) : Colors.white,
                    foregroundColor: isFailure ? Colors.white : const Color(0xFFFF4D4F),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFF4D4F)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('재발', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateAttendance(String status) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);

    // [추가된 로직] 재발(FAILURE)한 다음날 유지(SUCCESS) 되면 재시작 여부 확인
    if (status == 'SUCCESS') {
      final prevDay = _selectedDay.subtract(const Duration(days: 1));
      final prevDayStr = DateFormat('yyyy-MM-dd').format(prevDay);
      Map<String, dynamic>? prevDayRecord;
      try {
        prevDayRecord = _attendanceData.firstWhere(
          (item) => item['date'] == prevDayStr,
        );
      } catch (e) {
        prevDayRecord = null;
      }

      if (prevDayRecord != null && (prevDayRecord['status'] == 'FAILURE' || prevDayRecord['status'] == 'MISSED')) {
        final String reason = prevDayRecord['status'] == 'FAILURE' ? '재발' : '실수';
        final bool? shouldRestart = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.refresh, color: Color(0xFFFFA940)),
                SizedBox(width: 8),
                Text('단도박 재시작'),
              ],
            ),
            content: Text('어제 $reason 기록이 있습니다.\n오늘 날짜부터 단도박을 다시 시작하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('아니오', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA940),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('예, 다시 시작합니다'),
              ),
            ],
          ),
        );

        if (shouldRestart == true) {
          // 서버에 재시작일 저장
          await ApiService.saveRestartDate(widget.userData!['uid'], dateStr);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('단도박 재시작 패턴이 기록되었습니다.'))
            );
          }
        }
      }
    }

    final response = await ApiService.saveAttendance(
      widget.userData!['uid'], 
      status, 
      date: dateStr
    );

    if (response['success']) {
      if (mounted) {
        loadMonthlyAttendance(); // 캘린더 색상 및 시작일 데이터 업데이트를 위해 전체 재로딩
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? '저장 실패'))
        );
      }
    }
  }



  void _showDebtDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => DebtDetailsModal(
          debtData: _debtData ?? {},
          userData: widget.userData!,
          initialDate: _selectedDay,
          onSave: () {
            loadMonthlyAttendance(); // 데이터가 변경되었을 수 있으므로 다시 로드
          },
        ),
      ),
    );
  }

  Widget _buildVoiceRecordCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(left: BorderSide(color: Color(0xFFADC6FF), width: 4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Color(0xFF5C72EB), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('오늘의 다짐 녹음', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('07:00', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, color: Color(0xFF5C72EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.45,
                            child: Container(decoration: BoxDecoration(color: const Color(0xFF5C72EB), borderRadius: BorderRadius.circular(1.5))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('0:45', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['activityType'];
    final title = activity['title'] ?? '';
    final content = activity['content'] ?? '';
    final imageUrls = activity['imageUrls'] as List<dynamic>? ?? [];
    final startTime = activity['startTime'];

    IconData icon;
    Color color;
    String label;

    switch (type) {
      case 'GRATITUDE':
        icon = Icons.favorite_border;
        color = const Color(0xFFFF851B);
        label = '감사 일기';
        break;
      case 'WALK':
        icon = Icons.wb_sunny_outlined;
        color = const Color(0xFF52C41A);
        label = '일상 기록';
        break;
      case 'IMPULSE':
        icon = Icons.flash_on;
        color = const Color(0xFFFF4D4F);
        label = '충동 일지';
        break;
      case 'POSITIVE_SELF':
        icon = Icons.auto_awesome;
        color = const Color(0xFF722ED1);
        label = '희망 리코딩';
        break;
      default:
        icon = Icons.edit_note_rounded;
        color = Colors.blueGrey;
        label = '활동 기록';
    }

    // Construct display content based on type if content is empty
    Widget contentWidget;
    if (type == 'GRATITUDE') {
      final fields = [
        activity['gratitudeTo'],
        activity['gratitudeSituation'],
        activity['gratitudeEmotion']
      ].where((e) => e != null && e.toString().isNotEmpty).toList();
      
      if (fields.isEmpty) {
        contentWidget = Text(content.isEmpty ? '내용 없음' : content, style: const TextStyle(color: Color(0xFF434343), fontSize: 15, height: 1.5));
      } else {
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fields.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${entry.key + 1}. ${entry.value}',
                style: const TextStyle(color: Color(0xFF434343), fontSize: 14, height: 1.4),
                maxLines: imageUrls.isNotEmpty ? 1 : null,
                overflow: imageUrls.isNotEmpty ? TextOverflow.ellipsis : null,
              ),
            );
          }).toList(),
        );
      }
    } else if (type == 'IMPULSE') {
      final fields = [
        activity['impulseSituation'],
        activity['impulseThought'],
        activity['impulseHelpful'],
        activity['impulseAfter']
      ].where((e) => e != null && e.toString().isNotEmpty).toList();

      if (fields.isEmpty) {
        contentWidget = Text(content.isEmpty ? '내용 없음' : content, style: const TextStyle(color: Color(0xFF434343), fontSize: 15, height: 1.5));
      } else {
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fields.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${entry.key + 1}. ${entry.value}',
                style: const TextStyle(color: Color(0xFF434343), fontSize: 14, height: 1.4),
                maxLines: imageUrls.isNotEmpty ? 1 : null,
                overflow: imageUrls.isNotEmpty ? TextOverflow.ellipsis : null,
              ),
            );
          }).toList(),
        );
      }
    } else {
      contentWidget = Text(
        content.isEmpty ? '내용 없음' : content,
        style: const TextStyle(color: Color(0xFF434343), fontSize: 15, height: 1.5),
        maxLines: imageUrls.isNotEmpty ? 3 : null,
        overflow: imageUrls.isNotEmpty ? TextOverflow.ellipsis : null,
      );
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityItemDetailScreen(
              activity: activity,
              userData: widget.userData!,
            ),
          ),
        );
        if (result == true) {
          loadMonthlyAttendance(); 
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (startTime != null)
                  Text(
                    startTime.substring(0, 5),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrls.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이미지 미리보기 (첫 번째 사진)
                  FutureBuilder<String>(
                    future: ApiService.baseUrl,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }
                      String finalUrl = snapshot.data!.replaceAll('/api', '') + imageUrls.first;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          finalUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          headers: {'X-User-Uid': widget.userData!['uid']},
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error_outline, size: 20, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  // 텍스트 정보 (내용 미리보기)
                  Expanded(child: contentWidget),
                ],
              )
            else
              contentWidget,
          ],
        ),
      ),
    );
  }


  void _buildGroupedCards(List<Widget> cards, String type, List<dynamic> items) {
    if (items.isEmpty) return;
    
    // items가 1개인 경우 펼침 UI 없이 바로 표시
    if (items.length == 1) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(_buildActivityCard(items.first));
      return;
    }
    
    // items가 2개 이상일 때 그룹화 UI 적용
    if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
    
    // 그룹 헤더 추가
    final isExpanded = _expandedGroups[type] ?? false;
    cards.add(_buildGroupHeaderCard(type, items.length, isExpanded));
    
    // 펼쳐진 상태라면 리스트 아이템 표시
    if (isExpanded) {
      for (var activity in items) {
        cards.add(const SizedBox(height: 8)); // 간격 좁게
        // 들여쓰기를 위해 Padding과 크기 조절을 적용한 컨테이너 감싸기
        cards.add(
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _buildActivityCard(activity),
          )
        );
      }
    }
  }

  Widget _buildGroupHeaderCard(String type, int count, bool isExpanded) {
    IconData icon;
    Color color;
    String label;

    switch (type) {
      case 'GRATITUDE':
        icon = Icons.favorite_border;
        color = const Color(0xFFFF851B);
        label = '감사 일기';
        break;
      case 'WALK':
        icon = Icons.wb_sunny_outlined;
        color = const Color(0xFF52C41A);
        label = '일상 기록';
        break;
      case 'IMPULSE':
        icon = Icons.flash_on;
        color = const Color(0xFFFF4D4F);
        label = '충동 일지';
        break;
      case 'POSITIVE_SELF':
        icon = Icons.auto_awesome;
        color = const Color(0xFF722ED1);
        label = '희망 리코딩';
        break;
      default:
        icon = Icons.edit_note_rounded;
        color = Colors.blueGrey;
        label = '활동 기록';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedGroups[type] = !isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 높이를 조금 줄임
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5), // 테두리로 그룹임을 표시
          boxShadow: [
             BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              '$label 모아보기',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count건',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  String _getWeekDayStr(int weekday) {
    switch (weekday) {
      case DateTime.monday: return '월';
      case DateTime.tuesday: return '화';
      case DateTime.wednesday: return '수';
      case DateTime.thursday: return '목';
      case DateTime.friday: return '금';
      case DateTime.saturday: return '토';
      case DateTime.sunday: return '일';
      default: return '';
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  bool _isMilestoneDay(DateTime day) {
    final baseDate = _getResolutionDate();
    // baseDate부터 day까지의 일수 차이 (당일 포함 +1 필요하다면 조정, 보통 D+100은 baseDate + 99일)
    // 여기서는 baseDate.add(Duration(days: milestone)) == day 인지 확인
    // 예를 들어 1월 1일 시작 -> 100일째는 1월 1일 + 99일? 아니면 1월 1일 + 100일?
    // 보통 기념일은 100일 '째' 되는 날 -> baseDate + 99일이 D+100일.
    // 하지만 사용자의 요청인 "100일, 200일" 태그에서 계산한 방식은 `resolutionDate.add(Duration(days: days))` 였음.
    // SelfDevelopmentScreen 코드: `resolutionDate.add(Duration(days: days))`
    // 따라서 동일하게 계산.
    
    // 시분초 제거하고 날짜만 비교
    final dDay = DateTime(day.year, day.month, day.day);
    final start = DateTime(baseDate.year, baseDate.month, baseDate.day);
    
    // baseDate로부터 며칠 지났는지
    final diff = dDay.difference(start).inDays;
    
    // add(Duration(days: 100)) -> 차이는 100일.
    return _milestoneDays.contains(diff);
  }

  String _getMilestoneLabel(DateTime day) {
    final baseDate = _getResolutionDate();
    final dDay = DateTime(day.year, day.month, day.day);
    final start = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final diff = dDay.difference(start).inDays;
    
    if (diff == 365) return '1주년';
    if (diff == 730) return '2주년';
    return '${diff}일';
  }

  Widget _buildMilestoneCard(DateTime day) {
    final label = _getMilestoneLabel(day);
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final hasPlan = _rewardPlans.containsKey(dateStr);
    final plan = hasPlan ? _rewardPlans[dateStr]! : null;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (hasPlan) {
              setState(() {
                _isMilestoneExpanded = !_isMilestoneExpanded;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF722ED1), Color(0xFF9254DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(20),
                bottom: (_isMilestoneExpanded && hasPlan) ? Radius.zero : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF722ED1).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cake, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '응원합니다! 👏',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '단도박 $label 달성',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (hasPlan)
                  Icon(
                    _isMilestoneExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                  ),
              ],
            ),
          ),
        ),
        if (hasPlan)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isMilestoneExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D4F), Color(0xFFFF7875)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D4F).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '나에게 주는 선물 🎁',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan!['content'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildRewardPlanCard(Map<String, dynamic> plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4D4F), Color(0xFFFF7875)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D4F).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '나에게 주는 선물 🎁',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['content'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('보상 계획 삭제'),
                      content: const Text('이 보상 계획을 삭제하시겠습니까?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true), 
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('삭제')
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final response = await ApiService.deleteRewardPlan(widget.userData!['uid'], plan['id']);
                    if (response['success']) {
                      loadMonthlyAttendance();
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
              ),
            ],
          ),
          if (plan['milestoneDays'] == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '정기 기념일과 연결되지 않은 보상입니다',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
