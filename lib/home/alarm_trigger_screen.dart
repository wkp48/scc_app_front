import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class AlarmTriggerScreen extends StatefulWidget {
  final Map<String, dynamic> alarmData;

  const AlarmTriggerScreen({super.key, required this.alarmData});

  @override
  State<AlarmTriggerScreen> createState() => _AlarmTriggerScreenState();
}

class _AlarmTriggerScreenState extends State<AlarmTriggerScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _playAlarmSound();
    _startVibration();
  }

  Future<void> _startVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      final String vibrationType = widget.alarmData['vibrationType'] ?? '기본';
      if (vibrationType == '없음') return;
      final int intensity = widget.alarmData['vibrationIntensity'] ?? 255;

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
          pattern = [0, 2000, 800, 2000];
          intensities = [0, intensity, 0, intensity];
          break;
        case '기본':
        default:
          pattern = [500, 1000, 500, 1000];
          intensities = [intensity, 0, intensity, 0];
          break;
      }

      Vibration.vibrate(pattern: pattern, intensities: intensities, repeat: 0);
    }
  }

  Future<void> _playAlarmSound() async {
    // 1. 오디오 컨텍스트 설정 (강력한 포커스 요청)
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gain, // gainTransient -> gain (더 강력한 포커스)
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error setting audio context: $e');
    }

    // 2. 약간의 딜레이 (엔진 초기화 안정화)
    await Future.delayed(const Duration(milliseconds: 500));

    final String soundType = widget.alarmData['soundType'] ?? '기본 알람';
    String fileName;
    switch (soundType) {
      case '알람 1': fileName = 'logo/sounds/alarm1.mp3'; break;
      case '알람 2': fileName = 'logo/sounds/alarm2.mp3'; break;
      case '알람 3': fileName = 'logo/sounds/alarm3.mp3'; break;
      case '긴급 알람': fileName = 'logo/sounds/emergency_alarm.mp3'; break;
      case '경찰 사이렌': fileName = 'logo/sounds/police_siren_alarm.mp3'; break;
      case '빠른 알람': fileName = 'logo/sounds/quickly_alarm.mp3'; break;
      case '탁상시계 알람': fileName = 'logo/sounds/table_clock_alarm.mp3'; break;
      case '기본': 
      case '기본 알람':
      default:
        fileName = 'logo/sounds/basic_alarm.mp3';
        break;
    }

    final double volume = (widget.alarmData['volume'] ?? 1.0).toDouble();

    // 3. 재생 재시도 로직 (최대 3회)
    for (int i = 0; i < 3; i++) {
      try {
        debugPrint('Attempting to play alarm sound (Attempt ${i + 1})');
        
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(volume);
        
        // Android release 모드에서 AssetSource 경로 문제 방지를 위해 로깅
        debugPrint('Playing asset: $fileName');
        
        await _audioPlayer.play(AssetSource(fileName));
        
        debugPrint('Alarm sound started successfully');
        break; // 성공 시 루프 종료
      } catch (e) {
        debugPrint('Error playing alarm sound (Attempt ${i + 1}): $e');
        await Future.delayed(const Duration(seconds: 1)); // 실패 시 1초 대기 후 재시도
      }
    }
  }

  Future<void> _handleSnooze() async {
    final int remainingSnooze = widget.alarmData['remainingSnooze'] ?? 0;
    if (remainingSnooze <= 0) return;

    final int interval = widget.alarmData['snoozeInterval'] ?? 5;
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: interval));
    
    // 다음 알람을 위한 페이로드 업데이트 (남은 횟수 차감)
    final Map<String, dynamic> nextData = Map.from(widget.alarmData);
    nextData['remainingSnooze'] = remainingSnooze - 1;
    
    // 현재 시간 기준으로 시/분 업데이트
    nextData['hour'] = snoozeTime.hour;
    nextData['minute'] = snoozeTime.minute;

    await NotificationService().scheduleAlarm(
      widget.alarmData['id'],
      TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
      widget.alarmData['message'] ?? '단도박 할 수 있다!',
      payload: jsonEncode(nextData),
    );

    await _stopAlarm(); // Changed to await
    if (mounted) Navigator.pop(context);
  }

  Future<void> _stopAlarm() async {
    try {
      debugPrint('Stopping alarm sound and vibration...');
      _audioPlayer.stop();
      _audioPlayer.release(); // Ensure audio player resources are released

      // 진동 중지: 확실한 중지를 위해 약간의 텀을 두고 반복 호출
      Vibration.cancel();
      
      // 일부 기기에서 즉시 멈추지 않는 경우 대비
      Future.delayed(const Duration(milliseconds: 100), () => Vibration.cancel());
      Future.delayed(const Duration(milliseconds: 300), () => Vibration.cancel());

    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose(); // Dispose audio player
    _stopAlarm(); // Call _stopAlarm to ensure vibration is cancelled
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.alarmData['message'] ?? '단도박 할 수 있다!';
    final imagePath = widget.alarmData['imagePath'];
    final hour = widget.alarmData['hour'] ?? 0;
    final minute = widget.alarmData['minute'] ?? 0;
    
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$period ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
              ? Image.file(File(imagePath), fit: BoxFit.cover)
              : Image.network(
                  'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1920&q=80',
                  fit: BoxFit.cover,
                ),
          
          // Blur Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Pulse Time Display
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 70,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Resolution Text (Glass Container)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '나의 다짐',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Snooze Button
                        if ((widget.alarmData['remainingSnooze'] ?? 0) > 0) ...[
                          GestureDetector(
                            onTap: _handleSnooze,
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: const Icon(Icons.snooze, color: Colors.white, size: 32),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '다시 알림 (${widget.alarmData['remainingSnooze']}회 남음)',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],

                        // Dismiss Button
                        GestureDetector(
                          onTap: () {
                            _stopAlarm();
                            if (NotificationService().isAlarmLaunch) {
                              // 앱이 알람으로 인해 실행된 경우, 알람을 끄면 앱도 함께 종료
                              if (Platform.isAndroid) {
                                SystemNavigator.pop();
                              } else {
                                exit(0);
                              }
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF32B34A), Color(0xFF2E9941)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF32B34A).withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.close, color: Colors.white, size: 40),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '알람 끄기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
