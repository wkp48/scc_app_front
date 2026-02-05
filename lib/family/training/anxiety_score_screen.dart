import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AnxietyScoreScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? initialData;
  const AnxietyScoreScreen({Key? key, required this.userData, this.initialData}) : super(key: key);

  @override
  State<AnxietyScoreScreen> createState() => _AnxietyScoreScreenState();
}

class _AnxietyScoreScreenState extends State<AnxietyScoreScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // CBT 5단계 입력 값
  String _situation = '';
  
  // 감정 관련 상태 (태그 선택 및 점수)
  // Set of selected keys: 'ANGER', 'ANXIETY', 'DEPRESSION', 'HASTE'
  final Set<String> _selectedEmotions = {}; 
  
  double _anxietyScore = 50;
  double _angerScore = 50;
  double _depressionScore = 50;
  double _hasteScore = 50;

  String _thought = ''; // 자동적 사고
  String _rebuttal = ''; // 반박하기

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _situation = widget.initialData!['situation'] ?? '';
      _thought = widget.initialData!['thought'] ?? '';
      _rebuttal = widget.initialData!['rebuttal'] ?? '';

      // Initialize scores and tags based on existing data
      if (widget.initialData!['anxietyScore'] != null && widget.initialData!['anxietyScore'] > 0) {
        _anxietyScore = double.tryParse(widget.initialData!['anxietyScore'].toString()) ?? 50;
        _selectedEmotions.add('ANXIETY');
      }
      if (widget.initialData!['angerScore'] != null && widget.initialData!['angerScore'] > 0) {
        _angerScore = double.tryParse(widget.initialData!['angerScore'].toString()) ?? 50;
        _selectedEmotions.add('ANGER');
      }
      if (widget.initialData!['depressionScore'] != null && widget.initialData!['depressionScore'] > 0) {
        _depressionScore = double.tryParse(widget.initialData!['depressionScore'].toString()) ?? 50;
        _selectedEmotions.add('DEPRESSION');
      }
      if (widget.initialData!['hasteScore'] != null && widget.initialData!['hasteScore'] > 0) {
        _hasteScore = double.tryParse(widget.initialData!['hasteScore'].toString()) ?? 50;
        _selectedEmotions.add('HASTE');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('감정일기 (CBT)'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideSection(),
                const SizedBox(height: 32),
                
                _buildSectionTitle('1. 상황 (Situation)'),
                _buildTextField(
                  hint: '어떤 상황에서 감정의 변화를 느꼈나요?',
                  onSaved: (val) => _situation = val ?? '',
                  maxLines: 2,
                  initialValue: _situation,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('2. 감정과 점수 (Feeling)'),
                const Text('느껴지는 감정을 모두 선택하고 점수를 매겨보세요.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                _buildEmotionChips(),
                
                if (_selectedEmotions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedEmotions.contains('ANGER')) _buildSlider('분노', _angerScore, (v) => setState(() => _angerScore = v), const Color(0xFFFF4D4F)),
                        if (_selectedEmotions.contains('ANXIETY')) _buildSlider('불안', _anxietyScore, (v) => setState(() => _anxietyScore = v), const Color(0xFF722ED1)),
                        if (_selectedEmotions.contains('DEPRESSION')) _buildSlider('우울', _depressionScore, (v) => setState(() => _depressionScore = v), const Color(0xFF1890FF)),
                        if (_selectedEmotions.contains('HASTE')) _buildSlider('조급함', _hasteScore, (v) => setState(() => _hasteScore = v), const Color(0xFFFA8C16)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                _buildSectionTitle('3. 자동적 사고 (Thoughts)'),
                _buildTextField(
                  hint: '그때 순간적으로 어떤 생각이 스쳤나요?\n(예: "영원히 해결되지 않을 거야", "큰일 났다")',
                  onSaved: (val) => _thought = val ?? '',
                  maxLines: 3,
                  initialValue: _thought,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('4. 반박하기 (Rebuttal)'),
                _buildTextField(
                  hint: '그 생각이 사실이 아닐 수도 있는 증거는?\n더 합리적인 생각으로 바꿔본다면?',
                  onSaved: (val) => _rebuttal = val ?? '',
                  maxLines: 3,
                  initialValue: _rebuttal,
                ),
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF722ED1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                     child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('기록 저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3ADF7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Color(0xFF722ED1)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '인지행동치료(CBT) 기법을 활용해\n나의 감정을 객관적으로 바라보고\n건강하게 대처하는 연습을 합니다.',
              style: TextStyle(color: Color(0xFF531DAB), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmotionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChoiceChip('분노', 'ANGER', const Color(0xFFFF4D4F)),
        _buildChoiceChip('불안', 'ANXIETY', const Color(0xFF722ED1)),
        _buildChoiceChip('우울', 'DEPRESSION', const Color(0xFF1890FF)),
        _buildChoiceChip('조급함', 'HASTE', const Color(0xFFFA8C16)),
      ],
    );
  }

  Widget _buildChoiceChip(String label, String code, Color color) {
    bool isSelected = _selectedEmotions.contains(code);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _selectedEmotions.add(code);
          } else {
            _selectedEmotions.remove(code);
          }
        });
      },
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text('${value.round()}점', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 2),
            overlayColor: color.withOpacity(0.1),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 10,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextField({required String hint, required FormFieldSetter<String> onSaved, int maxLines = 1, String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF722ED1))),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
      ),
      maxLines: maxLines,
      onSaved: onSaved,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '내용을 입력해주세요';
        return null;
      },
    );
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedEmotions.isEmpty) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('하나 이상의 감정을 선택해주세요.')));
      }
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    final uid = widget.userData['uid'] ?? widget.userData['userid'];
    final data = {
      'situation': _situation,
      // Send 0 for unselected emotions, or keep value? 
      // Requirement: only selected emotions imply existence, but backend might just store value. 
      // We will send the value if selected, else 0 (or null if backend handles it). 
      // Backend uses Double class, so null is possible. Let's send null for unselected.
      'angerScore': _selectedEmotions.contains('ANGER') ? _angerScore : null,
      'anxietyScore': _selectedEmotions.contains('ANXIETY') ? _anxietyScore : null,
      'depressionScore': _selectedEmotions.contains('DEPRESSION') ? _depressionScore : null,
      'hasteScore': _selectedEmotions.contains('HASTE') ? _hasteScore : null,
      'thought': _thought,
      'rebuttal': _rebuttal,
    };

    if (widget.initialData != null && widget.initialData!['id'] != null) {
      data['id'] = widget.initialData!['id'];
    }

    final response = await ApiService.saveAnxietyLog(uid, data);

    if (mounted) {
      setState(() => _isSaving = false);
      if (response['success'] == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('저장 완료'),
            content: const Text('감정일기가 저장되었습니다.\n꾸준한 기록이 마음의 근육을 만듭니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog close
                  Navigator.pop(context, true); // Screen close with result
                },
                child: const Text('확인'),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? '저장 실패')));
      }
    }
  }
}
