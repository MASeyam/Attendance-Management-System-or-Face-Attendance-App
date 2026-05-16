import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = false;
  String _error = '';
  List<dynamic> _logs = [];

  final _instructorCtrl = TextEditingController();
  final _studentCtrl    = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _instructorCtrl.dispose();
    _studentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final params = <String, String>{};
      if (_instructorCtrl.text.trim().isNotEmpty)
        params['instructor'] = _instructorCtrl.text.trim();
      if (_studentCtrl.text.trim().isNotEmpty)
        params['student'] = _studentCtrl.text.trim();
      if (_dateFrom != null)
        params['date_from'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      if (_dateTo != null)
        params['date_to'] = DateFormat('yyyy-MM-dd').format(_dateTo!);

      final uri = Uri.parse(ApiConstants.adminAuditLogs)
          .replace(queryParameters: params);
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _logs = data['logs'];
      } else {
        _error = data['message'] ?? 'Failed to load audit log';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
      _fetch();
    }
  }

  void _clearDates() {
    setState(() { _dateFrom = null; _dateTo = null; });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: context.clrSurf,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // ── Instructor + Student search ──────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: _instructorCtrl,
              decoration: InputDecoration(
                labelText: 'Instructor',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    onPressed: _fetch),
              ),
              onSubmitted: (_) => _fetch(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _studentCtrl,
              decoration: InputDecoration(
                labelText: 'Student',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    onPressed: _fetch),
              ),
              onSubmitted: (_) => _fetch(),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // ── Date range ─────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(true),
              icon: const Icon(Icons.calendar_today_rounded, size: 14),
              label: Text(
                _dateFrom == null
                    ? 'From date'
                    : DateFormat('dd MMM yyyy').format(_dateFrom!),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.calendar_today_rounded, size: 14),
              label: Text(
                _dateTo == null
                    ? 'To date'
                    : DateFormat('dd MMM yyyy').format(_dateTo!),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded,
                  color: AppColors.danger, size: 18),
              onPressed: _clearDates,
            ),
        ]),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 6, itemHeight: 90);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_logs.isEmpty) {
      return const EmptyState(
          icon: Icons.history_edu_rounded,
          message: 'No audit entries found.');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final log = _logs[i];
          final oldV = log['old_status'] ?? '—';
          final newV = log['new_status'] ?? '—';
          final oldColor = AppTheme.statusColor(oldV);
          final newColor = AppTheme.statusColor(newV);

          return FadeInLeft(
            delay: Duration(milliseconds: 30 * i),
            duration: const Duration(milliseconds: 200),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // ── Change summary row ────────────────────────────────
                  Row(children: [
                    StatusChip(label: oldV, color: oldColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: context.clrSubText),
                    ),
                    StatusChip(label: newV, color: newColor),
                    const Spacer(),
                    Text(log['timestamp'] ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: context.clrSubText)),
                  ]),
                  const SizedBox(height: 10),
                  // ── Detail rows ───────────────────────────────────────
                  _logRow(context, Icons.person_rounded,
                      'Student', log['student_name'] ?? '—'),
                  const SizedBox(height: 4),
                  _logRow(context, Icons.book_rounded,
                      'Course', log['course_name'] ?? '—'),
                  const SizedBox(height: 4),
                  _logRow(context, Icons.event_rounded,
                      'Session', log['session_date'] ?? '—'),
                  const SizedBox(height: 4),
                  _logRow(context, Icons.edit_rounded,
                      'Edited by', log['instructor_name'] ?? '—'),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _logRow(BuildContext ctx, IconData icon, String label, String value) =>
      Row(children: [
        Icon(icon, size: 13, color: ctx.clrSubText),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text('$label:',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: ctx.clrSubText)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ctx.clrText),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}
