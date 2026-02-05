import 'package:flutter/material.dart';

class DiagnosisIntroStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const DiagnosisIntroStep({
    Key? key,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 우측 상단 초록색 그라데이션 디자인
        Positioned(
          top: -400,
          right: -400,
          child: Container(
            width: 600,
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7,
                colors: [
                  const Color(0xFFB2FF59).withOpacity(0.4),
                  const Color(0xFFB2FF59).withOpacity(0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // 기존 컨텐츠
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F8D1), // 연한 초록 배경
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security, // 방패 아이콘 (유사한 것 사용)
                    size: 60,
                    color: Color(0xFF33CC00),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Pretendard',
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: '마지막으로\n'),
                    TextSpan(text: '현재 나의 상태를\n'),
                    TextSpan(text: '한번 '),
                    TextSpan(
                      text: '진단',
                      style: TextStyle(color: Color(0xFF00C853)),
                    ),
                    TextSpan(text: '해볼까요?'),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Subtext
              const Text(
                '더 나은 단도박을 위해\n현재를 돌아보는 시간입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              
              const Spacer(flex: 3),
              
              // Bottom Buttons
              Row(
                children: [
                  // 이전 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPrevious,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFEFEF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('이전'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 다음(완료) 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext, // 완료 처리 또는 진단 페이지 이동
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF33CC00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '다음',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
