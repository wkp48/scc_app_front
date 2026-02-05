import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../utils/toast_utils.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class Alarm {
  final int id;
  TimeOfDay time;
  String message;
  String? imagePath;
  bool isActive;
  String soundType;
  String vibrationType;

  int snoozeInterval;
  int snoozeCount;
  double volume;
  int vibrationIntensity;

  Alarm({
    required this.id,
    required this.time,
    required this.message,
    this.imagePath,
    this.isActive = true,
    this.soundType = '기본 알람',
    this.vibrationType = '기본',
    this.snoozeInterval = 5,
    this.snoozeCount = 3,
    this.volume = 1.0,
    this.vibrationIntensity = 255,
  });
}

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback? onRefresh;

  const AlarmScreen({super.key, required this.userData, this.onRefresh});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<Alarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getAlarms(widget.userData['uid']);
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        if (mounted) {
          setState(() {
            _alarms = data.map((item) {
              final timeParts = (item['time'] as String).split(':');
              return Alarm(
                id: item['id'],
                time: TimeOfDay(
                  hour: int.parse(timeParts[0]),
                  minute: int.parse(timeParts[1]),
                ),
                message: item['message'] ?? '',
                imagePath: item['imagePath'],
                isActive: item['isActive'] ?? true,
                soundType: item['soundType'] ?? '기본',
                vibrationType: item['vibrationType'] ?? '기본',
                snoozeInterval: item['snoozeInterval'] ?? 5,
                snoozeCount: item['snoozeCount'] ?? 3,
              );
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ToastUtils.show(context, result['message'] ?? '알람을 불러오지 못했습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, '네트워크 오류가 발생했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('단도박 집중 알람', style: TextStyle(color: Color(0xFF262626), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF32B34A), size: 30),
            onPressed: _addAlarm,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF32B34A)))
        : _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.alarm_off, size: 80, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text('설정된 알람이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _alarms.length,
              itemBuilder: (context, index) {
                return _buildAlarmItem(_alarms[index], index);
              },
            ),
    );
  }

  void _addAlarm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmAddScreen(
          onSave: (data) async {
            final time = data['time'] as TimeOfDay;
            final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            
            final result = await ApiService.saveAlarm(widget.userData['uid'], {
              'time': timeStr,
              'message': data['message'],
              'imagePath': data['imagePath'],
              'soundType': data['soundType'],
              'vibrationType': data['vibrationType'],
              'snoozeInterval': data['snoozeInterval'],
              'snoozeCount': data['snoozeCount'],
              'volume': data['volume'],
              'vibrationIntensity': data['vibrationIntensity'],
              'isActive': true,
            });

            if (result['success'] == true) {
              final newAlarmData = result['data'];
              final newAlarm = Alarm(
                id: newAlarmData['id'],
                time: time,
                message: data['message'],
                imagePath: data['imagePath'],
                soundType: data['soundType'],
                vibrationType: data['vibrationType'],
                snoozeInterval: data['snoozeInterval'],
                snoozeCount: data['snoozeCount'],
                volume: data['volume'],
                vibrationIntensity: data['vibrationIntensity'],
              );
              setState(() {
                _alarms.add(newAlarm);
              });
              
              final payload = jsonEncode({
                'id': newAlarm.id,
                'message': newAlarm.message,
                'imagePath': newAlarm.imagePath ?? '',
                'hour': newAlarm.time.hour,
                'minute': newAlarm.time.minute,
                'soundType': newAlarm.soundType,
                'vibrationType': newAlarm.vibrationType,
                'snoozeInterval': newAlarm.snoozeInterval,
                'snoozeCount': newAlarm.snoozeCount,
                'remainingSnooze': newAlarm.snoozeCount,
                'volume': newAlarm.volume,
                'vibrationIntensity': newAlarm.vibrationIntensity,
              });
              NotificationService().scheduleAlarm(newAlarm.id, newAlarm.time, newAlarm.message, payload: payload);
              
              if (mounted) {
                ToastUtils.show(context, '알람이 추가되었습니다.');
                widget.onRefresh?.call();
              }
            } else {
              if (mounted) ToastUtils.show(context, '알람 저장에 실패했습니다.');
            }
          },
        ),
      ),
    );
  }

  Widget _buildAlarmItem(Alarm alarm, int index) {
    final period = alarm.time.hour < 12 ? '오전' : '오후';
    final hour = alarm.time.hour % 12 == 0 ? 12 : alarm.time.hour % 12;
    final minute = alarm.time.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _editAlarm(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: alarm.isActive ? const Color(0xFF32B34A) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (alarm.isActive)
                BoxShadow(
                  color: const Color(0xFF32B34A).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: alarm.isActive ? Colors.white.withOpacity(0.9) : const Color(0xFF8C8C8C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$hour:$minute',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: alarm.isActive ? Colors.white : const Color(0xFF434343),
                        ),
                      ),
                    ],
                  ),
                  if (alarm.message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      alarm.message,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: alarm.isActive ? Colors.white.withOpacity(0.9) : const Color(0xFFBFBFBF),
                      ),
                    ),
                  ],
                ],
              ),
              Switch(
                value: alarm.isActive,
                onChanged: (value) async {
                  final String timeStr = '${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}';
                  final result = await ApiService.updateAlarm(widget.userData['uid'], alarm.id, {
                    'time': timeStr,
                    'message': alarm.message,
                    'imagePath': alarm.imagePath,
                    'soundType': alarm.soundType,
                    'vibrationType': alarm.vibrationType,
                    'snoozeInterval': alarm.snoozeInterval,
                    'snoozeCount': alarm.snoozeCount,
                    'volume': alarm.volume,
                    'vibrationIntensity': alarm.vibrationIntensity,
                    'isActive': value,
                  });

                  if (result['success'] == true) {
                    setState(() {
                      alarm.isActive = value;
                    });
                    if (value) {
                      final payload = jsonEncode({
                        'id': alarm.id,
                        'message': alarm.message,
                        'imagePath': alarm.imagePath ?? '',
                        'hour': alarm.time.hour,
                        'minute': alarm.time.minute,
                        'soundType': alarm.soundType,
                        'vibrationType': alarm.vibrationType,
                        'snoozeInterval': alarm.snoozeInterval,
                        'snoozeCount': alarm.snoozeCount,
                        'remainingSnooze': alarm.snoozeCount,
                        'volume': alarm.volume,
                        'vibrationIntensity': alarm.vibrationIntensity,
                      });
                      NotificationService().scheduleAlarm(alarm.id, alarm.time, alarm.message, payload: payload);
                    } else {
                      NotificationService().cancelAlarm(alarm.id);
                    }
                    widget.onRefresh?.call();
                  } else {
                    if (mounted) ToastUtils.show(context, '상태 변경에 실패했습니다.');
                  }
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.4),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editAlarm(int index) async {
    final alarm = _alarms[index];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmAddScreen(
          initialAlarm: alarm,
          onSave: (updatedData) async {
            final String timeStr = '${updatedData['time'].hour.toString().padLeft(2, '0')}:${updatedData['time'].minute.toString().padLeft(2, '0')}';
            final result = await ApiService.updateAlarm(widget.userData['uid'], alarm.id, {
              'time': timeStr,
              'message': updatedData['message'],
              'imagePath': updatedData['imagePath'],
              'soundType': updatedData['soundType'],
              'vibrationType': updatedData['vibrationType'],
              'snoozeInterval': updatedData['snoozeInterval'],
              'snoozeCount': updatedData['snoozeCount'],
              'volume': updatedData['volume'],
              'vibrationIntensity': updatedData['vibrationIntensity'],
              'isActive': alarm.isActive,
            });

            if (result['success'] == true) {
              setState(() {
                alarm.time = updatedData['time'];
                alarm.message = updatedData['message'];
                alarm.imagePath = updatedData['imagePath'];
                alarm.soundType = updatedData['soundType'];
                alarm.vibrationType = updatedData['vibrationType'];
                alarm.snoozeInterval = updatedData['snoozeInterval'];
                alarm.snoozeCount = updatedData['snoozeCount'];
                alarm.volume = updatedData['volume'];
                alarm.vibrationIntensity = updatedData['vibrationIntensity'];
              });
              if (alarm.isActive) {
                final payload = jsonEncode({
                  'id': alarm.id,
                  'message': alarm.message,
                  'imagePath': alarm.imagePath ?? '',
                  'hour': alarm.time.hour,
                  'minute': alarm.time.minute,
                  'soundType': alarm.soundType,
                  'vibrationType': alarm.vibrationType,
                  'snoozeInterval': alarm.snoozeInterval,
                  'snoozeCount': alarm.snoozeCount,
                  'remainingSnooze': alarm.snoozeCount,
                  'volume': alarm.volume,
                  'vibrationIntensity': alarm.vibrationIntensity,
                });
                NotificationService().scheduleAlarm(alarm.id, alarm.time, alarm.message, payload: payload);
              }
              if (mounted) {
                ToastUtils.show(context, '알람이 수정되었습니다.');
                widget.onRefresh?.call();
              }
            } else {
              if (mounted) ToastUtils.show(context, '알람 수정에 실패했습니다.');
            }
          },
          onDelete: () async {
            final result = await ApiService.deleteAlarm(widget.userData['uid'], alarm.id);
            if (result['success'] == true) {
              NotificationService().cancelAlarm(alarm.id);
              setState(() {
                _alarms.removeAt(index);
              });
              if (mounted) {
                ToastUtils.show(context, '알람이 삭제되었습니다.');
                widget.onRefresh?.call();
              }
            } else {
              if (mounted) ToastUtils.show(context, '알람 삭제에 실패했습니다.');
            }
          },
        ),
      ),
    );
  }
}

class AlarmAddScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback? onDelete;
  final Alarm? initialAlarm;

  const AlarmAddScreen({
    super.key, 
    required this.onSave, 
    this.initialAlarm, 
    this.onDelete
  });

  @override
  State<AlarmAddScreen> createState() => _AlarmAddScreenState();
}

class _AlarmAddScreenState extends State<AlarmAddScreen> {
  int _selectedPeriod = 0;
  int _selectedHour = 2;
  int _selectedMinute = 0;
  String? _imagePath;
  String _selectedSound = '기본 알람';
  String _selectedVibration = '기본';
  int _selectedSnoozeInterval = 5;
  int _selectedSnoozeCount = 3;
  double _selectedVolume = 1.0;
  int _selectedVibrationIntensity = 255;
  late TextEditingController _messageController;
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    if (widget.initialAlarm != null) {
      final alarm = widget.initialAlarm!;
      _selectedPeriod = alarm.time.hour < 12 ? 0 : 1;
      _selectedHour = alarm.time.hour % 12 == 0 ? 12 : alarm.time.hour % 12;
      _selectedMinute = alarm.time.minute;
      _messageController.text = alarm.message;
      _imagePath = alarm.imagePath;
      _selectedSound = alarm.soundType;
      _selectedVibration = alarm.vibrationType;
      _selectedSnoozeInterval = alarm.snoozeInterval;
      _selectedSnoozeCount = alarm.snoozeCount;
      _selectedVolume = alarm.volume;
      _selectedVibrationIntensity = alarm.vibrationIntensity;
    } else {
      final now = TimeOfDay.now();
      _selectedPeriod = now.hour < 12 ? 0 : 1;
      _selectedHour = now.hour % 12 == 0 ? 12 : now.hour % 12;
      _selectedMinute = now.minute;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  void _handleSave() {
    final time = TimeOfDay(
      hour: _selectedPeriod == 0 
          ? (_selectedHour == 12 ? 0 : _selectedHour)
          : (_selectedHour == 12 ? 12 : _selectedHour + 12),
      minute: _selectedMinute,
    );
    widget.onSave({
      'time': time,
      'message': _messageController.text.trim(),
      'imagePath': _imagePath,
      'soundType': _selectedSound,
      'vibrationType': _selectedVibration,
      'snoozeInterval': _selectedSnoozeInterval,
      'snoozeCount': _selectedSnoozeCount,
      'volume': _selectedVolume,
      'vibrationIntensity': _selectedVibrationIntensity,
    });
    Navigator.pop(context);
  }

  bool _isPickerActive = false;

  Future<void> _pickImage() async {
    if (_isPickerActive) return;
    setState(() => _isPickerActive = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } finally {
      setState(() => _isPickerActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                  const Text('알람 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF32B34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('저장하기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          _buildWheelPicker(
                            onChanged: (index) => setState(() => _selectedPeriod = index),
                            items: const ['오전', '오후'],
                            currentIndex: _selectedPeriod,
                          ),
                          _buildWheelPicker(
                            onChanged: (index) => setState(() => _selectedHour = index + 1),
                            items: List.generate(12, (index) => (index + 1).toString().padLeft(2, '0')),
                            currentIndex: _selectedHour - 1,
                          ),
                          const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5C72EB))),
                          _buildWheelPicker(
                            onChanged: (index) => setState(() => _selectedMinute = index),
                            items: List.generate(60, (index) => index.toString().padLeft(2, '0')),
                            currentIndex: _selectedMinute,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('나의 다짐', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: '예) 단도박 할 수 있다',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('배경화면 설정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(16),
                          image: _imagePath != null ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover) : null,
                        ),
                        child: _imagePath == null ? const Icon(Icons.add, color: Colors.grey, size: 36) : null,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildSelectionItem('다시 알림', '${_selectedSnoozeInterval}분 / ${_selectedSnoozeCount}회', onTap: _showSnoozePicker),
                    const SizedBox(height: 16),
                    _buildSelectionItem('사운드', _selectedSound, onTap: _showSoundPicker),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.volume_up, size: 20, color: Colors.grey),
                        Expanded(
                          child: Slider(
                            value: _selectedVolume,
                            onChanged: (val) {
                              setState(() => _selectedVolume = val);
                              _previewPlayer.setVolume(val);
                            },
                            activeColor: const Color(0xFF5C72EB),
                          ),
                        ),
                        Text('${(_selectedVolume * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionItem('진동', _selectedVibration, onTap: _showVibrationPicker),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.vibration, size: 20, color: Colors.grey),
                        Expanded(
                          child: Slider(
                            value: _selectedVibrationIntensity.toDouble(),
                            min: 0,
                            max: 255,
                            onChanged: (val) {
                              setState(() => _selectedVibrationIntensity = val.toInt());
                            },
                            activeColor: const Color(0xFF5C72EB),
                          ),
                        ),
                        Text('${(_selectedVibrationIntensity / 255 * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF32B34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF32B34A).withOpacity(0.4),
                        ),
                        child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (widget.initialAlarm != null) ...[
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                             widget.onDelete?.call();
                             Navigator.pop(context);
                          },
                          child: const Text('알람 삭제', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelPicker({required Function(int) onChanged, required List<String> items, required int currentIndex}) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        itemExtent: 45,
        onSelectedItemChanged: onChanged,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(initialItem: currentIndex),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            final isSelected = index == currentIndex;
            return Center(
              child: Text(items[index], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF5C72EB) : Colors.black)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectionItem(String title, String value, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFFE9E9E9), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: Color(0xFF5C72EB), fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSoundPicker() {
    final sounds = [
      '알람 1', 
      '알람 2', 
      '알람 3', 
      '기본 알람', 
      '긴급 알람', 
      '경찰 사이렌', 
      '빠른 알람', 
      '탁상시계 알람'
    ];
    _showSimpleListPicker('사운드 선택', sounds, _selectedSound, (val) {
      setState(() => _selectedSound = val);
      _playPreview(val);
    });
  }

  void _playPreview(String soundName) async {
    String fileName;
    switch (soundName) {
      case '알람 1': fileName = 'logo/sounds/alarm1.mp3'; break;
      case '알람 2': fileName = 'logo/sounds/alarm2.mp3'; break;
      case '알람 3': fileName = 'logo/sounds/alarm3.mp3'; break;
      case '긴급 알람': fileName = 'logo/sounds/emergency_alarm.mp3'; break;
      case '경찰 사이렌': fileName = 'logo/sounds/police_siren_alarm.mp3'; break;
      case '빠른 알람': fileName = 'logo/sounds/quickly_alarm.mp3'; break;
      case '탁상시계 알람': fileName = 'logo/sounds/table_clock_alarm.mp3'; break;
      default: fileName = 'logo/sounds/basic_alarm.mp3'; break;
    }
    await _previewPlayer.stop();
    await _previewPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );
    await _previewPlayer.setVolume(_selectedVolume);
    await _previewPlayer.play(AssetSource(fileName));
  }

  void _showVibrationPicker() {
    final vibrations = ['기본', '심장박동', '스타카토', '긴 진동', '없음'];
    _showSimpleListPicker('진동 선택', vibrations, _selectedVibration, (val) {
      setState(() => _selectedVibration = val);
      _playVibrationPreview(val);
    });
  }

  void _playVibrationPreview(String vibrationType) async {
    if (vibrationType == '없음') {
      Vibration.cancel();
      return;
    }
    
    if (await Vibration.hasVibrator() ?? false) {
      final int intensity = _selectedVibrationIntensity;
      List<int> pattern;
      List<int> intensities;

      switch (vibrationType) {
        case '심장박동':
          pattern = [0, 200, 200, 200, 800, 200, 200, 200];
          intensities = [0, intensity, 0, intensity, 0, intensity, 0, intensity];
          break;
        case '스타카토':
          pattern = [0, 100, 100, 100, 100, 100];
          intensities = [0, intensity, 0, intensity, 0, intensity];
          break;
        case '긴 진동':
          pattern = [0, 2000];
          intensities = [0, intensity];
          break;
        case '기본':
        default:
          pattern = [0, 500, 200, 500];
          intensities = [0, intensity, 0, intensity];
          break;
      }
      Vibration.cancel();
      Vibration.vibrate(pattern: pattern, intensities: intensities);
    }
  }

  void _showSimpleListPicker(String title, List<String> items, String currentVal, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => WillPopScope(
        onWillPop: () async {
          await _previewPlayer.stop();
          Vibration.cancel();
          return true;
        },
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: items.map((item) => ListTile(
                    title: Text(item, textAlign: TextAlign.center, style: TextStyle(color: item == currentVal ? const Color(0xFF5C72EB) : Colors.black, fontWeight: item == currentVal ? FontWeight.bold : FontWeight.normal)),
                    onTap: () { onSelect(item); Navigator.pop(context); },
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnoozePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text('다시 알림 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 30),
              const Text('간격', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [5, 10, 15, 30].map((min) => GestureDetector(
                  onTap: () => setModalState(() => _selectedSnoozeInterval = min),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: _selectedSnoozeInterval == min ? const Color(0xFF5C72EB) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                    child: Text('$min분', style: TextStyle(color: _selectedSnoozeInterval == min ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 30),
              const Text('반복 횟수', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [1, 3, 5].map((count) => GestureDetector(
                  onTap: () => setModalState(() => _selectedSnoozeCount = count),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(color: _selectedSnoozeCount == count ? const Color(0xFF5C72EB) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                    child: Text('$count회', style: TextStyle(color: _selectedSnoozeCount == count ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C72EB), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () { setState(() {}); Navigator.pop(context); },
                  child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
