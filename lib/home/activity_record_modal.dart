import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import 'voice_record_screen.dart';

class ActivityRecordModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String initialType;
  final VoidCallback? onSaved;
  final Map<String, dynamic>? initialActivity; // 추가

  const ActivityRecordModal({
    super.key, 
    required this.userData,
    required this.initialType,
    this.onSaved,
    this.initialActivity,
    this.allowedTypes, // 추가
  });

  final List<String>? allowedTypes;

  static void show(BuildContext context, Map<String, dynamic> userData, String type, {VoidCallback? onSaved, Map<String, dynamic>? initialActivity, List<String>? allowedTypes}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityRecordModal(
        userData: userData, 
        initialType: type, 
        onSaved: onSaved,
        initialActivity: initialActivity,
        allowedTypes: allowedTypes,
      ),
    );
  }

  @override
  State<ActivityRecordModal> createState() => _ActivityRecordModalState();
}

class _ActivityRecordModalState extends State<ActivityRecordModal> {
  late int _selectedTabIndex;
  List<String> _tabs = [];
  List<String> _typeKeys = [];

  final List<String> _allTabs = ['일상 기록', '감사 일기', '충동 일지', '희망 리코딩', '감정일기'];
  final List<String> _allTypeKeys = ['WALK', 'GRATITUDE', 'IMPULSE', 'POSITIVE_SELF', 'EMOTION_DIARY'];

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  // Gratitude specific controllers
  final TextEditingController _gratitudeToController = TextEditingController();
  final TextEditingController _gratitudeSituationController = TextEditingController();
  final TextEditingController _gratitudeEmotionController = TextEditingController();

  // Impulse specific controllers
  final TextEditingController _impulseSituationController = TextEditingController();
  final TextEditingController _impulseThoughtController = TextEditingController();
  final TextEditingController _impulseHelpfulController = TextEditingController();
  final TextEditingController _impulseAfterController = TextEditingController();

  // Emotion Diary specific controllers and state
  final TextEditingController _emotionSituationController = TextEditingController();
  final TextEditingController _emotionThoughtController = TextEditingController();
  final TextEditingController _emotionRebuttalController = TextEditingController();
  final TextEditingController _emotionAftermathController = TextEditingController(); // 추가: 5번 문항
  double _anxietyScore = 50;
  double _angerScore = 50;
  double _depressionScore = 50;
  double _hasteScore = 50;
  final Set<String> _selectedEmotions = {};

  String? _voiceFilePath;
  String? _voiceDuration;

  // 추가 필드
  String? _selectedCategory;
  double _impulseScore = 5.0;
  bool _isSavingSuccess = false;
  
  final List<String> _gratitudeCategories = [
    '나 자신', '가족', '친구', '일/공부', '건강', '자연/환경', '소소한 기쁨', '기타'
  ];

  List<String> _existingImageUrls = [];

  // 검증 에러 메시지
  String? _titleError;
  String? _timeError;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    
    // Filter tabs if allowedTypes is provided
    if (widget.allowedTypes != null && widget.allowedTypes!.isNotEmpty) {
      for (int i = 0; i < _allTypeKeys.length; i++) {
        if (widget.allowedTypes!.contains(_allTypeKeys[i])) {
          _typeKeys.add(_allTypeKeys[i]);
          _tabs.add(_allTabs[i]);
        }
      }
    } else {
      _typeKeys = List.from(_allTypeKeys);
      _tabs = List.from(_allTabs);
    }
    
    // Ensure initialType is valid, otherwise fallback
    if (!_typeKeys.contains(widget.initialType) && _typeKeys.isNotEmpty) {
       // If initialType is not in allowed list, use the first allowed one
       // But usually the caller handles this. We'll just default to 0 index of available.
       _selectedTabIndex = 0;
    } else {
       _selectedTabIndex = _typeKeys.indexOf(widget.initialType);
    }

    if (_selectedTabIndex == -1 && _typeKeys.isNotEmpty) _selectedTabIndex = 0;

