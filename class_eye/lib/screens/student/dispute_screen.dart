import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import 'issue_detail_screen.dart';

class IssueScreen extends StatefulWidget {
  final int studentId;
  const IssueScreen({super.key, required this.studentId});

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _issues = [];

  bool _loadingAbsent = false;
  bool _submitting    = false;
  List<dynamic> _absentSessions = [];
  int? _selectedSessionId;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchIssues() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.studentIssues(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _issues = data['issues'];
      } else {
        _error = data['message'] ?? 'Failed to load issues';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAbsentSessions() async {
    setState(() => _loadingAbsent = true);
    try {
      final res  = await http.get(Uri.parse(ApiConstants.attendanceHistory(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final all = data['history'] as List;
        _absentSessions = all.where((r) => r['status'] == 'Absent').toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAbsent = false);
  }

  Future<void> _submit() async {
    if (_selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a session'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a reason'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.createIssue),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.studentId,
          'session_id': _selectedSessionId,
          'reason':     _reasonCtrl.text.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if ((res.statusCode == 200 || res.statusCode == 201) && data['success'] == true) {
        _reasonCtrl.clear();
        setState(() => _selectedSessionId = null);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Issue submitted successfully'),
              backgroundColor: AppColors.success),
        );
        _fetchIssues();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Submission failed'),
              backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot reach server.'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openSubmitSheet() async {
    _selectedSessionId = null;
    _reasonCtrl.clear();
    await _fetchAbsentSessions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.clrSurf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Submit New Issue',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: context.clrText)),
                ),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              if (_loadingAbsent)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_absentSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('No absent sessions to issue.',
                        style: GoogleFonts.poppins(
                            color: context.clrSubText, fontSize: 13)),
                  ]),
                )
              else ...[
                DropdownButtonFormField<int>(
                  value: _selectedSessionId,
                  decoration: const InputDecoration(labelText: 'Select absent session'),
                  items: _absentSessions.map((s) => DropdownMenuItem<int>(
                    value: s['session_id'] as int,
                    child: Text(
                      '${s['course_name']} — ${s['session_start']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => _selectedSessionId = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Explain why you believe this was recorded incorrectly…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Submit Issue',
                  icon: Icons.send_rounded,
                  loading: _submitting,
                  onTap: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppShimmer(count: 4, itemHeight: 90);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetchIssues);

    return Stack(children: [
      _issues.isEmpty
          ? RefreshIndicator(
              onRefresh: _fetchIssues,
              color: AppColors.accent,
              child: ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.flag_outlined,
                  message: 'No issues submitted yet.\nTap + to raise one.',
                ),
              ]),
            )
          : RefreshIndicator(
              onRefresh: _fetchIssues,
              color: AppColors.accent,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _issues.length,
                itemBuilder: (_, i) {
                  final issue  = _issues[i];
                  final status = issue['status'] ?? 'pending';
                  final color  = AppTheme.statusColor(status);
                  return FadeInUp(
                    delay: Duration(milliseconds: 60 * i),
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(context,
                              AppTheme.slideRoute(IssueDetailScreen(issue: issue))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(issue['course_name'] ?? '',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: context.clrText)),
                                  ),
                                  StatusChip(label: status, color: color),
                                ]),
                                const SizedBox(height: 4),
                                Text(issue['submitted_at'] ?? '',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: context.clrSubText)),
                                const SizedBox(height: 8),
                                Text(
                                  (issue['reason'] as String? ?? '').length > 70
                                      ? '${(issue['reason'] as String).substring(0, 70)}…'
                                      : issue['reason'] ?? '',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: context.clrSubText),
                                ),
                                if (status != 'pending') ...[
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Icon(
                                      status == 'accepted'
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      color: color, size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      status == 'accepted'
                                          ? 'Accepted by instructor'
                                          : 'Declined by instructor',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: color,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.extended(
          onPressed: _openSubmitSheet,
          icon: const Icon(Icons.add_rounded),
          label: Text('New Issue',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
    ]);
  }
}
