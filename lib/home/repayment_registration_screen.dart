import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class RepaymentRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic> debt;
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? initialRepayment;

  const RepaymentRegistrationScreen({
    super.key,
    required this.debt,
    required this.userData,
    this.initialRepayment,
  });

  @override
  State<RepaymentRegistrationScreen> createState() => _RepaymentRegistrationScreenState();
}

class _RepaymentRegistrationScreenState extends State<RepaymentRegistrationScreen> {
  final TextEditingController _repaymentDateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  // interestController removed
  
  // _includeInterest removed
  
  String _paymentSource = '근로 및 일용소득';
  bool _isLoading = false;

  final List<String> _sources = [
    '근로 및 일용소득',
    '사업 소득',
    '재산처분대금',
    '예금 및 적금'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRepayment != null) {
      final rp = widget.initialRepayment!;
      _repaymentDateController.text = rp['repaymentDate']?.toString().replaceAll('-', '/') ?? '';
      _amountController.text = '${_formatCurrency(rp['amount'])}원';
      
      // 기존 로직 제거 (이자 불러오기)
      // _includeInterest, _interestController logic removed
      
      _paymentSource = rp['paymentSource'] ?? _sources[0];
    } else {
      _repaymentDateController.text = DateFormat('yyyy/MM/dd').format(DateTime.now());
    }
  }

  bool get _isEditMode => widget.initialRepayment != null;

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final double value = amount is double ? amount : double.tryParse(amount.toString()) ?? 0;
    return NumberFormat('#,###').format(value);
  }

  Future<void> _handleSave() async {
    final String amountStr = _amountController.text.replaceAll(',', '').replaceAll('원', '');
    if (amountStr.isEmpty) {
      ToastUtils.show(context, '상환 금액을 입력해주세요');
      return;
    }

    final int? amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ToastUtils.show(context, '올바른 금액을 입력해주세요');
      return;
    }

    // 잔여 채무액보다 변제 금액이 많은지 확인 (신규 등록일 때만 체크하거나, 수정 시에도 적용 가능)
    final double remainingAmount = (widget.debt['remainingAmount'] ?? widget.debt['amount'] ?? 0).toDouble();
    if (amount > remainingAmount) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('확인'),
          content: Text('변제 금액(${_formatCurrency(amount)}원)이 잔여 채무액(${_formatCurrency(remainingAmount)}원)보다 많습니다.\n계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인', style: TextStyle(color: Color(0xFF52C41A))),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    // 이자 자동 계산 (원리금균등상환 일정 유지를 위해)
    final double remainingForCalc = (widget.debt['remainingAmount'] ?? widget.debt['amount'] ?? 0).toDouble();
    final double rate = double.tryParse((widget.debt['interestRate'] ?? 0).toString().replaceAll('%', '')) ?? 0.0;
    final String repaymentType = widget.debt['repaymentType'] ?? '원리금균등상환';
    
    // [Fix] 대출 발생월에 상환하는 경우 이자는 발생하지 않음 (전액 원금 상환)
    bool isStartMonth = false;
    try {
      // debtDate 형식 유연하게 처리 (. 또는 -)
      String dDateStr = widget.debt['debtDate'].toString().replaceAll('.', '-');
      DateTime debtDate = DateTime.parse(dDateStr);
      DateTime repayDate = DateFormat('yyyy/MM/dd').parse(_repaymentDateController.text);
      
      if (debtDate.year == repayDate.year && debtDate.month == repayDate.month) {
        isStartMonth = true;
      }
    } catch (e) {
      debugPrint('Date compare error: $e');
    }

    int calculatedInterest = 0;
    if (!isStartMonth) {
      if (repaymentType == '원리금균등상환') {
        // 원리금균등은 단순 월할(12분할) 적용
        final double monthlyRate = (rate / 100) / 12;
        calculatedInterest = (remainingForCalc * monthlyRate).round();
      } else {
        // 원금만기일시/원금균등은 일할 계산 (해당 월 일수 기준)
        try {
          DateTime repayDate = DateFormat('yyyy/MM/dd').parse(_repaymentDateController.text);
          DateTime monthStart = DateTime(repayDate.year, repayDate.month, 1);
          DateTime nextMonthStart = DateTime(repayDate.year, repayDate.month + 1, 1);
          int daysInMonth = nextMonthStart.difference(monthStart).inDays;
          
          final double dailyRate = (rate / 100) / 365;
          calculatedInterest = (remainingForCalc * dailyRate * daysInMonth).round();
        } catch (e) {
          // 파싱 실패 시 월할로 폴백
          final double monthlyRate = (rate / 100) / 12;
          calculatedInterest = (remainingForCalc * monthlyRate).round();
        }
      }
    }

    // [중요] 원금만기일시상환이고, 입력한 금액이 계산된 이자와 거의 같다면(오차 1000원 이내), 
    // 사용자 편의를 위해 전액 이자로 간주 (원금 0원 처리)
    if (repaymentType == '원금만기일시상환' && !isStartMonth) {
      if ((amount - calculatedInterest).abs() < 2000) {
        calculatedInterest = amount;
      }
    }

    // 상환액보다 이자가 클 수 없음 (예외처리)
    if (calculatedInterest > amount) {
      calculatedInterest = amount; // 전액 이자로 처리 (원금 상환 0)
    }
    
    final int interestAmount = calculatedInterest;
    final int principalAmount = amount - interestAmount;

    setState(() => _isLoading = true);

    try {
      final repaymentData = {
        'repaymentDate': _repaymentDateController.text.replaceAll('/', '-'),
        'amount': amount,
        'principalAmount': principalAmount,
        'interestAmount': interestAmount,
        'paymentSource': _paymentSource,
      };

      final response = _isEditMode
          ? await ApiService.updateRepayment(
              widget.userData['uid'],
              widget.initialRepayment!['id'],
              repaymentData,
            )
          : await ApiService.registerRepayment(
              widget.userData['uid'],
              widget.debt['id'],
              repaymentData,
            );

      if (mounted) {
        if (response['success'] == true) {
          ToastUtils.show(context, _isEditMode ? '상환 내역이 수정되었습니다' : '상환 내역이 등록되었습니다');
          Navigator.pop(context, true);
        } else {
          ToastUtils.show(context, response['message'] ?? '요청에 실패했습니다');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, '오류가 발생했습니다');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    try {
      if (controller.text.isNotEmpty) {
        initialDate = DateFormat('yyyy/MM/dd').parse(controller.text);
      }
    } catch (e) {
      initialDate = DateTime.now();
    }

    DateTime firstDate = DateTime(2000);
    try {
      if (widget.debt['debtDate'] != null) {
        String dDateStr = widget.debt['debtDate'].toString().replaceAll('.', '-');
        firstDate = DateTime.parse(dDateStr);
      }
    } catch (e) {
      // 파싱 실패 시 기본값 유지
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate, // 초기 날짜가 시작일보다 전이면 시작일로 조정
      firstDate: firstDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF52C41A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy/MM/dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditMode ? '상환 내역 수정' : '상환 등록',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4D4F)),
              onPressed: _showDeleteConfirmDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('채무 일자'),
                _buildReadOnlyField(widget.debt['debtDate'] ?? '-'),
                const SizedBox(height: 20),
                
                _buildFieldLabel('상환일'),
                GestureDetector(
                  onTap: () => _selectDate(context, _repaymentDateController),
                  child: AbsorbPointer(
                    child: _buildDateField(_repaymentDateController),
                  ),
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('상환 주체'),
                _buildReadOnlyField(widget.debt['categoryCustom'] ?? widget.debt['subCategory'] ?? '-'),
                const SizedBox(height: 20),

                _buildFieldLabel('변제 원천'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sources.map((source) => _buildSourceChip(source)).toList(),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('잔여 채무액'),
                          _buildReadOnlyField('${_formatCurrency(widget.debt['remainingAmount'] ?? widget.debt['amount'])}원'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('이자율'),
                          _buildReadOnlyField('${widget.debt['interestRate'] ?? 0}%'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildFieldLabel('변제 금액'),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0원',
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.isNotEmpty) {
                        String formatted = NumberFormat('#,###').format(int.parse(digits));
                        _amountController.text = '$formatted원';
                        _amountController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _amountController.text.length - 1),
                        );
                      }
                    }
                  },
                ),
                
                // (이전 이자 입력란 제거됨)
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F3F3),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF52C41A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            controller.text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String source) {
    final bool isSelected = _paymentSource == source;
    return GestureDetector(
      onTap: () => setState(() => _paymentSource = source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6FFFB) : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF52C41A) : Colors.transparent,
          ),
        ),
        child: Text(
          source,
          style: TextStyle(
            color: isSelected ? const Color(0xFF52C41A) : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('상환 내역 삭제'),
        content: const Text('정말로 이 상환 내역을 삭제하시겠습니까?\n삭제 시 해당 금액만큼 채무 잔액이 복구됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // 다이얼로그 닫기
              setState(() => _isLoading = true);
              final response = await ApiService.deleteRepayment(
                widget.userData['uid'],
                widget.initialRepayment!['id'],
              );
              if (mounted) {
                if (response['success']) {
                  ToastUtils.show(context, '상환 내역이 삭제되었습니다');
                  Navigator.pop(context, true); // 화면 닫기 (이 context는 RepaymentRegistrationScreen의 context)
                } else {
                  ToastUtils.show(context, response['message'] ?? '삭제 실패');
                }
                setState(() => _isLoading = false);
              }
            },
            child: const Text('삭제', style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
    );
  }
}
