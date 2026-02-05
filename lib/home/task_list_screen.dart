import 'package:flutter/material.dart';
import 'task_detail_screen.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import 'package:intl/intl.dart';

class TaskListScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TaskListScreen({super.key, required this.userData});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    final result = await ApiService.getMissions(widget.userData['uid']);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _tasks = result['data'];
        }
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'IN_PROGRESS': return const Color(0xFF5C72EB);
      case 'ASSIGNED': return const Color(0xFFFA8C16);
      case 'COMPLETED': return const Color(0xFF52C41A);
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'IN_PROGRESS': return '진행중';
      case 'ASSIGNED': return '수행 전';
      case 'COMPLETED': return '완료';
      default: return status;
    }
  }

  String _getDDay(String endDate) {
    try {
      final end = DateTime.parse(endDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(end.year, end.month, end.day);
      final diff = target.difference(today).inDays;
      if (diff == 0) return 'D-Day';
      if (diff < 0) return '기간 만료';
      return 'D-$diff';
    } catch (e) {
      return '';
    }
  }

  Future<void> _deleteTask(int missionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('과제 삭제'),
        content: const Text('정말 이 과제를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ApiService.deleteMission(missionId);
      if (result['success'] == true) {
        if (mounted) {
          ToastUtils.showSuccess(context, '과제가 삭제되었습니다.');
          _fetchTasks();
        }
      } else {
        if (mounted) {
          ToastUtils.showError(context, result['message'] ?? '삭제 실패');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('나의 과제', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: () async {
                   await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(task: {
                        'id': -1, // 자율 과제 ID
                        'userUid': widget.userData['uid'],
                        'title': '과제',
                        'description': '과제를 수행하고 기록합니다.',
                        'status': 'IN_PROGRESS',
                        'startDate': DateTime.now().toString().substring(0, 10),
                        'endDate': DateTime.now().toString().substring(0, 10),
                        'color': const Color(0xFF5C72EB),
                      }),
                    ),
                  );
                  _fetchTasks();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '과제 입력+',
                    style: TextStyle(
                      color: Color(0xFF1890FF), 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('할당된 과제가 없습니다.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _tasks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final Color taskColor = _getStatusColor(task['status']);
                    final String dDayText = _getDDay(task['endDate']);

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(task['status']),
                                  style: TextStyle(
                                    color: taskColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                                Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        if (task['status'] == 'COMPLETED' && task['submittedAt'] != null) {
                                          try {
                                            final date = DateTime.parse(task['submittedAt']);
                                            return Text(
                                              DateFormat('yy.MM.dd HH:mm').format(date),
                                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            );
                                          } catch (_) {}
                                        }
                                        return Text(
                                          '${task['startDate'].replaceAll('-', '.')} ~ ${task['endDate'].replaceAll('-', '.')}',
                                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        );
                                      }
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: taskColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        dDayText,
                                        style: TextStyle(
                                          color: taskColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteTask(task['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Text(
                            task['title'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            task['description'] ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                          ),
                          if (task['result'] != null && task['result'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text('제출 내용:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(task['result'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: task['status'] == 'COMPLETED'
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TaskDetailScreen(task: {
                                            ...task,
                                            'color': taskColor,
                                          }),
                                        ),
                                      );
                                      _fetchTasks(); // 상세화면 다녀온 후 다시 불러오기
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: taskColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[200],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                task['status'] == 'COMPLETED' ? '완료됨' : '과제 수행하기',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
