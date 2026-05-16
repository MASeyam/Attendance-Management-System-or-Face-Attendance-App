import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import 'add_student_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _all      = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.students));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _all      = data['students'];
        _filtered = List.from(_all);
      } else {
        _error = data['message'] ?? 'Failed to load students';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((s) {
        final name  = '${s['first_name']} ${s['last_name']}'.toLowerCase();
        final id    = '${s['id']}';
        final email = (s['email'] ?? '').toLowerCase();
        return name.contains(q) || id.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _delete(int studentId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $name? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res  = await http.delete(Uri.parse(ApiConstants.deleteStudent(studentId)));
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Student deleted'), backgroundColor: AppColors.success),
        );
        _fetch();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Delete failed'),
              backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot reach server.'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, AppTheme.slideRoute(const AddStudentScreen()));
          _fetch();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by name, ID, or email',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 8, itemHeight: 72);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_filtered.isEmpty) {
      return const EmptyState(
          icon: Icons.people_outline_rounded, message: 'No students found.');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final s = _filtered[i];
          return FadeInLeft(
            delay: Duration(milliseconds: 30 * i),
            duration: const Duration(milliseconds: 200),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withAlpha(28),
                  child: Text(
                    '${s['first_name'] ?? '?'}'[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                        color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text('${s['first_name']} ${s['last_name']}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  'ID: ${s['id']}  •  Level ${s['level'] ?? '-'}  •  GPA: ${(s['gpa'] ?? 0).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: context.clrSubText),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  onPressed: () =>
                      _delete(s['id'], '${s['first_name']} ${s['last_name']}'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
