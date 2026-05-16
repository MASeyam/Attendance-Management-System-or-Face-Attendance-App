import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AttendanceSheetScreen extends StatefulWidget {
  final int sessionId;
  const AttendanceSheetScreen({super.key, required this.sessionId});

  @override
  State<AttendanceSheetScreen> createState() => _AttendanceSheetScreenState();
}

class _AttendanceSheetScreenState extends State<AttendanceSheetScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _records = [];
  int _editorId   = 0;
  String _editorName = '';

  @override
  void initState() {
    super.initState();
    _loadEditor();
    _fetch();
  }

  Future<void> _loadEditor() async {
    final prefs = await SharedPreferences.getInstance();
    _editorId   = prefs.getInt('user_id') ?? 0;
    _editorName = '${prefs.getString('first_name') ?? ''} ${prefs.getString('last_name') ?? ''}'.trim();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(
          Uri.parse(ApiConstants.sessionAttendance(widget.sessionId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _records = List<Map<String, dynamic>>.from(data['records']);
      } else {
        _error = data['message'] ?? 'Failed to load records';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(int index) async {
    final r    = _records[index];
    final atId = r['attendance_id'];
    if (atId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No attendance record to update. Student is absent.'),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    final oldStatus = r['status'] as String? ?? 'Absent';
    final newStatus = oldStatus == 'Present' ? 'Absent' : 'Present';

    try {
      final res = await http.put(
        Uri.parse(ApiConstants.updateAttendance(atId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status':       newStatus,
          'editor_id':    _editorId,
          'editor_name':  _editorName,
          'student_name': r['student_name'] ?? '',
          'old_status':   oldStatus,
          'session_id':   widget.sessionId,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => _records[index]['status'] = newStatus);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Update failed'),
              backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot reach server.'),
            backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session #${widget.sessionId} — Attendance'),
      ),
      body: _loading
          ? const AppShimmer(count: 8, itemHeight: 68)
          : _error.isNotEmpty
              ? ErrorState(message: _error, onRetry: _fetch)
              : _records.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline_rounded,
                      message: 'No students enrolled in this session.')
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: AppColors.accent,
                      child: Column(children: [
                        // Audit notice banner
                        Container(
                          color: AppColors.accent.withAlpha(18),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Manual edits are logged with your name and a timestamp.',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: AppColors.accent),
                              ),
                            ),
                          ]),
                        ),
                        _SummaryBar(records: _records),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final r      = _records[i];
                              final status = r['status'] ?? 'Absent';
                              final color  = AppTheme.statusColor(status);
                              return FadeInLeft(
                                delay: Duration(milliseconds: 30 * i),
                                duration: const Duration(milliseconds: 200),
                                child: Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withAlpha(28),
                                      child: Text(
                                        (r['student_name'] as String? ?? '?')
                                                .isNotEmpty
                                            ? (r['student_name']
                                                    as String)[0]
                                                .toUpperCase()
                                            : '?',
                                        style: GoogleFonts.poppins(
                                            color: color,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    title: Text(r['student_name'] ?? '',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    subtitle: Text(
                                      'ID: ${r['student_id']}  •  '
                                      '${r['marked_at'].toString().isNotEmpty ? r['marked_at'] : 'Not marked'}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: context.clrSubText),
                                    ),
                                    trailing: GestureDetector(
                                      onTap: () => _toggleStatus(i),
                                      child: StatusChip(
                                          label: status, color: color),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _SummaryBar({required this.records});

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r['status'] == 'Present').length;
    final absent  = records.length - present;
    return Container(
      color: context.clrSurf,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _chip(context, 'Total',   '${records.length}', Colors.blueGrey),
          _divider(context),
          _chip(context, 'Present', '$present', AppColors.success),
          _divider(context),
          _chip(context, 'Absent',  '$absent',  AppColors.danger),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.poppins(color: ctx.clrSubText, fontSize: 12)),
      ]);

  Widget _divider(BuildContext ctx) =>
      Container(width: 1, height: 36, color: ctx.clrBorder);
}
