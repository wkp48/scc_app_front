import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class DiagnosisStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const DiagnosisStep({
    Key? key,
    required this.userData,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<DiagnosisStep> createState() => _DiagnosisStepState();
}

class _DiagnosisStepState extends State<DiagnosisStep> {
  // 설문 문항 데이터 (API에서 동적으로 로드)
  List<Map<String, dynamic>> _questions = [];

  // 사용자의 선택 결과 저장 (문항 인덱스 -> 선택 옵션 인덱스)
  final Map<int, int> _answers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getDiagnosisQuestions();
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        if (data.isNotEmpty) {
          setState(() {
            _questions = data.map((q) => {
              'question': q['question'],
              'options': List<String>.from(json.decode(q['optionsJson'])),
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch questions: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '성인 도박 자가진단 검사',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2222DD), // 파란색 제목
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '귀하의 답변은 개인정보보호법에 따라 기밀로 유지됩니다\n본 문항에 솔직하게 답변해주세요!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Question List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  return _buildQuestionCard(index);
                },
              ),
            ),

            // Submit Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _answers.length < _questions.length 
                    ? null 
                    : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // 보라빛/파란색 버튼
                    disabledBackgroundColor: const Color(0xFFC7D2FE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '결과 제출 및 보기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int qIndex) {
    final question = _questions[qIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
            '질문 ${qIndex + 1}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question['question'],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(question['options'].length, (oIndex) {
            final isSelected = _answers[qIndex] == oIndex;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _answers[qIndex] = oIndex;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFEEEEEE),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          )
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      question['options'][oIndex],
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? const Color(0xFF1E40AF) : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 답변 인덱스 리스트 추출
      final List<int> responseAnswers = [];
      for (int i = 0; i < _questions.length; i++) {
        responseAnswers.add(_answers[i]!);
      }

      final response = await ApiService.saveDiagnosis(
        widget.userData['uid'],
        responseAnswers,
      );

      if (response['success'] == true) {
        widget.onNext(); // 다음 단계 (또는 완료)
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
}
