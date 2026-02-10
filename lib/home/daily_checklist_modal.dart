import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class DailyChecklistModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<int, double>? initialAnswers; // Added for editing
  final String checklistType; // [Added]

  const DailyChecklistModal({
    Key? key, 
    required this.userData, 
    this.initialAnswers,
    this.checklistType = 'PATIENT', // Default
  }) : super(key: key);

  @override
  State<DailyChecklistModal> createState() => _DailyChecklistModalState();
}

class _DailyChecklistModalState extends State<DailyChecklistModal> {
  List<dynamic> _questions = [];
  final Map<int, double> _answers = {}; // questionId: score (0.0 ~ 10.0)
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final response = await ApiService.getDailyChecklistQuestions(type: widget.checklistType);
    if (mounted) {
      if (response['success'] == true) {
        setState(() {
          _questions = response['data'];
          
          // Initialize answers
          for (var q in _questions) {
            final int id = q['id'];
            if (widget.initialAnswers != null && widget.initialAnswers!.containsKey(id)) {
               _answers[id] = widget.initialAnswers![id]!;
            } else {
               _answers[id] = 5.0; // Default middle value
            }
          }
          _isLoading = false;
        });
      } else {
        ToastUtils.show(context, response['message'] ?? '질문 목록을 불러오는데 실패했습니다.');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _submit() async {
    debugPrint('=== [DEBUG] Submit button clicked ===');
    setState(() => _isSubmitting = true);
    
    // Convert double scores to integer for API
    final Map<int, int> submitData = {};
    _answers.forEach((key, value) {
      submitData[key] = value.round();
    });
    debugPrint('=== [DEBUG] Submit Data: $submitData ===');

    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    debugPrint('=== [DEBUG] Submitting with UID: $uid ===');
    final response = await ApiService.submitDailyChecklist(uid, submitData);
    debugPrint('=== [DEBUG] Submit Response: $response ===');

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response['success'] == true) {
        ToastUtils.show(context, '오늘의 체크리스트를 완료했습니다.');
        Navigator.pop(context, true);
      } else {
        ToastUtils.show(context, response['message'] ?? '제출에 실패했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF5C72EB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.checklist_rtl_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘의 마음 체크',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '오늘 하루 나의 상태를 점검해보세요 (1~10점)', // [Modified] 0~10 -> 1~10
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _questions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 32),
                      itemBuilder: (context, index) => _buildQuestionItem(_questions[index]),
                    ),
            ),

            // Footer (Button)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C72EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          '제출하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(dynamic question) {
    final int id = question['id'];
    final String text = question['question'];

    final double currentScore = _answers[id] ?? 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F1F1F),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
             Text('1', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)), // [Modified] 0 -> 1
             Expanded(
               child: SliderTheme(
                 data: SliderTheme.of(context).copyWith(
                   activeTrackColor: const Color(0xFF5C72EB),
                   inactiveTrackColor: const Color(0xFFE0E0E0),
                   thumbColor: const Color(0xFF5C72EB),
                   overlayColor: const Color(0xFF5C72EB).withOpacity(0.1),
                   trackHeight: 4,
                   thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                   overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                   valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                   valueIndicatorColor: const Color(0xFF5C72EB),
                   valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                 ),
                 child: Slider(
                   value: currentScore,
                   min: 1, // [Modified] 0 -> 1 (User Request)
                   max: 10,
                   divisions: 9, // [Modified] 10 -> 9 (1 to 10 is 9 intervals)
                   label: currentScore.round().toString(),
                   onChanged: (value) {
                     setState(() {
                       _answers[id] = value;
                     });
                   },
                 ),
               ),
             ),
             Text('10', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Center(
          child: Text(
            '${currentScore.round()}점',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C72EB),
            ),
          ),
        ),
      ],
    );
  }
}
