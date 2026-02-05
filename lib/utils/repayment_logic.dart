import 'dart:math' as math;
import 'package:intl/intl.dart';

class InstallmentDetail {
  final int index;
  final double totalPayment;
  final double principalPaid;
  final double interestPaid;
  final double accumulatedPrincipal;
  final double remainingBalance;

  InstallmentDetail({
    required this.index,
    required this.totalPayment,
    required this.principalPaid,
    required this.interestPaid,
    required this.accumulatedPrincipal,
    required this.remainingBalance,
  });
}

class RepaymentLogic {
  static List<InstallmentDetail> generateSchedule({
    required double principal,
    required double annualRate,
    required int loanMonths,
    required int graceMonths,
    required String repaymentType,
    required DateTime startDate,
    int startIndex = 1,
  }) {
    if (principal <= 0 || loanMonths <= 0) return [];

    final double monthlyRate = (annualRate / 100) / 12; // 월할 이자율 (원리금균등용)
    final double dailyRate = (annualRate / 100) / 365;  // 일할 이자율 (나머지 방식용)
    final int repaymentMonths = loanMonths - graceMonths;
    
    double remainingPrincipal = principal;
    double accumulatedPrincipal = 0;
    double monthlyPaymentFixed = 0; // 원리금균등용 고정 상환액

    // 원리금균등 고정 상환액 계산
    if (repaymentType == '원리금균등상환' && repaymentMonths > 0) {
      if (monthlyRate == 0) {
        monthlyPaymentFixed = principal / repaymentMonths;
      } else {
        monthlyPaymentFixed = principal * 
            (monthlyRate * math.pow(1 + monthlyRate, repaymentMonths)) / 
            (math.pow(1 + monthlyRate, repaymentMonths) - 1);
      }
    }

    List<InstallmentDetail> schedule = [];
    DateTime currentDate = startDate;

    for (int i = 1; i <= loanMonths; i++) {
        // 다음 달 날짜 및 일수 계산
        DateTime nextMonth = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
        if (nextMonth.day != currentDate.day) {
          nextMonth = DateTime(currentDate.year, currentDate.month + 2, 0);
        }
        int daysInMonth = nextMonth.difference(currentDate).inDays;

        double interest = 0;
        double principalPaid = 0;
        double totalPayment = 0;

        if (i <= graceMonths) {
          // 거치 기간: 이자만 납부
           if (repaymentType == '원리금균등상환') {
             interest = remainingPrincipal * monthlyRate;
           } else {
             interest = remainingPrincipal * dailyRate * daysInMonth;
           }
           principalPaid = 0;
           totalPayment = interest;
        } else {
           // 상환 기간
           if (repaymentType == '원리금균등상환') {
             // Type A: 원리금균등 -> 월할 계산
             interest = remainingPrincipal * monthlyRate;
             if (repaymentMonths > 0) {
               principalPaid = monthlyPaymentFixed - interest;
             }
           } else {
             // Type B: 원금균등/만기일시 -> 일할 계산
             interest = remainingPrincipal * dailyRate * daysInMonth;
             if (repaymentMonths > 0) {
               if (repaymentType == '원금균등상환') {
                 principalPaid = principal / repaymentMonths;
               } else if (repaymentType == '원금만기일시상환') {
                 principalPaid = (i == loanMonths) ? principal : 0;
               }
             }
           }
           
           totalPayment = interest + principalPaid;
        }

        if (i == loanMonths) principalPaid = remainingPrincipal; // 마지막달 잔여 원금 정리
 
        // 정밀도 조정 및 예외 처리
        if (principalPaid > remainingPrincipal) principalPaid = remainingPrincipal;
        
        // 원리금균등 중간 회차 고정금액 보정
        if (repaymentType == '원리금균등상환' && i < loanMonths && i > graceMonths) {
            totalPayment = monthlyPaymentFixed;
        } else {
             totalPayment = interest + principalPaid;
        }
        
        accumulatedPrincipal += principalPaid;
        remainingPrincipal -= principalPaid;
        
        if (remainingPrincipal < 1.0) remainingPrincipal = 0;

        schedule.add(InstallmentDetail(
          index: startIndex + i - 1,
          totalPayment: totalPayment,
          principalPaid: principalPaid,
          interestPaid: interest,
          accumulatedPrincipal: accumulatedPrincipal,
          remainingBalance: remainingPrincipal,
        ));
        
        currentDate = nextMonth;
    }

    return schedule;
  }

