import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import '../utils/repayment_logic.dart';
import '../widgets/repayment_schedule_table.dart';

class DebtStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  final bool isStandalone;
  final Map<String, dynamic>? initialDebt; // 추가

  const DebtStep({
    Key? key,
    required this.userData,
    required this.onNext,
    required this.onPrevious,
    this.isStandalone = false,
    this.initialDebt, // 추가
  }) : super(key: key);

  @override
  State<DebtStep> createState() => _DebtStepState();
}

class _DebtStepState extends State<DebtStep> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _directInputController = TextEditingController(); // 직접 입력용 컨트롤러
  final TextEditingController _loanPeriodController = TextEditingController(); // 대출기간
  final TextEditingController _gracePeriodController = TextEditingController(); // 거치기간
  
  String _mainCategory = '금융권'; // 대분류 기본값
  String _subCategory = '국민은행'; // 소분류 기본값
  
  // 카테고리 데이터 구조
  final Map<String, List<String>> _categoryMap = {
    '금융권': ['국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '기업은행', '카카오뱅크', '토스뱅크', '저축은행', '캐피탈', '카드사(현금서비스)', '보험사 대출', '새마을금고', '신협', '직접 입력'],
    '불법 사채': ['일수', '월변', '지인 사칭 사채', '직접 입력'],
    '개인 차용': ['가족', '지인', '친구', '직접 입력'],
    '기타': ['도박 사이트 미지급금', '물품 대금', '직접 입력'],
  };
  
  String _repaymentType = '원리금균등상환'; // 상환 방식 기본값

  bool _showInterestWarning = false; // 이자율 경고 표시 여부
  bool _isLoading = false; // 로딩 상태 관리
  
  // 에러 메시지 상태
  String? _amountError;
  String? _interestError;
  String? _directInputError;

  int _currentSchedulePage = 0; // 상환 스케줄 현재 페이지 (Skeletone UI 유지용, 실제 로직은 위젯 내부) 


  @override
  void initState() {
    super.initState();
    // 초기값: 오늘 날짜
    String today = DateFormat('yyyy/MM/dd').format(DateTime.now());
    _dateController.text = today;
    _dueDateController.text = today;

    // 직접 입력 필드 리스너 추가 (에러 메시지 초기화용)
    _directInputController.addListener(() {
      if (_directInputError != null && _directInputController.text.isNotEmpty) {
        setState(() => _directInputError = null);
      }
    });

    // 수정 모드인 경우 초기 데이터 설정
    if (widget.initialDebt != null) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final debt = widget.initialDebt!;
    
    // 날짜 형식 변환: yyyy-MM-dd -> yyyy/MM/dd
    String debtDate = debt['debtDate'] ?? '';
    if (debtDate.contains('-')) {
      debtDate = debtDate.replaceAll('-', '/');
    }
    _dateController.text = debtDate;

    String dueDate = debt['dueDate'] ?? '';
    if (dueDate.contains('-')) {
      dueDate = dueDate.replaceAll('-', '/');
    }
    _dueDateController.text = dueDate;

    // 카테고리 설정
    _mainCategory = debt['mainCategory'] ?? '1금융권';
    _subCategory = debt['subCategory'] ?? '국민은행';
    
    if (_subCategory == '직접 입력') {
      _directInputController.text = debt['categoryCustom'] ?? '';
    }

    // 금액 포맷팅
    if (debt['amount'] != null) {
      final formatter = NumberFormat("#,###");
      String formatted = formatter.format(debt['amount']);
      _amountController.text = "$formatted원";
    }

    // 이자율 포맷팅
    if (debt['interestRate'] != null) {
      _interestController.text = "${debt['interestRate']}%";
      _showInterestWarning = (debt['interestRate'] as num) > 20.0;
    }

    _memoController.text = debt['memo'] ?? '';
    _repaymentType = debt['repaymentType'] ?? '원리금균등상환';
    if (debt['loanPeriod'] != null) _loanPeriodController.text = "${debt['loanPeriod']}개월";
    if (debt['gracePeriod'] != null) _gracePeriodController.text = "${debt['gracePeriod']}개월";
  }
  
  // 유효성 검사
  bool _validateFields() {
    setState(() {
      _amountError = _amountController.text.isEmpty ? '금액을 입력해주세요' : null;
      _interestError = _interestController.text.isEmpty ? '이자율을 입력해주세요' : null;
      
      if (_subCategory == '직접 입력') {
        _directInputError = _directInputController.text.isEmpty ? '내용을 입력해주세요' : null;
      } else {
        _directInputError = null;
      }

      if (_loanPeriodController.text.isEmpty) {
        ToastUtils.show(context, '대출기간을 입력해주세요');
      }
    });

    return _amountError == null && 
           _interestError == null && 
           _directInputError == null && 
           _loanPeriodController.text.isNotEmpty;
  }

  Future<void> _handleNext() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 데이터 변환 (콤마, 원, % 등 제거)
      final amountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final interestStr = _interestController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final debtDate = _dateController.text.replaceAll('/', '-');
      final dueDate = _dueDateController.text.replaceAll('/', '-');

      final Map<String, dynamic> debtData = {
        'debtDate': debtDate,
        'dueDate': dueDate,
        'mainCategory': _mainCategory,
        'subCategory': _subCategory,
        'categoryCustom': _subCategory == '직접 입력' ? _directInputController.text.trim() : null,
        'amount': double.parse(amountStr),
        'interestRate': double.parse(interestStr),
        'loanPeriod': _loanPeriodController.text.isEmpty ? null : int.parse(_loanPeriodController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'gracePeriod': _gracePeriodController.text.isEmpty ? null : int.parse(_gracePeriodController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'memo': _memoController.text.trim(),
        'repaymentType': _repaymentType,
      };

      final Map<String, dynamic> response;
      if (widget.initialDebt != null) {
        // 수정 모드
        response = await ApiService.updateDebt(
          widget.userData['uid'],
          widget.initialDebt!['id'],
          debtData,
        );
      } else {
        // 추가 모드
        response = await ApiService.saveDebt(
          widget.userData['uid'],
          debtData,
        );
      }

      if (response['success'] == true) {
        widget.onNext();
      } else {
        ToastUtils.show(context, response['message'] ?? '저장에 실패했습니다');
      }
    } catch (e) {
      _debugLog('채무 저장/수정 오류: $e');
      ToastUtils.show(context, '오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _dueDateController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _memoController.dispose();
    _directInputController.dispose();
    _loanPeriodController.dispose();
    _gracePeriodController.dispose();
    super.dispose();
  }

  // 날짜 선택기
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    try {
      if (controller.text.isNotEmpty) {
        initialDate = DateFormat('yyyy/MM/dd').parse(controller.text);
      }
    } catch (e) {
      // 파싱 실패시 오늘 날짜
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'), // 한국어 설정 명시
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF33CC00), // 선택 색상 Green
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy/MM/dd').format(picked);
        
        // 채무 발생일 변경 시 만료일 자동 갱신 (기간이 입력되어 있을 때)
        if (controller == _dateController) {
          _updateDueDate();
        }
        // [Added] 상환 만료일 변경 시 대출기간 자동 갱신
        else if (controller == _dueDateController) {
          _updateLoanPeriod();
        }
      });
    }
  }

  // 금액 포맷팅 (원 단위 추가)
  void _formatAmount(String value) {
    if (_amountError != null) {
      setState(() => _amountError = null);
    }
    
    if (value.isEmpty) return;
    
    // 숫자만 추출
    String number = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isEmpty) {
      _amountController.clear();
      return;
    }
    
    // 천단위 콤마
    final formatter = NumberFormat("#,###");
    String formatted = formatter.format(int.parse(number));
    
    // '원' 붙이기
    String newText = "$formatted원";
    
    _amountController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1), // '원' 앞에 커서 위치
    );


  }

  // 이자율 포맷팅 (% 추가 및 경고 체크)
  void _formatInterest(String value) {
    if (_interestError != null) {
      setState(() => _interestError = null);
    }

    if (value.isEmpty) {
      setState(() {
        _showInterestWarning = false;
      });
      return;
    }
    
    // 숫자와 소수점만 추출
    String number = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (number.isEmpty) {
      _interestController.clear();
      setState(() {
        _showInterestWarning = false;
      });
      return;
    }

    // 값 체크
    try {
      double rate = double.parse(number);
      setState(() {
        _showInterestWarning = rate > 20.0;
      });
    } catch (e) {
      // 파싱 에러 무시
    }
    
    // '%' 붙이기
    String newText = "$number%";
    
    _interestController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1), // '%' 앞에 커서 위치
    );


  }

  // 기간 포맷팅 (개월 단위 추가)
  void _formatPeriod(TextEditingController controller, String value) {
    if (value.isEmpty) return;
    
    String number = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isEmpty) {
      controller.clear();
      return;
    }
    
    String newText = "$number개월";
    
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 2), // '개월' 앞에 커서 위치
    );


    
    // 기간 변경 시 만료일 자동 계산 (newText에서 숫자만 추출하여 전달)
    _updateDueDate(period: int.tryParse(number));
  }
  
  // 상환 만료일 자동 계산 Helper
  void _updateDueDate({int? period}) {
    try {
      // 1. 대출기간 확인 (입력된 period가 없으면 컨트롤러에서 확인)
      int loanMonths = period ?? 0;
      if (period == null && _loanPeriodController.text.isNotEmpty) {
        loanMonths = int.tryParse(_loanPeriodController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
      
      if (loanMonths <= 0) return; // 기간이 없으면 계산 안함
      
      // 2. 채무 발생일 파싱
      DateTime startDate;
      if (_dateController.text.isNotEmpty) {
        startDate = DateFormat('yyyy/MM/dd').parse(_dateController.text);
      } else {
        startDate = DateTime.now();
      }
      
      // 3. 만료일 계산 (발생일 + 대출기간 개월 수)
      DateTime dueDate = DateTime(startDate.year, startDate.month + loanMonths, startDate.day);
      
      // 4. 만료일 업데이트
      setState(() {
        _dueDateController.text = DateFormat('yyyy/MM/dd').format(dueDate);
      });
      
    } catch (e) {
      // 날짜 파싱 등 에러 발생 시 무시
    }
  }

  // [Added] 대출기간 자동 계산 Helper (만료일 선택 시)
  void _updateLoanPeriod() {
    try {
      if (_dateController.text.isEmpty || _dueDateController.text.isEmpty) return;

      DateTime startDate = DateFormat('yyyy/MM/dd').parse(_dateController.text);
      DateTime dueDate = DateFormat('yyyy/MM/dd').parse(_dueDateController.text);

      // 개월 수 차이 계산
      int months = (dueDate.year - startDate.year) * 12 + dueDate.month - startDate.month;
      
      // 일자 차이 보정 (예: 1월 1일 ~ 2월 1일은 1개월, 1월 1일 ~ 1월 31일은 0개월?)
      // 금융권은 보통 '개월' 단위로 딱 떨어지게 만기를 잡으므로 단순 월 차이만 계산해도 무방하지만,
      // 만약 2/1 ~ 3/1 사이가 28일/29일인 경우 등도 고려해야 함.
      // 여기서는 단순 월 차이로 계산 후, 만약 일자가 줄어들었으면 보정? 
      // -> 복잡성 줄이기 위해 단순 월 차이(year*12 + month) 사용.
      
      // 만약 계산된 개월 수가 1보다 작으면 1로 설정 (최소 1개월)
      if (months <= 0) months = 1;

      setState(() {
        _loanPeriodController.text = "${months}개월";
      });
    } catch (e) {
      // 날짜 파싱 실패 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 우측 상단 초록색 그라데이션 디자인
        Positioned(
          top: -400,
          right: -400,
          child: Container(
            width: 600,
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7,
                colors: [
                  const Color(0xFFB2FF59).withOpacity(0.4), // 더 밝은 연두색
                  const Color(0xFFB2FF59).withOpacity(0.0), // 투명으로 빠짐
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // 기존 컨텐츠
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Title
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Pretendard',
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: widget.initialDebt != null 
                          ? '채무정보를\n' 
                          : (widget.isStandalone ? '새로운\n' : '현재 나의\n')
                      ),
                      TextSpan(
                        text: widget.initialDebt != null ? '수정할까요?' : '채무정보',
                        style: const TextStyle(color: Color(0xFF00C853)), // 초록색 강조
                      ),
                      if (widget.initialDebt == null)
                        TextSpan(text: widget.isStandalone ? '를 추가할까요?' : '를 적어볼까요?'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 채무 발생일
                _buildLabel('채무 발생일'),
                GestureDetector(
                  onTap: () => _selectDate(context, _dateController),
                  child: AbsorbPointer(
                    child: _buildTextField(_dateController,
                        readOnly: true, suffixIcon: Icons.calendar_today),
                  ),
                ),

                const SizedBox(height: 16),

                // 상환 만료일
                _buildLabel('상환 만료일'),
                GestureDetector(
                  onTap: () => _selectDate(context, _dueDateController),
                  child: AbsorbPointer(
                    child: _buildTextField(_dueDateController,
                        readOnly: true, suffixIcon: Icons.calendar_today),
                  ),
                ),

                const SizedBox(height: 16),

                // 채무 종류 (대분류 & 소분류)
                _buildLabel('채무 종류'),
                Row(
                  children: [
                    // 대분류
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _mainCategory,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                            items: _categoryMap.keys.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _mainCategory = newValue!;
                                _subCategory = _categoryMap[_mainCategory]!.first;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 소분류
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _subCategory,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                            items: _categoryMap[_mainCategory]!.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _subCategory = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 직접 입력 필드 (조건부 노출)
                if (_subCategory == '직접 입력')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildTextField(
                          _directInputController,
                          hintText: '직접 입력해주세요',
                        ),
                      ),
                      if (_directInputError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(_directInputError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),

                const SizedBox(height: 16),

                // 상환 방식 탭 추가
                _buildLabel('상환 방식'),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      _buildRepaymentTab('원금만기일시'),
                      _buildRepaymentTab('원금균등'),
                      _buildRepaymentTab('원리금균등'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 대출원금 & 대출금리 Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('대출원금'),
                          _buildTextField(
                            _amountController,
                            textAlign: TextAlign.center,
                            onChanged: _formatAmount,
                            keyboardType: TextInputType.number,
                          ),
                          if (_amountError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                              child: Text(_amountError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('대출금리'),
                          _buildTextField(
                            _interestController,
                            textAlign: TextAlign.center,
                            onChanged: _formatInterest,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                          if (_interestError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                              child: Text(_interestError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 대출기간 & 거치기간 Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('대출기간'),
                          _buildTextField(
                            _loanPeriodController,
                            textAlign: TextAlign.center,
                            hintText: '예: 24개월',
                            onChanged: (val) => _formatPeriod(_loanPeriodController, val),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('거치기간'),
                          _buildTextField(
                            _gracePeriodController,
                            textAlign: TextAlign.center,
                            hintText: '예: 12개월',
                            onChanged: (val) => _formatPeriod(_gracePeriodController, val),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 이자율 경고 문구 (조건부 렌더링)
                if (_showInterestWarning)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0, right: 4.0),
                    child: Text(
                      '법정최고이자율은 20% 입니다.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // 월 예상 납입금액 카드 추가
                _buildExpectedPaymentCard(),

                const SizedBox(height: 24),

                // 메모
                _buildLabel('메모'),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _memoController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 건너뛰기
                if (!widget.isStandalone)
                  Column(
                    children: [
                      const Text(
                        '채무가 없으시면 건너뛰기 해주세요',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onNext,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            '건너뛰기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Bottom Buttons
                Row(
                  children: [
                    // 이전 버튼 (Standalone이 아닐 때만 표시)
                    if (!widget.isStandalone)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onPrevious,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFEFEFEF), // 연한 회색 (버튼 활성)
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            '이전',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (!widget.isStandalone) const SizedBox(width: 16),
                    // 다음/추가 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF33CC00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.initialDebt != null 
                                ? '수정 완료' 
                                : (widget.isStandalone ? '추가하기' : '다음'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    bool readOnly = false, 
    TextAlign textAlign = TextAlign.start,
    IconData? suffixIcon,
    String? hintText, // 추가
    Function(String)? onChanged,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        textAlign: textAlign,
        onChanged: onChanged,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText, // 추가
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: suffixIcon != null ? 12 : 0),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : null,
        ),
      ),
    );
  }

  Widget _buildRepaymentTab(String type) {
    // 실제 전체 명칭과 탭에 표시할 약칭 매칭
    final String fullName = type == '원금만기일시' ? '원금만기일시상환' : (type == '원금균등' ? '원금균등상환' : '원리금균등상환');
    final bool isSelected = _repaymentType == fullName;

    return Expanded(
      child: GestureDetector(
      onTap: () => setState(() {
          _repaymentType = fullName;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
              : [],
          ),
          child: Center(
            child: Text(
              type,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF00C853) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpectedPaymentCard() {
    final result = _getExpectedPaymentInfo();
    if (result == null) return const SizedBox.shrink();

    final schedule = _getInstallmentSchedule();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC5E1A5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Text('매월 예상 납입금액', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700])),
                ],
              ),
              const SizedBox(height: 16),
              ...result.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(line.label, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(line.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ))).toList(),
              const Divider(height: 24),
              Text(
                '* 위 결과는 입력하신 정보를 기반으로 한 단순 계산액이며, 실제 금융기관의 계산 방식에 따라 오차가 발생할 수 있습니다.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.4),
              ),
            ],
          ),
        ),
        
        // 상환 스케줄 표 추가
        if (schedule.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text('상환 스케줄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700])),
            ],
          ),
          const SizedBox(height: 12),
          RepaymentScheduleTable(
            schedule: schedule,
            // DebtStep에서는 탭 이벤트 없음 (단순 조회)
          ),
        ],
      ],
    );
  }

  List<InstallmentDetail> _getInstallmentSchedule() {
    try {
      final String amountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final String interestStr = _interestController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final String loanPeriodStr = _loanPeriodController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final String gracePeriodStr = _gracePeriodController.text.replaceAll(RegExp(r'[^0-9]'), '');

      if (amountStr.isEmpty || interestStr.isEmpty || loanPeriodStr.isEmpty) return [];

      final double principal = double.parse(amountStr);
      final double annualRate = double.parse(interestStr);
      final int loanMonths = int.parse(loanPeriodStr);
      final int graceMonths = gracePeriodStr.isEmpty ? 0 : int.parse(gracePeriodStr);

      if (principal <= 0 || loanMonths <= 0) return [];
      
      // 날짜 파싱
      DateTime startDate;
      try {
        startDate = DateFormat('yyyy/MM/dd').parse(_dateController.text);
      } catch (e) {
        startDate = DateTime.now();
      }

      return RepaymentLogic.generateSchedule(
        principal: principal,
        annualRate: annualRate,
        loanMonths: loanMonths,
        graceMonths: graceMonths,
        repaymentType: _repaymentType,
        startDate: startDate,
      );
    } catch (e) {
      return [];
    }
  }




  List<PaymentLine>? _getExpectedPaymentInfo() {
    try {
      final String amountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final String interestStr = _interestController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final String loanPeriodStr = _loanPeriodController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final String gracePeriodStr = _gracePeriodController.text.replaceAll(RegExp(r'[^0-9]'), '');

      if (amountStr.isEmpty || interestStr.isEmpty || loanPeriodStr.isEmpty) return null;

      return RepaymentLogic.getExpectedPaymentInfo(
        principal: double.parse(amountStr),
        annualRate: double.parse(interestStr),
        loanMonths: int.parse(loanPeriodStr),
        graceMonths: gracePeriodStr.isEmpty ? 0 : int.parse(gracePeriodStr),
        repaymentType: _repaymentType,
      );
    } catch (e) {
      return null;
    }
  }

  void _debugLog(String message) {
    debugPrint('[DebtStep] $message');
  }
}



