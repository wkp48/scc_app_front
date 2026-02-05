import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../onboarding/debt_step.dart';
import '../utils/repayment_logic.dart';
import '../widgets/repayment_schedule_table.dart';
import '../services/api_service.dart';
import 'repayment_registration_screen.dart';
import '../utils/toast_utils.dart';

class DebtItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> debt;
  final Map<String, dynamic> userData; // 추가

  const DebtItemDetailScreen({
    super.key, 
    required this.debt,
    required this.userData, // 추가
  });

  @override
  State<DebtItemDetailScreen> createState() => _DebtItemDetailScreenState();
}

class _DebtItemDetailScreenState extends State<DebtItemDetailScreen> {
  late Map<String, dynamic> currentDebt;
  List<dynamic> _repayments = [];
  List<dynamic> _schedules = [];
  bool _isRepaymentsLoading = false;
  int _selectedStrategyIndex = 0;


  @override
  void initState() {
    super.initState();
    currentDebt = widget.debt;
    _loadRepayments();
  }

  Future<void> _loadRepayments() async {
    setState(() => _isRepaymentsLoading = true);
    final response = await ApiService.getRepayments(
      widget.userData['uid'],
      currentDebt['id'],
    );
    if (mounted) {
      setState(() {
        if (response['success']) {
          final List<dynamic> all = response['data'];
          _repayments = all.where((r) => r['status'] != 'SCHEDULED').toList();
          _schedules = all.where((r) => r['status'] == 'SCHEDULED').toList();
        }
        _isRepaymentsLoading = false;
      });
    }
  }

