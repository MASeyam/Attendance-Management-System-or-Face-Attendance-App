import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import 'add_course_screen.dart';

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.courses));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _courses = data['courses'];
      } else {
        _error = data['message'] ?? 'Failed to load courses';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, AppTheme.slideRoute(const AddCourseScreen()));
          _fetch();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Course'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppShimmer(count: 6, itemHeight: 88);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_courses.isEmpty) {
      return const EmptyState(
          icon: Icons.menu_book_rounded, message: 'No courses yet.');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _courses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final c = _courses[i];
          return FadeInLeft(
            delay: Duration(milliseconds: 35 * i),
            duration: const Duration(milliseconds: 200),
            child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppColors.accent, size: 22),
                ),
                title: Text(c['name'] ?? '',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      c['instructor_name'] ?? 'No instructor assigned',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: context.clrSubText),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      _pill('${c['credit_hours'] ?? '-'} cr', AppColors.primary),
                      const SizedBox(width: 6),
                      _pill('${c['enrolled_count'] ?? 0} students',
                          AppColors.success),
                      if (c['department_name'] != null) ...[
                        const SizedBox(width: 6),
                        _pill(c['department_name'], AppColors.accent),
                      ],
                    ]),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
