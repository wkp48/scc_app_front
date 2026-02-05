import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialUtil {
  static const String _tutorialShownKey = 'tutorial_shown_v1';

  static Future<void> checkAndShowTutorial(
    BuildContext context, {
    required List<TargetFocus> targets,
    Function()? onFinish,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isShown = prefs.getBool(_tutorialShownKey) ?? false;

    if ((!isShown || force) && targets.isNotEmpty) {
      // 약간의 지연 후 튜토리얼 실행 (화면 렌더링 완료 대기)
      // ignore: use_build_context_synchronously
      if(!context.mounted) return;
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if(!context.mounted) return;
        
        TutorialCoachMark(
          targets: targets,
          colorShadow: Colors.black, // 배경색 색상
          textSkip: "건너뛰기",
          paddingFocus: 10,
          opacityShadow: 0.8,
          onFinish: () {
            prefs.setBool(_tutorialShownKey, true);
            if (onFinish != null) onFinish();
          },
          onSkip: () {
            prefs.setBool(_tutorialShownKey, true); // 건너뛰어도 본 것으로 처리
            return true;
          },
        ).show(context: context);
      });
    }
  }

  static TargetFocus createTarget({
    required String identify,
    required GlobalKey key,
    required String title,
    required String description,
    ContentAlign align = ContentAlign.bottom,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: key,
      alignSkip: Alignment.topRight,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
      shape: shape,
      radius: 5,
    );
  }
}
