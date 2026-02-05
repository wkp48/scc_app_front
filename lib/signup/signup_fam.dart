import 'package:flutter/material.dart';
import 'signup_complete_check.dart';
import '../services/api_service.dart';
import '../utils/page_route_util.dart';
import '../utils/toast_utils.dart';

class SignupFamScreen extends StatefulWidget {
  const SignupFamScreen({super.key});

  @override
  State<SignupFamScreen> createState() => _SignupFamScreenState();
}

class _SignupFamScreenState extends State<SignupFamScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  final TextEditingController _familyRelationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // 생년월일 선택용 변수들
  int _selectedYear = 1990;
  int _selectedMonth = 1;
  int _selectedDay = 1;
  
  // 성별 선택 변수
  String? _selectedGender;
  String? _genderError;

  bool _isIdAvailable = false;
  bool _isLoading = false;
  
  // 중복 확인 상태 변수들
  bool _isIdChecked = false;
  bool _isIdDuplicate = false;
  bool _isEmailChecked = false;
  bool _isEmailDuplicate = false;
  
  // 폼 검증을 위한 변수들
  String? _nameError;
  String? _idError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _birthError;
  String? _familyRelationError;
  String? _phoneError;

  // 비밀번호 가시성 상태 변수
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _updateBirthText(); // 초기값 설정
    
    // 전화번호 자동 포맷팅 리스너 추가
    _phoneController.addListener(() {
      _formatPhoneNumber();
    });
  }

  void _updateBirthText() {
    _birthController.text = "${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}";
  }

  // 전화번호 자동 포맷팅 함수
  void _formatPhoneNumber() {
    final text = _phoneController.text;
    final cleanedText = text.replaceAll(RegExp(r'[^\d]'), ''); // 숫자만 남기기
    
    if (cleanedText.length <= 3) {
      _phoneController.value = TextEditingValue(
        text: cleanedText,
        selection: TextSelection.collapsed(offset: cleanedText.length),
      );
    } else if (cleanedText.length <= 7) {
      _phoneController.value = TextEditingValue(
        text: '${cleanedText.substring(0, 3)}-${cleanedText.substring(3)}',
        selection: TextSelection.collapsed(offset: cleanedText.length + 1),
      );
    } else {
      _phoneController.value = TextEditingValue(
        text: '${cleanedText.substring(0, 3)}-${cleanedText.substring(3, 7)}-${cleanedText.substring(7, 11)}',
        selection: TextSelection.collapsed(offset: cleanedText.length + 2),
      );
    }
  }

  bool _validatePhone(String phone) {
    if (phone.isEmpty) {
      _phoneError = "전화번호를 입력해주세요";
      return false;
    }
    // 하이픈 제거 후 숫자만 검사
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedPhone.length < 10 || cleanedPhone.length > 11) {
      _phoneError = "올바른 전화번호를 입력해주세요";
      return false;
    }
    _phoneError = null;
    return true;
  }

  // 폼 검증 함수들
  bool _validateName(String name) {
    if (name.isEmpty) {
      _nameError = "이름을 입력해주세요";
      return false;
    } else if (name.length < 2) {
      _nameError = "이름은 2자 이상 입력해주세요";
      return false;
    }
    _nameError = null;
    return true;
  }

  bool _validateId(String id) {
    if (id.isEmpty) {
      _idError = "아이디를 입력해주세요";
      return false;
    } else if (id.length < 4) {
      _idError = "아이디는 4자 이상 입력해주세요";
      return false;
    } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      _idError = "아이디는 영문과 숫자만 사용 가능합니다";
      return false;
    }
    _idError = null;
    return true;
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) {
      _emailError = "이메일을 입력해주세요";
      return false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _emailError = "올바른 이메일 형식을 입력해주세요";
      return false;
    }
    _emailError = null;
    return true;
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _passwordError = "비밀번호를 입력해주세요";
      return false;
    } else if (password.length < 4 || password.length > 16) {
      _passwordError = "비밀번호는 4~16자리로 입력해주세요";
      return false;
    } else if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)[a-zA-Z\d!@#$%^&*(),.?":{}|<>]+$').hasMatch(password)) {
      _passwordError = "영문과 숫자를 조합해주세요";
      return false;
    }
    _passwordError = null;
    return true;
  }

  bool _validateConfirmPassword(String confirmPassword) {
    if (confirmPassword.isEmpty) {
      _confirmPasswordError = "비밀번호 확인을 입력해주세요";
      return false;
    } else if (confirmPassword != _passwordController.text) {
      _confirmPasswordError = "비밀번호가 일치하지 않습니다";
      return false;
    }
    _confirmPasswordError = null;
    return true;
  }

  bool _validateBirth() {
    DateTime birthDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (birthDate.isAfter(now)) {
      _birthError = "미래 날짜는 선택할 수 없습니다";
      return false;
    } else if (age < 10) {
      _birthError = "10세 이상만 가입 가능합니다";
      return false;
    }
    _birthError = null;
    return true;
  }

  bool _validateGender() {
    if (_selectedGender == null) {
      _genderError = "성별을 선택해주세요";
      return false;
    }
    _genderError = null;
    return true;
  }

  bool _validateFamilyRelation(String familyRelation) {
    if (familyRelation.isEmpty) {
      _familyRelationError = "가족 관계를 입력해주세요";
      return false;
    }
    _familyRelationError = null;
    return true;
  }


  bool _validateForm() {
    bool isValid = true;
    
    // 기본 필드 검증
    isValid &= _validateName(_nameController.text);
    isValid &= _validateId(_idController.text);
    isValid &= _validateEmail(_emailController.text);
    isValid &= _validatePassword(_passwordController.text);
    isValid &= _validateConfirmPassword(_confirmPasswordController.text);
    isValid &= _validateBirth();
    isValid &= _validateFamilyRelation(_familyRelationController.text);
    isValid &= _validateGender();
    isValid &= _validatePhone(_phoneController.text);
    
    // 아이디 중복 확인 체크
    if (!_isIdChecked) {
      _idError = "아이디 중복 확인이 필요합니다";
      isValid = false;
    } else if (_isIdDuplicate) {
      _idError = "이미 사용 중인 아이디입니다";
      isValid = false;
    } else if (!_isIdAvailable) {
      _idError = "사용할 수 없는 아이디입니다";
      isValid = false;
    }

    // 이메일 인증 체크
    if (_isEmailDuplicate) {
      _emailError = "이미 가입된 이메일입니다";
      isValid = false;
    }
    
    setState(() {});
    return isValid;
  }


  void _showDateSelector() {
    final yearController = FixedExtentScrollController(initialItem: _selectedYear - 1960);
    final monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
    final dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 상단 바
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 제목
                const Text(
                  '생년월일 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                
                // 날짜 선택기
                Expanded(
                  child: Row(
                    children: [
                      // 년도 선택
                      Expanded(
                        child: _buildScrollSelector(
                          items: List.generate(DateTime.now().year - 1960 + 1, (index) => 1960 + index),
                          selectedValue: _selectedYear,
                          controller: yearController,
                          onChanged: (value) {
                            setModalState(() {
                              _selectedYear = value;
                            });
                            setState(() {
                              _updateBirthText();
                            });
                          },
                          label: '년',
                          highlightColor: Colors.blue,
                        ),
                      ),
                      
                      // 월 선택
                      Expanded(
                        child: _buildScrollSelector(
                          items: List.generate(12, (index) => index + 1),
                          selectedValue: _selectedMonth,
                          controller: monthController,
                          onChanged: (value) {
                            setModalState(() {
                              _selectedMonth = value;
                            });
                            setState(() {
                              _updateBirthText();
                            });
                          },
                          label: '월',
                          highlightColor: Colors.blue,
                        ),
                      ),
                      
                      // 일 선택
                      Expanded(
                        child: _buildScrollSelector(
                          items: _getDaysInMonth(_selectedYear, _selectedMonth),
                          selectedValue: _selectedDay,
                          controller: dayController,
                          onChanged: (value) {
                            setModalState(() {
                              _selectedDay = value;
                            });
                            setState(() {
                              _updateBirthText();
                            });
                          },
                          label: '일',
                          highlightColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 확인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<int> _getDaysInMonth(int year, int month) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (index) => index + 1);
  }

  Widget _buildScrollSelector({
    required List<int> items,
    required int selectedValue,
    required Function(int) onChanged,
    required String label,
    FixedExtentScrollController? controller,
    Color highlightColor = const Color(0xFF09E89E),
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              onChanged(items[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: items.length,
              builder: (context, index) {
                final isSelected = items[index] == selectedValue;
                return Container(
                  alignment: Alignment.center,
                  child: Text(
                    items[index].toString(),
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? highlightColor : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthController.dispose();
    _familyRelationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '정보를 입력해주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '모든 항목은 필수 입력 사항입니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // 이메일 입력
              _buildEmailField(),
              const SizedBox(height: 24),

              // 성별 선택
              _buildGenderSelector(),
              const SizedBox(height: 24),

              // 전화번호 입력
              _buildPhoneField(),
              const SizedBox(height: 24),

              // 이름 입력
              _buildInputField(
                '이름', 
                _nameController, 
                errorText: _nameError,
                onChanged: (value) => setState(() => _validateName(value)),
              ),
              const SizedBox(height: 24),

              // 아이디 입력
              _buildIdField(),
              const SizedBox(height: 24),

              // 비밀번호 입력
              _buildPasswordField(),
              const SizedBox(height: 24),

              // 비밀번호 확인 입력
              _buildConfirmPasswordField(),
              const SizedBox(height: 24),

              // 생년월일 입력
              _buildBirthField(),
              const SizedBox(height: 24),

              // 가족 관계 입력
              _buildInputField(
                '가족 관계', 
                _familyRelationController, 
                errorText: _familyRelationError,
                onChanged: (value) => setState(() => _validateFamilyRelation(value)),
              ),
              const SizedBox(height: 48),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    if (_validateForm()) {
                      try {
                        setState(() {
                          _isLoading = true;
                        });
                        
                        final response = await ApiService.signupFamily(
                          _nameController.text,
                          _idController.text,
                          _emailController.text,
                          _passwordController.text,
                          _familyRelationController.text,
                          null,
                          _phoneController.text,
                          _selectedGender,
                        );

                        setState(() {
                          _isLoading = false;
                        });

                        if (response['success'] == true) {
                          Navigator.of(context).pushReplacement(
                            FadePageRoute(
                              page: SignupCompleteCheckScreen(
                                userName: _nameController.text,
                                userType: '가족',
                                userid: _idController.text,
                                email: _emailController.text,
                                birthDate: _birthController.text,
                                teacherName: '가족 회원',
                              ),
                            ),
                          );
                        } else {
                          ToastUtils.show(context, response['message'] ?? '회원가입에 실패했습니다');
                        }
                      } catch (e) {
                        setState(() {
                          _isLoading = false;
                        });
                        ToastUtils.show(context, '회원가입 중 오류가 발생했습니다');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF9D), // 형광초록
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? errorText, TextInputType? keyboardType, bool obscureText = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: errorText != null ? Border.all(color: Colors.red, width: 1) : null,
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 15),
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),
        if (errorText != null) 
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(errorText, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('아이디'),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: _idError != null ? Border.all(color: Colors.red, width: 1) : null,
                ),
                child: TextField(
                  controller: _idController,
                  style: const TextStyle(fontSize: 15),
                  onChanged: (value) {
                    setState(() {
                      _isIdChecked = false;
                      _isIdAvailable = false;
                      _isIdDuplicate = false;
                      _validateId(value);
                    });
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildCheckButton(
              onPressed: () async {
                if (_idController.text.isNotEmpty && _validateId(_idController.text)) {
                  final response = await ApiService.checkUserId(_idController.text);
                  setState(() {
                    _isIdChecked = true;
                    if (response['success'] == true && response['data'] == true) {
                      _isIdAvailable = true;
                      _isIdDuplicate = false;
                    } else {
                      _isIdAvailable = false;
                      _isIdDuplicate = true;
                    }
                  });
                } else {
                  ToastUtils.show(context, '아이디를 입력해주세요');
                }
              },
              text: '중복확인',
            ),
          ],
        ),
        if (_isIdChecked)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              _isIdAvailable ? '사용 가능한 아이디입니다' : '이미 사용 중인 아이디입니다',
              style: TextStyle(color: _isIdAvailable ? Colors.blue : Colors.red, fontSize: 12),
            ),
          )
        else if (_idError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_idError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('이메일'),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: _emailError != null ? Border.all(color: Colors.red, width: 1) : null,
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15),
                  onChanged: (value) {
                    setState(() {
                      _isEmailChecked = false;
                      _isEmailDuplicate = false;
                      _validateEmail(value);
                    });
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildCheckButton(
              onPressed: () async {
                if (_emailController.text.isNotEmpty && _validateEmail(_emailController.text)) {
                  final response = await ApiService.checkEmail(_emailController.text);
                  setState(() {
                    _isEmailChecked = true;
                    _isEmailDuplicate = response['success'] != true || response['data'] != true;
                  });
                } else {
                  ToastUtils.show(context, '이메일을 입력해주세요');
                }
              },
              text: '중복확인',
            ),
          ],
        ),
        if (_isEmailChecked)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              !_isEmailDuplicate ? '사용 가능한 이메일입니다' : '이미 사용 중인 이메일입니다',
              style: TextStyle(color: !_isEmailDuplicate ? Colors.blue : Colors.red, fontSize: 12),
            ),
          )
        else if (_emailError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('성별'),
        Row(
          children: [
            Expanded(child: _buildGenderButton('남성', 'MALE')),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderButton('여성', 'FEMALE')),
          ],
        ),
        if (_genderError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_genderError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildGenderButton(String text, String value) {
    final bool isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF9D) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: const Color(0xFF00FF9D), width: 1.5) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckButton({required VoidCallback onPressed, required String text}) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF9D),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('비밀번호'),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: _passwordError != null ? Border.all(color: Colors.red, width: 1) : null,
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(fontSize: 15),
            onChanged: (value) => setState(() => _passwordError = _validatePassword(value) ? null : _passwordError),
            decoration: InputDecoration(
              hintText: '4 ~ 16자리 영문, 숫자 조합',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
        ),
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_passwordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('비밀번호 확인'),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: _confirmPasswordError != null ? Border.all(color: Colors.red, width: 1) : null,
          ),
          child: TextField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            style: const TextStyle(fontSize: 15),
            onChanged: (value) => setState(() => _confirmPasswordError = value != _passwordController.text ? "비밀번호가 일치하지 않습니다" : null),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              suffixIcon: IconButton(
                icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              ),
            ),
          ),
        ),
        if (_confirmPasswordError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_confirmPasswordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('전화번호'),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: _phoneError != null ? Border.all(color: Colors.red, width: 1) : null,
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 15),
            onChanged: (value) => setState(() => _validatePhone(value)),
            decoration: InputDecoration(
              hintText: '010-1234-5678',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_phoneError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildBirthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('생년월일'),
        GestureDetector(
          onTap: _showDateSelector,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: _birthError != null ? Border.all(color: Colors.red, width: 1) : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthController.text.isEmpty ? '생년월일을 선택해주세요' : _birthController.text,
                    style: TextStyle(
                      color: _birthController.text.isEmpty ? Colors.grey[400] : Colors.black,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
        if (_birthError != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(_birthError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}
