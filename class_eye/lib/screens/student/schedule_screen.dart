import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class ScheduleScreen extends StatefulWidget {
  final int studentId;
  const ScheduleScreen({super.key, required this.studentId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.studentSchedule(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _sessions = data['sessions'];
      } else {
        _error = data['message'] ?? 'Failed to load schedule';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppShimmer(count: 5, itemHeight: 90);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_sessions.isEmpty) {
      return const EmptyState(
          icon: Icons.event_busy_rounded, message: 'No upcoming sessions.');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (_, i) {
          final s = _sessions[i];
          return FadeInUp(
            delay: Duration(milliseconds: 60 * i),
            duration: const Duration(milliseconds: 400),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.class_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['course_name'] ?? '',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14,
                            color: context.clrText)),
                    const SizedBox(height: 4),
                    _row(Icons.access_time_rounded,
                        '${s['start'] ?? ''} – ${_trim(s['end'] ?? '')}'),
                    const SizedBox(height: 2),
                    _row(Icons.location_on_outlined,
                        'Room ${s['room'] ?? '-'}  •  ${s['building'] ?? '-'}'),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(s['type'] ?? '',
                        style: GoogleFonts.poppins(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  String _trim(String t) => t.length > 16 ? t.substring(11) : t;

  Widget _row(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: context.clrSubText),
    const SizedBox(width: 4),
    Expanded(child: Text(text,
        style: GoogleFonts.poppins(color: context.clrSubText, fontSize: 12),
        overflow: TextOverflow.ellipsis)),
  ]);
}
