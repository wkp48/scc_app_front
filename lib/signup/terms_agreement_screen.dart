import 'package:flutter/material.dart';
import 'terms_text.dart';
import 'signup_sub.dart';
import 'signup_fam.dart';
import '../utils/page_route_util.dart';

class TermsAgreementScreen extends StatefulWidget {
  final String userType; // 'SUBJECT' or 'FAMILY'

  const TermsAgreementScreen({super.key, required this.userType});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _allAgreed = false;
  bool _serviceTermsAgreed = false;
  bool _privacyPolicyAgreed = false;
  bool _sensitiveDataAgreed = false;

  void _updateAllAgreed() {
    setState(() {
      _allAgreed = _serviceTermsAgreed && _privacyPolicyAgreed && _sensitiveDataAgreed;
    });
  }

  void _onAllAgreedChange(bool? value) {
    bool newValue = value ?? false;
    setState(() {
      _allAgreed = newValue;
      _serviceTermsAgreed = newValue;
      _privacyPolicyAgreed = newValue;
      _sensitiveDataAgreed = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('약관 동의', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '서비스 이용을 위해\n약관에 동의해주세요.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 48),
              
              // 전체 동의
              _buildAllAgreementTile(),
              
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF0F0F0)),
              const SizedBox(height: 12),
              
              // 개별 동의 사항
              Expanded(
                child: ListView(
                  children: [
                    _buildAgreementItem(
                      title: '[필수] 서비스 이용약관 동의',
                      content: TermsText.serviceTermsContent,
                      value: _serviceTermsAgreed,
                      onChanged: (val) {
                        setState(() => _serviceTermsAgreed = val!);
                        _updateAllAgreed();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildAgreementItem(
                      title: '[필수] 개인정보 수집 및 이용 동의',
                      content: TermsText.privacyPolicyContent,
                      value: _privacyPolicyAgreed,
                      onChanged: (val) {
                        setState(() => _privacyPolicyAgreed = val!);
                        _updateAllAgreed();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildAgreementItem(
                      title: '[필수] 민감정보 처리 동의',
                      content: TermsText.sensitiveDataConsentContent,
                      value: _sensitiveDataAgreed,
                      onChanged: (val) {
                        setState(() => _sensitiveDataAgreed = val!);
                        _updateAllAgreed();
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _allAgreed ? () {
                    if (widget.userType == 'SUBJECT') {
                      Navigator.of(context).pushReplacement(
                        SlidePageRoute(page: const SignupSubScreen()),
                      );
                    } else {
                      Navigator.of(context).pushReplacement(
                        SlidePageRoute(page: const SignupFamScreen()),
                      );
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF9D),
                    disabledBackgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _allAgreed ? Colors.black : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllAgreementTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _allAgreed ? const Color(0xFFE8FAF4) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _allAgreed ? const Color(0xFF09E89E) : Colors.transparent,
        ),
      ),
      child: CheckboxListTile(
        title: const Text(
          '전체 동의하기',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        value: _allAgreed,
        onChanged: _onAllAgreedChange,
        activeColor: const Color(0xFF09E89E),
        checkColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildAgreementItem({
    required String title,
    required String content,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF09E89E),
                checkColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              onPressed: () => _showFullTerms(title, content),
            ),
          ],
        ),
      ],
    );
  }

  void _showFullTerms(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
