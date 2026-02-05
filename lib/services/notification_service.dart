import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../home/alarm_trigger_screen.dart';
import '../services/api_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground processing: ${notificationResponse.payload}');
}

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 네이티브와 통신하기 위한 채널
  static const platform = MethodChannel('com.scc.scc_app/alarm');

  // 알람으로 앱이 실행되었는지 여부
  bool isAlarmLaunch = false;
  
  // 알람 화면이 닫혔음을 알리는 스트림
  final StreamController<void> _alarmDismissedController = StreamController<void>.broadcast();
  Stream<void> get onAlarmDismissed => _alarmDismissedController.stream;

  // 알람 중복 실행 방지를 위한 마지막 실행 시간
  DateTime? _lastAlarmTriggerTime;

  // 격언 알림을 위한 스트림 및 버퍼
  final StreamController<Map<String, dynamic>> _maximStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMaximReceived => _maximStreamController.stream;
  Map<String, dynamic>? _pendingMaxim;
  Map<String, dynamic>? get pendingMaxim => _pendingMaxim;

  void clearPendingMaxim() {
    _pendingMaxim = null;
  }

  // 포그라운드 상태에서 알람 발생 시 처리를 위한 타이머 관리
  final Map<int, Timer> _foregroundTimers = {};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativeLaunch();
    }
  }

  Future<void> init() async {
    // 1. 타임존 설정
    tz_data.initializeTimeZones();
    try {
      final dynamic timeZoneResult = await FlutterTimezone.getLocalTimezone();
      debugPrint('Local Timezone Result: $timeZoneResult');
      
      String cleanTz = timeZoneResult.toString();
      if (cleanTz.contains('(')) {
        cleanTz = cleanTz.split('(')[1].split(',')[0].split(')')[0].trim();
      }
      
      try {
        tz.setLocalLocation(tz.getLocation(cleanTz));
      } catch (e) {
        debugPrint('Failed to get location for $cleanTz, using Asia/Seoul');
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      }
    } catch (e) {
      debugPrint('Timezone initialization failed: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    // 2. 안드로이드 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS 초기화 설정 (Darwin)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 4. 통합 초기화
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked with payload: ${response.payload}');
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!);
            _handleAlarmAction(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    
    // FCM 초기화
    await _initFCM();

    // 4-1. 안드로이드 알림 채널 수동 생성 (중요)
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'scc_alarm_clock_channel', // 변경된 채널 ID (알람 시계 모드용)
        '단도박 집중 알람',
        description: '단도박 실천을 위한 중요 알람입니다.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(channel);
    }

    // 5. 권한 요청
    await requestPermissions();

    // 6. 알림 클릭으로 앱이 시작된 경우 처리 (Flutter Local Notifications)
    final NotificationAppLaunchDetails? launchDetails = 
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      if (launchDetails.notificationResponse?.payload != null) {
        try {
          final data = jsonDecode(launchDetails.notificationResponse!.payload!);
          // 앱이 완전히 뜰 때까지 잠시 기다림
          Future.delayed(const Duration(seconds: 1), () => _handleAlarmAction(data));
        } catch (e) {
          debugPrint('Error parsing launch notification payload: $e');
        }
      }
    }

    // 7. Native AlarmReceiver에 의해 앱이 강제 실행된 경우 처리 (Terminated -> Fullscreen)
    // 앱 초기 실행 시 체크
    _checkNativeLaunch();

    // 8. FCM 초기 메시지 확인 (앱이 꺼진 상태에서 알림 클릭 시)
    await _setupInteractedMessage();
  }

  Future<void> _setupInteractedMessage() async {
    try {
      // 앱이 종료된 상태에서 알림을 클릭하여 시작된 경우 (약간의 재시도 로직 추가)
      RemoteMessage? initialMessage;
      for (int i = 0; i < 3; i++) {
        initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (initialMessage != null) {
        debugPrint('=== [NOTIFICATION] App launched via FCM Notification ===');
        debugPrint('=== [NOTIFICATION] Initial Message Data: ${initialMessage.data}');
        
        // 데이터 처리 로직 재사용
        _handleAlarmAction(initialMessage.data..addAll({'source': 'FCM_INITIAL'}));
        
        // 만약 격언이라면 _handleAlarmAction 내부에서 _pendingMaxim에 저장됨.
      } else {
        debugPrint('=== [NOTIFICATION] App launched normally (No FCM Initial Message found after retries) ===');
      }

      // 백그라운드 상태에서 알림 클릭 시
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('=== [NOTIFICATION] App opened from Background via FCM ===');
        debugPrint('=== [NOTIFICATION] Message Data: ${message.data}');
        _handleAlarmAction(message.data..addAll({'source': 'FCM_BACKGROUND'}));
      });
      
    } catch (e) {
      debugPrint('=== [NOTIFICATION] Error in _setupInteractedMessage: $e');
    }
  }

  // 현재 로그인한 사용자의 UID
  String? _currentUid;

  // 로그인 후 호출하여 토큰과 UID를 매핑하고 서버에 전송
  Future<void> registerUserToken(String uid) async {
    _currentUid = uid;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('Registering FCM Token for UID: $uid');
        await ApiService.saveFCMToken(uid, token);
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> _checkNativeLaunch() async {
    if (Platform.isAndroid) {
      try {
        final String? nativePayload = await platform.invokeMethod('checkLaunchIntent');
        if (nativePayload != null) {
          isAlarmLaunch = true; // 알람 실행 상태 플래그 설정
          debugPrint('=== [ALARM] App launched via Native AlarmReceiver! ===');
          debugPrint('=== [ALARM] Payload: $nativePayload');
          try {
             final data = jsonDecode(nativePayload);
             // 스플래시 등을 건너뛰고 즉시 이동하기 위해 약간의 딜레이 후 실행
             Future.delayed(const Duration(milliseconds: 500), () => _handleAlarmAction(data));
          } catch (e) {
             debugPrint('=== [ALARM] Error parsing native payload: $e');
             isAlarmLaunch = false; // 파싱 실패 시 플래그 해제
          }
        }
      } catch (e) {
        debugPrint('=== [ALARM] Failed to check native launch intent: $e');
      }
    }
  }

  Future<void> _handleAlarmAction(dynamic rawData) async {
    debugPrint('=== [NOTIFICATION] _handleAlarmAction triggered ===');
    debugPrint('=== [NOTIFICATION] Received Raw Data: $rawData');
    
    if (rawData == null) return;

    // 1. 데이터 정규화 (중첩된 data 맵 처리)
    Map<String, dynamic> data = {};
    if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
      
      // FCM 데이터가 data 필드 안에 중첩되어 있는 경우 병합
      if (data.containsKey('data') && data['data'] is Map) {
        final nestedData = data['data'] as Map;
        nestedData.forEach((key, value) {
          data[key.toString()] = value;
        });
      }
    } else {
      debugPrint('=== [NOTIFICATION] Data is not a Map. Ignoring. ===');
      return;
    }

    // 디바운싱: 최근 3초 이내에 실행된 적이 있다면 무시
    if (_lastAlarmTriggerTime != null && 
        DateTime.now().difference(_lastAlarmTriggerTime!) < const Duration(seconds: 3)) {
      debugPrint('=== [NOTIFICATION] Debounced duplicate notification trigger ===');
      return;
    }
    _lastAlarmTriggerTime = DateTime.now();

    // 2. 격언 데이터 확인
    final String? type = data['type']?.toString().toUpperCase();
    final bool looksLikeMaxim = (type == 'MAXIM') || 
                               (data.containsKey('content') && !data.containsKey('message') && !data.containsKey('id'));

    debugPrint('=== [NOTIFICATION] Normalized Data: $data');
    debugPrint('=== [NOTIFICATION] Type: $type, LooksLikeMaxim: $looksLikeMaxim');

    if (looksLikeMaxim) {
      debugPrint('=== [MAXIM] Maxim notification clicked. Broadcasting directly. ===');
      _pendingMaxim = data;
      _maximStreamController.add(data);
      return;
    }

    // 3. 알람 데이터 유효성 검사 (ID 필수)
    if (!data.containsKey('id')) {
      debugPrint('=== [NOTIFICATION] Data missing "id". Not a valid alarm payload. Ignoring. ===');
      return;
    }

    debugPrint('=== [ALARM] Valid Alarm detected (ID: ${data['id']}). Waiting for Navigator... ===');

    // Navigator가 준비될 때까지 대기 (최대 10초)
    int attempts = 0;
    while (navigatorKey.currentState == null && attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (navigatorKey.currentState != null) {
      debugPrint('=== [ALARM] Navigator ready. Pushing AlarmTriggerScreen ===');
      
      // 혹시 모를 검은 화면 방지를 위해 약간의 추가 딜레이 후 진입
      await Future.delayed(const Duration(milliseconds: 200));

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/alarm_trigger'),
          builder: (context) => AlarmTriggerScreen(alarmData: data),
        ),
      ).then((_) {
        debugPrint('=== [ALARM] AlarmTriggerScreen Dismissed ===');
        isAlarmLaunch = false;
        _alarmDismissedController.add(null);
      });
    } else {
      debugPrint('=== [CRITICAL ERROR] Navigator still null after waiting. Alarm screen launch failed. ===');
      // 비상 시 SplashScreen에서라도 넘어가도록 플래그 해제 (선택 사항)
      // isAlarmLaunch = false; 
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      try {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      } catch (e) {
        debugPrint('Error requesting iOS permissions: $e');
      }
    } else if (Platform.isAndroid) {
      try {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          // 알림 권한 요청 (Android 13+)
          final granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('Android Notifications Permission: $granted');
          // 정확한 알람 권한 요청 (Android 12+)
          final exactAlarm = await androidPlugin.requestExactAlarmsPermission();
          debugPrint('Android Exact Alarms Permission: $exactAlarm');

          // 다른 앱 위에 그리기 권한 요청 (강제 전체 화면을 위해 필요)
          if (!await Permission.systemAlertWindow.isGranted) {
             debugPrint('Requesting System Alert Window permission...');
             final status = await Permission.systemAlertWindow.request();
             debugPrint('System Alert Window Permission status: $status');
          } else {
             debugPrint('System Alert Window Permission already granted.');
          }
        }
      } catch (e) {
        debugPrint('Error requesting Android permissions: $e');
      }
    }
  }

  Future<void> scheduleAlarm(int id, TimeOfDay time, String message, {String? payload}) async {
    debugPrint('=== [ALARM] scheduleAlarm called ===');
    debugPrint('=== [ALARM] ID: $id, Time: ${time.format(navigatorKey.currentContext!)}, Message: $message');

    // 이전 알람 취소
    await cancelAlarm(id);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0,
    );

    // 이미 시간이 지났다면 내일로 설정
    if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        debugPrint('=== [ALARM] Target time passed. Scheduling for tomorrow.');
    }

    debugPrint('=== [ALARM] Scheduled Native Date: $scheduledDate (Now: $now)');
    
    // 알람까지 남은 시간
    final Duration timeUntilAlarm = scheduledDate.difference(now);
    debugPrint('=== [ALARM] Time remaining until alarm: ${timeUntilAlarm.inSeconds} seconds');

    // 1. 포그라운드/앱 실행 중일 때를 위한 타이머 설정
    if (timeUntilAlarm.inSeconds > 0) {
      debugPrint('=== [ALARM] Setting FOREGROUND TIMER for $id in ${timeUntilAlarm.inSeconds} seconds');
      _foregroundTimers[id] = Timer(timeUntilAlarm, () async {
        debugPrint('=== [ALARM] >>> TIMER FIRED for ID: $id <<<');
        
        // Android: 강제로 앱을 화면 최상단으로 가져오기
        if (Platform.isAndroid) {
          try {
            debugPrint('=== [ALARM] Trying to bring app to front via MethodChannel ===');
            await platform.invokeMethod('bringToFront');
          } catch (e) {
            debugPrint('=== [ALARM] Failed to bring app to front: $e');
          }
        }

        if (payload != null) {
          try {
            final data = jsonDecode(payload);
            debugPrint('=== [ALARM] Payload data: $data');
            _handleAlarmAction(data);
          } catch (e) {
            debugPrint('=== [ALARM] Error parsing payload in timer: $e');
          }
        } else {
           debugPrint('=== [ALARM] Timer fired but payload is null');
        }
      });
    }

    // 2. 네이티브 알람 스케줄링 (Android vs iOS 분기)
    
    // Android: flutter_local_notifications 대신 직접 구현한 AlarmReceiver 사용 (배너 제거 및 강제 실행 목적)
    if (Platform.isAndroid) {
      try {
        debugPrint('=== [ALARM] Scheduling Native WakeUp for Terminated State (No Banner) ===');
        await platform.invokeMethod('scheduleNativeWakeUp', {
          'timestamp': scheduledDate.millisecondsSinceEpoch,
          'id': id,
          'payload': payload,
        });
      } catch (e) {
        debugPrint('=== [ALARM] Failed to schedule native wakeup: $e');
      }
    } else {
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '단도박 집중 알람',
          message.isEmpty ? '단도박 할 수 있다!' : message,
          scheduledDate,
          NotificationDetails(
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'default',
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.alarmClock, 
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (e) {
        debugPrint('=== [ALARM] Failed to schedule iOS notification: $e');
      }
    }
    
    debugPrint('=== [ALARM] Native schedule completed ===');
  }

  // 알람 취소
  Future<void> cancelAlarm(int id) async {
    debugPrint('=== [ALARM] cancelAlarm called for ID: $id');
    
    // 1. 포그라운드 타이머 취소
    if (_foregroundTimers.containsKey(id)) {
      _foregroundTimers[id]?.cancel();
      _foregroundTimers.remove(id);
      debugPrint('=== [ALARM] Foreground timer cancelled for ID: $id');
    }

    // 2. Local Notifications 취소
    await flutterLocalNotificationsPlugin.cancel(id);

    // 3. Android 네이티브 알람 취소 (커스텀 구현)
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('cancelNativeWakeUp', {'id': id});
        debugPrint('=== [ALARM] Native wakeup cancelled for ID: $id');
      } catch (e) {
        debugPrint('=== [ALARM] Failed to cancel native wakeup: $e');
      }
    }
  }

  // 모든 알람 취소
  Future<void> cancelAllAlarms() async {
    debugPrint('=== [ALARM] cancelAllAlarms called');
    for (var timer in _foregroundTimers.values) {
      timer.cancel();
    }
    _foregroundTimers.clear();
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _initFCM() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. 권한 요청
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // 2. [iOS] APNS 토큰 대기 (FCM 토큰 발급 전 필수)
      if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNS token is null. Waiting for it...');
          for (int i = 0; i < 3; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) {
              debugPrint('APNS Token received: $apnsToken');
              break;
            }
          }
        }
      }

      // 3. 토큰 가져오기 (단순 확인용)
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
      }

      // 3. 포그라운드 메시지 핸들링
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          // 포그라운드에서도 알림 표시 (로컬 알림 사용)
          _showForegroundNotification(message);
        }
      });
      
      // 토큰 리프레시 감지
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
         debugPrint("FCM Token Refreshed: $newToken");
         if (_currentUid != null) {
           ApiService.saveFCMToken(_currentUid!, newToken);
         }
      });

    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'scc_notice_channel', // 공지사항 채널 ID
            '공지사항 알림',
            channelDescription: '새로운 공지사항이 등록되었을 때 알림을 받습니다.',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true);
            
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
            
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: darwinPlatformChannelSpecifics,
        );
        
    debugPrint('=== [NOTIFICATION] Showing Foreground Notification ===');
    debugPrint('=== [NOTIFICATION] Message Data: ${message.data}');

    await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title ?? '알림',
        message.notification?.body ?? '',
        platformChannelSpecifics,
        payload: jsonEncode(message.data));
  }
}
