import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../home/education_detail_screen.dart';

class TrainingScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TrainingScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  List<dynamic> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final response = await ApiService.getHelpfulVideos();
    if (mounted) {
      setState(() {
        if (response['success']) {
          _videos = response['data'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchVideos,
            color: const Color(0xFF5C72EB),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), // [Modified] Adjusted padding
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '셀프 트레이닝', // [Modified] Renamed
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '나를 지키는 힘, 오늘 하루도 연습해보세요.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              _buildTrainingCard(
                context,
                title: '도박중독 이해증진',
                description: '회복을 위해 도박중독에 잘 이해 하기 위한 노력은 중요합니다!',
                icon: Icons.psychology,
                color: const Color(0xFF5C72EB),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationDetailScreen(
                        title: '도박중독 이해증진',
                        summary: '회복을 위해 도박중독에 잘 이해 하기 위한 노력은 중요합니다!',
                        descriptionPoints: const [
                          '도박중독에 대한 올바른 이해는 ‘통제력 착각’, ‘도박기대’ 등 비합리적 신념을 줄여줍니다.',
                          '도박중독의 생물학적·심리학적 원인을 알게 되면 ‘의지 부족’이라는 자기비난이 줄고, 회복을 위한 치료적 실천을 위한 노력을 시작하는데 도움이 됩니다.',
                          '‘중독은 질병이다’라는 과학적 이해는 치료에 대한 저항감을 줄이고, 회복을 위한 구체적 실천을 돕습니다.',
                        ],
                        videoCategory: 'UNDERSTANDING',
                        allVideos: _videos,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              _buildTrainingCard(
                context,
                title: '정서조절 훈련',
                description: '정서조절 훈련을 통해 안정적인 회복을 유지할 수 있습니다!',
                icon: Icons.security,
                color: const Color(0xFF36CFC9), // Keeping consistent color with previous design if possible, or use distinctive
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationDetailScreen(
                        title: '정서조절 훈련',
                        summary: '정서조절 훈련을 통해 안정적인 회복을 유지할 수 있습니다!',
                        descriptionPoints: const [
                          '심호흡과 체계적 둔감화 훈련은 교감신경계 과활성 상태를 진정시켜 위기 상황에서의 감정폭발, 조급함, 불안 등의 생리적 반응을 낮춰, 도박 행동의 유발 가능성을 줄이는데 효과적입니다.',
                          '인지행동 훈련은 특정 감정이나 상황과 연결되어 있는 자동적 사고에 대한 인식을 증진하여 도박행동을 촉발하는 연결 고리를 찾아 원인을 제거하는데 효과적입니다.',
                          '훈련을 통해 호흡, 긴장완화, 시각화, 대체 활동 등을 반복 학습하면 위기상황에서 자동적으로 대안 행동을 실천할 수 있습니다.',
                        ],
                        videoCategory: 'IMPULSE',
                        allVideos: _videos,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              _buildTrainingCard(
                context,
                title: '건강한 대화 훈련',
                description: '건강한 대화 훈련은 관계 회복에 큰 도움이 됩니다!',
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFFFF851B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationDetailScreen(
                        title: '건강한 대화 훈련',
                        summary: '건강한 대화 훈련은 관계 회복에 큰 도움이 됩니다!',
                        descriptionPoints: const [
                          '효과적인 의사소통 기술은 사회적 지지망을 확장하는 데 필수적이며, 이는 회복 유지에 중요한 보호 요인입니다.',
                          '긍정적인 의사소통은 부정적 정서 조절과 부부/가족 간 갈등 완화에 기여하고, 재발 가능성을 낮추는 데 중요한 역할을 합니다.',
                          '자기 생각과 욕구를 명확히 전달할 수 있는 능력은 자아 존중감을 회복하고, 회피적·수동적 의사소통에서 벗어나 자기결정성을 강화하는 등, 회복 유지에 도움이 됩니다.',
                        ],
                        videoCategory: 'COMMUNICATION',
                        allVideos: _videos,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}

  Widget _buildTrainingCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[300], size: 16),
          ],
        ),
      ),
    );
  }
}
