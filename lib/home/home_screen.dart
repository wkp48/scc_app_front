import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/repayment_logic.dart';
import '../utils/toast_utils.dart';
import 'calendar_screen.dart';
import 'self_development_screen.dart';
import 'alarm_screen.dart';
import '../training/training_screen.dart'; // Added: TrainingScreen import
import 'activity_record_modal.dart';
import '../utils/tutorial_util.dart'; // Added: TutorialUtil
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // Added: TutorialCoachMark
import 'profile_screen.dart';
import '../utils/page_route_util.dart';
import 'diagnosis_history_screen.dart';
import 'diagnosis_survey_screen.dart';
import 'chatbot_screen.dart';
import 'notice_screen.dart'; // Added: Import NoticeScreen
import 'task_list_screen.dart'; // Added: Import TaskListScreen
import 'dart:convert'; // Added for base64Decode
import '../family/family_home_screen.dart'; // Added: Family Home Screen import
import 'daily_checklist_modal.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/recovery_trend_card.dart'; // [Added]
import 'daily_checklist_card.dart';
import 'notice_create_modal.dart';
import 'debt_details_modal.dart'; // Added: Import DebtDetailsModal
import 'dart:math' as math;


class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _missions = [];
  Map<String, dynamic>? _latestNotice; // Added: Latest notice data
  int _currentIndex = 0; // 추가: 탭 인덱스
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _baseUrl;
  final GlobalKey<DailyChecklistCardState> _checklistCardKey = GlobalKey();

  Map<String, dynamic>? _debtData;
  double _monthlyTotal = 0;
  double _remainingTotal = 0;

  // Tutorial Keys
  final GlobalKey _dDayCardKey = GlobalKey();
  final GlobalKey _financeCardKey = GlobalKey();
  // _checklistCardKey is already defined
  final GlobalKey _navCalendarKey = GlobalKey();
  final GlobalKey _navSelfDevKey = GlobalKey();
  final GlobalKey _navTrainingKey = GlobalKey();

  bool get _hasRecentNotice {
    if (_latestNotice == null) return false;
    final dateStr = _latestNotice!['createAt'] ?? _latestNotice!['createdAt'];
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr.toString());
      final difference = DateTime.now().difference(date);
      // Allow for up to 1 day in the "future" to account for clock sync issues
      return (difference.inDays <= 7 && difference.inDays >= -1);
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _pendingMaximData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchLatestNotice();
    _fetchDebtData();
    _fetchBaseUrl();
    _checkAndShowAttendanceDialog();
    NotificationService().registerUserToken(widget.userData['uid']);
    _setupMaximNotificationListener();
    NotificationService().registerUserToken(widget.userData['uid']);
    _setupMaximNotificationListener();
    _initTutorial();
  }
  
  void _initTutorial({bool force = false}) {
    // 튜토리얼 대상이 되는 위젯들이 렌더링 된 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // 대상자용 튜토리얼 타겟 설정
       List<TargetFocus> targets = [];

       // 1. 단도박 D-Day 카드
       targets.add(TutorialUtil.createTarget(
         identify: 'd_day_card',
         key: _dDayCardKey,
         title: '단도박 시작일 확인',
         description: '단도박 시작일을 설정하고 경과 시간을 확인해보세요.\n클릭하여 날짜를 수정할 수 있습니다.',
         align: ContentAlign.bottom,
       ));
       
       // 2. 자금 관리 카드 (데이터가 있는 경우에만 표시되므로 체크 필요)
       if (_debtData != null) {
          targets.add(TutorialUtil.createTarget(
           identify: 'finance_card',
           key: _financeCardKey,
           title: '체계적인 자금 관리',
           description: '남은 부채와 이번 달 상환 예정 금액을 한눈에 확인하세요.\n클릭하여 상세 내역을 관리할 수 있습니다.',
           align: ContentAlign.bottom,
         ));
       }

       // 3. 오늘의 마음 상태 (체크리스트)
       targets.add(TutorialUtil.createTarget(
         identify: 'checklist_card',
         key: _checklistCardKey,
         title: '매일의 마음 기록',
         description: '오늘의 기분, 충동, 수면 만족도 등을 기록하고\n나의 회복 상태를 점검해보세요.',
         align: ContentAlign.top,
       ));

       // 4. 하단 탭 안내 (캘린더)
       targets.add(TutorialUtil.createTarget(
         identify: 'nav_calendar',
         key: _navCalendarKey,
         title: '캘린더',
         description: '매일의 기록과 활동 내역을 달력에서 확인하세요.',
         align: ContentAlign.top,
         shape: ShapeLightFocus.Circle,
       ));

       // 튜토리얼 실행
       if (targets.isNotEmpty) {
         TutorialUtil.checkAndShowTutorial(context, targets: targets, force: force);
       }
    });
  }

  void _setupMaximNotificationListener() {
    // 0. 초기화 시 NotificationService에 보관된 격언이 있는지 확인 (Terminate/Background 상태에서 클릭 시 대응)
    final pendingMaxim = NotificationService().pendingMaxim;
    if (pendingMaxim != null) {
      debugPrint('=== [MAXIM-HOME] Found pending maxim in NotificationService ===');
      
      // 약간의 딜레이 후 데이터 처리 (화면 빌드 안정화)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           _handleMaximMessage(RemoteMessage(data: pendingMaxim));
           NotificationService().clearPendingMaxim();
        }
      });
    }

    // 1. 스트림 리스너 (포그라운드, 백그라운드 클릭 등 NotificationService가 전파하는 모든 격언)
    NotificationService().onMaximReceived.listen((data) {
      if (mounted) {
        _handleMaximMessage(RemoteMessage(data: data));
      }
    });
  }

  void _handleMaximMessage(RemoteMessage message) {
    // 1. 데이터 정규화
    Map<String, dynamic> data = Map<String, dynamic>.from(message.data);
    // 중첩 데이터 처리
    if (data.containsKey('data') && data['data'] is Map) {
      final nested = data['data'] as Map;
      nested.forEach((key, value) => data[key.toString()] = value);
    }
    
    // 2. 타입 및 컨텐츠 확인
    final String? type = data['type']?.toString().toUpperCase();
    String? content = data['content'];
    String? author = data['author'];

    // 3. Fallback: 데이터에 컨텐츠가 없으면 알림 본문을 사용 (격언 알림이라고 가정)
    if (content == null && message.notification?.body != null) {
      // 만약 type이 MAXIM이거나, id가 없어서 알람이 아닌 것 같으면 본문을 사용
      if (type == 'MAXIM' || !data.containsKey('id')) {
        content = message.notification!.body;
        // debugPrint('=== [HOME] Using Notification Body as Content ===');
      }
    }

    // 4. 격언 여부 최종 판단
    final bool isMaxim = (type == 'MAXIM') || 
                        (content != null && !data.containsKey('id')); // ID가 없으면 알람이 아님 -> 격언으로 간주
    


    if (isMaxim && content != null) {
      setState(() {
        _pendingMaximData = {
          'content': content,
          'author': author,
        };
      });



    } else {
      // debugPrint('=== [HOME] Not a maxim notification or no content ===');
      

    }
  }

  Future<void> _fetchBaseUrl() async {
    final url = await ApiService.baseUrl;
    if (mounted) {
      setState(() {
        _baseUrl = url;
      });
    }
  }

  // Added: Helper to fetch latest notice
  Future<void> _fetchLatestNotice() async {
    try {
      final result = await ApiService.getNotices();
      if (mounted && result['success'] == true) {
        final List<dynamic> notices = result['data'];
        if (notices.isNotEmpty) {
          setState(() {
            _latestNotice = notices.first;
          });
        }
      }
    } catch (e) {
      print('Failed to fetch notices for home screen: $e');
    }
  }

  
  String _getAbsoluteUrl(String path) {
    if (path.startsWith('data:image')) return path;
    if (path.startsWith('http')) return path;
    
    
    final String effectiveBaseUrl = _baseUrl ?? 'http://192.168.0.75:8900/api';
    
    String url;
    if (effectiveBaseUrl.endsWith('/api') && path.startsWith('/api')) {
      url = effectiveBaseUrl.substring(0, effectiveBaseUrl.length - 4) + path;
    } else if (!path.startsWith('/')) {
      url = '$effectiveBaseUrl/$path';
    } else {
      url = '$effectiveBaseUrl$path';
    }
    return Uri.encodeFull(url);
  }

  Future<void> _checkAndShowAttendanceDialog() async {
    // Only show for SUBJECT users or ADMIN (for testing)
    if (widget.userData['userType'] != 'SUBJECT' && widget.userData['userType'] != 'ADMIN') return;

    final checkResult = await ApiService.checkTodayAttendance(widget.userData['uid']);
    if (checkResult['success'] == true && checkResult['hasAttendance'] == false) {
      if (mounted) {
        // 출석 체크 다이얼로그 표시 후, 닫히면 일일 체크리스트 확인
        await _showAttendanceDialog();
        if (mounted) _checkAndShowDailyChecklist();
      }
    } else {
      // 이미 출석했으면 바로 일일 체크리스트 확인
       if (mounted) _checkAndShowDailyChecklist();
    }
  }

  Future<void> _checkAndShowDailyChecklist() async {
    // 대상자(SUBJECT) 또는 관리자(ADMIN)인 경우에만 표시
    if (widget.userData['userType'] != 'SUBJECT' && widget.userData['userType'] != 'ADMIN') return;

    final checkResult = await ApiService.checkTodayDailyChecklist(widget.userData['uid']);
    if (checkResult['success'] == true && checkResult['data'] == false) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false, // 강제로 작성하도록 유도 (필요시 true로 변경)
          builder: (context) => DailyChecklistModal(userData: widget.userData),
        ).then((result) {
          if (result == true) {
            _fetchDashboardData();
            _checklistCardKey.currentState?.refresh();
            _calendarKey.currentState?.loadMonthlyAttendance();
          }
        });
      }
    }
  }

  Future<void> _fetchMissions() async {
    final result = await ApiService.getMissions(widget.userData['uid']);
    if (result['success'] == true && mounted) {
      setState(() {
        _missions = result['data'];
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    _fetchLatestNotice(); 
    _fetchDebtData(); 
    _fetchMissions(); // Added: Fetch missions for the dashboard
    final response = await ApiService.getHomeDashboard(widget.userData['uid']);
    if (response['success'] == true) {
      if (mounted) {
        setState(() {
          _dashboardData = response['data'];
          _isLoading = false;
        });
        // 대시보드 데이터 갱신 시 캘린더도 함께 갱신
        _calendarKey.currentState?.loadMonthlyAttendance();
        
        _checklistCardKey.currentState?.refresh();
      }
    } else {
      // 에러 처리
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playLatestPositiveSelfVoice() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    final response = await ApiService.getLatestVoiceRecord(
      widget.userData['uid'], 
      'POSITIVE_SELF'
    );

    if (response['success'] == true && response['data'] != null) {
      final voicePath = response['data']['voiceFilePath'];
      if (voicePath != null) {
        final url = '${await ApiService.baseUrl}/activities/images/$voicePath';
        try {
          setState(() => _isPlaying = true);
          await _audioPlayer.play(UrlSource(url));
          _audioPlayer.onPlayerComplete.listen((event) {
            if (mounted) setState(() => _isPlaying = false);
          });
        } catch (e) {
          if (mounted) {
            ToastUtils.show(context, '음성 재생 중 오류가 발생했습니다.');
            setState(() => _isPlaying = false);
          }
        }
      } else {
        if (mounted) {
          ToastUtils.show(context, '최근 녹음된 희망 리코딩이 없습니다.');
        }
      }
    } else {
      if (mounted) {
        ToastUtils.show(context, '녹음된 파일을 찾을 수 없습니다.');
      }
    }
  }

  Future<void> _selectResolutionDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C72EB),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String formattedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      final response = await ApiService.updateResolutionDate(widget.userData['uid'], formattedDate);
      
      if (response['success'] == true) {
        if (mounted) {
          ToastUtils.show(context, '단도박 시작일이 수정되었습니다.');
          _fetchDashboardData();
        }
      } else {
        if (mounted) {
          ToastUtils.show(context, response['message'] ?? '수정에 실패했습니다.');
        }
      }
    }
  }

  Future<void> _showResolutionHistoryModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResolutionHistoryBottomSheet(
        userData: widget.userData,
        dashboardData: _dashboardData,
        onEditInitial: () {
          Navigator.pop(context);
          _selectResolutionDate();
        },
        onRefresh: _fetchDashboardData,
      ),
    );
  }

  DateTime? _currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    // [가족 페이지 분기 처리]
    // UserType이 FAMILY이거나, ADMIN이면서 adminViewType이 FAMILY인 경우 FamilyHomeScreen 반환
    if (widget.userData['userType'] == 'FAMILY' || 
       (widget.userData['userType'] == 'ADMIN' && widget.userData['adminViewType'] == 'FAMILY')) {
        return FamilyHomeScreen(userData: widget.userData);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        
        DateTime now = DateTime.now();
        if (_currentIndex != 0) {
          // 홈 탭이 아니면 홈 탭으로 이동
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        if (_currentBackPressTime == null || 
            now.difference(_currentBackPressTime!) > const Duration(seconds: 2)) {
          _currentBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("'뒤로' 버튼을 한번 더 누르면 종료됩니다."),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeContent(),
                CalendarScreen(
                  key: _calendarKey, 
                  userData: widget.userData,
                  onChecklistCompleted: _fetchDashboardData,
                ),
                SelfDevelopmentScreen(
                  userData: widget.userData, 
                  dashboardData: _dashboardData,
                  onRefresh: _fetchDashboardData,
                ),
                TrainingScreen(
                  userData: widget.userData,
                ),
              ],
            ),
            if (_pendingMaximData != null) _buildMaximOverlay(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: _buildFloatingCalendarButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildMaximOverlay() {
    final String content = _pendingMaximData?['content'] ?? '';
    final String? author = _pendingMaximData?['author'];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background Blur & Dim
          GestureDetector(
            onTap: () => setState(() => _pendingMaximData = null),
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Maxim Box
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_quote_rounded, color: Color(0xFF6A11CB), size: 56),
                  const SizedBox(height: 24),
                  Text(
                    content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F1F1F),
                      height: 1.5,
                      fontStyle: FontStyle.italic
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (author != null && author.isNotEmpty)
                    Text(
                      '- $author -',
                      style: TextStyle(
                        fontSize: 14, 
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _pendingMaximData = null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        '오늘도 화이팅!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // [가족 페이지 분기 처리]
    // Family view is now handled at a higher level, so this always returns the subject content.
    return _buildSubjectHomeContent();
  }

  Widget _buildSubjectHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            // [Removed] 자가진단 알림 제거 (User Request)
            // _buildDiagnosisAlert(),
            // _buildDiagnosisAlert(),
            Container(
              key: _dDayCardKey,
              child: _buildDDayCard(),
            ),
            const SizedBox(height: 24),
            if (_debtData != null) ...[
              _buildFinancialManagementCard(),
              const SizedBox(height: 24),
            ],
            
            // [Added] 오늘의 마음 상태 (User Request)
            if (widget.userData['userType'] == 'SUBJECT' || widget.userData['userType'] == 'ADMIN') ...[
              DailyChecklistCard(
                key: _checklistCardKey, 
                userData: widget.userData,
                targetDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                customTitle: '나의 현재 상태', 
                forceResultOnly: true, 
                hideFeedback: true, 
                showRecoveryTrend: true, // [Added] 회복 변화 그래프 표시
                hideExpandButton: true, // [Added] 보러가기 삭제
                onChecklistCompleted: () {
                  _fetchDashboardData(); 
                },
              ),
              const SizedBox(height: 24),
              // [Removed] 독립된 RecoveryTrendCard 제거
            ],

            // [Removed] 회복 노력 카드 제거 (User Request)
            // _buildRecoveryEffortCard(),
            // const SizedBox(height: 24),
            _buildMyTasksSection(), // Added: My Tasks Section
            const SizedBox(height: 24),
            _buildNoticePreviewSection(),
            if (widget.userData['userType'] == 'SUBJECT' || widget.userData['userType'] == 'ADMIN') ...[
              const SizedBox(height: 24),
              _buildTodayMaximSection(), // Updated: Today's Maxim Section
            ],
            const SizedBox(height: 24),
            _buildChatbotBanner(),
            const SizedBox(height: 16),
            _buildConsultationBanner(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: _dashboardData?['profileImageUrl'] != null
                    ? FutureBuilder<String>(
                        future: ApiService.baseUrl,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.network(
                              _getAbsoluteUrl('activities/images/${_dashboardData!['profileImageUrl']}'),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                  const Icon(Icons.person, color: Colors.grey),
                            );
                          }
                          return const Icon(Icons.person, color: Colors.grey);
                        },
                      )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요, ${_dashboardData?['username'] ?? widget.userData['username'] ?? widget.userData['userid']}님!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (widget.userData['userType'] == 'TEACHER' || widget.userData['userType'] == 'ADMIN')
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.userData['userType'] == 'ADMIN' 
                              ? const Color(0xFFFFF1F0) 
                              : const Color(0xFFF0F5FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.userData['userType'] == 'ADMIN' 
                                ? const Color(0xFFFFCCC7) 
                                : const Color(0xFFADC6FF)
                            ),
                          ),
                          child: Text(
                            widget.userData['userType'] == 'TEACHER' ? '선생님' : '관리자',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.userData['userType'] == 'ADMIN' 
                                ? const Color(0xFFFF4D4F) 
                                : const Color(0xFF2F54EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.userData['userType'] == 'ADMIN') ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _initTutorial(force: true),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.help_outline, size: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Text(
                    '담당선생님: ${_dashboardData?['counselorName'] ?? '미배정'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              FadePageRoute(
                page: ProfileScreen(
                  userData: widget.userData,
                  dashboardData: _dashboardData,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person_outline, size: 24, color: Colors.black),
          ),
        ),
      ],
    );
  }





  /* [Removed] 자가진단 알림 카드 메소드
  Widget _buildDiagnosisAlert() {
    if (_dashboardData?['needsDiagnosis'] != true) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C72EB), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C72EB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
            child: const Icon(Icons.notification_important, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '정기 자가진단 알림',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  '마지막 검사 후 2주가 지났습니다.\n지금 상태를 확인해보세요.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiagnosisSurveyScreen(userData: widget.userData),
                ),
              );
              if (result == true) {
                _fetchDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5C72EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text('검사하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildDDayCard() {
    return GestureDetector(
      onTap: _showResolutionHistoryModal,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flag_rounded, color: Color(0xFF2F54EB), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '단도박 시작일',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_dashboardData?['resolutionDate'] ?? '-'}',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF595959), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '단도박 유지일',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'D + ${_dashboardData?['dday'] ?? 0}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -1),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact(); // 촉각 피드백 추가
                    _selectResolutionDate();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Icon(Icons.edit_calendar_outlined, color: Colors.grey[400], size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            _buildFirstResolutionNestedCard(),
            // [Removed] 단도박 집중 시간 카드 제거 (User Request)
            // const SizedBox(height: 24),
            // _buildFocusTimeNestedCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstResolutionNestedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF5C72EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '나의 첫 결심',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '"${_dashboardData?['initialResolutionText'] ?? '나는 꼭 단도박을 할 것이다!'}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F54EB),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* [Removed] 단도박 집중 시간 카드 메소드
  Widget _buildFocusTimeNestedCard() {
    final bool isActive = _dashboardData?['focusTimeActive'] ?? false;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0F5FF) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined, 
                    color: isActive ? const Color(0xFF2F54EB) : Colors.grey, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '단도박 집중 시간',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15, 
                      color: isActive ? Colors.black : Colors.grey[600]
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFD6E4FF) : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? '활성화' : '비활성',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF2F54EB) : Colors.grey, 
                    fontSize: 11, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isActive 
              ? '지정된 단도박 집중 시간이 ${_dashboardData?['focusEndTime'] ?? '18:00'}에 종료됩니다.\n계속 노력해 주세요!'
              : '알람 설정 페이지에서 단도박 집중 시간을 설정하고 매일 같은 시간 나를 돌아보세요.',
            style: TextStyle(
              fontSize: 13, 
              color: isActive ? const Color(0xFF595959) : Colors.grey, 
              height: 1.5
            ),
          ),
        ],
      ),
    );
  }
  */

  Future<void> _fetchDebtData() async {
    final response = await ApiService.getDebtList(widget.userData['uid']);
    if (mounted && response['success']) {
      setState(() {
        _debtData = response['data'];
        final List<dynamic> debts = _debtData?['debts'] ?? [];
        // 남은 부채 금액 합계 계산 (원금+이자 포함)
        _remainingTotal = debts.fold(0.0, (sum, item) => sum + RepaymentLogic.calculateTotalRemainingRepayment(item));
        // 월 예상 납입금 합계 계산 (현재 날짜 기준 실제 기일 도래액)
        _monthlyTotal = debts.fold(0.0, (sum, item) => sum + RepaymentLogic.getMonthlyPayment(item, targetDate: DateTime.now()));
      });
    }
  }



  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  Widget _buildFinancialManagementCard() {
    return GestureDetector(
      onTap: () => _showDebtDetailsModal(),
      child: Container(
        key: _financeCardKey,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(
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
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFF5C72EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '재정 관리',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('상세보기', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, color: Colors.grey, size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Content Row (Two Columns)
            Row(
              children: [
                // Monthly Payment
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '이번 달 예상 납입금',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(_monthlyTotal).replaceAll('원', ''),
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF5C72EB)
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2.0, left: 2.0),
                            child: Text('원', style: TextStyle(fontSize: 14, color: Color(0xFF5C72EB), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[200],
                ),
                const SizedBox(width: 24),
                // Remaining Debt
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '남은 부채 총액',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(_remainingTotal).replaceAll('원', ''),
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.black87
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2.0, left: 2.0),
                            child: Text('원', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtDetailsModal() {
    if (_debtData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebtDetailsModal(
        debtData: _debtData!,
        userData: widget.userData,
        onSave: () {
          _fetchDebtData();
        },
      ),
    );
  }

  /* [Removed] 회복 노력 카드 메소드
  Widget _buildRecoveryEffortCard() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          FadePageRoute(
            page: DiagnosisHistoryScreen(userData: widget.userData),
          ),
        );
        if (result == true) {
          _fetchDashboardData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FFED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF52C41A), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '회복 노력',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('현재 수준', style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text(
                  '${_dashboardData?['recoveryLevel'] ?? 100}%',
                  style: const TextStyle(color: Color(0xFF52C41A), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_dashboardData?['recoveryLevel'] ?? 100) / 100,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF52C41A)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF52C41A), size: 18),
                const SizedBox(width: 8),
                Text(
                  _dashboardData?['recoveryStatusMessage'] ?? '건강한 습관을 유지하고 있습니다!',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF595959)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  */

  // Added: My Tasks Section
  Widget _buildMyTasksSection() {
    // 필터링: 수행 전(ASSIGNED), 진행중(IN_PROGRESS)인 것만 최신 2개 표시
    final List<dynamic> activeMissions = _missions
        .where((m) => m['status'] == 'ASSIGNED' || m['status'] == 'IN_PROGRESS')
        .take(2)
        .toList();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskListScreen(userData: widget.userData),
          ),
        );
        _fetchMissions(); // 다녀와서 갱신
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F7FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_outlined, color: Color(0xFF1890FF), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '나의 과제',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            if (activeMissions.isNotEmpty) ...[
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeMissions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final mission = activeMissions[index];
                  
                  Color taskColor;
                String statusText;
                switch (mission['status']) {
                  case 'IN_PROGRESS':
                    taskColor = const Color(0xFF5C72EB);
                    statusText = '진행중';
                    break;
                  case 'ASSIGNED':
                    taskColor = const Color(0xFFFA8C16);
                    statusText = '수행 전';
                    break;
                  case 'COMPLETED':
                    taskColor = const Color(0xFF52C41A);
                    statusText = '완료';
                    break;
                  default:
                    taskColor = Colors.grey;
                    statusText = mission['status'];
                }

                String dDayText = '';
                try {
                  final end = DateTime.parse(mission['endDate']);
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final target = DateTime(end.year, end.month, end.day);
                  final diff = target.difference(today).inDays;
                  if (diff == 0) dDayText = 'D-Day';
                  else if (diff < 0) dDayText = '기간 만료';
                  else dDayText = 'D-$diff';
                } catch (_) {}

                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskListScreen(userData: widget.userData),
                      ),
                    );
                    _fetchMissions();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: taskColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: taskColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mission['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      if (mission['status'] == 'COMPLETED' && mission['submittedAt'] != null) {
                                        try {
                                          final date = DateTime.parse(mission['submittedAt']);
                                          return Text(
                                            DateFormat('yy.MM.dd HH:mm').format(date),
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                          );
                                        } catch (_) {}
                                      }
                                      return Text(
                                        '${mission['startDate'].replaceAll('-', '.')} ~ ${mission['endDate'].replaceAll('-', '.')}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      );
                                    }
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dDayText,
                                    style: TextStyle(
                                      color: taskColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: taskColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: taskColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

  // Added: Notice Preview Section
  Widget _buildNoticePreviewSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Row(
                children: [
                   const Icon(Icons.campaign_outlined, color: Color(0xFF5C72EB), size: 24),
                   const SizedBox(width: 8),
                   const Text('공지사항', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   if (_hasRecentNotice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                   ],
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NoticeScreen(userData: widget.userData)),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    children: [
                      if (widget.userData['userType'] == 'ADMIN' || widget.userData['userType'] == 'TEACHER')
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (context) => const NoticeCreateModal(),
                              );
                              if (result == true) {
                                _fetchLatestNotice();
                              }
                            },
                            child: const Icon(Icons.add_circle_outline, color: Color(0xFF5C72EB), size: 20),
                          ),
                        ),
                      const Text('더보기', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_latestNotice != null)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NoticeScreen(userData: widget.userData)),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _latestNotice!['title'] ?? '등록된 공지가 없습니다.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_latestNotice!['createdAt'] ?? _latestNotice!['createAt']),
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('등록된 공지사항이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MM.dd').format(date);
    } catch (e) {
      return '';
    }
  }

  Widget _buildSelfDevSection() {
    final List<dynamic> pinnedActivities = _dashboardData?['pinnedActivities'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: const Text(
                '자기 계발',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            if (pinnedActivities.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 2), // 자기계발 탭으로 이동
                child: const Text('더보기 >', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (pinnedActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: const Text(
                '자기계발 페이지에서 홈화면 추가해주세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          Column(
            children: pinnedActivities.map((activity) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPinnedActivityTile(activity.toString()),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPinnedActivityTile(String type) {
    IconData icon;
    String title;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'GRATITUDE':
        icon = Icons.favorite_border;
        title = '감사 일기';
        iconColor = const Color(0xFFFF851B);
        bgColor = const Color(0xFFFFF7E6);
        break;
      case 'WALK':
        icon = Icons.wb_sunny_outlined;
        title = '일상 기록';
        iconColor = const Color(0xFF52C41A);
        bgColor = const Color(0xFFF6FFED);
        break;
      case 'IMPULSE':
        icon = Icons.flash_on;
        title = '충동 일지';
        iconColor = const Color(0xFFFF4D4F);
        bgColor = const Color(0xFFFFF1F0);
        break;
      case 'POSITIVE_SELF':
        icon = Icons.auto_awesome;
        title = '희망 리코딩';
        iconColor = const Color(0xFF722ED1);
        bgColor = const Color(0xFFF9F0FF);
        break;
      default:
        return const SizedBox.shrink();
    }

    return _buildSelfDevTile(
      icon: icon,
      title: title,
      iconColor: iconColor,
      bgColor: bgColor,
      onTap: () {
        ActivityRecordModal.show(
          context, 
          widget.userData, 
          type,
          onSaved: _fetchDashboardData,
        );
      },
    );
  }

  Widget _buildSelfDevTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
  Widget _buildTodayMaximSection() {
    return GestureDetector(
      onTap: _showMaximSettingsModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A11CB).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    '오늘의 격언 신청하기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                   SizedBox(height: 4),
                   Text(
                    '매일 정해진 시간에 격언 푸시 알림을 드립니다',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  void _showMaximSettingsModal() {
    bool isAgreed = _dashboardData?['maximAgreement'] ?? false;
    TimeOfDay selectedTime = TimeOfDay(hour: 9, minute: 0);
    
    // Parse existing time if available
    final String? existingTime = _dashboardData?['maximTime'];
    if (existingTime != null && existingTime.contains(':')) {
      final parts = existingTime.split(':');
      selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘의 격언 설정',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '매일 새로운 용기와 희망을 주는 격언을 보내드립니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  
                  // Agreement Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '격언 푸시 알림 받기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: isAgreed,
                        activeColor: const Color(0xFF5C72EB),
                        onChanged: (value) {
                          setModalState(() => isAgreed = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Time Selection
                  if (isAgreed) ...[
                    const Text(
                      '알림 시간 설정',
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedTime.format(context),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.access_time, color: Color(0xFF5C72EB)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final String timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                        final result = await ApiService.updateMaximSettings(
                          widget.userData['uid'], 
                          isAgreed, 
                          timeStr
                        );
                        
                        if (result['success'] == true) {
                          if (context.mounted) {
                            ToastUtils.show(context, '격언 설정이 저장되었습니다.');
                            Navigator.pop(context);
                            _fetchDashboardData(); // Refresh dashboard data to reflect changes
                          }
                        } else {
                          if (context.mounted) {
                            ToastUtils.show(context, result['message'] ?? '저장에 실패했습니다.');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C72EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('설정 저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildChatbotBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          FadePageRoute(
            page: ChatbotScreen(
              userData: widget.userData,
              counselorName: _dashboardData?['counselorName'],
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00B09B).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AI 상담 챗봇',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '무엇이든 물어보세요! 24시간 상담 가능',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildConsultationBanner() {
    return GestureDetector(
      onTap: () => _showConsultationDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6E85F7), Color(0xFF5C72EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C72EB).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '센터 상담',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '월-금 09:00 - 18:00 (점심 12:00 ~ 13:00)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttendanceDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_dashboardData?['username'] ?? widget.userData['username'] ?? widget.userData['userid']}님 오늘도\n단도박 잘 지키셨나요?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('매일 PM 9시 초기화', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('정말인가요?'),
                              content: const Text('오늘 정말 재발하셨나요?\n다시 한 번 생각해 보세요.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('다시 생각하기'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('재발했습니다', style: TextStyle(color: Color(0xFFFF4D4F))),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ApiService.saveAttendance(widget.userData['uid'], 'FAILURE');
                            _fetchDashboardData();
                            _calendarKey.currentState?.loadMonthlyAttendance();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D4F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('재발'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await ApiService.saveAttendance(widget.userData['uid'], 'MISSED');
                          _fetchDashboardData();
                          _calendarKey.currentState?.loadMonthlyAttendance();
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA940), // 주황색
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('실수'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await ApiService.saveAttendance(widget.userData['uid'], 'SUCCESS');
                          _fetchDashboardData();
                          _calendarKey.currentState?.loadMonthlyAttendance();
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF36CFC9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('유지'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll('-', ''),
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ToastUtils.show(context, '전화 걸기 기능을 실행할 수 없습니다.');
      }
    }
  }

  void _showConsultationDialog() {
    const String phoneNumber = '043-275-0051';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '센터 상담 연결',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                phoneNumber,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5C72EB)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: phoneNumber));
                        Navigator.pop(context);
                        ToastUtils.show(context, '전화번호가 클립보드에 복사되었습니다.');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('복사하기'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _makePhoneCall(phoneNumber);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C72EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('전화걸기'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      padding: EdgeInsets.zero,
      height: 50,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(Icons.home, _currentIndex == 0, 0),
          // 두 번째 위치로 이동한 스피커 버튼
          IconButton(
            onPressed: _playLatestPositiveSelfVoice,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying ? Icons.stop : Icons.volume_up,
              color: _isPlaying ? const Color(0xFFFF4D4F) : const Color(0xFFBFBFBF),
              size: 28,
            ),
          ),
          const SizedBox(width: 48),
          _buildNavIcon(Icons.menu_book_outlined, _currentIndex == 2, 2),
          _buildNavIcon(Icons.self_improvement, _currentIndex == 3, 3),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive, int index) {
    return IconButton(
      onPressed: () {
        setState(() {
          _currentIndex = index;
        });
        if (index == 0) {
          _fetchDashboardData();
        }
        if (index == 1) {
          _checkAndShowAttendanceDialog();
          _calendarKey.currentState?.loadMonthlyAttendance();
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        icon,
        color: isActive ? const Color(0xFF5C72EB) : const Color(0xFFBFBFBF),
        size: 28, // Restored to original size
      ),
    );
  }

  Widget _buildFloatingCalendarButton() {
    return FloatingActionButton(
      backgroundColor: _currentIndex == 1 ? const Color(0xFF5C72EB) : const Color(0xFFBFBFBF),
      onPressed: () {
        setState(() {
          _currentIndex = 1;
        });
        _checkAndShowAttendanceDialog();
        _calendarKey.currentState?.loadMonthlyAttendance();
      },
      shape: const CircleBorder(),
      elevation: 4,
      child: const Icon(
        Icons.calendar_today_outlined, 
        color: Colors.white, 
        size: 28
      ),
    );
  }
}

class _ResolutionHistoryBottomSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? dashboardData;
  final VoidCallback onEditInitial;
  final VoidCallback onRefresh;

  const _ResolutionHistoryBottomSheet({
    Key? key,
    required this.userData,
    this.dashboardData,
    required this.onEditInitial,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<_ResolutionHistoryBottomSheet> createState() => _ResolutionHistoryBottomSheetState();
}

class _ResolutionHistoryBottomSheetState extends State<_ResolutionHistoryBottomSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        ApiService.getMonthlyAttendance(widget.userData['uid'], now.year, now.month),
        ApiService.getMonthlyAttendance(widget.userData['uid'], 
            now.month == 1 ? now.year - 1 : now.year, 
            now.month == 1 ? 12 : now.month - 1),
      ]);

      List<dynamic> allAttendance = [];
      for (var res in results) {
        if (res['success']) {
          allAttendance.addAll(res['data'] as List);
        }
      }

      // 날짜순 정렬 (과거 -> 현재)
      allAttendance.sort((a, b) => a['date'].compareTo(b['date']));

      List<Map<String, dynamic>> tempHistory = [];

      // 1. 최초 시작일 파싱
      String? initialDateRaw;
      final resDate = widget.dashboardData?['resolutionDate'];
      if (resDate != null) {
        if (resDate.toString().contains('년')) {
          final parts = resDate.toString().split(' ');
          if (parts.length >= 3) {
            final y = parts[0].replaceAll('년', '').trim();
            final m = parts[1].replaceAll('월', '').trim().padLeft(2, '0');
            final d = parts[2].replaceAll('일', '').trim().padLeft(2, '0');
            initialDateRaw = '$y-$m-$d';
          }
        } else {
          initialDateRaw = resDate.toString();
        }
      }

      // 2. 서버에서 등록된 재시작일 오름차순 정렬 (과거 -> 현재)
      final List<dynamic> restartDatesRaw = widget.dashboardData?['restartDates'] ?? [];
      List<String> sortedRestartDates = List<String>.from(restartDatesRaw);
      sortedRestartDates.sort((a, b) => a.compareTo(b));

      for (int i = 0; i < sortedRestartDates.length; i++) {
        final date = sortedRestartDates[i];
        if (date != initialDateRaw) {
          tempHistory.add({
            'date': date,
            'type': 'RESTART',
            'label': '단도박 재시작 ${tempHistory.length + 1}', // 이 시점의 tempHistory 길이에 따라 번호 부여? No. 
            'description': '마음을 다잡고 다시 시작한 날입니다.',
            'color': const Color(0xFF2F54EB),
            'icon': Icons.refresh_rounded,
          });
        }
      }

      // 최초 시작일 추가
      if (initialDateRaw != null) {
        tempHistory.add({
          'date': initialDateRaw,
          'type': 'INITIAL',
          'label': '최초 시작일',
          'description': '처음 단도박을 결심한 소중한 날입니다.',
          'color': const Color(0xFF2F54EB),
          'icon': Icons.flag_rounded,
        });
      }

      // 날짜순 정렬 (과거 -> 현재) 후 번호 다시 매기기
      tempHistory.sort((a, b) => a['date'].compareTo(b['date']));
      int restartCount = 1;
      for (var item in tempHistory) {
        if (item['type'] == 'RESTART') {
          item['label'] = '단도박 재시작 $restartCount';
          restartCount++;
        }
      }

      // 표시를 위한 최종 정렬: 최신순 (단, 최초 시작일은 여전히 구분이 필요할 수 있음)
      // 사용자가 최신순을 선호하므로 b.compareTo(a)
      tempHistory.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) {
        setState(() {
          _history = tempHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '나의 단도박 여정',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
          ),
          const SizedBox(height: 8),
          const Text(
            '결심하고 다시 일어선 모든 순간이 기록됩니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: Color(0xFF5C72EB)),
            )
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Text('기존 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _history.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = _history[index];
                  final bool isInitial = item['type'] == 'INITIAL';

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isInitial ? const Color(0xFFF0F5FF) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFADC6FF),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item['color'],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item['icon'], color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['label'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isInitial ? const Color(0xFF2F54EB) : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(item['date']),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['description'],
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        if (isInitial)
                          IconButton(
                            onPressed: widget.onEditInitial,
                            icon: const Icon(Icons.edit_calendar_outlined, color: Colors.grey, size: 22),
                          )
                        else if (item['type'] == 'RESTART')
                          IconButton(
                            onPressed: () => _deleteRestartDate(item['date']),
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D4F), size: 22),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _deleteRestartDate(String date) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('재시작일 삭제'),
        content: const Text('기록된 재시작일을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await ApiService.deleteRestartDate(widget.userData['uid'], date);
      if (response['success']) {
        if (mounted) {
          ToastUtils.show(context, '삭제되었습니다.');
          widget.onRefresh();
          Navigator.pop(context); // 시트 닫기 (새 정보로 다시 열 수 있도록)
        }
      } else {
        if (mounted) {
          ToastUtils.show(context, response['message'] ?? '삭제에 실패했습니다.');
        }
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy년 MM월 dd일').format(dt);
    } catch (e) {
      return dateStr;
    }
  }
}
