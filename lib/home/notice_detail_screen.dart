import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../services/api_service.dart';

class NoticeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchBaseUrl();
  }

  Future<void> _fetchBaseUrl() async {
    final url = await ApiService.baseUrl;
    if (mounted) {
      setState(() {
        _baseUrl = url;
      });
    }
  }

  // Image URL helper (duplicated safely from NoticeScreen)
  String _getImageUrl(String path) {
    String url;
    if (path.startsWith('http')) {
      url = path;
    } else if (_baseUrl == null) {
      url = path;
    } else {
      if (_baseUrl!.endsWith('/api') && path.startsWith('/api')) {
        url = _baseUrl!.substring(0, _baseUrl!.length - 4) + path;
      } else if (!path.startsWith('/')) {
        url = '$_baseUrl/$path';
      } else {
        url = '$_baseUrl$path';
      }
    }
    return Uri.encodeFull(url);
  }

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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    bool isDataUri = false;
    String imageUrl = '';
    if (notice['imageUrl'] != null && notice['imageUrl'].toString().isNotEmpty) {
      imageUrl = notice['imageUrl'].toString();
      isDataUri = imageUrl.startsWith('data:image');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('공지사항 상세', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice['title'] ?? '제목 없음',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(notice['createAt'] ?? notice['createdAt']),
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const Divider(height: 32),
              if (imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                style: const TextStyle(color: Colors.black87, height: 1.6, fontSize: 16),
              ),
              if (notice['linkUrl'] != null && notice['linkUrl'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: InkWell(
                    onTap: () => _launchUrl(notice['linkUrl']),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
