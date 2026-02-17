import 'package:flutter/material.dart';

class PreConversationChecklistModal extends StatefulWidget {
  const PreConversationChecklistModal({Key? key}) : super(key: key);

  @override
  State<PreConversationChecklistModal> createState() => _PreConversationChecklistModalState();
}

class _PreConversationChecklistModalState extends State<PreConversationChecklistModal> {
  // 5 Questions
  final List<String> _questions = [
    '난 평안한 상태에 있나요?',
    '내 과제와 대상자의 과제를 명확히 구분하고 있나요?',
    '진심으로 대상자의 성장과 안녕을 희망하고 있나요?',
    '도박문제 치료목적을 최우선 순위에 놓고 있나요?',
    '지금 나의 말과 행동은 원칙에 부합한가요?',
  ];

  // Scores for each question (1-10)
  // Initializing with 5 (mid-point)
  final List<int> _scores = [5, 5, 5, 5, 5];

  // Threshold for warning (Red color if <= 7)
  static const int _threshold = 7;

  bool get _hasRedItems {
    return _scores.any((score) => score <= _threshold);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 32),
              itemBuilder: (context, index) {
                return _buildQuestionItem(index);
              },
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '대화전 체크리스트',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '대상자와 대화하기 전, 스스로 점검해보세요.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildQuestionItem(int index) {
    final int score = _scores[index];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${index + 1}. ${_questions[index]}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1점', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            Text(
              '$score점',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5C72EB),
              ),
            ),
            Text('10점', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF5C72EB),
            inactiveTrackColor: Colors.grey[200],
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF5C72EB).withOpacity(0.1),
            thumbShape: _CustomThumbShape(color: const Color(0xFF5C72EB)), // Custom thumb
            trackHeight: 6.0,
          ),
          child: Slider(
            value: score.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                _scores[index] = value.round();
              });
            },
          ),
        ),

      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Icon(Icons.info_outline, color: Colors.grey, size: 20),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   '자기점검 결과, 붉은색으로 표기된 문항이 있다면\n대상자와의 대화를 다음으로 미뤄주세요',
                   style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                 ),
               ),
             ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _scores),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C72EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple custom thumb shape for the slider
class _CustomThumbShape extends SliderComponentShape {
  final Color color;
  _CustomThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(20, 20);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    
    // Shadow
    final Path shadowPath = Path()
      ..addOval(Rect.fromCenter(center: center, width: 24, height: 24));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.2), 4.0, true);

    // Border
    final Paint borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, borderPaint);

    // Inner White
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, innerPaint);
  }
}
