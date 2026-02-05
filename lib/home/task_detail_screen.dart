import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('과제 수행', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.task['color'].withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.task['color'].withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task['title'],
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.task['color']),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.task['description'],
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '과제 수행 내용',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '과제 수행 결과나 소감을 입력해주세요.',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.task['color'],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('과제 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitTask() async {
    if (_contentController.text.trim().isEmpty) {
      ToastUtils.show(context, '내용을 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    
    // API 호출
    Map<String, dynamic> result;
    if (widget.task['id'] == -1) {
      // 자율 과제인 경우: createSelfMission 호출
      result = await ApiService.createSelfMission(widget.task['userUid'], _contentController.text.trim());
    } else {
      result = await ApiService.submitMission(widget.task['id'], _contentController.text.trim());
    }
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        ToastUtils.show(context, '과제가 저장되었습니다.');
        Navigator.pop(context, true); // true 반환하여 목록 갱신 트리거
      } else {
        ToastUtils.show(context, result['message'] ?? '제출에 실패했습니다.');
      }
    }
  }
}
