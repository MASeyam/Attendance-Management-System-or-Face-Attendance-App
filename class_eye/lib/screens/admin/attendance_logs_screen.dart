import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  bool _loading     = false;
  String _error     = '';
  List<dynamic> _logs = [];

  final _studentIdCtrl = TextEditingController();
  String? _statusFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final _statuses = ['Present', 'Absent', 'issued', 'resolved'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final params = <String, String>{};
      if (_studentIdCtrl.text.trim().isNotEmpty) params['student_id'] = _studentIdCtrl.text.trim();
      if (_statusFilter != null) params['status'] = _statusFilter!;
      if (_dateFrom != null) params['date_from'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      if (_dateTo   != null) params['date_to']   = DateFormat('yyyy-MM-dd').format(_dateTo!);

      final uri  = Uri.parse(ApiConstants.adminAttendanceLogs).replace(queryParameters: params);
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _logs = data['logs'];
      } else {
        _error = data['message'] ?? 'Failed to load logs';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Logs')),
      body: Column(children: [
        _buildFilters(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: context.clrSurf,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _pickDate(true),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(
              _dateFrom == null ? 'From' : DateFormat('dd MMM').format(_dateFrom!),
              style: const TextStyle(fontSize: 12),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _pickDate(false),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(
              _dateTo == null ? 'To' : DateFormat('dd MMM').format(_dateTo!),
              style: const TextStyle(fontSize: 12),
            ),
          )),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
                icon: const Icon(Icons.clear_rounded,
                    size: 18, color: AppColors.danger),
                onPressed: () {
                  setState(() { _dateFrom = null; _dateTo = null; });
                  _fetch();
                }),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _studentIdCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Student ID',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _fetch),
              ),
              onSubmitted: (_) => _fetch(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _fetch();
              },
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${_logs.length} records',
              style: GoogleFonts.poppins(
                  color: context.clrSubText, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 8, itemHeight: 72);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_logs.isEmpty) {
      return const EmptyState(
          icon: Icons.bar_chart_rounded, message: 'No records found.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final r      = _logs[i];
        final status = r['status'] ?? '';
        final color  = AppTheme.statusColor(status);
        return FadeInLeft(
          delay: Duration(milliseconds: 30 * i),
          duration: const Duration(milliseconds: 200),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: color.withAlpha(22),
                child: Icon(Icons.person_rounded, color: color, size: 18),
              ),
              title: Text(
                '${r['student_name']} (${r['student_id']})',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                '${r['course_name']} • ${r['session_start']} • ${r['method']}',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: context.clrSubText),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(label: status, color: color),
                  const SizedBox(height: 4),
                  Text(r['marked_at'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: context.clrSubText)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
