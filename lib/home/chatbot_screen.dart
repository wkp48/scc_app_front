import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? counselorName;

  const ChatbotScreen({
    super.key,
    required this.userData,
    this.counselorName,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  // 관리자 설정 변수
  bool _isRAGEnabled = true;
  bool _showSources = true;
  String _personaMode = 'friendly'; // friendly, professional, empathic
  Map<String, dynamic>? _adminDashboardData;

  @override
  void initState() {
    super.initState();
    final username = widget.userData['username'] ?? widget.userData['userid'] ?? '회원';
    // 초기 환영 메시지
    _messages.add({
      "role": "assistant",
      "content": "안녕하세요, $username님! 세종충북센터 AI 상담사입니다. 무엇을 도와드릴까요? 앱이나 도박 문제, 센터 이용에 대해 궁금한 점이 있다면 편하게 물어보세요."
    });

    if (widget.userData['userType'] == 'ADMIN') {
      _fetchAdminStats();
    }
    _fetchChatHistory();
  }

  Future<void> _fetchChatHistory() async {
    final uid = widget.userData['uid'];
    if (uid == null) return;

    final result = await ApiService.getChatHistory(uid);
    if (result['success'] == true) {
      final List<dynamic> history = result['data'];
      if (mounted && history.isNotEmpty) {
        setState(() {
          for (var item in history) {
            _messages.add({
              "role": "user",
              "content": item['userQuery'],
            });
            _messages.add({
              "role": "assistant",
              "content": item['botResponse'],
            });
          }
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _fetchAdminStats() async {
    final response = await ApiService.getAdminStats();
    if (response['success'] == true) {
      if (mounted) {
        setState(() {
          _adminDashboardData = response['data'];
        });
      }
    }
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 초기화'),
        content: const Text('지금까지의 대화 내용을 모두 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                final username = widget.userData['username'] ?? widget.userData['userid'] ?? '회원';
                _messages.add({
                  "role": "assistant",
                  "content": "안녕하세요, $username님! 대화가 초기화되었습니다. 무엇을 도와드릴까요?"
                });
              });
              Navigator.pop(context);
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAdminSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings_suggest, color: Color(0xFF5C72EB)),
                    SizedBox(width: 8),
                    Text('관리자 전용 AI 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('문서 검색(RAG) 활성화'),
                  subtitle: const Text('PDF 내부 자료를 참고하여 답변합니다.'),
                  value: _isRAGEnabled,
                  onChanged: (val) {
                    setState(() => _isRAGEnabled = val);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('출처 문서 표시'),
                  subtitle: const Text('답변 끝에 [참고 문서] 목록을 노출합니다.'),
                  value: _showSources,
                  onChanged: (val) {
                    setState(() => _showSources = val);
                    setModalState(() {});
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('상담 말투(페르소나)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPersonaChip('친절함', 'friendly', setModalState),
                    _buildPersonaChip('전문적', 'professional', setModalState),
                    _buildPersonaChip('공감 중심', 'empathic', setModalState),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildPersonaChip(String label, String value, StateSetter setModalState) {
    bool isSelected = _personaMode == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _personaMode = value);
          setModalState(() {});
        }
      },
      selectedColor: const Color(0xFF5C72EB).withOpacity(0.2),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF5C72EB) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final username = widget.userData['username'] ?? widget.userData['userid'] ?? '회원';
    
    // 사용자 유형 매핑 개선
    final rawUserType = widget.userData['userType']?.toString().toUpperCase() ?? '';
    String userTypeStr = '정보 없음';
    if (rawUserType == 'SUBJECT') {
      userTypeStr = '도박 문제 당사자(대상자 본인)';
    } else if (rawUserType == 'FAMILY') {
      final relationship = widget.userData['relationship'] ?? '';
      userTypeStr = '도박 문제 대상자의 가족${relationship.isNotEmpty ? " ($relationship)" : ""}';
    } else if (rawUserType == 'TEACHER') {
      userTypeStr = '센터 상담사(선생님)';
    } else if (rawUserType == 'ADMIN') {
      userTypeStr = '시스템 관리자';
    } else {
      userTypeStr = widget.userData['userType'] ?? '정보 없음';
    }

    final counselor = widget.counselorName ?? '미배정';
    final phone = widget.userData['phone'] ?? widget.userData['phoneNumber'] ?? '정보 없음';

    // 관리자용 통계 데이터 준비
    String adminStatsContext = '';
    if (rawUserType == 'ADMIN' && _adminDashboardData != null) {
      int weeklySignupCount = 0;
      if (_adminDashboardData!['weeklySignupStats'] != null) {
        for (var stat in _adminDashboardData!['weeklySignupStats']) {
          weeklySignupCount += (stat['count'] as num).toInt();
        }
      }

      adminStatsContext = "\n[현재 시스템 실시간 통계]\n"
          "- 총 회원 수: ${_adminDashboardData!['totalUsers'] ?? 0}명\n"
          "- 오늘 활동 기록 수: ${_adminDashboardData!['todayActivityCount'] ?? 0}건\n"
          "- 미납/연체 채무 건수: ${_adminDashboardData!['overdueDebtCount'] ?? 0}건\n"
          "- 이번 주 신규 가입: $weeklySignupCount명\n";
    }

    // 페르소나 지침 설정
    String personaGuideline = '친절하고 따뜻한 "해요"체를 사용해.';
    if (_personaMode == 'professional') {
      personaGuideline = '전문적이고 객관적인 "하십시오"체 또는 "했습니다"체를 주로 사용해.';
    } else if (_personaMode == 'empathic') {
      personaGuideline = '사용자의 감정에 깊이 공감하고 위로하는 따뜻한 말투를 사용해.';
    }

    // 1. 사용자 메시지 추가 및 UI 업데이트
    setState(() {
      _messages.add({"role": "user", "content": text});
      _messages.add({"role": "assistant", "content": ""}); // 빈 메시지 추가 (스트리밍용)
      _isLoading = true;
    });
    _scrollToBottom();
    _controller.clear();

    // 오프라인 모드인 경우 모킹 처리
    if (ApiService.isOfflineMode) {
      await Future.delayed(const Duration(seconds: 1)); // 응답 대기 지연 효과
      setState(() {
        _messages.last['content'] = "안녕하세요, $username님! 현재는 오프라인 모드(서버 점검 중)로 작동하고 있어 제한된 답변만 가능합니다. 백엔드 서버가 복구되면 더 정확하고 실시간인 상담이 가능해집니다. 궁금한 점이 있으시면 언제든 말씀해주세요!";
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      // 백엔드 Proxy API로 요청 주소 변경
      final baseUrl = await ApiService.baseUrl;
      final request = http.Request('POST', Uri.parse('$baseUrl/chat'));
      request.headers['Content-Type'] = 'application/json';
      
      // 토큰이 있다면 헤더에 추가 (보안)
      if (widget.userData['token'] != null) {
        request.headers['Authorization'] = 'Bearer ${widget.userData['token']}';
      }

      request.body = jsonEncode({
        "model": "gemma3",
        "userUid": widget.userData['uid'],
        "rag_enabled": _isRAGEnabled,
        "show_sources": _showSources,
        "messages": [
          {
            "role": "system",
            "content": "너는 '세종충북도박문제예방치유센터'의 공식 AI 상담사야. \n"
                "너는 사용자의 가족이 아니며, 전문적인 상담사로서 행동해야 해.\n\n"
                "[사용자 프로필]\n"
                "- 이름: $username\n"
                "- 유형: $userTypeStr\n"
                "- 전화번호: $phone\n"
                "- 담당 상담 선생님: $counselor\n"
                "$adminStatsContext\n"
                "[센터 기본 정보]\n"
                "1. 위치: 충북 청주시 흥덕구 경산로 1 5층\n"
                "2. 연락처: 043-275-0051 (24시간 헬프라인: 1336)\n"
                "3. 운영시간: 평일 09:00 ~ 18:00 (점심시간 12:00 ~ 13:00)\n\n"
                "4. 주차장 위치: 청주시외버스터미널 환승주차장이나 갓길 주차\n"
                "5. 담당 선생님 명단: 김경진 센터장님, 이희연 선생님, 박마리 선생님, 이윤지 팀장님, 이형주 선생님\n"
                "[지침]\n"
                "1. [매우 중요] 담당 선생님 이름 뒤에 '(미배정)' 같은 말을 임의로 덧붙이지 마. 선생님 이름이 있으면 이름만 딱 말해.\n"
                "2. 담당 선생님이 '미배정'이거나 '정보 없음'이면, '아직 배정된 담당 선생님이 없습니다'라고 안내해.\n"
                "3. [절대 금지] 한글 이외의 언어는 사용하지 마.\n"
                "4. 위 [센터 기본 정보]에 없는 내용은 지어내지 말고, '센터로 문의해주세요'라고 답변해.\n"
                "5. 답변 말투는 $personaGuideline\n"
                "6. 위급한 상황 같으면 043-275-0051번으로 전화하도록 안내해.\n"
                "7. 사용자가 '시스템 관리자'나 '선생님'이라면, 센터 운영과 상담 업무를 지원하는 든든한 조력자로서 정중하고 일 처리에 도움이 되는 태도로 답해줘. 시스템 설정이나 정보 확인 요청에 적극 협조해.\n"
                "8. [관리자 전용 기능 - 공지 대행] 사용자가 공지사항 작성을 요청하면, 내용을 정리한 뒤 반드시 마지막에 \n"
                "   [ACTION: CREATE_NOTICE, TITLE: 공지제목, CONTENT: 공지내용]\n"
                "   형식으로 한 줄을 추가해줘.\n"
                "9. [관리자 전용 기능 - 실시간 학습] 사용자가 새로운 정보를 기억하라거나(학습) 센터 운영 지침이 변경되었다고 알려주면, 알겠다고 답한 뒤 반드시 마지막에 \n"
                "   [ACTION: MEMORIZE, CONTENT: 학습할 내용 요약]\n"
                "   형식으로 한 줄을 추가해줘.\n"
                "10. [관리자 전용 기능 - 학습 초기화] 사용자가 네가 가르쳐준 정보를 잊으라거나 학습한 데이터를 모두 지우라고 요청하면, 알겠다고 답한 뒤 반드시 마지막에 \n"
                "   [ACTION: FORGET_ALL]\n"
                "   형식으로 한 줄을 추가해줘.\n"
                "11. 사용자가 '가족'이라면 따뜻한 위로와 지지를, '당사자(대상자)'라면 단도박 의지를 응원하고 격려해줘.\n"
                "12. 사용자가 자신의 정보를 물어보면 위 [사용자 프로필] 및 실시간 통계를 토대로 답변해줘.\n"
                "13. 너는 대화 중인 현재 맥락을 모두 기억하고 있어. 이전 질문과 연결된 답변을 해줘.\n"
                "${_isRAGEnabled ? "" : "13. [중요] 내부 문서를 참고하지 말고 네가 알고 있는 지식으로만 답변해.\n"}"
                "${_showSources ? "" : "14. [매우 중요] 답변 끝에 참고 문서나 출처를 절대로 표시하지 마.\n"}"
          },
          ..._messages.sublist(0, _messages.length - 1).map((m) => {"role": m["role"], "content": m["content"]}).toList()
        ],
        "stream": true
      });

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        // Manual byte buffering to handle split UTF-8 characters safely
        List<int> buffer = [];
        await streamedResponse.stream.listen((List<int> chunk) {
          buffer.addAll(chunk);

          int offset = 0;
          while (true) {
            // Find newline character (10)
            int newlineIndex = -1;
            for (int i = offset; i < buffer.length; i++) {
              if (buffer[i] == 10) {
                newlineIndex = i;
                break;
              }
            }

            if (newlineIndex == -1) {
              // No more newlines, keep remaining bytes in buffer
              if (offset > 0) {
                buffer = buffer.sublist(offset);
              }
              break;
            }

            // Extract line
            final lineBytes = buffer.sublist(offset, newlineIndex);
            offset = newlineIndex + 1; // Skip the newline

            if (lineBytes.isEmpty) continue;

            try {
              final line = utf8.decode(lineBytes).trim();
              if (line.isEmpty) continue;

              // SSE 포맷 처리: "data:" 접두어 제거
              if (line.startsWith('data:')) {
                final jsonStr = line.substring(5).trim();
                if (jsonStr.isEmpty) continue;

                final data = jsonDecode(jsonStr);
                
                String content = '';
                if (data['message'] != null && data['message']['content'] != null) {
                  content = data['message']['content']; 
                } else if (data['response'] != null) {
                  content = data['response']; 
                }

                final done = data['done'] ?? false;

                if (content.isNotEmpty) {
                  if (mounted) {
                     setState(() {
                      _messages.last['content'] += content;
                    });
                     _scrollToBottom();
                  }
                }
                
                if (done) {
                   if (mounted) {
                     setState(() => _isLoading = false);
                     _processBotAction(_messages.last['content']);
                   }
                }
              }
            } catch (e) {
              debugPrint('파싱 에러: $e');
            }
          }
        }).asFuture();

        if (mounted) {
           setState(() => _isLoading = false);
           // 스트리밍 완료 후 전체 응답에 대해 액션 처리 실행
           _processBotAction(_messages.last['content']);
        }
      } else {
        throw Exception("API 응답 에러 (${streamedResponse.statusCode})");
      }
    } catch (e) {
      debugPrint("챗봇 통신 오류: $e");
      if (mounted) {
        setState(() {
          _messages.last['content'] = "현재 서버와의 연결이 원활하지 않습니다. 잠시 후 다시 시도해주시거나, 043-275-0051번으로 전화 부탁드립니다!";
          _isLoading = false;
        });
      }
    }
  }

  // AI의 응답에서 특수 동작([ACTION])을 감지하고 실행
  void _processBotAction(String fullResponse) async {
    // 1. 공지사항 생성 액션
    if (fullResponse.contains('[ACTION: CREATE_NOTICE')) {
      final regExp = RegExp(r'\[ACTION:\s*CREATE_NOTICE,\s*TITLE:\s*(.*?),\s*CONTENT:\s*(.*?)\]', dotAll: true, caseSensitive: false);
      final match = regExp.firstMatch(fullResponse);

      if (match != null) {
        final title = match.group(1)?.trim() ?? '';
        final content = match.group(2)?.trim() ?? '';

        if (title.isNotEmpty && content.isNotEmpty) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('공지사항 자동 등록'),
              content: Text('AI가 제안한 내용을 공지사항으로 등록할까요?\n\n제목: $title'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('등록하기')),
              ],
            ),
          );

          if (confirm == true) {
            String? token = widget.userData['token'];
            final res = await ApiService.createNoticeForAi(title, content, token);
            if (res['success'] == true) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지사항이 등록되었습니다. 푸시 알림은 별도로 발송해주세요.')));
            }
          }
        }
      }
    }
    
    // 2. 실시간 학습(Memorize) 액션
    if (fullResponse.contains('[ACTION: MEMORIZE')) {
      final regExp = RegExp(r'\[ACTION:\s*MEMORIZE,\s*CONTENT:\s*(.*?)\]', dotAll: true, caseSensitive: false);
      final match = regExp.firstMatch(fullResponse);

      if (match != null) {
        final content = match.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          String? token = widget.userData['token'];
          final res = await ApiService.memorizeFact(content, token);
          if (res['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF5C72EB),
                  content: Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text('AI가 새로운 정보를 학습했습니다: $content')),
                    ],
                  ),
                ),
              );
            }
          }
        }
      }
    }

    // 3. 학습 초기화(Forget) 액션
    if (fullResponse.contains('[ACTION: FORGET_ALL]')) {
      final res = await ApiService.clearMemorizedFacts();
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.white),
                  SizedBox(width: 8),
                  Text('학습된 데이터가 모두 초기화되었습니다.'),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('세종충북 AI 상담실', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF5C72EB), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('상담 가동 중', style: TextStyle(color: Colors.black54, fontSize: 11)),
              ],
            )
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'clear') _clearHistory();
              if (value == 'settings') _showAdminSettings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('대화 초기화'),
                  ],
                ),
              ),
              if (widget.userData['userType'] == 'ADMIN')
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20, color: Color(0xFF5C72EB)),
                      SizedBox(width: 8),
                      Text('관리자 설정', style: TextStyle(color: Color(0xFF5C72EB), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final bool isUser = message["role"] == "user";
                    final bool isFirst = index == 0;

                    return _buildMessageItem(message, isUser, isFirst);
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message, bool isUser, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 10),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF5C72EB),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser && isFirst)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('AI 상담사', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser 
                      ? const LinearGradient(
                          colors: [Color(0xFF5C72EB), Color(0xFF758BFD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message["content"],
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.5,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (isUser)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 4),
                    child: Text('전송됨', style: TextStyle(fontSize: 10, color: Colors.black26)),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '상담사에게 메시지 보내기...',
                  hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: _isLoading 
                  ? const LinearGradient(colors: [Colors.black12, Colors.black26])
                  : const LinearGradient(
                      colors: [Color(0xFF5C72EB), Color(0xFF758BFD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                shape: BoxShape.circle,
                boxShadow: _isLoading ? [] : [
                  BoxShadow(
                    color: const Color(0xFF5C72EB).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}