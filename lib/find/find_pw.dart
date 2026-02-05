import 'package:flutter/material.dart';
import 'find_pw_reset.dart';
import '../services/api_service.dart';
import '../utils/page_route_util.dart';
import '../utils/toast_utils.dart';

class FindPwScreen extends StatefulWidget {
  const FindPwScreen({super.key});

  @override
  State<FindPwScreen> createState() => _FindPwScreenState();
}

class _FindPwScreenState extends State<FindPwScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationController = TextEditingController();

  bool _isEmailVerified = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 생년월일 자동 포맷팅 리스너 추가
    _birthController.addListener(() {
      _formatBirthDate();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _birthController.dispose();
    _emailController.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  // 생년월일 자동 포맷팅 함수
  void _formatBirthDate() {
    final text = _birthController.text;
    final cleanedText = text.replaceAll(RegExp(r'[^\d]'), ''); // 숫자만 남기기
    
    if (cleanedText.length <= 4) {
      _birthController.value = TextEditingValue(
        text: cleanedText,
        selection: TextSelection.collapsed(offset: cleanedText.length),
      );
    } else if (cleanedText.length <= 6) {
      _birthController.value = TextEditingValue(
        text: '${cleanedText.substring(0, 4)}-${cleanedText.substring(4)}',
        selection: TextSelection.collapsed(offset: cleanedText.length + 1),
      );
    } else {
      _birthController.value = TextEditingValue(
        text: '${cleanedText.substring(0, 4)}-${cleanedText.substring(4, 6)}-${cleanedText.substring(6, 8)}',
        selection: TextSelection.collapsed(offset: cleanedText.length + 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0), // 베이지색 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: Colors.grey,
            size: 32,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // 메인 폼 컨테이너
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 입력
                    _buildInputField('이름', _nameController),
                    
                    const SizedBox(height: 20),
                    
                    // 아이디 입력
                    _buildInputField('아이디', _idController),
                    
                    const SizedBox(height: 20),
                    
                    // 생년월일 입력
                    _buildBirthDateField(),
                    
                    const SizedBox(height: 20),
                    
                    // 이메일 입력
                    _buildEmailField(),
                    
                    const SizedBox(height: 20),
                    
                    // 인증번호 입력
                    _buildVerificationField(),
                    
                    const SizedBox(height: 30),
                    
                    // 비밀번호 찾기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleFindPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF09E89E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text(
                              '비밀번호 찾기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '생년월일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _birthController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: '2000-01-01',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이메일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  // 임시 이메일 인증 완료
                  setState(() {
                    _isEmailVerified = true;
                  });
                  ToastUtils.show(context, '이메일 인증이 완료되었습니다 (임시)');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09E89E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '인증받기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerificationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '인증번호',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _verificationController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  // 임시 인증번호 확인 완료
                  setState(() {
                    _isEmailVerified = true;
                  });
                  ToastUtils.show(context, '인증번호 확인이 완료되었습니다 (임시)');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09E89E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '인증하기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isEmailVerified) ...[
          const SizedBox(height: 8),
          const Text(
            '인증이 완료되었습니다',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleFindPassword() async {
    if (_nameController.text.isEmpty || 
        _idController.text.isEmpty || 
        _birthController.text.isEmpty || 
        _emailController.text.isEmpty) {
      _showErrorDialog('입력 오류', '모든 필드를 입력해주세요');
      return;
    }

    if (!_isEmailVerified) {
      _showErrorDialog('인증 오류', '이메일 인증을 완료해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== 비밀번호 찾기 시도 시작 ===');
      print('이름: ${_nameController.text}');
      print('아이디: ${_idController.text}');
      print('생년월일: ${_birthController.text}');
      print('이메일: ${_emailController.text}');
      
      final response = await ApiService.findPassword(
        _nameController.text,
        _idController.text,
        _birthController.text,
        _emailController.text,
      );

      print('=== API 응답 받음 ===');
      print('응답 데이터: $response');

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        print('=== 비밀번호 찾기 성공 ===');
        print('사용자 정보: ${response['data']}');
        
        // 비밀번호 재설정 화면으로 이동
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            page: FindPwResetScreen(
              userid: response['data']['userid'],
              userName: _nameController.text.trim(),
            ),
          ),
        );
      } else {
        print('=== 비밀번호 찾기 실패 ===');
        print('실패 메시지: ${response['message']}');
        
        _showErrorDialog(
          '비밀번호 찾기 실패', 
          response['message'] ?? '입력한 정보를 다시 확인해주세요.'
        );
      }
    } catch (e) {
      print('=== 비밀번호 찾기 오류 발생 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 메시지: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorDialog(
        '네트워크 오류', 
        '비밀번호 찾기 중 오류가 발생했습니다.\n\n오류 상세:\n$e'
      );
    }
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
}
