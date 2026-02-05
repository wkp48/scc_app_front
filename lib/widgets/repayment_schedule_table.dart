import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/repayment_logic.dart';

class RepaymentScheduleTable extends StatefulWidget {
  final List<InstallmentDetail> schedule;
  final Function(InstallmentDetail)? onItemTap;
  final bool showBorder;

  const RepaymentScheduleTable({
    Key? key,
    required this.schedule,
    this.onItemTap,
    this.showBorder = true,
  }) : super(key: key);

  @override
  State<RepaymentScheduleTable> createState() => _RepaymentScheduleTableState();
}

class _RepaymentScheduleTableState extends State<RepaymentScheduleTable> {
  final PageController _schedulePageController = PageController();
  int _currentSchedulePage = 0;
  final int itemsPerPage = 6;

  @override
  void dispose() {
    _schedulePageController.dispose();
    super.dispose();
  }

  String _formatCurrencyValue(double amount) {
    return NumberFormat('#,###').format(amount.round());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedule.isEmpty) return const SizedBox.shrink();

    final int totalPages = (widget.schedule.length / itemsPerPage).ceil();

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            clipBehavior: Clip.hardEdge, // 페이지 전환 시 튀어나오는 부분 깔끔하게 절삭
            decoration: const BoxDecoration(), // clipBehavior 작동을 위한 기본 장식
            // 헤더(약 45px) + 각 행(약 42px) + 보더 및 여유공간 고려하여 높이 계산
            height: 45.0 + (widget.schedule.sublist(
              _currentSchedulePage * itemsPerPage,
              ((_currentSchedulePage * itemsPerPage) + itemsPerPage) > widget.schedule.length 
                  ? widget.schedule.length 
                  : (_currentSchedulePage * itemsPerPage) + itemsPerPage
            ).length * 42.0),
            child: PageView.builder(
              controller: _schedulePageController,
              onPageChanged: (page) {
                setState(() {
                  _currentSchedulePage = page;
                });
              },
              itemCount: totalPages,
              itemBuilder: (context, pageIndex) {
                final int startIndex = pageIndex * itemsPerPage;
                final int endIndex = (startIndex + itemsPerPage) > widget.schedule.length 
                    ? widget.schedule.length 
                    : (startIndex + itemsPerPage);
                final pageItems = widget.schedule.sublist(startIndex, endIndex);

                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // 스크롤은 수동 드래그(PageView)로 처리하므로 비활성화
                  clipBehavior: Clip.hardEdge,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: widget.showBorder ? Border.all(color: const Color(0xFFC5E1A5)) : null,
                      borderRadius: widget.showBorder ? BorderRadius.circular(12) : null,
                      color: Colors.white,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: widget.showBorder 
                              ? const BorderRadius.vertical(top: Radius.circular(12))
                              : null,
                          ),
                          child: Row(
                            children: [
                              _buildHeaderCell('회차', 1),
                              _buildHeaderCell('상환금(원)', 2, hasLeadingBorder: true),
                              _buildHeaderCell('납입원금(원)', 2, hasLeadingBorder: true),
                              _buildHeaderCell('이자(원)', 2, hasLeadingBorder: true),
                              _buildHeaderCell('납입원금누계(원)', 2, hasLeadingBorder: true),
                              _buildHeaderCell('잔금(원)', 2, hasLeadingBorder: true),
                            ],
                          ),
                        ),
                        // Data Rows
                        ...pageItems.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final item = entry.value;
                          final bool isLastRow = entry.key == pageItems.length - 1;
  
                          return GestureDetector(
                            onTap: widget.onItemTap != null 
                              ? () => widget.onItemTap!(item) 
                              : null,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              decoration: BoxDecoration(
                                color: idx % 2 == 1 ? const Color(0xFFF9FBE7).withOpacity(0.3) : Colors.white,
                                border: Border(top: BorderSide(color: const Color(0xFFC5E1A5).withOpacity(0.3))),
                                borderRadius: (isLastRow && widget.showBorder)
                                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  _buildDataCell(item.index.toString(), 1),
                                  _buildDataCell(_formatCurrencyValue(item.totalPayment), 2, hasLeadingBorder: true),
                                  _buildDataCell(_formatCurrencyValue(item.principalPaid), 2, hasLeadingBorder: true),
                                  _buildDataCell(_formatCurrencyValue(item.interestPaid), 2, hasLeadingBorder: true),
                                  _buildDataCell(_formatCurrencyValue(item.accumulatedPrincipal), 2, hasLeadingBorder: true),
                                  _buildDataCell(_formatCurrencyValue(item.remainingBalance), 2, hasLeadingBorder: true),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Pagination Controls
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 24, color: Colors.green[700]),
                  onPressed: _currentSchedulePage > 0 
                  ? () {
                      _schedulePageController.previousPage(
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut);
                    }
                  : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentSchedulePage + 1} / $totalPages', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 24, color: Colors.green[700]),
                  onPressed: _currentSchedulePage < totalPages - 1 
                  ? () {
                      _schedulePageController.nextPage(
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut);
                    }
                  : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, int flex, {bool hasLeadingBorder = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 1),
        decoration: BoxDecoration(
          border: hasLeadingBorder ? Border(left: BorderSide(color: const Color(0xFFC5E1A5).withOpacity(0.5))) : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.bold, 
            color: Colors.green[800],
            letterSpacing: -0.5, // 글자 간격 축소로 너비 확보
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, int flex, {bool hasLeadingBorder = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 1),
        decoration: BoxDecoration(
          border: hasLeadingBorder ? Border(left: BorderSide(color: const Color(0xFFC5E1A5).withOpacity(0.2))) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10, 
              color: Colors.black87, 
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5, 
            ),
          ),
        ),
      ),
    );
  }
}
