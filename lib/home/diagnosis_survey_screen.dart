import 'package:flutter/material.dart';
import '../onboarding/diagnosis_step.dart';

class DiagnosisSurveyScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const DiagnosisSurveyScreen({Key? key, required this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DiagnosisStep(
      userData: userData,
      onNext: () {
        Navigator.pop(context, true);
      },
      onPrevious: () {
        Navigator.pop(context);
      },
    );
  }
}
