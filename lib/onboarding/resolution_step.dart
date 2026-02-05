import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class ResolutionStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const ResolutionStep({
    Key? key,
    required this.userData,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<ResolutionStep> createState() => _ResolutionStepState();
}

  class _ResolutionStepState extends State<ResolutionStep> {
  final TextEditingController _resolutionController = TextEditingController();
  bool _showError = false; // 에러 상태 관리
  bool _isLoading = false; // 로딩 상태 관리

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    // 유효성 검사: 내용이 비어있으면 넘어가지 않음
    if (_resolutionController.text.trim().isEmpty) {
      setState(() {
        _showError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.saveResolution(
        widget.userData['uid'],
        _resolutionController.text.trim(),
      );

      if (response['success'] == true) {
        widget.onNext();
      } else {
        ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다');
      }
    } catch (e) {
      ToastUtils.show(context, '오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 우측 상단 초록색 그라데이션 디자인
        Positioned(
          top: -350, // 화면 위쪽으로 위치
          right: -350, // 화면 오른쪽으로 위치
          child: Container(
            width: 600,
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.5, // 반경을 키워 더 부드럽게 퍼지도록 설정
                colors: [
                  const Color(0xFFB2FF59).withOpacity(0.4), // 더 밝은 연두색
                  const Color(0xFFB2FF59).withOpacity(0.0), // 같은 색상의 투명색으로 빠져야 얼룩(회색조)이 안 생김
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
        children: [
          const SizedBox(height: 80),
          // Title
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.4,
              ),
              children: [
                TextSpan(text: '시작하기 앞서서\n'),
                TextSpan(
                  text: '단도박',
                  style: TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 25, // 크기 25으로 설정
                    fontWeight: FontWeight.w900, // 가장 굵게 (Black)
                    decoration: TextDecoration.underline, // 밑줄 추가
                    decorationColor: Color(0xFF00C853), // 밑줄 색상
                  ),
                ),
                TextSpan(text: '을 향한 나의\n결심을 적어볼까요?'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Subtext
          const Text(
            '나의 첫 다짐이 흔들리지 않는 뿌리가 되어줄 거예요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 60),
          
          // Label
          const Text(
            '나의 첫 결심',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Input Field
          Container(
            height: 200, // 넉넉한 높이
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED), // 회색 배경
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _resolutionController,
              maxLines: null, // 여러 줄 입력 가능
              onChanged: (value) {
                if (_showError && value.isNotEmpty) {
                  setState(() {
                    _showError = false;
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: '도박을 끊고 달라진 나의 모습을 상상하며 다짐을 적어보세요',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(20),
              ),
            ),
          ),
          
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 8.0, left: 4.0),
              child: Text(
                '다짐을 작성해주세요!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          const Spacer(),
          
          // Bottom Buttons
          Row(
            children: [
              // 이전 버튼 (비활성화 - 첫 페이지니까)
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onPrevious, // 이전 버튼 활성화
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
              // 다음 버튼
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33CC00), // 밝은 초록색
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
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
