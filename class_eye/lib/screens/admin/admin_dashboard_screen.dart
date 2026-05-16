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
import 'student_list_screen.dart';
import 'instructor_list_screen.dart';
import 'course_management_screen.dart';
import 'attendance_logs_screen.dart';
import 'audit_log_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _stats = {};
  List<dynamic> _pendingIssues = [];
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetchStats();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() =>
        _name = prefs.getString('full_name') ?? prefs.getString('username') ?? 'Admin');
  }

  Future<void> _fetchStats() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.adminStats));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _stats        = data;
        _pendingIssues = data['pending_disputes'] ?? data['pending_issues'] ?? [];
      } else {
        _error = data['message'] ?? 'Failed to load stats';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    child: Icon(Icons.admin_panel_settings_rounded,
                        size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_name,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Administrator',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerNavTile(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    selected: true,
                    onTap: () => Navigator.pop(context)),
                DrawerNavTile(
                    icon: Icons.people_rounded,
                    title: 'Students',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const StudentListScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.school_rounded,
                    title: 'Instructors',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const InstructorListScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.book_rounded,
                    title: 'Courses',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const CourseManagementScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.fact_check_rounded,
                    title: 'Attendance Logs',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const AttendanceLogsScreen()));
                    }),
                DrawerNavTile(
                    icon: Icons.history_edu_rounded,
                    title: 'Audit Log',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          AppTheme.slideRoute(const AuditLogScreen()));
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
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _buildDrawer(),
      body: _loading
          ? const AppShimmer(count: 5, itemHeight: 90)
          : _error.isNotEmpty
              ? ErrorState(message: _error, onRetry: _fetchStats)
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                                fontSize: 22, color: context.clrText),
                            children: [
                              const TextSpan(text: 'Welcome, '),
                              TextSpan(
                                text: _name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          ZoomIn(
                              delay: const Duration(milliseconds: 100),
                              child: _StatCard(
                                  label: 'Students',
                                  value: '${_stats['total_students'] ?? 0}',
                                  icon: Icons.people_rounded,
                                  color: AppColors.accent)),
                          ZoomIn(
                              delay: const Duration(milliseconds: 180),
                              child: _StatCard(
                                  label: 'Instructors',
                                  value:
                                      '${_stats['total_instructors'] ?? 0}',
                                  icon: Icons.school_rounded,
                                  color: AppColors.warning)),
                          ZoomIn(
                              delay: const Duration(milliseconds: 260),
                              child: _StatCard(
                                  label: 'Courses',
                                  value: '${_stats['total_courses'] ?? 0}',
                                  icon: Icons.book_rounded,
                                  color: AppColors.success)),
                          ZoomIn(
                              delay: const Duration(milliseconds: 340),
                              child: _StatCard(
                                  label: "Today's Sessions",
                                  value:
                                      '${_stats['total_sessions_today'] ?? 0}',
                                  icon: Icons.event_rounded,
                                  color: Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          child: Text('Quick Actions',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.clrText))),
                      const SizedBox(height: 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 350),
                        child: Wrap(spacing: 10, runSpacing: 10, children: [
                          _QuickAction(
                              label: 'Students',
                              icon: Icons.people_rounded,
                              color: AppColors.accent,
                              onTap: () => Navigator.push(context,
                                  AppTheme.slideRoute(
                                      const StudentListScreen()))),
                          _QuickAction(
                              label: 'Instructors',
                              icon: Icons.school_rounded,
                              color: AppColors.warning,
                              onTap: () => Navigator.push(context,
                                  AppTheme.slideRoute(
                                      const InstructorListScreen()))),
                          _QuickAction(
                              label: 'Courses',
                              icon: Icons.book_rounded,
                              color: AppColors.success,
                              onTap: () => Navigator.push(context,
                                  AppTheme.slideRoute(
                                      const CourseManagementScreen()))),
                          _QuickAction(
                              label: 'Att. Logs',
                              icon: Icons.fact_check_rounded,
                              color: Colors.purple,
                              onTap: () => Navigator.push(context,
                                  AppTheme.slideRoute(
                                      const AttendanceLogsScreen()))),
                          _QuickAction(
                              label: 'Audit Log',
                              icon: Icons.history_edu_rounded,
                              color: Colors.teal,
                              onTap: () => Navigator.push(context,
                                  AppTheme.slideRoute(
                                      const AuditLogScreen()))),
                        ]),
                      ),
                      if (_pendingIssues.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        FadeInUp(
                            delay: const Duration(milliseconds: 400),
                            child: Text('Pending Issues',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.clrText))),
                        const SizedBox(height: 10),
                        ..._pendingIssues.asMap().entries.map((e) =>
                            FadeInLeft(
                              delay: Duration(
                                  milliseconds: 450 + 60 * e.key),
                              child: Card(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.warning.withAlpha(30),
                                    child: const Icon(
                                        Icons.flag_rounded,
                                        color: AppColors.warning,
                                        size: 20),
                                  ),
                                  title: Text(
                                      e.value['student_name'] ?? '',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  subtitle: Text(
                                      '${e.value['course_name']} • ${e.value['submitted_at']}',
                                      style:
                                          GoogleFonts.poppins(fontSize: 12)),
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white70, size: 26),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11)),
            ]),
          ]),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: width,
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withAlpha(70)),
          ),
          child: Row(children: [
            Icon(widget.icon, color: widget.color, size: 20),
            const SizedBox(width: 8),
            Text(widget.label,
                style: GoogleFonts.poppins(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
