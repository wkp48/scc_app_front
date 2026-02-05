import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../login/login.dart';
import '../utils/page_route_util.dart';
import '../utils/toast_utils.dart';
import 'notice_screen.dart';
import 'chatbot_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? dashboardData;

  const ProfileScreen({
    super.key,
    required this.userData,
    this.dashboardData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _profileImageUrl = widget.dashboardData?['profileImageUrl'];
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final response = await ApiService.uploadProfileImage(
        widget.userData['uid'], 
        image.path
      );

      if (response['success'] == true) {
        setState(() {
          _profileImageUrl = response['data'];
        });
        if (mounted) {
          ToastUtils.show(context, '프로필 사진이 변경되었습니다.');
        }
      } else {
        if (mounted) {
          ToastUtils.show(context, response['message'] ?? '업로드에 실패했습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, '오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auto_login');
    await prefs.remove('saved_password');
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        FadePageRoute(page: const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleWithdraw(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말로 탈퇴하시겠습니까?\n탈퇴 시 모든 활동 기록이 비활성화됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await ApiService.withdrawMember(widget.userData['uid']);
      if (response['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (context.mounted) {
          ToastUtils.show(context, '회원 탈퇴가 완료되었습니다.');
          Navigator.of(context).pushAndRemoveUntil(
            FadePageRoute(page: const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        if (context.mounted) {
          ToastUtils.show(context, response['message'] ?? '탈퇴 처리 중 오류가 발생했습니다.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String username = widget.dashboardData?['username'] ?? widget.userData['username'] ?? widget.userData['userid'];
    final String userid = widget.userData['userid'] ?? '';
    final String email = widget.userData['email'] ?? '';
    final String userType = widget.userData['userType'] ?? 'SUBJECT';
    String userTypeStr = '대상자';
    if (userType == 'FAMILY') userTypeStr = '가족';
    else if (userType == 'TEACHER') userTypeStr = '선생님';
    else if (userType == 'ADMIN') userTypeStr = '관리자';

    String? detailInfo;
    String detailLabel = '관계';
    
    if (userType == 'SUBJECT') {
      detailLabel = '담당 선생님';
      detailInfo = widget.dashboardData?['counselorName'] ?? '미배정';
    } else if (userType == 'FAMILY') {
      detailLabel = '관계';
      detailInfo = widget.userData['relationship'];
    } else {
      detailLabel = '계정 권한';
      detailInfo = userType == 'ADMIN' ? '시스템 관리자' : '상담 선생님';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('내 정보', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 프로필 헤더
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              color: Colors.white,
              width: double.infinity,
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _isUploading
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                              : _profileImageUrl != null
                                  ? FutureBuilder<String>(
                                      future: ApiService.baseUrl,
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.network(
                                            '${snapshot.data}/activities/images/$_profileImageUrl',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => 
                                                const Icon(Icons.person, size: 60, color: Colors.grey),
                                          );
                                        }
                                        return const Icon(Icons.person, size: 60, color: Colors.grey);
                                      },
                                    )
                                  : const Icon(Icons.person, size: 60, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF5C72EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: userType == 'ADMIN' 
                        ? const Color(0xFFFFF1F0) 
                        : (userType == 'TEACHER' ? const Color(0xFFF0F5FF) : const Color(0xFFF5F5F5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: userType == 'ADMIN' 
                          ? const Color(0xFFFFCCC7) 
                          : (userType == 'TEACHER' ? const Color(0xFFADC6FF) : const Color(0xFFE8E8E8)),
                      ),
                    ),
                    child: Text(
                      userTypeStr,
                      style: TextStyle(
                        color: userType == 'ADMIN' 
                          ? const Color(0xFFFF4D4F) 
                          : (userType == 'TEACHER' ? const Color(0xFF2F54EB) : Colors.grey[700]),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 상세 정보 리스트
            _buildInfoSection([
              _buildInfoTile('아이디', userid),
              _buildInfoTile('이메일', email),
              _buildInfoTile(detailLabel, detailInfo ?? '정보 없음'),
            ]),

            const SizedBox(height: 12),
            // 고객센터 섹션
            _buildInfoSection([
              ListTile(
                title: const Text('공지사항', style: TextStyle(color: Colors.black87)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.of(context).push(
                    FadePageRoute(page: const NoticeScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 12),
            // 앱 설정 섹션
            _buildSectionHeader('앱 설정'),
            _buildInfoSection([
              ListTile(
                title: const Text('권한 설정', style: TextStyle(color: Colors.black87)),
                subtitle: const Text('알림, 카메라, 마이크 등 권한 관리', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showPermissionSettings(context),
              ),
            ]),
            const SizedBox(height: 12),
            // 계정 관리 섹션
            _buildSectionHeader('계정 관리'),
            _buildInfoSection([
              ListTile(
                title: const Text('로그아웃', style: TextStyle(color: Colors.black87)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _handleLogout(context),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('회원 탈퇴', style: TextStyle(color: Colors.redAccent)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.redAccent),
                onTap: () => _handleWithdraw(context),
              ),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showPermissionSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '권한 설정',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildPermissionTile(
                  icon: Icons.notifications_none,
                  title: '알림',
                  permission: Permission.notification,
                  setModalState: setModalState,
                ),
                _buildPermissionTile(
                  icon: Icons.camera_alt_outlined,
                  title: '카메라',
                  permission: Permission.camera,
                  setModalState: setModalState,
                ),
                _buildPermissionTile(
                  icon: Icons.photo_library_outlined,
                  title: '사진첩',
                  permission: Permission.photos,
                  setModalState: setModalState,
                ),
                _buildPermissionTile(
                  icon: Icons.mic_none,
                  title: '마이크',
                  permission: Permission.speech,
                  setModalState: setModalState,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('기기 설정으로 이동'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openAppSettings(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required Permission permission,
    required StateSetter setModalState,
  }) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? PermissionStatus.denied;
        final bool isGranted = status.isGranted;

        return ListTile(
          leading: Icon(icon, color: Colors.black87),
          title: Text(title),
          trailing: Text(
            isGranted ? '허용됨' : '거부됨',
            style: TextStyle(
              color: isGranted ? Colors.blue : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            if (!isGranted) {
              final newStatus = await permission.request();
              setModalState(() {});
            } else {
              // 이미 허용된 경우 안내
              ToastUtils.show(context, '이미 허용된 권한입니다.');
            }
          },
        );
      },
    );
  }

  Widget _buildInfoSection(List<Widget> children) {
    return Container(
      color: Colors.white,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        ],
      ),
    );
  }
}
