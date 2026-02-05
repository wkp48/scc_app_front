import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DiagnosisDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const DiagnosisDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  State<DiagnosisDetailScreen> createState() => _DiagnosisDetailScreenState();
}

class _DiagnosisDetailScreenState extends State<DiagnosisDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _questions = [];
  Map<int, int> _userAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. 답변 데이터 파싱 ([0, 1, 2, ...] 형태의 문자열)
    String answersJson = widget.record['answersJson'] ?? "[]";
    try {
      // "[0, 1, 2]" -> List<int>
      List<dynamic> parsed = json.decode(answersJson);
      for (int i = 0; i < parsed.length; i++) {
        _userAnswers[i] = parsed[i] as int;
      }
    } catch (e) {
      print("답변 파싱 오류: $e");
    }

    // 2. 질문 목록 가져오기
    final response = await ApiService.getDiagnosisQuestions();
    if (response['success'] == true) {
      if (mounted) {
        setState(() {
          _questions = response['data'];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime date = DateTime.parse(widget.record['createdAt']);
    int totalScore = widget.record['totalScore'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('진단 상세 기록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(date, totalScore),
                  const SizedBox(height: 24),
                  const Text('검사 항목별 답변', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...List.generate(_questions.length, (index) => _buildQuestionItem(index)),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(DateTime date, int score) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FFED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.assignment_turned_in, color: Color(0xFF52C41A), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(date),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text('최종 합계 점수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(
            '$score점',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF52C41A)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionItem(int index) {
    final question = _questions[index];
    final questionText = question['question'] ?? "";
    final optionsJson = question['optionsJson'] ?? "[]";
    List<dynamic> options = json.decode(optionsJson);
    
    int? selectedIndex = _userAnswers[index];
    String selectedText = (selectedIndex != null && selectedIndex >= 0 && selectedIndex < options.length) 
        ? options[selectedIndex] 
        : "응답 없음";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Expanded(
                child: Text(
                  questionText,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: Color(0xFF1890FF)),
                const SizedBox(width: 8),
                Text(
                  selectedText,
                  style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
