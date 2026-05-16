import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _students = [];
  late Map<String, dynamic> _session;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(
          Uri.parse(ApiConstants.sessionAttendance(_session['session_id'])));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _students = List<Map<String, dynamic>>.from(data['records']);
      } else {
        _error = data['message'] ?? 'Failed to load students';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Returns true if the current time is before the session's scheduled start
  bool get _isBeforeStart {
    try {
      final start = DateTime.parse(_session['start'] as String);
      return DateTime.now().isBefore(start);
    } catch (_) {
      return false;
    }
  }

  bool get _isOpen {
    final s = (_session['session_status'] ?? '') as String;
    return s == 'Open' || s == 'Active';
  }

  Future<void> _toggleSession() async {
    if (_isBeforeStart) return;
    setState(() => _toggling = true);
    final url = _isOpen
        ? ApiConstants.closeSession(_session['session_id'])
        : ApiConstants.openSession(_session['session_id']);
    try {
      final res  = await http.put(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          _session['session_status'] = _isOpen ? 'Closed' : 'Open';
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Failed'),
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
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_session['session_status'] ?? 'Scheduled') as String;
    final statusColor = AppTheme.statusColor(status);
    final locked = _isBeforeStart;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session['course_name'] ?? 'Session Detail'),
      ),
      body: Column(
        children: [
          // ── Session info header ──────────────────────────────────────────
          Container(
            color: context.clrSurf,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerRow(context, Icons.access_time_rounded,
                          '${_session['start'] ?? ''}  →  ${_trimTime(_session['end'] ?? '')}'),
                      const SizedBox(height: 4),
                      _headerRow(context, Icons.location_on_outlined,
                          'Room ${_session['room'] ?? '-'}  •  ${_session['building'] ?? '-'}'),
                      const SizedBox(height: 4),
                      _headerRow(context, Icons.people_outline,
                          '${_session['present_count'] ?? 0} / ${_session['total_enrolled'] ?? 0} present'),
                    ],
                  ),
                ),
                StatusChip(label: status, color: statusColor),
              ]),
              const SizedBox(height: 14),
              // ── Toggle button ────────────────────────────────────────────
              Tooltip(
                message: locked
                    ? 'Session cannot be opened before its scheduled start time'
                    : _isOpen
                        ? 'Close this session'
                        : 'Open this session for attendance',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: locked || _toggling ? null : _toggleSession,
                    icon: _toggling
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            locked
                                ? Icons.lock_clock_rounded
                                : _isOpen
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                            size: 18),
                    label: Text(
                      locked
                          ? 'Locked until session start'
                          : _isOpen
                              ? 'Close Session'
                              : 'Open Session',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: locked
                          ? Colors.grey
                          : _isOpen
                              ? AppColors.danger
                              : AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // ── Summary bar ──────────────────────────────────────────────────
          if (!_loading && _error.isEmpty && _students.isNotEmpty)
            _SummaryBar(students: _students),

          // ── Student list ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppShimmer(count: 6, itemHeight: 64)
                : _error.isNotEmpty
                    ? ErrorState(message: _error, onRetry: _fetchStudents)
                    : _students.isEmpty
                        ? const EmptyState(
                            icon: Icons.people_outline_rounded,
                            message: 'No students enrolled in this session.')
                        : RefreshIndicator(
                            onRefresh: _fetchStudents,
                            color: AppColors.accent,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _students.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, i) {
                                final s      = _students[i];
                                final sts    = s['status'] ?? 'Absent';
                                final color  = AppTheme.statusColor(sts);
                                return FadeInLeft(
                                  delay: Duration(milliseconds: 25 * i),
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            color.withAlpha(28),
                                        child: Text(
                                          (s['student_name'] as String? ??
                                                      '?')
                                                  .isNotEmpty
                                              ? (s['student_name']
                                                      as String)[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: GoogleFonts.poppins(
                                              color: color,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      title: Text(s['student_name'] ?? '',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      subtitle: Text('ID: ${s['student_id']}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: context.clrSubText)),
                                      trailing: StatusChip(
                                          label: sts, color: color),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _trimTime(String t) => t.length > 16 ? t.substring(11) : t;

  Widget _headerRow(BuildContext ctx, IconData icon, String text) =>
      Row(children: [
        Icon(icon, size: 13, color: ctx.clrSubText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  color: ctx.clrSubText, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}

class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  const _SummaryBar({required this.students});

  @override
  Widget build(BuildContext context) {
    final present = students.where((s) => s['status'] == 'Present').length;
    final absent  = students.length - present;
    return Container(
      color: context.clrSurf,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _chip(context, 'Total',   '${students.length}', Colors.blueGrey),
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
                color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.poppins(
                color: ctx.clrSubText, fontSize: 11)),
      ]);

  Widget _divider(BuildContext ctx) =>
      Container(width: 1, height: 32, color: ctx.clrBorder);
}
