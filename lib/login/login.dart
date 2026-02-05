import 'package:flutter/material.dart';
import '../signup/signup_class.dart';
import '../find/find_id.dart';
import '../find/find_pw.dart';
import '../services/api_service.dart';
import '../utils/page_route_util.dart';
import '../onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../widgets/toggle_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAutoLogin = false;
  bool _isSaveId = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // 무한 반복 펄스 효과
    _pulseController.repeat();
    
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoLogin = prefs.getBool('auto_login') ?? true;
      _isSaveId = prefs.getBool('save_id') ?? false;
      
      if (_isSaveId) {
        _idController.text = prefs.getString('saved_userid') ?? '';
      }
    });

    // 자동 로그인 체크
    if (_isAutoLogin && !NotificationService().isAlarmLaunch) {
      final savedId = prefs.getString('saved_userid');
      final savedPw = prefs.getString('saved_password');
      if (savedId != null && savedPw != null && savedId.isNotEmpty && savedPw.isNotEmpty) {
        _idController.text = savedId;
        _passwordController.text = savedPw;
        _handleLogin();
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // 로고 섹션
                _buildLogoSection(),
                
                const SizedBox(height: 32),
                
                // 입력 필드들
                _buildInputFields(),
                
                const SizedBox(height: 32),
                
                // 로그인 버튼
                _buildLoginButton(),
                
                const SizedBox(height: 24),
                
                // 하단 링크들
                _buildBottomLinks(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Transform.scale(
        scale: 1.25,
        child: ToggleLogo(
          pulseController: _pulseController,
          isStatic: true,
          switchScale: 0.8,
        ),
      ),
    );
  }


  Widget _buildInputFields() {
    const Color inputBgColor = Color(0xFFF7F8FA);
    const Color focusColor = Color(0xFF00FF9D);

    return Column(
      children: [
        // ID 입력 필드
        _buildTextField(
          controller: _idController,
          hintText: '아이디',
          icon: Icons.person_outline_rounded,
          backgroundColor: inputBgColor,
          focusColor: focusColor,
        ),
        
        const SizedBox(height: 16),
        
        // Password 입력 필드
        _buildTextField(
          controller: _passwordController,
          hintText: '비밀번호',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          backgroundColor: inputBgColor,
          focusColor: focusColor,
        ),
        
        const SizedBox(height: 16),
        
        // 체크박스 영역
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSmallCheckBox(
              label: '자동 로그인',
              value: _isAutoLogin,
              onChanged: (val) => setState(() => _isAutoLogin = val ?? false),
            ),
            _buildSmallCheckBox(
              label: '아이디 저장',
              value: _isSaveId,
              onChanged: (val) => setState(() => _isSaveId = val ?? false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    required Color backgroundColor,
    required Color focusColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent, width: 2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSmallCheckBox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00FF9D),
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('입력 오류', '아이디와 비밀번호를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== 로그인 시도 시작 ===');
      print('아이디: ${_idController.text}');
      print('비밀번호: ${_passwordController.text}');
      
      final response = await ApiService.login(
        _idController.text,
        _passwordController.text,
      );

      print('=== API 응답 받음 ===');
      print('응답 데이터: $response');

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        print('=== 로그인 성공 ===');
        final userData = response['data'];
        
        // 설정 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_login', _isAutoLogin);
        await prefs.setBool('save_id', _isSaveId);
        
        if (_isSaveId || _isAutoLogin) {
          await prefs.setString('saved_userid', _idController.text);
        } else {
          await prefs.remove('saved_userid');
        }

        if (_isAutoLogin) {
          await prefs.setString('saved_password', _passwordController.text);
        } else {
          await prefs.remove('saved_password');
        }

        print('사용자 데이터: $userData');
        
        if (userData['userType'] == 'ADMIN') {
          final String? choice = await _showAdminViewChoiceDialog();
          if (choice == null) {
            setState(() => _isLoading = false);
            return;
          }
          // 관리자가 선택한 뷰 타입을 데이터에 추가
          userData['adminViewType'] = choice;
        }

        if (!_isAutoLogin || _idController.text.isEmpty) {
          _showSuccessDialog('로그인 성공!', '환영합니다, ${userData['username'] ?? userData['userid']}님!');
        }
        
        // 온보딩 상태 확인
        final statusResponse = await ApiService.getOnboardingStatus(userData['uid']);
        bool isCompleted = false;
        
        if (statusResponse['success'] == true) {
          isCompleted = statusResponse['data']['isCompleted'] ?? false;
        }

        // 이동 전 잠시 대기
        await Future.delayed(Duration(milliseconds: _isAutoLogin ? 500 : 1500));
        
        if (mounted) {
          if (isCompleted) {
            // 온보딩 완료 시 홈으로 이동
            // 알람 화면(/alarm_trigger)이 떠 있는 경우 이를 유지하고 나머지만 비움
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home', 
              (route) => route.settings.name == '/alarm_trigger', 
              arguments: userData
            );
          } else {
            // 온보딩 미완료 시 온보딩 화면으로 이동
            Navigator.of(context).pushReplacement(
              FadePageRoute(
                page: OnboardingScreen(
                  userData: userData,
                ),
              ),
            );
          }
        }
      } else {
        print('=== 로그인 실패 ===');
        print('실패 메시지: ${response['message']}');
        
        _showErrorDialog(
          '로그인 실패', 
          response['message'] ?? '로그인에 실패했습니다.\n\n자세한 정보:\n${response.toString()}'
        );
      }
    } catch (e) {
      print('=== 로그인 오류 발생 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 메시지: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorDialog(
        '네트워크 오류', 
        '로그인 중 오류가 발생했습니다.\n\n오류 상세:\n$e'
      );
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF09E89E),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red[600],
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF9D).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF9D),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading 
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : const Text(
              '로그인',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
      ),
    );
  }

  Widget _buildBottomLinks() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLinkButton('아이디 찾기', () => Navigator.of(context).push(SlidePageRoute(page: const FindIdScreen()))),
            _buildVerticalDivider(),
            _buildLinkButton('비밀번호 찾기', () => Navigator.of(context).push(SlidePageRoute(page: const FindPwScreen()))),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '계정이 없으신가요? ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(SlidePageRoute(page: const SignupClassScreen())),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 12,
      color: Colors.grey[300],
    );
  }

  Future<String?> _showAdminViewChoiceDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('관리자 접속', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('접속하실 화면 모드를 선택해주세요.'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'SUBJECT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09E89E),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('대상자 화면 모드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'FAMILY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9999),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('가족 화면 모드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('취소', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
