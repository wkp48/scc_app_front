import 'package:flutter/material.dart';

class FamilyEmotionDetailScreen extends StatelessWidget {
  final dynamic log;
  const FamilyEmotionDetailScreen({Key? key, required this.log}) : super(key: key);

  String _getAbsoluteUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('data:image')) return path;
    if (path.startsWith('http')) return path;
    const String effectiveBaseUrl = 'http://115.20.138.8:8900/api';
    String url;
    if (path.startsWith('/api')) {
      url = effectiveBaseUrl.substring(0, effectiveBaseUrl.length - 4) + path;
    } else if (!path.startsWith('/')) {
      url = '$effectiveBaseUrl/$path';
    } else {
      url = '$effectiveBaseUrl$path';
    }
    return Uri.encodeFull(url);
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> imageUrls = log['imageUrls'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('감정일기 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _getAbsoluteUrl(imageUrls[index]),
                          width: MediaQuery.of(context).size.width * 0.8,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            _buildSection('상황', log['situation']),

            const SizedBox(height: 24),
            const Text('감정 점수', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                if (log['angerScore'] != null) _buildDetailScore('분노', log['angerScore'], const Color(0xFFFF4D4F)),
                if (log['anxietyScore'] != null) _buildDetailScore('불안', log['anxietyScore'], const Color(0xFF722ED1)),
                if (log['depressionScore'] != null) _buildDetailScore('우울', log['depressionScore'], const Color(0xFF1890FF)),
                if (log['hasteScore'] != null) _buildDetailScore('조급함', log['hasteScore'], const Color(0xFFFA8C16)),
              ],
            ),

            const SizedBox(height: 24),
            _buildSection('자동적 사고', log['thought']),
            _buildSection('반박하기', log['rebuttal']),
            _buildSection('상황 종료 후 나의 감정', log['aftermath']), // Question 5
          ],
        ),
      ),
    );
  }

  Widget _buildDetailScore(String label, dynamic score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text('$score점', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Text(content, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF424242))),
        ),
      ],
    );
  }
}
