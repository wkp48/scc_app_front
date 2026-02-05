import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; // Added for base64Decode
import 'notice_create_modal.dart';

class NoticeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const NoticeScreen({super.key, this.userData});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  bool _isLoading = true;
  List<dynamic> _notices = [];
  String? _baseUrl;

  // Helper to launch URL
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('링크를 열 수 없습니다.')),
         );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBaseUrl();
    _fetchNotices();
  }

  Future<void> _fetchBaseUrl() async {
    final url = await ApiService.baseUrl;
    if (mounted) {
      setState(() {
        _baseUrl = url;
      });
    }
  }

  Future<void> _fetchNotices() async {
    if (!mounted) return;
    
    // Initial fetch
    final result = await ApiService.getNotices();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _notices = result['data'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '공지사항을 불러오질 못했습니다.')),
          );
        }
      });
    }
  }

  // Image URL helper to handle relative paths from backend
  String _getImageUrl(String path) {
    String url;
    if (path.startsWith('http')) {
      url = path; // Already absolute URL
    } else if (_baseUrl == null) {
      url = path;
    } else {
      // Handle duplicate /api prefix
      // _baseUrl usually ends with /api (e.g., http://host:port/api)
      // path from backend usually starts with /api (e.g., /api/notices/images/...)
      if (_baseUrl!.endsWith('/api') && path.startsWith('/api')) {
        url = _baseUrl!.substring(0, _baseUrl!.length - 4) + path;
      } else if (!path.startsWith('/')) {
        url = '$_baseUrl/$path';
      } else {
        url = '$_baseUrl$path';
      }
    }
    
    // Encode the URL to handle special characters (e.g., Korean filenames)
    // Note: If using Image.network, it parses URI. But if path has spaces, encoding helps.
    final encoded = Uri.encodeFull(url);
    // print('[DEBUG] Notice Image URL: original=$path, full=$url, encoded=$encoded'); 
    return encoded;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  bool _isRecent(dynamic notice) {
    final dateStr = notice['createAt'] ?? notice['createdAt'];
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr.toString());
      final difference = DateTime.now().difference(date);
      // Allow for up to 1 day in the "future" to account for clock sync issues
      return (difference.inDays <= 7 && difference.inDays >= -1);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('공지사항', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.userData?['userType'] == 'ADMIN' || widget.userData?['userType'] == 'TEACHER')
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF5C72EB)),
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const NoticeCreateModal(),
                );
                if (result == true) {
                  _fetchNotices();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? const Center(
                  child: Text('등록된 공지사항이 없습니다.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notice = _notices[index];
                    return _buildNoticeCard(notice);
                  },
                ),
    );
  }

  Widget _buildNoticeCard(dynamic notice) {
    bool isDataUri = false;
    String imageUrl = '';
    if (notice['imageUrl'] != null && notice['imageUrl'].toString().isNotEmpty) {
      imageUrl = notice['imageUrl'].toString();
      isDataUri = imageUrl.startsWith('data:image');
    }

    final bool recent = _isRecent(notice);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  notice['title'] ?? '제목 없음',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (recent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D4F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _formatDate(notice['createdAt']),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (imageUrl.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 16),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: isDataUri
                           ? Image.memory(
                               base64Decode(imageUrl.split(',').last),
                               width: double.infinity,
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) => 
                                 const SizedBox(height: 100, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                             )
                           : Image.network(
                               _getImageUrl(imageUrl),
                               width: double.infinity,
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) => 
                                 const SizedBox(height: 100, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                             ),
                       ),
                     ),
                  Text(
                    notice['content'] ?? '',
                    style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 15),
                  ),
                  if (notice['linkUrl'] != null && notice['linkUrl'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: InkWell(
                        onTap: () => _launchUrl(notice['linkUrl']),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: Color(0xFF5C72EB), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notice['linkUrl'],
                                style: const TextStyle(
                                  color: Color(0xFF5C72EB),
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