  static List<PaymentLine>? getExpectedPaymentInfo({
    required double principal,
    required double annualRate,
    required int loanMonths,
    required int graceMonths,
    required String repaymentType,
  }) {
    try {
      if (principal <= 0 || loanMonths <= 0) return null;

      final double monthlyRate = (annualRate / 100) / 12;
      final double dailyRate = (annualRate / 100) / 365;
      final int repaymentMonths = loanMonths - graceMonths;

      double remainingPrincipal = principal;
      double monthlyPaymentFixed = 0;
      if (repaymentType == '원리금균등상환' && repaymentMonths > 0) {
        if (monthlyRate == 0) {
          monthlyPaymentFixed = principal / repaymentMonths;
        } else {
          monthlyPaymentFixed = principal *
              (monthlyRate * math.pow(1 + monthlyRate, repaymentMonths)) /
              (math.pow(1 + monthlyRate, repaymentMonths) - 1);
        }
      }

      double firstMonthTotal = 0;
      double totalInterest = 0;
      double lastMonthTotal = 0;
      DateTime currentDate = DateTime.now();

      for (int i = 1; i <= loanMonths; i++) {
        DateTime nextMonth = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
        if (nextMonth.day != currentDate.day) {
          nextMonth = DateTime(currentDate.year, currentDate.month + 2, 0);
        }
        int daysInMonth = nextMonth.difference(currentDate).inDays;

        double interest = 0;
        double principalPaid = 0;

        if (repaymentType == '원리금균등상환') {
          interest = remainingPrincipal * monthlyRate;
          if (i > graceMonths && repaymentMonths > 0) {
            principalPaid = monthlyPaymentFixed - interest;
          }
        } else {
          interest = remainingPrincipal * dailyRate * daysInMonth;
          if (i > graceMonths && repaymentMonths > 0) {
            if (repaymentType == '원금균등상환') {
              principalPaid = principal / repaymentMonths;
            } else if (repaymentType == '원금만기일시상환') {
              principalPaid = (i == loanMonths) ? principal : 0;
            }
          }
        }

        if (i == loanMonths) principalPaid = remainingPrincipal;

        double currentTotal = 0;
        if (repaymentType == '원리금균등상환' && i < loanMonths && i > graceMonths) {
          currentTotal = monthlyPaymentFixed;
        } else {
          currentTotal = interest + principalPaid;
        }
        
        if (i == 1) firstMonthTotal = currentTotal;

        totalInterest += interest;
        if (i == loanMonths) lastMonthTotal = currentTotal;

        remainingPrincipal -= (principalPaid > remainingPrincipal ? remainingPrincipal : principalPaid);
        currentDate = nextMonth;
      }

      final formatter = NumberFormat('#,###');
      List<PaymentLine> lines = [];

      if (repaymentType == '원금만기일시상환') {
        lines.add(PaymentLine('월 납입액 (이자)', '${formatter.format((totalInterest / loanMonths).round())}원'));
        lines.add(PaymentLine('만기 시 상환액', '${formatter.format(lastMonthTotal.round())}원'));
      } else if (repaymentType == '원금균등상환') {
        lines.add(PaymentLine('첫 달 납입금 (매월 감소)', '${formatter.format(firstMonthTotal.round())}원'));
      } else {
        lines.add(PaymentLine('월 납입액', '${formatter.format(monthlyPaymentFixed.round())}원'));
      }

      lines.add(PaymentLine('총 이자액', '${formatter.format(totalInterest.round())}원'));
      lines.add(PaymentLine('총 상환 금액 (원금+이자)', '${formatter.format((principal + totalInterest).round())}원'));

      return lines;
    } catch (e) {
      return null;
    }
  }
  static double getMonthlyPayment(Map<String, dynamic> debt, {DateTime? targetDate}) {
    try {
      final double principal = (debt['amount'] ?? 0).toDouble();
      final double remainingAmount = (debt['remainingAmount'] ?? 0).toDouble();
      final double annualRate = (debt['interestRate'] ?? 0).toDouble();
      int loanMonths = debt['debtPeriod'] ?? debt['loanPeriod'] ?? 0;
      final int graceMonths = debt['gracePeriod'] ?? 0;
      final String repaymentType = debt['repaymentType'] ?? '원리금균등상환';

      // 상환이 이미 완료된 경우 (잔액이 0) 계산 제외
      if (principal <= 0 || remainingAmount <= 0) return 0;

      // 대출 기간이 없는 경우 날짜 차이로 계산 (Fallback)
      if (loanMonths <= 0) {
        try {
          String? dDate = debt['debtDate'];
          String? duDate = debt['dueDate'];
          if (dDate != null && duDate != null) {
            DateTime start = dDate.contains('-') ? DateFormat('yyyy-MM-dd').parse(dDate) : DateFormat('yyyy/MM/dd').parse(dDate);
            DateTime end = duDate.contains('-') ? DateFormat('yyyy-MM-dd').parse(duDate) : DateFormat('yyyy/MM/dd').parse(duDate);
            loanMonths = (end.year - start.year) * 12 + end.month - start.month;
          }
        } catch (e) {
          loanMonths = 0;
        }
        if (loanMonths <= 0) loanMonths = 1;
      }

      // 기준일 (채무 발생일)
      DateTime currentDate;
      String? dateStr = debt['debtDate'];
      try {
        if (dateStr != null) {
          currentDate = dateStr.contains('-') ? DateFormat('yyyy-MM-dd').parse(dateStr) : DateFormat('yyyy/MM/dd').parse(dateStr);
        } else {
          currentDate = DateTime.now();
        }
      } catch (e) {
        currentDate = DateTime.now();
      }

      // 조회 날짜가 채무 발생 전이면 0원
      if (targetDate != null) {
        final startOfMonth = DateTime(currentDate.year, currentDate.month, 1);
        final targetOfMonth = DateTime(targetDate.year, targetDate.month, 1);
        if (targetOfMonth.isBefore(startOfMonth)) return 0;
      }

      final double dailyRate = (annualRate / 100) / 365;
      // final int repaymentMonths = (loanMonths - graceMonths) > 0 ? (loanMonths - graceMonths) : loanMonths;
      
      double totalInterest = 0;
      double remainingPrincipal = principal;
      double monthlyPaymentFixed = 0; 
      
      if (repaymentType == '원리금균등상환') {
        final int repaymentMonths = (loanMonths - graceMonths) > 0 ? (loanMonths - graceMonths) : loanMonths;
        double monthlyRate = (annualRate / 100) / 12;
        if (monthlyRate == 0) {
          monthlyPaymentFixed = principal / repaymentMonths;
        } else {
          monthlyPaymentFixed = principal * 
              (monthlyRate * math.pow(1 + monthlyRate, repaymentMonths)) / 
              (math.pow(1 + monthlyRate, repaymentMonths) - 1);
        }
      }

      for (int i = 1; i <= loanMonths; i++) {
        DateTime nextMonth = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
        if (nextMonth.day != currentDate.day) {
          nextMonth = DateTime(currentDate.year, currentDate.month + 2, 0);
        }
        int daysInMonth = nextMonth.difference(currentDate).inDays;
        
        double interest = remainingPrincipal * dailyRate * daysInMonth;
        totalInterest += interest;
        
        double principalPaid = 0;
        final int repaymentMonths = (loanMonths - graceMonths) > 0 ? (loanMonths - graceMonths) : loanMonths;

        if (i > graceMonths) {
          if (repaymentType == '원금균등상환') {
            principalPaid = principal / repaymentMonths;
          } else if (repaymentType == '원리금균등상환') {
            principalPaid = monthlyPaymentFixed - (remainingPrincipal * ((annualRate / 100) / 12));
          } else if (repaymentType == '원금만기일시상환') {
            principalPaid = (i == loanMonths) ? principal : 0;
          }
          if (i == loanMonths) principalPaid = remainingPrincipal;
        }
        
        double currentTotal = interest + principalPaid;

        // 타겟 날짜가 명시된 경우, 해당 월의 실제 납입금을 반환
        // 납입일은 기간의 끝(nextMonth) 기준 (이를 DebtDetailsModal 로직에 맞춤)
        if (targetDate != null && 
            nextMonth.year == targetDate.year && 
            nextMonth.month == targetDate.month) {
          // 원금만기일시상환이어도 매달 이자는 납부해야 함
          return currentTotal;
        }

        remainingPrincipal -= (principalPaid > remainingPrincipal ? remainingPrincipal : principalPaid);
        currentDate = nextMonth;
      }

      // 타겟 날짜가 명시되었는데 기간 내에 없으면 상환 종료된 것이므로 0원
      if (targetDate != null) return 0;

      // 타겟 날짜가 없으면 평균값 반환 (Fallback)
      if (repaymentType == '원금만기일시상환') {
        return loanMonths > 0 ? totalInterest / loanMonths : 0;
      } else if (repaymentType == '원금균등상환') {
        return (principal + totalInterest) / loanMonths;
      } else { // 원리금균등상환
        return monthlyPaymentFixed;
      }
    } catch (e) {
      return 0;
    }
  }
  static double calculateTotalRemainingRepayment(Map<String, dynamic> debt) {
    try {
      final double remainingPrincipal = (debt['remainingAmount'] ?? 0).toDouble();
      if (remainingPrincipal <= 0) return 0;

      final double annualRate = (debt['interestRate'] ?? 0).toDouble();
      final int totalMonths = debt['loanPeriod'] ?? 0;
      final String repaymentType = debt['repaymentType'] ?? '원리금균등상환';
      
      DateTime startDate;
      try {
        // 날짜 형식이 다양할 수 있으므로 안전하게 파싱
        String dateStr = debt['debtDate'].toString().replaceAll('.', '-'); 
        startDate = DateTime.parse(dateStr);
      } catch(_) { startDate = DateTime.now(); }
      
      // 경과 개월 수 계산
      final now = DateTime.now();
      int monthsPassed = (now.year - startDate.year) * 12 + now.month - startDate.month;
      
      int remainingMonths = totalMonths - monthsPassed;
      if (remainingMonths < 1) remainingMonths = 1; // 최소 1개월

      final schedule = RepaymentLogic.generateSchedule(
        principal: remainingPrincipal,
        annualRate: annualRate,
        loanMonths: remainingMonths,
        graceMonths: 0, 
        repaymentType: repaymentType,
        startDate: DateTime.now(),
      );

      return schedule.fold(0.0, (sum, item) => sum.toDouble() + item.totalPayment);
    } catch (e) {
      return (debt['remainingAmount'] ?? 0).toDouble();
    }
  }
}

class PaymentLine {
  final String label;
  final String value;
  PaymentLine(this.label, this.value);
}
