import 'package:flutter/material.dart';
import '../utils/toast_utils.dart';
import '../services/api_service.dart'; // 추후 API 연동 시 주석 해제

class PositiveChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PositiveChecklistScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<PositiveChecklistScreen> createState() => _PositiveChecklistScreenState();
}

class _PositiveChecklistScreenState extends State<PositiveChecklistScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // 답변 상태 저장
  final Map<String, dynamic> _answers = {
    'principle': null,   // 원칙관계
    'psychological': null, // 심리적 관계
    'daily': null,       // 일상 체크
    'conversation': null, // 건강한 대화법
    'role': null,        // 가족의 역할
  };

  // 질문 목록 정의
  final List<Map<String, dynamic>> _questions = [
    {
      'key': 'principle',
      'title': '원칙관계',
      'description': '도박 문제에 대하여 세운 원칙을\n잘 지키고 유지하셨나요?',
      'options': ['네, 잘 지켰습니다', '노력했지만 부족했습니다', '잘 지키지 못했습니다'],
    },
    {
      'key': 'psychological',
      'title': '심리적 관계',
      'description': '환자와 심리적 거리를 적절히 유지하며\n나의 감정을 잘 조절하셨나요?',
      'options': ['네, 평온을 유지했습니다', '조금 흔들렸습니다', '감정적으로 힘들었습니다'],
    },
    {
      'key': 'daily',
      'title': '일상 체크',
      'description': '가족 돌봄에 매몰되지 않고\n나의 소중한 일상을 챙기셨나요?',
      'options': ['네, 나의 일상을 보냈습니다', '조금 미흡했습니다', '일상에 집중하지 못했습니다'],
    },
    {
      'key': 'conversation',
      'title': '건강한 대화법',
      'description': '환자를 비난하거나 추궁하지 않고\n건강한 방식으로 대화하셨나요?',
      'options': ['네, 비폭력 대화를 했습니다', '노력했으나 욱했습니다', '비난하고 다투었습니다'],
    },
    {
      'key': 'role',
      'title': '가족의 역할을 잘 하고 있는지',
      'description': '부모, 배우자, 자녀로서의 본분을 잊지 않고\n가족의 역할을 충실히 했나요?',
      'options': ['네, 제 역할을 다했습니다', '보통이었습니다', '역할을 다하지 못했습니다'],
    },
  ];

  void _nextStep() {
    if (_answers[_questions[_currentStep]['key']] == null) {
      ToastUtils.show(context, '답변을 선택해주세요.');
      return;
    }

    if (_currentStep < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _submitChecklist();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitChecklist() async {
    setState(() => _isLoading = true);
    
    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    final response = await ApiService.saveFamilyChecklist(uid, _answers);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (response['success'] == true) {
        _showCompletionDialog();
      } else {
        ToastUtils.show(context, response['message'] ?? '저장 실패');
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF32B34A), size: 48),
            SizedBox(height: 16),
            Text('작성 완료', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '오늘도 건강한 가족 관계를 위해\n노력해주셔서 감사합니다.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF32B34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousStep,
        ),
        title: Text(
          '긍정관리 체크리스트 (${_currentStep + 1}/${_questions.length})',
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / _questions.length,
              backgroundColor: Colors.grey[100],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C72EB)),
              minHeight: 4,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  return _buildQuestionPage(_questions[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C72EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _currentStep == _questions.length - 1 ? '완료하기' : '다음',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> question) {
    final key = question['key'];
    final options = question['options'] as List<String>;
    final selectedOption = _answers[key];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question['title'],
              style: const TextStyle(color: Color(0xFF5C72EB), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            question['description'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 48),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final text = entry.value;
            final isSelected = selectedOption == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _answers[key] = index;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF5C72EB) : Colors.white,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF5C72EB) : Colors.grey[200]!,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF5C72EB).withValues(alpha: 0.3), // Changed to withValues for flutter 3.27+ if needed, but keeping withOpacity for strict flutter 3.10+ compat if unsure, sticking to withOpacity as it's standard unless deprecated error seen. Actually error log showed deprecated. I will use withOpacity for now as warning is just info.
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
