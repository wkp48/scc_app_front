import 'package:flutter/material.dart';
import 'family_training_detail_screen.dart';

class TrainingScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const TrainingScreen({Key? key, required this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '셀프 트레이닝',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '나와 가족을 지키는 힘, 오늘 하루도 연습해보세요.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          
          _buildTrainingCard(
            context,
            title: '도박중독 이해증진',
            description: '도박중독의 메커니즘을 이해하고\n회복을 위한 기초 지식 쌓기',
            icon: Icons.psychology_outlined,
            color: const Color(0xFF5C72EB),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyTrainingDetailScreen(
                 title: '도박중독 이해증진',
                 category: 'FAMILY_UNDERSTANDING',
                 descriptions: [
                   '도박중독을 ‘의지 문제’나 ‘성격 문제’가 아닌 뇌의 보상회로와 충동조절 문제라는 걸 이해하면, 비난보다 공감으로 반응할 수 있어 자기소진이 줄어듭니다.',
                   '도박중독에 대한 이해가 높을수록, 가족은 통제나 감시 대신, 회복 친화적인 행동을 선택하게 됩니다.',
                   '중독을 ‘가족의 책임’으로 오해하면, 과잉개입 또는 과방임으로 흐르기 쉽습니다. 이해가 깊을수록, 도박자와 가족의 심리적 경계를 건강하게 설정할 수 있게 됩니다.',
                 ],
               )));
            },
          ),
          const SizedBox(height: 16),
          
          _buildTrainingCard(
            context,
            title: '정서 안정 훈련',
            description: '불안과 스트레스를 관리하고\n정서적 평온을 되찾는 훈련',
            icon: Icons.spa_outlined,
            color: const Color(0xFF13C2C2),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyTrainingDetailScreen(
                 title: '정서 안정 훈련',
                 category: 'FAMILY_STABILITY',
                 descriptions: [
                   '도박중독자 가족은 오랜 정서적 스트레스로 신체 증상을 겪기 쉬우며, 호흡법과 이완기법은 긴장을 줄이고 몸의 회복을 돕는 데 효과적입니다.',
                   '인지행동 훈련은 특정 감정이나 상황과 연결되어 있는 자동적 사고에 대한 인식을 증진하여 불안을 촉발하는 연결 고리를 찾아 원인을 제거하는데 효과적입니다.', 
                   '감정 조절이 어려우면 가족은 무력감에 빠지기 쉽지만, 자기조절 기술을 익히면 감정을 다룰 수 있다는 자신감이 생기고, 회복을 견디는 힘도 함께 자라납니다.',
                 ],
               )));
            },
          ),
          const SizedBox(height: 16),
          
          _buildTrainingCard(
            context,
            title: '건강한 대화 훈련',
            description: '비난 대신 공감을 표현하고\n건강한 경계를 설정하는 대화식',
            icon: Icons.forum_outlined,
            color: const Color(0xFFFA8C16),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyTrainingDetailScreen(
                 title: '건강한 대화 훈련',
                 category: 'FAMILY_COMMUNICATION',
                 descriptions: [
                   '도박중독 상황에서는 가족 대화가 비난, 추궁, 침묵으로 흐르기 쉬워 갈등이 고조되고 정서적 불안이 반복됩니다. 공감적 소통을 배우면 방어가 줄고 정서적 안정이 높아집니다.',
                   '긍정적인 의사소통은 부정적 정서 조절과 부부/가족 간 갈등 완화에 기여하고, 재발 가능성을 낮추는 데 중요한 역할을 합니다.',
                   '많은 가족들이 중독자 앞에서 자신의 감정을 억누르거나, 반대로 감정 폭발을 경험합니다. 대화 기술을 배우면 “나는 지금 이런 감정을 느낀다”는 식의 자기표현과 심리적 경계 설정이 가능해져, 자기돌봄도 더 수월해집니다.',
                 ],
               )));
            },
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
