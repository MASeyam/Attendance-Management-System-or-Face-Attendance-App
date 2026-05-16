import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import '../auth/role_selection_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/settings_screen.dart';
import 'attendance_sheet_screen.dart';
import 'dispute_inbox_screen.dart';   // contains IssueInboxScreen
import 'attendance_reports_screen.dart';
import 'session_detail_screen.dart';

class InstructorDashboardScreen extends StatefulWidget {
  final int instructorId;
  const InstructorDashboardScreen({super.key, required this.instructorId});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState
    extends State<InstructorDashboardScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _sessions = [];
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetchSessions();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _name =
        '${prefs.getString('first_name') ?? ''} ${prefs.getString('last_name') ?? ''}');
  }

  Future<void> _fetchSessions() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(
          Uri.parse(ApiConstants.sessionsToday(widget.instructorId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _sessions = data['sessions'];
      } else {
        _error = data['message'] ?? 'Failed to load sessions';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSession(int sessionId, String currentStatus) async {
    final isOpen = currentStatus == 'Open' || currentStatus == 'Active';
    final url    = isOpen
        ? ApiConstants.closeSession(sessionId)
        : ApiConstants.openSession(sessionId);
    try {
      final res  = await http.put(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _fetchSessions();
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
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      AppTheme.slideRoute(const RoleSelectionScreen()),
      (_) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C5282), AppColors.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded,
                        size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_name,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Instructor',
                    style:
                        GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerNavTile(
                    icon: Icons.today_rounded,
                    title: "Today's Sessions",
                    selected: true,
                    onTap: () => Navigator.pop(context)),
                DrawerNavTile(
                    icon: Icons.flag_rounded,
                    title: 'Issue Inbox',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          AppTheme.slideRoute(IssueInboxScreen(
                              instructorId: widget.instructorId)));
                    }),
                DrawerNavTile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Attendance Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          AppTheme.slideRoute(AttendanceReportsScreen(
                              instructorId: widget.instructorId)));
                    }),
                DrawerNavTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const NotificationsScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context, AppTheme.slideRoute(const ProfileScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context, AppTheme.slideRoute(const SettingsScreen()));
                    }),
                const Divider(color: Colors.white24, height: 1),
                DrawerNavTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    iconColor: AppColors.danger,
                    onTap: _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Sessions")),
      drawer: _buildDrawer(),
      body: _loading
          ? const AppShimmer(count: 3, itemHeight: 160)
          : _error.isNotEmpty
              ? ErrorState(message: _error, onRetry: _fetchSessions)
              : _sessions.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_busy_rounded,
                      message: 'No sessions scheduled for today.')
                  : RefreshIndicator(
                      onRefresh: _fetchSessions,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (_, i) => FadeInUp(
                          delay: Duration(milliseconds: 80 * i),
                          duration: const Duration(milliseconds: 400),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _SessionCard(
                              session: _sessions[i],
                              onToggle: () => _toggleSession(
                                  _sessions[i]['session_id'],
                                  _sessions[i]['session_status'] ?? ''),
                              onViewAttendance: () => Navigator.push(
                                  context,
                                  AppTheme.slideRoute(AttendanceSheetScreen(
                                      sessionId: _sessions[i]
                                          ['session_id']))),
                              onTap: () => Navigator.push(
                                  context,
                                  AppTheme.slideRoute(SessionDetailScreen(
                                      session: _sessions[i]))),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onToggle;
  final VoidCallback onViewAttendance;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.onToggle,
    required this.onViewAttendance,
    required this.onTap,
  });

  Color _statusColor(String s) => AppTheme.statusColor(s);
  bool _isOpen(String s) => s == 'Open' || s == 'Active';

  // True when now is before the session's scheduled start time → toggle locked
  bool _isBeforeStart() {
    try {
      final dt = DateTime.parse(session['start'] as String);
      return DateTime.now().isBefore(dt);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = session['session_status'] ?? 'Scheduled';
    final open   = _isOpen(status);
    final color  = _statusColor(status);
    final locked = _isBeforeStart();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            // ── Header band ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                color: color.withAlpha(20),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: [
                Expanded(
                  child: Text(session['course_name'] ?? '',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: context.clrText)),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: StatusChip(
                      key: ValueKey(status), label: status, color: color),
                ),
              ]),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _row(context, Icons.access_time_rounded,
                    '${session['start'] ?? ''}  →  ${_trimTime(session['end'] ?? '')}'),
                const SizedBox(height: 4),
                _row(context, Icons.location_on_outlined,
                    'Room ${session['room'] ?? '-'}  •  ${session['building'] ?? '-'}'),
                const SizedBox(height: 4),
                _row(context, Icons.people_outline,
                    '${session['present_count'] ?? 0} / ${session['total_enrolled'] ?? 0} present'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewAttendance,
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text('Edit Sheet'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tooltip(
                      message: locked
                          ? 'Locked until session start time'
                          : open
                              ? 'Close session'
                              : 'Open session',
                      child: ElevatedButton.icon(
                        // Toggle is OFF by default and locked before start time
                        onPressed: locked ? null : onToggle,
                        icon: Icon(
                          locked
                              ? Icons.lock_clock_rounded
                              : open
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                          size: 16,
                        ),
                        label: Text(locked ? 'Locked' : open ? 'Close' : 'Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: locked
                              ? Colors.grey
                              : open
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
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _trimTime(String t) => t.length > 16 ? t.substring(11) : t;

  Widget _row(BuildContext context, IconData icon, String text) =>
      Row(children: [
        Icon(icon, size: 14, color: context.clrSubText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  color: context.clrSubText, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}
