import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:kcgp_cb/home/activity_record_modal.dart';
import 'package:kcgp_cb/home/activity_details_modal.dart';
import 'family_emotion_history_screen.dart';
import '../utils/toast_utils.dart'; // Add this import

class FamilyGrowthNoteScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FamilyGrowthNoteScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<FamilyGrowthNoteScreen> createState() => _FamilyGrowthNoteScreenState();
}

class _FamilyGrowthNoteScreenState extends State<FamilyGrowthNoteScreen> {
  // Callback for refresh
  void _onRefresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Daily Record Card (WALK)
              _buildDailyRecordCard(
                id: 'WALK',
                title: '일상기록',
                description: '가족의 일상을 기록하며 마음을 정리해요.',
                icon: Icons.wb_sunny_outlined,
                iconColor: const Color(0xFF52C41A),
                borderColors: [const Color(0xFFF6FFED), Colors.white],
                buttonText: '기록하기',
                onTap: () => ActivityRecordModal.show(
                  context, 
                  widget.userData, 
                  'WALK', 
                  onSaved: _onRefresh,
                  allowedTypes: ['WALK', 'EMOTION_DIARY'] // Only allow family tabs
                ),
                onDetailTap: () => ActivityDetailsModal.show(context, widget.userData, 'WALK', onRefresh: _onRefresh),
              ),

              const SizedBox(height: 16),

              // Emotion Diary Card (EMOTION_DIARY)
              _buildDailyRecordCard(
                id: 'EMOTION_DIARY',
                title: '감정일기',
                description: '오늘 하루 느꼈던 다양한 감정을\n기록하고 마음을 돌보는 시간',
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFF13C2C2),
                borderColors: [const Color(0xFFE6FFFB), Colors.white],
                buttonText: '기록하기',
                onTap: () => ActivityRecordModal.show(
                  context, 
                  widget.userData, 
                  'EMOTION_DIARY', 
                  onSaved: _onRefresh,
                   allowedTypes: ['WALK', 'EMOTION_DIARY'] // Only allow family tabs
                ),
                onDetailTap: () {
                   FamilyEmotionDetailsModal.show(context, widget.userData, onRefresh: _onRefresh);
                },
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성장노트',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          '오늘 하루도 힘내세요',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDailyRecordCard({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<Color> borderColors,
    required String buttonText,
    required VoidCallback onTap,
    required VoidCallback onDetailTap,
  }) {
    // Note: borderColors is used for Gradient in original code
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [iconColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  GestureDetector(
                    onTap: onDetailTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('상세내역', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
