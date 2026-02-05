import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'debt_item_detail_screen.dart';
import '../onboarding/debt_step.dart';
import '../services/api_service.dart';
import 'repayment_registration_screen.dart';
import '../utils/repayment_logic.dart';

class DebtDetailsModal extends StatefulWidget {
  final Map<String, dynamic> debtData;
  final Map<String, dynamic> userData;
  final VoidCallback onSave;
  final DateTime? initialDate;

  const DebtDetailsModal({
    super.key,
    required this.debtData,
    required this.userData,
    required this.onSave,
    this.initialDate,
  });

  @override
  State<DebtDetailsModal> createState() => _DebtDetailsModalState();
}

class _DebtDetailsModalState extends State<DebtDetailsModal> {
  DateTime _currentDate = DateTime.now();
  Map<String, dynamic>? _localDebtData;
  bool _isLoading = true;
  bool _showAll = false; // '전체' 보기 모드 상태 추가

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
    _localDebtData = widget.debtData;
    _loadDebtData();
  }

  Future<void> _loadDebtData() async {
    setState(() => _isLoading = true);
    final response = await ApiService.getDebtList(widget.userData['uid']);
    if (mounted) {
      setState(() {
        if (response['success']) {
          _localDebtData = response['data'];
        }
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final double value = amount is double ? amount : double.tryParse(amount.toString()) ?? 0;
    return NumberFormat('#,###').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> allDebts = _localDebtData?['debts'] ?? [];
    // 백엔드의 totalDebtAmount가 이제 원금 합계이므로 그대로 사용하거나 다시 계산
    final double originalDebt = allDebts.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0).toDouble());
    // 남은 부채 금액(원금) 합계 - 상환율 계산용
    final double remainingPrincipalSum = allDebts.fold(0.0, (sum, item) => sum + (item['remainingAmount'] ?? 0).toDouble());
    // 남은 총 상환액(원금+이자) 합계 - 표시용
    final double totalRemainingRepaymentSum = allDebts.fold(0.0, (sum, item) => sum + RepaymentLogic.calculateTotalRemainingRepayment(item));
    
    final double repaymentRate = originalDebt > 0 ? ((originalDebt - remainingPrincipalSum) / originalDebt) * 100 : 0;
    
    // 모드에 따라 필터링
    final List<dynamic> filteredDebts;
    if (_showAll) {
      // 전체 모드: 시간순 정렬 (최신순)
      filteredDebts = List.from(allDebts);
      filteredDebts.sort((a, b) {
        final dateA = a['debtDate'] ?? '';
        final dateB = b['debtDate'] ?? '';
        return dateB.compareTo(dateA);
      });
    } else {
      // 월별 모드: 선택된 월에 상환 의무가 있는 채무만 필터링
      filteredDebts = allDebts.where((debt) {
        // 해당 월에 납입할 금액이 0보다 큰 경우만 리스트에 표시
        return RepaymentLogic.getMonthlyPayment(debt, targetDate: _currentDate) > 0;
      }).toList();
    }

    final double monthlyTotal = filteredDebts.fold(0.0, (sum, item) => sum + RepaymentLogic.getMonthlyPayment(item, targetDate: _currentDate));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 닫기 핸들 (중앙 바)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // 제목
          const Center(
            child: Text(
              '채무/상환 내역',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // 탭 전환기 (일자별 / 전체)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAll = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showAll ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_showAll 
                          ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                          : [],
                      ),
                      child: Center(
                        child: Text(
                          '월 납입 예정금액',
                          style: TextStyle(
                            color: !_showAll ? const Color(0xFF1F1F1F) : Colors.grey,
                            fontWeight: !_showAll ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAll = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showAll ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _showAll 
                          ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                          : [],
                      ),
                      child: Center(
                        child: Text(
                          '상세 채무내역',
                          style: TextStyle(
                            color: _showAll ? const Color(0xFF1F1F1F) : Colors.grey,
                            fontWeight: _showAll ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 날짜 선택 버튼 (일자별 모드에서만 표시)
          if (!_showAll) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
                    });
                  }, 
                  icon: const Icon(Icons.chevron_left, color: Colors.grey),
                ),
                Text(
                  DateFormat('yyyy/MM').format(_currentDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
                    });
                  }, 
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          _showAll ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('총 부채 금액', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.normal)),
                    Text('${_formatCurrency(originalDebt)}원', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('남은 총 상환액', style: TextStyle(color: const Color(0xFF5C72EB), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formatCurrency(totalRemainingRepaymentSum),
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                                ),
                                const SizedBox(width: 4),
                                const Text('원', style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 16, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('대출 상환율', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '${repaymentRate.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Color(0xFF36CFC9), fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ) : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${DateFormat('M월').format(_currentDate)} 납입 예정 총액', style: const TextStyle(color: Color(0xFF5C72EB), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatCurrency(monthlyTotal),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                      ),
                      const SizedBox(width: 4),
                      const Text('원', style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 18, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 채무 내역 섹션 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('채무 내역', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            body: SafeArea(
                              child: DebtStep(
                                userData: widget.userData,
                                isStandalone: true,
                                onNext: () {
                                  Navigator.pop(context); // DebtStep 닫기
                                  _loadDebtData(); // 모달 내 데이터 갱신
                                  widget.onSave(); // 메인 화면 갱신
                                },
                                onPrevious: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: Color(0xFF36CFC9)),
                          SizedBox(width: 4),
                          Text('채무 추가', style: TextStyle(color: Color(0xFF36CFC9), fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 채무 목록 리스트
          Expanded(
            child: filteredDebts.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _showAll 
                          ? '등록된 상세 채무 내역이 없습니다.'
                          : '${DateFormat('M월').format(_currentDate)}에는 납입 예정인 채무가 없습니다.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filteredDebts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final debt = filteredDebts[index];
                    return _buildDebtItem(debt);
                  },
                ),
          ),
          const SizedBox(height: 24),

          // 하단 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('닫기', style: TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF36CFC9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }





  Widget _buildDebtItem(Map<String, dynamic> debt) {
    // 상태에 따른 칩 디자인
    final String status = debt['status'] ?? 'UNPAID';
    String statusText = '미납';
    Color statusColor = const Color(0xFFFF4D4F);
    Color statusBgColor = const Color(0xFFFFF1F0);

    if (status == 'PARTIAL') {
      statusText = '부분 상환';
      statusColor = const Color(0xFFFAAD14);
      statusBgColor = const Color(0xFFFFF7E6);
    } else if (status == 'PAID') {
      statusText = '완납';
      statusColor = const Color(0xFF52C41A);
      statusBgColor = const Color(0xFFF6FFED);
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DebtItemDetailScreen(
              debt: debt,
              userData: widget.userData, 
            ),
          ),
        );
        
        // 상세 화면에서 돌아왔을 때 새로고침 (수정 완료 시 true 반환)
        if (result == true) {
          _loadDebtData();
          widget.onSave();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${debt['debtDate']}', // 실제 데이터에 맞게 포맷 고정 필요
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // Align top of bank name with top of rate label
              children: [
                Expanded(
                  child: Text(
                    debt['categoryCustom'] ?? debt['subCategory'] ?? '금융기관',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // [대출 상환율 표시 - Moved Here]
                Builder(
                  builder: (context) {
                    double original = (debt['amount'] ?? 0).toDouble();
                    double remaining = (debt['remainingAmount'] ?? 0).toDouble();
                    double rate = 0;
                    if (original > 0) {
                        rate = (1 - (remaining / original)) * 100;
                    }
                    if (rate < 0) rate = 0;
                    if (rate > 100) rate = 100;
                    
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('대출 상환율', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF36CFC9), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('상환 만료일', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${debt['dueDate'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(!_showAll ? 
                      (debt['repaymentType'] == '원금균등상환' ? '월 평균 납입액' : '월 납입 금액') : 
                      '남은 총 상환액', 
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          !_showAll 
                            ? _formatCurrency(RepaymentLogic.getMonthlyPayment(debt, targetDate: _currentDate))
                            : _formatCurrency(RepaymentLogic.calculateTotalRemainingRepayment(debt)),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Text('원', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepaymentRegistrationScreen(
                        debt: debt,
                        userData: widget.userData,
                      ),
                    ),
                  );
                  
                  if (result == true) {
                    _loadDebtData();
                    widget.onSave(); // 캘린더 화면도 갱신
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF36CFC9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('상환 내역 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
