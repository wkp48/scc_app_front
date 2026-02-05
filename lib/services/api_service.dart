import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// 디버그 모드에서만 로깅
void _debugLog(String message) {
  assert(() {
    print(message);
    return true;
  }());
}

class ApiService {
  static const bool isOfflineMode = false; // 백엔드 점검/오프라인 모드 활성화

  static Future<String> get baseUrl async {
    // 맥미니 서버 공인 IP 주소 (외부 접속용)
    return 'http://115.20.138.8:8900/api';
    // ngrok HTTPS 주소 (사용 안 함)
    // return 'https://interrepellent-floretta-incorrigibly.ngrok-free.dev/api';
    // 내부망 IP (내부 접속용)
    // return 'http://192.168.0.75:8900/api';
  }
  
  // 회원 탈퇴
  static Future<Map<String, dynamic>> withdrawMember(String uid) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '회원 탈퇴 완료(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/member/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      
      _debugLog('회원 탈퇴 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '회원 탈퇴 중 오류가 발생했습니다 (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      _debugLog('회원 탈퇴 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e'
      };
    }
  }

  // 격언 설정 업데이트
  static Future<Map<String, dynamic>> updateMaximSettings(
      String uid, bool agreement, String time) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '격언 설정 저장 완료(모크)'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/member/maxim-settings'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-User-Uid': uid,
        },
        body: {
          'agreement': agreement.toString(),
          'time': time,
        },
      );

      _debugLog('격언 설정 업데이트 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '격언 설정 저장 중 오류가 발생했습니다 (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      _debugLog('격언 설정 업데이트 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e'
      };
    }
  }

  // 아이디 중복 확인
  static Future<Map<String, dynamic>> checkUserId(String userid) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'data': true}; // 중복 아님 처리
      }
      final url = '${await baseUrl}/signup/check/userid?userid=$userid';
      _debugLog('아이디 확인 요청 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      _debugLog('아이디 확인 응답 상태: ${response.statusCode}');
      _debugLog('아이디 확인 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': false
          };
        }
      } else {
        return {
          'success': false,
          'message': '아이디 확인 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': false
        };
      }
    } catch (e) {
      _debugLog('아이디 확인 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': false
      };
    }
  }
  
  // 이메일 중복 확인
  static Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'data': true}; // 중복 아님 처리
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/signup/check/email?email=$email'),
        headers: {'Content-Type': 'application/json'},
      );
      
      _debugLog('이메일 확인 응답 상태: ${response.statusCode}');
      _debugLog('이메일 확인 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': false
          };
        }
      } else {
        return {
          'success': false,
          'message': '이메일 확인 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': false
        };
      }
    } catch (e) {
      _debugLog('이메일 확인 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': false
      };
    }
  }
  
  // 대상자 회원가입
  static Future<Map<String, dynamic>> signupSubject({
    required String name,
    required String userid,
    required String email,
    required String password,
    required String birthDate,
    required String teacherName,
    String? phoneNumber,
    String? gender,
  }) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '회원가입 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/signup/subject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'userid': userid,
          'email': email,
          'password': password,
          'birthDate': birthDate,
          'teacherName': teacherName,
          'phoneNumber': phoneNumber,
          'gender': gender,
        }),
      );
      
      _debugLog('회원가입 응답 상태: ${response.statusCode}');
      _debugLog('회원가입 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '회원가입 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '회원가입 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '회원가입 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('회원가입 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }
  
  // 대상자 정보 조회
  static Future<Map<String, dynamic>> checkSubjectInfo(String userid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': {'name': '테스터', 'birthDate': '1990-01-01'}
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/signup/subject/info?userid=$userid'),
        headers: {'Content-Type': 'application/json'},
      );
      
      _debugLog('대상자 정보 조회 응답 상태: ${response.statusCode}');
      _debugLog('대상자 정보 조회 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '대상자 정보 조회 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '대상자 정보 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '대상자 정보 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('대상자 정보 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 가족 회원가입
  static Future<Map<String, dynamic>> signupFamily(String name, String userid, String email,
      String password, String relationship, String? subjectUserid, String? phoneNumber, String? gender) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '가족 회원가입 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/signup/family'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'name': name,
          'userid': userid,
          'email': email,
          'password': password,
          'relationship': relationship,
          if (subjectUserid != null) 'subjectUserid': subjectUserid,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
          if (gender != null) 'gender': gender,
        },
      );

      _debugLog('가족 회원가입 응답 상태: ${response.statusCode}');
      _debugLog('가족 회원가입 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '가족 회원가입 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '가족 회원가입 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '가족 회원가입 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('가족 회원가입 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 비밀번호 찾기 (본인 확인)
  static Future<Map<String, dynamic>> findPassword(String name, String userid, String birthDate, String email) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '본인 확인 완료(모크)', 'data': true};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/find/password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'userid': userid,
          'birthDate': birthDate,
          'email': email,
        }),
      );

      _debugLog('비밀번호 찾기 응답 상태: ${response.statusCode}');
      _debugLog('비밀번호 찾기 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '비밀번호 찾기 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '비밀번호 찾기 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '비밀번호 찾기 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('비밀번호 찾기 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 비밀번호 재설정
  static Future<Map<String, dynamic>> resetPassword(String userid, String newPassword) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '비밀번호 재설정 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/find/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userid': userid,
          'newPassword': newPassword,
        }),
      );

      _debugLog('비밀번호 재설정 응답 상태: ${response.statusCode}');
      _debugLog('비밀번호 재설정 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '비밀번호 재설정 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '비밀번호 재설정 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '비밀번호 재설정 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('비밀번호 재설정 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 아이디 찾기
  static Future<Map<String, dynamic>> findUserId(String name, String birthDate, String email) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '아이디 찾기 완료(모크)', 'data': 'tester123'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/find/id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'birthDate': birthDate,
          'email': email,
        }),
      );

      _debugLog('아이디 찾기 응답 상태: ${response.statusCode}');
      _debugLog('아이디 찾기 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '아이디 찾기 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '아이디 찾기 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '아이디 찾기 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('아이디 찾기 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 로그인
  static Future<Map<String, dynamic>> login(String userid, String password) async {
    try {
      if (isOfflineMode) {
        if (userid == 'family') {
          return {
            'success': true,
            'message': '오프라인 모드 로그인 성공(가족)',
            'data': {
              'uid': 'mock-family-uid-123',
              'userid': userid,
              'username': '가족회원',
              'userType': 'FAMILY',
              'token': 'mock-token',
              'profileImageUrl': null
            }
          };
        }
        _debugLog('Offline Mode: Mock Login Success');
        return {
          'success': true,
          'message': '오프라인 모드 로그인 성공',
          'data': {
            'uid': 'mock-uid-123',
            'userid': userid,
            'username': '테스터(관리자)',
            'userType': 'ADMIN',
            'token': 'mock-token',
            'profileImageUrl': null
          }
        };
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userid': userid,
          'password': password,
        }),
      );

      _debugLog('로그인 응답 상태: ${response.statusCode}');
      _debugLog('로그인 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          return json.decode(response.body);
        } else {
          return {
            'success': false,
            'message': '서버에서 빈 응답을 받았습니다',
            'data': null
          };
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            return {
              'success': false,
              'message': errorData['message'] ?? '로그인 중 오류가 발생했습니다',
              'data': null
            };
          } catch (e) {
            return {
              'success': false,
              'message': '로그인 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
              'data': null
            };
          }
        } else {
          return {
            'success': false,
            'message': '로그인 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
            'data': null
          };
        }
      }
    } catch (e) {
      _debugLog('로그인 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }
  // 다짐 저장
  static Future<Map<String, dynamic>> saveResolution(String uid, String content) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '다짐 저장 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/onboarding/resolution'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'content': content}),
      );

      _debugLog('다짐 저장 응답 상태: ${response.statusCode}');
      _debugLog('다짐 저장 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '다짐 저장 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('다짐 저장 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 채무 등록
  static Future<Map<String, dynamic>> saveDebt(String uid, Map<String, dynamic> debtData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '채무 등록 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/onboarding/debt'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(debtData),
      );

      _debugLog('채무 등록 응답 상태: ${response.statusCode}');
      _debugLog('채무 등록 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '채무 정보 등록 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('채무 등록 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 자가진단 저장
  static Future<Map<String, dynamic>> saveDiagnosis(String uid, List<int> answers) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '자가진단 저장 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/onboarding/diagnosis'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'answers': answers}),
      );

      _debugLog('자가진단 저장 응답 상태: ${response.statusCode}');
      _debugLog('자가진단 저장 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '자가진단 저장 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('자가진단 저장 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 온보딩 상태 조회
  static Future<Map<String, dynamic>> getOnboardingStatus(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'message': '성공',
          'data': {
            'debtCount': 1,
            'hasDiagnosis': true,
            'hasResolution': true,
            'isCompleted': true
          }
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/onboarding/status'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );


      _debugLog('온보딩 상태 조회 응답 상태: ${response.statusCode}');
      _debugLog('온보딩 상태 조회 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
           return json.decode(response.body);
        } else {
           return {'success': false, 'message': '서버에서 빈 응답을 받았습니다', 'data': null};
        }
      } else {
        return {
          'success': false,
          'message': '온보딩 상태 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('온보딩 상태 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 체크리스트 히스토리 조회
  static Future<Map<String, dynamic>> getChecklistHistory(String uid, {int days = 7}) async {
    try {
      if (isOfflineMode) {
        // Mock Data
        return {
          'success': true,
          'data': [
            {'date': '2024-01-28', 'scores': {'신체 지표': 5.0, '정서 지표': 6.0, '사고 지표': 4.0, '대인관계 지표': 7.0}},
            {'date': '2024-01-29', 'scores': {'신체 지표': 6.0, '정서 지표': 5.5, '사고 지표': 5.0, '대인관계 지표': 7.5}},
            {'date': '2024-01-30', 'scores': {'신체 지표': 5.5, '정서 지표': 7.0, '사고 지표': 6.0, '대인관계 지표': 7.0}},
            {'date': '2024-01-31', 'scores': {'신체 지표': 7.0, '정서 지표': 7.5, '사고 지표': 6.5, '대인관계 지표': 8.0}},
            {'date': '2024-02-01', 'scores': {'신체 지표': 7.5, '정서 지표': 8.0, '사고 지표': 7.0, '대인관계 지표': 8.5}},
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/daily-checklist/history?days=$days'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      _debugLog('체크리스트 히스토리 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': '히스토리 조회 실패'};
      }
    } catch (e) {
      _debugLog('히스토리 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  static Future<Map<String, dynamic>> getHomeDashboard(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'message': '성공',
          'data': {
            'username': '테스터',
            'counselorName': '미배정',
            'dday': 100,
            'resolutionDate': '2025년 01월 01일',
            'focusTimeActive': false,
            'focusEndTime': '18:00',
            'recoveryLevel': 95,
            'recoveryStatusMessage': '건강한 습관을 유지하고 있습니다!',
            'resolutionText': '흔들리지 않는 마음으로',
            'initialResolutionText': '첫 단도박의 결심',
            'pinnedActivities': ['IMPULSE', 'WALK', 'POSITIVE_SELF', 'GRATITUDE'],
            'profileImageUrl': null,
            'restartDates': [],
            'needsDiagnosis': false,
            'gratitudeCount': 5,
            'walkCount': 12,
            'impulseCount': 2,
            'positiveSelfCount': 8
          }
        };
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${await baseUrl}/home/dashboard?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      // _debugLog('홈 대시보드 조회 응답 상태: ${response.statusCode}');
      // _debugLog('홈 대시보드 조회 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '홈 대시보드 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('홈 대시보드 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }
  // --- 출석 체크 (Attendance) ---

  static Future<Map<String, dynamic>> checkTodayAttendance(String uid) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'hasAttendance': true};
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${await baseUrl}/attendance/today-check?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'hasAttendance': decoded['data'] as bool
        };
      }
      return {'success': false, 'hasAttendance': false};
    } catch (e) {
      _debugLog('오늘 출석 확인 오류: $e');
      return {'success': false, 'hasAttendance': false};
    }
  }

  static Future<Map<String, dynamic>> saveAttendance(String uid, String status, {String? date}) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '기록이 저장되었습니다(모크)'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/attendance'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({
          'status': status,
          if (date != null) 'date': date,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': '기록이 저장되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {'success': false, 'message': decoded['message'] ?? '저장에 실패했습니다'};
    } catch (e) {
      _debugLog('출석 저장 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> updateDebt(
      String uid, int debtId, Map<String, dynamic> debtData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '채무 정보가 수정되었습니다(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/debts/$debtId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(debtData),
      );

      _debugLog('채무 수정 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': '채무 정보가 수정되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': decoded['message'] ?? '수정에 실패했습니다'
      };
    } catch (e) {
      _debugLog('채무 수정 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> deleteDebt(
      String uid, int debtId) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '채무가 삭제되었습니다(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/debts/$debtId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      _debugLog('채무 삭제 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': '채무가 삭제되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': decoded['message'] ?? '삭제에 실패했습니다'
      };
    } catch (e) {
      _debugLog('채무 삭제 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getMonthlyAttendance(String uid, int year, int month) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {'date': '$year-${month.toString().padLeft(2, '0')}-01', 'status': 'STABLE'},
            {'date': '$year-${month.toString().padLeft(2, '0')}-05', 'status': 'STABLE'},
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/attendance/month?year=$year&month=$month'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded['data'] as List<dynamic>
        };
      }
      return {'success': false, 'data': []};
    } catch (e) {
      _debugLog('월간 출석 조회 오류: $e');
      return {'success': false, 'data': []};
    }
  }

  // --- 채무 관리 (Debt) ---

  static Future<Map<String, dynamic>> getDebtList(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': {
            'debtList': [
              {
                'id': 1,
                'creditor': '우리은행',
                'totalAmount': 5000000,
                'repaidAmount': 1500000,
                'monthlyPayment': 200000,
                'interestRate': 5.5,
                'memo': '오프라인 모드 데이터'
              }
            ],
            'totalDebtAmount': 5000000,
            'totalRepaidAmount': 1500000,
            'repaymentProgress': 30.0
          }
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/debts'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      
      _debugLog('채무 목록 조회 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '채무 목록을 가져오지 못했습니다.',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('채무 목록 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다.',
        'data': null
      };
    }
  }

  // 상환 기록 (Repayment)
  static Future<Map<String, dynamic>> registerRepayment(
      String uid, int debtId, Map<String, dynamic> repaymentData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '상환 내역이 등록되었습니다(모크)'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/debts/$debtId/repayments'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(repaymentData),
      );

      _debugLog('상환 등록 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': '상환 내역이 등록되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': decoded['message'] ?? '등록에 실패했습니다'
      };
    } catch (e) {
      _debugLog('상환 등록 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getRepayments(String uid, int debtId) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'amount': 200000,
              'repaymentDate': '2025-01-13',
              'memo': '정기 상환(모크)'
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/debts/$debtId/repayments'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded['data'] as List<dynamic>
        };
      }
      return {'success': false, 'message': '상환 내역을 가져오지 못했습니다'};
    } catch (e) {
      _debugLog('상환 목록 조회 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> updateRepayment(
      String uid, int repaymentId, Map<String, dynamic> repaymentData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '상환 내역이 수정되었습니다(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/debts/repayments/$repaymentId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(repaymentData),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '상환 내역이 수정되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': decoded['message'] ?? '수정에 실패했습니다'
      };
    } catch (e) {
      _debugLog('상환 수정 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> deleteRepayment(
      String uid, int repaymentId) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '상환 내역이 삭제되었습니다(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/debts/repayments/$repaymentId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '상환 내역이 삭제되었습니다'};
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': decoded['message'] ?? '삭제에 실패했습니다'
      };
    } catch (e) {
      _debugLog('상환 삭제 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> updateResolution(String uid, String content) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '다짐이 수정되었습니다(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/self-dev/resolution'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '다짐이 수정되었습니다'};
      }
      return {'success': false, 'message': '수정에 실패했습니다'};
    } catch (e) {
      _debugLog('다짐 수정 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> updateRewardPlan(String uid, String rewardPlan) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '자기보상 계획이 수정되었습니다(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/self-dev/reward-plan'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'rewardPlan': rewardPlan}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '자기보상 계획이 수정되었습니다'};
      }
      return {'success': false, 'message': '수정에 실패했습니다'};
    } catch (e) {
      _debugLog('자기보상 계획 수정 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getRewardPlans(String uid) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'data': []};
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/self-dev/reward-plans'),
        headers: {'X-User-Uid': uid},
      );

      _debugLog('보상 계획 조회 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        _debugLog('보상 계획 조회 응답 본문: ${response.body}');
        return {'success': true, 'data': decodedData['data']};
      }
      return {'success': false, 'message': '데이터 로드 실패 (상태코드: ${response.statusCode})'};
    } catch (e) {
      _debugLog('보상 계획 조회 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다: $e'};
    }
  }

  static Future<Map<String, dynamic>> saveRewardPlan(String uid, String targetDate, String content, {int? milestoneDays}) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '저장되었습니다(모크)'};
      }
      _debugLog('보상 계획 저장 요청: date=$targetDate, content=$content, milestone=$milestoneDays');
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/self-dev/reward-plan'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({
          'targetDate': targetDate, 
          'content': content,
          'milestoneDays': milestoneDays,
        }),
      );

      _debugLog('보상 계획 저장 응답 상태: ${response.statusCode}');
      _debugLog('보상 계획 저장 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': '저장되었습니다'};
      }
      return {'success': false, 'message': '저장에 실패했습니다 (상태코드: ${response.statusCode})'};
    } catch (e) {
      _debugLog('보상 계획 저장 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteRewardPlan(String uid, int planId) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '삭제되었습니다(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/self-dev/reward-plan/$planId'),
        headers: {'X-User-Uid': uid},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': '삭제되었습니다'};
      }
      return {'success': false, 'message': '삭제에 실패했습니다'};
    } catch (e) {
      _debugLog('보상 계획 삭제 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> updateResolutionDate(String uid, String date) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '시작일이 수정되었습니다(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/self-dev/resolution/date'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'date': date}),
      );
 
      if (response.statusCode == 200) {
        return {'success': true, 'message': '시작일이 수정되었습니다'};
      }
      return {'success': false, 'message': '수정에 실패했습니다'};
    } catch (e) {
      _debugLog('시작일 수정 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> togglePinActivity(String uid, String activityType) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'isPinned': true, 'message': '모크 토글 완료'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/self-dev/pin'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'activityType': activityType}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {'success': true, 'isPinned': data['data']};
      }
      return {'success': false, 'message': '고정 설정에 실패했습니다'};
    } catch (e) {
      _debugLog('핀 토글 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  // 나의 다짐 히스토리 조회
  static Future<Map<String, dynamic>> getResolutionHistory(String uid) async {
    final url = Uri.parse('${await baseUrl}/self-dev/resolution/history');
    debugPrint('=== [API] getResolutionHistory called ===');
    debugPrint('=== [API] Request URL: $url ===');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-User-Uid': uid},
      );
      debugPrint('=== [API] Response Code: ${response.statusCode} ===');
      _debugLog('다짐 히스토리 응답: ${response.body}');
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('=== [API] Error: $e ===');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> saveActivityRecord({
    required String uid,
    required String type,
    required String date,
    String? startTime,
    String? endTime,
    String? title,
    String? category,
    int? score,
    String? content,
    String? gratitudeTo,
    String? gratitudeSituation,
    String? gratitudeEmotion,
    String? impulseSituation,
    String? impulseThought,
    String? impulseHelpful,
    String? impulseAfter,
    List<File>? images,
    File? voiceFile,
    dynamic activityId, // 추가
  }) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '기록이 저장되었습니다(모크)'};
      }
      final method = activityId != null ? 'PUT' : 'POST';
      final url = activityId != null 
          ? '${await baseUrl}/activities/$activityId'
          : '${await baseUrl}/activities';

      final request = http.MultipartRequest(
        method,
        Uri.parse(url),
      );

      request.headers['X-User-Uid'] = uid;
      request.headers['X-User-Uid'] = uid;
      request.fields['type'] = type;
      request.fields['date'] = date;
      if (startTime != null) request.fields['startTime'] = startTime;
      if (endTime != null) request.fields['endTime'] = endTime;
      if (title != null) request.fields['title'] = title;
      if (category != null) request.fields['category'] = category;
      if (score != null) request.fields['score'] = score.toString();
      if (content != null) request.fields['content'] = content;
      if (gratitudeTo != null) request.fields['gratitudeTo'] = gratitudeTo;
      if (gratitudeSituation != null) request.fields['gratitudeSituation'] = gratitudeSituation;
      if (gratitudeEmotion != null) request.fields['gratitudeEmotion'] = gratitudeEmotion;
      if (impulseSituation != null) request.fields['impulseSituation'] = impulseSituation;
      if (impulseThought != null) request.fields['impulseThought'] = impulseThought;
      if (impulseHelpful != null) request.fields['impulseHelpful'] = impulseHelpful;
      if (impulseAfter != null) request.fields['impulseAfter'] = impulseAfter;

      if (images != null) {
        for (var image in images) {
          request.files.add(await http.MultipartFile.fromPath('images', image.path));
        }
      }

      if (voiceFile != null) {
        request.files.add(await http.MultipartFile.fromPath('voiceFile', voiceFile.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return {'success': true, 'message': '기록이 저장되었습니다'};
      }
      return {'success': false, 'message': '저장에 실패했습니다'};
    } catch (e) {
      _debugLog('활동 기록 저장 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getActivities({
    required String uid,
    String? date,
    String? type,
  }) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'type': type ?? 'REST',
              'title': '오늘의 기록(Mock)',
              'content': '백엔드 점검 중입니다. UI 테스트용 가짜 데이터입니다.',
              'date': date ?? '2025-01-01',
              'startTime': '10:00',
              'endTime': '11:00',
              'imageUrls': [],
            }
          ],
        };
      }
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('${await baseUrl}/activities').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'X-User-Uid': uid},
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decodedData['data'],
        };
      }
      return {'success': false, 'message': '데이터 로드 실패'};
    } catch (e) {
      _debugLog('활동 기록 조회 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> deleteActivity(dynamic activityId) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '기록 삭제 완료(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/activities/$activityId'),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': '기록 삭제 실패'};
    } catch (e) {
      _debugLog('기록 삭제 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getLatestVoiceRecord(String uid, String type) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': {
            'voiceUrl': 'mock_voice.aac',
            'createdAt': '2025-01-13T10:00:00'
          }
        };
      }
      final uri = Uri.parse('${await baseUrl}/activities/latest-voice')
          .replace(queryParameters: {'type': type});
      final response = await http.get(
        uri,
        headers: {'X-User-Uid': uid},
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decodedData['data'],
        };
      }
      return {'success': false, 'message': '데이터 로드 실패'};
    } catch (e) {
      _debugLog('최신 음성 기록 조회 오류: $e');
      return {'success': false, 'message': '오류가 발생했습니다'};
    }
  }

  // --- 알람 (Alarms) ---

  // 알람 목록 조회
  static Future<Map<String, dynamic>> getAlarms(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'type': 'FOCUS_TIME',
              'time': '18:00',
              'days': ['MON', 'TUE', 'WED', 'THU', 'FRI'],
              'isActive': true,
              'title': '단도박 집중 시간'
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/alarms'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      _debugLog('알람 목록 조회 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '알람 조회에 실패했습니다'};
    } catch (e) {
      _debugLog('알람 목록 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }

  // 알람 저장
  static Future<Map<String, dynamic>> saveAlarm(String uid, Map<String, dynamic> alarmData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '알람 저장 완료(모크)'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/alarms'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(alarmData),
      );

      _debugLog('알람 저장 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '알람 저장에 실패했습니다'};
    } catch (e) {
      _debugLog('알람 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }

  // 알람 수정
  static Future<Map<String, dynamic>> updateAlarm(String uid, int alarmId, Map<String, dynamic> alarmData) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '알람 수정 완료(모크)'};
      }
      final response = await http.put(
        Uri.parse('${await baseUrl}/alarms/$alarmId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode(alarmData),
      );

      _debugLog('알람 수정 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '알람 수정에 실패했습니다'};
    } catch (e) {
      _debugLog('알람 수정 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }

  // 알람 삭제
  static Future<Map<String, dynamic>> deleteAlarm(String uid, int alarmId) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '알람 삭제 완료(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/alarms/$alarmId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      _debugLog('알람 삭제 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '알람 삭제에 실패했습니다'};
    } catch (e) {
      _debugLog('알람 삭제 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }
  // --- 앱 콘텐츠 (자가진단, 영상 등) ---

  static Future<Map<String, dynamic>> getHelpfulVideos({String? category}) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'title': '회복으로 가는 길',
              'description': '전문가와 함께하는 회복 가이드',
              'videoUrl': 'https://example.com/video1.mp4',
              'thumbnailUrl': null
            }
          ]
        };
      }
      // [Fix] 서버 주소 및 경로 강제 지정 (디버깅)
      String url = 'http://115.20.138.8:8900/api/app/videos';
      if (category != null) {
        url += '?category=$category';
      }
      
      _debugLog('영상 목록 요청: $url');
      

      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      


      _debugLog('영상 목록 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        // List로 오더라도 성공 처리
        if (decoded is List) {
          _debugLog('Fetched ${decoded.length} videos.');
          decoded.take(5).forEach((v) => _debugLog('Video: ${v['title']} | Category: ${v['category']}'));
          return {'success': true, 'data': decoded};
        }
        // Map으로 오더라도 성공 처리
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': '영상 목록 로드 실패: ${response.statusCode}'};
    } catch (e) {

      _debugLog('영상 목록 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> checkAppVersion(String osType) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'currentVersion': '1.1.14',
          'minVersion': '1.0.0',
          'latestVersion': '1.1.14'
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/app/version/check?os=$osType'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      _debugLog('버전 체크 오류: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getDiagnosisHistory(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'totalScore': 85,
              'createdAt': '2025-01-01T10:00:00',
              'status': 'IMPROVING'
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/diagnosis/history'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded['data'] as List<dynamic>
        };
      }
      return {'success': false, 'message': '히스토리를 불러오는데 실패했습니다'};
    } catch (e) {
      _debugLog('진단 히스토리 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }

  static Future<Map<String, dynamic>> getDiagnosisQuestions() async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'content': '최근 도박 충동을 얼마나 느꼈나요?',
              'order': 1,
              'category': 'IMPULSE'
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/diagnosis/questions'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded['data'] as List<dynamic>
        };
      }
      return {'success': false, 'message': '질문 목록을 불러오는데 실패했습니다'};
    } catch (e) {
      _debugLog('진단 질문 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }


  static Future<Map<String, dynamic>> getMonthlyActivitySummary(String uid, int year, int month) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'date': '$year-${month.toString().padLeft(2, '0')}-01',
              'types': ['IMPULSE', 'WALK']
            },
            {
              'date': '$year-${month.toString().padLeft(2, '0')}-05',
              'types': ['GRATITUDE']
            },
            {
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'types': ['POSITIVE_SELF', 'WALK']
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/activities/monthly-summary?year=$year&month=$month'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded['data']
        };
      }
      return {'success': false, 'message': '활동 요약을 불러오는데 실패했습니다'};
    } catch (e) {
      _debugLog('활동 요약 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다'};
    }
  }
  static Future<Map<String, dynamic>> saveFCMToken(String uid, String token) async {
    try {
      if (isOfflineMode) {
        return {'success': true};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/fcm/token?token=$token'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': '토큰 저장 실패: ${response.statusCode}'};
    } catch (e) {
      _debugLog('FCM 토큰 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 공지사항 조회
  static Future<Map<String, dynamic>> getNotices() async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {
              'id': 1,
              'title': '[공지] 백엔드 서버 임시 점검 안내',
              'content': '현재 서버 점검 중으로 오프라인 모드가 활성화되어 있습니다.',
              'createdAt': '2025-01-13T09:00:00',
              'imageUrl': null
            },
            {
              'id': 2,
              'title': '세종충북센터 이용 안내',
              'content': '센터 방문 시 예약을 부탁드립니다.',
              'createdAt': '2025-01-12T14:00:00',
              'imageUrl': null
            }
          ],
        };
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await http.get(
      Uri.parse('${await baseUrl}/notices?t=$timestamp'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

      _debugLog('공지사항 조회 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': '공지사항을 불러오지 못했습니다. (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      _debugLog('공지사항 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> createNotice(Map<String, dynamic> noticeData) async {
    try {
      if (isOfflineMode) return {'success': true, 'data': noticeData};
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/notices'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(noticeData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(utf8.decode(response.bodyBytes)),
        };
      } else {
        return {
          'success': false,
          'message': '공지사항 등록에 실패했습니다. (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadNoticeImage(String filePath) async {
    try {
      if (isOfflineMode) return {'success': true, 'imageUrl': 'mock_image_url'};
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${await baseUrl}/notices/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(utf8.decode(response.bodyBytes)),
        };
      } else {
        return {'success': false, 'message': '이미지 업로드 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 프로필 이미지 업로드
  static Future<Map<String, dynamic>> uploadProfileImage(String uid, String filePath) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '업로드 완료(모크)'};
      }
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${await baseUrl}/member/profile-image'),
      );
      
      request.headers['X-User-Uid'] = uid;
      request.files.add(await http.MultipartFile.fromPath('profileImage', filePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      _debugLog('프로필 이미지 업로드 응답 상태: ${response.statusCode}');
      _debugLog('프로필 이미지 업로드 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '프로필 이미지 업로드 실패 (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      _debugLog('프로필 이미지 업로드 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e'
      };
    }
  }

  // 재시작일 저장
  static Future<Map<String, dynamic>> saveRestartDate(String uid, String date) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '저장 완료(모크)'};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/member/restart-date?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '재시작일 저장 실패'};
    } catch (e) {
      _debugLog('재시작일 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 재시작일 삭제
  static Future<Map<String, dynamic>> deleteRestartDate(String uid, String date) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '삭제 완료(모크)'};
      }
      final response = await http.delete(
        Uri.parse('${await baseUrl}/member/restart-date?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '재시작일 삭제 실패'};
    } catch (e) {
      _debugLog('재시작일 삭제 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }



  // --- 관리자 전용 API ---

  // 관리자 통계 조회
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': {
            'totalUsers': 150,
            'todayActivityCount': 25,
            'overdueDebtCount': 3,
            'weeklySignupCount': 12
          }
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/admin/dashboard/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': '관리자 통계 조회 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 공지사항 직접 등록 (AI 대행용)
  static Future<Map<String, dynamic>> createNoticeForAi(String title, String content,String? token) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${await baseUrl}/notices'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': '공지사항 등록 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // AI 정보 학습 요청
  static Future<Map<String, dynamic>> memorizeFact(String content, String? token) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${await baseUrl}/documents/memorize'),
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': '학습 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // AI 정보 학습 초기화
  static Future<Map<String, dynamic>> clearMemorizedFacts() async {
    try {
      final response = await http.delete(
        Uri.parse('${await baseUrl}/documents/memorize'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': '초기화 실패'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 채팅 기록 조회
  static Future<Map<String, dynamic>> getChatHistory(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('${await baseUrl}/chat/history/$uid'),
        headers: {'Content-Type': 'application/json'},
      );

      _debugLog('채팅 기록 조회 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      } else {
        return {'success': false, 'message': '채팅 기록 조회 실패'};
      }
    } catch (e) {
      _debugLog('채팅 기록 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // --- 가족 기능 API ---

  // 긍정관리 체크리스트 저장
  static Future<Map<String, dynamic>> saveFamilyChecklist(String uid, Map<String, dynamic> data) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '저장 완료(모크)'};
      
      final body = {
        'userUid': uid,
        ...data
      };
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/family/checklist'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '체크리스트 저장 실패 (${response.statusCode})'};
    } catch (e) {
      _debugLog('체크리스트 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 불안 점수 기록 저장
  static Future<Map<String, dynamic>> saveAnxietyLog(String uid, Map<String, dynamic> data, {List<File>? images}) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '저장 완료(모크)'};

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${await baseUrl}/family/anxiety'),
      );

      // Part 1: JSON Data (AnxietyLogRequest)
      // Backend expects @RequestPart("data") which is the DTO object.
      // We need to send it as a JSON string with Content-Type header for that part if strictly needed by Spring (application/json),
      // OR Spring might parse it if we just send fields?
      // "FamilyController" uses @RequestPart("data") AnxietyLogRequest request.
      // This usually requires the part "data" to be content-type application/json.
      
      // Let's create a multipart file for the JSON data to specify content type
      final body = {
        'userUid': uid,
        ...data
      };
      
      request.files.add(http.MultipartFile.fromString(
        'data',
        json.encode(body),
        contentType: MediaType.parse('application/json'),
      ));

      // Part 2: Images
      if (images != null) {
        for (var image in images) {
          request.files.add(await http.MultipartFile.fromPath('images', image.path));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '불안 기록 저장 실패 (${response.statusCode})'};
    } catch (e) {
      _debugLog('불안 기록 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 가족 일상/원칙 유지 기록 저장
  static Future<Map<String, dynamic>> saveFamilyDailyLog(String uid, String date, String type, bool value) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '저장 완료(모크)'};

      final body = {
        'userUid': uid,
        'date': date,
        '${type}Check': value, // type is 'principle' or 'daily' -> principleCheck, dailyCheck
      };

      final response = await http.post(
        Uri.parse('${await baseUrl}/family/daily-log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '일상 기록 저장 실패 (${response.statusCode})'};
    } catch (e) {
      _debugLog('일상 기록 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 가족 일상 기록 조회 (월별)
  static Future<Map<String, dynamic>> getFamilyDailyLogs(String uid, int year, int month) async {
    try {
      if (isOfflineMode) return {'success': true, 'data': []};

      final response = await http.get(
        Uri.parse('${await baseUrl}/family/daily-log?userUid=$uid&year=$year&month=$month'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '기록 조회 실패', 'data': []};
    } catch (e) {
      _debugLog('일상 기록 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류', 'data': []};
    }
  }

  // 불안 기록 조회
  static Future<Map<String, dynamic>> getAnxietyLogs(String uid) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            // Dummy data for offline testing
            {
              'id': 1,
              'situation': '테스트 상황',
              'anxietyScore': 70,
              'createdAt': '2024-01-01',
            }
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/family/anxiety?userUid=$uid'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '기록을 불러오는데 실패했습니다'};
    } catch (e) {
      _debugLog('불안 기록 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }
  // 나의 과제 조회
  static Future<Map<String, dynamic>> getMissions(String uid) async {
    try {
      if (isOfflineMode) return {'success': true, 'data': []};
      
      final response = await http.get(
        Uri.parse('${await baseUrl}/missions/my'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '과제 목록 조회 실패'};
    } catch (e) {
      _debugLog('과제 조회 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 과제 제출
  static Future<Map<String, dynamic>> submitMission(int missionId, String result) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '제출 완료(모크)'};
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/missions/$missionId/submit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'result': result}),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '과제 제출 실패'};
    } catch (e) {
      _debugLog('과제 제출 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 자율 과제 생성 및 제출
  static Future<Map<String, dynamic>> createSelfMission(String uid, String content) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '자율 과제 저장(모크)'};
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/missions/self'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '자율 과제 저장 실패'};
    } catch (e) {
      _debugLog('자율 과제 저장 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }

  // 과제 삭제
  static Future<Map<String, dynamic>> deleteMission(int missionId) async {
    try {
      if (isOfflineMode) return {'success': true, 'message': '삭제 완료(모크)'};
      
      final response = await http.delete(
        Uri.parse('${await baseUrl}/missions/$missionId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': '과제 삭제 실패'};
    } catch (e) {
      _debugLog('과제 삭제 오류: $e');
      return {'success': false, 'message': '네트워크 오류'};
    }
  }



  // 일일 체크리스트 질문 조회
  static Future<Map<String, dynamic>> getDailyChecklistQuestions() async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': [
            {'id': 1, 'question': '충분히 잠을 잤다고 느껴지나요?', 'category': '신체 지표', 'isReverse': false},
            {'id': 2, 'question': '건강에 도움이 되는 신체활동은 충분히 하셨나요?', 'category': '신체 지표', 'isReverse': false},
            {'id': 3, 'question': '사소한 일에도 예민하거나 화가나는 느낌은 어느정도 였나요?', 'category': '정서 지표', 'isReverse': true},
          ]
        };
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/daily-checklist/questions'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '질문 목록을 불러오는데 실패했습니다'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 일일 체크리스트 제출 여부 확인
  static Future<Map<String, dynamic>> checkTodayDailyChecklist(String uid) async {
    try {
      if (isOfflineMode) return {'success': true, 'data': false};
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${await baseUrl}/daily-checklist/check?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'message': '확인 중 오류가 발생했습니다'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 일일 체크리스트 요약 조회 (그래프용)
  static Future<Map<String, dynamic>> getChecklistSummary(String uid, {String? date}) async {
    try {
      if (isOfflineMode) return {'success': true, 'data': {'submitted': false}}; // Mock fallback

      String url = '${await baseUrl}/daily-checklist/summary';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (date != null) {
      url += '?date=$date&t=$timestamp';
    } else {
      url += '?t=$timestamp';
    }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '결과 요약을 불러오는데 실패했습니다'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 일일 체크리스트 제출
  static Future<Map<String, dynamic>> submitDailyChecklist(String uid, Map<int, int> answers) async {
    debugPrint('=== [API] submitDailyChecklist called ===');
    try {
      if (isOfflineMode) return {'success': true, 'message': '제출 완료(모크)'};

      final url = Uri.parse('${await baseUrl}/daily-checklist');
      final encodedBody = json.encode(answers.map((k, v) => MapEntry(k.toString(), v)));
      debugPrint('=== [API] Request URL: $url ===');
      debugPrint('=== [API] Body: $encodedBody ===');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: encodedBody,
      );

      debugPrint('=== [API] Response Code: ${response.statusCode} ===');
      debugPrint('=== [API] Response Body: ${utf8.decode(response.bodyBytes)} ===');

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '제출 실패: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('=== [API] Error: $e ===');
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }
  // 월별 체크리스트 요약 조회
  static Future<Map<String, dynamic>> getMonthlyChecklistSummary(String uid, int year, int month) async {
    try {
      if (isOfflineMode) {
        return {
          'success': true,
          'data': {}
        };
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('${await baseUrl}/daily-checklist/monthly-summary?year=$year&month=$month&t=$timestamp'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
      );
      
      _debugLog('월별 체크리스트 요약 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '월별 체크리스트 요약 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})'
        };
      }
    } catch (e) {
      _debugLog('월별 체크리스트 요약 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e'
      };
    }
  }
  // 가족 성장 점검 저장
  static Future<Map<String, dynamic>> saveFamilyGrowthChecklist(
      String uid, String date, Map<String, int> scores) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'message': '가족 성장 점검 저장 완료(모크)', 'data': null};
      }
      final response = await http.post(
        Uri.parse('${await baseUrl}/family/checklist'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Uid': uid,
        },
        body: json.encode({
          'userUid': uid,
          'financial': scores['재정관리'],
          'control': scores['통제욕구'],
          'conversation': scores['건강한 대화'],
          'feedback': scores['건강한 피드백'],
          'physical': scores['신체지표'],
          'interpersonal': scores['대인관계 지표'],
          'emotional': scores['정서지표'],
          'cognitive': scores['사고지표'],
        }),
      );

      _debugLog('가족 성장 점검 저장 응답 상태: ${response.statusCode}');
      _debugLog('가족 성장 점검 저장 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': '가족 성장 점검 저장 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('가족 성장 점검 저장 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }

  // 가족 성장 점검 조회 (날짜별)
  static Future<Map<String, dynamic>> getFamilyGrowthChecklist(String uid, String date) async {
    try {
      if (isOfflineMode) {
        return {'success': true, 'data': null};
      }
      final response = await http.get(
        Uri.parse('${await baseUrl}/family/checklist?userUid=$uid&date=$date'),
        headers: {'Content-Type': 'application/json'},
      );

      _debugLog('가족 성장 점검 조회 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // UTF-8 decoding needed? Spring usually sends JSON with UTF-8
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '가족 성장 점검 조회 중 오류가 발생했습니다 (상태코드: ${response.statusCode})',
          'data': null
        };
      }
    } catch (e) {
      _debugLog('가족 성장 점검 조회 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다: $e',
        'data': null
      };
    }
  }
}
