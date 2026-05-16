import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import 'dispute_detail_screen.dart'; // contains IssueDetailScreen

class IssueInboxScreen extends StatefulWidget {
  final int instructorId;
  const IssueInboxScreen({super.key, required this.instructorId});

  @override
  State<IssueInboxScreen> createState() => _IssueInboxScreenState();
}

class _IssueInboxScreenState extends State<IssueInboxScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _issues = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(
          Uri.parse(ApiConstants.instructorIssues(widget.instructorId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _issues = data['issues'] ?? data['disputes'] ?? [];
      } else {
        _error = data['message'] ?? 'Failed to load issues';
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
      appBar: AppBar(title: const Text('Issue Inbox')),
      body: _loading
          ? const AppShimmer(count: 5, itemHeight: 100)
          : _error.isNotEmpty
              ? ErrorState(message: _error, onRetry: _fetch)
              : _issues.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_rounded,
                      message: 'No issues yet.')
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: AppColors.accent,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _issues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, i) {
                          final d         = _issues[i];
                          final status    = d['status'] ?? 'pending';
                          final isPending = status == 'pending';
                          final color     = isPending
                              ? AppColors.warning
                              : status == 'accepted'
                                  ? AppColors.success
                                  : AppColors.danger;
                          return FadeInLeft(
                            delay: Duration(milliseconds: 40 * i),
                            duration: const Duration(milliseconds: 200),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      AppTheme.slideRoute(
                                          IssueDetailScreen(issue: d)));
                                  _fetch();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: color.withAlpha(25),
                                            shape: BoxShape.circle),
                                        child: Icon(
                                          isPending
                                              ? Icons.flag_rounded
                                              : status == 'accepted'
                                                  ? Icons.check_circle_rounded
                                                  : Icons.cancel_rounded,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(d['student_name'] ?? '',
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${d['course_name'] ?? ''} • ${d['session_start'] ?? ''}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: context.clrSubText),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (d['reason'] as String? ?? '').length > 60
                                                  ? '${(d['reason'] as String).substring(0, 60)}…'
                                                  : d['reason'] ?? '',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: context.clrSubText),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(label: status, color: color),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
