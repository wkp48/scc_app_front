
import 'package:flutter/material.dart';

class ChecklistStyleCard extends StatelessWidget {
  final VoidCallback onTap;

  const ChecklistStyleCard({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        width: double.infinity,
        height: 80,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Blue vertical strip on the left
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6, // Thickness of the blue strip
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C72EB), // Primary blue color
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 20), // Left padding adjusted for strip
                child: Row(
                  children: [
                    // Icon Circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF), // Light blue bg
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.assignment_turned_in_rounded, // Checklist icon
                          color: Color(0xFF5C72EB),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Text
                    Expanded(
                      child: const Text(
                        '오늘의 마음 점검',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                    ),
                    
                    // Arrow Icon
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFCCCCCC),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
