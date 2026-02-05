import 'package:flutter/material.dart';
import 'find_pw_reset_com.dart';
import '../services/api_service.dart';
import '../utils/page_route_util.dart';

class FindPwResetScreen extends StatefulWidget {
  final String userid;
  final String userName;
  
  const FindPwResetScreen({
    super.key,
    required this.userid,
    required this.userName,
  });

  @override
  State<FindPwResetScreen> createState() => _FindPwResetScreenState();
}

class _FindPwResetScreenState extends State<FindPwResetScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePasswords() {
    if (_confirmPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _passwordError = "새 비밀번호가 일치 하지 않습니다";
        });
      } else {
        setState(() {
          _passwordError = null;
        });
      }
    } else {
      setState(() {
        _passwordError = null;
      });
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
          '비밀번호 재설정',
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
                  color: const Color(0xFFEAE7E1), // 이미지와 동일한 회색 배경
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
                    // 새 비밀번호 입력
                    _buildPasswordField('새 비밀번호 입력', _newPasswordController),
                    
                    const SizedBox(height: 20),
                    
                    // 새 비밀번호 확인
                    _buildConfirmPasswordField(),
                    
                    const SizedBox(height: 30),
                    
                    // 비밀번호 재설정 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF66D98F), // 이미지와 동일한 녹색
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
                              '비밀번호 재설정',
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

  Widget _buildPasswordField(String label, TextEditingController controller) {
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
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: true,
            onChanged: (value) => _validatePasswords(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '새 비밀번호 확인',
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
            border: Border.all(
              color: _passwordError != null ? Colors.red : Colors.grey[300]!, 
              width: 1
            ),
          ),
          child: TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            onChanged: (value) => _validatePasswords(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (_passwordError != null) ...[
          const SizedBox(height: 4),
          Text(
            _passwordError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleResetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showErrorDialog('입력 오류', '새 비밀번호와 비밀번호 확인을 입력해주세요');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorDialog('비밀번호 오류', '새 비밀번호가 일치하지 않습니다');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== 비밀번호 재설정 시도 시작 ===');
      print('아이디: ${widget.userid}');
      print('새 비밀번호: ${_newPasswordController.text}');
      
      final response = await ApiService.resetPassword(
        widget.userid,
        _newPasswordController.text,
      );

      print('=== API 응답 받음 ===');
      print('응답 데이터: $response');

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        print('=== 비밀번호 재설정 성공 ===');
        
        // 비밀번호 재설정 완료 화면으로 이동
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            page: FindPwResetCompleteScreen(
              userName: widget.userName,
            ),
          ),
        );
      } else {
        print('=== 비밀번호 재설정 실패 ===');
        print('실패 메시지: ${response['message']}');
        
        _showErrorDialog(
          '비밀번호 재설정 실패', 
          response['message'] ?? '비밀번호 재설정 중 오류가 발생했습니다.'
        );
      }
    } catch (e) {
      print('=== 비밀번호 재설정 오류 발생 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 메시지: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorDialog(
        '네트워크 오류', 
        '비밀번호 재설정 중 오류가 발생했습니다.\n\n오류 상세:\n$e'
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
