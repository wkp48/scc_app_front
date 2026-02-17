import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import 'package:kcgp_cb/home/notice_screen.dart';
import 'package:kcgp_cb/home/chatbot_screen.dart';
import 'package:kcgp_cb/utils/page_route_util.dart'; // FadePageRoute
import 'family_calendar_screen.dart';
import 'training/training_screen.dart';
import 'family_growth_note_screen.dart';
import 'positive_checklist_screen.dart';
import 'package:kcgp_cb/home/profile_screen.dart';
import 'package:kcgp_cb/home/daily_checklist_card.dart';
import 'package:kcgp_cb/home/widgets/recovery_trend_card.dart';
import 'package:kcgp_cb/home/daily_checklist_modal.dart';
import 'pre_conversation_checklist_modal.dart';



import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../utils/tutorial_util.dart'; // Added: TutorialUtil
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // Added: TutorialCoachMark

class FamilyHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FamilyHomeScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _latestNotice;
  String? _baseUrl;
  Map<String, dynamic>? _pendingMaximData;
  List<int>? _checklistScores; // Added for checklist results
  
  // Tutorial Keys
  final GlobalKey _dDayCardKey = GlobalKey();
  final GlobalKey _positiveChecklistKey = GlobalKey();

  final GlobalKey _navTrainingKey = GlobalKey();
  final GlobalKey<DailyChecklistCardState> _checklistCardKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _fetchBaseUrl();
    _fetchDashboardData();
    _fetchLatestNotice();
    _setupMaximNotificationListener();
    NotificationService().registerUserToken(widget.userData['uid']);
    _initTutorial();
    _checkAndShowDailyChecklist();
  }

  void _initTutorial({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
       List<TargetFocus> targets = [];

       // 1. 단도박 D-Day 카드
       targets.add(TutorialUtil.createTarget(
         identify: 'family_d_day',
         key: _dDayCardKey,
         title: '단도박 시작일 확인',
         description: '대상자의 단도박 시작일과 경과 시간을 확인하세요.',
         align: ContentAlign.bottom,
       ));
       


       // 3. 트레이닝 탭
       targets.add(TutorialUtil.createTarget(
         identify: 'family_training',
         key: _navTrainingKey,
         title: '마음챙김 트레이닝',
         description: '가족을 위한 다양한 트레이닝 콘텐츠를 이용해보세요.',
         align: ContentAlign.top,
         shape: ShapeLightFocus.Circle,
       ));

       if (targets.isNotEmpty) {
         TutorialUtil.checkAndShowTutorial(context, targets: targets, force: force);
       }
    });
  }

  void _setupMaximNotificationListener() {
    // 0. 초기화 시 NotificationService에 보관된 격언이 있는지 확인
    final pendingMaxim = NotificationService().pendingMaxim;
    if (pendingMaxim != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           _handleMaximMessage(RemoteMessage(data: pendingMaxim));
           NotificationService().clearPendingMaxim();
        }
      });
    }

    // 1. 스트림 리스너
    NotificationService().onMaximReceived.listen((data) {
      if (mounted) {
        _handleMaximMessage(RemoteMessage(data: data));
      }
    });
  }

  void _handleMaximMessage(RemoteMessage message) {
    Map<String, dynamic> data = Map<String, dynamic>.from(message.data);
    if (data.containsKey('data') && data['data'] is Map) {
      final nested = data['data'] as Map;
      nested.forEach((key, value) => data[key.toString()] = value);
    }
    
    final String? type = data['type']?.toString().toUpperCase();
    String? content = data['content'];
    String? author = data['author'];

    if (content == null && message.notification?.body != null) {
      if (type == 'MAXIM' || !data.containsKey('id')) {
        content = message.notification!.body;
      }
    }

    final bool isMaxim = (type == 'MAXIM') || (content != null && !data.containsKey('id'));
    
    if (isMaxim && content != null) {
      setState(() {
        _pendingMaximData = {
          'content': content,
          'author': author,
        };
      });
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

  Future<void> _fetchLatestNotice() async {
    try {
      final result = await ApiService.getNotices();
      if (mounted && result['success'] == true) {
        final List<dynamic> notices = result['data'];
        if (notices.isNotEmpty) {
           notices.sort((a, b) {
            final dateA = DateTime.tryParse(a['createAt'] ?? a['createdAt'] ?? '') ?? DateTime(2000);
            final dateB = DateTime.tryParse(b['createAt'] ?? b['createdAt'] ?? '') ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          setState(() {
            _latestNotice = notices.first;
          });
        }
      }
    } catch (e) {
      print('Failed to fetch notices: $e');
    }
  }

  bool get _hasRecentNotice {
    if (_latestNotice == null) return false;
    final dateStr = _latestNotice!['createAt'] ?? _latestNotice!['createdAt'];
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr.toString());
      final difference = DateTime.now().difference(date);
      return difference.inDays <= 7 && !difference.isNegative;
    } catch (_) {
      return false;
    }
  }

  String _getAbsoluteUrl(String path) {
    if (path.startsWith('data:image')) return path; // Handle Data URI
    if (path.startsWith('http')) return path;
    if (_baseUrl == null) return path;
    
    String url;
    // _baseUrl usually is http://host:port/api
    // path from backend usually is /api/notices/images/filename
    if (_baseUrl!.endsWith('/api') && path.startsWith('/api')) {
      url = _baseUrl!.substring(0, _baseUrl!.length - 4) + path;
    } else if (!path.startsWith('/')) {
      url = '$_baseUrl/$path';
    } else {
      url = '$_baseUrl$path';
    }
    return Uri.encodeFull(url);
  }

  Future<void> _fetchDashboardData() async {
    // TODO: 가족용 대시보드 API 호출 구현
    // 현재는 더미 데이터 또는 기존 API 활용
    setState(() => _isLoading = true);
    
    try {
        // 임시: 기존 대시보드 API 사용하지만 가족용 데이터가 있다면 그것을 사용
        final result = await ApiService.getHomeDashboard(widget.userData['uid']);
        if (mounted) {
            if (result['success']) {
                setState(() {
                    _dashboardData = result['data'];
                    _isLoading = false;
                });
                
                // [First-time Setup] If resolution date is not set, prompt user
                if (_dashboardData?['resolutionDate'] == '-') {
                     // Use addPostFrameCallback to avoid showing dialog during build
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        _selectResolutionDate();
                     });
                }
            }
        }
    } catch (e) {
        print('Error fetching family dashboard: $e');
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndShowDailyChecklist() async {
    // 보호자(FAMILY) 또는 관리자(ADMIN)인 경우에만 표시
    if (widget.userData['userType'] != 'FAMILY' && widget.userData['userType'] != 'ADMIN') return;

    final checkResult = await ApiService.checkTodayDailyChecklist(widget.userData['uid']);
    if (checkResult['success'] == true && checkResult['data'] == false) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false, // 강제로 작성하도록 유도
          builder: (context) => DailyChecklistModal(
            userData: widget.userData, 
            checklistType: 'FAMILY',
          ),
        ).then((result) {
          if (result == true) {
            _fetchDashboardData();
            _checklistCardKey.currentState?.refresh();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 탭 화면들
    final List<Widget> _screens = [
      _buildHomeTab(),
      FamilyCalendarScreen(userData: widget.userData), // userData 전달
      FamilyGrowthNoteScreen(userData: widget.userData), // 성장노트
      TrainingScreen(userData: widget.userData), // userData 전달
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          SafeArea(
            child: _screens[_currentIndex],
          ),
          if (_pendingMaximData != null) _buildMaximOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF5C72EB), // 가족 테마 색상 (Blue/Indigo 계열)
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: '캘린더',
          ),
          const BottomNavigationBarItem(
             icon: Icon(Icons.note_alt_rounded),
             label: '성장노트',
          ),
          BottomNavigationBarItem(
            icon: Container(
              key: _navTrainingKey,
              child: const Icon(Icons.self_improvement_rounded),
            ),
            label: '셀프 트레이닝',
          ),
        ],
      ),
    );
  }



  Widget _buildHomeTab() {
     if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Container(
              key: _dDayCardKey,
              child: _buildDDayCard(),
            ),
            const SizedBox(height: 24),
            DailyChecklistCard(
              key: _checklistCardKey,
              userData: widget.userData,
              checklistType: 'FAMILY',
              customTitle: '나의 성장 상태',
              hideLeftBorder: true,
              showRecoveryTrend: true,
              hideExpandButton: true,
            ),
            const SizedBox(height: 24),
            _buildQuickAccessGrid(),
            const SizedBox(height: 16),
            _buildPreConversationChecklistButton(),
            const SizedBox(height: 24),
            _buildNoticePreviewSection(),
            const SizedBox(height: 24),
            _buildTodayMaximSection(),
            const SizedBox(height: 24),
            _buildChatbotBanner(),
            const SizedBox(height: 16),
            _buildConsultationBanner(),
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
               backgroundColor: Colors.grey[200],
               radius: 24,
               child: const Icon(Icons.person, color: Colors.grey),
               // TODO: 프로필 이미지 연동
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      children: [
                        Text(
                            '${widget.userData['username'] ?? '가족'}님',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (widget.userData['userType'] == 'ADMIN') ...[
                           const SizedBox(width: 8),
                           GestureDetector(
                             onTap: () => _initTutorial(force: true),
                             child: const Icon(Icons.help_outline, size: 20, color: Colors.grey),
                           ),
                        ],
                      ],
                    ),
                    Text(
                        '오늘도 평온한 하루 되세요',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

  Widget _buildDDayCard() {
    // 캘린더와 동일한 로직으로 D-Day 계산
    String label = '자기성장 D-Day';
    int dDays = _dashboardData?['dday'] ?? 0;
    String? targetDateStr;

    final resDate = _dashboardData?['resolutionDate'];
    final List<dynamic> restartDates = _dashboardData?['restartDates'] ?? [];

    if (restartDates.isNotEmpty) {
      List<String> sortedRestartDates = List<String>.from(restartDates);
      sortedRestartDates.sort((a, b) => a.compareTo(b));
      targetDateStr = sortedRestartDates.last;
    } else if (resDate != null) {
      if (resDate.toString().contains('년')) {
        try {
          final parts = resDate.toString().split(' ');
          if (parts.length >= 3) {
            final y = parts[0].replaceAll('년', '').trim();
            final m = parts[1].replaceAll('월', '').trim().padLeft(2, '0');
            final d = parts[2].replaceAll('일', '').trim().padLeft(2, '0');
            targetDateStr = '$y-$m-$d';
          }
        } catch (_) {}
      } else {
        targetDateStr = resDate.toString();
      }
    }

    if (targetDateStr != null) {
      try {
        final parts = targetDateStr.split('-');
        if (parts.length == 3) {
          final start = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          dDays = today.difference(start).inDays + 1;
        }
      } catch (_) {}
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          label,
                          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'D + $dDays',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        Text(
                          '${_dashboardData?['resolutionDate'] ?? '-'}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '자기성장 시작일 \n설정',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
              ],
            ),
            const SizedBox(height: 24),
            // _buildFirstResolutionNestedCard(), // Removed
            // const SizedBox(height: 24), // Removed
            // _buildFocusTimeNestedCard(), // Removed
          ],
        ),
      ),
    );
  }


  void _showResolutionHistoryModal() {
    // TODO: 다짐 히스토리 모달 구현 (필요시)
    // 현재는 간단한 알림이나 아무 동작 안함
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

  Widget _buildQuickAccessGrid() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF56AB2F).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern/Icon
            Positioned(
              right: -10,
              bottom: -20,
              child: Icon(
                Icons.spa_outlined,
                size: 100,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.spa_outlined, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '셀프 트레이닝',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '가족과 나를 위한 회복 훈련 시작하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildPreConversationChecklistButton() {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const PreConversationChecklistModal(),
        );

        if (result != null && result is List<int>) {
           setState(() {
             _checklistScores = result;
           });
        }
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C72EB).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFADC6FF).withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.checklist_rounded, color: Color(0xFF5C72EB), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '대화전 체크리스트',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _checklistScores != null ? '진단 완료' : '대상자와 대화하기 전 체크해보세요',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  _checklistScores != null ? Icons.check_circle : Icons.arrow_forward_ios_rounded, 
                  size: _checklistScores != null ? 24 : 16, 
                  color: _checklistScores != null ? const Color(0xFF5C72EB) : Colors.grey
                ),
              ],
            ),
          ),
          if (_checklistScores != null) ...[
            const SizedBox(height: 16),
            _buildChecklistResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistResults() {
    final List<String> questions = [
      '난 평안한 상태에 있나요?',
      '내 과제와 대상자의 과제를 명확히 구분하고 있나요?',
      '진심으로 대상자의 성장과 안녕을 희망하고 있나요?',
      '도박문제 치료목적을 최우선 순위에 놓고 있나요?',
      '지금 나의 말과 행동은 원칙에 부합한가요?',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('진단 결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (index) {
            final score = _checklistScores![index];
            final isWarning = score <= 7;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                   Container(
                     width: 24, height: 24,
                     alignment: Alignment.center,
                     decoration: BoxDecoration(
                       color: isWarning ? const Color(0xFFFF4D4F).withOpacity(0.1) : const Color(0xFF5C72EB).withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: Text(
                       '${index + 1}',
                       style: TextStyle(
                         color: isWarning ? const Color(0xFFFF4D4F) : const Color(0xFF5C72EB),
                         fontWeight: FontWeight.bold,
                         fontSize: 12,
                       ),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       questions[index],
                       style: const TextStyle(fontSize: 14, color: Colors.black87),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text(
                     '$score점',
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: isWarning ? const Color(0xFFFF4D4F) : const Color(0xFF5C72EB),
                     ),
                   ),
                ],
              ),
            );
          }),
          if (_checklistScores!.any((score) => score <= 7))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFFF4D4F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '자기점검 결과, 붉은색으로 표기된 문항이 있다면 대상자와의 대화를 다음으로 미뤄주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFFF4D4F),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
      return GestureDetector(
          onTap: onTap,
          child: Container(
              height: 140,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(icon, size: 32, color: color),
                      const SizedBox(height: 12),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
              ),
          ),
      );
  }

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
              const Row(
                children: [
                   Icon(Icons.campaign_outlined, color: Color(0xFF5C72EB), size: 24),
                   SizedBox(width: 8),
                   Text('공지사항', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NoticeScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    children: const [
                       Text('더보기', style: TextStyle(color: Colors.grey, fontSize: 13)),
                       Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_latestNotice != null)
            GestureDetector(
              onTap: () {
                 Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NoticeScreen()),
                  );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _latestNotice!['title'] ?? '공지사항',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F1F1F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_hasRecentNotice) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Image Display
                    if (_latestNotice!['imageUrl'] != null && _latestNotice!['imageUrl'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _latestNotice!['imageUrl'].toString().startsWith('data:image')
                            ? Image.memory(
                                base64Decode(_latestNotice!['imageUrl'].toString().split(',').last),
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              )
                            : Image.network(
                                _getAbsoluteUrl(_latestNotice!['imageUrl'].toString()),
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              ),
                        ),
                      ),
                    if (_latestNotice!['content'] != null && _latestNotice!['content'].toString().isNotEmpty)
                      Text(
                        _latestNotice!['content'],
                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_latestNotice!['linkUrl'] != null && _latestNotice!['linkUrl'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: Color(0xFF5C72EB), size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _latestNotice!['linkUrl'],
                                style: const TextStyle(color: Color(0xFF5C72EB), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Container(
               width: double.infinity,
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: const Color(0xFFF7F8FA),
                 borderRadius: BorderRadius.circular(16),
               ),
               child: const Text(
                 '등록된 공지사항이 없습니다.',
                 style: TextStyle(color: Colors.grey),
                 textAlign: TextAlign.center,
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatbotBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatbotScreen(userData: widget.userData)),
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
      onTap: _showConsultationDialog,
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
                    '월-금 09:00 - 18:00(점심시간 12:00 - 13:00)',
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

  Widget _buildMaximOverlay() {
    final String content = _pendingMaximData?['content'] ?? '';
    final String? author = _pendingMaximData?['author'];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '오늘의 격언 설정',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '매일 힘이 되는 한마디를 받아보세요',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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

  void _showMaximSettingsModal() {
    bool isAgreed = _dashboardData?['maximAgreement'] ?? widget.userData['maximAgreement'] ?? false;
    String timeStr = _dashboardData?['maximTime'] ?? widget.userData['maximTime'] ?? '09:00';
    
    int hour = 9;
    int minute = 0;
    try {
      final parts = timeStr.split(':');
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);
    } catch (_) {}
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);

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
                            _fetchDashboardData(); 
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
}
