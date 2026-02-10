import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../home/daily_checklist_card.dart';


class FamilyCalendarScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const FamilyCalendarScreen({Key? key, this.userData}) : super(key: key);

  @override
  State<FamilyCalendarScreen> createState() => _FamilyCalendarScreenState();
}

class _FamilyCalendarScreenState extends State<FamilyCalendarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  final ScrollController _scrollController = ScrollController();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Data: 'yyyy-MM-dd' -> {'principle': bool, 'daily': bool}
  Map<String, Map<String, bool>> _recordData = {}; 
  bool _isLoading = false;

  String? _resolutionDateRaw; // YYYY-MM-DD
  List<String> _restartDates = [];



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
    _fetchMonthlyData();
    _fetchDashboardData();

  }

  @override
  void dispose() {
    _expansionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }



  Future<void> _fetchMonthlyData() async {
    if (widget.userData == null) return;

    setState(() => _isLoading = true);
    
    final uid = widget.userData!['uid'] ?? widget.userData!['userid']; // Fallback
    final response = await ApiService.getFamilyDailyLogs(uid, _focusedDay.year, _focusedDay.month);
    
    if (mounted) {
      if (response['success'] == true) {
        final List<dynamic> logs = response['data'] ?? [];
        final Map<String, Map<String, bool>> newData = {};
        
        for (var log in logs) {
          // log: {date: "2023-01-01", principleCheck: true, dailyCheck: false}
          final date = log['date'] as String;
          newData[date] = {
            'principle': log['principleCheck'] ?? false,
            'daily': log['dailyCheck'] ?? false,
          };
        }
        setState(() {
          _recordData = newData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // SnackBar?
      }
    }
  }

  Future<void> _fetchDashboardData() async {
    if (widget.userData == null) return;
    final response = await ApiService.getHomeDashboard(widget.userData!['uid'] ?? widget.userData!['userid']);
    if (mounted && response['success'] == true) {
      setState(() {
          final resDate = response['data']['resolutionDate'];
          if (resDate != null && resDate.toString().contains('년')) {
            try {
              final dateParts = resDate.toString().split(' ');
              if (dateParts.length >= 3) {
                final year = dateParts[0].replaceAll('년', '').trim();
                final month = dateParts[1].replaceAll('월', '').trim().padLeft(2, '0');
                 final day = dateParts[2].replaceAll('일', '').trim().padLeft(2, '0');
                _resolutionDateRaw = '$year-$month-$day';
              }
            } catch (e) {
               _resolutionDateRaw = null;
            }
          } else if (resDate != null && resDate.toString().contains('-')) {
            _resolutionDateRaw = resDate.toString();
          }

          if (response['data']['restartDates'] != null) {
            _restartDates = List<String>.from(response['data']['restartDates']);
            _restartDates.sort((a, b) => a.compareTo(b));
          }
      });
    }
  }

  // --- Design Logic (Cloned from CalendarScreen) ---

  @override
  Widget build(BuildContext context) {
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
              if (_scrollController.hasClients && _scrollController.offset <= 0 && dy > 0 && expansionValue < 1.0) {
                _expansionController.value += dy / (screenHeight * 0.4);
              } else if (expansionValue > 0 && dy < 0 && _scrollController.offset <= 0) {
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
              physics: (expansionValue > 0 && expansionValue < 1) 
                  ? const NeverScrollableScrollPhysics() 
                  : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Column(
                children: [
                  _buildHeader(),
                  
                  // Calendar Area
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * (1.0 - expansionValue * 0.8)),
                    child: _buildCalendarCard(expansionValue),
                  ),
                  
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),

                  // Bottom Detail Section
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
                              // Title for details
                              /* Date Header moved to _buildDailyCheckSection */
                              /* Date Header moved to _buildDailyCheckSection */
                              const SizedBox(height: 16),

                              // [Added] 나의 현재 상태 (DailyChecklistCard)
                              DailyChecklistCard(
                                key: ValueKey(_selectedDay), // 날짜 변경 시 리빌드
                                userData: widget.userData!,
                                targetDate: DateFormat('yyyy-MM-dd').format(_selectedDay),
                                customTitle: '나의 성장 상태', // [Modified]
                                checklistType: 'FAMILY', // [Added]
                                showRecoveryTrend: false, // [Modified] Removed redundancy
                                forceResultOnly: false,
                                onChecklistCompleted: () {
                                   setState(() {});
                                },
                              ),

                              const SizedBox(height: 24),
                              _buildDailyCheckSection(),
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
                style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              Text(
                '${_focusedDay.month}월',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
              ),
            ],
          ),
          // D-Day Badge removed as requested
        ],
      ),
    );
  }

  Widget _buildDDayBadge() {
    if (_resolutionDateRaw == null) return const SizedBox();

    String targetDateStr = _resolutionDateRaw!;
    String label = '단도박 시작일';
    
    // Always use the initial resolution date
    // 재시작일 로직 제거: 무조건 최초 시작일 기준
    
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
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF2F54EB), fontWeight: FontWeight.w600)),
          Text('D+${dDays}', style: const TextStyle(fontSize: 18, color: Color(0xFF2F54EB), fontWeight: FontWeight.bold)),
        ],
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
        return Text(day, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500));
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    final daysInMonth = lastDayOfMonth.day;
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    
    List<Widget> dayWidgets = [];
    
    // Padding
    for (int i = 0; i < firstDayOfWeek; i++) {
       dayWidgets.add(const SizedBox());
    }
    
    // Days
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDay = DateTime(_focusedDay.year, _focusedDay.month, day);
      final isSelected = DateUtils.isSameDay(currentDay, _selectedDay);
      final isToday = DateUtils.isSameDay(currentDay, DateTime.now());
      final isFuture = currentDay.isAfter(DateTime.now());

      // Status Logic Mapping
      String status = 'NONE';
      bool principle = false;
      bool daily = false;
      
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDay);
      if (_recordData.containsKey(dateStr)) {
          principle = _recordData[dateStr]!['principle'] ?? false;
          daily = _recordData[dateStr]!['daily'] ?? false;
          
          if (principle && daily) status = 'SUCCESS';       
          else if (principle || daily) status = 'MISSED';   
          else status = 'FAILURE';              
      }

      dayWidgets.add(
        GestureDetector(
          onTap: isFuture ? null : () {
            setState(() => _selectedDay = currentDay);

          },
          child: Container(
            alignment: Alignment.center,
            child: _buildDayContent(currentDay, status, principle, daily, currentDay.weekday % 7, isToday, isFuture, isSelected),
          ),
        ),
      );
    }

    final currentSpacing = 6.0 - (_expansionAnimation.value * 5.5);
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
              if (rowItems.length < 7)
                ...List.generate(7 - rowItems.length, (index) => const Expanded(child: SizedBox())),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayContent(DateTime dayDate, String status, bool principle, bool daily, int weekDay, bool isToday, bool isFuture, bool isSelected) {
    Color textColor = isFuture ? const Color(0xFFD9D9D9) : const Color(0xFF1F1F1F);
    
    // D-Day check
    final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
    final isInitial = dateStr == _resolutionDateRaw;
    final isRestart = _restartDates.contains(dateStr);
    
    // Colors
    final principleColor = const Color(0xFFFFA940); // Orange
    final dailyColor = const Color(0xFF36CFC9); // Cyan
    
    if (!isFuture) {
      if (weekDay == 0) textColor = const Color(0xFFFF4D4F);
      if (weekDay == 6) textColor = const Color(0xFF2F54EB);
    }

    // Selected or Status logic for Text Color
    if ((principle || daily) && !isFuture) {
        textColor = isSelected ? const Color(0xFF5C72EB) : Colors.white;
    }

    return AnimatedScale(
      scale: isSelected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: 75 + (_expansionAnimation.value * 35),
        ),
        padding: EdgeInsets.symmetric(
          vertical: 6, 
          horizontal: 3 * (1.0 - _expansionAnimation.value * 0.6)
        ),
        decoration: BoxDecoration(
          color: (principle || daily) ? null : (isSelected ? Colors.white : Colors.transparent),
          gradient: (principle || daily) 
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 0.5],
                colors: [
                  principle ? principleColor : (isSelected ? Colors.white : Colors.transparent),
                  daily ? dailyColor : (isSelected ? Colors.white : Colors.transparent),
                ],
              )
            : null,
          borderRadius: BorderRadius.circular(12),
          border: isInitial 
            ? Border.all(color: const Color(0xFFADC6FF), width: 2.0)
            : (isSelected 
                ? Border.all(color: const Color(0xFF5C72EB), width: 2.0)
                : null),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF5C72EB).withOpacity(0.12),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: Column(
          children: [
             // D-Day Label
            if (isInitial && !isFuture)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.flag,
                        size: 8,
                        color: Color(0xFF2F54EB),
                      ),
                      SizedBox(width: 0.5),
                      Text(
                        '시작',
                        style: TextStyle(
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
            Text(
              '${dayDate.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF5C72EB) : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCheckSection() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final record = _recordData[dateStr];
    bool principleKept = record?['principle'] ?? false;
    bool dailyKept = record?['daily'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          '${_selectedDay.month}월 ${_selectedDay.day}일 (${_getWeekDayStr(_selectedDay.weekday)})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
        ),
        const SizedBox(height: 16),
        _buildCheckItem(
          title: '원칙 유지',
          desc: '가족 원칙을 잘 지켰나요?',
          isChecked: principleKept,
          color: const Color(0xFFFFA940), // Orange
          onChanged: (val) => _updateRecord(dateStr, 'principle', val),
        ),
        const SizedBox(height: 12),
        _buildCheckItem(
          title: '일상 유지',
          desc: '나의 일상을 잘 살았나요?',
          isChecked: dailyKept,
          color: const Color(0xFF36CFC9), // Green
          onChanged: (val) => _updateRecord(dateStr, 'daily', val),
        ),
      ],
    );
  }

  String _getWeekDayStr(int weekday) {
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      return days[weekday - 1];
  }

  Widget _buildCheckItem({
    required String title,
    required String desc,
    required bool isChecked,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border(left: BorderSide(color: isChecked ? color : Colors.grey.withOpacity(0.3), width: 4)),
      ),
      child: Row(
        children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isChecked ? color : Colors.grey).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.star, color: isChecked ? color : Colors.grey, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                ),
            ),
            Switch(
                value: isChecked,
                activeColor: color,
                onChanged: onChanged,
            ),
        ],
      ),
    );
  }

  Future<void> _updateRecord(String date, String type, bool value) async {
    if (widget.userData == null) return;
    
    // Optimistic Update
    setState(() {
       _recordData.putIfAbsent(date, () => {});
       _recordData[date]![type] = value;
    });

    final uid = widget.userData!['uid'] ?? widget.userData!['userid'];
    await ApiService.saveFamilyDailyLog(uid, date, type, value);
  }





  // Detailed Feedback Texts



}
