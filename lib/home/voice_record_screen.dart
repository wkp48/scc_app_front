import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/toast_utils.dart';

class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  late AudioPlayer _audioPlayer;
  late AnimationController _animationController;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  
  Duration _duration = Duration.zero;
  Timer? _timer;
  String _storageLocation = '불러오는 중...';
  String _basePath = '';
  
  Future<void> _editStoragePath() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '녹음 파일 저장 폴더 선택',
        initialDirectory: _storageLocation,
      );

      if (selectedDirectory != null) {
        setState(() {
          _storageLocation = selectedDirectory;
        });
      }
    } catch (e) {
      debugPrint('폴더 선택 오류: $e');
      if (mounted) {
        ToastUtils.show(context, '폴더 선택 중 오류가 발생했습니다.');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _initPath();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
       // 추후 재생 시 타이머 업데이트용
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
      if (_isRecording) setState(() {});
    });
  }

  Future<void> _initPath() async {
    String path = '';
    try {
      if (Platform.isAndroid) {
        // 안드로이드 공용 다운로드 폴더 시도
        const downloadPath = '/storage/emulated/0/Download';
        if (await Directory(downloadPath).exists()) {
          path = downloadPath;
        } else {
          final externalDir = await getExternalStorageDirectory();
          path = externalDir?.path ?? (await getApplicationDocumentsDirectory()).path;
        }
      } else {
        // iOS는 문서 폴더가 최선 (파일 앱 연동)
        final dir = await getApplicationDocumentsDirectory();
        path = dir.path;
      }
    } catch (e) {
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    if (mounted) {
      setState(() {
        _basePath = path;
        _storageLocation = path;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final dir = Directory(_storageLocation);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        final now = DateTime.now();
        final fileName = '${DateFormat('yyyy.MM.dd.HH.mm').format(now)}_희망 리코딩녹음.m4a';
        final path = '${dir.path}/$fileName';
        
        const config = RecordConfig(encoder: AudioEncoder.aacLc);
        
        await _audioRecorder.start(config, path: path);
        
        setState(() {
          _isRecording = true;
          _recordingPath = null;
          _duration = Duration.zero;
        });
        
        _startTimer();
        _animationController.repeat();
      }
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
      _animationController.stop();
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _duration = _duration + const Duration(milliseconds: 100);
      });
    });
  }

  Future<void> _playRecording() async {
    if (_recordingPath != null) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor().toString();
    return "$minutes:$seconds.$tenths";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.transparent, // 터치 영역 확보
            padding: const EdgeInsets.only(left: 16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF8C96A3)),
                SizedBox(width: 4),
                Text('뒤로가기', style: TextStyle(color: Color(0xFF8C96A3), fontSize: 16)),
              ],
            ),
          ),
        ),
        leadingWidth: 120,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            '희망 리코딩\n녹음',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3E50),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '오늘의 긍정적인 다짐을 목소리로 남겨보세요.',
            style: TextStyle(color: Color(0xFF8C96A3), fontSize: 14),
          ),
          
          const Spacer(),
          
          // Waveform placeholder (이미지 내 그래픽 구현)
          _buildWaveform(),
          
          const SizedBox(height: 40),
          
          Text(
            _formatDuration(_duration),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3E50),
            ),
          ),
          
          if (_isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFFF8282), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text('녹음 중', style: TextStyle(color: Color(0xFFFF8282), fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          
          const Spacer(),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play Button
              _buildControlButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                onPressed: _recordingPath != null ? _playRecording : null,
                enabled: _recordingPath != null,
              ),
              const SizedBox(width: 24),
              // Record Button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFEDEE), width: 4),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D4F),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Stop/Reset Button
              _buildControlButton(
                icon: Icons.stop,
                onPressed: () {
                  if (_recordingPath != null) {
                    Navigator.pop(context, _recordingPath);
                  }
                },
                enabled: _recordingPath != null,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            '녹음 버튼을 눌러 시작하고, 다시 눌러 종료하세요.',
            style: TextStyle(color: Color(0xFF8C96A3), fontSize: 13),
          ),
          
          const SizedBox(height: 40),
          
          // Bottom Info
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.folder_open, color: Color(0xFF5C72EB), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('실제 저장 경로', style: TextStyle(color: Color(0xFF8C96A3), fontSize: 13)),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _storageLocation,
                            style: const TextStyle(color: Color(0xFF2D3E50), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _editStoragePath,
                    child: const Text('변경', style: TextStyle(color: Color(0xFF36D1DC), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, VoidCallback? onPressed, bool enabled = true}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF1F4F7) : const Color(0xFFF8F9FA),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: enabled ? const Color(0xFF2D3E50) : Colors.grey[300]),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildWaveform() {
     return SizedBox(
       height: 60,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: List.generate(24, (index) {
           double waveValue = 0;
           if (_isRecording) {
             // 인덱스와 애니메이션 값을 조합하여 파동 형태 구현
             waveValue = (3.14 * (_animationController.value * 2 + index / 4)).toDouble();
             waveValue = (1 + (0.5 * (index % 2 == 0 ? 1 : -1) * (0.5 + 0.5 * (1 + sin(index % 3 == 0 ? waveValue : -waveValue))).abs())) * 15;
           } else {
             waveValue = 10.0 + (index % 4) * 2;
           }
           
           // 중앙으로 갈수록 높게 설정
           double multiplier = (12 - (index - 12).abs()) / 12.0;
           double height = waveValue * (0.5 + multiplier * 1.5);
           if (height < 6) height = 6;
           if (height > 60) height = 60;

           final isPrimary = index > 4 && index < 20;
           return Container(
             margin: const EdgeInsets.symmetric(horizontal: 2.5),
             width: 5,
             height: height,
             decoration: BoxDecoration(
               color: isPrimary 
                  ? (_isRecording ? const Color(0xFFFF4D4F).withOpacity(0.7) : const Color(0xFF36D1DC).withOpacity(0.4)) 
                  : const Color(0xFFEEEEEE),
               borderRadius: BorderRadius.circular(3),
             ),
           );
         }),
       ),
     );
  }
}
