import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../login/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/toggle_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  String _appVersion = '';
  String _versionPrefix = '[BETA]';
  double _downloadProgress = 0;
  bool _isDownloading = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward().then((_) {
      // 주 애니메이션이 끝나면 펄스 효과를 4번 실행
      int count = 0;
      _pulseController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          count++;
          if (count < 4) {
            _pulseController.forward(from: 0.0);
          }
        }
      });
      _pulseController.forward();
    });
    
    _loadAppVersion();
    _startAppDelay();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          final prefix = _versionPrefix.isNotEmpty ? '$_versionPrefix ' : '';
          _appVersion = '$prefix v${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'v1.0.0';
        });
      }
    }
  }

  void _startAppDelay() async {
    // 애니메이션 속도 및 펄스(3회)에 맞춰 대기 시간 조절 (5.5초)
    await Future.delayed(const Duration(milliseconds: 5500));
    if (mounted) {
      await _checkVersionAndProceed();
    }
  }

  Future<void> _checkVersionAndProceed() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // 버전과 빌드 번호를 합친 전체 버전 문자열 (예: 1.0.2+2)
      final currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      final osType = Platform.isAndroid ? 'ANDROID' : 'IOS';

      final versionData = await ApiService.checkAppVersion(osType);
      
      if (versionData.isNotEmpty) {
        final latestVersion = versionData['latestVersion'] as String;
        final minVersion = versionData['minVersion'] as String;
        final updateUrl = versionData['updateUrl'] as String;
        final updateMessage = versionData['updateMessage'] as String? ?? '새로운 버전이 출시되었습니다.';

        // 디버깅을 위한 로그 출력
        debugPrint('--- Version Check ---');
        debugPrint('OS: $osType');
        debugPrint('Current: $currentVersion');
        debugPrint('Latest: $latestVersion');
        debugPrint('Min: $minVersion');

        bool isMandatory = _isUpdateNeeded(currentVersion, minVersion);
        bool isLatest = _isUpdateNeeded(currentVersion, latestVersion);

        if (isMandatory || isLatest) {
          if (!mounted) return;

          // 강제 업데이트이고 안드로이드 APK인 경우에만 자동 업데이트 시도 (대소문자 무시)
          bool isAndroidApk = Platform.isAndroid && updateUrl.toLowerCase().endsWith('.apk');
          
          if (isMandatory && isAndroidApk) {
            debugPrint('Starting automatic mandatory OTA update for Android...');
            _startAndroidUpdate(updateUrl);
            return;
          }

          // 그 외의 경우(선택 업데이트 또는 iOS 등) 팝업 표시
          bool proceed = await _showUpdateDialog(updateUrl, updateMessage, isForce: isMandatory);
          
          if (!isMandatory && !proceed) {
            // 강제가 아니고 사용자가 취소한 경우 다음 화면으로
            _proceedToNextScreen();
          } else if (proceed && isAndroidApk) {
            // 사용자가 업데이트를 선택했고 안드로이드 APK인 경우 자동 업데이트 시작
            _startAndroidUpdate(updateUrl);
          } else if (proceed) {
            // 그 외(스토어 이동 등)는 _showUpdateDialog 내부에서 처리됨
            // 만약 팝업이 닫혔는데 여전히 여기에 있다면 다음 화면으로 시도
            if (!isMandatory) _proceedToNextScreen();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }

    _proceedToNextScreen();
  }

  bool _isUpdateNeeded(String current, String target) {
    try {
      if (current == target) return false;

      // 숫자와 점(.)만 남기고 제거 (v1.0.0 -> 1.0.0)
      String cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '.');
      String cleanTarget = target.replaceAll(RegExp(r'[^0-9.]'), '.');

      List<int> currentParts = cleanCurrent.split('.').where((s) => s.isNotEmpty).map((e) => int.tryParse(e) ?? 0).toList();
      List<int> targetParts = cleanTarget.split('.').where((s) => s.isNotEmpty).map((e) => int.tryParse(e) ?? 0).toList();

      int maxLength = currentParts.length > targetParts.length ? currentParts.length : targetParts.length;

      for (int i = 0; i < maxLength; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int t = i < targetParts.length ? targetParts[i] : 0;
        
        if (t > c) return true;
        if (t < c) return false;
      }
    } catch (e) {
      debugPrint('Version comparison error: $e');
    }
    return false;
  }

  Future<bool> _showUpdateDialog(String url, String message, {required bool isForce}) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) => AlertDialog(
        title: Text(isForce ? '필수 업데이트' : '업데이트 알림'),
        content: Text(message),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('나중에 하기'),
            ),
          ElevatedButton(
            onPressed: () async {
              // 대소문자 무시 체크
              if (Platform.isAndroid && url.toLowerCase().endsWith('.apk')) {
                Navigator.pop(context, true);
                // _startAndroidUpdate(url) call removed to prevent duplicate execution
              } else {
                final uri = Uri.parse(url);
                try {
                  bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (launched && !isForce) {
                    if (mounted) Navigator.pop(context, true);
                  }
                } catch (e) {
                  debugPrint('URL 실행 실패: $e');
                }
              }
            },
            child: const Text('업데이트 하러가기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _startAndroidUpdate(String url) async {
    if (!mounted) return;
    if (_isDownloading) return; // Prevent multiple concurrent downloads

    // 안드로이드 8.0 이상에서 '알 수 없는 앱 설치' 권한 체크 및 요청
    if (Platform.isAndroid) {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        // 권한이 없으면 요청 (설정 화면으로 이동할 수 있음)
        status = await Permission.requestInstallPackages.request();
        // 사용자가 설정에서 돌아온 후 상태 재확인
        if (!status.isGranted) {
            status = await Permission.requestInstallPackages.status;
        }
        
        if (!status.isGranted) {
          if (mounted) {
            _showPermissionDeniedDialog();
          }
          return;
        }
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadStatus = '업데이트 확인 중...';
      _downloadProgress = 0;
    });

    try {
      final dio = Dio();
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('저장소를 찾을 수 없습니다.');
      
      final savePath = "${dir.path}/scc_app_update.apk";
      
      // 기존 파일 삭제
      final file = File(savePath);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 파일 삭제 실패 시 무시하고 진행
        debugPrint('Old file delete failed: $e');
      }

      final response = await dio.download(
        url,
        savePath,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            if (!mounted) return;
            setState(() {
               _downloadStatus = '최신 버전 다운로드 중... (${(received / total * 100).toStringAsFixed(0)}%)';
               _downloadProgress = (received / total * 100);
            });
          }
        },
      );

      if (!mounted) return;
      
      // 파일 무결성 검증
      final downloadedFile = File(savePath);
      final fileSize = await downloadedFile.length();
      final expectedSizeHeader = response.headers.value('content-length');
      
      debugPrint('File size: $fileSize bytes');
      debugPrint('Expected size: $expectedSizeHeader bytes');

      if (expectedSizeHeader != null) {
        final expectedSize = int.tryParse(expectedSizeHeader);
        if (expectedSize != null && fileSize != expectedSize) {
           throw Exception('다운로드된 파일 크기가 일치하지 않습니다. (예상: $expectedSize, 실제: $fileSize)');
        }
      } else {
        // Content-Length가 없는 경우 최소 크기 체크 (예: 5MB)
        if (fileSize < 5 * 1024 * 1024) { 
           throw Exception('다운로드된 파일이 너무 작습니다. 손상된 파일일 수 있습니다. ($fileSize bytes)');
        }
      }

      setState(() {
        _downloadStatus = '업데이트 설치 준비 중...';
        _downloadProgress = 100;
      });

      // 설치 실행 (open_filex) - MIME Type 명시
      final result = await OpenFilex.open(savePath, type: "application/vnd.android.package-archive");
      debugPrint('Open file result: ${result.message}');

      if (mounted) {
         setState(() {
          _isDownloading = false;
        });
      }

    } catch (e) {
      debugPrint('Download/Install Error: $e');
      if (mounted) {
        setState(() {
          _downloadStatus = '오류 발생: ${e.toString()}';
          _isDownloading = false;
        });
        
        // 오류 시 다이얼로그
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('오류'),
            content: Text('업데이트 다운로드 중 오류가 발생했습니다.\n$e'),
            actions: [
              TextButton(
                onPressed: () {
                   Navigator.pop(context);
                   _proceedToNextScreen();
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _proceedToNextScreen() async {
    if (!mounted) return;

    debugPrint('SplashScreen: _proceedToNextScreen called');

    // 1. 알람 실행 여부 우선 확인
    if (NotificationService().isAlarmLaunch) {
      debugPrint('SplashScreen: Detected isAlarmLaunch = true');
      debugPrint('SplashScreen: Waiting for NotificationService to handle navigation...');
      
      // 알람 화면 이동을 위한 안전장치: 5초간 대기 후에도 이동하지 않으면 강제 진행
      // (NotificationService가 실패했을 경우 대비)
      bool alarmHandled = false;
      
      // 모니터링: 알람 화면이 스택에 올라왔는지 체크 (간접적 확인)하거나 단순히 시간 대기
      // 여기서는 단순히 5초 기다리면서 로그 찍기
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        // NotificationService에서 처리가 완료되었다면 isAlarmLaunch가 false로 변할 수 있음 (로직에 따라)
        // 현재 로직상 _handleAlarmAction 끝에서 isAlarmLaunch = false로 바꿈.
        if (!NotificationService().isAlarmLaunch) {
          debugPrint('SplashScreen: NotificationService reset isAlarmLaunch to false. Assuming success.');
          alarmHandled = true;
          break;
        }
      }

      if (alarmHandled) {
        debugPrint('SplashScreen: Alarm seems to be handled. Staying on Splash (letting pushed route cover).');
        return; 
      } else {
        debugPrint('SplashScreen: [WARNING] Alarm launch timeout. NotificationService did not finish in time. Proceeding to normal flow.');
        // 타임아웃 발생 시에도 그냥 진행시킴 (앱이 멈추는 것 방지)
      }
    } else {
      debugPrint('SplashScreen: isAlarmLaunch is false.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isAutoLogin = prefs.getBool('auto_login') ?? false;
      debugPrint('SplashScreen: isAutoLogin: $isAutoLogin');
      
      if (isAutoLogin) {
        final savedId = prefs.getString('saved_userid');
        final savedPw = prefs.getString('saved_password');
        debugPrint('SplashScreen: Saved credentials found: ${savedId != null}');
        
        if (savedId != null && savedPw != null && savedId.isNotEmpty && savedPw.isNotEmpty) {
          // 자동 로그인 시도
          debugPrint('SplashScreen: Attempting auto-login...');
          final response = await ApiService.login(savedId, savedPw);
          debugPrint('SplashScreen: Auto-login response success: ${response['success']}');
          
          if (response['success'] == true) {
            final userData = response['data'];
            
            if (userData['userType'] != 'SUBJECT') {
              debugPrint('SplashScreen: User is not SUBJECT. Going to LoginScreen.');
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
              return;
            }

            // 온보딩 상태 확인
            final statusResponse = await ApiService.getOnboardingStatus(userData['uid']);
            bool isCompleted = false;
            
            if (statusResponse['success'] == true) {
              isCompleted = statusResponse['data']['isCompleted'] ?? false;
            }
            debugPrint('SplashScreen: Onboarding completed: $isCompleted');

            if (mounted) {
              if (isCompleted) {
                Navigator.of(context).pushReplacementNamed('/home', arguments: userData);
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
              return;
            }
          } else {
             debugPrint('SplashScreen: Auto-login failed (invalid credentials?).');
          }
        }
      }
    } catch (e) {
      debugPrint('Auto login failed in SplashScreen: $e');
    }

    if (mounted) {
      debugPrint('SplashScreen: Proceeding to LoginScreen (Default fallback).');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 필요'),
        content: const Text('앱 업데이트를 설치하기 위해서는\n"알 수 없는 앱 설치" 권한이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToNextScreen();
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // 설정 갔다와서 다시 시도? 
              // 여기서는 그냥 설정만 열어주고 사용자가 다시 앱을 켜거나 하는 흐름으로
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 새 로고 이미지 (애니메이션 적용된 Flutter 위젯)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return ToggleLogo(
                        animationController: _animationController,
                        pulseController: _pulseController,
                      );
                    },
                  ),
                  
                  // 업데이트 진행바 (다운로드 시에만 표시)
                  if (_isDownloading) ...[
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF8942E)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_downloadStatus',
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 버전 표시
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

