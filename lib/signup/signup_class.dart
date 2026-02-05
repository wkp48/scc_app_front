import 'package:flutter/material.dart';
import 'terms_agreement_screen.dart';
import '../utils/page_route_util.dart';

class SignupClassScreen extends StatelessWidget {
  const SignupClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // 안내 문구
              const Text(
                '어떤 유형으로\n회원가입하시겠어요?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.4,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '본인에게 맞는 유형을 선택해 주세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 선택 버튼들
              Row(
                children: [
                  // 대상자 버튼
                  Expanded(
                    child: _buildSelectionButton(
                      title: '대상자',
                      subtitle: '치유 및 관리 대상',
                      icon: Icons.person_rounded,
                      primaryColor: const Color(0xFF00FF9D), // 형광초록
                      onTap: () {
                        Navigator.of(context).push(
                          SlidePageRoute(
                            page: const TermsAgreementScreen(userType: 'SUBJECT'),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 가족 버튼
                  Expanded(
                    child: _buildSelectionButton(
                      title: '가족',
                      subtitle: '지지 및 동행 가족',
                      icon: Icons.favorite_rounded,
                      primaryColor: const Color(0xFFFF7B7B), // 세련된 레드
                      onTap: () {
                        Navigator.of(context).push(
                          SlidePageRoute(
                            page: const TermsAgreementScreen(userType: 'FAMILY'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 배경 및 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: primaryColor,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 텍스트 섹션
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
