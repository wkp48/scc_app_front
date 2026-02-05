import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Added
import '../services/api_service.dart'; // 추후 연동
import 'family_growth_checklist_modal.dart'; // Added
import 'widgets/family_growth_status_card.dart';


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
  Map<String, dynamic>? _todayGrowthData; // [Added] Mock data storage for today


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
    // Fetch checklist for today (or selected day)
    _fetchGrowthChecklist(_selectedDay);
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchGrowthChecklist(DateTime date) async {
    if (widget.userData == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final uid = widget.userData!['uid'] ?? widget.userData!['userid'];
    
    final response = await ApiService.getFamilyGrowthChecklist(uid, dateStr);
    
    if (mounted) {
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        // Backend returns integer fields (0-10)
        setState(() {
          _todayGrowthData = {
            '재정관리': data['financial'],
            '통제욕구': data['control'],
            '건강한 대화': data['conversation'],
            '건강한 피드백': data['feedback'],
            '신체지표': data['physical'],
            '대인관계 지표': data['interpersonal'],
            '정서지표': data['emotional'],
            '사고지표': data['cognitive'],
          };
        });
      } else {
        setState(() {
          _todayGrowthData = null; 
        });
      }
    }
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
                              const SizedBox(height: 16),
                              _buildGrowthStatusCard(),
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
          // D-Day Badge
           _buildDDayBadge(),
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
            _fetchGrowthChecklist(currentDay);
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

  // 0: 가족 역할, 1: 개인 회복
  int _selectedGraphTab = 0;
  String _selectedDetailCategory = '재정관리'; // [Added] Default
  bool _isGrowthCardExpanded = false; // [Added] Expansion State

  Widget _buildGrowthStatusCard() {
    return FamilyGrowthStatusCard(
      userData: widget.userData ?? {},
      date: DateFormat('yyyy-MM-dd').format(_selectedDay),
      onRefresh: () {
        _fetchMonthlyData();
      },
    );
  }

  Widget _buildTabButton(String text, int index) {
      final bool isSelected = _selectedGraphTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedGraphTab = index;
              // Reset detail category to first item of new list
              if (index == 0) {
                 _selectedDetailCategory = '재정관리';
              } else {
                 _selectedDetailCategory = '신체지표';
              }
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

  Widget _buildGrowthGraph() {
    // Safely handle the map as Map<String, dynamic> and cast values individually
    final Map<String, dynamic> scores = _todayGrowthData ?? {};
   
    List<String> categories;
    List<String> categoryKeys;
   
    if (_selectedGraphTab == 0) {
      // 가족 역할
      categories = ['재정관리', '통제욕구', '건강한대화', '건강한피드백'];
      categoryKeys = ['재정관리', '통제욕구', '건강한 대화', '건강한 피드백'];
    } else {
      // 개인 회복
      categories = ['신체', '대인관계', '정서', '사고'];
      // Keys from checklist modal
      categoryKeys = ['신체지표', '대인관계 지표', '정서지표', '사고지표'];
    }

    // Safely extract values as doubles
    final List<double> values = categoryKeys.map((key) {
      final val = scores[key];
      if (val is num) return val.toDouble();
      return 0.0; 
    }).toList();

    const Color primaryColor = Color(0xFF5C72EB); 

    Widget buildLabel(String labelText, String key, Alignment alignment) {
       final val = scores[key];
       double score = (val is num) ? val.toDouble() : 0.0;
       int displayScore = score.toInt();
       
       return Align(
           alignment: alignment,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 labelText,
                  style: const TextStyle(
                     color: Color(0xFF555555),
                     fontSize: 13,
                     fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
               ),
               Text(
                 '$displayScore점',
                 style: const TextStyle(
                     color: primaryColor,
                     fontSize: 12,
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
               padding: const EdgeInsets.all(40.0), // increased padding so labels don't overlap
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
           // Order: Top, Right, Bottom, Left for 4 items in fl_chart logic
           buildLabel(categories[0], categoryKeys[0], Alignment.topCenter),
           buildLabel(categories[1], categoryKeys[1], Alignment.centerRight),
           buildLabel(categories[2], categoryKeys[2], Alignment.bottomCenter),
           buildLabel(categories[3], categoryKeys[3], Alignment.centerLeft),
       ],
     ),
   );
 }

  // Feedback Text Definitions
  final Map<String, Map<String, String>> _feedbackTexts = {
    '가족 역할': {
      '주의 상태': '지금은 중독자와의 관계에서 많이 지치고, 혼란스러운 감정이 반복될 수 있어요.\n내가 뭘 해도 바뀌지 않는다는 무력감이나 과도한 책임감이 교차할 수 있습니다.\n이럴수록 중요한 건, 중독자를 바꾸겠다라는 생각보다 내가 변화 할 수 있는 부분을 찾아 실천해 나가는 겁니다.\n낙담하지 마시고 할 수 있는 것을 시작해 주세요',
      '성장 노력 상태': '가족 안에서 건강한 역할을 회복하려는 노력과 변화가 조금씩 시작되고 있어요.\n때때로 중독자를 통제하고 싶은 마음이 올라올 수 있지만, 그럴 때마다 자신을 돌아보려는 태도 자체가 회복에 큰 힘이 됩니다.\n지금처럼 건강한 피드백과 감정 조절 연습을 이어간다면, 서로 간의 관계도 한결 더 편안하고 따뜻하게 변화될 수 있어요',
      '안정유지 상태': '중독자의 회복 과정에 과도하게 휘둘리지 않고, 스스로 건강한 거리와 태도를 잘 유지하고 계시네요.\n지지와 회복에 도움이 되는 피드백도 따뜻하게 전달할 수 있는 능력이 자리잡아가고 있어요.\n지금처럼 가족으로서의 경계, 표현, 돌봄의 균형을 잘 이어가 주세요',
    },
    '개인 회복': {
      '주의 상태': '몸도 마음도 지쳐 있고, 혼자 버텨야 한다는 고립감과 긴장이 쌓였을 수 있어요.\n감정이 예민하거나 부정적인 생각이 반복되면, 자기돌봄보다 중독자의 문제에 다시 매몰될 위험이 커집니다.\n지금은 내 감정부터 살피고, 일상의 흐름을 회복하는 것이 가장 중요합니다.',
      '성장 노력 상태': '감정이나 생각을 알아차리고 조절해보려는 노력과 꾸준한 일상 실천이 조금씩 자리 잡아가고 있어요.\n산책이나 누군가와 대화를 시도하는 등 일상의 회복을 위한 꾸준한 노력이 내 삶을 변화시킬 수 있는 밑거름이 됩니다.\n아직 마음이 흔들릴 때도 있지만, 내 삶을 되찾으려는 회복의 힘이 서서히 자라나고 있는 중이에요',
      '안정유지 상태': '지금의 흐름 속에서 스스로를 잘 돌보고, 감정을 조절하며, 관계도 안정적으로 이어가고 계시네요.\n회복은 중독자의 상태와 무관하게, \'내 삶의 균형\'을 지켜가는 힘에서 시작됩니다.\n지금처럼 나에게 맞는 돌봄과 건강한 관계 맺기를 꾸준히 이어가 주세요. 그 리듬이 곧 회복의 기반이 되어 줄 거예요.',
    }
  };

  Map<String, dynamic> _getFeedbackStatus(String domain, Map<String, dynamic> scores) {
    List<String> subCategories;
    if (domain == '가족 역할') {
      subCategories = ['재정관리', '통제욕구', '건강한 대화', '건강한 피드백'];
    } else {
      subCategories = ['신체지표', '대인관계 지표', '정서지표', '사고지표'];
    }

    double totalScore = 0;
    double minSubScore = 11; // Max is 10

    for (var key in subCategories) {
      double score = (scores[key] as num?)?.toDouble() ?? 0.0;
      totalScore += score;
      if (score < minSubScore) minSubScore = score;
    }

    // Logic from image
    String status = '주의 상태';
    Color color = const Color(0xffFF5252); // Red

    if (totalScore >= 34 && minSubScore > 7) {
      status = '안정유지 상태';
      color = const Color(0xff4CAF50); // Green
    } else if (totalScore >= 24 && minSubScore > 4) {
       status = '성장 노력 상태';
       color = const Color(0xff2196F3); // Blue
    } else {
       status = '주의 상태';
       color = const Color(0xffFF5252);
    }
    
    return {'status': status, 'color': color, 'total': totalScore};
  }

  Widget _buildGrowthProcessBar() {
    final Map<String, dynamic> scores = _todayGrowthData ?? {};
    final String domain = _selectedGraphTab == 0 ? '가족 역할' : '개인 회복';
    final statusData = _getFeedbackStatus(domain, scores);
    final String currentStatus = statusData['status'];

    final List<String> steps = ['주의 상태', '성장 노력 상태', '안정유지 상태'];
    final List<String> labels = ['주의', '성장 노력', '안정 유지']; 

    return Container(
      width: double.infinity,
      height: 36,
      margin: const EdgeInsets.only(right: 32), // Move whole bar left
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final bool isActive = currentStatus == steps[index];
          Color activeBackgroundColor = Colors.transparent;
          Color textColor = const Color(0xFFBDBDBD);
          FontWeight fontWeight = FontWeight.normal;

          if (isActive) {
             if (index == 0) activeBackgroundColor = const Color(0xffFF5252);
             else if (index == 1) activeBackgroundColor = const Color(0xff2196F3);
             else activeBackgroundColor = const Color(0xff4CAF50);
             
             textColor = Colors.white;
             fontWeight = FontWeight.bold;
          }

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeBackgroundColor,
                borderRadius: BorderRadius.circular(0),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final Map<String, dynamic> scores = _todayGrowthData ?? {};
    final String domain = _selectedGraphTab == 0 ? '가족 역할' : '개인 회복';
    
    final statusData = _getFeedbackStatus(domain, scores);
    final String status = statusData['status'];
    final Color color = statusData['color'];
    final String feedback = _feedbackTexts[domain]?[status] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.psychology_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '종합 피드백',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: Colors.grey[600]
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: color
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0x1A000000)),
          const SizedBox(height: 16),
          Text(
            feedback,
            style: const TextStyle(
              fontSize: 14, 
              height: 1.6, 
              color: Color(0xFF424242)
            ),
          ),
        ],
      ),
    );
  }

  // Detailed Feedback Texts
  final Map<String, Map<String, String>> _detailedFeedbackTexts = {
    // --- 가족 역할 ---
    '재정관리': {
      '주의 상태': '지금은 재정 지원을 반복하기 쉬운 시기지만, 이는 회복에 도움이 되기보다 도박을 지속시킬 수 있습니다. 회복은 고통을 대신 해주는 것이 아니라, 당사자가 스스로 마주할 수 있도록 돕는 과정입니다. 조금 힘들더라도 재정관리 원칙을 세우고 지켜주세요',
      '성장 노력 상태': '돈을 직접 주는 건 피하지만 여전히 감정에 따라 흔들릴 수 있는 단계입니다. 지금은 도박자가 책임감을 가질 수 있도록 재정 경계를 연습해 나가야 할 시기이며, \'돈\'이 강한 갈망을 자극할 수 있다는 점을 기억해 주세요.',
      '안정유지 상태': '재정관리를 잘 유지하고 계시군요! 감정에 흔들리지 않고 재정 원칙을 지키며, 회복자에게 경제적 자립의 방향을 잘 전달하고 있습니다.',
    },
    '통제욕구': {
      '주의 상태': '도박중독 당사자를 통제하고 싶은 마음이 여전히 크게 느껴지실 수 있어요. 그럴수록 내 불안이 통제 욕구로 이어진다는 점을 기억해 주세요. 통제하거나 감시하는 것은 가족의 몫이 아닙니다.',
      '성장 노력 상태': '지금은 관계를 회복하고자 시도하는 변화의 과정입니다. \'지켜보기\'와 \'개입하기\'의 균형을 잡는 연습이 필요해요. 감정을 조절하고, 회복자의 책임을 존중하며 함께 걸어가는 법을 익혀보세요',
      '안정유지 상태': '회복의 기반이 안정된 상태예요. 중독자와의 신뢰 관계를 유지하며, 감정에 휘둘리지 않고 건강한 거리두기를 실천하고 계십니다. 지금처럼 \'내 감정도 돌보며, 상대를 존중하는 태도\'를 지속해 주세요',
    },
    '건강한 대화': {
      '주의 상태': '지금은 대화를 통해 회복을 돕기보다, 감정이 앞서며 관계가 단절될 수 있는 시기입니다. 대화는 \'설득\'이나 \'통제\'가 아닌, 서로를 이해하기 위한 연결 통로입니다. 나의 감정부터 알아차리는 연습을 시작해 보세요.',
      '성장 노력 상태': '지금은 건강한 대화를 연습해 나가는 시기로, 완벽하지 않아도 괜찮습니다. 중요한 건 말을 많이 하기보다 진심으로 들어주는 태도이며, 실수는 감정을 함께 다루려는 노력이 회복에 큰 도움이 됩니다.',
      '안정유지 상태': '지금은 서로를 존중하며 편안하게 대화할 수 있는 단계로, 따뜻한 소통이 회복자의 신뢰를 더 깊게 만들어줍니다. 이 흐름을 잘 이어가 주세요',
    },
    '건강한 피드백': {
      '주의 상태': '지금은 도박자의 노력이 눈에 잘 들어오지 않을 수 있습니다. 그러나 작은 변화라도 \'지켜봐주고, 알아봐주는 사람\'이 있다는 느낌이 회복의 큰 힘이 됩니다. 결과보다 과정을 살펴보는 시선을 조금씩 연습해 보세요.',
      '성장 노력 상태': '회복자의 변화에 관심을 갖고 반응하려는 연습이 시작되셨군요! 완벽하지 않아도 괜찮아요. 진심 어린 인정은 말 한마디로도 충분합니다. 지금의 시도 자체가 매우 의미 있습니다.',
      '안정유지 상태': '회복자의 변화에 진심으로 반응하며 신뢰를 쌓아가는 과정이 자리잡아 가고 있습니다. 지금의 따뜻한 응원이 계속 이어질 수 있도록 자신도 함께 돌봐야 한다는 사실을 잊지 마세요.',
    },
    // --- 개인 회복 ---
    '신체지표': {
      '주의 상태': '지금은 몸보다 마음이 더 지쳐 있을 수 있어요. 하지만 단 10분의 산책만으로도 내 감정과 생각이 훨씬 부드러워질 수 있습니다. 지금 이 자리에서 움직여 보는 것부터 시작해 보세요',
      '성장 노력 상태': '조금씩 몸을 움직여 보려는 시도가 있으셨군요! 중요한 건 자주 하는 것보다 \'잊지 않고 나를 돌아보는 습관\'을 만드는 거예요. 한 번의 실천이 나를 회복의 길로 다시 데려옵니다.',
      '안정유지 상태': '지금은 몸을 돌보는 일상의 규칙이 자리를 잡아가고 있어요. 회복은 마음만이 아니라 몸에서부터 시작된다는 것을 기억하고, 이 흐름을 잘 이어나가 주세요.',
    },
    '대인관계 지표': {
      '주의 상태': '지금은 너무 힘이들어, 관계를 피하거나 닫아둘 수 있어요. 그러나 회복은 연결 속에서 이루어 집니다. 작은 안부 인사, 짧은 전화 한 통이 회복의 문을 여는 시작이 될 수 있어요',
      '성장 노력 상태': '이제 관계를 조금씩 회복하려는 시도가 시작되고 있어요. 완벽하지 않아도 괜찮아요. \'그냥 함께하는 시간\' 자체가 큰 의미입니다. 너무 많은 걸 기대하기보다 \'연결감\' 자체를 느끼는 데 집중해보세요',
      '안정유지 상태': '지금은 관계 속에서 나를 지키면서도 따뜻하게 연결되어 있으시군요! 혼자가 아니라는 경험은 회복을 지탱하는 큰 자원이 됩니다. 지금의 관계 흐름을 소중히 지켜가 주세요',
    },
    '정서지표': {
      '주의 상태': '지금은 감정이 쌓여서 쉽게 무기력해지거나 분노가 앞설 수 있어요. 감정을 억누르기보다, 잠깐 멈추고 나의 마음을 들여다보는 시간이 필요합니다. 호흡부터 천천히 시작해보세요. 감정을 다룰 수 있다는 믿음이 회복의 시작이에요.',
      '성장 노력 상태': '감정을 억누르지 않고, 천천히 들여다보려는 시도를 잘 이어가고 계세요. 완벽하지 않아도 괜찮아요. 중요한 건 내가 감정을 다룰 수 있다는 \'경험\'을 조금씩 쌓아가는 것입니다.',
      '안정유지 상태': '감정을 건강하게 바라보고, 조절하고, 흘려보내는 힘이 잘 자리 잡아가고 있어요. 이 회복된 감정 리듬이 내 삶뿐만 아니라 가족 전체를 지켜주는 보호막이 됩니다. 지금의 마음 돌봄을 소중히 이어가 주세요.',
    },
    '사고지표': {
      '주의 상태': '지금은 부정적인 생각이 마음을 지배할 수 있는 시기입니다. 그 생각이 \'사실인지\' 아니면 \'감정에 따른 해석인지\' 구분해보는 연습부터 시작해보세요. 생각은 감정처럼 흘러가고, 우리는 그것을 관찰할 수 있어요',
      '성장 노력 상태': '지금은 생각의 자동 반응에서 벗어나려는 중요한 시점입니다. 완벽히 바꾸려 하지 않아도 괜찮아요. 다르게 바라보려는 태도만으로도 사고의 흐름은 달라질 수 있습니다. \'이건 내 생각일 뿐\'이라는 문장을 기억해보세요',
      '안정유지 상태': '지금은 생각에 휘둘리기보다 스스로 선택하는 힘이 커진 상태입니다. 사고의 균형은 감정의 균형으로, 결국 관계의 균형으로 이어집니다. 지금처럼 나의 생각을 들여다보고, 조율하는 힘을 잘 이어가 주세요.',
    },
  };

  Widget _buildDetailedFeedback() {
    // Determine categories based on tab
    final List<String> categories = _selectedGraphTab == 0
      ? ['재정관리', '통제욕구', '건강한 대화', '건강한 피드백']
      : ['신체지표', '대인관계 지표', '정서지표', '사고지표'];

    // Ensure _selectedDetailCategory is valid for current tab
    String currentCategory = _selectedDetailCategory;
    if (!categories.contains(currentCategory)) {
        currentCategory = categories[0];
    }
    
    // Get score
    double score = 0;
    if (_todayGrowthData != null && _todayGrowthData!.containsKey(currentCategory)) {
       score = (_todayGrowthData![currentCategory] as num).toDouble();
    }
    
    // Determine Status
    String status = '주의 상태';
    Color statusColor = const Color(0xffFF5252);
    String scoreRange = '(4점 이하)';
    
    if (score >= 8) {
       status = '안정유지 상태';
       statusColor = const Color(0xff4CAF50);
       scoreRange = '(8~10점)';
    } else if (score >= 5) {
       status = '성장 노력 상태';
       statusColor = const Color(0xff2196F3); // Blue
       scoreRange = '(5~7점)';
    } else {
       status = '주의 상태';
       statusColor = const Color(0xffFF5252);
       scoreRange = '(4점 이하)';
    }
    
    final String feedback = _detailedFeedbackTexts[currentCategory]?[status] ?? '피드백을 불러올 수 없습니다. ($currentCategory / $status)';

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
            // Category Tabs
            SizedBox(
              width: double.infinity,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = currentCategory == cat;
                  // Remove '지표' and '건강한' for display
                  String displayName = cat.replaceAll('지표', '').replaceAll('건강한', '').trim();
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0), // items gap
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDetailCategory = cat;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF5C72EB) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF5C72EB) : Colors.grey[300]!,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Slightly smaller to fit
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                    currentCategory,
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
                                        status,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        Text(
                            feedback,
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
}
