import 'package:flutter/material.dart';
import 'resolution_step.dart';

class OnboardingScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const OnboardingScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // _totalPages will be determined by the length of _pages list

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initPages();
    
    // 페이지가 없으면(가족 회원 등) 바로 완료 처리
    if (_pages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeOnboarding();
      });
    }
  }

  void _initPages() {
    _pages = [];
    
    // 대상자인 경우에만 온보딩 단계 추가 (단도박 결심, 자가진단 등)
    if (widget.userData['userType'] != 'FAMILY') {
      _pages.add(
        ResolutionStep(
          userData: widget.userData,
          onNext: _nextPage,
          onPrevious: _previousPage,
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 첫 페이지에서 이전 버튼 누르면 로그인 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _completeOnboarding() {
    // 온보딩 완료 시 홈 화면으로 이동
    // 알람 화면(/alarm_trigger)이 떠 있는 경우 이를 유지하고 나머지만 비움
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home', 
      (route) => route.settings.name == '/alarm_trigger', 
      arguments: widget.userData
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EB), // 공통 베이지 배경
      body: SafeArea(
        child: Column(
          children: [
            // 프로그레스 바
            LinearProgressIndicator(
              value: (_currentPage + 1) / _pages.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF09E89E)),
              minHeight: 4,
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // 스와이프 방지
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
