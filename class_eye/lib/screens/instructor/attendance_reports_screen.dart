import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class AttendanceReportsScreen extends StatefulWidget {
  final int instructorId;
  const AttendanceReportsScreen({super.key, required this.instructorId});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  bool _loading = false;
  String _error = '';
  List<dynamic> _records = [];
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _totalPresent = 0, _totalAbsent = 0, _totalIssues = 0;
  final _studentIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final params = <String, String>{};
      if (_studentIdCtrl.text.trim().isNotEmpty) params['student_id'] = _studentIdCtrl.text.trim();
      if (_dateFrom != null) params['date_from'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      if (_dateTo   != null) params['date_to']   = DateFormat('yyyy-MM-dd').format(_dateTo!);

      final uri  = Uri.parse(ApiConstants.instructorReports(widget.instructorId))
          .replace(queryParameters: params);
      final res  = await http.get(uri);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _records      = data['records'];
        _totalPresent = data['total_present']  ?? 0;
        _totalAbsent  = data['total_absent']   ?? 0;
        _totalIssues  = data['total_disputed'] ?? data['total_issues'] ?? 0;
      } else {
        _error = data['message'] ?? 'Failed to load reports';
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
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Reports')),
      body: Column(children: [
        _buildFilters(),
        if (!_loading && _error.isEmpty) _buildSummary(),
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
            label: Text(_dateFrom == null ? 'From' : DateFormat('dd MMM').format(_dateFrom!),
                style: const TextStyle(fontSize: 12)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _pickDate(false),
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(_dateTo == null ? 'To' : DateFormat('dd MMM').format(_dateTo!),
                style: const TextStyle(fontSize: 12)),
          )),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.danger),
                onPressed: () {
                  setState(() { _dateFrom = null; _dateTo = null; });
                  _fetchReports();
                }),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _studentIdCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Student ID (optional)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded), onPressed: _fetchReports),
          ),
          onSubmitted: (_) => _fetchReports(),
        ),
      ]),
    );
  }

  Widget _buildSummary() {
    return Container(
      color: context.clrBg,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _summaryChip('Total',   '${_records.length}', Colors.blueGrey),
        _summaryChip('Present', '$_totalPresent',     AppColors.success),
        _summaryChip('Absent',  '$_totalAbsent',      AppColors.danger),
        _summaryChip('Issues',  '$_totalIssues',      AppColors.warning),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label,
          style: GoogleFonts.poppins(
              color: context.clrSubText, fontSize: 11)),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 6, itemHeight: 68);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetchReports);
    if (_records.isEmpty) {
      return const EmptyState(
          icon: Icons.bar_chart_rounded, message: 'No records found.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final r      = _records[i];
        final status = r['status'] ?? 'Absent';
        final color  = AppTheme.statusColor(status);
        return FadeInLeft(
          delay: Duration(milliseconds: 40 * i),
          duration: const Duration(milliseconds: 200),
          child: Card(
            child: ListTile(
              title: Text(r['student_name'] ?? '',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${r['course_name']} • ${r['session_start']}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: context.clrSubText)),
              trailing: StatusChip(label: status, color: color),
            ),
          ),
        );
      },
    );
  }
}
