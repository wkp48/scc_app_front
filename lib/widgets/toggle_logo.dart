import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToggleLogo extends StatelessWidget {
  final AnimationController? animationController;
  final AnimationController pulseController;
  final bool isStatic; 
  final bool showText; // 텍스트 표시 여부
  final double switchScale; // 스위치 크기 비율
  final Color onTextColor; // ON 텍스트 색상
  final Color dayTextColor; // DAY 텍스트 색상

  const ToggleLogo({
    super.key,
    this.animationController,
    required this.pulseController,
    this.isStatic = false,
    this.showText = true,
    this.switchScale = 1.0, // 기본값 1.0 (원본 크기)
    this.onTextColor = const Color(0xFF4A4A4A), // 기본값: 다크 그레이
    this.dayTextColor = const Color(0xFF4A4A4A), // 기본값: 다크 그레이
  });

  @override
  Widget build(BuildContext context) {
    // isStatic이 true이면 항상 1.0 (최종 상태)을 유지하는 더미 애니메이션 사용
    final toggleValue = isStatic ? 1.0 : (animationController?.value ?? 0.0);
    
    final toggleAnimation = animationController != null 
        ? CurvedAnimation(
            parent: animationController!,
            curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
          )
        : null;

    final textOpacity = isStatic ? 1.0 : (animationController != null 
        ? CurvedAnimation(
            parent: animationController!,
            curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
          ).value
        : 0.0);

    final displayToggleValue = isStatic ? 1.0 : (toggleAnimation?.value ?? 0.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 토글 스위치 부분
        Container(
          width: 200 * switchScale,
          height: 85 * switchScale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42.5 * switchScale),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE8E8E8), // OFF 배경
                Color.lerp(const Color(0xFFE8E8E8), const Color(0xFF1FB5BA), displayToggleValue)!,
                const Color(0xFF1FB5BA), // ON 배경
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // OFF 텍스트
              Positioned(
                left: 20 * switchScale,
                child: Opacity(
                  opacity: (1.0 - displayToggleValue).clamp(0.3, 1.0),
                  child: Text(
                    'OFF',
                    style: TextStyle(
                      color: const Color(0xFF999999),
                      fontSize: 22 * switchScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // ON 텍스트
              Positioned(
                right: 30 * switchScale,
                child: Opacity(
                  opacity: displayToggleValue,
                  child: Text(
                    'ON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22 * switchScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // 펄스 효과
              Align(
                alignment: Alignment.lerp(
                  const Alignment(-0.95, 0.0),
                  const Alignment(1.00, 0.0),
                  displayToggleValue,
                )!,
                child: AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, child) {
                    final isVisible = displayToggleValue > 0.99;
                    return Opacity(
                      opacity: isVisible ? (1.0 - pulseController.value) * 0.5 : 0.0,
                      child: Transform.scale(
                        scale: 1.0 + (pulseController.value * 0.35),
                        child: Container(
                          width: 83 * switchScale,
                          height: 83 * switchScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF8B5A),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 썸 (움직이는 원)
              Align(
                alignment: Alignment.lerp(
                  const Alignment(-0.95, 0.0),
                  const Alignment(1.00, 0.0),
                  displayToggleValue,
                )!,
                child: Container(
                  width: 83 * switchScale,
                  height: 83 * switchScale,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8B5A), Color(0xFFF57242)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: displayToggleValue,
                      child: Text(
                        'ON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22 * switchScale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(height: 25 * switchScale), // 간격 소폭 축소
          // 하단 텍스트 부분
          Opacity(
            opacity: textOpacity,
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 60 * switchScale,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Arial Black',
                      letterSpacing: 2,
                    ),
                    children: [
                      TextSpan(text: 'ON', style: TextStyle(color: onTextColor)),
                      const WidgetSpan(
                        child: SizedBox(width: 10),
                      ),
                      TextSpan(text: ': DAY', style: TextStyle(color: dayTextColor)), 
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.gaegu(
                      fontSize: 28 * switchScale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 1,
                    ),
                    children: [
                      const TextSpan(text: '일상으로 다시,'), 
                      TextSpan(
                        text: '온',
                        style: GoogleFonts.gaegu(
                          fontSize: 38 * switchScale,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