  Future<void> _refreshDebtData() async {
    try {
      final response = await ApiService.getDebtList(widget.userData['uid']);
      if (response['success'] && mounted) {
        final debts = response['data']['debts'] as List<dynamic>;
        final updatedDebt = debts.firstWhere(
          (d) => d['id'] == currentDebt['id'],
          orElse: () => currentDebt,
        );
        setState(() {
          currentDebt = updatedDebt;
        });
      }
      // 상환 내역도 새로고침
      await _loadRepayments();
    } catch (e) {
      debugPrint('[DebtItemDetailScreen] 데이터 새로고침 오류: $e');
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final double value = amount is double ? amount : double.tryParse(amount.toString()) ?? 0;
    return NumberFormat('#,###').format(value);
  }

  int _calculateDDay(String? dueDateStr) {
    if (dueDateStr == null) return 0;
    try {
      final dueDate = DateTime.parse(dueDateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return dueDate.difference(today).inDays;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dDay = _calculateDDay(currentDebt['dueDate']);
    final totalAmount = (currentDebt['amount'] ?? 0).toDouble();
    final remainingAmount = (currentDebt['remainingAmount'] ?? 0).toDouble();
    final interestRate = currentDebt['interestRate'] ?? 0.0;
    final categoryName = currentDebt['categoryCustom'] ?? currentDebt['subCategory'] ?? '금융기관';

    String statusText = '미납';
    Color statusColor = const Color(0xFFFF4D4F);
    Color statusBgColor = const Color(0xFFFFF1F0);

    if (currentDebt['status'] == 'PARTIAL') {
      statusText = '부분 상환';
      statusColor = const Color(0xFFFAAD14);
      statusBgColor = const Color(0xFFFFF7E6);
    } else if (currentDebt['status'] == 'PAID') {
      statusText = '완납';
      statusColor = const Color(0xFF52C41A);
      statusBgColor = const Color(0xFFF6FFED);
    }

    // [추가] 메인 화면 표시용: 남은 총 상환 금액(원금+이자) 계산
    double displayTotalRemaining = remainingAmount;
    
    try {
      final double calcAnnualRate = (currentDebt['interestRate'] ?? 0.0).toDouble();
      final int calcTotalMonths = (currentDebt['loanPeriod'] ?? 0);
      final int calcGraceMonths = (currentDebt['gracePeriod'] ?? 0);
      final String calcRepaymentType = currentDebt['repaymentType'] ?? '원리금균등상환';
      final DateTime calcStartDate = DateTime.parse(currentDebt['debtDate'] ?? DateTime.now().toIso8601String());

      // (1) 전체 스케줄 생성
      final originalSchedule = RepaymentLogic.generateSchedule(
        principal: totalAmount,
        annualRate: calcAnnualRate,
        loanMonths: calcTotalMonths,
        graceMonths: calcGraceMonths,
        repaymentType: calcRepaymentType,
        startDate: calcStartDate,
      );

      // (2) Month-Match Indexing (납입 여부 체크)
      int targetIndex = 1;
      if (originalSchedule.isNotEmpty) {
        for (int i = 1; i <= calcTotalMonths; i++) {
          final checkDate = DateTime(calcStartDate.year, calcStartDate.month + i, 1);
          double paidinMonth = 0;
          for (var repayment in _repayments) {
              DateTime? rDate;
              try { rDate = DateTime.tryParse(repayment['repaymentDate'].toString()); } catch (_) {}
              if (rDate != null && rDate.year == checkDate.year && rDate.month == checkDate.month) {
                paidinMonth += (repayment['amount'] ?? 0).toDouble();
              }
          }
          final double required = originalSchedule[i-1].totalPayment;
          if (paidinMonth < required * 0.9) {
            targetIndex = i;
            break; 
          } else {
            targetIndex = i + 1;
          }
        }
      }
      if (targetIndex < 1) targetIndex = 1;
      if (targetIndex > calcTotalMonths) targetIndex = calcTotalMonths;

      // (3) 남은 기간 재산정
      final int remainingMonthsForCalc = calcTotalMonths - targetIndex + 1;
      if (remainingMonthsForCalc > 0) {
        final recalcSchedule = RepaymentLogic.generateSchedule(
          principal: remainingAmount,
          annualRate: calcAnnualRate,
          loanMonths: remainingMonthsForCalc,
          graceMonths: 0, 
          repaymentType: calcRepaymentType,
          startDate: DateTime.now(),
        );
        
        // 총 상환액 합산
        double calcTotal = recalcSchedule.fold(0.0, (sum, item) => sum + item.totalPayment);
        displayTotalRemaining = calcTotal;
      } else {
        // 이미 다 갚았거나 기간 종료 시 -> 0? or remainingAmount?
        if (remainingAmount <= 0) displayTotalRemaining = 0;
      }
    } catch (e) {
      debugPrint('메인 총액 계산 오류: $e');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF434343)),
          onPressed: () => Navigator.pop(context, true), // 수정 사항이 있을 수 있으므로 새로고침 유도
        ),
        title: const Text(
          '채무 상세',
          style: TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D4F)),
            onPressed: () => _showDeleteConfirmDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 상단 카드 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7E6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFFFA8C16), size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    categoryName,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatCurrency(displayTotalRemaining),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F)),
                      ),
                      const SizedBox(width: 4),
                      Text('원', style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '(남은 원금 + 예상 이자)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '대출 상환율 ${(totalAmount > 0 ? ((totalAmount - remainingAmount) / totalAmount * 100).toStringAsFixed(1) : "0.0")}%',
                    style: const TextStyle(color: Color(0xFF5C72EB), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Color(0xFFFF4D4F)),
                            const SizedBox(width: 4),
                            Text(
                              'D${dDay >= 0 ? "-$dDay" : "+${dDay.abs()}"}',
                              style: const TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 상세 정보 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: const Color(0xFF5C72EB)),
                      const SizedBox(width: 8),
                      const Text('상세 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('채무종류', categoryName),
                  const SizedBox(height: 16),
                  _buildDetailRow('상환방식', currentDebt['repaymentType'] ?? '원리금균등상환'),
                  const SizedBox(height: 16),
                  _buildDetailRow('채무 발생일', currentDebt['debtDate'] ?? '-'),
                  const SizedBox(height: 16),
                  _buildDetailRow('대출기간', '${currentDebt['loanPeriod'] ?? '-'}개월'),
                  const SizedBox(height: 16),
                  _buildDetailRow('거치기간', '${currentDebt['gracePeriod'] ?? '0'}개월'),
                  const SizedBox(height: 16),
                  _buildDetailRow('상환 만료일', currentDebt['dueDate'] ?? '-', isHighlight: true),
                  const SizedBox(height: 16),
                  _buildDetailRow('원금', '${_formatCurrency(totalAmount)} 원'),
                  const SizedBox(height: 16),
                  _buildDetailRow('금리', '연 $interestRate%'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 월 예상 납입금액 카드 (상태가 PAID가 아닐 때만 표시)
            if (currentDebt['status'] != 'PAID') ...[

              _buildExpectedPaymentCard(), // 전략에 따라 내부 내용 변경됨
              const SizedBox(height: 24),
            ],

            // 상환 내역 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: const Color(0xFFFA8C16)), // 주황색 막대
                      const SizedBox(width: 8),
                      const Text('상환 내역', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isRepaymentsLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_repayments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('상환 내역이 없습니다.', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _repayments.length,
                      separatorBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFF5F5F5)),
                      ),
                      itemBuilder: (context, index) {
                        final rp = _repayments[index];
                        return InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RepaymentRegistrationScreen(
                                  debt: currentDebt,
                                  userData: widget.userData,
                                  initialRepayment: rp,
                                ),
                              ),
                            );

                            if (result == true && mounted) {
                              await _refreshDebtData();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rp['repaymentDate']?.toString().replaceAll('-', '/') ?? '-',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rp['paymentSource'] ?? '출처 미기입',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_formatCurrency(rp['amount'])} 원',
                                    style: const TextStyle(
                                      color: Color(0xFF52C41A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      bool isStartMonthRepay = false;
                                      try {
                                        String dDate = currentDebt['debtDate'].toString().replaceAll('.', '-');
                                        String rDate = rp['repaymentDate'].toString().replaceAll('.', '-');
                                        DateTime dtD = DateTime.parse(dDate);
                                        DateTime dtR = DateTime.parse(rDate);
                                        if (dtD.year == dtR.year && dtD.month == dtR.month) {
                                          isStartMonthRepay = true;
                                        }
                                      } catch(_) {}

                                      if (isStartMonthRepay) {
                                        return Text(
                                          '(원금 선납)',
                                          style: TextStyle(color: Colors.blue[300], fontSize: 11, fontWeight: FontWeight.w500),
                                        );
                                      }

                                      if (rp['interestAmount'] != null && rp['interestAmount'] > 0) {
                                        return Text(
                                          '(이자 ${_formatCurrency(rp['interestAmount'])}원)',
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),



              const SizedBox(height: 24),


            // 메모 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes, size: 20, color: Color(0xFF8C8C8C)),
                      SizedBox(width: 8),
                      Text('메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      currentDebt['memo'] == null || currentDebt['memo'].toString().isEmpty
                          ? '작성된 메모가 없습니다.'
                          : currentDebt['memo'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // 수정 페이지로 이동
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: DebtStep(
                          userData: widget.userData,
                          isStandalone: true,
                          initialDebt: currentDebt,
                          onNext: () {
                            // DebtStep만 닫기 (상세 화면은 유지)
                            Navigator.pop(context, true);
                          },
                          onPrevious: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  );
                  
                  // 수정 완료 후 돌아왔다면 데이터 새로고침
                  if (result == true && mounted) {
                    await _refreshDebtData();
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('수정'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F1F1F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RepaymentRegistrationScreen(
                        debt: currentDebt,
                        userData: widget.userData,
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    await _refreshDebtData();
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('상환 등록'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF36CFC9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyTab(String title, int index) {
    bool isSelected = _selectedStrategyIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStrategyIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5C72EB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF5C72EB) : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF5C72EB) : const Color(0xFF1F1F1F),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int _getRemainingMonths() {
    try {
      if (currentDebt['dueDate'] == null) return currentDebt['loanPeriod'] ?? 1;
      final dueDate = DateTime.parse(currentDebt['dueDate']);
      final now = DateTime.now();
      
      // 이번 달부터 만기일까지의 개월 수 계산 (최소 1개월)
      int months = (dueDate.year - now.year) * 12 + (dueDate.month - now.month);
      return months < 1 ? 1 : months;
    } catch (e) {
      return currentDebt['loanPeriod'] ?? 1;
    }
  }



  Widget _buildExpectedPaymentCard() {
    try {
      final double originalPrincipal = (currentDebt['amount'] ?? 0).toDouble();
      final double annualRate = double.tryParse(currentDebt['interestRate'].toString().replaceAll('%', '')) ?? 0.0;
      final int totalMonths = (currentDebt['loanPeriod'] ?? 0);
      final String repaymentType = currentDebt['repaymentType'] ?? '원리금균등상환';
      
      DateTime startDate;
      try {
        String dateStr = (currentDebt['debtDate'] ?? DateTime.now().toIso8601String()).toString().replaceAll('.', '-');
        startDate = DateTime.parse(dateStr);
      } catch (e) {
        startDate = DateTime.now();
        debugPrint('Debt Date Parse Error: $e');
      }

      // 0. 납입 내역 정렬 (FIFO) & 시작월 선납금 계산 (for principal adjustment)
      double startMonthPrepayment = 0;
      for (var repayment in _repayments) {
        if (repayment['repaymentDate'] == null) continue;
        try {
          final DateTime rDate = DateTime.parse(repayment['repaymentDate'].toString());
          if (rDate.year == startDate.year && rDate.month == startDate.month) {
            startMonthPrepayment += (repayment['amount'] ?? 0).toDouble();
          } 
        } catch (_) {}
      }

      List<dynamic> sortedRepayments = List.from(_repayments);
      sortedRepayments.sort((a, b) {
        DateTime dA = DateTime.parse(a['repaymentDate'] ?? '1970-01-01');
        DateTime dB = DateTime.parse(b['repaymentDate'] ?? '1970-01-01');
        return dA.compareTo(dB);
      });

      // 1. 시뮬레이션: RepaymentLogic으로 정식 스케줄 생성 후 차감
      int gracePeriod = currentDebt['gracePeriod'] ?? 0;
      List<InstallmentDetail> originSchedule = RepaymentLogic.generateSchedule(
        principal: originalPrincipal - startMonthPrepayment,
        annualRate: annualRate,
        loanMonths: totalMonths,
        graceMonths: gracePeriod,
        startDate: startDate,
        repaymentType: repaymentType,
      );

      double simulatedRemaining = originalPrincipal - startMonthPrepayment;
      if (simulatedRemaining < 0) simulatedRemaining = 0;

      int targetIndex = 1;
      double paidForTargetMonth = 0; // 이번 달(targetIndex)에 대해 부분 납부된 금액

      // Payment Stream Cursor
      int repCursor = 0;
      double currentRepaymentResidue = 0; // 현재 커서가 가리키는 납입 내역 중 아직 안 쓴 잔액

      // "선납된 금액(startMonthPrepayment)"은 이미 위에서 원금 차감으로 처리했으므로,
      // sortedRepayments에서 해당 날짜(대출 시작월) 납입건은 스킵해야 함.
      // (단, startMonthPrepayment 로직이 'startDate.month' 기준이므로, 정확히 매칭되는 것만 스킵)
      while (repCursor < sortedRepayments.length) {
          DateTime rDate = DateTime.parse(sortedRepayments[repCursor]['repaymentDate']);
          if (rDate.year == startDate.year && rDate.month == startDate.month) {
             repCursor++; // Skip start month prepayment
          } else {
             break;
          }
      }

      for (int i = 0; i < originSchedule.length; i++) {
         InstallmentDetail item = originSchedule[i];
         double requiredTotal = item.totalPayment;
         double collectedForThisRound = 0;

         // 해당 회차의 "제 기간" 날짜 범위 계산 (이자 감면/원금 상환 판별용)
         // item.index는 1부터 시작. 1회차 = startDate + 1달.
         int monthsToAdd = item.index;
         int year = startDate.year + (startDate.month + monthsToAdd - 1) ~/ 12;
         int month = (startDate.month + monthsToAdd - 1) % 12 + 1;
         DateTime monthEndCutoff = DateTime(year, month + 1, 0, 23, 59, 59); // 해당 회차 월 말일

         // 필요한 금액만큼 납입 내역에서 가져오기 (Stream Consumption)
         while (requiredTotal > 0.1) { // 부동소수점 오차 고려 0.1
            // 가져올 돈이 없으면 종료 (다음 납입 내역 로드)
            if (currentRepaymentResidue <= 0) {
               if (repCursor >= sortedRepayments.length) break; // 더 이상 돈 없음
               
               var r = sortedRepayments[repCursor];
               currentRepaymentResidue = (r['amount'] ?? 0).toDouble();
               // 날짜는 체크하지 않음 (FIFO: 과거/미래 돈 모두 현재 가장 급한 불(requiredTotal) 끄는데 사용)
            }
            
            double amountToUse = 0;
            if (currentRepaymentResidue >= requiredTotal) {
               amountToUse = requiredTotal;
            } else {
               amountToUse = currentRepaymentResidue;
            }
            
            requiredTotal -= amountToUse;
            collectedForThisRound += amountToUse;
            currentRepaymentResidue -= amountToUse;
            
            if (currentRepaymentResidue <= 0.1) {
               repCursor++;
               currentRepaymentResidue = 0;
            }
         }

         // 납부 결과 처리
         if (requiredTotal <= 1.0) { 
             // [완납]
             simulatedRemaining -= item.principalPaid; // 스케줄대로 원금 정상 차감
             targetIndex = i + 2; 
             
             // [초과 납부 처리: 모든 상환 방식에 대해 원금 상환으로 처리]
             // "이번 회차를 갚는 데 쓰이고 남은 돈(currentRepaymentResidue)"이 있는가?
             // && 그 돈이 "이번 달(혹은 그 이전)에 들어온 돈"인가? (미래 돈 아님)
             if (currentRepaymentResidue > 0) {
                 // 현재 커서가 가리키는 납입 내역의 날짜 확인
                 // (주의: repCursor는 이미 다음을 가리킬 수도 있음. 바로 전꺼를 봐야 함... 복잡)
                 // 간소화: 현재 repCursor가 아직 안 넘어갔으면(위에서 잔액 남음) 그 건의 날짜 확인.
                 if (repCursor < sortedRepayments.length) {
                    DateTime rDate = DateTime.parse(sortedRepayments[repCursor]['repaymentDate']);
                    if (rDate.isBefore(monthEndCutoff) || rDate.isAtSameMomentAs(monthEndCutoff)) {
                        // "제 때(또는 미리) 낸 돈"이 남았다 -> 원금 상환!
                        simulatedRemaining -= currentRepaymentResidue;
                        currentRepaymentResidue = 0; 
                        repCursor++; 
                        // 원금을 갚아버렸으므로, 이후 스케줄은 의미가 달라짐. 
                        // 하지만 시뮬레이션 단순화를 위해 여기서 루프 중단하지는 않고, 
                        // "돈 다 썼음" 상태로 다음 루프 진입 -> 다음 루프는 돈 없어서 미납 처리됨 (Correct)
                    }
                 }
             }
         } else {
             // [미납/부분납]
             targetIndex = i + 1;
             paidForTargetMonth = collectedForThisRound; // 낸 만큼만 기록
             
             // [Fix] 이자 먼저 제하고 원금 차감 (Bullet Repayment 등에서 필수)
             if (collectedForThisRound > 0) {
                 double principalPart = collectedForThisRound - item.interestPaid;
                 if (principalPart > 0) {
                     simulatedRemaining -= principalPart;
                 }
             }
             break; // 더 이상 진행 불가
         }
         
         if (simulatedRemaining < 0) simulatedRemaining = 0;
      }
      
      if (targetIndex < 1) targetIndex = 1;

      // 완납 체크
      if (simulatedRemaining <= 100 && targetIndex > totalMonths) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF6FFED), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFB7EB8F))),
            child: const Center(child: Text('모든 상환이 완료되었습니다! 🎉', style: TextStyle(color: Color(0xFF52C41A), fontSize: 16, fontWeight: FontWeight.bold))),
          );
      }

      // ----------------------------------------------------------------------
      // 납입금 감면형 로직 (단일 적용)
      // ----------------------------------------------------------------------

      int remainingMonthsForCalc = totalMonths - targetIndex + 1;
      List<InstallmentDetail> recalcSchedule = [];
      if (remainingMonthsForCalc > 0) {

        String debtDateStr = (currentDebt['debtDate'] ?? '').replaceAll('.', '-');
        DateTime debtDate;
        try {
          debtDate = DateTime.parse(debtDateStr);
        } catch (e) {
          debtDate = DateTime.now();
        }

        
        int monthsToAdvance = targetIndex - 1;
        DateTime adjustedStartDate = DateTime(debtDate.year, debtDate.month + monthsToAdvance, debtDate.day);
        
        

      
        int adjustedGraceMonths = 0;
        if (gracePeriod > 0) {
          adjustedGraceMonths = math.max(0, gracePeriod - monthsToAdvance);
        }

        recalcSchedule = RepaymentLogic.generateSchedule(
          principal: simulatedRemaining,
          annualRate: annualRate,
          loanMonths: remainingMonthsForCalc,
          graceMonths: adjustedGraceMonths,
          repaymentType: repaymentType,
          startDate: adjustedStartDate,
          startIndex: targetIndex,
        );
      }
      
      double nextMonthPayment = recalcSchedule.isNotEmpty ? recalcSchedule[0].totalPayment : 0;
      double remainingPaymentForCurrentMonth = nextMonthPayment - paidForTargetMonth;
      if (remainingPaymentForCurrentMonth < 0) remainingPaymentForCurrentMonth = 0;

      // Create a full display schedule including paid rounds as 0
      List<InstallmentDetail> displaySchedule = [];
      for (int i = 1; i < targetIndex; i++) {
        displaySchedule.add(InstallmentDetail(
          index: i,
          totalPayment: 0,
          principalPaid: 0,
          interestPaid: 0,
          accumulatedPrincipal: 0,
          remainingBalance: 0,
        ));
      }

      double alreadyPaidPrincipal = 0;
      if (recalcSchedule.isNotEmpty) {
         alreadyPaidPrincipal = originalPrincipal - simulatedRemaining;
      }

      if (recalcSchedule.isNotEmpty) {
        int currentMonthIndexInOrigin = targetIndex - 1;
        InstallmentDetail originalItem;
        
        if (currentMonthIndexInOrigin < originSchedule.length && currentMonthIndexInOrigin >= 0) {
           originalItem = originSchedule[currentMonthIndexInOrigin];
        } else {
           originalItem = recalcSchedule[0]; // Fallback
        }
        
        final first = originalItem;
        double pdInterest = (paidForTargetMonth > first.interestPaid) ? first.interestPaid : paidForTargetMonth;
        double displayInterest = first.interestPaid - pdInterest;
        if (displayInterest < 0) displayInterest = 0;
        
        double pdPrincipal = (paidForTargetMonth - pdInterest); 
        double displayPrincipal = first.principalPaid - pdPrincipal;
        if (displayPrincipal < 0) displayPrincipal = 0;

       
        double realRemainingTotal = first.totalPayment - paidForTargetMonth;
        if (realRemainingTotal < 0) realRemainingTotal = 0;

        displaySchedule.add(InstallmentDetail(
          index: targetIndex, 
          totalPayment: realRemainingTotal, // Use recalculated total
          principalPaid: displayPrincipal,
          interestPaid: displayInterest, 
          accumulatedPrincipal: first.accumulatedPrincipal, 
          remainingBalance: first.remainingBalance,
        ));
        
        for (int k = 1; k < recalcSchedule.length; k++) {
           var item = recalcSchedule[k];
           displaySchedule.add(InstallmentDetail(
              index: item.index,
              totalPayment: item.totalPayment,
              principalPaid: item.principalPaid,
              interestPaid: item.interestPaid,
              accumulatedPrincipal: item.accumulatedPrincipal + alreadyPaidPrincipal,
              remainingBalance: item.remainingBalance,
           ));
        }
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FFED),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB7EB8F).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Color(0xFF52C41A)),
                const SizedBox(width: 8),
                const Text('월 예상 납입금액 (감액 적용)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF237804))),
              ],
            ),
            const SizedBox(height: 24),
            _buildSummaryRow(
              paidForTargetMonth > 0 ? '남은 납입금액 (남은 ${recalcSchedule.length}회)' : '다음 달 예상 납입금 (남은 ${recalcSchedule.length}회)',
              '${_formatCurrency(remainingPaymentForCurrentMonth)}원',
              isBold: true
            ),
            const SizedBox(height: 12),
            // [Fix] 남은 총 이자/상환액 계산 시, '이미 낸 돈'을 차감해야 함.
            Builder(
              builder: (context) {
                // recalcSchedule은 '이번 달 전체'를 포함하므로, 거기서 '이번 달 낸 돈'을 빼줘야 정확함.
                double totalScheduledInterest = recalcSchedule.fold(0.0, (sum, i) => sum + i.interestPaid);
                double totalScheduledPayment = recalcSchedule.fold(0.0, (sum, i) => sum + i.totalPayment);
                
                // 이번 달 낸 돈 중 '이자'로 나간 부분 계산 (Interest First)
                double currentMonthInterest = recalcSchedule.isNotEmpty ? recalcSchedule[0].interestPaid : 0;
                double paidInterest = (paidForTargetMonth > currentMonthInterest) ? currentMonthInterest : paidForTargetMonth;
                
                debugPrint('=== SUMMARY DEBUG ===');
                debugPrint('Target Index: $targetIndex');
                debugPrint('Paid For Target Month: $paidForTargetMonth');
                debugPrint('Current Month Interest: $currentMonthInterest');
                debugPrint('Calculated Paid Interest: $paidInterest');
                
                double realRemainingInterest = totalScheduledInterest - paidInterest;
                if (realRemainingInterest < 0) realRemainingInterest = 0;
                
                double realRemainingTotalPay = totalScheduledPayment - paidForTargetMonth;
                if (realRemainingTotalPay < 0) realRemainingTotalPay = 0;

                return Column(
                  children: [
                    _buildSummaryRow('남은 총 이자액', '${_formatCurrency(realRemainingInterest)}원'),
                    const SizedBox(height: 12),
                    _buildSummaryRow('남은 총 상환 금액', '${_formatCurrency(realRemainingTotalPay)}원'),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            Text('* 위 결과는 입력하신 정보를 기반으로 한 단순 계산액이며, 실제 금융기관의 계산 방식에 따라 오차가 발생할 수 있습니다.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 8),
            Text('ⓘ 미리 낸 만큼 매월 납입금이 줄어듭니다 (${targetIndex}회차부터 재산정)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            

          ],
        ),
      );
    } catch (e) {
      return Container(child: Text('상환 스케줄 계산 중 오류가 발생했습니다. $e'));
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채무 삭제'),
        content: const Text('정말로 이 채무를 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              _deleteDebt(); // 삭제 실행
            },
            child: const Text('삭제', style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDebt() async {
    try {
      final response = await ApiService.deleteDebt(
        widget.userData['uid'],
        currentDebt['id'],
      );

      if (mounted) {
        if (response['success'] == true) {
          ToastUtils.show(context, '채무가 삭제되었습니다');
          // 상세 화면 닫고 목록 새로고침 트리거
          Navigator.pop(context, true);
        } else {
          ToastUtils.show(context, response['message'] ?? '삭제에 실패했습니다');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, '오류가 발생했습니다');
      }
    }
  }

  bool _isValidDebtForSchedule() {
    final amount = (currentDebt['amount'] ?? 0).toDouble();
    final rate = (currentDebt['interestRate'] ?? 0).toDouble();
    final period = currentDebt['loanPeriod'] ?? 0;
    return amount > 0 && rate > 0 && period > 0;
  }

  List<InstallmentDetail> _generateDetailedSchedule() {
    try {
      final double principal = (currentDebt['amount'] ?? 0).toDouble();
      final double annualRate = (currentDebt['interestRate'] ?? 0).toDouble();
      
      int loanMonths = currentDebt['loanPeriod'] ?? 0;
      final int graceMonths = currentDebt['gracePeriod'] ?? 0;
      
      // 대출기간 없는 경우 날짜로 추정
      DateTime startDate;
      try {
        startDate = DateFormat('yyyy-MM-dd').parse(currentDebt['debtDate']);
        if (loanMonths <= 0) {
           DateTime end = DateFormat('yyyy-MM-dd').parse(currentDebt['dueDate']);
           loanMonths = (end.year - startDate.year) * 12 + end.month - startDate.month;
        }
      } catch (e) {
        startDate = DateTime.now();
        loanMonths = 12; // default fallback
      }
      
      return RepaymentLogic.generateSchedule(
        principal: principal,
        annualRate: annualRate,
        loanMonths: loanMonths,
        graceMonths: graceMonths,
        repaymentType: currentDebt['repaymentType'] ?? '원리금균등상환',
        startDate: startDate,
      );
    } catch (e) {
      return [];
    }
  }

  DateTime _calculatePaymentDateForIndex(int index) {
      try {
        DateTime startDate = DateFormat('yyyy-MM-dd').parse(currentDebt['debtDate']);
        DateTime targetDate = startDate;
        for (int i = 0; i < index; i++) {
           DateTime nextMonth = DateTime(targetDate.year, targetDate.month + 1, targetDate.day);
           if (nextMonth.day != targetDate.day) {
              nextMonth = DateTime(targetDate.year, targetDate.month + 2, 0); 
           }
           targetDate = nextMonth;
        }
        return targetDate;
      } catch (e) {
        return DateTime.now();
      }
  }
}
