import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────
// Run this app separately or integrate via a route.
// Entry point for the instructor-facing dashboard.
// ─────────────────────────────────────────────────────────────

void runInstructorApp() {
  runApp(MaterialApp(
    home: const InstructorLoginPage(),
    debugShowCheckedModeBanner: false,
    title: 'AMS Instructor',
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData.dark(),
  ));
}

// ─────────────────────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────────────────────
class InstructorLoginPage extends StatefulWidget {
  const InstructorLoginPage({super.key});
  @override
  State<InstructorLoginPage> createState() => _InstructorLoginPageState();
}

class _InstructorLoginPageState extends State<InstructorLoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ipCtrl       = TextEditingController(text: '192.168.1.1');
  bool  _loading      = false;
  String? _error;

  String get _baseUrl {
    final ip = _ipCtrl.text
        .trim()
        .replaceAll('http://', '')
        .replaceAll('/', '')
        .split(':')[0];
    return 'http://$ip:5001';
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final role = data['role']?.toString() ?? '';
        if (!role.toLowerCase().contains('instructor') &&
            !role.toLowerCase().contains('admin')) {
          setState(() { _error = 'Only instructors can access this portal.'; });
          return;
        }
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => InstructorDashboard(
            instructorId:   data['id'].toString(),
            instructorName: data['name'].toString(),
            baseUrl:        _baseUrl,
          ),
        ));
      } else {
        setState(() { _error = data['message'] ?? 'Invalid credentials'; });
      }
    } catch (e) {
      setState(() { _error = 'Cannot connect to server at $_baseUrl'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text('AMS Instructor Portal',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                _buildField(
                  ctrl: _ipCtrl,
                  label: 'Server IP',
                  icon: Icons.dns,
                  keyboard: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildField(
                  ctrl: _usernameCtrl,
                  label: 'Username',
                  icon: Icons.person,
                ),
                const SizedBox(height: 12),
                _buildField(
                  ctrl: _passwordCtrl,
                  label: 'Password',
                  icon: Icons.lock,
                  obscure: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : _login,
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login),
                    label: Text(_loading ? 'Signing in…' : 'Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A2A3A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD — COURSE LIST
// ─────────────────────────────────────────────────────────────
class InstructorDashboard extends StatefulWidget {
  const InstructorDashboard({
    super.key,
    required this.instructorId,
    required this.instructorName,
    required this.baseUrl,
  });
  final String instructorId;
  final String instructorName;
  final String baseUrl;

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard> {
  List<Map<String, dynamic>> _courses = [];
  bool  _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/get_instructor_courses'),
        body: {'instructor_id': widget.instructorId},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(data['courses'] ?? []);
        });
      } else {
        setState(() => _error = data['message']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Courses', style: TextStyle(fontSize: 16)),
            Text(widget.instructorName,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const InstructorLoginPage()),
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)))
              : _courses.isEmpty
                  ? const Center(
                      child: Text('No courses assigned.',
                          style: TextStyle(color: Colors.white60)))
                  : RefreshIndicator(
                      onRefresh: _loadCourses,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _courses.length,
                        itemBuilder: (ctx, i) => _CourseCard(
                          course:  _courses[i],
                          baseUrl: widget.baseUrl,
                        ),
                      ),
                    ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.baseUrl});
  final Map<String, dynamic> course;
  final String               baseUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2A3A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
          child: const Icon(Icons.book, color: Colors.blueAccent),
        ),
        title: Text(course['course_name']?.toString() ?? '',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${course['credit_hours'] ?? ''} credit hours  •  '
          '${course['enrolled_count'] ?? 0} students enrolled',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionListPage(
              courseId:   course['course_id'].toString(),
              courseName: course['course_name']?.toString() ?? '',
              baseUrl:    baseUrl,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SESSION LIST
// ─────────────────────────────────────────────────────────────
class SessionListPage extends StatefulWidget {
  const SessionListPage({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.baseUrl,
  });
  final String courseId;
  final String courseName;
  final String baseUrl;

  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool  _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/get_course_sessions'),
        body: {'course_id': widget.courseId},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        setState(() {
          _sessions =
              List<Map<String, dynamic>>.from(data['sessions'] ?? []);
        });
      } else {
        setState(() => _error = data['message']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSession(Map<String, dynamic> session) async {
    final isActive = session['status'] == 'Active';
    final endpoint = isActive ? 'end_session' : 'start_session';
    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/$endpoint'),
        body: {'session_id': session['session_id'].toString()},
      ).timeout(const Duration(seconds: 10));
      _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Active':    return Colors.green;
      case 'Completed': return Colors.blueGrey;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sessions', style: TextStyle(fontSize: 16)),
            Text(widget.courseName,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadSessions),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)))
              : _sessions.isEmpty
                  ? const Center(
                      child: Text('No sessions found.',
                          style: TextStyle(color: Colors.white60)))
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (ctx, i) {
                          final s = _sessions[i];
                          final status = s['status']?.toString() ?? '';
                          return Card(
                            color: const Color(0xFF1A2A3A),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    _statusColor(status).withValues(alpha: 0.2),
                                child: Icon(
                                  status == 'Active'
                                      ? Icons.play_circle
                                      : status == 'Completed'
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                  color: _statusColor(status),
                                ),
                              ),
                              title: Text(
                                '${s['type'] ?? 'Session'}  •  Room ${s['room'] ?? ''}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['start'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(status,
                                          style: TextStyle(
                                              color: _statusColor(status),
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${s['present_count'] ?? 0} present',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12),
                                    ),
                                  ]),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status != 'Completed')
                                    TextButton(
                                      onPressed: () =>
                                          _toggleSession(s),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            status == 'Active'
                                                ? Colors.redAccent
                                                : Colors.green,
                                      ),
                                      child: Text(
                                          status == 'Active'
                                              ? 'End'
                                              : 'Start',
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white38),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AttendanceListPage(
                                    sessionId: s['session_id'].toString(),
                                    sessionInfo:
                                        '${s['type']} — ${s['start']}',
                                    courseName: widget.courseName,
                                    baseUrl:    widget.baseUrl,
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

// ─────────────────────────────────────────────────────────────
// ATTENDANCE LIST FOR A SESSION
// ─────────────────────────────────────────────────────────────
class AttendanceListPage extends StatefulWidget {
  const AttendanceListPage({
    super.key,
    required this.sessionId,
    required this.sessionInfo,
    required this.courseName,
    required this.baseUrl,
  });
  final String sessionId;
  final String sessionInfo;
  final String courseName;
  final String baseUrl;

  @override
  State<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  List<Map<String, dynamic>> _records = [];
  bool   _loading = true;
  String? _error;

  int get _presentCount =>
      _records.where((r) => r['status'] == 'Present').length;
  int get _absentCount  =>
      _records.where((r) => r['status'] == 'Absent').length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/get_session_attendance'),
        body: {'session_id': widget.sessionId},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        setState(() {
          _records =
              List<Map<String, dynamic>>.from(data['records'] ?? []);
        });
      } else {
        setState(() => _error = data['message']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _exportCSV() {
    final url =
        '${widget.baseUrl}/export_attendance?session_id=${widget.sessionId}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export URL: $url'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseName,
                style: const TextStyle(fontSize: 15)),
            Text(widget.sessionInfo,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCSV,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)))
              : Column(
                  children: [
                    // ── Summary bar ──────────────────────────────
                    Container(
                      color: const Color(0xFF1A2A3A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(
                              label: 'Total',
                              value: _records.length,
                              color: Colors.white70),
                          _Stat(
                              label: 'Present',
                              value: _presentCount,
                              color: Colors.green),
                          _Stat(
                              label: 'Absent',
                              value: _absentCount,
                              color: Colors.redAccent),
                          _Stat(
                              label: 'Rate',
                              value: _records.isEmpty
                                  ? 0
                                  : (_presentCount * 100 ~/
                                      _records.length),
                              suffix: '%',
                              color: Colors.blueAccent),
                        ],
                      ),
                    ),
                    // ── Student list ──────────────────────────────
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (ctx, i) {
                            final r = _records[i];
                            final present =
                                r['status'] == 'Present';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (present
                                        ? Colors.green
                                        : Colors.redAccent)
                                    .withValues(alpha: 0.15),
                                child: Icon(
                                  present
                                      ? Icons.check
                                      : Icons.close,
                                  color: present
                                      ? Colors.green
                                      : Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                  r['student_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14)),
                              subtitle: Text(
                                  'ID: ${r['student_id']}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                              trailing: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    r['status']?.toString() ?? '',
                                    style: TextStyle(
                                      color: present
                                          ? Colors.green
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if ((r['marked_at'] ?? '').isNotEmpty)
                                    Text(
                                      r['marked_at']!,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10),
                                    ),
                                ],
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
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });
  final String label;
  final int    value;
  final Color  color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value$suffix',
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
