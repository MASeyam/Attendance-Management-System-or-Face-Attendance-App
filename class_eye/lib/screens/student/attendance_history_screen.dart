import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int studentId;
  const AttendanceHistoryScreen({super.key, required this.studentId});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _records   = [];
  List<dynamic> _courses   = [];

  // Step 1: selected course_id (int); avoids Map reference-equality assertion
  int? _selectedCourseId;
  // Step 2: session type — only available after course is selected
  String? _selectedType;

  static const _sessionTypes = ['Theoretical', 'Practical'];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _fetchDefault();
  }

  Future<void> _fetchCourses() async {
    try {
      final res  = await http.get(Uri.parse(ApiConstants.attendanceSummary(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true && mounted) {
        setState(() => _courses = data['summary']);
      }
    } catch (_) {}
  }

  // Default: fetch all records, display only last 5 client-side
  Future<void> _fetchDefault() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.attendanceHistory(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final all = data['history'] as List;
        _records = all.length > 5 ? all.sublist(0, 5) : all;
      } else {
        _error = data['message'] ?? 'Failed to load history';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Filtered: pass course_id and/or session_type, returns all matching records
  Future<void> _fetchFiltered() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final params = <String, String>{};
      if (_selectedCourseId != null) params['course_id'] = '$_selectedCourseId';
      if (_selectedType     != null) params['session_type'] = _selectedType!;
      final uri = Uri.parse(ApiConstants.attendanceHistory(widget.studentId))
          .replace(queryParameters: params);
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _records = data['history'];
      } else {
        _error = data['message'] ?? 'Failed to load history';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCourseChanged(int? courseId) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedType     = null; // reset step 2 whenever step 1 changes
    });
    if (courseId == null) {
      _fetchDefault();
    } else {
      _fetchFiltered();
    }
  }

  void _onTypeChanged(String? type) {
    setState(() => _selectedType = type);
    _fetchFiltered();
  }

  void _clearAll() {
    setState(() { _selectedCourseId = null; _selectedType = null; });
    _fetchDefault();
  }

  bool get _isFiltered => _selectedCourseId != null;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildFilters(),
      Expanded(child: _buildList()),
    ]);
  }

  Widget _buildFilters() {
    return Container(
      color: context.clrSurf,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        // ── Step 1: course ──────────────────────────────────────────────────
        DropdownButtonFormField<int?>(
          value: _selectedCourseId,
          decoration: InputDecoration(
            labelText: 'Step 1 — Select course',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: _selectedCourseId != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        size: 18, color: AppColors.danger),
                    onPressed: _clearAll)
                : null,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'All courses (last 5 records)',
                style: GoogleFonts.poppins(
                    color: context.clrSubText, fontSize: 13),
              ),
            ),
            ..._courses.map((c) => DropdownMenuItem<int?>(
                value: c['course_id'] as int,
                child: Text(c['course_name'] as String,
                    overflow: TextOverflow.ellipsis))),
          ],
          onChanged: _onCourseChanged,
        ),

        // ── Step 2: session type — only visible after course is chosen ──────
        if (_selectedCourseId != null) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'Step 2 — Session type',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _selectedType != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: AppColors.danger),
                      onPressed: () => _onTypeChanged(null))
                  : null,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('All types',
                    style: GoogleFonts.poppins(
                        color: context.clrSubText, fontSize: 13)),
              ),
              ..._sessionTypes.map((t) => DropdownMenuItem<String?>(
                  value: t, child: Text(t))),
            ],
            onChanged: _onTypeChanged,
          ),
        ],
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 5, itemHeight: 72);
    if (_error.isNotEmpty) {
      return ErrorState(
          message: _error,
          onRetry: _isFiltered ? _fetchFiltered : _fetchDefault);
    }
    if (_records.isEmpty) {
      return EmptyState(
          icon: Icons.history_rounded,
          message: _isFiltered
              ? 'No records for the selected filters.'
              : 'No recent attendance records.');
    }

    return RefreshIndicator(
      onRefresh: _isFiltered ? _fetchFiltered : _fetchDefault,
      color: AppColors.accent,
      child: Column(children: [
        // Info banner when showing default (unfiltered) view
        if (!_isFiltered)
          Container(
            color: AppColors.accent.withAlpha(18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Showing last 5 records. Select a course to see all.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.accent),
                ),
              ),
            ]),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final r      = _records[i];
              final status = r['status'] ?? '';
              final color  = AppTheme.statusColor(status);
              final type   = r['session_type'] as String?;
              return FadeInLeft(
                delay: Duration(milliseconds: 40 * i),
                duration: const Duration(milliseconds: 200),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.circle, size: 10, color: color),
                    ),
                    title: Text(r['course_name'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${r['session_start'] ?? ''}${type != null ? '  •  $type' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: context.clrSubText),
                    ),
                    trailing: StatusChip(label: status, color: color),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