    // 수정 모드 초기화
    if (widget.initialActivity != null) {
      final act = widget.initialActivity!;
      _titleController.text = act['title'] ?? '';
      _contentController.text = act['content'] ?? '';
      if (act['date'] != null) _selectedDate = DateTime.parse(act['date']);
      if (act['startTime'] != null) {
        final parts = act['startTime'].split(':');
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (act['endTime'] != null) {
        final parts = act['endTime'].split(':');
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (act['category'] != null) _selectedCategory = act['category'];
      if (act['score'] != null) _impulseScore = (act['score'] as num).toDouble();
      
      // Gratitude fields initialization
      _gratitudeToController.text = act['gratitudeTo'] ?? '';
      _gratitudeSituationController.text = act['gratitudeSituation'] ?? '';
      _gratitudeEmotionController.text = act['gratitudeEmotion'] ?? '';

      // Impulse fields initialization
      _impulseSituationController.text = act['impulseSituation'] ?? '';
      _impulseThoughtController.text = act['impulseThought'] ?? '';
      _impulseHelpfulController.text = act['impulseHelpful'] ?? '';
      _impulseAfterController.text = act['impulseAfter'] ?? '';

      if (act['imageUrls'] != null) {
        _existingImageUrls = List<String>.from(act['imageUrls']);
      }
    } else {
      // 신규 작성 시 기본 시간 설정
      _startTime = TimeOfDay.now();
    }
  }

  String _getAbsoluteUrl(String path, String baseUrl) {
    return ApiService.getAbsoluteUrl(baseUrl, path);
  }

  Widget _buildTitleInput({bool readOnly = false, String? initialValue}) {
    if (initialValue != null && _titleController.text.isEmpty) {
        _titleController.text = initialValue;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('제목', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: '제목을 입력하세요',
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _gratitudeToController.dispose();
    _gratitudeSituationController.dispose();
    _gratitudeEmotionController.dispose();
    _impulseSituationController.dispose();
    _impulseThoughtController.dispose();
    _impulseHelpfulController.dispose();
    _impulseAfterController.dispose();
    _emotionSituationController.dispose();
    _emotionThoughtController.dispose();
    _emotionRebuttalController.dispose();
    _emotionAftermathController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final String type = _typeKeys[_selectedTabIndex];
    
    // 희망 리코딩인 경우 제목이 비어있으면 기본값 자동 입력
    if (type == 'POSITIVE_SELF' && _titleController.text.trim().isEmpty) {
      _titleController.text = '희망 리코딩';
    }

    setState(() {
      final type = _typeKeys[_selectedTabIndex];
      
      // 제목이 없으면 기본값 설정
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _tabs[_selectedTabIndex];
      }

      // 검증
      if (type == 'WALK' || type == 'POSITIVE_SELF') {
        _contentError = _contentController.text.trim().isEmpty ? '내용을 입력해주세요!' : null;
      } else if (type == 'GRATITUDE') {
        _contentError = (_gratitudeToController.text.trim().isEmpty || 
                         _gratitudeSituationController.text.trim().isEmpty || 
                         _gratitudeEmotionController.text.trim().isEmpty) 
                         ? '모든 항목을 입력해주세요!' : null;
      } else if (type == 'IMPULSE') {
        _contentError = (_impulseSituationController.text.trim().isEmpty || 
                         _impulseThoughtController.text.trim().isEmpty || 
                         _impulseHelpfulController.text.trim().isEmpty || 
                         _impulseAfterController.text.trim().isEmpty) 
                         ? '모든 항목을 입력해주세요!' : null;
      } else if (type == 'EMOTION_DIARY') {
          if (_selectedEmotions.isEmpty) {
             _contentError = '하나 이상의 감정을 선택해주세요.';
          } else {
             _contentError = (_emotionSituationController.text.trim().isEmpty || 
                               _emotionThoughtController.text.trim().isEmpty || 
                               _emotionRebuttalController.text.trim().isEmpty ||
                               _emotionAftermathController.text.trim().isEmpty)
                               ? '모든 항목을 입력해주세요!' : null;
          }
      } else {
        _contentError = null;
      }
    });

    if (_contentError != null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String type = _typeKeys[_selectedTabIndex];
      final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      String? startTimeStr;
      String? endTimeStr;

      // 모든 기록은 현 시간으로 설정 (또는 기존 시간 유지)
      if (widget.initialActivity != null && widget.initialActivity?['startTime'] != null) {
          startTimeStr = widget.initialActivity?['startTime'];
          endTimeStr = widget.initialActivity?['endTime'];
      } else {
          // [Changed] 충동일지의 경우 선택된 시간 사용, 그 외에는 현재 시간
          if (type == 'IMPULSE' && _startTime != null) {
             startTimeStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00';
          } else {
             final now = DateTime.now();
             startTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
             
             if (type == 'POSITIVE_SELF' && _voiceDuration != null) {
               endTimeStr = _voiceDuration;
             }
          }
      }



      if (type == 'EMOTION_DIARY') {
          await _handleEmotionDiarySave();
          return;
      }
      
      final response = await ApiService.saveActivityRecord(
        uid: widget.userData['uid'],
        type: type,
        date: dateStr,
        startTime: startTimeStr,
        endTime: endTimeStr,
        title: _titleController.text,
        category: type == 'GRATITUDE' ? _selectedCategory : null,
        score: type == 'IMPULSE' ? _impulseScore.toInt() : null,
        content: _contentController.text,
        gratitudeTo: type == 'GRATITUDE' ? _gratitudeToController.text : null,
        gratitudeSituation: type == 'GRATITUDE' ? _gratitudeSituationController.text : null,
        gratitudeEmotion: type == 'GRATITUDE' ? _gratitudeEmotionController.text : null,
        impulseSituation: type == 'IMPULSE' ? _impulseSituationController.text : null,
        impulseThought: type == 'IMPULSE' ? _impulseThoughtController.text : null,
        impulseHelpful: type == 'IMPULSE' ? _impulseHelpfulController.text : null,
        impulseAfter: type == 'IMPULSE' ? _impulseAfterController.text : null,
        images: _selectedImages.map((xfile) => File(xfile.path)).toList(),
        voiceFile: _voiceFilePath != null ? File(_voiceFilePath!) : null,
        activityId: widget.initialActivity?['id'], 
      );

      if (response['success']) {
        _isSavingSuccess = true;
        if (mounted) {
          Navigator.pop(context, true);
          if (widget.onSaved != null) widget.onSaved!();
        }
      } else {
        setState(() => _isSaving = false);
        if (mounted) {
          ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다.');
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ToastUtils.show(context, '오류가 발생했습니다: $e');
      }
    }
  }



  Future<void> _handleEmotionDiarySave() async {
    final data = {
      'situation': _emotionSituationController.text,
      'angerScore': _selectedEmotions.contains('ANGER') ? _angerScore : null,
      'anxietyScore': _selectedEmotions.contains('ANXIETY') ? _anxietyScore : null,
      'depressionScore': _selectedEmotions.contains('DEPRESSION') ? _depressionScore : null,
      'hasteScore': _selectedEmotions.contains('HASTE') ? _hasteScore : null,
      'thought': _emotionThoughtController.text,
      'rebuttal': _emotionRebuttalController.text,
      'aftermath': _emotionAftermathController.text, // 추가
    };
    
    // images: _selectedImages list (List<XFile> -> List<File>)
    final List<File> files = _selectedImages.map((x) => File(x.path)).toList();

    final response = await ApiService.saveAnxietyLog(
      widget.userData['uid'] ?? widget.userData['userid'], 
      data,
      images: files.isNotEmpty ? files : null,
    );

    if (response['success']) {
        _isSavingSuccess = true;
        if (mounted) {
          Navigator.pop(context, true);
          if (widget.onSaved != null) widget.onSaved!();
        }
      } else {
        setState(() => _isSaving = false);
        if (mounted) {
          ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다.');
        }
      }
  }

  bool _hasChanges() {
    // 저장 중이거나 이미 성공한 경우 변경사항 없는 것으로 간주
    if (_isSaving || _isSavingSuccess) return false;

    if (widget.initialActivity == null) {
      // 신규 등록 모드
      return _titleController.text.isNotEmpty ||
             _contentController.text.isNotEmpty ||
             _selectedImages.isNotEmpty ||
             _voiceFilePath != null ||
             _selectedCategory != null ||
             _impulseScore != 5.0;
    } else {
      // 수정 모드
      final act = widget.initialActivity!;
      bool contentChanged = _contentController.text != (act['content'] ?? '');
      bool categoryChanged = _selectedCategory != act['category'];
      bool scoreChanged = _impulseScore != (act['score'] as num?)?.toDouble();
      
      bool gratitudeToChanged = _gratitudeToController.text != (act['gratitudeTo'] ?? '');
      bool gratitudeSituationChanged = _gratitudeSituationController.text != (act['gratitudeSituation'] ?? '');
      bool gratitudeEmotionChanged = _gratitudeEmotionController.text != (act['gratitudeEmotion'] ?? '');

      bool impulseSituationChanged = _impulseSituationController.text != (act['impulseSituation'] ?? '');
      bool impulseThoughtChanged = _impulseThoughtController.text != (act['impulseThought'] ?? '');
      bool impulseHelpfulChanged = _impulseHelpfulController.text != (act['impulseHelpful'] ?? '');
      bool impulseAfterChanged = _impulseAfterController.text != (act['impulseAfter'] ?? '');

      bool emotionSituationChanged = _emotionSituationController.text != (act['situation'] ?? '');
      bool emotionThoughtChanged = _emotionThoughtController.text != (act['thought'] ?? '');
      bool emotionRebuttalChanged = _emotionRebuttalController.text != (act['rebuttal'] ?? '');

      bool imagesAdded = _selectedImages.isNotEmpty;
      // 기존 이미지 개수 변화 체크 (삭제된 경우)
      bool imagesRemoved = _existingImageUrls.length != (act['imageUrls'] as List?)?.length;
      
      return contentChanged || categoryChanged || scoreChanged || gratitudeToChanged || 
             gratitudeSituationChanged || gratitudeEmotionChanged || 
             impulseSituationChanged || impulseThoughtChanged || impulseHelpfulChanged || impulseAfterChanged ||
             emotionSituationChanged || emotionThoughtChanged || emotionRebuttalChanged ||
             imagesAdded || imagesRemoved;
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작성 취소'),
        content: const Text('변경사항이 저장되지 않을 수 있습니다.\n정말로 닫으시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 작성', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('닫기', style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showTabSwitchConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('활동 변경'),
        content: const Text('현재 작성 중인 내용이 사라질 수 있습니다.\n정말로 다른 활동으로 변경하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경', style: TextStyle(color: Color(0xFF5C72EB))),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C72EB),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges() || _isSavingSuccess,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTabBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateTimeInfo(),
                          const SizedBox(height: 24),
                          _buildSpecializedInput(),
                          const SizedBox(height: 24),
                           const SizedBox(height: 24),
                           _buildImageUploadSection(), // 모든 탭에서 이미지 업로드 허용 (감정일기 포함)
                          if (_typeKeys[_selectedTabIndex] == 'POSITIVE_SELF') ...[
                            const SizedBox(height: 24),
                            _buildVoiceSection(),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomButtons(),
                ],
              ),
              if (_isSaving)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5C72EB)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_selectedTabIndex == index) return;
                
                // 수정 모드인 경우 타입 변경 불가 안내
                if (widget.initialActivity != null) {
                  ToastUtils.show(context, '저장된 기록의 종류는 변경할 수 없습니다.');
                  return;
                }

                if (_hasChanges()) {
                  final leave = await _showTabSwitchConfirmationDialog();
                  if (!leave) return;
                }
                
                setState(() {
                  _selectedTabIndex = index;
                  // 탭 변경 시 입력 데이터 초기화
                  _titleController.clear();
                  _contentController.clear();
                  _selectedImages.clear();
                  _selectedCategory = null;
                  _impulseScore = 5.0;
                  _voiceFilePath = null;
                  
                  // Reset Emotion Diary state
                  _emotionSituationController.clear();
                  _emotionThoughtController.clear();
                  _emotionRebuttalController.clear();
                  _selectedEmotions.clear();
                  _anxietyScore = 50;
                  _angerScore = 50;
                  _depressionScore = 50;
                  _hasteScore = 50;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected ? [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ] : null,
                ),
                child: Text(
                  _tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey[500],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDateTimeInfo() {
    String formattedDate = DateFormat('yyyy/MM/dd').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: _selectDate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF5C72EB)),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5C72EB)),
                  ),
                ],
              ),
            ),
            if (_selectedTabIndex < _typeKeys.length && _typeKeys[_selectedTabIndex] == 'IMPULSE') ...[
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _selectTime(isStart: true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Color(0xFF5C72EB)),
                    const SizedBox(width: 8),
                    Text(
                      _startTime?.format(context) ?? '시간 선택',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5C72EB)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (_timeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(_timeError!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSpecializedInput() {
    final type = _typeKeys[_selectedTabIndex];
    
    switch (type) {
      case 'GRATITUDE':
        return _buildGratitudeInput();
      case 'IMPULSE':
        return _buildImpulseInput();
      case 'WALK':
        return _buildDailyRecordInput();
      case 'POSITIVE_SELF':
        return _buildContentInput();
      case 'EMOTION_DIARY':
        return _buildEmotionDiaryInput();
      default:
        return _buildContentInput();
    }
  }

  Widget _buildGratitudeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. 누구에게 감사했나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_gratitudeToController, '누구에게 감사했는지 적어주세요'),
        
        const SizedBox(height: 24),
        const Text('2. 어떤 상황이었나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_gratitudeSituationController, '어떤 상황이었는지 적어주세요'),
        
        const SizedBox(height: 24),
        const Text('3. 어떤 감정을 느꼈나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_gratitudeEmotionController, '어떤 감정을 느꼈는지 적어주세요'),

        if (_contentError != null && _typeKeys[_selectedTabIndex] == 'GRATITUDE')
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text(_contentError!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSubjectiveInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildImpulseInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('충동 강도', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _impulseScore,
                min: 0,
                max: 10,
                divisions: 10,
                activeColor: const Color(0xFFFF4D4F),
                inactiveColor: const Color(0xFFFFF1F0),
                label: _impulseScore.toInt().toString(),
                onChanged: (val) => setState(() => _impulseScore = val),
              ),
            ),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                _impulseScore.toInt().toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF4D4F)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('1. 어떤 상황이었나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_impulseSituationController, '어떤 상황이었는지 적어주세요'),
        
        const SizedBox(height: 24),
        const Text('2. 어떤 생각이 들었나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_impulseThoughtController, 'ex) 도박해서 딴 돈으로 빚을 갚고 싶다.'),
        
        const SizedBox(height: 24),
        const Text('3. 충동을 물리치는데 도움이 되었던 생각이나 상황은 무엇이었나요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_impulseHelpfulController, '도움이 된 내용을 적어주세요'),

        const SizedBox(height: 24),
        const Text('4. 충동이 지나간 후 드는 감정이나 생각은 무엇인가요?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_impulseAfterController, '충동이 지난 후의 느낌을 적어주세요'),

        if (_contentError != null && _typeKeys[_selectedTabIndex] == 'IMPULSE')
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text(_contentError!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildDailyRecordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('일상 기록', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildContentInput(hint: '나의 일상을 자유롭게 기록해보세요'),
      ],
    );
  }



  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('사진 첨부', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 24)),
                ),
              ),

              ...List.generate(_existingImageUrls.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<String>(
                          future: ApiService.baseUrl,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[100],
                              );
                            }
                            final baseUrl = snapshot.data!;
                            return Image.network(
                              _getAbsoluteUrl(_existingImageUrls[index], baseUrl),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              headers: {'X-User-Uid': widget.userData['uid'] ?? ''},
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            );
                          }
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _existingImageUrls.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              ...List.generate(_selectedImages.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentInput({String hint = '내용을 입력하세요!'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _contentController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        if (_contentError != null && (_typeKeys[_selectedTabIndex] == 'WALK' || _typeKeys[_selectedTabIndex] == 'POSITIVE_SELF'))
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(_contentError!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('녹음파일 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            if (_voiceFilePath != null)
              GestureDetector(
                onTap: () => setState(() => _voiceFilePath = null),
                child: const Text('삭제', style: TextStyle(color: Color(0xFFFF4D4F), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _voiceFilePath == null 
            ? Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VoiceRecordScreen()),
                      );
                      if (result != null && result is Map) {
                        setState(() {
                          _voiceFilePath = result['path'];
                          _voiceDuration = result['duration'];
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4D4F), 
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '버튼을 눌러 희망 리코딩을 녹음해보세요.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, size: 18, color: Color(0xFFFF4D4F)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _voiceFilePath!.split('/').last,
                              style: const TextStyle(
                                color: Color(0xFF1F1F1F),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '저장위치: ${_voiceFilePath!}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F0),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF52C41A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmotionDiaryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. 상황 (Situation)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_emotionSituationController, '어떤 상황에서 감정의 변화를 느꼈나요?'),
        
        const SizedBox(height: 24),
        const Text('2. 감정과 점수 (Feeling)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const Text('느껴지는 감정을 모두 선택하고 점수를 매겨보세요.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        _buildEmotionChips(),
        
        if (_selectedEmotions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
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
        const Text('3. 자동적 사고 (Thoughts)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_emotionThoughtController, '그때 순간적으로 어떤 생각이 스쳤나요?'),
        
        const SizedBox(height: 24),
        const Text('4. 반박하기 (Rebuttal)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_emotionRebuttalController, '그 생각이 사실이 아닐 수도 있는 증거는?'),

        const SizedBox(height: 24),
        const Text('5. 상황 종료 후 (Aftermath)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSubjectiveInput(_emotionAftermathController, '상황이 종료된 후의 감정이나 생각은 어땠나요?'),

        if (_contentError != null && _typeKeys[_selectedTabIndex] == 'EMOTION_DIARY')
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text(_contentError!, style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
          ),
      ],
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
}
