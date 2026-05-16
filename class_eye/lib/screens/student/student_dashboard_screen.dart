import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import '../auth/role_selection_screen.dart';
import 'attendance_history_screen.dart';
import 'schedule_screen.dart';
import 'dispute_screen.dart'; // contains IssueScreen
import '../shared/profile_screen.dart';
import '../shared/notifications_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final int studentId;
  const StudentDashboardScreen({super.key, required this.studentId});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardBody(studentId: widget.studentId),
      AttendanceHistoryScreen(studentId: widget.studentId),
      ScheduleScreen(studentId: widget.studentId),
      IssueScreen(studentId: widget.studentId),
    ];
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      AppTheme.slideRoute(const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ClassEye',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
                context, AppTheme.slideRoute(const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
                context, AppTheme.slideRoute(const ProfileScreen())),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 4) { _logout(); return; }
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Schedule'),
          BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag_rounded),
              label: 'Issues'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout, color: AppColors.danger),
              label: 'Logout'),
        ],
      ),
    );
  }
}

// ── Dashboard body ─────────────────────────────────────────────────────────────

class _DashboardBody extends StatefulWidget {
  final int studentId;
  const _DashboardBody({required this.studentId});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _profile = {};
  List<dynamic> _summary = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      _profile = {
        'first_name': prefs.getString('first_name') ?? '',
        'last_name':  prefs.getString('last_name')  ?? '',
        'id':         widget.studentId,
        'level':      prefs.getInt('level') ?? 0,
        'group_name': prefs.getString('group_name') ?? '',
        'gpa':        prefs.getDouble('gpa') ?? 0.0,
      };
      final res  = await http.get(Uri.parse(ApiConstants.attendanceSummary(widget.studentId)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _summary = data['summary'];
      } else {
        _error = data['message'] ?? 'Failed to load summary';
      }
    } catch (_) {
      _error = 'Cannot reach server. Check your connection.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(children: [
          _shimmerHeader(),
          const SizedBox(height: 16),
          const AppShimmer(count: 4, itemHeight: 110),
        ]),
      );
    }
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: _ProfileHeader(profile: _profile),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'My Courses',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: context.clrText),
            ),
          ),
          const SizedBox(height: 12),
          if (_summary.isEmpty)
            const EmptyState(
                icon: Icons.book_outlined, message: 'No courses enrolled yet.')
          else
            ...List.generate(_summary.length, (i) => FadeInUp(
              delay: Duration(milliseconds: 150 + 80 * i),
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseCard(course: _summary[i], index: i),
              ),
            )),
        ],
      ),
    );
  }

  Widget _shimmerHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        color: context.clrCard,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeader({required this.profile});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  String _displayed = '';
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final name = widget.profile['first_name'] as String? ?? '';
    final fullText = '$greeting, $name 👋';
    _timer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (_index < fullText.length) {
        setState(() => _displayed += fullText[_index++]);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 2),
            ),
            child: const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person_rounded, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _displayed.isEmpty ? ' ' : _displayed,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'ID: ${widget.profile['id']}',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ])),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _StatChip(label: 'Level', value: '${widget.profile['level']}'),
          _vDivider(),
          _StatChip(label: 'Group', value: widget.profile['group_name'] ?? '-'),
          _vDivider(),
          _StatChip(
              label: 'GPA',
              value: (widget.profile['gpa'] as double).toStringAsFixed(2)),
        ]),
      ]),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 32, color: Colors.white30);
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

// ── Course card ────────────────────────────────────────────────────────────────

class _CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final int index;
  const _CourseCard({required this.course, required this.index});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _animate = false;

  Color _pctColor(double p) {
    if (p >= 75) return AppColors.success;
    if (p >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final pct   = (widget.course['percentage'] as num).toDouble();
    final color = _pctColor(pct);

    return VisibilityDetector(
      key: Key('course-${widget.index}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.2 && !_animate) {
          setState(() => _animate = true);
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  widget.course['course_name'] ?? '',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: context.clrText),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _animate ? pct / 100 : 0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 5,
                      backgroundColor: context.clrBorder,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Chip('Total',   '${widget.course['total_sessions']}', Colors.blueGrey),
              _Chip('Present', '${widget.course['present']}', AppColors.success),
              _Chip('Absent',  '${widget.course['absent']}', AppColors.danger),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _animate ? pct / 100 : 0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              color: color, fontWeight: FontWeight.w700, fontSize: 16)),
      Text(label,
          style: GoogleFonts.poppins(color: context.clrSubText, fontSize: 11)),
    ]);
  }
}
